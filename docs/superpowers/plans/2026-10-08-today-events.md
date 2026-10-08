# Today's Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Today shows an Events section above Priority, only when it has something in it: today's events (with Join near the start of an online one), events that have started and still need "Mark who was there", and checklist steps due today or late, each ticked with the ring (#154).

**Architecture:** One pure function, `todayEvents(events, eventWorkflows, now)` in `lib/features/today/domain/today_events.dart`, picks the three lists. `TodayView` takes them and four callbacks and renders them through `todayEventItems(...)`, a list builder like `checkInItems`. `TodayPage` watches `eventsProvider`, `eventWorkflowsProvider` and the book, and wires the callbacks to the existing event screen, the "Who was there?" sheet, `EventsController.tick` and `openExternal`. No schema change.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3.

**Spec:** `docs/superpowers/specs/2026-10-07-calendar-design.md` §4 (Today), and the Join rule in Decisions ("Online"). Figma: [Calendar — #150](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=257-4672), frame "Today — mobile (events)".

## Global Constraints

- No new dependency. Don't touch `pubspec.lock`. Stage only changed files by path (never `git add -A` / `git add .`): the user keeps untracked local files.
- "Today" is the device's: `today()` and `DateTime.now()`.
- Dart: `package:loomia/...` imports; Material from `package:material_ui/material_ui.dart`; the domain imports no Flutter.
- Theme from `colorScheme`, `LoomiaColors`, `AppSpacing`, `AppRadii`; the ring is `IconButton(style: AppTheme.resolveRing(context))`; `FilledButton.tonal` takes `style: AppTheme.tonal(context)`.
- Copy: English only, in `lib/l10n/app_en.arb`, every key with a description; `flutter gen-l10n`. No string concatenation in the UI. Informal register; never "came", "recruit", or a score.
- Async UI handlers read `ref` / `context` values before the first `await`; a SnackBar on `PeopleFailure` through a messenger captured before the await (the house pattern).
- The hero headline keeps counting people only.
- Quality gate: `dart format .`, `flutter analyze` ("No issues found!"), full `flutter test`. Goldens from CI only.
- Branch `feature/154-today-events`; PR body `Closes #154`.

## Rulings made while planning

- **A 14-day window.** "Mark who was there" lists events that started in the last 14 days and aren't done. Checklist steps are listed when due from 14 days ago through today and not ticked. Older ones stay on the event's screen. Without a window, a forgotten workshop would sit on Today forever.
- **An event that has started and isn't done** shows once, as "How did … go?", not also as one of today's events.
- **Join** shows on today's row from 15 minutes before the start until the end, or until 2 hours after the start when there's no end time.
- **The existing Today goldens stay as they are.** A new preview, `todayEventsMobileLight`, shows the section.
- **`EventRow` gains an optional `trailing`**, which Today uses for Join.

## Review Focus

1. A step due before today and not ticked shows, and it disappears once ticked. A step due tomorrow doesn't show yet. Pinned in Task 1.
2. A done event shows neither as "How did … go?" nor through its steps once they're ticked. A started event with nobody invited isn't offered "Mark who was there" (`canMarkDone`). Pinned in Task 1.
3. Join appears at 18:45 for a 19:00 event with a link, and not at 18:44 or after the end. Pinned in Task 1.
4. With no due people (the up-to-date state), the Events section still shows. Pinned in Task 2.
5. Ticking a step from Today calls the same tick as the event screen, and a failure says so. Pinned in Task 2.

---

### Task 1: What Today shows from the calendar

**Files:**
- Create: `lib/features/today/domain/today_events.dart`
- Test: `test/features/today/domain/today_events_test.dart`

**Interfaces:**
- Consumes: `CalendarEvent`, `eventsOn`, `byStart`, `stepDue` (`lib/features/calendar/domain/calendar_event.dart`); `EventWorkflow`, `EventWorkflowStep`, `findEventWorkflow` (`lib/features/workflows/domain/event_workflow.dart`).
- Produces:

```dart
/// A checklist step due on [due] for [event].
typedef DueEventStep = ({
  CalendarEvent event,
  EventWorkflowStep step,
  DateTime due,
});

/// Today's Events section: today's events, those to mark, the steps due.
typedef TodayEvents = ({
  List<CalendarEvent> today,
  List<CalendarEvent> toMark,
  List<DueEventStep> steps,
});

const TodayEvents noTodayEvents = (today: [], toMark: [], steps: []);

extension TodayEventsEmpty on TodayEvents {
  bool get isEmpty => today.isEmpty && toMark.isEmpty && steps.isEmpty;
}

TodayEvents todayEvents(
  List<CalendarEvent> events,
  List<EventWorkflow> workflows,
  DateTime now,
);

/// Join is offered from 15 minutes before the start until the end (2 hours
/// after the start without an end time), for an event with a link.
bool canJoin(CalendarEvent event, DateTime now);
```

- [ ] **Step 1: Write the failing tests** `test/features/today/domain/today_events_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/today/domain/today_events.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';

final _workshop = EventWorkflow(
  id: 'workshop',
  name: 'Workshop',
  steps: const [
    EventWorkflowStep(id: 'remind', label: 'Remind', days: -1),
    EventWorkflowStep(id: 'thank', label: 'Thank', days: 1),
  ],
);

const _invited = [(personId: 'p1', came: false)];

CalendarEvent _event(
  String id,
  DateTime startsAt, {
  DateTime? endsAt,
  String? link,
  DateTime? doneAt,
  Map<String, DateTime> stepsDone = const {},
  List<Attendee> attendees = _invited,
  String? eventWorkflowId = 'workshop',
}) => CalendarEvent(
  id: id,
  title: id,
  startsAt: startsAt,
  endsAt: endsAt,
  link: link,
  doneAt: doneAt,
  stepsDone: stepsDone,
  attendees: attendees,
  eventWorkflowId: eventWorkflowId,
);

final _morning = DateTime(2026, 10, 8, 9);

void main() {
  test("today's events, earliest first; tomorrow's wait", () {
    final evening = _event('evening', DateTime(2026, 10, 8, 19));
    final lunch = _event('lunch', DateTime(2026, 10, 8, 12));
    final tomorrow = _event('tomorrow', DateTime(2026, 10, 9, 19));

    final shown = todayEvents([evening, tomorrow, lunch], const [], _morning);

    expect(shown.today, [lunch, evening]);
  });

  test('an event that started and is not done is to mark, once', () {
    final started = _event('started', DateTime(2026, 10, 8, 8));
    final yesterday = _event('yesterday', DateTime(2026, 10, 7, 19));
    final done = _event(
      'done',
      DateTime(2026, 10, 7, 10),
      doneAt: DateTime(2026, 10, 7, 12),
    );
    final nobody = _event('nobody', DateTime(2026, 10, 7, 9), attendees: const []);
    final old = _event('old', DateTime(2026, 9, 23, 19));

    final shown = todayEvents(
      [started, yesterday, done, nobody, old],
      const [],
      _morning,
    );

    expect(shown.toMark, [yesterday, started]);
    expect(shown.today, isEmpty);
  });

  test('steps due today or late, not ticked, within two weeks', () {
    // Due Oct 8 (remind for the 9th) and Oct 7 (thank for the 6th, whose
    // reminder was ticked).
    final friday = _event('friday', DateTime(2026, 10, 9, 19));
    final tuesday = _event(
      'tuesday',
      DateTime(2026, 10, 6, 19),
      doneAt: DateTime(2026, 10, 6, 21),
      stepsDone: {'remind': DateTime(2026, 10, 5)},
    );
    // Thank due Oct 9: tomorrow, not yet.
    final today = _event('today', DateTime(2026, 10, 8, 19));
    // Both ticked.
    final ticked = _event(
      'ticked',
      DateTime(2026, 10, 7, 19),
      doneAt: DateTime(2026, 10, 7, 21),
      stepsDone: {
        'remind': DateTime(2026, 10, 6),
        'thank': DateTime(2026, 10, 8),
      },
    );
    // Thank due Sep 21: too old.
    final old = _event('old', DateTime(2026, 9, 20, 19));
    // No checklist.
    final plain = _event('plain', DateTime(2026, 10, 7, 19), eventWorkflowId: null);

    final steps = todayEvents(
      [friday, tuesday, today, ticked, old, plain],
      [_workshop],
      _morning,
    ).steps;

    expect(
      [for (final due in steps) '${due.event.id}:${due.step.id}:${due.due.day}'],
      ['tuesday:thank:7', 'today:remind:7', 'friday:remind:8'],
    );
  });

  test('Join from 15 minutes before until the end', () {
    final online = _event(
      'online',
      DateTime(2026, 10, 8, 19),
      endsAt: DateTime(2026, 10, 8, 20),
      link: 'https://meet.google.com/abc',
    );

    expect(canJoin(online, DateTime(2026, 10, 8, 18, 44)), isFalse);
    expect(canJoin(online, DateTime(2026, 10, 8, 18, 45)), isTrue);
    expect(canJoin(online, DateTime(2026, 10, 8, 19, 59)), isTrue);
    expect(canJoin(online, DateTime(2026, 10, 8, 20)), isFalse);
  });

  test('without an end, Join lasts two hours; without a link, never', () {
    final open = _event('open', DateTime(2026, 10, 8, 19), link: 'https://x.io');
    final inPerson = _event('inPerson', DateTime(2026, 10, 8, 19));

    expect(canJoin(open, DateTime(2026, 10, 8, 20, 59)), isTrue);
    expect(canJoin(open, DateTime(2026, 10, 8, 21)), isFalse);
    expect(canJoin(inPerson, DateTime(2026, 10, 8, 19)), isFalse);
  });
}
```

The steps test's expected order is by due date, then by start: `tuesday:thank` is due Oct 7, `today:remind` Oct 7 (the 19:00 event starts after Tuesday's), and `friday:remind` Oct 8.

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/today/domain/today_events_test.dart`
Expected: FAIL, `today_events.dart` not found.

- [ ] **Step 3: Write it** `lib/features/today/domain/today_events.dart`

```dart
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';

