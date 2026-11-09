# Event reports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Event types carry an editable report template; one-person events of such a type get a report next to their prep notes, the previous report one tap away, and a history entry that opens the report. Default "Mentorat" type, onboarding step 4, and the 3 check-in workflows removed.

**Architecture:** Template = `text[]` on `event_workflow`; report = `jsonb` array of `{label, text}` on `event` (labels frozen per event); `activity.event_id` links history to the event, filled by `close_event`. Dart reads them through the existing repositories; one `ReportView` widget is reused by the event screen (previous report) and the history (bottom sheet on mobile, side panel on tablet/desktop).

**Tech Stack:** Flutter, flutter_riverpod, go_router, Supabase (Postgres, pgTAP tests in `supabase/tests/`).

**Spec:** `docs/superpowers/specs/2026-11-09-event-reports-design.md`

## Global Constraints

- Issue #483, branch `feature/483-event-reports`, Conventional Commits, PR body `Closes #483` and the **Database** section filled.
- Migrations additive; `close_event(uuid, jsonb, uuid[], date)` and `seed_workflows(text, date)` keep their signatures. New migrations via `supabase migration new <name>`.
- New UI strings only in `lib/l10n/app_en.arb`, each with a description; informal register. Seeded names and field labels are data in SQL, not ARB.
- No new dependency. Material from `package:material_ui/material_ui.dart`; `package:loomia/...` imports; theme tokens only; branch on `context.screenSize`.
- Mentorat type: FR `Mentorat`, EN `Mentoring`, `is_group = false`, no steps, `report_fields`:
  - FR `{"Sujets abordés","Actions faites / en cours et prévues","Problématiques rencontrées","À faire","Divers"}`
  - EN `{"Topics covered","Actions done, in progress and planned","Issues encountered","To do","Other"}`
- Onboarding step 4: FR `Planifier le mentorat`, EN `Plan the mentoring`, days 0, event step → Mentorat.
- Removed workflows (seeded names, both languages): `Suivi équipe — hebdo`, `Suivi équipe — toutes les 2 semaines`, `Suivi équipe — mensuel`, `Team check-in — weekly`, `Team check-in — every 2 weeks`, `Team check-in — monthly`.
- Reports and template UI hidden on group types (`is_group`).
- **No UI code (Tasks 5–7) before the Figma mockups of Task 4 are approved by the user.**
- Quality gate before done: `dart format .`, `flutter analyze` → "No issues found!", `flutter test`, `supabase test db`. Goldens regenerated via CI only.

## Review Focus

1. Template edited after a report was written (rename, remove, add a field) → that event keeps showing the labels it was written with. Test: Task 3 `reportFor` frozen-labels test.
2. Every report field blank → treated as no report: stored as `null`, no history icon, no delete warning. Tests: Task 3 `normaliseReport` test, Task 1 SQL check.
3. "Previous report" must never pick the current event, a later one, one of another person, another type, or a done one without a report. Test: Task 3 repository-shape test via fake + Task 1 SQL query test.
4. Released (old) app editing an event with the form → report untouched (it never sends `report`; `EventRepository.update` must not either). Test: Task 3 `eventDraftRow` excludes `report`.
5. An old event entry (no `event_id`) or one whose event was deleted → history row behaves as today, tap opens edit. Test: Task 7 widget test.

---

### Task 1: Schema — template, report, history link

**Files:**
- Create: `supabase/migrations/<ts>_event_reports.sql`
- Test: `supabase/tests/event_report_test.sql`

**Interfaces:**
- Produces: `event_workflow.report_fields text[] not null default '{}'`; `event.report jsonb` (null or a JSON array of objects with string `label` and `text`); `activity.event_id uuid` with composite FK `(event_id, owner_id) → event(id, owner_id) on delete set null (event_id)` and an index on `(event_id, owner_id)`; `close_event` writes `event_id` on the `event` activities it inserts.

