import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The kinds of push this build has strings for (`notification_kind`): the
/// sender sends no other kind to this phone (#148). A new kind ships its
/// strings first, then is added here.
const pushKinds = [
  'daily_summary',
  'month_ritual',
  // #377: a task's time, and the summary's task counts.
  'task_alert',
  'daily_summary_tasks',
  // #423: an invite to share goals was accepted.
  'share_accepted',
];

/// Where this phone's pushes go. Throws `PeopleFailure` only.
class DeviceRepository {
  DeviceRepository(this._client);

  final SupabaseClient _client;

  /// Saves [token] as the signed-in user's, taking it over from any other
  /// account, with the language the push is written in and [pushKinds].
  Future<void> register({
    required String token,
    required String platform,
    required String locale,
  }) => guardPeople(
    () => _client.rpc<void>(
      'register_device',
      params: {
        'p_token': token,
        'p_platform': platform,
        'p_locale': locale,
        'p_kinds': pushKinds,
      },
    ),
  );
}

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => DeviceRepository(ref.watch(supabaseClientProvider)),
);