/// How far back Today looks for events to mark and steps left undone. Older
/// ones stay on the event's screen.
const int todayEventsDays = 14;

/// Join opens this long before the start.
const Duration joinEarly = Duration(minutes: 15);

/// Without an end time, Join stays this long after the start.
const Duration joinWithoutEnd = Duration(hours: 2);

typedef DueEventStep = ({
  CalendarEvent event,
  EventWorkflowStep step,
  DateTime due,
});

typedef TodayEvents = ({
  List<CalendarEvent> today,
  List<CalendarEvent> toMark,
  List<DueEventStep> steps,
});

const TodayEvents noTodayEvents = (today: [], toMark: [], steps: []);

extension TodayEventsEmpty on TodayEvents {
  bool get isEmpty => today.isEmpty && toMark.isEmpty && steps.isEmpty;
}

/// What Today's Events section shows at [now]: today's events not yet to
/// mark; events started within [todayEventsDays] days that can be marked
/// done; and checklist steps due from [todayEventsDays] days ago through
/// today, not ticked. Each list earliest first.
TodayEvents todayEvents(
  List<CalendarEvent> events,
  List<EventWorkflow> workflows,
  DateTime now,
) {
  final day = DateTime(now.year, now.month, now.day);
  final from = DateTime(day.year, day.month, day.day - todayEventsDays);
  final toMark = byStart(
    events.where(
      (event) => event.canMarkDone(now) && !event.day.isBefore(from),
    ),
  );
  final today = [
    for (final event in eventsOn(events, day))
      if (!toMark.contains(event)) event,
  ];
  final steps = <DueEventStep>[
    for (final event in byStart(events))
      if (findEventWorkflow(workflows, event.eventWorkflowId) case final workflow?)
        for (final step in workflow.steps)
          if (!event.stepsDone.containsKey(step.id))
            if (stepDue(event, step) case final due
                when !due.isAfter(day) && !due.isBefore(from))
              (event: event, step: step, due: due),
  ]..sort((a, b) {
      final byDue = a.due.compareTo(b.due);
      return byDue != 0 ? byDue : a.event.startsAt.compareTo(b.event.startsAt);
    });
  return (today: today, toMark: toMark, steps: steps);
}

