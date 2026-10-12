# Today progress — design

Issue: #292. Figma: [Today progress — #292](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=320-10151)
on "04 — Screens (Light)":

- mobile frames: in progress (320:10152) and all done (320:10199);
- desktop frames: in progress (320:10235) and all done (320:10355);
- all done, dark (320:10669).

`TodayHero` (35:92) lost `effortLabel` and gained `showProgress`.

## Intent

Ticking a row on Today makes it disappear, and nothing records that the day
moved on. The hero's progress bar puts that back: "1 of 3 done", and a white bar
that grows on each tick. It is the user's own list for the day, not a target, so
it is direction without pressure (principle #5).

`2026-09-29-today-due-steps-design.md` removed the bar and the effort label
"until their features exist". This spec brings the bar back on real data. The
effort label stays out.

## Decisions

| Question | Decision |
| --- | --- |
| What counts as done | A workflow step or reminder whose `activity` row (`kind in ('step', 'reminder')`) has `happened_on` = the device's today. It counts wherever it was ticked, on Today or on the contact page. Notes, calls, orders and other logged entries don't count, because they were never on Today's list. |
| What N is | Done today plus what is still on the list (`dueToday(...).length`, hidden rows and late ones included). Ticking a row moves it from one side to the other. The exception is a ticked step whose next step is also due today: that adds a row, and the total grows by one. |
| Unit | Rows, not people: Claire's reminder and Claire's step are two. The headline keeps counting people. The Figma frame already reads this way ("Two people…" over "1 of 3 done"). |
| Events | Not counted. The headline doesn't count them either, and event checklist ticks write no `activity`. Add them when the headline does. |
| Effort label | Dropped. Nothing knows how long an action takes, and a guess would be a fake number. |
| Where the count is computed | A client count query on `activity`, behind `ActivityRepository`. No migration, no RPC. The rule "steps and reminders done on day D" has one reader, Today. The daily summary counts what is still due, not what is done. |
| Moving on a tick | `TodayPage._tick` adds one to the count when `writePeople` succeeds. The book already dropped the row in that same microtask, so no frame shows "0 of 2" between "0 of 3" and "1 of 3". On failure nothing changes, as with the row. |
| Ticks made elsewhere | The count is `autoDispose`, like `goalsProvider`. A step ticked on the contact page shows when Today is opened again, because no route keeps Today built behind another screen. Pull to refresh also reloads it. |
| Day rollover | The count is keyed by `(owner, day)`. `_onResume` already rebuilds Today with the new `today()`, which reads a new key and fetches again. |
| Nothing left, something done | The hero stays: full bar, "3 of 3 done", headline "That's everyone for today". The empty state's body (`todayEmptyBody`) sits under the hero as a body-sm line in `text/secondary`. On mobile it goes after the goal line, 4px in. On desktop, where the goal is in the side column, it goes 8px under the hero. The up-to-date `EmptyState` is not shown. |
| Nothing due, nothing done | Unchanged: no hero, the up-to-date empty state. |
| Count loading or failed | No bar and no caption (`showProgress` off): the hero is the sentence alone, as it is now. No error is shown, because the list itself still works. Nothing due and no count yet: the up-to-date empty state. |
| Percentage | Never. A screen reader hears the caption ("1 of 3 done"), not the indicator's percentage. |

## 1. Data

No schema change. `ActivityRepository` gains:

```dart
/// Steps and reminders ticked on [day]: the activity rows those ticks write.
Future<int> doneOn(DateTime day);
```

It is a PostgREST `count` (head request) on `activity`. The filters are
`kind in ('step', 'reminder')` and `happened_on = day`. RLS scopes the count
to the owner.

`activity` has no index on `happened_on`. `ordersIn` already filters by date
without one. The query carries
`// ponytail: no (owner_id, happened_on) index; add one if this shows up slow`.

## 2. State

`doneTodayProvider` is an `AsyncNotifierProvider.autoDispose.family` keyed by
`({String? owner, DateTime day})`. It lives next to `TodayPage`, in
`lib/features/today/presentation/done_today.dart`:

- `build` returns 0 when signed out, else calls `doneOn(day)`, with no retry;
- `add()` increments the current value when there is one.

`TodayPage._refresh` also invalidates it.

## 3. Hero

`TodayHero` gains an optional `progress: ({int done, int total})?`. When it is
not null, the hero shows under the headline, `AppSpacing.ms` below it (the
Figma gap):

```dart
LoomiaProgressBar(
  tone: ProgressTone.primary,
  value: done / total,
  leadingLabel: l10n.todayDone(done, total),
)
```

It is wrapped in `Semantics(label: caption, excludeSemantics: true)`. The bar's
240ms tween is already in `LoomiaProgressBar`.

`TodayView` gains `int? done`:

- `done == null`: the hero renders without progress.
- `due` is not empty: `progress: (done: done, total: done + due.length)`. The
  headline is unchanged.
- `due` is empty and `done > 0`: the hero renders with
  `headline: l10n.todayAllDone` and full progress, with `todayEmptyBody`
  placed as in Decisions.
- `due` is empty and `done` is 0 or null: the up-to-date empty state, as now.

New copy in `app_en.arb`, each key with a description:

- `todayDone`: "{done} of {total} done". The hero's caption: rows ticked today
  out of today's list, never a target.
- `todayAllDone`: "That's everyone for today". The hero once everything on
  today's list is done.

## 4. Docs

`docs/design/components.md` #11:

- Props become `eyebrow`, `headline`, `progress`.
- The footer is the done count only.
- The rule changes from "Footer states effort in minutes" to "The footer
  counts today's own list, never a target and never a percentage".

## 5. Testing

- Widget, `TodayView`:
  - `done: 1` with two rows due shows "1 of 3 done";
  - `done: null` shows no bar;
  - nothing due and `done: 3` shows "That's everyone for today", "3 of 3 done"
    and the body, and no up-to-date title;
  - nothing due and `done: 0` shows the empty state as before.
- Widget, `TodayPage` through `pumpLoomia`:
  - the count comes from the activity fake;
  - a successful tick moves "0 of 1 done" to the all-done hero;
  - a failed tick leaves "0 of 1 done".
- `FakeActivityRepository.doneOn` counts its `step` / `reminder` entries on the
  day. The repository's query building isn't unit-tested, like the other
  repositories'.
- Goldens: the existing `today_*` previews with rows due change (the hero
  gains its bar). There is a new `todayAllDoneMobileLight` preview. Both are
  regenerated through CI.
