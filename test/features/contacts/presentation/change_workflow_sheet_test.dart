import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/change_workflow_sheet.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:material_ui/material_ui.dart';

import '../../calendar/fake_event_repository.dart';
import '../../workflows/fake_event_workflow_repository.dart';
import '../../workflows/fake_workflow_repository.dart';
import '../fake_people_repository.dart';
import 'form_harness.dart';

Person _sarah({WorkflowPlace? place}) => Person(
  id: 'p1',
  name: 'Sarah Martin',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 3, 4),
  place: place,
);

void main() {
  late FakePeopleRepository people;

  Future<void> open(WidgetTester tester, Person person) {
    people = FakePeopleRepository([person]);
    return pumpFormHarness(
      tester,
      people: people,
      open: (context) => showChangeWorkflow(context, [person]),
      result: (_) {},
    );
  }

  group('a first step that is an event to plan (#413)', () {
    late FakeEventRepository events;

    Future<void> openBooking(WidgetTester tester, Person person) async {
      final workflows = FakeWorkflowRepository([
        Workflow(
          id: 'flow',
          stage: Stage.prospect,
          name: 'Samples',
          isDefault: true,
          steps: const [
            WorkflowStep(
              id: 'book',
              position: 1,
              label: 'Book the wellness check',
              days: 0,
              eventWorkflowId: 'wellness',
            ),
          ],
        ),
      ]);
      people = FakePeopleRepository([person])..workflows = workflows.store;
      events = FakeEventRepository();
      await pumpFormHarness(
        tester,
        people: people,
        workflows: workflows,
        eventWorkflows: FakeEventWorkflowRepository([
          EventWorkflow(
            id: 'wellness',
            name: 'Wellness check',
            isGroup: false,
            steps: const [],
          ),
        ]),
        events: events,
        open: (context) => showChangeWorkflow(context, [person]),
        result: (_) {},
      );
    }

    testWidgets('Plan it now: saved, then the event form', (tester) async {
      await openBooking(tester, _sarah());

      expect(find.widgetWithText(ChoiceChip, 'Plan it now'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(people.calls, contains('setPlace(p1, flow)'));
      expect(find.text('Wellness check — Sarah'), findsOneWidget);
    });

    testWidgets('not offered while what they follow is only shown', (
      tester,
    ) async {
      await openBooking(
        tester,
        _sarah(place: (workflowId: 'flow', atPosition: 1, lastTick: today())),
      );

      expect(find.widgetWithText(ChoiceChip, 'Plan it now'), findsNothing);
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(people.calls, isNot(contains('setPlace(p1, flow)')));
      expect(find.text('Wellness check — Sarah'), findsNothing);
    });
  });

  testWidgets('the current workflow is selected; Save changes it', (
    tester,
  ) async {
    await open(
      tester,
      _sarah(
        place: (
          workflowId: 'health',
          atPosition: 2,
          lastTick: DateTime(2026, 9, 28),
        ),
      ),
    );

    expect(find.text("Change Sarah's workflow"), findsOneWidget);
    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'health',
    );
    await tester.tap(find.text('Samples'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('setPlace(p1, samples)'));
    expect(find.text("Change Sarah's workflow"), findsNothing);
  });

  testWidgets('no workflow: the default is selected', (tester) async {
    await open(tester, _sarah());

    expect(
      tester
          .widget<RadioGroup<String>>(find.byType(RadioGroup<String>))
          .groupValue,
      'samples',
    );
  });

  testWidgets('a failure stays open and says why', (tester) async {
    await open(tester, _sarah());
    people.failWith = PeopleFailure.network;

    await tester.tap(find.text('Health professionals'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(FormError), findsOneWidget);
    expect(find.text("Change Sarah's workflow"), findsOneWidget);
  });

  testWidgets('Save without picking closes and leaves place unchanged', (
    tester,
  ) async {
    await open(
      tester,
      _sarah(
        place: (
          workflowId: 'samples',
          atPosition: 3,
          lastTick: DateTime(2026, 9, 27),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(people.calls, isNot(contains(startsWith('setPlace('))));
    expect(find.text("Change Sarah's workflow"), findsNothing);
  });

  testWidgets('several people: the default, saved for all', (tester) async {
    final nina = Person(
      id: 'p2',
      name: 'Nina Roux',
      stage: Stage.prospect,
      stageSince: DateTime.utc(2026, 3, 4),
      place: (
        workflowId: 'health',
        atPosition: 1,
        lastTick: DateTime(2026, 9, 28),
      ),
    );
    people = FakePeopleRepository([_sarah(), nina]);
    await pumpFormHarness(
      tester,
      people: people,
      open: (context) => showChangeWorkflow(context, [_sarah(), nina]),
      result: (_) {},
    );

    expect(find.text('Change the workflow for 2 people'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    // They followed different workflows: Save without picking still writes.
    expect(people.calls, contains('setPlace(p1, p2, samples)'));
  });
}
