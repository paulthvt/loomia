# Edit Repeating Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On an occurrence of a repeating event, Save, Delete, Add people and Remove ask "This event" or "This and following events"; a single event can be made to repeat. Done occurrences are never touched (#299, epic #297).

**Architecture:** Migration `edit_repeating_events` adds `repeat_event`, `update_event_series` and `end_event_series` (`set_series_attendees` shipped in #298). `EventRepository` gains `repeat`, `updateSeries`, `endSeries`; `EventsController` gains `repeat`, `saveFollowing`, `endSeries`, and `invite` / `uninvite` take `following`. `pickScope` (`scope_dialog.dart`) is the one dialog, used by the form and the event page.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase (Postgres, pgTAP).

**Spec:** `docs/superpowers/specs/2026-10-12-repeating-events-design.md` (§1 functions, §3 scope dialog, §6 PR 2). Figma: [Repeating events — #297](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=323-8181): frames 323:8690, 323:8743, 323:8796, 323:9051.

## Global Constraints

- One additive migration: three new functions, `security invoker`, `search_path = ''`, `authenticated` only. Safe for the released app; `supabase db push` at merge, before or after the app release.
- pgTAP in `supabase/tests/event_series_edit_test.sql`.
- No new dependency. Copy in `app_en.arb` only, every key described.
- Branch `feature/299-edit-repeating-events`; PR body `Closes #299`, `Part of #297`.

## Rulings made while planning

- **`update_event_series` takes the form's instants, not `p_first_on`.** `p_starts_at` / `p_ends_at` read in the series' zone give the day, the local time and the minutes, so the client sends what it already has. Same rule means same weeks, same end day and the occurrence's current day; anything else regenerates from the new day.
- **It returns the event now in the occurrence's place** (itself in place, the first regenerated one otherwise), so the form resolves to an event that exists. `repeat_event` returns the series id.
- **In place, the occurrence edited keeps the instants typed**; the following ones take the new time on their own `series_on`.
- **No "Doesn't repeat" on an occurrence.** Stopping a series is Delete → This and following; turning the rest into one single event would need a series split. `ponytail:` in the form.
- **Repeat on Edit for a single event** saves the row, then `repeat_event`. Two calls, not one transaction: a failed second call leaves the edit saved and says so.
- **The scope is asked before the spinner**, so Cancel returns to the form with nothing saved.
- **Add people and Remove ask with Save**, not a red action: neither deletes the event.

## Review Focus

1. A new rule regenerates from the new day and never deletes or changes a done occurrence. Task 1.
2. Ending from the first occurrence drops the series; done ones stay without it. Task 1.
3. "This event" is off when the rule or day changed. Task 3.

---

### Task 1: Migration

**Files:** Create `supabase/migrations/20261019190841_edit_repeating_events.sql`, `supabase/tests/event_series_edit_test.sql`.

- [x] **Step 1: Failing pgTAP**: in place from an occurrence: earlier and done ones keep their title, later ones take the time across the October clock change, their people stay, the series takes the template; a new rule (every 2 weeks) regenerates and keeps a done one; a new day regenerates from it; ending from the middle sets `until_on` and nothing comes back; ending from the first drops the series, the done one stays without it; `repeat_event` links the event as the first occurrence, its people reach the following ones; refusals: repeating twice, a done event, outside a series, another owner's.
- [x] **Step 2: Migration** per the rulings.

### Task 2: Repository and controller

**Files:** `event_repository.dart`, `calendar_controller.dart`, `test/features/calendar/fake_event_repository.dart`, `calendar_controller_test.dart`.

- [x] **Step 1: Failing tests**: `invite` / `uninvite` with and without `following`; `saveFollowing` in place and with a new rule; `endSeries`; `repeat`.
- [x] **Step 2:** the three RPCs; the controller methods reload and resolve to the event by id. The fake copies the SQL (occurrence ids are `<series>-<yyyymmdd>`).

### Task 3: Scope dialog, form and event page

**Files:** `scope_dialog.dart`, `event_form.dart`, `event_page.dart`, `app_en.arb`, `event_form_test.dart`, `event_page_test.dart`.

- [x] **Step 1: Copy**: `eventScopeChangeTitle`, `eventScopeDeleteTitle`, `eventScopeThis`, `eventScopeFollowing`, `eventScopeRuleChanged`.
- [x] **Step 2: Failing widget tests**: a single event made to repeat; Save on an occurrence asks, This event and This and following; a new repeat disables This event and shows the note; Cancel keeps the form; Delete asks once, both scopes; Add people and Remove ask.
- [x] **Step 3:** `pickScope` (`LoomiaDialog`, radios, red Delete when deleting); the form shows Repeat on any event not done, pre-filled on an occurrence; the page asks on Delete, Add people and Remove of a not done occurrence.
- [x] **Step 4: Gate**: `dart format .`, `flutter analyze`, `flutter test`, the pgTAP files.

## Found while implementing

- **No preview or golden.** `EventForm` has none and the dialog follows; the Figma frames are the reference. Supersedes the spec's "the dialog" golden.
- **pgTAP run with `psql` against the local database**: `supabase db reset` fails here on the first migration (`set_updated_at already exists`, before any migration of this branch runs), so the migrations were applied one by one and every file in `supabase/tests/` run directly. `supabase db lint` reports nothing new.