- [ ] **Step 1: Write the failing pgTAP test** (style of `supabase/tests/close_event_test.sql`): user A creates a one-person type with `report_fields = '{"A","B"}'`, an event with an attendee, sets `report = '[{"label":"A","text":"x"}]'`, calls `close_event`. Assert:
  - `report_fields` round-trips, default `'{}'` on a new type;
  - `report` = `'"oops"'::jsonb` is rejected (check constraint `jsonb_typeof(report) = 'array'`);
  - the `event` activity has `event_id` = the event;
  - updating `report` after `done_at` is set succeeds (event update RLS has no done guard — keep it so);
  - deleting the event leaves the activity with `event_id` null;
  - user B cannot read A's `report` (RLS unchanged).
- [ ] **Step 2: Run** `supabase test db` → FAIL (column missing).
- [ ] **Step 3: Write the migration**: the three columns, constraint, FK, index; `create or replace function public.close_event(...)` copied from `20261014204040_close_event.sql:9-110` with the activity insert adding `event_id` (`select a.person_id, 'event', marked.title, p_today, p_event`). Re-issue the same revoke/grant lines. Header comment: additive, safe for the released app.
- [ ] **Step 4: Run** `supabase test db` → PASS, including `schema_rls_test.sql`.
- [ ] **Step 5: Commit** `feat(calendar): report template on event types, report on events, history linked to its event`

### Task 2: Defaults — Mentorat, onboarding step 4, check-ins removed

**Files:**
- Create: `supabase/migrations/<ts>_mentorat_defaults.sql`
- Modify: `supabase/tests/new_defaults_test.sql` (seed now: 5 event types, no check-in workflows, onboarding 4 steps, no onboarding `workflow_next`)
- Test: `supabase/tests/mentorat_defaults_test.sql`

**Interfaces:**
- Consumes: `event_workflow.report_fields` (Task 1).
- Produces: new accounts and existing accounts both have a `Mentorat`/`Mentoring` type and onboarding step 4 pointing to it.

