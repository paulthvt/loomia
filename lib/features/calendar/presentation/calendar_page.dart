import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/month_grid.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_form.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:loomia/features/calendar/presentation/week_view.dart';
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
/// day, or an event. In week view the columns are the days, so the day
/// pane only shows while an event is open ([eventOpen]).
class CalendarPage extends ConsumerWidget {
  const CalendarPage({this.pane, this.eventOpen = false, super.key});

  final Widget? pane;
  final bool eventOpen;

  /// How far the title's pickers reach, either side of today.
  static const int _pickYears = 10;

  Future<void> _pickTitle(BuildContext context, WidgetRef ref) async {
    final selection = ref.read(calendarSelectionProvider);
    final selector = ref.read(calendarSelectionProvider.notifier);
    final now = today();
    final first = DateTime(now.year - _pickYears, now.month);
    final last = DateTime(now.year + _pickYears, now.month + 1, 0);
    switch (selection.mode) {
      case CalendarMode.month:
        final month = await pickMonth(
          context,
          initial: selection.month,
          first: first,
          last: last,
        );
        if (month != null) selector.showMonth(month);
      case CalendarMode.week:
        final day = await pickDay(
          context,
          initial: selection.day,
          first: first,
          last: last,
        );
        if (day != null) selector.select(day);
    }
  }

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
    final selection = ref.watch(calendarSelectionProvider);
    final desktop = context.screenSize.isDesktop;
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final side = selection.mode == CalendarMode.week && !eventOpen
        ? null
        : pane;
    return CalendarView(
      events: ref.watch(provider),
      selection: selection,
      today: today(),
      onSelect: (day) {
        selector.select(day);
        // Desktop: an open event gives the pane back to the day.
        if (desktop && eventOpen) context.go(Routes.calendar);
      },
      onShift: (delta) => selector.shift(delta, firstDayOfWeek: firstDay),
      onToday: selector.toToday,
      onMode: selector.setMode,
      onPickTitle: () => unawaited(_pickTitle(context, ref)),
      onOpen: (event) => openEvent(context, event.id),
      onAdd: (day) => unawaited(_add(context, ref, day)),
      onRetry: () => ref.invalidate(provider),
      onRefresh: () => _refresh(context, ref),
      desktop: desktop,
      pane: side,
      // With a sidebar, Settings is its account block instead, and there
      // is no pull to refresh on a mouse: a button, as on Today.
      accountAction: context.screenSize.usesSideNavigation
          ? IconButton(
              onPressed: () => unawaited(_refresh(context, ref)),
              tooltip: AppLocalizations.of(context).contactsRefresh,
              icon: const Icon(Icons.refresh_rounded),
            )
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
/// and tablet: the month and the selected day, or the week strip and the
/// week's days, and an add button. Desktop: the month or the week's
/// columns on the left, [pane] on the right when there is one.
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
    this.onMode,
    this.onPickTitle,
    this.onRefresh,
    this.desktop = false,
    this.pane,
    this.accountAction,
    super.key,
  });

  /// Fixed, like the Contacts list, so a resized window narrows the month.
  static const double _paneWidth = 440;

  /// Desktop: the month column, padding included, stops growing here, so a
  /// wide window doesn't spread the days out of reach of each other. The
  /// week's columns take the full width.
  static const double _monthMax = 840;

  final AsyncValue<List<CalendarEvent>> events;
  final CalendarSelection selection;

  /// The device's today, local midnight.
  final DateTime today;

  final ValueChanged<DateTime> onSelect;

  /// −1 for the month (or week) before, 1 for the one after.
  final ValueChanged<int> onShift;
  final VoidCallback onToday;
  final void Function(CalendarEvent event) onOpen;

  /// Adds an event on the given day.
  final ValueChanged<DateTime> onAdd;
  final VoidCallback onRetry;

  /// Month or week. None in previews.
  final ValueChanged<CalendarMode>? onMode;

  /// The title's picker: a month, or a day whose week to show.
  final VoidCallback? onPickTitle;

  /// Pull to refresh, on mobile and tablet. None in previews.
  final Future<void> Function()? onRefresh;

  /// The desktop layout: the calendar beside [pane], or alone.
  final bool desktop;
  final Widget? pane;

  /// Top-bar entry to Settings, where there is no sidebar to hold it.
  final Widget? accountAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final week = selection.mode == CalendarMode.week;
    final firstDay = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    final days = weekDays(selection.day, firstDay);
    final title = week
        ? weekTitle(l10n, days)
        : l10n.calendarMonth(selection.month);
    final header = Row(
      children: [
        Expanded(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: _TitleButton(
              title: title,
              semantics: week
                  ? l10n.calendarChooseWeek(title)
                  : l10n.calendarChooseMonth(selection.month),
              style: desktop
                  ? theme.textTheme.displaySmall
                  : theme.textTheme.headlineSmall,
              onTap: onPickTitle,
            ),
          ),
        ),
        IconButton(
          onPressed: () => onShift(-1),
          tooltip: week
              ? l10n.calendarPreviousWeek
              : l10n.calendarPreviousMonth,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          onPressed: () => onShift(1),
          tooltip: week ? l10n.calendarNextWeek : l10n.calendarNextMonth,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        ?accountAction,
      ],
    );
    final switcher = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      spacing: AppSpacing.sm,
      children: [
        // Shrinks before Today does, its labels cut with "…" if need be.
        Flexible(
          child: SegmentedButton<CalendarMode>(
            segments: [
              for (final (mode, label) in [
                (CalendarMode.month, l10n.calendarViewMonth),
                (CalendarMode.week, l10n.calendarViewWeek),
              ])
                ButtonSegment(
                  value: mode,
                  label: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            selected: {selection.mode},
            onSelectionChanged: (modes) => onMode?.call(modes.single),
          ),
        ),
        TextButton(onPressed: onToday, child: Text(l10n.calendarToday)),
      ],
    );
    final counts = eventsPerDay(events.value ?? const []);
    final pager = week
        ? _SwipePager(
            anchor: days.first,
            onShift: onShift,
            builder: (delta) => WeekStrip(
              days: weekDays(
                DateTime(
                  days.first.year,
                  days.first.month,
                  days.first.day + DateTime.daysPerWeek * delta,
                ),
                firstDay,
              ),
              selected: selection.day,
              today: today,
              counts: counts,
              onSelect: onSelect,
            ),
          )
        : _SwipePager(
            anchor: selection.month,
            onShift: onShift,
            builder: (delta) => MonthGrid(
              month: DateTime(
                selection.month.year,
                selection.month.month + delta,
              ),
              selected: selection.day,
              today: today,
              counts: counts,
              onSelect: onSelect,
            ),
          );

    if (desktop) {
      final side = pane;
      const padding = EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xl,
      );
      final top = [
        header,
        const SizedBox(height: AppSpacing.md),
        switcher,
        const SizedBox(height: AppSpacing.lg),
      ];
      // The week's columns run to the bottom of the window, each scrolling
      // its own cards; the month scrolls as one.
      final calendar = week
          ? Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...top,
                  Expanded(
                    child: WeekColumns(
                      events: events,
                      days: days,
                      selected: selection.day,
                      today: today,
                      onSelect: onSelect,
                      onOpen: onOpen,
                      onRetry: onRetry,
                    ),
                  ),
                ],
              ),
            )
          : ListView(padding: padding, children: [...top, pager]);
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                // From the start edge, as the other desktop pages.
                child: week
                    ? calendar
                    : Align(
                        alignment: AlignmentDirectional.topStart,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _monthMax,
                          ),
                          child: calendar,
                        ),
                      ),
              ),
              if (side != null)
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
              const SizedBox(height: AppSpacing.sm),
              switcher,
              const SizedBox(height: AppSpacing.md),
              pager,
              const Divider(height: AppSpacing.xl),
              if (week)
                WeekList(
                  events: events,
                  days: days,
                  selected: selection.day,
                  today: today,
                  onOpen: onOpen,
                  onRetry: onRetry,
                )
              else
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