bool canJoin(CalendarEvent event, DateTime now) {
  if (event.link == null) return false;
  final opens = event.startsAt.subtract(joinEarly);
  final closes = event.endsAt ?? event.startsAt.add(joinWithoutEnd);
  return !now.isBefore(opens) && now.isBefore(closes);
}
```

`findEventWorkflow` takes a nullable id. If it doesn't, check `event.eventWorkflowId` for null first.

- [ ] **Step 4: Run the tests** — Expected: PASS (5).

- [ ] **Step 5: Commit**

```bash
git add lib/features/today/domain/today_events.dart test/features/today/domain/today_events_test.dart
git commit -m "feat(today): pick today's events, those to mark, and the steps due"
```

---

### Task 2: The Events section on Today

**Files:**
- Create: `lib/features/today/presentation/today_event_items.dart`
- Modify: `lib/features/today/presentation/today_page.dart`
- Modify: `lib/features/calendar/presentation/event_row.dart` (an optional `trailing`)
- Modify: `lib/features/calendar/presentation/event_page.dart` (extract `eventPeople`)
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/today/today_events_test.dart` (widget), plus the existing Today tests stay green.

**Interfaces:**
- Consumes: Task 1; `EventRow`, `whenLabel`, `timeLabel` (`event_row.dart`); `openEvent` (`calendar_page.dart`); `showWhoWasThere`, `EventPerson` (`who_was_there_sheet.dart`, `event_page.dart`); `eventsProvider` with `tick`; `eventWorkflowsProvider`; `peopleProvider`; `openExternal`; `stepTiming`; `SectionHeader`; `AppTheme.resolveRing`, `AppTheme.tonal`.
- Produces:
  - `List<EventPerson> eventPeople(CalendarEvent event, List<Person> book)`, moved from `EventPane.build` into a top-level function in `event_page.dart`, which `EventPane` now calls. It gives the attendees found in the book, sorted by name.
  - `EventRow({event, onTap, trailing})`.
  - `List<Widget> todayEventItems(BuildContext context, {required TodayEvents events, required DateTime now, required void Function(CalendarEvent) onOpen, required void Function(CalendarEvent) onMarkDone, required void Function(DueEventStep) onTick, required void Function(Uri) onJoin})`: the header and the rows, or nothing when `events.isEmpty`.
  - `TodayView` gains `this.events = noTodayEvents` and the four optional callbacks `onOpenEvent`, `onMarkDone`, `onTickStep` and `onJoin`.
  - l10n keys: `todaySectionEvents`, `todayHowDidItGo`, `todayStepFor`

