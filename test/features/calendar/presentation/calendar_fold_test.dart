import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/domain/month_grid.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_event_repository.dart';

/// The phone month's fold (#561), in the app: the real selection and fold
/// state, today's month, English (weeks from Sunday).
void main() {
  late ProviderContainer container;
  late FakeEventRepository events;

  Future<void> open(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    events = FakeEventRepository();
    container = await pumpLoomia(tester, size: size, events: events);
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
  }

  bool folded() => container.read(monthFoldedProvider);
  double gridBottom(WidgetTester tester) =>
      tester.getBottomLeft(find.byType(MonthGrid)).dy;
  int loads() => events.calls.where((call) => call == 'list()').length;

  /// What the month gives back folded: all its rows but one.
  double distance() {
    final month = container.read(calendarSelectionProvider).month;
    final rows = monthDays(month, 0).length ~/ DateTime.daysPerWeek;
    return (rows - 1) * DayCell.size;
  }

  testWidgets('a short drag up on the day folds the month to its week', (
    tester,
  ) async {
    await open(tester);
    final top = gridBottom(tester);

    await tester.drag(find.byType(DaySection), const Offset(0, -10));
    await tester.pumpAndSettle();
    expect(folded(), isFalse, reason: 'under 24 dp: a tap or a wobble');

    await tester.drag(find.byType(DaySection), const Offset(0, -30));
    await tester.pumpAndSettle();
    expect(folded(), isTrue);
    expect(gridBottom(tester), closeTo(top - distance(), 0.5));
    // One week: seven days, today among them.
    expect(find.byType(DayCell), findsNWidgets(DateTime.daysPerWeek));
  });

  testWidgets('started, the fold lands whatever the finger does', (
    tester,
  ) async {
    await open(tester);
    final top = gridBottom(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DaySection)),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    // Held still mid-way, then past its 420 ms.
    await tester.pump(const Duration(milliseconds: 150));
    final midway = gridBottom(tester);
    expect(midway, lessThan(top));
    expect(midway, greaterThan(top - distance()));
    await tester.pump(const Duration(milliseconds: 400));
    expect(gridBottom(tester), closeTo(top - distance(), 0.5));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(folded(), isTrue);
  });

  testWidgets('pulling down before it lands turns it back', (tester) async {
    await open(tester);
    final top = gridBottom(tester);
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(DaySection)),
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -5));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 8));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(folded(), isFalse);
    expect(gridBottom(tester), closeTo(top, 0.5));
  });

  testWidgets('folded, a pull at the top unfolds it and reloads nothing', (
    tester,
  ) async {
    await open(tester);
    final top = gridBottom(tester);
    await tester.drag(find.byType(DaySection), const Offset(0, -30));
    await tester.pumpAndSettle();
    final before = loads();

    await tester.drag(find.byType(DaySection), const Offset(0, 40));
    await tester.pumpAndSettle();

    expect(folded(), isFalse);
    expect(gridBottom(tester), closeTo(top, 0.5));
    expect(loads(), before);

    // Open, the same pull reloads.
    await tester.fling(find.byType(DaySection), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();
    expect(loads(), before + 1);
  });

  testWidgets('folded, a drag down on the week or its handle unfolds it', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    await tester.drag(find.byType(DaySection), const Offset(0, -30));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(MonthGrid), const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(folded(), isFalse);

    await tester.drag(find.byType(DaySection), const Offset(0, -30));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Show the whole month'));
    await tester.pumpAndSettle();
    expect(folded(), isFalse);
    expect(find.bySemanticsLabel('Show the whole month'), findsNothing);
    semantics.dispose();
  });

  testWidgets('folded, a swipe turns a week; unfolding shows its month', (
    tester,
  ) async {
    await open(tester);
    await tester.drag(find.byType(DaySection), const Offset(0, -30));
    await tester.pumpAndSettle();
    final now = today();

    for (var week = 1; week <= 5; week++) {
      await tester.drag(find.byType(MonthGrid), const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(
        container.read(calendarSelectionProvider).day,
        DateTime(now.year, now.month, now.day + 7 * week),
      );
    }
    expect(folded(), isTrue);

    await tester.drag(find.byType(DaySection), const Offset(0, 40));
    await tester.pumpAndSettle();
    final day = container.read(calendarSelectionProvider).day;
    expect(
      container.read(calendarSelectionProvider).month,
      DateTime(day.year, day.month),
    );
    expect(
      find.byType(DayCell),
      findsNWidgets(monthDays(DateTime(day.year, day.month), 0).length),
    );
  });

  testWidgets('a vertical drag on the open month folds nothing (#369)', (
    tester,
  ) async {
    await open(tester);
    await tester.drag(find.byType(MonthGrid), const Offset(0, -60));
    await tester.pumpAndSettle();
    expect(folded(), isFalse);
  });

  testWidgets('another view, then Month again: it opens unfolded', (
    tester,
  ) async {
    await open(tester);
    await tester.drag(find.byType(DaySection), const Offset(0, -30));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(folded(), isFalse);
  });

  testWidgets('reduce motion: folded in 120 ms, nothing in between', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await open(tester);
    final top = gridBottom(tester);

    await tester.drag(find.byType(DaySection), const Offset(0, -30));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(folded(), isTrue);
    expect(gridBottom(tester), closeTo(top - distance(), 0.5));
    expect(find.byType(DayCell), findsNWidgets(DateTime.daysPerWeek));
  });

  testWidgets('on its side, the month never folds', (tester) async {
    await open(tester, size: const Size(844, 390));
    // The whole page scrolls there, the month with it.
    await tester.drag(find.byType(MonthGrid), const Offset(6, -200));
    await tester.pumpAndSettle();
    expect(folded(), isFalse);
    expect(
      find.byType(DayCell),
      findsNWidgets(
        monthDays(container.read(calendarSelectionProvider).month, 0).length,
      ),
    );
  });
}
