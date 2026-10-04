import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/today/domain/due.dart';
import 'package:loomia/features/today/presentation/today_page.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

final _september = DateTime(2026, 9);

final _samples = Workflow(
  id: 'samples',
  stage: Stage.prospect,
  name: 'Samples',
  isDefault: true,
  steps: const [
    WorkflowStep(id: 's1', position: 1, label: 'Send a first message', days: 0),
  ],
);

Due _due(String name, DateTime due) => (
  person: Person(
    id: name,
    name: name,
    stage: Stage.prospect,
    stageSince: DateTime.utc(2026, 9),
  ),
  step: OnStep(
    workflow: _samples,
    step: _samples.steps.first,
    index: 1,
    total: 1,
    due: due,
  ),
);

GoalsMonth _goals() => (
  month: _september,
  plan: MonthPlan(month: _september, ownVolumeTarget: 2800),
  progress: const Progress(
    ownVolume: 1000,
    prospects: 0,
    customers: 0,
    teamMembers: 0,
    loyalty: 0,
  ),
  forecast: 0,
  plans: [MonthPlan(month: _september, ownVolumeTarget: 2800)],
);

void main() {
  late int goalsTaps;
  late int ritualTaps;

  Future<void> pump(
    WidgetTester tester, {
    required DateTime now,
    List<Due>? due,
    GoalsMonth? goals,
  }) {
    goalsTaps = 0;
    ritualTaps = 0;
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TodayView(
          due: AsyncData(
            due ?? [_due('Anna', DateTime(now.year, now.month, now.day))],
          ),
          now: now,
          firstName: 'Pauline',
          onTick: (_) {},
          onOpen: (_) {},
          onRetry: () {},
          onRefresh: () async {},
          goals: goals,
          model: BusinessModel.doterra,
          onGoals: () => goalsTaps++,
          onRitual: () => ritualTaps++,
        ),
      ),
    );
  }

  testWidgets('a planned month: the line under the hero opens Goals', (
    tester,
  ) async {
    await pump(tester, now: DateTime(2026, 9, 19, 9), goals: _goals());

    final line = find.text('1,800 PV to go · 11 days left');
    expect(line, findsOneWidget);
    expect(
      tester.getTopLeft(line).dy,
      greaterThan(
        tester.getTopLeft(find.text('One person is worth a message today')).dy,
      ),
    );
    expect(find.textContaining('Close September'), findsNothing);
    await tester.tap(line);
    expect(goalsTaps, 1);
  });

  testWidgets('the window: the card opens the close flow', (tester) async {
    await pump(tester, now: DateTime(2026, 9, 29, 9), goals: _goals());

    expect(find.text('Close September, plan October'), findsOneWidget);
    await tester.tap(find.text('Start'));
    expect(ritualTaps, 1);
  });

  testWidgets('no one due: the line and the card still show', (tester) async {
    await pump(
      tester,
      now: DateTime(2026, 9, 29, 9),
      due: const [],
      goals: _goals(),
    );

    expect(find.text('You are up to date'), findsOneWidget);
    expect(find.text('1,800 PV to go · 1 day left'), findsOneWidget);
    expect(find.text('Close September, plan October'), findsOneWidget);
  });

  testWidgets('Goals not loaded: Today as before', (tester) async {
    await pump(tester, now: DateTime(2026, 9, 29, 9));

    expect(find.text('Anna'), findsOneWidget);
    expect(find.textContaining('to go'), findsNothing);
    expect(find.textContaining('Close September'), findsNothing);
  });
}