- [ ] **Step 1: Add the copy**

```json
  "todaySectionEvents": "Events",
  "@todaySectionEvents": {
    "description": "Heading on Today, shown uppercased, above today's events, the events to mark who was there, and the event steps that are due."
  },
  "todayHowDidItGo": "How did {title} go?",
  "@todayHowDidItGo": {
    "description": "On Today, an event that has started and isn't marked done yet. title is the event's title, e.g. 'How did New member training go?'.",
    "placeholders": {
      "title": { "type": "String" }
    }
  },
  "todayStepFor": "{event} · {timing}",
  "@todayStepFor": {
    "description": "Second line of an event's checklist step on Today: the event's title, then when the step is due relative to it, e.g. 'Workshop · 1 day before'.",
    "placeholders": {
      "event": { "type": "String" },
      "timing": { "type": "String" }
    }
  }
```

- [ ] **Step 2: Write the failing tests** `test/features/today/today_events_test.dart`

Pump `TodayView` the way `today_goals_test.dart` does: a `MaterialApp` with the delegates and `AppTheme.light`, `due: AsyncData([...])`, `now: DateTime(2026, 10, 8, 18, 50)`, and the callbacks recorded. Use `TodayEvents` values built by hand:

```dart
final _online = CalendarEvent(
  id: 'e1',
  title: 'Essential oils for sleep',
  startsAt: DateTime(2026, 10, 8, 19),
  endsAt: DateTime(2026, 10, 8, 21),
  link: 'https://meet.google.com/abc',
  attendees: const [(personId: 'p1', came: false)],
);
final _training = CalendarEvent(
  id: 'e2',
  title: 'New member training',
  startsAt: DateTime(2026, 10, 6, 14),
  attendees: const [(personId: 'p1', came: false)],
);
const _remind = EventWorkflowStep(id: 'remind', label: "Remind everyone it's tomorrow", days: -1);
final TodayEvents _events = (
  today: [_online],
  toMark: [_training],
  steps: [(event: _online, step: _remind, due: DateTime(2026, 10, 7))],
);
```