/// The Calendar's title, a button that opens its picker: the month, or the
/// week. One line, cut with "…" if it still doesn't fit.
class _TitleButton extends StatelessWidget {
  const _TitleButton({
    required this.title,
    required this.semantics,
    required this.style,
    required this.onTap,
  });

  final String title;
  final String semantics;
  final TextStyle? style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantics,
    excludeSemantics: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.xs,
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    ),
  );
}

/// A horizontal drag that claims the gesture at half the usual slop, so a
/// swipe whose first pixels lean down as much as sideways is the page's,
/// not the vertical scroll's around it, which still needs its full slop.
class _SidewaysDrag extends HorizontalDragGestureRecognizer {
  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) =>
      globalDistanceMoved.abs() >
      computeHitSlop(pointerDeviceKind, gestureSettings) / 2;
}

/// A page of the calendar (a month grid, a week strip) at [anchor], which
/// follows the finger: dragged sideways, the neighbouring page comes in
/// beside it, and on release the page turns (past halfway, or flung) or
/// springs back. The arrows and Today slide the new page in from its side
/// too. Reduce motion: they just switch.
class _SwipePager extends StatefulWidget {
  const _SwipePager({
    required this.anchor,
    required this.onShift,
    required this.builder,
  });

  /// What the page shows: the month's 1st, or the week's first day.
  final DateTime anchor;

