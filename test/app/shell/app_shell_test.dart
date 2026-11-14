import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/shell/floating_nav_bar.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contact_list.dart';
import 'package:loomia/features/contacts/presentation/contact_page.dart';
import 'package:loomia/features/contacts/presentation/reminder_sheet.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_page.dart';
import 'package:loomia/features/settings/presentation/settings_page.dart';
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

/// A destination of the floating bar, by the label it announces.
Finder _tab(String label) => find.descendant(
  of: find.byType(FloatingNavBar),
  matching: find.bySemanticsLabel(label),
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
    final icon = find.byIcon(Icons.wb_sunny);
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

  testWidgets("desktop: the sidebar's first button creates for the section", (
    tester,
  ) async {
    final container = await pumpLoomia(tester, size: const Size(1440, 900));
    container.read(routerProvider).go(Routes.contacts);
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('New person'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoomiaDialog), findsOneWidget);
  });

  testWidgets('desktop: on Goals the sidebar button says New order', (
    tester,
  ) async {
    final container = await pumpLoomia(tester, size: const Size(1440, 900));
    container.read(routerProvider).go(Routes.goals);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('New order'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('desktop: a long create label shrinks onto one line', (
    tester,
  ) async {
    // Large text stands in for a long translation.
    tester.platformDispatcher.textScaleFactorTestValue = 2.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final container = await pumpLoomia(tester, size: const Size(1440, 900));
    container.read(routerProvider).go(Routes.goals);
    await tester.pumpAndSettle();

    final label = find.descendant(
      of: find.byType(AppSidebar),
      matching: find.text('New order'),
    );
    final button = tester.getRect(
      find.ancestor(of: label, matching: find.byType(FilledButton)),
    );
    final text = tester.getRect(label);
    expect(button.left <= text.left && text.right <= button.right, isTrue);
    // Laid out on one line, then scaled down to fit.
    expect(text.width, lessThan(tester.getSize(label).width));
  });

  testWidgets("tablet: the rail's + is labelled for screen readers", (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpLoomia(tester, size: const Size(800, 1000));

    final create = find.descendant(
      of: find.byType(AppSidebar),
      matching: find.byTooltip('New task'),
    );
    expect(
      tester.getSemantics(create),
      isSemantics(tooltip: 'New task', isButton: true),
    );
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(find.byType(ReminderDayField), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('mobile: a floating bar with Today and Contacts', (tester) async {
    await pumpLoomia(
      tester,
      size: const Size(390, 844),
      people: FakePeopleRepository([_marie]),
    );

    expect(find.byType(FloatingNavBar), findsOneWidget);
    await tester.tap(_tab('Contacts'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactList), findsOneWidget);
  });

  testWidgets('mobile: the bar is hidden on a contact and on Settings', (
    tester,
  ) async {
    await pumpLoomia(
      tester,
      size: const Size(390, 844),
      people: FakePeopleRepository([_marie]),
    );
    await tester.tap(_tab('Contacts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactPage), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsNothing);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(FloatingNavBar), findsOneWidget);
    await tester.tap(find.byType(AccountButton));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsNothing);
  });

  testWidgets('bar hidden while picking contacts', (tester) async {
    await pumpLoomia(
      tester,
      size: const Size(390, 844),
      people: FakePeopleRepository([_marie]),
    );
    await tester.tap(_tab('Contacts'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Marie Dupont'));
    await tester.pumpAndSettle();

    expect(find.text('1 selected'), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsNothing);
  });

  testWidgets('mobile: the + on each tab has its label', (tester) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));
    for (final (path, label) in [
      (Routes.today, 'New task'),
      (Routes.calendar, 'New event'),
      (Routes.contacts, 'New person'),
      (Routes.goals, 'New order'),
    ]) {
      container.read(routerProvider).go(path);
      await tester.pumpAndSettle();

      expect(find.byTooltip(label), findsOneWidget, reason: path);
    }
  });

  testWidgets('mobile: + on Today opens the task sheet', (tester) async {
    await pumpLoomia(tester, size: const Size(390, 844));

    await tester.tap(find.byTooltip('New task'));
    await tester.pumpAndSettle();

    final field = tester.widget<ReminderDayField>(
      find.byType(ReminderDayField),
    );
    expect(field.value, today());
  });

  testWidgets('plus on calendar adds on the selected day', (tester) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    final now = today();
    final day = DateTime(now.year, now.month, now.day == 15 ? 16 : 15);
    container.read(calendarSelectionProvider.notifier).select(day);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New event'));
    await tester.pumpAndSettle();
    // A sheet, not a menu over the bar.
    final sheet = find.byType(BottomSheet);
    expect(
      find.byWidgetPredicate((widget) => widget is PopupMenuEntry),
      findsNothing,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Event')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: sheet,
        matching: find.text('Something with a time and people'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.descendant(of: sheet, matching: find.text('Task')));
    await tester.pumpAndSettle();

    final field = tester.widget<ReminderDayField>(
      find.byType(ReminderDayField),
    );
    expect(field.value, day);
  });

  testWidgets('plus on calendar opens the event form from the sheet', (
    tester,
  ) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New event'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    await tester.tap(find.text('Event'));
    await tester.pumpAndSettle();
    // The chooser closed, the event form opened in its place.
    expect(find.text('Something with a time and people'), findsNothing);
    expect(find.text('New event'), findsWidgets);
    expect(find.byType(LoomiaDialog), findsOneWidget);
  });

  testWidgets('last row scrolls above the floating bar', (tester) async {
    await pumpLoomia(
      tester,
      size: const Size(390, 844),
      people: FakePeopleRepository([
        for (var i = 0; i < 30; i++)
          Person(
            id: 'p$i',
            name: 'Person ${i.toString().padLeft(2, '0')}',
            stage: Stage.prospect,
            stageSince: DateTime.utc(2026, 3, 4),
          ),
      ]),
    );
    await tester.tap(_tab('Contacts'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, -5000));
    await tester.pumpAndSettle();

    final last = find.widgetWithText(ContactRow, 'Person 29');
    final bar = find.descendant(
      of: find.byType(FloatingNavBar),
      matching: find.byType(Container),
    );
    expect(
      tester.getBottomLeft(last).dy,
      lessThanOrEqualTo(tester.getTopLeft(bar.first).dy),
    );
  });

  testWidgets('floating bar survives text scale 1.3, icons only', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpLoomia(tester, size: const Size(390, 844));

    for (final label in ['Calendar', 'Contacts', 'Goals', 'Today']) {
      await tester.tap(_tab(label));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(FloatingNavBar),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('mobile: back on a tab returns to Today, not out of the app', (
    tester,
  ) async {
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 844),
      people: FakePeopleRepository([_marie]),
    );
    String path() =>
        container.read(routerProvider).routerDelegate.state.uri.path;
    await tester.tap(_tab('Contacts'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();

    // A person pops to the list first, then the tab to Today.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(path(), Routes.contacts);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(path(), Routes.today);

    await tester.tap(_tab('Calendar'));
    await tester.pumpAndSettle();
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(path(), Routes.today);

    // On Today, back is left to the system: the app closes.
    expect(await tester.binding.handlePopRoute(), isFalse);
  });

  for (final (screen, size) in [
    ('tablet rail', const Size(800, 1000)),
    ('desktop sidebar', const Size(1440, 900)),
  ]) {
    testWidgets('$screen: the active item shows its filled icon', (
      tester,
    ) async {
      await pumpLoomia(tester, size: size);

      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_outlined), findsNothing);
      expect(find.byIcon(Icons.people_outline), findsOneWidget);
      expect(find.byIcon(Icons.people), findsNothing);
    });
  }

  testWidgets('desktop: the sidebar has Contacts', (tester) async {
    await pumpLoomia(tester, size: const Size(1440, 900));

    // On Today, the sidebar entry is the only "Contacts" on screen.
    await tester.tap(find.text('Contacts'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactList), findsOneWidget);
    expect(find.byType(FloatingNavBar), findsNothing);
  });

  testWidgets('mobile: Calendar is the second tab and opens the month', (
    tester,
  ) async {
    await pumpLoomia(tester, size: const Size(390, 844));

    await tester.tap(_tab('Calendar'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarView), findsOneWidget);
    final bar = tester.widget<FloatingNavBar>(find.byType(FloatingNavBar));
    expect(bar.selected, 1);
    expect(find.text('Team'), findsNothing);
  });

  testWidgets('desktop: the sidebar opens the Calendar', (tester) async {
    await pumpLoomia(tester, size: const Size(1440, 900));

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarView), findsOneWidget);
  });

  testWidgets('an old link to Team opens Contacts', (tester) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));

    container.read(routerProvider).go(Routes.team);
    await tester.pumpAndSettle();

    expect(find.byType(ContactList), findsOneWidget);
  });

  testWidgets('mobile: Goals is the fourth tab and opens Goals', (
    tester,
  ) async {
    await pumpLoomia(tester, size: const Size(390, 844));

    await tester.tap(_tab('Goals'));
    await tester.pumpAndSettle();

    expect(find.byType(GoalsPage), findsOneWidget);
    final bar = tester.widget<FloatingNavBar>(find.byType(FloatingNavBar));
    expect(bar.selected, 3);
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
    await tester.tap(_tab('Goals'));
    await tester.pumpAndSettle();
    final loads = goals.calls.where((call) => call == 'plans()').length;

    await tester.tap(find.byTooltip('New order'));
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