Tests:
- **"the Events section sits above Priority"**: `find.text('EVENTS')` is above `find.text('PRIORITY')` (compare `getTopLeft(...).dy`). Today's row shows "Essential oils for sleep" and "7:00 PM". "How did New member training go?" shows with "Mark who was there". The step shows "Remind everyone it's tomorrow" and "Essential oils for sleep · 1 day before".
- **"each row does what it says"**: tapping the event's title calls `onOpenEvent(_online)`; "Join" calls `onJoin(Uri.parse('https://meet.google.com/abc'))`; "Mark who was there" calls `onMarkDone(_training)`; the step's ring (tooltip `Mark "Remind everyone it's tomorrow" done`, the existing `eventStepTick` key) calls `onTickStep` with that step.
- **"Join waits for 15 minutes before"**: with `now: DateTime(2026, 10, 8, 9)`, no "Join".
- **"nothing to show, no section"**: `events: noTodayEvents` gives no "EVENTS".
- **"up to date on people, the events still show"**: `due: const AsyncData([])` with `_events` shows "EVENTS" and the up-to-date empty state's title (`todayEmptyTitle`).
- **"the headline still counts people only"**: with one due person and `_events`, the hero reads the one-person headline (`todayHeadline(1)`, read the English from the ARB).
- **In the app** (`pumpLoomia` with `FakeEventRepository` and the default event workflows fake): an event today at 19:00 with `eventWorkflowId: 'workshop'`, created on a day where Workshop's `remind` (−1) is due today, i.e. the event is tomorrow at 19:00. On Today, tap the step's ring, and expect `events.calls` to contain `tick(e1:remind)` and the step to leave Today after the reload. Set `events.failWith = PeopleFailure.network` before a second event's tick, and expect the network failure copy (`peopleFailureNetwork`) in a SnackBar.

- [ ] **Step 3: Run them to see them fail**

- [ ] **Step 4: Small moves first**
- `event_row.dart`: `EventRow` gains `final Widget? trailing;` (doc: "Today's Join."), shown after the text column inside the row's `Row`.
- `event_page.dart`: move the attendee-to-book join and the sort from `EventPane.build` into:

```dart
/// [event]'s attendees found in [book], by name. Someone deleted from the
/// contacts on another device is left out rather than shown nameless.
List<EventPerson> eventPeople(CalendarEvent event, List<Person> book) {
  final byId = {for (final person in book) person.id: person};
  return [
    for (final attendee in event.attendees)
      if (byId[attendee.personId] case final person?)
        (person: person, came: attendee.came),
  ]..sort((a, b) => searchKey(a.person.name).compareTo(searchKey(b.person.name)));
}
```

and call it there. The event page tests must stay green.

- [ ] **Step 5: The items** `lib/features/today/presentation/today_event_items.dart`

