import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';

MonthPlan _closed(
  int month, {
  double ownVolume = 0,
  int prospects = 0,
  double? teamVolume,
}) => MonthPlan(
  month: DateTime(2026, month),
  actual: Progress(
    ownVolume: ownVolume,
    prospects: prospects,
    customers: 0,
    teamMembers: 0,
    loyalty: 0,
  ),
  teamVolumeActual: teamVolume,
  closedAt: DateTime(2026, month + 1),
);

void main() {
  group('pace', () {
    test('nothing in the first 3 days', () {
      expect(pace(2800, 100, DateTime(2026, 9, 3)), isNull);
    });

    test('nothing without a target', () {
      expect(pace(null, 100, DateTime(2026, 9, 19)), isNull);
    });

    test('projects the month end from the days gone', () {
      // 1 840 in 19 of 30 days: about 2 905 by the 30th.
      final result = pace(2800, 1840, DateTime(2026, 9, 19))!;
      expect(result.projected, closeTo(2905.26, 0.01));
      expect(result.onPace, isTrue);
    });

    test('behind when the projection falls short', () {
      expect(pace(2800, 1000, DateTime(2026, 9, 19))!.onPace, isFalse);
    });
  });

  group('ritualWindow', () {
    test('the last 3 days close this month and plan the next', () {
      expect(ritualWindow(DateTime(2026, 9, 28)), (
        close: DateTime(2026, 9),
        plan: DateTime(2026, 10),
      ));
      expect(ritualWindow(DateTime(2026, 12, 29))?.plan, DateTime(2027));
    });

    test('February opens on the 26th of 28', () {
      expect(ritualWindow(DateTime(2027, 2, 26))?.close, DateTime(2027, 2));
      expect(ritualWindow(DateTime(2027, 2, 25)), isNull);
    });

    test('the first 5 days close the previous month', () {
      expect(ritualWindow(DateTime(2026, 10, 5)), (
        close: DateTime(2026, 9),
        plan: DateTime(2026, 10),
      ));
      expect(ritualWindow(DateTime(2027, 1, 1))?.close, DateTime(2026, 12));
    });

    test('closed from the 6th until 3 days before the end', () {
      expect(ritualWindow(DateTime(2026, 10, 6)), isNull);
      expect(ritualWindow(DateTime(2026, 10, 28)), isNull);
    });
  });

  group('suggest', () {
    test('nothing without a closed month', () {
      final none = suggest([MonthPlan(month: DateTime(2026, 9))]);
      expect(none.ownVolume, isNull);
      expect(none.prospects, isNull);
    });

    test('the rounded mean of the last 3 closed months', () {
      final result = suggest([
        _closed(5, ownVolume: 9000, prospects: 9),
        _closed(6, ownVolume: 1000, prospects: 2),
        _closed(7, ownVolume: 1500, prospects: 3),
        _closed(8, ownVolume: 2000, prospects: 3),
        MonthPlan(month: DateTime(2026, 9)),
      ]);
      expect(result.ownVolume, 1500);
      expect(result.prospects, 3);
    });

    test('team volume from the months it was typed', () {
      final result = suggest([
        _closed(6, teamVolume: 4000),
        _closed(7),
        _closed(8, teamVolume: 5001),
      ]);
      expect(result.teamVolume, 4501);
    });
  });
}
