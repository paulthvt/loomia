import 'dart:async';

import 'package:loomia/features/notifications/data/push.dart';

/// Records registrations; [tap] plays a push being tapped. [grant] is the
/// answer to the OS prompt; [isAvailable] false is the web or no Firebase.
class FakePush implements Push {
  FakePush({
    this.isAvailable = true,
    this.isAllowed = false,
    this.grant = true,
  });

  bool isAvailable;
  bool isAllowed;
  bool grant;

  final registered = <String>[];
  var asked = 0;
  var forgotten = 0;
  final _opened = StreamController<Map<String, Object?>>.broadcast();

  /// A push tapped, carrying [data] as FCM does.
  void tap([Map<String, Object?> data = const {}]) => _opened.add(data);

  @override
  Future<bool> get available async => isAvailable;

  @override
  Future<bool?> allowed() async => isAvailable ? isAllowed : null;

  @override
  Future<bool> ask() async {
    if (!isAvailable) return false;
    asked++;
    isAllowed = grant;
    return grant;
  }

  @override
  Future<void> register(String locale) async => registered.add(locale);

  @override
  Stream<Map<String, Object?>> get opened => _opened.stream;

  @override
  Future<void> forget() async => forgotten++;

  @override
  Future<void> dispose() => _opened.close();
}
