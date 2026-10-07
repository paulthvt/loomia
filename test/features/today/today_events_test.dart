import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/today/domain/due.dart';
import 'package:loomia/features/today/domain/today_events.dart';
import 'package:loomia/features/today/presentation/today_page.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_harness.dart';
import '../calendar/fake_event_repository.dart';

final _online = CalendarEvent(
  id: 'e1',
  title: 'Essential oils for sleep',
  startsAt: DateTime(2026, 10, 8, 19),
  endsAt: DateTime(2026, 10, 8, 21),
  link: 'https://meet.google.com/abc',
  attendees: const [(personId: 'p1', came: false)],
);

final _training = CalendarEvent(
  id: 'e2',
  title: 'New member training',
  startsAt: DateTime(2026, 10, 6, 14),
  attendees: const [(personId: 'p1', came: false)],
);

const _remind = EventWorkflowStep(
  id: 'remind',
  label: "Remind everyone it's tomorrow",
  days: -1,
);

final TodayEvents _events = (
  today: [_online],
  toMark: [_training],
  steps: [(event: _online, step: _remind, due: DateTime(2026, 10, 7))],
);

void main() {
  late List<CalendarEvent> openedEvents;
  late List<CalendarEvent> markedEvents;
  late List<DueEventStep> tickedSteps;
  late List<Uri> joinedLinks;

  Future<void> pump(
    WidgetTester tester, {
    required DateTime now,
    TodayEvents events = noTodayEvents,
    AsyncValue<List<Due>> due = const AsyncData([]),
  }) {
    openedEvents = [];
    markedEvents = [];
    tickedSteps = [];
    joinedLinks = [];
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TodayView(
          due: due,
          now: now,
          firstName: 'Pauline',
          onTick: (_) {},
          onOpen: (_) {},
          onRetry: () {},
          onRefresh: () async {},
          events: events,
          onOpenEvent: (event) => openedEvents.add(event),
          onMarkDone: (event) => markedEvents.add(event),
          onTickStep: (step) => tickedSteps.add(step),
          onJoin: (link) => joinedLinks.add(link),
        ),
      ),
    );
  }

  testWidgets('the Events section sits above Priority', (tester) async {
    final workflow = Workflow(
      id: 'w1',
      stage: Stage.prospect,
      name: 'Test',
      isDefault: true,
      steps: const [
        WorkflowStep(id: 's1', position: 1, label: 'Test step', days: 0),
      ],
    );
    await pump(
      tester,
      now: DateTime(2026, 10, 8, 18, 50),
      events: _events,
      due: AsyncData([
        (
          person: Person(
            id: 'p1',
            name: 'Anna',
            stage: Stage.prospect,
            stageSince: DateTime(2026, 10),
          ),
          step: OnStep(
            workflow: workflow,
            step: workflow.steps.first,
            index: 1,
            total: 1,
            due: DateTime(2026, 10, 8),
          ),
        ),
      ]),
    );

    final eventsHeader = find.text('EVENTS');
    final priorityHeader = find.text('PRIORITY');
    expect(eventsHeader, findsOneWidget);
    expect(priorityHeader, findsOneWidget);
    expect(
      tester.getTopLeft(eventsHeader).dy,
      lessThan(tester.getTopLeft(priorityHeader).dy),
    );

    expect(find.text('Essential oils for sleep'), findsOneWidget);
    expect(find.text('7:00 PM'), findsOneWidget);

    expect(find.text('How did New member training go?'), findsOneWidget);
    expect(find.text('Mark who was there'), findsOneWidget);

    expect(find.text("Remind everyone it's tomorrow"), findsOneWidget);
    expect(
      find.text('Essential oils for sleep · 1 day before'),
      findsOneWidget,
    );
  });

  testWidgets('each row does what it says', (tester) async {
    await pump(tester, now: DateTime(2026, 10, 8, 18, 50), events: _events);

    await tester.tap(find.text('Essential oils for sleep'));
    await tester.pump();
    expect(openedEvents, [_online]);

    await tester.tap(find.text('Join'));
    await tester.pump();
    expect(joinedLinks, [Uri.parse('https://meet.google.com/abc')]);

    await tester.tap(find.text('Mark who was there'));
    await tester.pump();
    expect(markedEvents, [_training]);

    final ring = find.byTooltip('Mark "Remind everyone it\'s tomorrow" done');
    expect(ring, findsOneWidget);
    await tester.tap(ring);
    await tester.pump();
    expect(tickedSteps.length, 1);
    expect(tickedSteps.first.step, _remind);
  });

  testWidgets('Join waits for 15 minutes before', (tester) async {
    await pump(tester, now: DateTime(2026, 10, 8, 9), events: _events);

    expect(find.text('Essential oils for sleep'), findsOneWidget);
    expect(find.text('Join'), findsNothing);
  });

  testWidgets('nothing to show, no section', (tester) async {
    await pump(
      tester,
      now: DateTime(2026, 10, 8, 18, 50),
      events: noTodayEvents,
    );

    expect(find.text('EVENTS'), findsNothing);
  });

  testWidgets('up to date on people, the events still show', (tester) async {
    await pump(
      tester,
      now: DateTime(2026, 10, 8, 18, 50),
      events: _events,
      due: const AsyncData([]),
    );

    expect(find.text('EVENTS'), findsOneWidget);
    expect(find.text('You are up to date'), findsOneWidget);
  });

  testWidgets('the headline still counts people only', (tester) async {
    final workflow = Workflow(
      id: 'w1',
      stage: Stage.prospect,
      name: 'Test',
      isDefault: true,
      steps: const [
        WorkflowStep(id: 's1', position: 1, label: 'Test step', days: 0),
      ],
    );
    await pump(
      tester,
      now: DateTime(2026, 10, 8, 18, 50),
      events: _events,
      due: AsyncData([
        (
          person: Person(
            id: 'p1',
            name: 'Anna',
            stage: Stage.prospect,
            stageSince: DateTime(2026, 10),
          ),
          step: OnStep(
            workflow: workflow,
            step: workflow.steps.first,
            index: 1,
            total: 1,
            due: DateTime(2026, 10, 8),
          ),
        ),
      ]),
    );

    expect(find.text('One person is worth a message today'), findsOneWidget);
    expect(find.text('EVENTS'), findsOneWidget);
  });

  testWidgets('in the app: tick a step and the network error', (tester) async {
    final events = FakeEventRepository();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1, 19);

    events.store.addAll([
      CalendarEvent(
        id: 'e1',
        title: 'Workshop',
        startsAt: tomorrow,
        eventWorkflowId: 'workshop',
      ),
      CalendarEvent(
        id: 'e2',
        title: 'Second workshop',
        startsAt: tomorrow,
        eventWorkflowId: 'workshop',
      ),
    ]);

    await pumpLoomia(tester, size: const Size(390, 1400), events: events);

    final rings = find.byTooltip('Mark "Remind everyone it\'s tomorrow" done');
    expect(rings, findsNWidgets(2));

    await tester.tap(rings.first);
    await tester.pumpAndSettle();

    expect(
      events.calls.where((c) => c.startsWith('tick(e1:remind)')).length,
      1,
    );
    expect(
      find.byTooltip('Mark "Remind everyone it\'s tomorrow" done'),
      findsOneWidget,
    );

    events.failWith = PeopleFailure.network;
    await tester.tap(
      find.byTooltip('Mark "Remind everyone it\'s tomorrow" done'),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Couldn\'t save. Check your connection and try again.'),
      findsOneWidget,
    );
  });
}
