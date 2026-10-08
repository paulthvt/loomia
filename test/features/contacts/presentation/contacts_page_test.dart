import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contact_details.dart';
import 'package:loomia/features/contacts/presentation/contact_list.dart';
import 'package:loomia/features/contacts/presentation/contact_page.dart';
import 'package:loomia/features/contacts/presentation/history_section.dart';
import 'package:loomia/features/contacts/presentation/next_step_section.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../auth/fake_auth_repository.dart';
import '../../workflows/fake_workflow_repository.dart';
import '../fake_activity_repository.dart';
import '../fake_people_repository.dart';

final _marie = Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: Stage.prospect,
  prospectStatus: ProspectStatus.thinking,
  phone: '06 12 34 56 78',
  stageSince: DateTime.utc(2026, 3, 4),
);

final _lucas = Person(
  id: 'p2',
  name: 'Lucas Martin',
  stage: Stage.customer,
  stageSince: DateTime.utc(2026, 5, 1),
);

const _phone = Size(390, 844);
const _desktop = Size(1440, 900);

Activity _note(String id, String text, int day) => Activity(
  id: id,
  personId: 'p1',
  kind: ActivityKind.note,
  happenedOn: DateTime(2026, 9, day),
  text: text,
  createdAt: DateTime.utc(2026, 9, day, 12),
);

Person _marieOn(num position, {DateTime? pausedAt}) => Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: Stage.prospect,
  phone: '06 12 34 56 78',
  stageSince: DateTime.utc(2026, 3, 4),
  place: (workflowId: 'samples', atPosition: position, lastTick: today()),
  pausedAt: pausedAt,
);

/// The custom actions on [finder]'s semantics node, a tap hint included.
List<CustomSemanticsAction> _customActions(
  WidgetTester tester,
  Finder finder,
) => [
  for (final id
      in tester
              .getSemantics(finder)
              .getSemanticsData()
              .customSemanticsActionIds ??
          const <int>[])
    CustomSemanticsAction.getAction(id)!,
];

