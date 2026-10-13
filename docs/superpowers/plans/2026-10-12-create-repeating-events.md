# Create Repeating Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** New event can repeat every 1, 2 or 4 weeks, forever or until a day. Each occurrence is a real `event` row, generated a year ahead in Postgres when the calendar loads. The event page says how it repeats, people added to an occurrence join the following ones, and Today asks "How did … go?" once per series (#298, epic #297).

**Architecture:** Migration `repeating_events`: `event_series` (the rule and template), `event_series_attendee`, `event.series_id` / `event.series_on`, `extend_event_series(p_today)` and `set_series_attendees(p_event, p_add, p_remove)`. `EventRepository.list` calls `extend_event_series` with the device's today before reading, and embeds `event_series(id, every_weeks, first_on, until_on)`. `addSeries` inserts the series row; the controller reloads and returns the first occurrence. `EventsController.invite` / `uninvite` go through `set_series_attendees` for an occurrence. `todayEvents` keeps a series' latest occurrence only.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase (Postgres, pgTAP), `flutter_timezone` (already a dependency).

**Spec:** `docs/superpowers/specs/2026-10-12-repeating-events-design.md`. Figma: [Repeating events — #297](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=323-8181): frames 323:8183, 323:8410, 323:8637, 323:8849.

## Global Constraints

- One migration, `supabase migration new repeating_events`. RLS, owner policies, `revoke all` then grants, composite FKs and their indexes, in that migration. pgTAP in `supabase/tests/event_series_test.sql`.
- The rule lives in Postgres. `FakeEventRepository.addSeries` is the only Dart copy (test-only), weekly steps from the first day.
- No new dependency. Stage only changed files by path.
- Copy: English only, `app_en.arb`, every key described; `flutter gen-l10n`.
- Quality gate: `dart format .`, `flutter analyze`, `flutter test`, `supabase test db`. Goldens through CI.
- Branch `feature/298-repeating-events`; PR body `Closes #298`, `Part of #297`.

## Rulings made while planning

- **People on an occurrence reach the following ones in #298.** Without it a new weekly call has nobody on its later weeks: people are added on the event page, after it is created. `set_series_attendees` moves from #299 to here; #299 adds the "This event / This and following" choice in front of it.
- **Repeat only on New event.** Editing an occurrence changes that occurrence; making an existing event repeat (`repeat_event`) stays in #299.
- **`list()` keeps its signature** and reads `today()` itself, as other repositories pass the device's day.
- **The zone comes from `deviceTimeZoneProvider`** (notifications). Null (unreadable) fails the save with `PeopleFailure.unknown` rather than guess UTC and shift every start.
- **`repeatLine` is presentation**, in `event_row.dart` next to the other event copy helpers: it needs `AppLocalizations`.
- **Ends before the first day** is refused under Ends on Save ("Pick a day after the first one"), since the date can change after Ends was picked.

## Review Focus

1. 19:00 stays 19:00 across the October DST change; generating twice adds nothing; a deleted occurrence never comes back. Task 1.
2. People added on an occurrence join every not done occurrence from it on, and the series. Tasks 1 and 3.
3. Today shows one "How did … go?" per series. Task 4.

---

### Task 1: Migration

**Files:** Create `supabase/migrations/<ts>_repeating_events.sql`, `supabase/tests/event_series_test.sql`.

- [x] **Step 1: Failing pgTAP**: RLS on both tables (another owner sees nothing); every 1 and 2 weeks from `first_on`; stops at `until_on` and at `p_today + 365`; a second run adds nothing; a deleted occurrence is not regenerated; `Europe/Paris` 19:00 on Oct 20 and Oct 27 2026 (DST ends Oct 25) is 17:00 then 18:00 UTC; series people are copied; `set_series_attendees` adds to this and later not done occurrences, not earlier ones nor done ones, and removes the same way; an event outside a series is refused.
- [x] **Step 2: Migration** per the spec's §1, with `generated_until` nullable (null: none yet), the `check_time_zone` trigger, and the two functions (`security invoker`, `search_path = ''`, `authenticated` only).

### Task 2: Model and repository

**Files:** `lib/features/calendar/domain/calendar_event.dart`, `lib/features/calendar/data/event_repository.dart`, `test/features/calendar/fake_event_repository.dart`, `test/features/calendar/data/event_repository_test.dart`.

- [x] **Step 1: Failing tests**: `eventFromRow` reads the `event_series` embed; `seriesToRow(draft, rule, zone)` writes `first_on`, `starts_time`, `minutes`, `time_zone`, `every_weeks`, `until_on` and the template.
- [x] **Step 2:** `typedef EventSeries = ({String id, int everyWeeks, DateTime firstOn, DateTime? untilOn})`, `typedef RepeatRule = ({int everyWeeks, DateTime? untilOn})`; `CalendarEvent.series`. Repository: `list()` runs `extend_event_series` first; `addSeries(draft, rule, zone)` returns the series id; `setSeriesPeople(eventId, add, remove)`.
- [x] **Step 3: Fake**: `addSeries` generates the occurrences up to `today() + 365` (or the end day); `setSeriesPeople` as the SQL.

### Task 3: Controller and form

**Files:** `calendar_controller.dart`, `event_form.dart`, `event_page.dart`, `event_row.dart`, `app_en.arb`, their tests.

- [x] **Step 1: Failing tests**: New event with Every week saves a series and resolves to its first occurrence; Ends On a day before the first day is refused; the event page shows "Every week on Tuesday · until December 15"; Add people on an occurrence calls `setSeriesPeople`, on a single event `invite`.
- [x] **Step 2: Copy**: `eventRepeat`, `eventRepeatNever`, `eventRepeatEvery`, `eventRepeatLine`, `eventRepeatUntil`, `eventRepeatEnds`, `eventRepeatEndsNever`, `eventRepeatEndsOn`, `eventRepeatEndsBeforeStart`.
- [x] **Step 3: Form**: under the times, new events only: Repeat chips (Doesn't repeat · Every week · Every 2 weeks · Every 4 weeks) with the repeat line under them; Ends chips (Never · On a day, `pickDay` from the first day) with the day under them. Save with a rule calls `addRepeating`.
- [x] **Step 4: Page and controller**: `repeatLine` under the when line (`Icons.repeat_rounded`); `invite` / `uninvite` pick `setSeriesPeople` for an occurrence.

### Task 4: Today

**Files:** `lib/features/today/domain/today_events.dart`, its test.

- [x] **Step 1: Failing unit test**: three past occurrences of one series with a mapping and a single event: `toMark` is the latest occurrence and the single event.
- [x] **Step 2:** keep the latest per `series.id`.
- [x] **Step 3: Gate**, previews (the calendar preview gains a repeating event's line on the event page preview), goldens through CI, PR.

## Found while implementing

- **`list(DateTime today)` takes the day after all.** `today()` lives in `core/ui/pick_day.dart`; the controller passes it rather than a data class importing UI code. Supersedes the ruling above.
- **"Repeat ends", not "Ends".** The end-time field above is already labelled "Ends" (`eventEnds`); two "Ends" in one form read as the same thing. Figma frames 323:8183 / 323:8410 say "Ends".
- **No preview or golden changed.** `EventForm` has no `@Preview`, and the event page previews show single events. Task 4 Step 3's preview change was dropped.
- **Not pinned by a widget test:** "Pick a day after the first one" (driving two platform pickers for a one-line comparison). The check sits in `_submit`, next to the end-time one.
- **Not run against PostgREST locally** (only the database container runs here): the `event_series(...)` embed and the two RPCs are covered by pgTAP and the row-mapping tests, not by a live request.
