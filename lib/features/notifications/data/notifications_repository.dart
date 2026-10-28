import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in user's `notification_settings` row. Throws `PeopleFailure`
/// only.
class NotificationsRepository {
  NotificationsRepository(this._client);

  final SupabaseClient _client;

  /// Null when there is no row yet: off, and Today's card asks.
  Future<NotificationSettings?> load() => guardPeople(() async {
    final row = await _client
        .from('notification_settings')
        .select(
          'summary_enabled, ritual_enabled, task_enabled, summary_time, summary_days, '
          'time_zone',
        )
        .maybeSingle();
    return row == null ? null : NotificationSettings.fromRow(row);
  });

  /// Creates the row or replaces it; the owner is the session's, by default.
  Future<void> save(NotificationSettings settings) => guardPeople(
    () => _client.from('notification_settings').upsert(settings.toRow()),
  );
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.watch(supabaseClientProvider)),
);
