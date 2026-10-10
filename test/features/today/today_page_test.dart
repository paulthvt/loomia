import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/event_page.dart';
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
import '../calendar/fake_event_repository.dart';
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
  List<Reminder> reminders = const [],
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
  reminders: reminders,
);

/// Due [inDays] from today: negative is late.
Reminder _reminder(String text, int inDays) => (
  id: 'r-$text',
  text: text,
  dueOn: addDays(today(), inDays),
  createdAt: DateTime.utc(2026),
);

const _markPriceList = 'Mark "Send her the price list" done';

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
    expect(find.text('Send a first message'), findsNWidgets(2));
    expect(find.text('Samples · 1 of 5'), findsNWidgets(2));
    // The accent chip only where the date says something: late.
    expect(find.text('2 days late'), findsOneWidget);
    expect(find.text('Due today'), findsNothing);
    // Who each person is, on their name line.
    expect(find.text('Prospect'), findsNWidgets(2));
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

  testWidgets('a ticked row slides out while the others stay', (tester) async {
    final people = FakePeopleRepository([
      _on('p1', 'Anna'),
      _on('p2', 'Bruno', ago: 2),
    ]);
    await pumpLoomia(tester, size: _phone, people: people);
    final left = tester.getTopLeft(find.text('Anna')).dx;

    await tester.tap(find.byTooltip(_markFirst).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.getTopLeft(find.text('Anna')).dx, lessThan(left));
    expect(tester.getTopLeft(find.text('Bruno')).dx, left);
    await tester.pumpAndSettle();
    expect(find.text('Anna'), findsNothing);
    expect(find.text('Bruno'), findsOneWidget);
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

  testWidgets('a reminder joins Priority beside the step; the person counts '
      'once', (tester) async {
    final people = FakePeopleRepository([
      _on(
        'p1',
        'Anna',
        reminders: [
          _reminder('Send her the price list', -2),
          _reminder('Next week', 7),
        ],
      ),
      _on('p2', 'Bruno', at: 2, reminders: [_reminder('Call back', 0)]),
    ]);
    await pumpLoomia(tester, size: _tallPhone, people: people);

    expect(find.text('2 people are worth a message today'), findsOneWidget);
    expect(find.text('Send her the price list'), findsOneWidget);
    expect(find.text('Call back'), findsOneWidget);
    expect(find.text('Reminder'), findsNWidgets(2));
    expect(find.textContaining('Next week'), findsNothing);
    // Late: the accent chip; due today: none.
    expect(find.text('2 days late'), findsOneWidget);
    expect(find.text('Due today'), findsNothing);
    final reminder = tester.getTopLeft(find.text('Send her the price list'));
    final step = tester.getTopLeft(find.text('Send a first message'));
    expect(reminder.dy, lessThan(step.dy));
  });

  testWidgets('ticking a reminder leaves the step tickable, and it goes', (
    tester,
  ) async {
    final people = FakePeopleRepository([
      _on('p1', 'Anna', reminders: [_reminder('Send her the price list', -2)]),
    ]);
    await pumpLoomia(tester, size: _phone, people: people);
    people.gate = Completer<void>();

    await tester.tap(find.byTooltip(_markPriceList));
    await tester.pump();
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byTooltip(_markFirst),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    people.gate!.complete();
    people.gate = null;
    await tester.pumpAndSettle();

    expect(
      people.calls,
      contains('completeReminder(r-Send her the price list)'),
    );
    expect(find.text('Send her the price list'), findsNothing);
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

    expect(find.text("You're offline"), findsOneWidget);
    people.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
  });

  testWidgets('a failed load that is not the connection does not blame it', (
    tester,
  ) async {
    final people = FakePeopleRepository()..failWith = PeopleFailure.unknown;
    await pumpLoomia(tester, size: _phone, people: people);

    expect(find.text("Couldn't load today."), findsOneWidget);
    expect(
      find.text('Something went wrong on our side. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.text("You're offline"), findsNothing);
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
    expect(find.text("You're offline"), findsNothing);
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

    expect(find.text("You're offline"), findsOneWidget);
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

  testWidgets('Mark who was there with people loading opens event page', (
    tester,
  ) async {
    final people = FakePeopleRepository()..failWith = PeopleFailure.network;
    final events = FakeEventRepository([
      CalendarEvent(
        id: 'workshop',
        title: 'Workshop',
        startsAt: addDays(today(), -1).add(const Duration(hours: 19)),
        attendees: const [(personId: 'p1', came: false)],
      ),
    ]);
    await pumpLoomia(tester, size: _tallPhone, people: people, events: events);

    expect(find.text('How did Workshop go?'), findsOneWidget);
    await tester.tap(find.text('Mark who was there'));
    await tester.pumpAndSettle();

    // Opens the event page, not the sheet.
    expect(find.byType(EventPage), findsOneWidget);
  });
}
