import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `event` table. Every method throws [PeopleFailure] and nothing else.
/// RLS scopes everything to the user, and `owner_id` defaults to them.
class EventRepository {
  EventRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'event';

  /// Every event, earliest first.
  // ponytail: loads every event; read a month at a time (the starts_at
  // index is there) once someone has years of them.
  Future<List<CalendarEvent>> list() => guardPeople(() async {
    final rows = await _client.from(_table).select().order('starts_at');
    return rows.map(eventFromRow).toList();
  });

  Future<CalendarEvent> add(EventDraft draft) => guardPeople(() async {
    final row = await _client
        .from(_table)
        .insert(draftToEventRow(draft))
        .select()
        .single();
    return eventFromRow(row);
  });

  Future<CalendarEvent> update(String id, EventDraft draft) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .update(draftToEventRow(draft))
            .eq('id', id)
            .select()
            .single();
        return eventFromRow(row);
      });

  Future<void> remove(String id) =>
      guardPeople(() => _client.from(_table).delete().eq('id', id));
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
);

Map<String, Object?> draftToEventRow(EventDraft draft) => {
  'title': draft.title,
  'starts_at': draft.startsAt.toUtc().toIso8601String(),
  'ends_at': draft.endsAt?.toUtc().toIso8601String(),
  'place': draft.place,
  'link': draft.link,
  'notes': draft.notes,
};
