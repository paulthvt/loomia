import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/notifications/data/device_repository.dart';

/// The only Firebase code (docs/architecture.md → Push).
///
/// Optional at run time: on the web, in tests and in a build without the
/// Firebase files, [Firebase.initializeApp] fails and every method does
/// nothing. Nothing here throws; failures are logged.
class Push {
  Push(this._devices);

  final DeviceRepository Function() _devices;

  Future<bool>? _ready;
  StreamSubscription<String>? _refresh;
  String? _locale;

  /// Saves this phone's token for the signed-in user, in [locale], when
  /// notifications are allowed; asking is not this class's job (#270). A
  /// token refresh saves the new one.
  Future<void> register(String locale) async {
    _locale = locale;
    if (!await _start()) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final status =
          (await messaging.getNotificationSettings()).authorizationStatus;
      if (status != AuthorizationStatus.authorized &&
          status != AuthorizationStatus.provisional) {
        return;
      }
      _refresh ??= messaging.onTokenRefresh.listen(_save);
      // iOS hands out an FCM token only once APNs has given one; until then
      // onTokenRefresh catches up.
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          await messaging.getAPNSToken() == null) {
        return;
      }
      final token = await messaging.getToken();
      if (token != null) await _save(token);
    } on Object catch (error) {
      _log.info('no token', error);
    }
  }

  /// One event per push tapped: the one that launched the app, then each
  /// one tapped while it runs.
  Stream<void> get opened async* {
    if (!await _start()) return;
    if (await FirebaseMessaging.instance.getInitialMessage() != null) {
      yield null;
    }
    yield* FirebaseMessaging.onMessageOpenedApp.map((_) {});
  }

  /// After sign-out: the token dies, so pushes for that account stop here
  /// and the sender drops its row when FCM says UNREGISTERED. The session is
  /// gone already, so the row can't be deleted from here.
  Future<void> forget() async {
    if (!await _start()) return;
    await _refresh?.cancel();
    _refresh = null;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } on Object catch (error) {
      _log.info('token not deleted', error);
    }
  }

  Future<void> dispose() async => _refresh?.cancel();

  Future<bool> _start() => _ready ??= () async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return false;
    }
    try {
      await Firebase.initializeApp();
      return true;
    } on Object catch (error) {
      _log.info('push off: no Firebase', error);
      return false;
    }
  }();

  Future<void> _save(String token) async {
    final locale = _locale;
    if (locale == null) return;
    try {
      await _devices().register(
        token: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        locale: locale,
      );
    } on PeopleFailure {
      // Logged by guardPeople; the next launch registers again.
    }
  }
}

/// Forgets the token when the account signs out.
final pushProvider = Provider<Push>((ref) {
  final push = Push(() => ref.read(deviceRepositoryProvider));
  ref.listen(accountProvider, (was, now) {
    if (was != null && now == null) unawaited(push.forget());
  });
  ref.onDispose(push.dispose);
  return push;
});

final _log = Logger('push');