- [ ] **Step 1: Write failing tests.**
  - `new_defaults_test.sql`: update expectations as above; `seed_workflows('fr', …)` gives `Mentorat` with the FR fields in order; onboarding steps = the 3 existing + `('Planifier le mentorat', 0)` with `event_workflow_id` = Mentorat.
  - `mentorat_defaults_test.sql` (simulates an already-seeded account: seed with the *previous* body is not available, so insert the old rows by hand — a `Suivi équipe — hebdo` repeating team workflow with one person on it at position 1, a workflow `Onboarding` with 3 steps whose first label is `Caler l'appel d'unboxing`, an `Atelier` type, and a user's own type `Appel mentorat`; then run the backfill function). Assert: one `Mentorat` added with FR fields; step 4 appended at `max(position)+1`; the check-in workflow is gone, the person has `workflow_id` and `at_position` null, their activities remain; `Appel mentorat` untouched; running the backfill twice adds nothing; an EN account (`Team check-in — weekly`, `Book the unboxing call`) gets `Mentoring` with EN fields; an account with no seeded names gets EN.
- [ ] **Step 2: Run** `supabase test db` → FAIL.
- [ ] **Step 3: Write the migration.**
  - `create or replace function public.seed_workflows(p_lang text, p_today date)`: body from `20261015200327_rename_wellness_workflow.sql:6-135` with: Mentorat inserted with `report_fields`; a `mentorat` key in the step `case`; onboarding JSON gets the 4th step `["Planifier le mentorat",0,"mentorat"]` / `["Plan the mentoring",0,"mentorat"]`; `weekly`/`fortnightly`/`monthly` rows and their `workflow_next` rows removed.
  - Backfill as a plain `do $$ … $$` block (runs as the migration owner, every account), per `owner_id` in `workflow_seeded`, skipping owners who already have an `event_workflow` named `Mentorat` or `Mentoring`:
    - language: `fr` when the owner has any `workflow` or `event_workflow` whose name is in (`Suivi équipe — hebdo`, `Suivi équipe — toutes les 2 semaines`, `Suivi équipe — mensuel`, `Atelier`, `Bilan bien-être`, `Appel d'unboxing`, `Consultation bien-être`, `Échantillons`, `Nouveau client`) or a `workflow_step` labelled `Caler l'appel d'unboxing`; else `en`;
    - insert the type with `owner_id` explicit;
    - append step 4 to the owner's team workflow named `Onboarding` if it exists and has no step pointing at a Mentorat type.
  - Removal: `update person set at_position = null` for people on the 6 seeded check-in names (stage `team`, `repeats`), then `delete from workflow` with those names. `workflow_next` and steps cascade; history stays.
  - Header comment: data deletion accepted by the user; Task 8 verifies the released app tolerates it.
- [ ] **Step 4: Run** `supabase test db` → PASS (all files).
- [ ] **Step 5: Commit** `feat(workflows): Mentorat as a default event type, onboarding plans it, check-in workflows removed`

### Task 3: Dart data and domain

**Files:**
- Create: `lib/features/calendar/domain/event_report.dart`
- Modify: `lib/features/workflows/domain/event_workflow.dart`, `lib/features/workflows/data/event_workflow_repository.dart`, `lib/features/calendar/domain/calendar_event.dart`, `lib/features/calendar/data/event_repository.dart`, `lib/features/calendar/presentation/calendar_controller.dart`, `lib/features/contacts/domain/activity.dart`, `lib/features/contacts/data/activity_repository.dart`, fakes in `test/features/{calendar,workflows,contacts}/fake_*.dart`
- Test: `test/features/calendar/domain/event_report_test.dart`, `test/features/calendar/data/event_repository_test.dart` (existing or new), `test/features/contacts/data/activity_repository_test.dart` (row mapping)

**Interfaces:**
- Produces:
  - `typedef ReportEntry = ({String label, String text});`
  - `List<ReportEntry> reportFor(CalendarEvent event, EventWorkflow? type)`: the event's own `report` when non-null, else the type's `reportFields` with empty text; `const []` when type is null or `isGroup`.
  - `List<ReportEntry>? normaliseReport(List<ReportEntry> entries)`: texts trimmed; `null` when every text is empty.
  - `String? reportPreview(List<ReportEntry>? report)`: first line of the first non-empty text.
  - `EventWorkflow.reportFields` (`List<String>`, default `const []`), `bool get hasReport => !isGroup && reportFields.isNotEmpty`.
  - `EventWorkflowRepository.setReportFields(String id, List<String> fields)`.
  - `CalendarEvent.report` (`List<ReportEntry>?`).
  - `EventRepository.saveReport(String eventId, List<ReportEntry>? report)`; `EventRepository.previousReport({required String eventWorkflowId, required String personId, required DateTime before}) → Future<CalendarEvent?>`: `event` with inner-joined `event_attendee` on `personId`, same type, `done_at` not null, `report` not null, `starts_at < before`, newest first, limit 1.
  - `EventsController.saveReport(String eventId, List<ReportEntry> entries)` (normalises, saves, updates state without a full reload).
  - `Activity.eventId` (`String?`) and `Activity.report` (`List<ReportEntry>?`, from `select('*, event(report)')`).

- [ ] **Step 1: Write failing tests**:
  - `reportFor` returns template labels with empty text when `report` is null; returns the event's frozen labels after the type renamed `A`→`A2` and added `C`; returns `[]` for a group type with fields.
  - `normaliseReport([('A',' '),('B','')])` → `null`; `normaliseReport([('A',' x ')])` → `[('A','x')]`.
  - `reportPreview` of `[('A',''),('B','line1\nline2')]` → `'line1'`.
  - Row mapping: `eventWorkflowFromRow` reads `report_fields`; event row with `report` maps; activity row with `event: {report: [...]}` and with `event: null` / missing `event_id`.
  - The map `EventRepository` sends for `add`/`update` from an `EventDraft` has no `report` key (extract `eventDraftRow(EventDraft)` if it isn't already a function).
- [ ] **Step 2: Run** `flutter test test/features/calendar test/features/contacts test/features/workflows` → FAIL.
- [ ] **Step 3: Implement** the interfaces above; update fakes to store `reportFields`, `report`, and answer `previousReport` with the same rule as SQL.
- [ ] **Step 4: Run** the same tests → PASS; `flutter analyze` clean.
- [ ] **Step 5: Commit** `feat(calendar): read and save event reports`

### Task 4: Figma mockups (gate for Tasks 5–7)

**Files:** none in the repo. Figma file `spz2vsSK8gbt1Ok2rW1sdQ`, page "04 — Screens (Light)", new SECTION `Event reports — #483`. Load `figma:figma-use` and `figma:figma-generate-design` first; clone existing frames and components, as in memory `figma-mockups`.

- [ ] **Step 1:** Mock, phone and desktop: event screen of a Mentorat before the call (prep notes, "Previous report" action, empty report fields) and during/after (fields filled); the report view as a bottom sheet (phone) and as a side panel next to the contact (desktop); the history row with report icon and preview; the type editor's "Report" section (add, rename, reorder, delete).
- [ ] **Step 2:** Share screenshots with the user. Iterate until they approve. Record decisions (placement, labels, save feedback) as a comment on #483.

### Task 5: Type editor — report section

**Files:**
- Modify: `lib/features/workflows/presentation/event_workflow_editor.dart`, `lib/features/workflows/presentation/event_workflows_controller.dart`, `lib/l10n/app_en.arb`
- Test: `test/features/workflows/presentation/event_workflow_editor_test.dart`

**Interfaces:**
- Consumes: `EventWorkflow.reportFields`, `EventWorkflowRepository.setReportFields` (Task 3).
- Produces: `EventWorkflowsController.setReportFields(String id, List<String> fields)`.

- [ ] **Step 1: Failing widget tests**: section shown for a one-person type, hidden for a group type; add a field → controller called with `[…, 'New']`; rename; delete; reorder (drag via `ReorderableListView` handle) → new order sent; blank label refused.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** per the approved mockup. Field labels trimmed, non-empty, duplicates allowed.
- [ ] **Step 4: Run** → PASS. Add/refresh `@Preview` if the editor has one (golden via CI).
- [ ] **Step 5: Commit** `feat(workflows): edit an event type's report fields`

### Task 6: Event screen — prep notes, report, previous report

**Files:**
- Create: `lib/features/calendar/presentation/report_view.dart` (`ReportView` widget + `showReportSheet`), `lib/features/calendar/presentation/report_editor.dart`
- Modify: `lib/features/calendar/presentation/event_page.dart` (`EventView`, around notes at :424; delete confirmation path at :134-139/:207-220), `lib/l10n/app_en.arb`
- Test: `test/features/calendar/presentation/event_page_test.dart`, `test/features/calendar/presentation/report_view_test.dart`

**Interfaces:**
- Consumes: `reportFor`, `normaliseReport`, `EventsController.saveReport`, `EventRepository.previousReport` (Task 3).
- Produces:
  - `class ReportView extends StatelessWidget { const ReportView({required List<ReportEntry> report, required DateTime day, VoidCallback? onOpenEvent}); }`: sections in order, empty sections omitted.
  - `Future<void> showReportSheet(BuildContext context, {required List<ReportEntry> report, required DateTime day, VoidCallback? onOpenEvent})`: bottom sheet.
  - `ReportEditor({required CalendarEvent event, required List<ReportEntry> entries})`: one multiline field per entry; saves through `EventsController.saveReport` 1 s after the last keystroke and on dispose (flush pending), so nothing typed is lost when leaving the screen.
  - `previousReportProvider` (`FutureProvider.family` keyed by `(eventWorkflowId, personId, before)`), next to `EventView`.

- [ ] **Step 1: Failing tests**:
  - Mentorat event (one attendee): notes shown under a "Prep notes" label; 5 report fields; typing then `pump(1s)` → `saveReport` called with that text; leaving the page before 1 s still saves.
  - Done event: fields still editable.
  - "Previous report" visible when the fake returns one, opens `ReportView` with its entries; hidden when none; hidden when the event has no attendee.
  - Type without fields, group type, event without type → screen unchanged from today (existing tests stay green).
  - Deleting an event whose `report` is non-null shows the warning text; without report, the current dialog. Same warning when "this and following" (delete, or an edit that changes the rule/day and regenerates) would remove a not-done occurrence that has a report — check the controller's loaded events from this one on.
  - `ReportView` omits empty sections, shows "Open event" only with `onOpenEvent`.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** per the approved mockup.
- [ ] **Step 4: Run** → PASS. Add `@Preview`s for `ReportView` and the event screen with a report (goldens via CI).
- [ ] **Step 5: Commit** `feat(calendar): prep notes, call report and the previous report on the event`

### Task 7: History — open the report

**Files:**
- Modify: `lib/features/contacts/presentation/history_section.dart` (`_Entry` :204, tap at :174), `lib/core/ui/activity_item.dart`, `lib/features/contacts/presentation/contact_page.dart` (`ContactPane` / `ContactDetails` layout for the side panel), `lib/l10n/app_en.arb`
- Test: `test/features/contacts/presentation/contact_details_test.dart` or a new `history_section_test.dart`

**Interfaces:**
- Consumes: `Activity.eventId`, `Activity.report`, `reportPreview` (Task 3); `ReportView`, `showReportSheet` (Task 6); `Routes.eventLocation(id)`.

- [ ] **Step 1: Failing tests**:
  - Event entry with report: report icon and preview line; tap on mobile opens the sheet with the sections; "Open event" goes to `Routes.eventLocation(eventId)`.
  - Same on desktop: tap shows a side panel next to the contact, history still visible; tapping another report entry swaps the panel; a close control hides it.
  - Event entry without report, or with `eventId == null` → tap opens edit as today; long-press delete unchanged.
- [ ] **Step 2: Run** → FAIL.
- [ ] **Step 3: Implement** per the approved mockup. Selected entry is local `setState` in the widget that owns the side panel.
- [ ] **Step 4: Run** → PASS. Golden/preview for the row with a report.
- [ ] **Step 5: Commit** `feat(contacts): open a call report from the history`

### Task 8: Released-app check, verification, PR

**Files:** none beyond fixes found.

- [ ] **Step 1:** On `origin/main`'s Dart code, read how a person with `workflow_id == null` and an onboarding with no `workflow_next` render (`next_step_section.dart`, `whats_next_sheet.dart`, Today due steps). If anything crashes or misleads, move the deletion part of Task 2 into a follow-up migration and say so in the PR.
- [ ] **Step 2:** Run `dart format .`, `flutter analyze` (expect "No issues found!"), `flutter test`, `supabase test db`; all pass.
- [ ] **Step 3:** Run the app on web against local Supabase (`run` skill): seed a fresh FR account, put someone on onboarding, plan step 4, write prep notes, close, write the report, open it from history (phone width and desktop width), plan the next occurrence and open "Previous report".
- [ ] **Step 4:** `graphify update .`; push over HTTPS with the paulthvt token (memory); open the PR from the template: `Closes #483`; **Database**: additive columns, `close_event`/`seed_workflows` same signatures, backfill + deletion of the 3 check-in workflows (accepted, released app checked in Step 1), no Edge Function to deploy. Goldens regenerated through CI per README.
