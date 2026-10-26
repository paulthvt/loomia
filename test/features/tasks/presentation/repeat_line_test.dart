import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/task_row.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en'));
  final l10n = lookupAppLocalizations(const Locale('en'));

  String line(int every, RepeatUnit unit, DateTime from, {DateTime? until}) =>
      repeatLine(l10n, (
        every: every,
        unit: unit,
        from: from,
        until: until,
        scheduledOn: from,
      ));

  test('each unit, one and several', () {
    final thu = DateTime(2026, 10, 22);
    expect(line(1, RepeatUnit.day, thu), 'Every day');
    expect(line(3, RepeatUnit.day, thu), 'Every 3 days');
    expect(line(1, RepeatUnit.week, thu), 'Every week on Thursday');
    expect(line(2, RepeatUnit.week, thu), 'Every 2 weeks on Thursday');
    expect(line(1, RepeatUnit.month, thu), 'Every month on the 22nd');
    expect(line(6, RepeatUnit.month, thu), 'Every 6 months on the 22nd');
    expect(line(1, RepeatUnit.year, thu), 'Every year on October 22');
    expect(line(2, RepeatUnit.year, thu), 'Every 2 years on October 22');
  });

  test('ordinal days of the month', () {
    String day(int d) => line(1, RepeatUnit.month, DateTime(2026, 1, d));
    expect(day(1), 'Every month on the 1st');
    expect(day(2), 'Every month on the 2nd');
    expect(day(3), 'Every month on the 3rd');
    expect(day(11), 'Every month on the 11th');
    expect(day(12), 'Every month on the 12th');
    expect(day(21), 'Every month on the 21st');
    expect(day(31), 'Every month on the 31st');
  });

  test('an end date', () {
    expect(
      line(
        1,
        RepeatUnit.month,
        DateTime(2026, 10, 3),
        until: DateTime(2027, 6, 3),
      ),
      'Every month on the 3rd, until Jun 3, 2027',
    );
  });
}
