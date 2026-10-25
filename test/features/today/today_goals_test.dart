import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/team/domain/check_in.dart';
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

Due _due(String name, DateTime due) => DueStep(
  Person(
    id: name,
    name: name,
    stage: Stage.prospect,
    stageSince: DateTime.utc(2026, 9),
  ),
  OnStep(
    workflow: _samples,
    step: _samples.steps.first,
    index: 1,
    total: 1,
    due: due,
  ),
);

GoalsMonth _goals({bool drafted = false}) => (
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
  plans: [
    MonthPlan(month: _september, ownVolumeTarget: 2800),
    if (drafted) MonthPlan(month: DateTime(2026, 10), ownVolumeTarget: 2800),
  ],
);

void main() {
  late int goalsTaps;
  late int ritualTaps;

  Future<void> pump(
    WidgetTester tester, {
    required DateTime now,
    List<Due>? due,
    GoalsMonth? goals,
    Size size = const Size(390, 1400),
    List<CheckIn> checkIns = const [],
    int? done,
  }) {
    goalsTaps = 0;
    ritualTaps = 0;
    tester.view.physicalSize = size;
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
          tasks: const AsyncData([]),
          now: now,
          firstName: 'Pauline',
          done: done,
          onTick: (_) {},
          onOpen: (_) {},
          onRetry: () {},
          onRefresh: () async {},
          goals: goals,
          model: BusinessModel.doterra,
          onGoals: () => goalsTaps++,
          onRitual: () => ritualTaps++,
          checkIns: checkIns,
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

  testWidgets('the last days: the card opens the plan', (tester) async {
    await pump(tester, now: DateTime(2026, 9, 29, 9), goals: _goals());

    expect(find.text('Plan October'), findsOneWidget);
    await tester.tap(find.text('Start'));
    expect(ritualTaps, 1);
  });

  testWidgets('the last days, October drafted: one line opens it', (
    tester,
  ) async {
    await pump(
      tester,
      now: DateTime(2026, 9, 30, 9),
      goals: _goals(drafted: true),
    );

    final line = find.text(
      "October's plan is drafted. Change it before the 1st.",
    );
    expect(line, findsOneWidget);
    expect(find.text('Start'), findsNothing);
    expect(
      tester.getTopLeft(line).dy,
      greaterThan(tester.getTopLeft(find.textContaining('1,800 PV to go')).dy),
    );
    await tester.tap(line);
    expect(ritualTaps, 1);
  });

  testWidgets('the 1st: the card closes the month', (tester) async {
    await pump(
      tester,
      now: DateTime(2026, 10, 1, 9),
      goals: _goals(drafted: true),
    );

    expect(find.text('Close September, plan October'), findsOneWidget);
  });

  testWidgets('desktop, October drafted: the line on the side', (tester) async {
    await pump(
      tester,
      now: DateTime(2026, 9, 30, 9),
      goals: _goals(drafted: true),
      size: const Size(1440, 900),
    );

    final priority = tester.getTopLeft(find.text('PEOPLE')).dx;
    expect(
      tester
          .getTopLeft(
            find.text("October's plan is drafted. Change it before the 1st."),
          )
          .dx,
      greaterThan(priority + 600),
    );
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
    expect(find.text('Plan October'), findsOneWidget);
  });

  testWidgets('everything done: the line under the goal, above the card', (
    tester,
  ) async {
    await pump(
      tester,
      now: DateTime(2026, 9, 29, 9),
      due: const [],
      goals: _goals(),
      done: 2,
    );

    final body = tester.getTopLeft(find.textContaining('Nothing is waiting'));
    expect(
      body.dy,
      greaterThan(
        tester.getTopLeft(find.text('1,800 PV to go · 1 day left')).dy,
      ),
    );
    expect(body.dy, lessThan(tester.getTopLeft(find.text('Plan October')).dy));
  });

  testWidgets('Goals not loaded: Today as before', (tester) async {
    await pump(tester, now: DateTime(2026, 9, 29, 9));

    expect(find.text('Anna'), findsOneWidget);
    expect(find.textContaining('to go'), findsNothing);
    expect(find.textContaining('Close September'), findsNothing);
  });

  testWidgets('desktop: the volume card and the card on the side', (
    tester,
  ) async {
    await pump(
      tester,
      now: DateTime(2026, 9, 29, 9),
      goals: _goals(),
      size: const Size(1440, 900),
    );

    expect(find.text('1,800 PV to go · 1 day left'), findsNothing);
    expect(find.text('Own volume'), findsOneWidget);
    final priority = tester.getTopLeft(find.text('PEOPLE')).dx;
    expect(
      tester.getTopLeft(find.text('Own volume')).dx,
      greaterThan(priority + 600),
    );
    expect(
      tester.getTopLeft(find.text('Plan October')).dx,
      greaterThan(priority + 600),
    );
    await tester.tap(find.text('Own volume'));
    expect(goalsTaps, 1);
  });

  testWidgets('desktop, nothing for the side: main stays put', (tester) async {
    await pump(
      tester,
      now: DateTime(2026, 9, 15, 9),
      size: const Size(1440, 900),
    );

    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Own volume'), findsNothing);
  });

  testWidgets('desktop check-ins sit 12 apart, as on Team', (tester) async {
    CheckIn quiet(String name) => (
      person: Person(
        id: name,
        name: name,
        stage: Stage.team,
        stageSince: DateTime(2026, 5),
        lastContactOn: DateTime(2026, 9),
      ),
      reason: CheckInReason.quiet,
      since: DateTime(2026, 9),
      days: 28,
    );
    await pump(
      tester,
      now: DateTime(2026, 9, 29, 9),
      size: const Size(1440, 1200),
      checkIns: [quiet('Bruno'), quiet('Léa')],
    );

    final first = tester.getRect(
      find.ancestor(of: find.text('Bruno'), matching: find.byType(ActionItem)),
    );
    final second = tester.getRect(
      find.ancestor(of: find.text('Léa'), matching: find.byType(ActionItem)),
    );
    expect(second.top - first.bottom, 12);
  });

  testWidgets('mobile: the check-ins follow the day', (tester) async {
    await pump(
      tester,
      now: DateTime(2026, 9, 29, 9),
      size: const Size(390, 1600),
      checkIns: [_quiet('Bruno')],
    );

    expect(find.text('CATCH UP'), findsOneWidget);
    expect(find.text('1 person you could catch up with'), findsOneWidget);
  });

  group('catch up on one column', () {
    Future<void> folded(WidgetTester tester, {Size size = _phone}) => pump(
      tester,
      now: DateTime(2026, 9, 29, 9),
      size: size,
      checkIns: [_quiet('Bruno'), _quiet('Léa')],
    );

    testWidgets('folded under Priority; Show and Hide', (tester) async {
      await folded(tester);

      expect(find.text('2 people you could catch up with'), findsOneWidget);
      expect(find.text('Bruno'), findsNothing);

      await tester.tap(find.text('Show'));
      await tester.pump();
      expect(find.text('Bruno'), findsOneWidget);
      expect(find.text('Léa'), findsOneWidget);
      expect(find.text('2 people you could catch up with'), findsNothing);

      await tester.tap(find.text('Hide'));
      await tester.pump();
      expect(find.text('Bruno'), findsNothing);
    });

    testWidgets('the summary line opens it too, as one button', (tester) async {
      final semantics = tester.ensureSemantics();
      await folded(tester);

      expect(
        find.bySemanticsLabel('2 people you could catch up with'),
        findsOneWidget,
      );
      await tester.tap(find.text('2 people you could catch up with'));
      await tester.pump();
      expect(find.text('Bruno'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a tablet folds it too', (tester) async {
      await folded(tester, size: const Size(800, 1600));

      expect(find.text('Show'), findsOneWidget);
      expect(find.text('Bruno'), findsNothing);
    });

    testWidgets('nothing due: open', (tester) async {
      await pump(
        tester,
        now: DateTime(2026, 9, 29, 9),
        size: _phone,
        due: const [],
        checkIns: [_quiet('Bruno')],
      );

      expect(find.text('Bruno'), findsOneWidget);
      expect(find.text('Hide'), findsOneWidget);
      expect(find.text('1 person you could catch up with'), findsNothing);
    });

    testWidgets('desktop: the rows, no Show', (tester) async {
      await folded(tester, size: const Size(1440, 1200));

      expect(find.text('Bruno'), findsOneWidget);
      expect(find.text('Show'), findsNothing);
      expect(find.text('Hide'), findsNothing);
    });
  });
}

const _phone = Size(390, 1600);

CheckIn _quiet(String name) => (
  person: Person(
    id: name,
    name: name,
    stage: Stage.team,
    stageSince: DateTime(2026, 5),
    lastContactOn: DateTime(2026, 8, 20),
  ),
  reason: CheckInReason.quiet,
  since: DateTime(2026, 8, 20),
  days: 40,
);
