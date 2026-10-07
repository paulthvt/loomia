import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contact_page.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goal_line.dart';
import 'package:loomia/features/today/presentation/today_page.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_harness.dart';
import '../contacts/fake_activity_repository.dart';
import '../contacts/fake_people_repository.dart';
import '../goals/fake_goals_repository.dart';
import '../workflows/fake_workflow_repository.dart';

const _phone = Size(390, 844);
// Tall enough that every row is built without scrolling; the cap follows the
// width alone.
const _tallPhone = Size(390, 1800);
const _tallDesktop = Size(1440, 1800);

const _markFirst = 'Mark "Send a first message" done';

/// On Samples at [at], last ticked [ago] days before today. Samples' steps
/// are due 0, 1, 4, 3 and 7 days after the last tick.
Person _on(
  String id,
  String name, {
  num at = 1,
  int ago = 0,
  DateTime? pausedAt,
}) => Person(
  id: id,
  name: name,
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 3, 4),
  place: (
    workflowId: 'samples',
    atPosition: at,
    lastTick: addDays(today(), -ago),
  ),
  pausedAt: pausedAt,
);

void main() {
  testWidgets('due today and late show, oldest first; not yet due and '
      'paused do not', (tester) async {
    final people = FakePeopleRepository([
      _on('p1', 'Anna'),
      _on('p2', 'Bruno', ago: 2),
      _on('p3', 'Chloé', at: 2),
      _on('p4', 'Dora', pausedAt: DateTime.utc(2026, 9)),
    ]);
    await pumpLoomia(tester, size: _phone, people: people);

    expect(find.text('2 people are worth a message today'), findsOneWidget);
    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
    expect(find.text('Chloé'), findsNothing);
    expect(find.text('Dora'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Bruno')).dy,
      lessThan(tester.getTopLeft(find.text('Anna')).dy),
    );
    expect(
      find.text('Send a first message · Samples, step 1 of 5'),
      findsNWidgets(2),
    );
    // The accent chip only where the date says something: late.
    expect(find.text('2 days late'), findsOneWidget);
    expect(find.text('Due today'), findsNothing);
  });

  testWidgets('a tick sends completeStep and the row leaves', (tester) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')]);
    await pumpLoomia(tester, size: _phone, people: people);

    await tester.tap(find.byTooltip(_markFirst));
    await tester.pumpAndSettle();

    expect(people.calls, contains('completeStep(p1, samples-1)'));
    // The next step is due tomorrow.
    expect(find.text('Anna'), findsNothing);
    expect(find.text('You are up to date'), findsOneWidget);
  });

  testWidgets('a tick in flight takes no second tap: one step, not two', (
    tester,
  ) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')]);
    await pumpLoomia(tester, size: _phone, people: people);
    people.gate = Completer<void>();

    await tester.tap(find.byTooltip(_markFirst));
    await tester.pump();
    await tester.tap(find.byTooltip(_markFirst));
    await tester.pump();
    people.gate!.complete();
    people.gate = null;
    await tester.pumpAndSettle();

    expect(
      people.calls.where((call) => call.startsWith('completeStep')),
      hasLength(1),
    );
  });

  testWidgets('a failed tick says so and keeps the row', (tester) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')]);
    await pumpLoomia(tester, size: _phone, people: people);
    people.failWith = PeopleFailure.network;

    await tester.tap(find.byTooltip(_markFirst));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('Anna'), findsOneWidget);
    expect(find.byTooltip(_markFirst), findsOneWidget);
  });

  testWidgets('five rows on a phone; And N more waiting shows the rest', (
    tester,
  ) async {
    final people = FakePeopleRepository([
      for (var i = 1; i <= 7; i++) _on('p$i', 'Person $i'),
    ]);
    await pumpLoomia(tester, size: _tallPhone, people: people);

    expect(find.byType(ActionItem), findsNWidgets(5));
    expect(find.text('7 people are worth a message today'), findsOneWidget);
    await tester.tap(find.text('And 2 more waiting'));
    await tester.pumpAndSettle();

    expect(find.byType(ActionItem), findsNWidgets(7));
    expect(find.textContaining('more waiting'), findsNothing);
  });

  testWidgets('six rows on a desktop', (tester) async {
    final people = FakePeopleRepository([
      for (var i = 1; i <= 7; i++) _on('p$i', 'Person $i'),
    ]);
    await pumpLoomia(tester, size: _tallDesktop, people: people);

    expect(find.byType(ActionItem), findsNWidgets(6));
    expect(find.text('And one more waiting'), findsOneWidget);
  });

  testWidgets('a spinner while loading, then the rows', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples())
      ..gate = Completer<void>();
    await pumpLoomia(
      tester,
      size: _phone,
      people: FakePeopleRepository([_on('p1', 'Anna')]),
      workflows: workflows,
      settle: false,
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    workflows.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
  });

  testWidgets('a failed load says so; Try again loads Today', (tester) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')])
      ..failWith = PeopleFailure.network;
    await pumpLoomia(tester, size: _phone, people: people);

    expect(find.text("Couldn't load today."), findsOneWidget);
    people.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
  });

  testWidgets('nobody due: up to date', (tester) async {
    await pumpLoomia(tester, size: _phone, people: FakePeopleRepository());

    expect(find.text('You are up to date'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the rows', (tester) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')]);
    await pumpLoomia(tester, size: _phone, people: people);
    people.failWith = PeopleFailure.network;

    await tester.fling(find.text('Anna'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
    expect(
      find.text("Couldn't refresh. You're seeing the last loaded list."),
      findsOneWidget,
    );
    expect(find.text("Couldn't load today."), findsNothing);
  });

  testWidgets('tapping a row opens the person', (tester) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')]);
    await pumpLoomia(tester, size: _phone, people: people);

    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactPage), findsOneWidget);
  });

  testWidgets('desktop refresh button reloads the book', (tester) async {
    final people = FakePeopleRepository([_on('p1', 'Anna')])
      ..failWith = PeopleFailure.network;
    await pumpLoomia(tester, size: _tallDesktop, people: people);

    expect(find.text("Couldn't load today."), findsOneWidget);
    people.failWith = null;
    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.byTooltip(l10n.contactsRefresh));
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
  });

  test('the greeting follows the clock, with the first name if there is '
      'one', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    String at(int hour, int minute, [String name = 'Pauline']) =>
        greeting(l10n, DateTime(2026, 9, 29, hour, minute), name);

    expect(at(0, 0), 'Good morning, Pauline');
    expect(at(11, 59), 'Good morning, Pauline');
    expect(at(12, 0), 'Good afternoon, Pauline');
    expect(at(17, 59), 'Good afternoon, Pauline');
    expect(at(18, 0), 'Good evening, Pauline');
    expect(at(9, 0, ''), 'Good morning');
    expect(at(9, 0, '  '), 'Good morning');
  });

  testWidgets('pull to refresh also brings back a failed goals load', (
    tester,
  ) async {
    final now = today();
    final goals = FakeGoalsRepository(
      plans: [
        MonthPlan(month: DateTime(now.year, now.month), ownVolumeTarget: 2800),
      ],
    )..failWith = PeopleFailure.network;
    await pumpLoomia(
      tester,
      size: _phone,
      people: FakePeopleRepository([_on('p1', 'Anna')]),
      goals: goals,
    );
    expect(find.byType(GoalLine), findsNothing);

    goals.failWith = null;
    await tester.fling(find.byType(ListView).first, const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.byType(GoalLine), findsOneWidget);
  });

  testWidgets('a new team member is worth a check-in; logging clears it', (
    tester,
  ) async {
    final activities = FakeActivityRepository();
    final people = FakePeopleRepository([
      Person(
        id: 'bea',
        name: 'Bea Martin',
        stage: Stage.team,
        stageSince: addDays(today(), -9).toUtc(),
      ),
    ])..activities = activities;
    await pumpLoomia(
      tester,
      size: _tallPhone,
      people: people,
      activities: activities,
    );
    expect(find.text('WORTH A CHECK-IN'), findsOneWidget);

    await tester.tap(find.byTooltip('Log something with Bea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Welcome call');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('WORTH A CHECK-IN'), findsNothing);
  });
}
