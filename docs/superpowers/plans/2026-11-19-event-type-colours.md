# Event Type Colours Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every event type has a tag-palette colour, and events show it on Today, the calendar's lists and its hour grids, quieter once over (#516).

**Architecture:** A nullable `event_workflow.color` (`public.tag_color`), filled by a `before insert` trigger and backfilled, so old clients and seeds keep working. The event query embeds `event_workflow(color)`, so `CalendarEvent.color` reaches every widget without threading the type list; one resolver, `eventInk`, turns it into the type's `TagInk` or the accent's. The type editor reuses the tags' swatch row, lifted into `lib/core/ui/`.

**Tech Stack:** Flutter, `material_ui`, `flutter_riverpod` (no codegen), Supabase (Postgres, PostgREST), pgTAP.

**Spec:** `docs/superpowers/specs/2026-11-19-event-type-colours-design.md`

## Global Constraints

- Branch `feature/516-event-type-colours` off `main`; Conventional Commits; PR body `Closes #516`, the template's **Database** section filled: `supabase db push` at merge (Release workflow), before the app build, released app keeps working (additive only), no Edge Function deploy.
- Migration through `supabase migration new event_workflow_color`; it must pass `bash tool/check_migrations.sh` (no `set not null`, no drop, no rename).
- No new dependency. Imports `package:loomia/...`, Material from `package:material_ui/material_ui.dart`.
- Widgets read `Theme.of(context).colorScheme`, `LoomiaColors.of(context)`, `TagColor.of(context)`, `AppSpacing.*`, `AppRadii.*`; no literal colour.
- No red: only the 8 `TagColor` keys, or the accent (`primary` / `primaryContainer`) for an event with no type.
- Past ("over") bar: the type's `ink` at opacity **0.5**. Grid fill when upcoming: the type's `container`.
- Copy in `lib/l10n/app_en.arb` only, with a description; French comes from Weblate.
- Goldens are regenerated through CI only (README.md → *Golden tests*); never commit local goldens.
- Before calling a task done: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`; for Task 1 also `supabase test db`.

## Rulings made while planning

- **Month dots stay white.** `DayCell` dots only ever draw on the hero gradient (`onHero: true` on phone and tablet); a 6 dp dot in a type colour fails 3:1 against rosewood → apricot in both modes. Mockup 5 was drawn on white by mistake. Dots unchanged; spec updated.
- **No event page dot.** The event page shows no type line to put it before. Dropped; spec updated.
- **Nullable column.** `set not null` is a "tighter column" for the migration guard. The trigger fills every insert and the backfill every existing row, so null never occurs; Dart falls back to `TagColor.stone` if it ever does.
- **`create` sends no colour.** The trigger picks it, so `EventWorkflowRepository.create` is unchanged; the fake mirrors the rule with `TagColor.firstFree`.
- **Colour on the event, not looked up.** `eventFromRow` reads `row['event_workflow']?['color']`; `EventWorkflowsController.edit` already invalidates `eventsProvider`, so a colour change reaches the calendar.
- **Quiet rule.** Lists keep #451 (`isOver(now)`). Grid cards and desktop month chips: quiet when `done || isOver(now)` (today: `done` only). Spec says "one rule everywhere" → this is that rule plus done, which can only be true once started.

## Review Focus

- An event whose type was deleted (`event_workflow_id` null after `on delete set null`): accent colours, no crash. → Task 2 `eventFromRow` test, Task 3 resolver test.
- Dark mode: grid fill is the dark `container`, bar the dark `ink`. → Task 4 test pumps `AppTheme.dark` too.
- An event with no end that has started, on the grid: quiet (`isOver` uses the start when there is no end), even though its block is drawn an hour tall. → Task 4 test.
- A ninth type when all 8 colours are used: `stone`, in SQL and in Dart. → Task 1 pgTAP, Task 2 unit test.
- Seeded defaults (`seed_workflows`) insert five types with no colour: they get stone, sand, olive, sage, teal in insertion order. → Task 1 pgTAP.

---

### Task 1: Database — `event_workflow.color`

**Files:**
- Create: `supabase/migrations/<timestamp>_event_workflow_color.sql` (via `supabase migration new event_workflow_color`)
- Create: `supabase/tests/event_workflow_color_test.sql`

**Interfaces:**
- Produces: column `public.event_workflow.color public.tag_color` (nullable, always filled); trigger function `public.event_workflow_default_color()`.

- [x] **Step 1: Write the failing pgTAP test** `supabase/tests/event_workflow_color_test.sql`, shaped like `tags_test.sql` (two users, `set local role authenticated`, jwt claims):
  - `has_column('public', 'event_workflow', 'color', ...)`
  - user A inserts `('One')` with no colour → `results_eq` its color is `'stone'`
  - user A inserts `('Two')` → `'sand'`; inserts `('Three', color => 'violet')` → stays `'violet'`
  - user A inserts six more with no colour (`Four` … `Nine`) → `results_eq` on `(name, color)` ordered by `color, name` matches: One stone, Two sand, Four olive, Five sage, Six teal, Seven sky, Eight indigo, Three violet, Nine stone (first unused, all used → stone). Compare by name, not `created_at`: every row in one test transaction has the same `now()`.
  - user B's first type with no colour is `'stone'` (the rule is per owner)
  - `plan(6)`: a third user runs `select public.seed_workflows('en', current_date)` → `(name, color)`: Workshop stone, Wellness check sand, Unboxing call olive, Wellness consultation sage, Mentoring teal (insertion order inside the function)
- [x] **Step 2: Run** `supabase test db` — Expected: FAIL, column `color` does not exist.
- [x] **Step 3: Write the migration**:
  - `alter table public.event_workflow add column color public.tag_color;` with a comment naming #516.
  - Backfill: per owner, by `created_at, id`, the n-th type (1-based) gets `(enum_range(null::public.tag_color))[n]` for n ≤ 8, else `'stone'` (equal to first-unused when none had a colour). Types seeded in one transaction share a `created_at`, so their order among themselves is arbitrary; they still get distinct colours.
  - `create function public.event_workflow_default_color() returns trigger language plpgsql set search_path = ''`: when `new.color is null`, set it to the first value of `enum_range(null::public.tag_color)` not used by another `event_workflow` of `new.owner_id`, else `'stone'`. Trigger `before insert on public.event_workflow for each row`.
  - No grant change (table-level grants to `authenticated` already cover the column).
- [x] **Step 4: Run** `supabase test db` — Expected: PASS, including `schema_rls_test.sql` and `new_defaults_test.sql` / `mentorat_defaults_test.sql`. Run `bash tool/check_migrations.sh supabase/migrations/*_event_workflow_color.sql` — Expected: no output, exit 0.
- [x] **Step 5: Commit** `feat(workflows): give every event type a colour (#516)`.

### Task 2: Domain and data — colours on types and events

**Files:**
- Modify: `lib/app/theme/app_colors.dart` (`TagColor`)
- Modify: `lib/features/contacts/domain/tag.dart:19-27` (`nextTagColor`)
- Modify: `lib/features/workflows/domain/event_workflow.dart`
- Modify: `lib/features/workflows/data/event_workflow_repository.dart`
- Modify: `lib/features/calendar/domain/calendar_event.dart`
- Modify: `lib/features/calendar/data/event_repository.dart:19-22`, `eventFromRow`
- Modify: `test/features/workflows/fake_event_workflow_repository.dart`
- Test: `test/features/contacts/domain/tag_test.dart`, `test/features/workflows/data/event_workflow_repository_test.dart`, `test/features/calendar/data/` (the existing `eventFromRow` test file, or `test/features/calendar/domain/calendar_event_test.dart` if that is where row mapping is tested)

**Interfaces:**
- Produces:
  - `static TagColor TagColor.firstFree(Iterable<TagColor> used)` — first key not in `used`, all used → `TagColor.values.first`.
  - `nextTagColor(tags)` = `TagColor.firstFree(tags.map((t) => t.color))` (behaviour unchanged).
  - `EventWorkflow.color` (`TagColor`, constructor param `this.color = TagColor.stone`).
  - `EventWorkflowRepository.setColor(String id, TagColor color) -> Future<void>`; `eventWorkflowFromRow` reads `row['color']` by name, null → `TagColor.stone`.
  - `CalendarEvent.color` (`TagColor?`, null = no type), copied by `withReport`.
  - `_columns` gains `event_workflow(color)`; `eventFromRow` reads `(row['event_workflow'] as Map?)?['color']`.

- [x] **Step 1: Failing tests**:
  - `tag_test.dart`: `TagColor.firstFree([])` is `stone`; `firstFree([stone, sand])` is `olive`; `firstFree(TagColor.values)` is `stone`.
  - repository test: `eventWorkflowFromRow({'id': 'w', 'name': 'Workshop', 'color': 'violet'})` has `color == TagColor.violet`; without `'color'` → `stone`.
  - event row mapping: a row with `'event_workflow': {'color': 'sky'}` → `color == TagColor.sky`; `'event_workflow': null` → `null`.
- [x] **Step 2: Run** `flutter test test/features/contacts/domain/tag_test.dart test/features/workflows/data test/features/calendar` — Expected: FAIL (undefined `firstFree`, `color`).
- [x] **Step 3: Implement** the Produces list. In the fake: `create` assigns `TagColor.firstFree(store.map((w) => w.color))`; add `setColor` recording `setColor($id, ${color.name})`; every `_change` rebuild passes `color: workflow.color` (and `setColor` passes the new one).
- [x] **Step 4: Run** `flutter test` — Expected: PASS.
- [x] **Step 5: Commit** `feat(workflows): read event type colours (#516)`.

### Task 3: Type editor — the colour row, and the resolver

**Files:**
- Create: `lib/core/ui/tag_color_picker.dart`
- Modify: `lib/features/contacts/presentation/tags_settings.dart:220-290` (use the picker; delete `_Swatch`)
- Modify: `lib/features/workflows/presentation/event_workflow_editor.dart`
- Modify: `lib/features/calendar/presentation/event_row.dart` (resolver)
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/workflows/presentation/event_workflow_editor_test.dart`, `test/features/calendar/presentation/event_row_test.dart`

**Interfaces:**
- Consumes: Task 2's `EventWorkflow.color`, `setColor`, `CalendarEvent.color`.
- Produces:
  - `TagColorPicker({required TagColor selected, required ValueChanged<TagColor>? onPick, super.key})` — the `Wrap` of swatches tags settings has today (32 dp circle in `container`, 1 px `ink` border; picked: 3 px `onSurface` border and a check in `ink`; 48 dp tap target; `Semantics(button, selected, label: tagColorName(...))`). `onPick` null disables.
  - `EventWorkflowEditorView.onColor` (`Future<void> Function(TagColor color)`, required), wired in `EventWorkflowEditor` to `editEventWorkflows(ref, (r) => r.setColor(workflow.id, color))`; `_Control.color` guards it like `group`.
  - `TagInk eventInk(BuildContext context, CalendarEvent event)` in `event_row.dart`: `event.color?.of(context)`, else `(container: scheme.primaryContainer, ink: scheme.primary)`.
  - ARB key `eventWorkflowColor`: `"Colour"`, description: "Label above the swatches in the event type editor: the colour its events take in the calendar and on Today."

- [x] **Step 1: Failing tests**:
  - editor: `'Colour: tapping a swatch saves it'` — open an event type (fake store colour `sky`), the swatch labelled `Violet` (via `tagColorName`) is tapped → fake `calls` contains `setColor(<id>, violet)`, and the `Violet` swatch's semantics is selected after reload.
  - event_row_test: `'eventInk: the type's colours, the accent without one'` — under `AppTheme.light`, an event with `color: TagColor.sage` gets `TagColor.sage.light`; with `color: null` gets `(primaryContainer, primary)` of `AppColors.light`.
  - Existing tags settings tests still pass (picker lifted, not changed).
- [x] **Step 2: Run** the two test files — Expected: FAIL.
- [x] **Step 3: Implement.** In the editor, put `LabeledField(label: l10n.eventWorkflowColor, child: TagColorPicker(...))` after the name field, `AppSpacing.lg` above it. Run `flutter gen-l10n` if the build does not regenerate.
- [x] **Step 4: Run** `flutter test` — Expected: PASS.
- [x] **Step 5: Commit** `feat(workflows): pick an event type's colour (#516)`.

### Task 4: Events in colour — list rows, grid cards, month chips

**Files:**
- Modify: `lib/features/calendar/presentation/event_row.dart` (`EventRow` bar)
- Modify: `lib/features/calendar/presentation/desktop_calendar.dart` (`_WeekCard`, its caller at ~1301, `MonthEventChip`, `DesktopMonth` + its day cell that builds chips at ~215)
- Modify: `lib/features/calendar/presentation/calendar_page.dart` (pass `now` to `DesktopMonth`)
- Test: `test/features/calendar/presentation/event_row_test.dart`, `test/features/calendar/presentation/week_grid_phone_test.dart`, a `DesktopMonth` chip test in `test/features/calendar/presentation/calendar_page_test.dart` (or wherever `MonthEventChip` is already pumped)

**Interfaces:**
- Consumes: `eventInk` (Task 3), `CalendarEvent.color` (Task 2).
- Produces: `_WeekCard({..., DateTime? now})`; `MonthEventChip({..., DateTime? now})`; `DesktopMonth({..., DateTime? now})`.

Behaviour (from the spec's Decisions):
- `EventRow`: bar = `eventInk(...).ink`; over → the same at opacity 0.5 (was `borderStrong`). Card, fill and text unchanged.
- `_WeekCard`: `quiet = event.done || (now != null && event.isOver(now))`. Upcoming: `Material.color` = `ink.container`, start bar `ink.ink`, text `onSurface`. Quiet: `Material.color` = `surfaceDefault`, `borderSubtle` side, start bar `ink.ink` at 0.5, title and time in `onSurfaceVariant` (was `textMuted`).
- `MonthEventChip`: bar `ink.ink`, quiet (same rule) → 0.5; title colour rule unchanged but keyed on quiet.

- [x] **Step 1: Failing tests**:
  - event_row_test, extend the over test: an event with `color: TagColor.sky` → upcoming bar `TagColor.sky.light.ink`; over → `TagColor.sky.light.ink.withValues(alpha: 0.5)`. Same event with no colour → `primary` / `primary` at 0.5.
  - week_grid_phone_test `'3 days: a typed event is tinted, quiet once over'`: one `sage` event at 10:00–11:00 and one at 14:00–15:00, `now` 12:00 → the later card's `Material` colour is `TagColor.sage.light.container`, the earlier's is `surfaceDefault` with a `borderSubtle` side. Repeat under `AppTheme.dark` expecting `TagColor.sage.dark.container`.
  - week_grid_phone_test `'3 days: an event with no end is quiet once started'`: no `endsAt`, starts 11:00, `now` 11:30 → `surfaceDefault`.
  - desktop month: a `violet` chip, `now` after it → bar colour `TagColor.violet.light.ink.withValues(alpha: 0.5)`.
- [x] **Step 2: Run** those files — Expected: FAIL.
- [x] **Step 3: Implement** per Behaviour; thread `now` from `WeekGrid`'s day column (already has `now`) into `_WeekCard`, and from `CalendarView` (has `now`) through `DesktopMonth` to `MonthEventChip`.
- [x] **Step 4: Run** `flutter test` — Expected: PASS except goldens that show events (calendar_*, today_*); note which fail.
- [x] **Step 5: Commit** `feat(calendar): show event type colours (#516)`.

### Task 5: Previews, spec, PR

**Files:**
- Modify: `lib/features/calendar/presentation/calendar_preview.dart`, `lib/features/today/presentation/today_preview.dart` (give the typed sample events their `color`: `mentorat` sky, `workshop` violet, `unboxing` sage, `product-evening` teal; leave one event untyped)
- Modify: `docs/superpowers/specs/2026-11-19-event-type-colours-design.md` (the rulings above: month dots stay white on the hero, no event page dot, nullable column, `create` sends no colour)
- Regenerate: goldens through CI (README.md → *Golden tests*)

- [x] **Step 1:** Set the preview colours; run `flutter test` — Expected: only golden diffs fail.
- [x] **Step 2:** Update the spec's Decisions and Behaviour for the four rulings.
- [x] **Step 3:** `dart format .`, `flutter analyze` → "No issues found!"; commit `docs(calendar): event colour rulings (#516)` and the preview change `test(calendar): typed events in previews (#516)`.
- [x] **Step 4:** Push `feature/516-event-type-colours`, regenerate goldens through CI as README.md describes, pull the golden commit, `flutter test` → all pass.
- [x] **Step 5:** Open the PR: `Closes #516`, Database section as in Global Constraints, link the FigCraft section.
