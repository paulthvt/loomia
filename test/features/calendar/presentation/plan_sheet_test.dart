import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../contacts/fake_people_repository.dart';
import '../../workflows/fake_event_workflow_repository.dart';
import '../../workflows/fake_workflow_repository.dart';
import '../fake_event_repository.dart';

/// Plan from a contact's NEXT STEP card (#315), on an event step of [type].
void main() {
  final unboxing = EventWorkflow(
    id: 'unboxing',
    name: 'Unboxing call',
    isGroup: false,
    steps: const [],
  );
  final workshop = EventWorkflow(
    id: 'workshop',
    name: 'Workshop',
    steps: const [],
  );

  Workflow flow(String type) => Workflow(
    id: 'flow',
    stage: Stage.customer,
    name: 'New customer',
    isDefault: true,
    steps: [
      WorkflowStep(
        id: 'book',
        position: 1,
        label: 'Book it',
        days: 0,
        eventWorkflowId: type,
      ),
    ],
  );

  final julie = Person(
    id: 'p1',
    name: 'Julie Martin',
    stage: Stage.customer,
    stageSince: DateTime.utc(2026, 9),
    place: (workflowId: 'flow', atPosition: 1, lastTick: today()),
  );

  Future<({FakeEventRepository events, FakePeopleRepository people})> open(
    WidgetTester tester,
    String type, {
    List<CalendarEvent> calendar = const [],
  }) async {
    final workflows = FakeWorkflowRepository([flow(type)]);
    final people = FakePeopleRepository([julie])..workflows = workflows.store;
    final events = FakeEventRepository(calendar)
      ..isGroup = (id) => id == 'workshop';
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1400),
      people: people,
      workflows: workflows,
      eventWorkflows: FakeEventWorkflowRepository([unboxing, workshop]),
      events: events,
    );
    container.read(routerProvider).go(Routes.contactLocation('p1'));
    await tester.pumpAndSettle();
    return (events: events, people: people);
  }

  testWidgets('one person: the form, prefilled a week out at 19:00; saving '
      'creates the event with them', (tester) async {
    final (:events, :people) = await open(tester, 'unboxing');
    final listed = people.calls.where((c) => c == 'list()').length;

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Unboxing call — Julie'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Unboxing call'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Unboxing call'))
          .selected,
      isTrue,
    );
    expect(find.text('7:00 PM'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final added = events.store.single;
    expect(added.title, 'Unboxing call — Julie');
    expect(added.eventWorkflowId, 'unboxing');
    expect(added.day, addDays(today(), 7));
    expect(events.calls, contains('invite(${added.id}:p1)'));
    expect(added.attendees.single.going, isTrue);
    expect(
      people.calls.where((c) => c == 'list()').length,
      greaterThan(listed),
    );
  });

  testWidgets('several people: an upcoming one of the type, invited', (
    tester,
  ) async {
    final soon = DateTime.now().add(const Duration(days: 5));
    final (:events, people: _) = await open(
      tester,
      'workshop',
      calendar: [
        CalendarEvent(
          id: 'e1',
          title: 'Huiles et sommeil',
          startsAt: soon,
          eventWorkflowId: 'workshop',
        ),
        CalendarEvent(
          id: 'e0',
          title: 'Past workshop',
          startsAt: DateTime.now().subtract(const Duration(days: 2)),
          eventWorkflowId: 'workshop',
        ),
      ],
    );

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Invite Julie to Workshop'), findsOneWidget);
    expect(find.textContaining('Huiles et sommeil ·'), findsOneWidget);
    expect(find.textContaining('Past workshop'), findsNothing);
    expect(find.text('New Workshop'), findsOneWidget);

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();

    expect(events.calls, contains('invite(e1:p1)'));
    final attendee = events.store
        .firstWhere((e) => e.id == 'e1')
        .attendees
        .single;
    expect(attendee.going, isFalse);
  });

  testWidgets('a failed invite says so', (tester) async {
    final soon = DateTime.now().add(const Duration(days: 5));
    final (:events, people: _) = await open(
      tester,
      'workshop',
      calendar: [
        CalendarEvent(
          id: 'e1',
          title: 'Huiles et sommeil',
          startsAt: soon,
          eventWorkflowId: 'workshop',
        ),
      ],
    );
    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    events.failWith = PeopleFailure.network;

    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('Later: due on the day picked', (tester) async {
    final (events: _, :people) = await open(tester, 'unboxing');

    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    final day = addDays(today(), 3);
    expect(
      people.calls,
      contains(
        'postponeStep(p1:book:${day.year}-${'${day.month}'.padLeft(2, '0')}-'
        '${'${day.day}'.padLeft(2, '0')})',
      ),
    );
    expect(people.store['p1'], isNotNull);
  });
}
