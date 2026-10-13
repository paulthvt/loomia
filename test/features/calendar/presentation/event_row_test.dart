import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // The app's localization delegates load this; a plain test does it here.
  setUpAll(() => initializeDateFormatting('en'));
  final l10n = lookupAppLocalizations(const Locale('en'));
  final tuesday = DateTime(2026, 10, 13);

  test('repeatLine: the weeks, the weekday, and the end day', () {
    expect(
      repeatLine(l10n, everyWeeks: 1, firstOn: tuesday),
      'Every week on Tuesday',
    );
    expect(
      repeatLine(
        l10n,
        everyWeeks: 2,
        firstOn: tuesday,
        untilOn: DateTime(2026, 12, 15),
      ),
      'Every 2 weeks on Tuesday · until December 15',
    );
    expect(
      repeatLine(
        l10n,
        everyWeeks: 4,
        firstOn: tuesday,
        untilOn: DateTime(2027, 3, 2),
      ),
      'Every 4 weeks on Tuesday · until March 2, 2027',
    );
  });
}
