import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Where this phone's pushes go. Throws `PeopleFailure` only.
class DeviceRepository {
  DeviceRepository(this._client);

  final SupabaseClient _client;

  /// Saves [token] as the signed-in user's, taking it over from any other
  /// account, with the language the push is written in.
  Future<void> register({
    required String token,
    required String platform,
    required String locale,
  }) => guardPeople(
    () => _client.rpc<void>(
      'register_device',
      params: {'p_token': token, 'p_platform': platform, 'p_locale': locale},
    ),
  );
}

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => DeviceRepository(ref.watch(supabaseClientProvider)),
);
