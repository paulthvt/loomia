import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contact_list.dart';
import 'package:loomia/features/contacts/presentation/contact_page.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../../core/photos/fake_photo_repository.dart';
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
  // As in the app: pushed above the Contacts list, never reached on its own.
  final router = container.read(routerProvider)..go(Routes.contacts);
  await tester.pumpAndSettle();
  unawaited(router.push(Routes.importContacts));
  await tester.pumpAndSettle();
  return people;
}

/// Taps Import on the list: the sheet with the stage, the day and the
/// workflow opens.
Future<void> _openSheet(WidgetTester tester, String action) async {
  await tester.tap(find.widgetWithText(FilledButton, action));
  await tester.pumpAndSettle();
  expect(find.byType(LoomiaDialog), findsOneWidget);
}

/// Confirms the sheet.
Future<void> _confirm(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(LoomiaDialog),
      matching: find.widgetWithText(FilledButton, 'Import'),
    ),
  );
  await tester.pumpAndSettle();
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
        (name: 'Maman', phone: '+33 6 12 34 56 78', email: null, photo: null),
        (
          name: 'Chloé Bernard',
          phone: '07 11 22 33 44',
          email: null,
          photo: null,
        ),
        (name: 'Denis', phone: null, email: 'denis@example.com', photo: null),
      ]),
    );

    // Marie's number, saved under another name: flagged, not ticked.
    expect(find.text('Already in Loomia'), findsOneWidget);
    expect(find.text('0 selected'.toUpperCase()), findsOneWidget);
    final import = find.widgetWithText(FilledButton, 'Import');
    expect(tester.widget<FilledButton>(import).onPressed, isNull);
    // The settings wait for the second step.
    expect(find.byType(ChoiceChip), findsNothing);

    await tester.tap(find.text('Chloé Bernard'));
    await tester.tap(find.text('Denis'));
    await tester.pump();
    expect(find.text('2 selected'.toUpperCase()), findsOneWidget);

    await _openSheet(tester, 'Import 2 people');
    expect(find.text('Add 2 people as'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Customer'));
    await tester.pump();
    await _confirm(tester);

    expect(people.calls.last, 'addAll(Chloé Bernard, Denis)');
    final added = people.store.values.where((person) => person.id != 'p1');
    expect(added.map((person) => person.stage), everyElement(Stage.customer));
    expect(added.map((person) => person.email), contains('denis@example.com'));
    expect(find.byType(ContactList), findsOneWidget);
    expect(find.text('2 people imported'), findsOneWidget);
  });

  testWidgets('Cancel in the sheet imports nothing and keeps the ticks', (
    tester,
  ) async {
    final people = await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Denis', phone: null, email: null, photo: null),
      ]),
    );

    await tester.tap(find.text('Denis'));
    await tester.pump();
    await _openSheet(tester, 'Import one person');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(LoomiaDialog), findsNothing);
    expect(people.calls.where((call) => call.startsWith('addAll')), isEmpty);
    expect(find.text('1 selected'.toUpperCase()), findsOneWidget);
  });

  testWidgets('someone on a known line opens them instead of being ticked', (
    tester,
  ) async {
    await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Denis', phone: null, email: null, photo: null),
        (name: 'Maman', phone: '+33 6 12 34 56 78', email: null, photo: null),
      ]),
    );
    final maman = find.widgetWithText(ContactRow, 'Maman');
    expect(
      find.descendant(of: maman, matching: find.byType(Checkbox)),
      findsNothing,
    );

    await tester.tap(find.text('Denis'));
    await tester.tap(maman);
    await tester.pumpAndSettle();
    expect(find.byType(ContactPage), findsOneWidget);
    expect(find.text('Marie Dupont'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 selected'.toUpperCase()), findsOneWidget);
  });

  testWidgets('a namesake without a number is flagged and can be ticked', (
    tester,
  ) async {
    await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'marie dupont', phone: null, email: null, photo: null),
      ]),
    );

    expect(find.text('Same name as someone in Loomia'), findsOneWidget);
    await tester.tap(find.text('marie dupont'));
    await tester.pump();
    expect(find.text('Import one person'), findsOneWidget);
  });

  testWidgets('a contact with a photo shows it, one without its initials', (
    tester,
  ) async {
    await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Chloé Bernard', phone: null, email: null, photo: jpegBytes),
        (name: 'Denis', phone: null, email: null, photo: null),
      ]),
    );

    LoomiaAvatar avatar(String name) => tester.widget<LoomiaAvatar>(
      find.descendant(
        of: find.widgetWithText(ContactRow, name),
        matching: find.byType(LoomiaAvatar),
      ),
    );
    expect(avatar('Chloé Bernard').photo, isA<MemoryImage>());
    expect(avatar('Denis').photo, isNull);
  });

  testWidgets('the photos of the people imported follow them', (tester) async {
    final people = await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Chloé Bernard', phone: null, email: null, photo: jpegBytes),
        (name: 'Denis', phone: null, email: null, photo: null),
      ]),
    );

    await tester.tap(find.text('Chloé Bernard'));
    await tester.tap(find.text('Denis'));
    await tester.pump();
    await _openSheet(tester, 'Import 2 people');
    await _confirm(tester);

    final chloe = people.store.values.singleWhere(
      (person) => person.name == 'Chloé Bernard',
    );
    expect(people.calls.where((call) => call.startsWith('setPhoto')), [
      'setPhoto(${chloe.id}, u1/new)',
    ]);
    expect(find.text('2 people imported'), findsOneWidget);
  });

  testWidgets('everyone imported can start their stage on an earlier day', (
    tester,
  ) async {
    final people = await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Denis', phone: null, email: null, photo: null),
      ]),
    );

    await tester.tap(find.text('Denis'));
    await tester.pump();
    await _openSheet(tester, 'Import one person');
    await tester.tap(find.text('Since today'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '03/04/2025');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Since Mar 4, 2025'), findsOneWidget);

    await _confirm(tester);

    final denis = people.store.values.singleWhere((p) => p.name == 'Denis');
    expect(denis.stageSince, DateTime(2025, 3, 4));
    // Already in their stage: onboarding is behind them (#225).
    expect(denis.place, isNull);
  });

  testWidgets('since today starts the default workflow', (tester) async {
    final people = await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Denis', phone: null, email: null, photo: null),
      ]),
    );

    await tester.tap(find.text('Denis'));
    await tester.pump();
    await _openSheet(tester, 'Import one person');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Customer'));
    await tester.pump();
    expect(find.text('New customer'), findsOneWidget);
    expect(_start(tester).value, isTrue);

    await _confirm(tester);

    final denis = people.store.values.singleWhere((p) => p.name == 'Denis');
    expect(denis.place?.workflowId, 'new-customer');
  });

  testWidgets('the workflow switch can be turned off', (tester) async {
    final people = await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Denis', phone: null, email: null, photo: null),
      ]),
    );

    await tester.tap(find.text('Denis'));
    await tester.pump();
    await _openSheet(tester, 'Import one person');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    expect(_start(tester).value, isFalse);

    await _confirm(tester);

    final denis = people.store.values.singleWhere((p) => p.name == 'Denis');
    expect(denis.place, isNull);
  });

  testWidgets('search narrows the list and keeps what is ticked', (
    tester,
  ) async {
    await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Chloé Bernard', phone: null, email: null, photo: null),
        (name: 'Denis', phone: null, email: null, photo: null),
      ]),
    );

    await tester.tap(find.text('Denis'));
    await tester.enterText(find.byType(TextField), 'chloe');
    await tester.pump();

    expect(find.text('Denis'), findsNothing);
    expect(find.text('Chloé Bernard'), findsOneWidget);
    expect(find.text('Import one person'), findsOneWidget);
  });

  testWidgets('with the keyboard up the list keeps the room', (tester) async {
    await _openImport(
      tester,
      FakePhoneContactsRepository([
        (name: 'Chloé Bernard', phone: null, email: null, photo: null),
        (name: 'Denis', phone: null, email: null, photo: null),
      ]),
    );
    await tester.tap(find.text('Denis'));
    await tester.enterText(find.byType(TextField), 'chlo');
    // Roughly a phone keyboard with its suggestion bar.
    tester.view.viewInsets = const FakeViewPadding(bottom: 430);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final chloe = tester.getRect(find.text('Chloé Bernard'));
    final search = tester.getRect(find.byType(TextField));
    final import = tester.getRect(find.text('Import one person'));
    expect(search.bottom, lessThan(chloe.top));
    expect(chloe.bottom, lessThan(import.top));
    expect(import.bottom, lessThanOrEqualTo(_phone.height - 430));
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
      (name: 'Denis', phone: null, email: null, photo: null),
    ])..failWith = Exception('boom');
    await _openImport(tester, phone);
    expect(find.text("Couldn't read your contacts"), findsOneWidget);

    phone.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Denis'), findsOneWidget);
  });
}