  /// −1 for the page before, 1 for the one after.
  final ValueChanged<int> onShift;

  /// The page [delta] pages away from [anchor].
  final Widget Function(int delta) builder;

  @override
  State<_SwipePager> createState() => _SwipePagerState();
}

class _SwipePagerState extends State<_SwipePager>
    with SingleTickerProviderStateMixin {
  /// A release faster than this, in px/s, the way the page was dragged,
  /// turns it however short the drag was: a thumb's flick, not only a fling.
  static const double _fling = 100;

  /// Released slower, a drag past this share of the width still turns.
  static const double _past = 1 / 3;

  /// Where [_SwipePager.anchor]'s page sits, in page widths: −1 is off to
  /// the left with the next page fully in, 1 off to the right with the one
  /// before fully in.
  late final _offset = AnimationController.unbounded(vsync: this);
  double _width = 1;

  /// The side a released drag is turning to, until the page lands: −1, 1,
  /// or 0 when nothing is turning.
  double _turning = 0;

  /// [_grab] landed a turn and already moved the offset onto the new page,
  /// so the anchor change it causes must not move it again: the rebuild
  /// may come mid-drag, or (in a test) only after the new release.
  bool _rebased = false;

  @override
  void didUpdateWidget(_SwipePager old) {
    super.didUpdateWidget(old);
    if (widget.anchor == old.anchor) return;
    if (_rebased) {
      _rebased = false;
      return;
    }
    final step = widget.anchor.isAfter(old.anchor) ? 1.0 : -1.0;
    // After a drag the new page is already in place (−1 + 1 = 0); after
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

  /// A new drag stops whatever is moving. A page still turning lands now,
  /// so a quick second swipe turns another page instead of cancelling the
  /// first; the new drag goes on from where the page visibly is.
  void _grab() {
    _offset.stop();
    final turning = _turning;
    _turning = 0;
    if (turning == 0) return;
    // The new page's own offset: the next page sits one width right of
    // the old (−0.8 → 0.2). Left (−1) shows the next page.
    _offset.value -= turning;
    _rebased = true;
    widget.onShift(-turning.toInt());
  }

  Future<void> _release(DragEndDetails details) async {
    final velocity = details.primaryVelocity ?? 0;
    final at = _offset.value;
    // A flick back against the drag cancels it rather than turning the
    // other way.
    final double target =
        velocity.abs() > _fling && (at == 0 || velocity.sign == at.sign)
        ? velocity.sign
        : velocity.abs() > _fling
        ? 0
        : at.abs() > _past
        ? at.sign
        : 0;
    _turning = target;
    // Never completes when a new drag stops it; [_grab] turns it then.
    await _settle(target);
    if (_turning == 0 || !mounted) return;
    _turning = 0;
    widget.onShift(-target.toInt());
  }

  @override
  Widget build(BuildContext context) {
    Widget page(int delta, double at) => FractionalTranslation(
      translation: Offset(at, 0),
      child: widget.builder(delta),
    );
    return RawGestureDetector(
      gestures: {
        _SidewaysDrag: GestureRecognizerFactoryWithHandlers<_SidewaysDrag>(
          _SidewaysDrag.new,
          (drag) => drag
            ..onStart = ((_) => _grab())
            ..onUpdate = _drag
            ..onEnd = ((details) => unawaited(_release(details)))
            ..onCancel = () => unawaited(_settle(0)),
        ),
      },
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
    if (list == null) {
      body = [?eventsNotLoaded(context, events, onRetry)];
    } else {
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
