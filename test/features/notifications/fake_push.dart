import 'dart:async';

import 'package:loomia/features/notifications/data/push.dart';

/// Records registrations; [tap] plays a push being tapped.
class FakePush implements Push {
  final registered = <String>[];
  var forgotten = 0;
  final _opened = StreamController<void>.broadcast();

  void tap() => _opened.add(null);

  @override
  Future<void> register(String locale) async => registered.add(locale);

  @override
  Stream<void> get opened => _opened.stream;

  @override
  Future<void> forget() async => forgotten++;

  @override
  Future<void> dispose() => _opened.close();
}
