import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/add_person_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_people_repository.dart';
import 'form_harness.dart';

void main() {
  late FakePeopleRepository people;
  Object? saved;

  setUp(() {
    people = FakePeopleRepository();
    saved = 'not resolved';
  });

  Future<void> open(WidgetTester tester) => pumpFormHarness(
    tester,
    people: people,
    open: showAddPerson,
    result: (value) => saved = value,
  );

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledField, label),
    matching: find.byType(TextFormField),
  );

  testWidgets('a name is required', (tester) async {
    await open(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name.'), findsOneWidget);
    // Nothing was written; the book may have been reloaded.
    expect(people.calls, everyElement('list()'));
  });

  testWidgets('saves a prospect by default, reading the channel', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(field('Name'), 'Marie Dupont');
    await tester.enterText(
      field('Phone, email or Instagram'),
      'marie@example.com',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final person = saved! as Person;
    expect(person.name, 'Marie Dupont');
    expect(person.stage, Stage.prospect);
    expect(person.email, 'marie@example.com');
    expect(person.phone, isNull);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('the stage chips choose the stage', (tester) async {
    await open(tester);

    await tester.enterText(field('Name'), 'Lucas');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Customer'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect((saved! as Person).stage, Stage.customer);
  });

  testWidgets('a failure stays on the form with the input kept', (
    tester,
  ) async {
    await open(tester);
    people.failWith = PeopleFailure.network;

    await tester.enterText(field('Name'), 'Marie');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(FormError), findsOneWidget);
    expect(
      find.text('Couldn\'t save. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(find.text('Marie'), findsOneWidget);
    expect(saved, 'not resolved');
  });

  testWidgets('Save is disabled while saving', (tester) async {
    await open(tester);
    people.gate = Completer<void>();

    await tester.enterText(field('Name'), 'Marie');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    people.gate!.complete();
    await tester.pumpAndSettle();
    expect(people.calls.where((call) => call.startsWith('add')), hasLength(1));
  });

  testWidgets('someone new starts their stage\'s default workflow', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(field('Name'), 'Bruno Petit');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(people.store.values.single.place?.workflowId, 'samples');
  });

  testWidgets('the workflow switch is on, naming the stage\'s default', (
    tester,
  ) async {
    await open(tester);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    expect(find.text('Samples'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Customer'));
    await tester.pump();
    expect(find.text('New customer'), findsOneWidget);
  });

  testWidgets('switched off, someone new starts no workflow', (tester) async {
    await open(tester);
    await tester.enterText(field('Name'), 'Bruno Petit');
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(people.store.values.single.place, isNull);
  });
}