void main() {
  late FakePeopleRepository people;
  late FakeActivityRepository activities;

  setUp(() {
    activities = FakeActivityRepository();
    people = FakePeopleRepository([_marie, _lucas])..activities = activities;
  });

  Future<void> openContacts(
    WidgetTester tester, {
    Size size = _phone,
    FakeWorkflowRepository? workflows,
    FakeAuthRepository? auth,
  }) async {
    final container = await pumpLoomia(
      tester,
      size: size,
      auth: auth,
      people: people,
      activities: activities,
      workflows: workflows,
    );
    container.read(routerProvider).go(Routes.contacts);
    await tester.pumpAndSettle();
  }

  Future<void> openMarie(
    WidgetTester tester, {
    FakeWorkflowRepository? workflows,
    FakeAuthRepository? auth,
  }) async {
    await openContacts(tester, workflows: workflows, auth: auth);
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();
  }

  /// HISTORY sits below the fold on a phone, and the list builds lazily.
  Future<void> reveal(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.descendant(
        of: find.byType(ContactDetails),
        matching: find.byType(Scrollable),
      ),
    );
    // The last jump lays out on the next frame.
    await tester.pump();
  }

  testWidgets('a failed load shows Retry, which loads the list', (
    tester,
  ) async {
    people.failWith = PeopleFailure.network;
    await openContacts(tester);

    expect(find.text("Couldn't load your contacts."), findsOneWidget);
    people.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Marie Dupont'), findsOneWidget);
  });

  testWidgets('refresh failure keeps the list', (tester) async {
    await openContacts(tester);
    people.failWith = PeopleFailure.network;

    await tester.fling(find.byType(ContactList), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Marie Dupont'), findsOneWidget);
    expect(
      find.text("Couldn't refresh. You're seeing the last loaded list."),
      findsOneWidget,
    );
    expect(find.text("Couldn't load your contacts."), findsNothing);
  });

  testWidgets('Add someone opens the new person', (tester) async {
    await openContacts(tester);

    await tester.tap(find.byTooltip('Add someone'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Name'),
        matching: find.byType(TextFormField),
      ),
      'Chloé',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactPage), findsOneWidget);
    expect(find.text('Chloé'), findsOneWidget);
  });

  testWidgets('missing person', (tester) async {
    final container = await pumpLoomia(tester, size: _phone, people: people);
    container.read(routerProvider).go(Routes.contactLocation('gone'));
    await tester.pumpAndSettle();

    expect(find.text("This person isn't here anymore"), findsOneWidget);
    await tester.tap(find.text('Back to contacts'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactList), findsOneWidget);
  });

  testWidgets('delete returns to the list without the person', (tester) async {
    await openMarie(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Marie'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactList), findsOneWidget);
    expect(find.text('Marie Dupont'), findsNothing);
    expect(people.store.containsKey('p1'), isFalse);
  });

  testWidgets('delete never shows the missing state while leaving', (
    tester,
  ) async {
    await openMarie(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Marie'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    // Every frame of the pop, not just the settled one.
    do {
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text("This person isn't here anymore"), findsNothing);
    } while (tester.binding.hasScheduledFrame);

    expect(find.byType(ContactList), findsOneWidget);
    expect(people.store.containsKey('p1'), isFalse);
  });

  testWidgets('delete from a deep link replaces the page and deletes', (
    tester,
  ) async {
    final container = await pumpLoomia(tester, size: _phone, people: people);
    container.read(routerProvider).go(Routes.contactLocation('p1'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Marie'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactList), findsOneWidget);
    expect(people.store.containsKey('p1'), isFalse);
  });

  testWidgets('a failed delete says so and keeps the person', (tester) async {
    await openMarie(tester);
    people.failWith = PeopleFailure.unknown;

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Marie'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(find.text('Marie Dupont'), findsOneWidget);
  });

  testWidgets('a failed status change reverts with a SnackBar', (tester) async {
    await openMarie(tester);
    people.failWith = PeopleFailure.network;

    await tester.tap(find.widgetWithText(ChoiceChip, 'Interested'));
    await tester.pumpAndSettle();

    ChoiceChip chip(String label) =>
        tester.widget(find.widgetWithText(ChoiceChip, label));
    expect(chip('Thinking about it').selected, isTrue);
    expect(chip('Interested').selected, isFalse);
    expect(
      find.text('Couldn\'t save. Check your connection and try again.'),
      findsOneWidget,
    );
  });

  testWidgets('moving someone updates the header and the history', (
    tester,
  ) async {
    await openMarie(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to customers'));
    await tester.pumpAndSettle();
    expect(find.text('Marie is now a customer'), findsOneWidget);
    expect(
      find.text(
        'Everything you noted stays with them. Where it stands is cleared.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Move to customers'));
    await tester.pumpAndSettle();

    expect(find.text('Customer since September 2026'), findsOneWidget);
    await reveal(tester, find.text('Became a customer'));
    expect(find.text('Became a customer'), findsOneWidget);
  });

  testWidgets('a failed move keeps the sheet open and the stage', (
    tester,
  ) async {
    await openMarie(tester);
    people.failWith = PeopleFailure.network;

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to team'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move to team'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('Marie is now on your team'), findsOneWidget);
    expect(find.text('Prospect since March 2026'), findsOneWidget);
  });

  testWidgets('the latest 3 entries; See all shows the rest in place', (
    tester,
  ) async {
    activities.store.addAll([
      _note('a1', 'First call', 1),
      _note('a2', 'Sent the price list', 5),
      _note('a3', 'Ordered the cream', 10),
      _note('a4', 'Asked about delivery', 15),
    ]);
    await openMarie(tester);

    await reveal(tester, find.text('See all 4'));
    expect(find.text('Asked about delivery'), findsOneWidget);
    expect(find.text('First call'), findsNothing);
    await tester.tap(find.text('See all 4'));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('First call'));
    expect(find.text('See all 4'), findsNothing);
  });

  testWidgets('nothing logged yet', (tester) async {
    await openMarie(tester);

    await reveal(tester, find.text('Nothing logged yet.'));
    expect(find.text('Nothing logged yet.'), findsOneWidget);
  });

  testWidgets('a failed history load has its own Retry', (tester) async {
    activities.failWith = PeopleFailure.network;
    await openMarie(tester);

    await reveal(tester, find.text("Couldn't load the history."));
    // The rest of the page still works: scroll back up to the header.
    await tester.scrollUntilVisible(
      find.text('Marie Dupont'),
      -300,
      scrollable: find.descendant(
        of: find.byType(ContactDetails),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Marie Dupont'), findsOneWidget);
    await reveal(tester, find.text('Try again'));
    activities.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't load the history."), findsNothing);
    expect(find.text('Nothing logged yet.'), findsOneWidget);
  });

  testWidgets('Retry on the history shows the spinner, not the error', (
    tester,
  ) async {
    activities.failWith = PeopleFailure.network;
    await openMarie(tester);
    await reveal(tester, find.text("Couldn't load the history."));

    activities
      ..failWith = null
      ..gate = Completer<void>();
    await tester.tap(find.text('Try again'));
    await tester.pump();

    expect(find.text("Couldn't load the history."), findsNothing);
    expect(
      find.descendant(
        of: find.byType(HistorySection),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    activities.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Nothing logged yet.'), findsOneWidget);
  });

  testWidgets('long-press deletes an entry once confirmed', (tester) async {
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    await openMarie(tester);

    await reveal(tester, find.text('Ordered the cream'));
    await tester.longPress(find.text('Ordered the cream'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this entry?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(activities.calls, contains('delete(a1)'));
    expect(find.text('Ordered the cream'), findsNothing);
  });

  testWidgets('a failed delete brings the entry back with a SnackBar', (
    tester,
  ) async {
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    await openMarie(tester);
    activities.failWith = PeopleFailure.network;

    await reveal(tester, find.text('Ordered the cream'));
    await tester.longPress(find.text('Ordered the cream'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Ordered the cream'), findsOneWidget);
    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets('a stage entry cannot be deleted', (tester) async {
    activities.recordStage('p1', Stage.customer);
    await openMarie(tester);

    await reveal(tester, find.text('Became a customer'));
    await tester.longPress(find.text('Became a customer'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this entry?'), findsNothing);
  });

  testWidgets('tapping an entry edits it', (tester) async {
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    await openMarie(tester);

    await reveal(tester, find.text('Ordered the cream'));
    await tester.tap(find.text('Ordered the cream'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ordered the cream'),
      'Ordered the cream and the soap',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(activities.calls, contains('update(a1)'));
    expect(find.text('Ordered the cream and the soap'), findsOneWidget);
  });

  testWidgets('Delete in the edit sheet confirms, then deletes', (
    tester,
  ) async {
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    await openMarie(tester);

    await reveal(tester, find.text('Ordered the cream'));
    await tester.tap(find.text('Ordered the cream'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this entry?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(activities.calls, contains('delete(a1)'));
    expect(find.text('Ordered the cream'), findsNothing);
  });

  testWidgets('only the latest stage entry opens', (tester) async {
    Activity stage(String id, Stage stage, int day) => Activity(
      id: id,
      personId: 'p1',
      kind: ActivityKind.stage,
      happenedOn: DateTime(2026, 9, day),
      stage: stage,
      createdAt: DateTime.utc(2026, 9, day, 12),
    );
    activities.store.addAll([
      stage('s1', Stage.customer, 20),
      stage('s2', Stage.prospect, 25),
    ]);
    await openMarie(tester);
    final save = find.widgetWithText(FilledButton, 'Save');

    await reveal(tester, find.text('Became a customer'));
    await tester.tap(find.text('Became a customer'));
    await tester.pumpAndSettle();
    expect(save, findsNothing);

    await reveal(tester, find.text('Back to prospects'));
    await tester.tap(find.text('Back to prospects'));
    await tester.pumpAndSettle();
    expect(save, findsOneWidget);
  });

  testWidgets('screen readers hear that a tap edits', (tester) async {
    final semantics = tester.ensureSemantics();
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    activities.recordStage('p1', Stage.customer);
    await openMarie(tester);

    for (final title in ['Ordered the cream', 'Became a customer']) {
      await reveal(tester, find.text(title));
      expect(
        _customActions(tester, find.text(title)),
        contains(
          const CustomSemanticsAction.overridingAction(
            hint: 'Edit',
            action: SemanticsAction.tap,
          ),
        ),
      );
    }
    semantics.dispose();
  });

  testWidgets('screen readers get a Delete action on an entry', (tester) async {
    final semantics = tester.ensureSemantics();
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    await openMarie(tester);
    await reveal(tester, find.text('Ordered the cream'));

    expect(
      _customActions(tester, find.text('Ordered the cream')),
      contains(const CustomSemanticsAction(label: 'Delete')),
    );
    semantics.dispose();
  });

  testWidgets('Log something from ⋯ adds to the history', (tester) async {
    await openMarie(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log something'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'What happened'),
        matching: find.byType(TextFormField),
      ),
      'Met at the market',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Met at the market'));
    expect(find.text('Met at the market'), findsOneWidget);
  });

  testWidgets('Log an order from ⋯ reads Order · 100 PV', (tester) async {
    final auth = FakeAuthRepository()
      ..session = true
      ..account = const Account(
        firstName: 'Pauline',
        email: 'p@example.com',
        businessModel: BusinessModel.doterra,
      );
    await openMarie(tester, auth: auth);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log something'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Order'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Amount'),
        matching: find.byType(TextFormField),
      ),
      '100',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Order · 100 PV'));
    expect(find.text('Order · 100 PV'), findsOneWidget);
  });

  testWidgets('Add in HISTORY opens Log something', (tester) async {
    await openMarie(tester);

    await reveal(tester, find.text('HISTORY'));
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Log something with Marie'), findsOneWidget);
  });

  testWidgets('desktop: the split keeps the list and its filter', (
    tester,
  ) async {
    await openContacts(tester, size: _desktop);

    expect(find.text('Pick someone'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Customers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lucas Martin'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactDetails), findsOneWidget);
    expect(find.byType(ContactPage), findsNothing);
    expect(find.byType(BackButton), findsNothing);
    final filter = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Customers'),
    );
    expect(filter.selected, isTrue);
    expect(find.text('Marie Dupont'), findsNothing);
  });

  testWidgets('several picked move to the team together', (tester) async {
    await openContacts(tester);

    await tester.longPress(find.text('Marie Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lucas Martin'));
    await tester.pumpAndSettle();
    // The picking's actions take the bottom navigation's place.
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.text('Move to…'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Team').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Move to team'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('setStage(p2, p1, team)'));
    expect(people.store['p1']!.stage, Stage.team);
    expect(people.store['p2']!.stage, Stage.team);
    expect(find.text('2 selected'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('back ends the picking and brings the navigation back', (
    tester,
  ) async {
    await openContacts(tester);

    await tester.longPress(find.text('Marie Dupont'));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('desktop: deleting the open person empties the pane', (
    tester,
  ) async {
    await openContacts(tester, size: _desktop);
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select'));
    await tester.pump();
    await tester.tap(find.text('Select all'));
    await tester.pump();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('delete(p2, p1)'));
    expect(find.text('Pick someone'), findsOneWidget);
    expect(find.byType(ContactDetails), findsNothing);
  });

  testWidgets('desktop: right-click deletes an entry in the split', (
    tester,
  ) async {
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    await openContacts(tester, size: _desktop);
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();

    await reveal(tester, find.text('Ordered the cream'));
    await tester.tap(find.text('Ordered the cream'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Delete this entry?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(activities.calls, contains('delete(a1)'));
    expect(find.text('Ordered the cream'), findsNothing);
  });

  const markFirst = 'Mark "Send a first message" done';
  const couldNotSave = "Couldn't save. Check your connection and try again.";

  testWidgets('ticking a step moves the card on and logs it', (tester) async {
    people.store['p1'] = _marieOn(1);
    await openMarie(tester);

    expect(find.text('Samples · 1 of 5'), findsOneWidget);
    await tester.tap(find.byTooltip(markFirst));
    await tester.pumpAndSettle();

    expect(find.text('Send the samples'), findsOneWidget);
    expect(find.text('Samples · 2 of 5'), findsOneWidget);
    expect(people.calls, contains('completeStep(p1, samples-1)'));
  });

  testWidgets('a reminder: added from Next step, then ticked into the '
      'history', (tester) async {
    people.store['p1'] = _marieOn(1);
    await openMarie(tester);

    await tester.tap(find.text('Add a reminder'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'What'),
        matching: find.byType(TextFormField),
      ),
      'Call back about the diffuser',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Call back about the diffuser'), findsOneWidget);
    expect(find.text('Due tomorrow'), findsOneWidget);
    // The step is still there, below.
    expect(find.text('Send a first message'), findsOneWidget);

    await tester.tap(
      find.byTooltip('Mark "Call back about the diffuser" done'),
    );
    await tester.pumpAndSettle();

    expect(people.calls.last, startsWith('completeReminder('));
    expect(
      activities.store.where((entry) => entry.kind == ActivityKind.reminder),
      hasLength(1),
    );
    expect(find.text('Send a first message'), findsOneWidget);
  });

  testWidgets('a tick in flight takes no second tap: one step, not two', (
    tester,
  ) async {
    people.store['p1'] = _marieOn(1);
    await openMarie(tester);
    people.gate = Completer<void>();

    await tester.tap(find.byTooltip(markFirst));
    await tester.pump();
    await tester.tap(find.byTooltip(markFirst));
    await tester.pump();
    people.gate!.complete();
    people.gate = null;
    await tester.pumpAndSettle();

    expect(
      people.calls.where((call) => call.startsWith('completeStep')),
      hasLength(1),
    );
  });

  testWidgets('a failed tick says so and keeps the step', (tester) async {
    people.store['p1'] = _marieOn(1);
    await openMarie(tester);
    people.failWith = PeopleFailure.network;

    await tester.tap(find.byTooltip(markFirst));
    await tester.pumpAndSettle();

    expect(find.text(couldNotSave), findsOneWidget);
    expect(find.text('Send a first message'), findsOneWidget);
  });

  testWidgets('Pause from ⋯ shows the paused card; Resume brings it back', (
    tester,
  ) async {
    people.store['p1'] = _marieOn(2);
    await openMarie(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause — not now'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Paused since'), findsOneWidget);
    expect(people.store['p1']!.prospectStatus, ProspectStatus.notNow);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Resume'));
    await tester.pumpAndSettle();

    expect(find.text('Send the samples'), findsOneWidget);
  });

  testWidgets('done: Became a customer opens the move to customers', (
    tester,
  ) async {
    people.store['p1'] = _marieOn(6);
    await openMarie(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Became a customer'));
    await tester.pumpAndSettle();

    expect(find.text('Marie is now a customer'), findsOneWidget);
  });

  testWidgets('Change workflow from ⋯ opens the sheet', (tester) async {
    people.store['p1'] = _marieOn(2);
    await openMarie(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change workflow'));
    await tester.pumpAndSettle();

    expect(find.text("Change Marie's workflow"), findsOneWidget);
  });

  testWidgets('workflows loading: a spinner in the card, the page works', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples())
      ..gate = Completer<void>();
    people.store['p1'] = _marieOn(1);
    // Today spins too while the workflows load: nothing settles, pump by hand.
    final container = await pumpLoomia(
      tester,
      size: _phone,
      people: people,
      activities: activities,
      workflows: workflows,
      settle: false,
    );
    container.read(routerProvider).go(Routes.contactLocation('p1'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.descendant(
        of: find.byType(NextStepSection),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(find.text('Marie Dupont'), findsWidgets);
    workflows.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Send a first message'), findsOneWidget);
  });

  testWidgets('workflows failed: the card says so, Try again loads them', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples())
      ..failWith = PeopleFailure.network;
    people.store['p1'] = _marieOn(1);
    await openMarie(tester, workflows: workflows);

    expect(find.text("Couldn't load the workflows"), findsOneWidget);
    workflows.failWith = null;
    await tester.tap(
      find.descendant(
        of: find.byType(NextStepSection),
        matching: find.text('Try again'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Send a first message'), findsOneWidget);
  });
}
