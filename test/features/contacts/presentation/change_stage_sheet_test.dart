import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/change_stage_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_people_repository.dart';
import 'form_harness.dart';

Person _sarah({Stage stage = Stage.prospect, ProspectStatus? status}) => Person(
  id: 'p1',
  name: 'Sarah Martin',
  stage: stage,
  prospectStatus: status,
  stageSince: DateTime.utc(2026, 3, 4),
);

void main() {
  late FakePeopleRepository people;

  Future<void> open(WidgetTester tester, Person person, Stage stage) {
    people = FakePeopleRepository([person]);
    return pumpFormHarness(
      tester,
      people: people,
      open: (context) => showChangeStage(context, [person], stage),
      result: (_) {},
    );
  }

  testWidgets('moves once confirmed, then closes', (tester) async {
    await open(tester, _sarah(), Stage.customer);

    expect(find.text('Sarah is now a customer'), findsOneWidget);
    expect(find.text('Everything you noted stays with them.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Move to customers'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('setStage(p1, customer)'));
    expect(people.store['p1']!.stage, Stage.customer);
    expect(find.text('Sarah is now a customer'), findsNothing);
  });

  testWidgets('a prospect with a status is told it goes', (tester) async {
    await open(tester, _sarah(status: ProspectStatus.thinking), Stage.team);

    expect(find.text('Sarah is now on your team'), findsOneWidget);
    expect(
      find.text(
        'Everything you noted stays with them. Where it stands is cleared.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('back to prospects has its own title', (tester) async {
    await open(tester, _sarah(stage: Stage.customer), Stage.prospect);

    expect(find.text('Sarah is a prospect again'), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, 'Move to prospects'),
      findsOneWidget,
    );
  });

  testWidgets('a failed move says so and stays open', (tester) async {
    await open(tester, _sarah(), Stage.customer);
    people.failWith = PeopleFailure.network;

    await tester.tap(find.widgetWithText(FilledButton, 'Move to customers'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('Sarah is now a customer'), findsOneWidget);
    expect(people.store['p1']!.stage, Stage.prospect);
  });

  testWidgets('Cancel leaves the stage alone', (tester) async {
    await open(tester, _sarah(), Stage.customer);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(people.calls, isNot(contains('setStage(p1, customer)')));
  });

  testWidgets('follows with the new stage\'s default', (tester) async {
    await open(tester, _sarah(), Stage.customer);

    expect(find.text('Suggested · 4 steps'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Move to customers'));
    await tester.pumpAndSettle();

    expect(people.store['p1']!.place?.workflowId, 'new-customer');
  });

  testWidgets('Nothing for now moves with no workflow', (tester) async {
    await open(tester, _sarah(), Stage.team);

    await tester.tap(find.text('Nothing for now'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Move to team'));
    await tester.pumpAndSettle();

    expect(people.store['p1']!.stage, Stage.team);
    expect(people.store['p1']!.place, isNull);
  });

  testWidgets('says the current workflow ends', (tester) async {
    await open(
      tester,
      Person(
        id: 'p1',
        name: 'Sarah Martin',
        stage: Stage.prospect,
        stageSince: DateTime.utc(2026, 3, 4),
        place: (
          workflowId: 'samples',
          atPosition: 2,
          lastTick: DateTime(2026, 9, 28),
        ),
        currentStepId: 'samples-2',
        dueOn: DateTime(2026, 9, 29),
      ),
      Stage.customer,
    );

    expect(
      find.text(
        'Everything you noted stays with them. The Samples workflow ends here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('several people move in one write', (tester) async {
    final nina = Person(
      id: 'p2',
      name: 'Nina Roux',
      stage: Stage.customer,
      stageSince: DateTime.utc(2026, 3, 4),
    );
    people = FakePeopleRepository([_sarah(), nina]);
    await pumpFormHarness(
      tester,
      people: people,
      open: (context) => showChangeStage(context, [_sarah(), nina], Stage.team),
      result: (_) {},
    );

    expect(find.text('These 2 are now on your team'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Move to team'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('setStage(p1, p2, team)'));
    expect(people.store['p2']!.stage, Stage.team);
  });
}
