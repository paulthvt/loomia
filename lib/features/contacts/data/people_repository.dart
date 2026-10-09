import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `person` table. Every method throws [PeopleFailure] and nothing else, so
/// screens never see a `supabase_flutter` type.
///
/// RLS scopes every query to the signed-in user, and `owner_id` defaults to
/// them on insert, so no call here names an owner.
class PeopleRepository {
  PeopleRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'person';

  /// Every column, the server's computed step, due day and last contact, and
  /// the open reminders.
  static const String _columns =
      '*, current_step_id, due_on, last_contact_on, reminder($_reminderColumns)';

  static const String _reminderColumns = 'id, text, due_on, created_at';

  /// Unordered: the controller sorts by `searchKey`, which Postgres collation
  /// does not match.
  Future<List<Person>> list() => guardPeople(() async {
    final rows = await _client.from(_table).select(_columns);
    return rows.map(personFromRow).toList();
  });

  Future<Person> add(PersonDraft draft, {WorkflowPlace? place}) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .insert({...draftToRow(draft), ...placeToRow(place)})
            .select(_columns)
            .single();
        return personFromRow(row);
      });

  /// One insert for the whole batch: all of them are saved, or none. Each
  /// starts at [place], in their stage since [stageSince]; null is now.
  Future<List<Person>> addAll(
    List<PersonDraft> drafts, {
    WorkflowPlace? place,
    DateTime? stageSince,
  }) => guardPeople(() async {
    final rows = await _client
        .from(_table)
        .insert([
          for (final draft in drafts)
            {
              ...draftToRow(draft),
              ...placeToRow(place),
              if (stageSince != null)
                'stage_since': stageSince.toUtc().toIso8601String(),
            },
        ])
        .select(_columns);
    return rows.map(personFromRow).toList();
  });

  /// [stageSince] corrects the day the stage began (#179); null keeps it, so
  /// a stale copy never moves it back.
  Future<Person> update(Person person, {DateTime? stageSince}) =>
      _write(person.id, {
        ...personToRow(person),
        if (stageSince != null)
          'stage_since': stageSince.toUtc().toIso8601String(),
      });

  /// One request: all of them are deleted, or none.
  Future<void> delete(List<String> ids) =>
      guardPeople(() => _client.from(_table).delete().inFilter('id', ids));

  /// Writes the stage and the workflow that follows it, in one update for all
  /// of [ids]; a null [place] is "nothing for now". The database sets
  /// [Person.stageSince], clears a leaving prospect's status and any pause,
  /// and records each change in the history; the returned people are the
  /// rows as it left them.
  Future<List<Person>> setStage(
    List<String> ids,
    Stage stage, {
    WorkflowPlace? place,
  }) => _writeAll(ids, {'stage': stage.name, ...placeToRow(place)});

  /// Change workflow, for all of [ids] in one update. Picking what comes next
  /// also ends a pause.
  Future<List<Person>> setPlace(List<String> ids, WorkflowPlace? place) =>
      _writeAll(ids, {...placeToRow(place), 'paused_at': null});

  /// Null: no photo. The file itself is the caller's (`swapPhoto`).
  Future<Person> setPhoto(String id, String? path) =>
      _write(id, {'photo_path': path});

  /// [notNow] also sets a prospect's status to Not now.
  /// Corrects the day their stage began. The database moves the latest stage
  /// entry in the history with it.
  Future<Person> setStageSince(String id, DateTime at) =>
      _write(id, {'stage_since': at.toUtc().toIso8601String()});

  Future<Person> pause(String id, DateTime at, {required bool notNow}) =>
      _write(id, {
        'paused_at': at.toUtc().toIso8601String(),
        if (notNow) 'prospect_status': _statusColumn[ProspectStatus.notNow],
      });

  /// The same step comes back, due counted from [today].
  Future<Person> resume(String id, DateTime today) =>
      _write(id, {'paused_at': null, 'last_tick': dayColumn(today)});

  /// Ticks [stepId], which must be the person's current step: the history
  /// entry and the move, in one transaction on the server, which also finds
  /// the next step. Any other step (a stale tick) is refused.
  Future<Person> completeStep(String personId, String stepId, DateTime on) =>
      guardPeople(() async {
        final row = await _client
            .rpc<Object?>(
              'complete_step',
              params: {
                'p_person': personId,
                'p_step': stepId,
                'p_on': dayColumn(on),
              },
            )
            .select(_columns)
            .single();
        return personFromRow(row);
      });

  /// A reminder for [personId], as saved.
  Future<Reminder> addReminder(String personId, String text, DateTime dueOn) =>
      guardPeople(() async {
        final row = await _client
            .from('reminder')
            .insert({
              'person_id': personId,
              'text': text.trim(),
              'due_on': dayColumn(dueOn),
            })
            .select(_reminderColumns)
            .single();
        return reminderFromRow(row);
      });

  Future<Reminder> updateReminder(String id, String text, DateTime dueOn) =>
      guardPeople(() async {
        final row = await _client
            .from('reminder')
            .update({'text': text.trim(), 'due_on': dayColumn(dueOn)})
            .eq('id', id)
            .select(_reminderColumns)
            .single();
        return reminderFromRow(row);
      });

  Future<void> deleteReminder(String id) =>
      guardPeople(() => _client.from('reminder').delete().eq('id', id));

  /// Ticks a reminder: the history entry and the delete, in one transaction
  /// on the server. One already gone (ticked on another device) is refused.
  ///
  /// Returns nothing: PostgREST would read an embedded `reminder(...)` and
  /// `last_contact_on` in the call's own snapshot, before its delete and
  /// insert, so the person it returns still has the reminder. The caller
  /// reads the book again.
  Future<void> completeReminder(String id, DateTime on) => guardPeople(
    () => _client.rpc<Object?>(
      'complete_reminder',
      params: {'p_reminder': id, 'p_on': dayColumn(on)},
    ),
  );

  Future<Person> _write(String id, Map<String, dynamic> values) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .update(values)
            .eq('id', id)
            .select(_columns)
            .single();
        return personFromRow(row);
      });

  /// Rows deleted meanwhile are simply not returned.
  Future<List<Person>> _writeAll(
    List<String> ids,
    Map<String, dynamic> values,
  ) => guardPeople(() async {
    final rows = await _client
        .from(_table)
        .update(values)
        .inFilter('id', ids)
        .select(_columns);
    return rows.map(personFromRow).toList();
  });
}

