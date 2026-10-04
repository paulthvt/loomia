import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goal_line.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

final _september = DateTime(2026, 9);

GoalsMonth _month(double volume, {double? target = 2800}) => (
  month: _september,
  plan: MonthPlan(month: _september, ownVolumeTarget: target),
  progress: Progress(
    ownVolume: volume,
    prospects: 0,
    customers: 0,
    teamMembers: 0,
    loyalty: 0,
  ),
  forecast: 0,
  plans: const [],
);

void main() {
  late int taps;

  Future<void> pump(
    WidgetTester tester,
    GoalsMonth month, {
    DateTime? day,
    BusinessModel model = BusinessModel.doterra,
  }) {
    taps = 0;
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GoalLine(
            month: month,
            today: day ?? DateTime(2026, 9, 19),
            model: model,
            onTap: () => taps++,
          ),
        ),
      ),
    );
  }

  testWidgets('behind: what is left and the days', (tester) async {
    await pump(tester, _month(1000));

    expect(find.text('1,800 PV to go · 11 days left'), findsOneWidget);
    await tester.tap(find.byType(GoalLine));
    expect(taps, 1);
  });

  testWidgets('on pace from day 4', (tester) async {
    await pump(tester, _month(1840));

    expect(find.text('On pace · 11 days left'), findsOneWidget);
  });

  testWidgets('the first 3 days: no pace, what is left', (tester) async {
    await pump(tester, _month(500), day: DateTime(2026, 9, 3));

    expect(find.text('2,300 PV to go · 27 days left'), findsOneWidget);
  });

  testWidgets('reached', (tester) async {
    await pump(tester, _month(2900));

    expect(
      find.text('You reached what you planned · 11 days left'),
      findsOneWidget,
    );
  });

  testWidgets('no target: nothing', (tester) async {
    await pump(tester, _month(1000, target: null));

    expect(find.byType(InkWell), findsNothing);
    expect(hasGoalLine(_month(1000, target: null)), isFalse);
  });

  testWidgets('Other: no unit', (tester) async {
    await pump(tester, _month(1000), model: BusinessModel.other);

    expect(find.text('1,800 to go · 11 days left'), findsOneWidget);
  });
}
