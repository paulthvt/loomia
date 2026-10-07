import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/workflows/presentation/event_step_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('before, on the day, after', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(stepTiming(l10n, -3), '3 days before');
    expect(stepTiming(l10n, -1), '1 day before');
    expect(stepTiming(l10n, 0), 'On the day');
    expect(stepTiming(l10n, 1), '1 day after');
  });
}