final peopleRepositoryProvider = Provider<PeopleRepository>(
  (ref) => PeopleRepository(ref.watch(supabaseClientProvider)),
);

/// A refusal from the server is [PeopleFailure.unknown]; any other exception
/// on the way (socket, timeout, `http.ClientException`) is the connection.
/// Errors — bugs, a malformed row — are unknown.
PeopleFailure peopleFailureFrom(Object error) => switch (error) {
  final PeopleFailure failure => failure,
  PostgrestException() => PeopleFailure.unknown,
  // A refusal from Storage (too large, wrong type, a policy): not the
  // connection.
  StorageException() => PeopleFailure.unknown,
  FormatException() => PeopleFailure.unknown,
  Exception() => PeopleFailure.network,
  _ => PeopleFailure.unknown,
};

/// Runs [call] and turns whatever it throws into a [PeopleFailure]. Every
/// contacts repository goes through it.
Future<T> guardPeople<T>(Future<T> Function() call) async {
  try {
    return await call();
  } catch (error) {
    throw peopleFailureFrom(error);
  }
}

const Map<ProspectStatus, String> _statusColumn = {
  ProspectStatus.interested: 'interested',
  ProspectStatus.thinking: 'thinking',
  ProspectStatus.notNow: 'not_now',
  ProspectStatus.noReply: 'no_reply',
};

final Map<String, ProspectStatus> _statusFromColumn = {
  for (final MapEntry(:key, :value) in _statusColumn.entries) value: key,
};

