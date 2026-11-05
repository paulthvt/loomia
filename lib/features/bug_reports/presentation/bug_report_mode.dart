import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';

/// Whether the floating bug-report button shows (#463). In memory only: off
/// at launch and whenever the account stops being a reporter (sign-out).
class BugReportMode extends Notifier<bool> {
  @override
  bool build() {
    // Rebuilds only when the flag flips, so a token refresh keeps it on.
    ref.watch(accountProvider.select((a) => a?.bugReporter ?? false));
    return false;
  }

  bool get _allowed => ref.read(accountProvider)?.bugReporter ?? false;

  void turnOn() => state = _allowed;

  void turnOff() => state = false;
}

final bugReportModeProvider = NotifierProvider<BugReportMode, bool>(
  BugReportMode.new,
);
