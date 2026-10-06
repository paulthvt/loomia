import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/change_workflow_sheet.dart';
import 'package:material_ui/material_ui.dart';

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
