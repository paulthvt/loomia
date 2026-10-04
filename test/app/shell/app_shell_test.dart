import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contact_list.dart';
import 'package:loomia/features/contacts/presentation/contact_page.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_page.dart';
import 'package:loomia/features/settings/presentation/settings_page.dart';
import 'package:loomia/features/team/presentation/team_page.dart';
import 'package:material_ui/material_ui.dart';

import '../../features/contacts/fake_activity_repository.dart';
import '../../features/contacts/fake_people_repository.dart';
import '../../features/goals/fake_goals_repository.dart';
import '../app_harness.dart';

final _marie = Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 3, 4),
);

void main() {
  testWidgets('mobile: no sidebar, Settings opens from the top bar', (
    tester,
  ) async {
    await pumpLoomia(tester, size: const Size(390, 844));

    expect(find.bySemanticsLabel('Loomia'), findsNothing);
    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('tablet: an icon rail, its items labelled for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpLoomia(tester, size: const Size(800, 1000));

    expect(find.byType(AccountButton), findsNothing);
    expect(find.bySemanticsLabel('Loomia'), findsNothing);
    // Activated the way a screen reader would, through the semantics action.
    tester.semantics.tap(find.semantics.byLabel('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('landscape phone: the rail widens past the cutout inset', (
    tester,
  ) async {
    tester.view.padding = const FakeViewPadding(left: 28, right: 48);
    addTearDown(tester.view.resetPadding);
    await pumpLoomia(tester, size: const Size(832, 384));

    // The sidebar comes first in the Row, so its Today item is the first tile.
    final tile = find.byType(ListTile).first;
    expect(tester.getTopLeft(tile).dx, greaterThanOrEqualTo(28));
    expect(tester.getSize(tile).width, greaterThanOrEqualTo(44));
    final icon = find.byIcon(Icons.wb_sunny_outlined);
    expect(tester.getCenter(icon).dx, tester.getCenter(tile).dx);
  });

  testWidgets('desktop: the sidebar, its account block opens Settings', (
    tester,
  ) async {
    await pumpLoomia(tester, size: const Size(1440, 900));

    expect(find.bySemanticsLabel('Loomia'), findsOneWidget);
    expect(find.byType(AccountButton), findsNothing);
    await tester.tap(find.text('Pauline'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('mobile: a bottom bar with Today and Contacts', (tester) async {
    await pumpLoomia(
      tester,
      size: const Size(390, 844),
      people: FakePeopleRepository([_marie]),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.widgetWithText(NavigationDestination, 'Contacts'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactList), findsOneWidget);
  });

  testWidgets('mobile: the bar stays on a contact, not on Settings', (
    tester,
  ) async {
    await pumpLoomia(
      tester,
      size: const Size(390, 844),
      people: FakePeopleRepository([_marie]),
    );
    await tester.tap(find.widgetWithText(NavigationDestination, 'Contacts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('desktop: the sidebar has Contacts', (tester) async {
    await pumpLoomia(tester, size: const Size(1440, 900));

    // On Today, the sidebar entry is the only "Contacts" on screen.
    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactList), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('mobile: Team is the third tab and opens the team', (
    tester,
  ) async {
    await pumpLoomia(tester, size: const Size(390, 844));

    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();

    expect(find.byType(TeamPage), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });

  testWidgets('desktop: the sidebar opens the team', (tester) async {
    await pumpLoomia(tester, size: const Size(1440, 900));

    await tester.tap(find.text('Team'));
    await tester.pumpAndSettle();

    expect(find.byType(TeamPage), findsOneWidget);
  });

  testWidgets('mobile: Goals is the fourth tab and opens Goals', (
    tester,
  ) async {
    await pumpLoomia(tester, size: const Size(390, 844));

    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();

    expect(find.byType(GoalsPage), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 3);
  });

  testWidgets('desktop: the sidebar opens Goals', (tester) async {
    await pumpLoomia(tester, size: const Size(1440, 900));

    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();

    expect(find.byType(GoalsPage), findsOneWidget);
  });

  testWidgets('an own order from Goals counts at once', (tester) async {
    final now = DateTime.now();
    final goals = FakeGoalsRepository(
      plans: [MonthPlan(month: DateTime(now.year, now.month))],
    );
    final activities = FakeActivityRepository();
    await pumpLoomia(
      tester,
      size: const Size(390, 844),
      goals: goals,
      activities: activities,
    );
    await tester.tap(find.text('Goals'));
    await tester.pumpAndSettle();
    final loads = goals.calls.where((call) => call == 'plans()').length;

    await tester.scrollUntilVisible(find.text('Log my own order'), 200);
    await tester.tap(find.text('Log my own order'));
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

    expect(activities.store.single.personId, isNull);
    expect(goals.calls.where((call) => call == 'plans()').length, loads + 1);
  });
}
