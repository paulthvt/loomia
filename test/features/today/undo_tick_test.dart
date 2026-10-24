import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/undo_tick.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/app_harness.dart';
import '../contacts/fake_activity_repository.dart';
import '../contacts/fake_people_repository.dart';

// Undo a tick on Today (#372).

const _phone = Size(390, 1400);
const _markFirst = 'Mark "Send a first message" done';
const _markPriceList = 'Mark "Send her the price list" done';

Person _anna({List<Reminder> reminders = const []}) => Person(
  id: 'p1',
  name: 'Anna',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 3, 4),
  place: (workflowId: 'samples', atPosition: 1, lastTick: today()),
  reminders: reminders,
);

Person _bruno() => Person(
  id: 'p2',
  name: 'Bruno',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 3, 4),
  place: (workflowId: 'samples', atPosition: 1, lastTick: addDays(today(), -2)),
);

void main() {
  late FakeActivityRepository activities;
  late FakePeopleRepository people;

  setUp(() {
    activities = FakeActivityRepository();
    people = FakePeopleRepository([_anna()])..activities = activities;
  });

  Future<void> pump(WidgetTester tester) =>
      pumpLoomia(tester, size: _phone, people: people, activities: activities);

  testWidgets('Undo on a step: the row and the bar come back', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip(_markFirst));
    await tester.pumpAndSettle();
    expect(find.text('1 of 1 done'), findsOneWidget);
    expect(find.text('Done for Anna: Send a first message'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('undoStep(p1, samples-1)'));
    expect(find.byTooltip(_markFirst), findsOneWidget);
    expect(find.text('0 of 1 done'), findsOneWidget);
    expect(activities.store, isEmpty);
  });

  testWidgets('Undo on a reminder brings it back', (tester) async {
    people = FakePeopleRepository([
      _anna(
        reminders: [
          (
            id: 'r1',
            text: 'Send her the price list',
            dueOn: today(),
            createdAt: DateTime.utc(2026),
          ),
        ],
      ),
    ])..activities = activities;
    await pump(tester);
    await tester.tap(find.byTooltip(_markPriceList));
    await tester.pumpAndSettle();
    expect(find.byTooltip(_markPriceList), findsNothing);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('undoReminder(r1)'));
    expect(find.byTooltip(_markPriceList), findsOneWidget);
    expect(activities.store, isEmpty);
  });

  testWidgets('Undo on an LRP renewal unchecks it', (tester) async {
    // Within the 3 days ahead there is always a day from 1 to 28.
    final day = [
      for (var ahead = 0; ahead <= 3; ahead++) addDays(today(), ahead).day,
    ].firstWhere((day) => day <= 28);
    people = FakePeopleRepository([
      Person(
        id: 'p3',
        name: 'Julie Martin',
        stage: Stage.customer,
        stageSince: DateTime.utc(2026, 9),
        loyaltySince: DateTime(2026, 1, day),
        loyaltyDay: day,
      ),
    ])..activities = activities;
    await pump(tester);
    final row = find.textContaining("Julie's Loyalty orders renews");
    await tester.tap(find.byTooltip(RegExp('^Mark "Julie')));
    await tester.pumpAndSettle();
    expect(row, findsNothing);
    expect(find.text('LRP checked for Julie Martin'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('undoLoyaltyCheck(p3)'));
    expect(row, findsOneWidget);
  });

  testWidgets('two ticks, then Undo: only the second comes back', (
    tester,
  ) async {
    people = FakePeopleRepository([_anna(), _bruno()])..activities = activities;
    await pump(tester);
    // Bruno is late: his row is first.
    await tester.tap(find.byTooltip(_markFirst).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(_markFirst));
    await tester.pumpAndSettle();
    expect(find.text('Done for Anna: Send a first message'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('Bruno'), findsNothing);
    expect(people.calls.where((call) => call.startsWith('undo')), hasLength(1));
  });

  testWidgets('a person changed since the tick: Undo says so, nothing moves', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byTooltip(_markFirst));
    await tester.pumpAndSettle();
    // Edited on another device.
    final edited = people.store['p1']!;
    people.store['p1'] = Person(
      id: edited.id,
      name: edited.name,
      stage: edited.stage,
      stageSince: edited.stageSince,
      place: edited.place,
      updatedAt: 'elsewhere',
    );

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(
      find.text("That changed in the meantime, so it wasn't undone."),
      findsOneWidget,
    );
    expect(find.byTooltip(_markFirst), findsNothing);
    expect(activities.store, hasLength(1));
  });

  testWidgets('Undo goes after 5 s', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip(_markFirst));
    await tester.pumpAndSettle();

    await tester.pump(undoTickDuration + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('with a screen reader, Undo stays until dismissed', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pump(tester);
    await tester.tap(find.byTooltip(_markFirst));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();

    expect(find.text('Undo'), findsOneWidget);
  });

  testWidgets('on desktop the snackbar is 480 wide', (tester) async {
    await pumpLoomia(
      tester,
      size: const Size(1440, 1400),
      people: people,
      activities: activities,
    );
    await tester.tap(find.byTooltip(_markFirst));
    await tester.pumpAndSettle();

    final card = find.descendant(
      of: find.byType(SnackBar),
      matching: find.byType(Material),
    );
    expect(tester.getSize(card.first).width, 480);
  });
}
