import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
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
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
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

  Future<void> _add(BuildContext context, WidgetRef ref, DateTime day) async {
    final saved = await showEventForm(context, day: day);
    if (saved != null && context.mounted) {
      ref.read(calendarSelectionProvider.notifier).select(saved.day);
    }
  }

  /// Reloads the events, and the book their people come from, while the
  /// month stays on screen. A failure says so in a SnackBar.
  Future<void> _refresh(BuildContext context, WidgetRef ref) async {
    final owner = ref.read(accountProvider)?.email;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final provider = eventsProvider(owner);
    ref
      ..invalidate(peopleProvider(owner))
      ..invalidate(provider);
    try {
      await ref.read(provider.future);
    } on PeopleFailure {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.contactsRefreshFailed)),
      );
    }
  }

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
      onAdd: (day) => unawaited(_add(context, ref, day)),
      onRetry: () => ref.invalidate(provider),
      onRefresh: () => _refresh(context, ref),
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

  Future<void> _add(BuildContext context, WidgetRef ref, DateTime day) async {
    final saved = await showEventForm(context, day: day);
    if (saved != null && context.mounted) {
      ref.read(calendarSelectionProvider.notifier).select(saved.day);
    }
  }

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
          onAdd: (day) => unawaited(_add(context, ref, day)),
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
    this.onRefresh,
    this.pane,
    this.accountAction,
    super.key,
  });

  /// Fixed, like the Contacts list, so a resized window narrows the month.
  static const double _paneWidth = 440;

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

  /// Pull to refresh, on mobile and tablet. None in previews.
  final Future<void> Function()? onRefresh;
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
    final counts = eventsPerDay(events.value ?? const []);
    final grid = _SwipeableMonth(
      month: selection.month,
      onShift: onShift,
      builder: (month) => MonthGrid(
        month: month,
        selected: selection.day,
        today: today,
        counts: counts,
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
        child: _refreshable(
          ListView(
            // Pull to refresh works on a short list too.
            physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }

  Widget _refreshable(Widget list) {
    final refresh = onRefresh;
    return refresh == null
        ? list
        : RefreshIndicator(onRefresh: refresh, child: list);
  }
}

/// The grid for [month], which follows the finger: dragged sideways, the
/// neighbouring month comes in beside it, and on release the page turns
/// (past halfway, or flung) or springs back. The arrows and Today slide the
/// new month in from its side too. Reduce motion: they just switch.
class _SwipeableMonth extends StatefulWidget {
  const _SwipeableMonth({
    required this.month,
    required this.onShift,
    required this.builder,
  });

  final DateTime month;

  /// −1 for the month before, 1 for the one after.
  final ValueChanged<int> onShift;

  /// The grid for a month.
  final Widget Function(DateTime month) builder;

  @override
  State<_SwipeableMonth> createState() => _SwipeableMonthState();
}

class _SwipeableMonthState extends State<_SwipeableMonth>
    with SingleTickerProviderStateMixin {
  /// A fling faster than this, in px/s, turns the page however short it was.
  static const double _fling = 300;

  /// Where [_SwipeableMonth.month] sits, in grid widths: −1 is off to the
  /// left with the next month fully in, 1 off to the right with the one
  /// before fully in.
  late final _offset = AnimationController.unbounded(vsync: this);
  double _width = 1;

  @override
  void didUpdateWidget(_SwipeableMonth old) {
    super.didUpdateWidget(old);
    if (widget.month == old.month) return;
    final step = widget.month.isAfter(old.month) ? 1.0 : -1.0;
    // After a drag the new month is already in place (−1 + 1 = 0); after
    // the arrows or Today it starts on its side and slides in.
    _offset.value = context.reduceMotion
        ? 0
        : (_offset.value + step).clamp(-1.0, 1.0);
    unawaited(_settle(0));
  }

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  Future<void> _settle(double target) => _offset.animateTo(
    target,
    duration: context.motion(AppMotion.medium),
    curve: AppMotion.decelerate,
  );

  void _drag(DragUpdateDetails details) {
    final delta = (details.primaryDelta ?? 0) / _width;
    _offset.value = (_offset.value + delta).clamp(-1.0, 1.0);
  }

  Future<void> _release(DragEndDetails details) async {
    final velocity = details.primaryVelocity ?? 0;
    final at = _offset.value;
    final double target = velocity.abs() > _fling
        ? velocity.sign
        : at.abs() > 0.5
        ? at.sign
        : 0;
    // Never completes when a new drag stops it, which then decides instead.
    await _settle(target);
    // Left (−1) shows the next month.
    if (target != 0 && mounted) widget.onShift(-target.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final month = widget.month;
    Widget page(int delta, double at) => FractionalTranslation(
      translation: Offset(at, 0),
      child: widget.builder(DateTime(month.year, month.month + delta)),
    );
    return GestureDetector(
      onHorizontalDragStart: (_) => _offset.stop(),
      onHorizontalDragUpdate: _drag,
      onHorizontalDragEnd: (details) => unawaited(_release(details)),
      // A five-week month and a six-week one: the height eases between them.
      child: AnimatedSize(
        duration: context.motion(AppMotion.medium),
        curve: AppMotion.standard,
        alignment: Alignment.topCenter,
        child: LayoutBuilder(
          builder: (context, constraints) {
            _width = constraints.maxWidth;
            return AnimatedBuilder(
              animation: _offset,
              builder: (context, _) {
                final at = _offset.value;
                // Clipped, so the months slide under the page's padding.
                return ClipRect(
                  child: Stack(
                    children: [
                      page(0, at),
                      // Only while moving; it sizes nothing, so a taller
                      // neighbour is cut to this month's height meanwhile.
                      if (at != 0)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: ExcludeSemantics(
                            child: at < 0 ? page(1, at + 1) : page(-1, at - 1),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
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
