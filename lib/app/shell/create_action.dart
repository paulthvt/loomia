import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/features/contacts/presentation/log_activity_sheet.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/tasks/presentation/task_sheet.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// What the + creates on a tab: its label (tooltip, sidebar text), icon,
/// and what it runs.
typedef CreateAction = ({
  String label,
  IconData icon,
  Future<void> Function(BuildContext context, WidgetRef ref) run,
});

/// The + of the tab at [location]: what the tab is about. Null anywhere
/// else (a contact, an event, Settings), which has no +.
CreateAction? createActionFor(
  String location,
  AppLocalizations l10n,
) => switch (location) {
  Routes.today => (
    label: l10n.createTask,
    icon: Icons.add_rounded,
    run: (context, _) async => showTask(context, day: today()),
  ),
  Routes.calendar => (
    label: l10n.createEvent,
    icon: Icons.add_rounded,
    run: (context, ref) =>
        addOnCalendar(context, ref, ref.read(calendarSelectionProvider).day),
  ),
  Routes.contacts => (
    label: l10n.createPerson,
    icon: Icons.add_rounded,
    run: (context, _) => addPerson(context),
  ),
  Routes.goals => (
    label: l10n.newOrder,
    icon: Icons.add_rounded,
    run: (context, _) {
      // The container, not the context: the sheet may be closing.
      final container = ProviderScope.containerOf(context, listen: false);
      return showLogOwnOrder(context, onSaved: () => refreshOrders(container));
    },
  ),
  _ => null,
};