```dart
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/today/domain/today_events.dart';
import 'package:loomia/features/workflows/presentation/event_step_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Today's EVENTS: today's events (Join near an online one's start), events
/// to mark who was there, then the checklist steps due. Nothing when there's
/// nothing to show.
List<Widget> todayEventItems(
  BuildContext context, {
  required TodayEvents events,
  required DateTime now,
  required void Function(CalendarEvent event) onOpen,
  required void Function(CalendarEvent event) onMarkDone,
  required void Function(DueEventStep step) onTick,
  required void Function(Uri link) onJoin,
}) {
  if (events.isEmpty) return const [];
  final l10n = AppLocalizations.of(context);
  final rows = <Widget>[
    for (final event in events.today)
      EventRow(
        event: event,
        onTap: () => onOpen(event),
        trailing: canJoin(event, now)
            ? FilledButton.tonal(
                style: AppTheme.tonal(context),
                onPressed: () => onJoin(Uri.parse(event.link!)),
                child: Text(l10n.eventJoin),
              )
            : null,
      ),
    for (final event in events.toMark)
      _Card(
        onTap: () => onOpen(event),
        title: l10n.todayHowDidItGo(event.title),
        subtitle: whenLabel(context, event),
        below: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonal(
            style: AppTheme.tonal(context),
            onPressed: () => onMarkDone(event),
            child: Text(l10n.eventMarkWhoWasThere),
          ),
        ),
      ),
    for (final due in events.steps)
      _Card(
        onTap: () => onOpen(due.event),
        title: due.step.label,
        subtitle: l10n.todayStepFor(due.event.title, stepTiming(l10n, due.step.days)),
        trailing: IconButton(
          onPressed: () => onTick(due),
          tooltip: l10n.eventStepTick(due.step.label),
          style: AppTheme.resolveRing(context),
          icon: const Icon(Icons.check_rounded),
        ),
      ),
  ];
  return [
    SectionHeader(title: l10n.todaySectionEvents),
    for (final (index, row) in rows.indexed) ...[
      if (index > 0) const SizedBox(height: AppSpacing.ms),
      row,
    ],
  ];
}

/// A card like EventRow's, for a line of text and an action.
class _Card extends StatelessWidget {
  const _Card({
    required this.onTap,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.below,
  });

  final VoidCallback onTap;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      side: BorderSide(color: colors.borderSubtle),
    );
    return Material(
      color: colors.surfaceDefault,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.ms,
            children: [
              Row(
                spacing: AppSpacing.ms,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: AppSpacing.xs,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
              ?below,
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: `TodayView` and `TodayPage`** (`today_page.dart`)
- `TodayView` gains `this.events = noTodayEvents`, `this.onOpenEvent`, `this.onMarkDone`, `this.onTickStep` and `this.onJoin`, documented like the other fields.
- In `build`, `final eventItems = todayEventItems(context, events: widget.events, now: widget.now, onOpen: widget.onOpenEvent ?? (_) {}, onMarkDone: widget.onMarkDone ?? (_) {}, onTick: widget.onTickStep ?? (_) {}, onJoin: widget.onJoin ?? (_) {});` and a spaced version: `final eventsBlock = [if (eventItems.isNotEmpty) ...[...eventItems, SizedBox(height: desktop ? AppSpacing.xl : AppSpacing.lg)]];`.
- Insert `...eventsBlock` in `content`:
  - in the empty branch before `const _UpToDate()`;
  - in the error and loading branches before their widget;
  - in `_due` after `...goalWidgets`, replacing the `SizedBox` before Priority's header with the events block when it isn't empty, and keeping that `SizedBox` when it is.

  Pass `eventsBlock` into `_due` as a parameter.
- `TodayPage.build`: watch `eventsProvider(account?.email)` and `eventWorkflowsProvider(account?.email)`. Compute `events` as `todayEvents(list, workflows, DateTime.now())` when both have values, else `noTodayEvents`. A failed calendar load simply doesn't show events: Today's own error state stays about people. Wire:
  - `onOpenEvent: (event) => openEvent(context, event.id)`
  - `onMarkDone: (event) => unawaited(showWhoWasThere(context, event: event, people: eventPeople(event, people.value ?? const [])))`. Only offer it once the book has loaded: when `people.value == null`, pass `toMark: const []` in the `TodayEvents` handed to the view.
  - `onTickStep: (due) => unawaited(_tickStep(due))`, a method that reads the events notifier, messenger and l10n before awaiting `tick(due.event.id, due.step.id, today())`, and shows `peopleFailureCopy` in a SnackBar on `PeopleFailure`.
  - `onJoin: (link) => unawaited(openExternal(context, link))`.

  Match `showWhoWasThere`'s real signature. It may take `followUpNames` or resolve names itself since #153's fixes; read it.
- The pull to refresh (`_refresh`) also invalidates `eventsProvider(owner)`.

- [ ] **Step 7: Run the tests**

Run: `flutter test`
Expected: PASS. The existing Today goldens don't change: their previews pass no events.

- [ ] **Step 8: Commit**

```bash
git add <the files you changed>
git commit -m "feat(today): today's events, events to mark, and steps due"
```

---

### Task 3: Preview, golden, and the push

**Files:**
- Modify: `lib/features/today/presentation/today_preview.dart`, `test/previews_test.dart`
- Golden (from CI only): `today_events_mobile_light.png` (new). No other golden should change.

- [ ] **Step 1: The preview.** Add `@Preview(group: 'Today', name: 'Events — light', size: Size(390, 844)) Widget todayEventsMobileLight()`, built as the existing `_app` with three due people and these `events`:
  - today: "Essential oils for sleep" at 19:00 with a link and 6 invited;
  - to mark: "New member training", Tuesday 14:00, 3 invited;
  - a step: "Remind everyone it's tomorrow" for "Product evening".

  Use `now` 18:50 on the preview's fixed day, so Join shows. Keep the other previews unchanged.
- [ ] **Step 2:** Add `'today_events_mobile_light': (const Size(390, 844), todayEventsMobileLight),` to `test/previews_test.dart`. Run `flutter test test/previews_test.dart`.
- [ ] **Step 3: The quality gate:** `dart format . && flutter analyze && flutter test`.
- [ ] **Step 4: Commit and push**

```bash
git add lib/features/today/presentation/today_preview.dart test/previews_test.dart
git commit -m "test(today): preview the Events section"
git push -u origin feature/154-today-events
```

(If the push fails with "Connection closed … port 443": `git -c credential.helper= -c credential.helper='!gh auth git-credential' push -u https://github.com/paulthvt/loomia.git feature/154-today-events`.)

- [ ] **Step 5: Goldens from CI**

`gh workflow run CI --ref feature/154-today-events -f update-goldens=true`, then `gh run watch`, then download to `/tmp/goldens-154`. Copy only the PNGs that differ (`cmp`). It should be only the new `today_events_mobile_light.png`; report any other. Commit (`test(today): add the Events golden`) and push.

The PR is opened by the controller after the final review.