Person personFromRow(Map<String, dynamic> row) {
  final status = row['prospect_status'] as String?;
  return Person(
    id: row['id'] as String,
    name: row['name'] as String,
    stage:
        Stage.values.asNameMap()[row['stage']] ?? (throw PeopleFailure.unknown),
    prospectStatus: status == null
        ? null
        : _statusFromColumn[status] ?? (throw PeopleFailure.unknown),
    phone: _text(row['phone']),
    email: _text(row['email']),
    instagram: _text(row['instagram']),
    needs: _text(row['needs']),
    products: _text(row['products']),
    profession: _text(row['profession']),
    address: _text(row['address']),
    notes: _text(row['notes']),
    why: _text(row['why']),
    currentLevel: _text(row['current_level']),
    targetLevel: _text(row['target_level']),
    targetLevelBy: switch (row['target_level_by']) {
      // A bare date parses as local midnight.
      final String by => DateTime.parse(by),
      _ => null,
    },
    monthlyVolumeTarget: (row['monthly_volume_target'] as num?)?.toDouble(),
    ownGoal: _text(row['own_goal']),
    timeAvailable: _text(row['time_available']),
    wouldLoveTo: _text(row['would_love_to']),
    strengths: _text(row['strengths']),
    stuckOn: _text(row['stuck_on']),
    stageSince: DateTime.parse(row['stage_since'] as String),
    place: switch ((row['workflow_id'], row['at_position'], row['last_tick'])) {
      (final String id, final num at, final String tick) => (
        workflowId: id,
        atPosition: at,
        // A bare date parses as local midnight, which is what a day is here.
        lastTick: DateTime.parse(tick),
      ),
      _ => null,
    },
    pausedAt: switch (row['paused_at']) {
      final String at => DateTime.parse(at),
      _ => null,
    },
    currentStepId: row['current_step_id'] as String?,
    dueOn: switch (row['due_on']) {
      // A bare date parses as local midnight, like last_tick.
      final String day => DateTime.parse(day),
      _ => null,
    },
    lastContactOn: switch (row['last_contact_on']) {
      // A bare date parses as local midnight, like due_on.
      final String day => DateTime.parse(day),
      _ => null,
    },
    photoPath: _text(row['photo_path']),
    reminders: sortedReminders([
      for (final reminder in (row['reminder'] as List?) ?? const [])
        reminderFromRow(reminder as Map<String, dynamic>),
    ]),
  );
}

Reminder reminderFromRow(Map<String, dynamic> row) => (
  id: row['id'] as String,
  text: row['text'] as String,
  // A bare date parses as local midnight.
  dueOn: DateTime.parse(row['due_on'] as String),
  createdAt: DateTime.parse(row['created_at'] as String),
);

/// What an update writes: everything the user can edit, except the stage and
/// the workflow fields. Only [PeopleRepository.setStage] writes it, so a stale
/// copy never moves someone back (and into the history). Nor the photo: only
/// [PeopleRepository.setPhoto] writes it, so a stale copy never brings a
/// removed one back.
Map<String, dynamic> personToRow(Person person) => {
  'name': person.name.trim(),
  'prospect_status': _statusColumn[person.prospectStatus],
  'phone': _text(person.phone),
  'email': _text(person.email),
  'instagram': _text(person.instagram),
  'needs': _text(person.needs),
  'products': _text(person.products),
  'profession': _text(person.profession),
  'address': _text(person.address),
  'notes': _text(person.notes),
  'why': _text(person.why),
  'own_goal': _text(person.ownGoal),
  'time_available': _text(person.timeAvailable),
  'would_love_to': _text(person.wouldLoveTo),
  'strengths': _text(person.strengths),
  'stuck_on': _text(person.stuckOn),
  'current_level': _text(person.currentLevel),
  'target_level': _text(person.targetLevel),
  'target_level_by': switch (person.targetLevelBy) {
    final DateTime by => dayColumn(by),
    null => null,
  },
  'monthly_volume_target': person.monthlyVolumeTarget,
};

Map<String, dynamic> draftToRow(PersonDraft draft) => {
  'name': draft.name.trim(),
  'stage': draft.stage.name,
  'phone': _text(draft.phone),
  'email': _text(draft.email),
  'instagram': _text(draft.instagram),
};

/// Blank is absent, in both directions.
String? _text(Object? value) {
  final text = (value as String?)?.trim();
  return text == null || text.isEmpty ? null : text;
}

Map<String, dynamic> placeToRow(WorkflowPlace? place) => {
  'workflow_id': place?.workflowId,
  'at_position': place?.atPosition,
  'last_tick': place == null ? null : dayColumn(place.lastTick),
};

/// `yyyy-MM-dd`, what a `date` column takes; no locale involved.
String dayColumn(DateTime day) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${day.year}-${two(day.month)}-${two(day.day)}';
}
