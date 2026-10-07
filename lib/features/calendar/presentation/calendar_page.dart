import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_form.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Opens an event: in the pane beside the month on desktop, pushed above
/// the month elsewhere so back returns to it.
void openEvent(BuildContext context, String id) {
  final location = Routes.eventLocation(id);
  if (context.screenSize.isDesktop) {
    context.go(location);
  } else {
    unawaited(context.push(location));
  }
}

/// The Calendar destination. On desktop it also holds [pane]: the selected
/// day, or an event.
class CalendarPage extends ConsumerWidget {
  const CalendarPage({this.pane, super.key});

  final Widget? pane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = eventsProvider(ref.watch(accountProvider)?.email);
    final selector = ref.read(calendarSelectionProvider.notifier);
    return CalendarView(
      events: ref.watch(provider),
      selection: ref.watch(calendarSelectionProvider),
      today: today(),
      onSelect: (day) {
        selector.select(day);
        // Desktop: an open event gives the pane back to the day.
        if (pane != null) context.go(Routes.calendar);
      },
      onShift: selector.shift,
      onToday: selector.toToday,
      onOpen: (event) => openEvent(context, event.id),
      onAdd: (day) => unawaited(showEventForm(context, day: day)),
      onRetry: () => ref.invalidate(provider),
      pane: pane,
      // With a sidebar, Settings is its account block instead.
      accountAction: context.screenSize.usesSideNavigation
          ? null
          : const AccountButton(),
    );
  }
}

/// Desktop's pane at `/calendar`: the selected day.
class CalendarDayPane extends ConsumerWidget {
  const CalendarDayPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = eventsProvider(ref.watch(accountProvider)?.email);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        DaySection(
          events: ref.watch(provider),
          day: ref.watch(calendarSelectionProvider).day,
          onOpen: (event) => openEvent(context, event.id),
          onAdd: (day) => unawaited(showEventForm(context, day: day)),
          onRetry: () => ref.invalidate(provider),
        ),
      ],
    );
  }
}

/// The screen as a function of its inputs, for previews and tests. Mobile
/// and tablet: the month, then the selected day, and an add button. Desktop
/// ([pane] set): the month on the left, [pane] on the right.
class CalendarView extends StatelessWidget {
  const CalendarView({
    required this.events,
    required this.selection,
    required this.today,
    required this.onSelect,
    required this.onShift,
    required this.onToday,
    required this.onOpen,
    required this.onAdd,
    required this.onRetry,
    this.pane,
    this.accountAction,
    super.key,
  });

  /// Fixed, like the Contacts list, so a resized window narrows the month.
  static const double _paneWidth = 440;

  /// A horizontal swipe faster than this changes month.
  static const double _swipe = 300;

  final AsyncValue<List<CalendarEvent>> events;
  final CalendarSelection selection;

  /// The device's today, local midnight.
  final DateTime today;

  final ValueChanged<DateTime> onSelect;

  /// −1 for the month before, 1 for the one after.
  final ValueChanged<int> onShift;
  final VoidCallback onToday;
  final void Function(CalendarEvent event) onOpen;

  /// Adds an event on the given day.
  final ValueChanged<DateTime> onAdd;
  final VoidCallback onRetry;
  final Widget? pane;

  /// Top-bar entry to Settings, where there is no sidebar to hold it.
  final Widget? accountAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final side = pane;
    final header = Row(
      children: [
        Expanded(
          child: Text(
            l10n.calendarMonth(selection.month),
            style: side == null
                ? theme.textTheme.headlineSmall
                : theme.textTheme.displaySmall,
          ),
        ),
        TextButton(onPressed: onToday, child: Text(l10n.calendarToday)),
        IconButton(
          onPressed: () => onShift(-1),
          tooltip: l10n.calendarPreviousMonth,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          onPressed: () => onShift(1),
          tooltip: l10n.calendarNextMonth,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        ?accountAction,
      ],
    );
    final grid = GestureDetector(
      // A swipe changes month, as in the phone's own calendar.
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > _swipe) onShift(velocity < 0 ? 1 : -1);
      },
      child: MonthGrid(
        month: selection.month,
        selected: selection.day,
        today: today,
        counts: eventsPerDay(events.value ?? const []),
        onSelect: onSelect,
      ),
    );

    if (side != null) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.xl,
                  ),
                  children: [
                    header,
                    const SizedBox(height: AppSpacing.lg),
                    grid,
                  ],
                ),
              ),
              Container(
                width: _paneWidth,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: LoomiaColors.of(context).borderSubtle,
                    ),
                  ),
                ),
                child: side,
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => onAdd(selection.day),
        tooltip: l10n.calendarNewEvent,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: ListView(
          // The bottom inset keeps the last row clear of the add button.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxxl + AppSpacing.lg,
          ),
          children: [
            header,
            const SizedBox(height: AppSpacing.md),
            grid,
            const Divider(height: AppSpacing.xl),
            DaySection(
              events: events,
              day: selection.day,
              onOpen: onOpen,
              onAdd: onAdd,
              onRetry: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// The selected day: its heading with Add, then its events, or what is
/// wrong with loading them.
class DaySection extends StatelessWidget {
  const DaySection({
    required this.events,
    required this.day,
    required this.onOpen,
    required this.onAdd,
    required this.onRetry,
    super.key,
  });

  final AsyncValue<List<CalendarEvent>> events;
  final DateTime day;
  final void Function(CalendarEvent event) onOpen;
  final ValueChanged<DateTime> onAdd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // `.value` survives a failed refresh, so the rows stay on screen.
    final list = events.value;
    final List<Widget> body;
    if (list != null) {
      final onDay = eventsOn(list, day);
      body = onDay.isEmpty
          ? [
              Text(
                l10n.calendarNothingPlanned,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: LoomiaColors.of(context).textMuted,
                ),
              ),
            ]
          : [
              for (final (index, event) in onDay.indexed) ...[
                if (index > 0) const SizedBox(height: AppSpacing.ms),
                EventRow(event: event, onTap: () => onOpen(event)),
              ],
            ];
    } else if (events.hasError) {
      body = [
        EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l10n.calendarLoadFailed,
          body: l10n.contactsLoadErrorBody,
          actionLabel: l10n.contactsRetry,
          onAction: onRetry,
        ),
      ];
    } else {
      body = [const Center(child: CircularProgressIndicator())];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.calendarDayTitle(day),
          actionLabel: l10n.calendarAdd,
          onAction: () => onAdd(day),
        ),
        const SizedBox(height: AppSpacing.ms),
        ...body,
      ],
    );
  }
}
