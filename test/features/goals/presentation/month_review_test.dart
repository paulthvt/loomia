import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/month_review.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final september = DateTime(2026, 9);
  const progress = Progress(
    ownVolume: 2850,
    prospects: 7,
    customers: 6,
    teamMembers: 1,
    loyalty: 2,
  );
  late int next;

  Future<void> show(WidgetTester tester, MonthPlan closed) async {
    next = 0;
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MonthReview(
            closed: closed,
            next: DateTime(2026, 10),
            model: BusinessModel.doterra,
            onNext: () => next++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('every goal reached: praise and the ring', (tester) async {
    await show(
      tester,
      MonthPlan(
        month: september,
        ownVolumeTarget: 2800,
        customersTarget: 6,
        levelTarget: 'Elite',
        levelActual: 'Premier',
        actual: progress,
      ),
    );

    expect(find.text('STEP 2 OF 3'), findsOneWidget);
    expect(find.text('Bravo, you reached your goals!'), findsOneWidget);
    expect(find.textContaining('You can be proud of yourself'), findsOneWidget);
    expect(find.byType(ReachedRing), findsOneWidget);
    expect(find.text('You reached'), findsOneWidget);
    expect(find.text('On its way'), findsNothing);
    expect(find.text('2,850 of 2,800 PV'), findsOneWidget);
    expect(find.text('Premier'), findsOneWidget);
    expect(find.bySemanticsLabel('Reached'), findsNWidgets(3));

    await tester.tap(find.text('Plan October'));
    expect(next, 1);
  });

  testWidgets('some reached: those praised, the rest on its way', (
    tester,
  ) async {
    await show(
      tester,
      MonthPlan(
        month: september,
        ownVolumeTarget: 3000,
        customersTarget: 6,
        teamMembersTarget: 1,
        levelTarget: 'Elite',
        levelActual: 'Executive',
        actual: progress,
      ),
    );

    expect(find.text('Well done on September'), findsOneWidget);
    expect(
      find.textContaining('You reached 2 of your 4 goals'),
      findsOneWidget,
    );
    expect(find.byType(ReachedRing), findsNothing);
    expect(find.text('You reached'), findsOneWidget);
    expect(find.text('On its way'), findsOneWidget);
    expect(find.text('Executive, aiming for Elite'), findsOneWidget);
  });

  testWidgets('none reached: what was built, turned to next month', (
    tester,
  ) async {
    await show(
      tester,
      MonthPlan(
        month: september,
        prospectsTarget: 8,
        teamVolumeTarget: 6000,
        actual: progress,
      ),
    );

    expect(find.text('September is behind you'), findsOneWidget);
    expect(find.textContaining('it carries into October'), findsOneWidget);
    expect(find.byType(ReachedRing), findsNothing);
    expect(find.text('What you built'), findsOneWidget);
    expect(find.text('You reached'), findsNothing);
    expect(find.text('7 of 8'), findsOneWidget);
    expect(find.text('Not filled in'), findsOneWidget);
    expect(find.bySemanticsLabel('Reached'), findsNothing);
  });

  testWidgets('reduce motion: the ring shows closed without drawing', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await show(
      tester,
      MonthPlan(month: september, customersTarget: 6, actual: progress),
    );
    expect(find.byType(ReachedRing), findsOneWidget);
  });
}
