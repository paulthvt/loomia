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

  /// Whether push works here: Android or iOS with Firebase configured.
  Future<bool> get available => _start();

  /// Whether the OS lets Loomia notify; null where push doesn't work.
  Future<bool?> allowed() async {
    if (!await _start()) return null;
    try {
      return _isAllowed(
        (await FirebaseMessaging.instance.getNotificationSettings())
            .authorizationStatus,
      );
    } on Object catch (error) {
      _log.info('permission unknown', error);
      return null;
    }
  }

  /// The OS prompt, once; after a refusal the OS answers without asking.
  /// Granted: registers this phone straight away.
  Future<bool> ask() async {
    if (!await _start()) return false;
    try {
      final granted = _isAllowed(
        (await FirebaseMessaging.instance.requestPermission())
            .authorizationStatus,
      );
      final locale = _locale;
      if (granted && locale != null) await register(locale);
      return granted;
    } on Object catch (error) {
      _log.info('permission not asked', error);
      return false;
    }
  }

  /// Saves this phone's token for the signed-in user, in [locale], when
  /// notifications are allowed; asking is [ask]'s job. A token refresh saves
  /// the new one.
  Future<void> register(String locale) async {
    _locale = locale;
    if (!await _start()) return;
    try {
      final messaging = FirebaseMessaging.instance;
      if (!_isAllowed(
        (await messaging.getNotificationSettings()).authorizationStatus,
      )) {
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

  /// One event per push tapped, with its `data`: the one that launched the
  /// app, then each one tapped while it runs.
  Stream<Map<String, Object?>> get opened async* {
    if (!await _start()) return;
    if (await FirebaseMessaging.instance.getInitialMessage() case final m?) {
      yield m.data;
    }
    yield* FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);
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

  static bool _isAllowed(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

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
