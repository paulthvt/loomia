import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/goals/presentation/goals_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_goals_repository.dart';

final _today = DateTime(2026, 9, 19);
final _september = DateTime(2026, 9);

GoalsMonth month({
  MonthPlan? plan,
  Progress progress = noProgress,
  int forecast = 0,
  List<MonthPlan> past = const [],
}) => (
  month: _september,
  plan: plan,
  progress: progress,
  forecast: forecast,
  plans: [?plan, ...past],
);

var plans = 0;
var retries = 0;
var orders = 0;
var rituals = 0;
var logs = 0;

/// [GoalsView] alone, on a fixed day, counting Plan and Try again taps.
Future<void> pumpGoals(
  WidgetTester tester,
  AsyncValue<GoalsMonth> value, {
  BusinessModel model = BusinessModel.doterra,
  DateTime? day,
}) {
  plans = 0;
  retries = 0;
  orders = 0;
  rituals = 0;
  logs = 0;
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GoalsView(
        month: value,
        today: day ?? _today,
        model: model,
        onPlan: () => plans++,
        onRetry: () => retries++,
        onLogOrder: () => logs++,
        onOrders: () => orders++,
        onRitual: () => rituals++,
        onRefresh: () async {},
      ),
    ),
  );
}

void main() {
  testWidgets('no plan: the question and Plan September', (tester) async {
    await pumpGoals(tester, AsyncData(month()));

    expect(find.text('11 DAYS LEFT IN SEPTEMBER'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('What are you aiming for this month?'), findsOneWidget);
    await tester.tap(find.text('Plan September'));
    expect(plans, 1);
  });

  testWidgets('loading: a spinner', (tester) async {
    await pumpGoals(tester, const AsyncLoading());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a failed load offers Try again', (tester) async {
    await pumpGoals(
      tester,
      const AsyncError(PeopleFailure.network, StackTrace.empty),
    );

    expect(find.text("Couldn't load your goals."), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  const progress = Progress(
    ownVolume: 1840,
    prospects: 5,
    customers: 4,
    teamMembers: 1,
    loyalty: 2,
  );
  final full = MonthPlan(
    month: _september,
    ownVolumeTarget: 2800,
    teamVolumeTarget: 6000,
    levelTarget: 'Elite',
    prospectsTarget: 8,
    customersTarget: 6,
    teamMembersTarget: 2,
    loyaltyTarget: 3,
  );

  testWidgets('the month against the plan, in dōTERRA words', (tester) async {
    await pumpGoals(
      tester,
      AsyncData(month(plan: full, progress: progress, forecast: 1)),
    );

    expect(find.text('1,840'), findsOneWidget);
    expect(find.text('of 2,800 PV'), findsOneWidget);
    // 1 840 in 19 of 30 days: about 2 905 by the end.
    expect(find.text('On pace'), findsOneWidget);
    expect(find.text('66% of what you planned'), findsOneWidget);
    expect(find.text('11 days left'), findsOneWidget);
    expect(find.text('NEW PROSPECTS'), findsOneWidget);
    expect(find.text('of 8 you aimed for'), findsOneWidget);
    expect(find.text('LRPS'), findsOneWidget);
    expect(find.text('of 3 · 1 more likely'), findsOneWidget);
    expect(find.text('Aiming for Elite · OV 6,000'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('At this pace you finish the month at about 2,905 PV.'),
      200,
    );

    await tester.scrollUntilVisible(find.text('Change the plan'), 200);
    await tester.tap(find.text('Change the plan'));
    expect(plans, 1);
  });

  testWidgets('the first 3 days: the numbers, no pace', (tester) async {
    await pumpGoals(
      tester,
      AsyncData(month(plan: full, progress: progress)),
      day: DateTime(2026, 9, 3),
    );

    expect(find.text('1,840'), findsOneWidget);
    expect(find.text('On pace'), findsNothing);
    expect(find.textContaining('At this pace'), findsNothing);
  });

  testWidgets('only some targets: counts alone, no declared row', (
    tester,
  ) async {
    await pumpGoals(
      tester,
      AsyncData(
        month(
          plan: MonthPlan(month: _september, prospectsTarget: 8),
          progress: progress,
        ),
      ),
    );

    expect(find.text('PV this month'), findsOneWidget);
    expect(find.byType(LoomiaProgressBar), findsNothing);
    expect(find.text('of 8 you aimed for'), findsOneWidget);
    expect(find.textContaining('you aimed for'), findsOneWidget);
    expect(find.textContaining('Aiming for'), findsNothing);
    expect(find.textContaining('At this pace'), findsNothing);
  });

  testWidgets('Other: neutral words', (tester) async {
    await pumpGoals(
      tester,
      AsyncData(month(plan: full, progress: progress)),
      model: BusinessModel.other,
    );

    expect(find.text('of 2,800'), findsOneWidget);
    expect(find.text('LOYALTY ORDERS'), findsOneWidget);
    expect(find.text('Aiming for Elite · Team volume 6,000'), findsOneWidget);
    expect(find.textContaining('PV'), findsNothing);
    expect(find.textContaining('OV'), findsNothing);
    expect(find.textContaining('LRP'), findsNothing);
  });

  testWidgets('past months: plan against result', (tester) async {
    await pumpGoals(
      tester,
      AsyncData(
        month(
          plan: full,
          progress: progress,
          past: [
            MonthPlan(
              month: DateTime(2026, 8),
              ownVolumeTarget: 2500,
              levelTarget: 'Elite',
              actual: const Progress(
                ownVolume: 2410,
                prospects: 0,
                customers: 0,
                teamMembers: 0,
                loyalty: 0,
              ),
              levelActual: 'Elite',
              closedAt: DateTime(2026, 9, 1),
            ),
            MonthPlan(
              month: DateTime(2026, 7),
              levelTarget: 'Elite',
              actual: const Progress(
                ownVolume: 2180,
                prospects: 0,
                customers: 0,
                teamMembers: 0,
                loyalty: 0,
              ),
              levelActual: 'Executive',
              closedAt: DateTime(2026, 8, 1),
            ),
          ],
        ),
      ),
    );

    await tester.scrollUntilVisible(find.text('2,180 PV · Executive'), 200);
    expect(find.text('PAST MONTHS'), findsOneWidget);
    expect(find.text('August 2026'), findsOneWidget);
    expect(find.text('2,410 of 2,500 PV · Elite reached'), findsOneWidget);
    expect(find.text('2,180 PV · Executive'), findsOneWidget);
  });

  testWidgets('the card opens the orders; the button logs one', (tester) async {
    await pumpGoals(tester, AsyncData(month(plan: full, progress: progress)));

    await tester.tap(find.text('Own volume'));
    expect(orders, 1);
    await tester.scrollUntilVisible(find.text('Log my own order'), 200);
    await tester.tap(find.text('Log my own order'));
    expect(logs, 1);
  });

  testWidgets('the last days: a card to close and plan', (tester) async {
    await pumpGoals(
      tester,
      AsyncData(month(plan: full, progress: progress)),
      day: DateTime(2026, 9, 29),
    );

    expect(find.text('Close September, plan October'), findsOneWidget);
    await tester.tap(find.text('Start'));
    expect(rituals, 1);
  });

  testWidgets('mid-month: no card', (tester) async {
    await pumpGoals(tester, AsyncData(month(plan: full, progress: progress)));

    expect(find.textContaining('Close September'), findsNothing);
  });

  testWidgets('closed: the plan no longer changes', (tester) async {
    await pumpGoals(
      tester,
      AsyncData(
        month(
          plan: MonthPlan(
            month: _september,
            ownVolumeTarget: 2800,
            actual: progress,
            closedAt: DateTime(2026, 9, 29),
          ),
          progress: progress,
        ),
      ),
      day: DateTime(2026, 9, 29),
    );

    expect(find.text('Change the plan'), findsNothing);
    // Closed, October not planned yet: the card offers October alone.
    expect(find.text('Plan October'), findsOneWidget);
  });
}
