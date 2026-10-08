import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contact_list.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_people_repository.dart';
import '../fake_phone_contacts_repository.dart';

const _phone = Size(390, 844);

final _marie = Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: Stage.prospect,
  phone: '06 12 34 56 78',
  stageSince: DateTime.utc(2026, 3, 4),
);

Future<FakePeopleRepository> _openImport(
  WidgetTester tester,
  FakePhoneContactsRepository phone,
) async {
  final people = FakePeopleRepository([_marie]);
  final container = await pumpLoomia(
    tester,
    size: _phone,
    people: people,
    phoneContacts: phone,
  );
  container.read(routerProvider).go(Routes.importContacts);
  await tester.pumpAndSettle();
  return people;
}

SwitchListTile _start(WidgetTester tester) =>
    tester.widget<SwitchListTile>(find.byType(SwitchListTile));

void main() {
  testWidgets('imports the ticked contacts at the chosen stage', (
    tester,
  ) async {
    final people = await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Maman', phone: '+33 6 12 34 56 78', email: null),
        (name: 'Chloé Bernard', phone: '07 11 22 33 44', email: null),
        (name: 'Denis', phone: null, email: 'denis@example.com'),
      ]),
    );

    // Marie's number, saved under another name: flagged, not ticked.
    expect(find.text('Already in Loomia'), findsOneWidget);
    expect(find.text('0 selected'.toUpperCase()), findsOneWidget);
    final import = find.widgetWithText(FilledButton, 'Import');
    expect(tester.widget<FilledButton>(import).onPressed, isNull);

    await tester.tap(find.text('Chloé Bernard'));
    await tester.tap(find.text('Denis'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Customer'));
    await tester.pump();
    expect(find.text('2 selected'.toUpperCase()), findsOneWidget);

    await tester.tap(find.text('Import 2 people'));
    await tester.pumpAndSettle();

    expect(people.calls.last, 'addAll(Chloé Bernard, Denis)');
    final added = people.store.values.where((person) => person.id != 'p1');
    expect(added.map((person) => person.stage), everyElement(Stage.customer));
    expect(added.map((person) => person.email), contains('denis@example.com'));
    expect(find.byType(ContactList), findsOneWidget);
    expect(find.text('2 people imported'), findsOneWidget);
  });

  testWidgets('everyone imported can start their stage on an earlier day', (
    tester,
  ) async {
    final people = await _openImport(
      tester,
      FakePhoneContactsRepository([(name: 'Denis', phone: null, email: null)]),
    );

    await tester.tap(find.text('Denis'));
    await tester.tap(find.text('Since today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '03/04/2025');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Since Mar 4, 2025'), findsOneWidget);

    await tester.tap(find.text('Import one person'));
    await tester.pumpAndSettle();

    final denis = people.store.values.singleWhere((p) => p.name == 'Denis');
    expect(denis.stageSince, DateTime(2025, 3, 4));
    // Already in their stage: onboarding is behind them (#225).
    expect(denis.place, isNull);
  });

  testWidgets('since today starts the default workflow', (tester) async {
    final people = await _openImport(
      tester,
      FakePhoneContactsRepository([(name: 'Denis', phone: null, email: null)]),
    );

    await tester.tap(find.text('Denis'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Customer'));
    await tester.pump();
    expect(find.text('New customer'), findsOneWidget);
    expect(_start(tester).value, isTrue);

    await tester.tap(find.text('Import one person'));
    await tester.pumpAndSettle();

    final denis = people.store.values.singleWhere((p) => p.name == 'Denis');
    expect(denis.place?.workflowId, 'new-customer');
  });

  testWidgets('the workflow switch can be turned off', (tester) async {
    final people = await _openImport(
      tester,
      FakePhoneContactsRepository([(name: 'Denis', phone: null, email: null)]),
    );

    await tester.tap(find.text('Denis'));
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(_start(tester).value, isFalse);

    await tester.tap(find.text('Import one person'));
    await tester.pumpAndSettle();

    final denis = people.store.values.singleWhere((p) => p.name == 'Denis');
    expect(denis.place, isNull);
  });

  testWidgets('search narrows the list and keeps what is ticked', (
    tester,
  ) async {
    await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Chloé Bernard', phone: null, email: null),
        (name: 'Denis', phone: null, email: null),
      ]),
    );

    await tester.tap(find.text('Denis'));
    await tester.enterText(find.byType(TextField), 'chloe');
    await tester.pump();

    expect(find.text('Denis'), findsNothing);
    expect(find.text('Chloé Bernard'), findsOneWidget);
    expect(find.text('Import one person'), findsOneWidget);
  });

  testWidgets('refused access points to the settings', (tester) async {
    final phone = FakePhoneContactsRepository()..contacts = null;
    await _openImport(tester, phone);

    await tester.tap(find.text('Open settings'));

    expect(phone.settingsOpened, 1);
  });

  testWidgets('an empty address book says so', (tester) async {
    await _openImport(tester, FakePhoneContactsRepository());

    expect(find.text('No contacts on this phone'), findsOneWidget);
  });

  testWidgets('a failed read offers Try again', (tester) async {
    final phone = FakePhoneContactsRepository([
      (name: 'Denis', phone: null, email: null),
    ])..failWith = Exception('boom');
    await _openImport(tester, phone);
    expect(find.text("Couldn't read your contacts"), findsOneWidget);

    phone.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Denis'), findsOneWidget);
  });
}
