import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/workflows/data/event_workflow_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `event` table. Every method throws [PeopleFailure] and nothing else.
/// RLS scopes everything to the user, and `owner_id` defaults to them.
class EventRepository {
  EventRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'event';

  /// Every column, who is invited, and the series an occurrence is in.
  static const String _columns =
      '*, event_attendee(person_id, came), event_step_done(step_id, done_on), '
      'event_series(id, every_weeks, first_on, until_on)';

  /// Every event, earliest first, once every series is generated up to a
  /// year after [today] (the device's).
  // ponytail: loads every event; read a month at a time (the starts_at
  // index is there) once someone has years of them.
  Future<List<CalendarEvent>> list(DateTime today) => guardPeople(() async {
    await _client.rpc<void>(
      'extend_event_series',
      params: {'p_today': dayColumn(today)},
    );
    final rows = await _client.from(_table).select(_columns).order('starts_at');
    return rows.map(eventFromRow).toList();
  });

  /// A new series; its occurrences appear on the next [list]. Returns its id.
  Future<String> addSeries(EventDraft draft, RepeatRule rule, String zone) =>
      guardPeople(() async {
        final row = await _client
            .from('event_series')
            .insert(seriesToRow(draft, rule, zone))
            .select('id')
            .single();
        return row['id'] as String;
      });

  /// [add] and [remove] on [eventId]'s series and on every not done
  /// occurrence from it on.
  Future<void> setSeriesPeople(
    String eventId, {
    Iterable<String> add = const [],
    Iterable<String> remove = const [],
  }) => guardPeople(
    () => _client.rpc<Object?>(
      'set_series_attendees',
      params: {
        'p_event': eventId,
        'p_add': add.toList(),
        'p_remove': remove.toList(),
      },
    ),
  );

  Future<CalendarEvent> add(EventDraft draft) => guardPeople(() async {
    final row = await _client
        .from(_table)
        .insert(draftToEventRow(draft))
        .select(_columns)
        .single();
    return eventFromRow(row);
  });

  Future<CalendarEvent> update(String id, EventDraft draft) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .update(draftToEventRow(draft))
            .eq('id', id)
            .select(_columns)
            .single();
        return eventFromRow(row);
      });

  Future<void> remove(String id) =>
      guardPeople(() => _client.from(_table).delete().eq('id', id));

  Future<void> invite(String eventId, Iterable<String> personIds) =>
      guardPeople(
        () => _client.from('event_attendee').insert([
          for (final personId in personIds)
            {'event_id': eventId, 'person_id': personId},
        ]),
      );

  Future<void> uninvite(String eventId, String personId) => guardPeople(
    () => _client
        .from('event_attendee')
        .delete()
        .eq('event_id', eventId)
        .eq('person_id', personId),
  );

  /// Who was there, an Event entry in each of their histories on [today],
  /// and the event done, in one transaction. An event already done, or an
  /// id that isn't invited, is refused.
  Future<void> markDone(
    String eventId,
    Iterable<String> came,
    DateTime today,
  ) => guardPeople(
    () => _client.rpc<Object?>(
      'mark_event_done',
      params: {
        'p_event': eventId,
        'p_came': came.toList(),
        'p_today': dayColumn(today),
      },
    ),
  );

  /// Ticking a step already ticked (a double tap) keeps the first day.
  Future<void> tick(String eventId, String stepId, DateTime on) => guardPeople(
    () => _client
        .from('event_step_done')
        .upsert(
          {'event_id': eventId, 'step_id': stepId, 'done_on': dayColumn(on)},
          onConflict: 'event_id,step_id',
          ignoreDuplicates: true,
        ),
  );

  Future<void> untick(String eventId, String stepId) => guardPeople(
    () => _client
        .from('event_step_done')
        .delete()
        .eq('event_id', eventId)
        .eq('step_id', stepId),
  );
}

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(ref.watch(supabaseClientProvider)),
);

String? _text(Object? value) {
  final text = (value as String?)?.trim();
  return text == null || text.isEmpty ? null : text;
}

CalendarEvent eventFromRow(Map<String, dynamic> row) => CalendarEvent(
  id: row['id'] as String,
  title: row['title'] as String,
  startsAt: DateTime.parse(row['starts_at'] as String),
  endsAt: switch (row['ends_at']) {
    final String at => DateTime.parse(at),
    _ => null,
  },
  place: _text(row['place']),
  link: _text(row['link']),
  notes: _text(row['notes']),
  doneAt: switch (row['done_at']) {
    final String at => DateTime.parse(at),
    _ => null,
  },
  attendees: [
    for (final attendee in (row['event_attendee'] as List?) ?? const [])
      (
        personId: (attendee as Map<String, dynamic>)['person_id'] as String,
        came: attendee['came'] as bool,
      ),
  ],
  eventWorkflowId: row['event_workflow_id'] as String?,
  followUps: followUpsFromRow(row),
  stepsDone: {
    for (final done in (row['event_step_done'] as List?) ?? const [])
      (done as Map<String, dynamic>)['step_id'] as String: DateTime.parse(
        done['done_on'] as String,
      ),
  },
  series: switch (row['event_series']) {
    final Map<String, dynamic> series => (
      id: series['id'] as String,
      everyWeeks: series['every_weeks'] as int,
      firstOn: DateTime.parse(series['first_on'] as String),
      untilOn: switch (series['until_on']) {
        final String day => DateTime.parse(day),
        _ => null,
      },
    ),
    _ => null,
  },
);

/// The series row for New event with Repeat: the first day and the start
/// as a local day and wall-clock time in [zone], so Postgres can place
/// every later start in that zone.
Map<String, Object?> seriesToRow(
  EventDraft draft,
  RepeatRule rule,
  String zone,
) {
  final start = draft.startsAt;
  String two(int value) => value.toString().padLeft(2, '0');
  final until = rule.untilOn;
  return {
    'title': draft.title,
    'first_on': dayColumn(start),
    'starts_time': '${two(start.hour)}:${two(start.minute)}',
    'minutes': draft.endsAt?.difference(start).inMinutes,
    'time_zone': zone,
    'every_weeks': rule.everyWeeks,
    'until_on': until == null ? null : dayColumn(until),
    'place': draft.place,
    'link': draft.link,
    'notes': draft.notes,
    'event_workflow_id': draft.eventWorkflowId,
    ...followUpsToRow(draft.followUps),
  };
}

Map<String, Object?> draftToEventRow(EventDraft draft) => {
  'title': draft.title,
  'starts_at': draft.startsAt.toUtc().toIso8601String(),
  'ends_at': draft.endsAt?.toUtc().toIso8601String(),
  'place': draft.place,
  'link': draft.link,
  'notes': draft.notes,
  'event_workflow_id': draft.eventWorkflowId,
  ...followUpsToRow(draft.followUps),
};
