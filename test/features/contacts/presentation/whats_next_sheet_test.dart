import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/whats_next_sheet.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:material_ui/material_ui.dart';

import '../../workflows/fake_workflow_repository.dart';
import '../fake_people_repository.dart';
import 'form_harness.dart';

Workflow _with(Workflow workflow, List<String> next) => Workflow(
  id: workflow.id,
  stage: workflow.stage,
  name: workflow.name,
  isDefault: workflow.isDefault,
  steps: workflow.steps,
  next: next,
);

void main() {
  final samples = FakeWorkflowRepository.samples();
  final prospects = [
    _with(samples[0], ['health']),
    samples[1],
    ...samples.skip(2),
  ];

  Person done(String id, Stage stage, String workflowId) => Person(
    id: id,
    name: id == 'p1' ? 'Sophie Bernard' : 'Julie Martin',
    stage: stage,
    stageSince: DateTime.utc(2026, 9),
    place: (
      workflowId: workflowId,
      atPosition: 1e9,
      lastTick: DateTime(2026, 10, 1),
    ),
  );

  Future<FakePeopleRepository> open(
    WidgetTester tester,
    Person person,
    Workflow workflow,
  ) async {
    final people = FakePeopleRepository([person])..workflows = prospects;
    await pumpFormHarness(
      tester,
      people: people,
      workflows: FakeWorkflowRepository(prospects),
      open: (context) => showWhatsNext(context, person, workflow, prospects),
      result: (_) {},
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return people;
  }

  testWidgets('a prospect: the workflows offered and Nothing for now; Done '
      'starts the one picked', (tester) async {
    final people = await open(
      tester,
      done('p1', Stage.prospect, 'samples'),
      prospects[0],
    );

    expect(find.text("What's next for Sophie?"), findsOneWidget);
    expect(find.text('Samples is done'), findsOneWidget);
    expect(find.text('Health professionals'), findsOneWidget);
    expect(find.text('Nothing for now'), findsOneWidget);
    expect(find.textContaining('LRP'), findsNothing);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('setPlace(p1, health)'));
    expect(find.text("What's next for Sophie?"), findsNothing);
  });

  testWidgets('Nothing for now: no workflow, and the question goes', (
    tester,
  ) async {
    final people = await open(
      tester,
      done('p1', Stage.prospect, 'samples'),
      prospects[0],
    );

    await tester.tap(find.text('Nothing for now'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('setPlace(p1, none)'));
  });

  testWidgets('a customer without an LRP: asked first; Yes starts it', (
    tester,
  ) async {
    final people = await open(
      tester,
      done('p2', Stage.customer, 'new-customer'),
      samples[2],
    );

    expect(find.text('Did Julie start an LRP?'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Done');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(find.text('Yes'));
    await tester.pumpAndSettle();
    expect(find.text('Loyalty orders renews on day'), findsOneWidget);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(people.calls, contains('setLoyalty(p2)'));
    // Nothing offered after New customer: the LRP was all there was to ask.
    expect(people.calls.where((c) => c.startsWith('setPlace')), isEmpty);
  });

  testWidgets('a failure says so and keeps the sheet', (tester) async {
    final people = await open(
      tester,
      done('p1', Stage.prospect, 'samples'),
      prospects[0],
    );
    people.failWith = PeopleFailure.network;

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text("What's next for Sophie?"), findsOneWidget);
    expect(find.textContaining('connection'), findsOneWidget);
  });
}
