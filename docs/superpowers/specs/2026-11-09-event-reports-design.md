# Event reports, and the mentorat as an event — design

Date: 2026-11-09. Status: approved in conversation, pending Figma mockups.

## Why

Team check-ins were built as three repeating workflows (weekly, every 2
weeks, monthly). In practice a check-in is an **event**: it gets scheduled,
prepared, held, and it repeats. The main tester (a team lead) already works
around this: she created her own event type "Appel mentorat" and writes her
agenda in the event notes, e.g.

```
Mise en route LRP : quel kit ?
Point formation, questions ?
Objectifs mois :
Orga atelier : poser date
```

then overwrites those notes during the call. Her agenda and what was said end
up mixed in one text, and nothing carries over to the next call.

She wants two separate things on such an event — prep notes written before,
and a structured report written during the call — and the previous report at
hand when preparing and holding the next one.

The same pattern applies to other one-person events (a wellness
consultation: prep notes before, report during, report visible in the
contact's history afterwards). So the feature is generic: **event types can
carry a report template.** The mentorat is its first default use.

## Goals

1. An event type can define a **report template**: an ordered list of field
   labels, editable by the user in the event type editor (add, rename,
   reorder, remove), next to the existing steps.
2. Every event of a type with a template has:
   - **Prep notes** — the event's existing `notes` field, unchanged.
   - **A report** — one free-text box per template field.
3. **Previous report one tap away**, both while preparing and during the
   call: the report of the most recent *done* event of the same type with the
   same person, held before this one.
4. During the call the event screen shows the prep notes, the report fields
   to fill, and the previous-report access.
5. Closing the event logs a history entry **linked to the event**. Tapping
   that entry shows the report.
6. A new default event type **Mentorat** (EN: "Mentoring"), one-person,
   with the template:
   - Sujets abordés / Topics covered
   - Actions faites / en cours et prévues / Actions done, in progress and planned
   - Problématiques rencontrées / Issues encountered
   - À faire / To do
   - Divers / Other
7. The **onboarding** workflow gets a 4th step, "Planifier le mentorat" /
   "Plan the mentoring", an event step pointing to the Mentorat type.
8. The 3 check-in workflows (`weekly`, `fortnightly`, `monthly`) are
   removed — from the seed and from every existing account.

## Non-goals

- Prep notes in the history entry. The history shows the report; the prep
  notes stay on the event, reachable via "Open event".
- Reports on group event types (e.g. Atelier). One report per event only;
  no per-attendee reports. *(Builder's call made in conversation: the
  template editor and report UI are hidden for `is_group` types.)*
- Starter templates for Bilan / Consultation bien-être. Only add them once
  the tester says what she'd write there; don't invent fields.
- Structured field types (checkboxes, numbers, dates). Every field is free
  text.
- Changes to the "Prendre des nouvelles" / "Catch up" nudge on Today. A closed
  mentorat already logs an `event` activity, which counts as contact.
- Migrating the tester's own "Appel mentorat" type or its events. The new
  Mentorat type is added beside it; she moves over and deletes hers herself.

## Anti-goals

- A past report silently changing meaning. **Report labels are frozen per
  event**: renaming or removing a template field later must not rewrite
  reports already written. Each event stores the labels it was written with.
- Losing a report. Text typed into report fields must persist without an
  explicit save the user can forget (follow whatever the event notes do
  today, or save on change).
- MLM-flavoured copy ("downline", "recruit", ranks). "Mentorat" is the
  tester's own word and is fine.

## Behaviour

### Event type editor
- New "Report" section below the steps: ordered list of field labels.
  Add, rename, reorder, delete. Empty list = no report, the type behaves
  exactly as today.
- Hidden for group types.

### Event screen (one-person type with a template)
- **Before the call** (not done): prep notes (existing notes), "Previous
  report" action (disabled/hidden when there is none), report fields.
- **During the call**: same screen. Prep notes visible, report fields
  editable, previous report one tap away. *(Builder's call: no explicit
  "start call" mode; before and during are the same open event.)*
- **After closing**: report stays editable. She often finishes writing right
  after hanging up.
- Report fields shown are the event's own frozen labels if a report already
  exists, else the type's current template.

### Previous report
- Definition: among events of the same type where this event's person is an
  attendee, with `done_at` set and `starts_at` before this event's, the most
  recent one that has a report.
- Phone: bottom sheet. Web/tablet: side panel. Same report view widget as the
  history uses.

### History
- Closing logs the `event` activity as today, plus a link to the event
  (`activity.event_id`, nullable, new).
- An event entry whose event has a non-empty report shows a report icon and a
  one-line preview of the first filled field.
- Tap on such an entry opens the report view (instead of the edit sheet):
  the sections, plus "Open event" to reach prep notes and edit.
  - Phone: bottom sheet.
  - Web/tablet (`context.screenSize` not mobile): side panel next to the
    contact, history stays visible, clicking another entry swaps the panel.
- Entries without a report behave as today.

### Deleting an event with a report
- The report lives only on the event and goes with it (decided: keep it
  simple, no copy on the history entry). `activity.event_id` is
  `on delete set null`; the history entry stays as a plain event entry.
- The delete confirmation warns when the event has a report ("the report
  will be deleted too"). Same for series edits that delete occurrences —
  but those only touch not-done occurrences, which rarely have a report;
  warn if any does.

### Onboarding step 4
- Appended **last**, after the 3 existing steps (unboxing call, training
  access, wellness consultation), which stay as they are. The mentorat is
  planned from step 4, so it starts after the consultation step. If a user
  reorders steps, existing step-ordering rules apply; no special handling.
- Day offset: 0 (due as soon as step 3 is done). *(Builder's call.)*
- Event step → Mentorat type. Tapping it opens the event form prefilled with
  type Mentorat and this person (existing `planEvent` path); she sets day,
  time, repeat (every 1 / 2 / 4 weeks — existing recurrence options).
- Ticks itself when the first mentorat is closed (existing `close_event`
  behaviour). Onboarding then ends.
- The "which check-in next?" prompt after onboarding (`workflow_next`
  onboarding → weekly/fortnightly/monthly, `needs_next`) goes away with the
  three workflows.

## Data (current state, from the code survey)

- Event types are `event_workflow` (id, owner_id, name, is_group), seeded
  once per account by `seed_workflows(p_lang, p_today)`
  (`supabase/migrations/20261015200327_rename_wellness_workflow.sql`). No
  built-in flag; seeded types are ordinary owner rows. Seeded names are
  hard-coded per language in that function, not in ARB.
- Workflows have no stored key; existing accounts are matched by seeded name
  (precedent: same migration, lines 137–145).
- `event.notes` exists; no structured per-event data.
- `activity` (kind `event`, text = title) has no link to the event.
- Recurring events: `event_series` + real `event` rows per occurrence;
  `extend_event_series` generates ahead; series notes are copied into
  occurrences.
- `close_event(p_event, p_there, p_invite_next, p_today)` logs activities,
  advances event steps, sets `done_at`.

Storage shape is left to the builder. Constraints:
- Template on the type, report on the event, labels frozen in the event's
  report. (A `text[]` on `event_workflow` and a `jsonb` array of
  `{label, text}` on `event` is one minimal shape.)
- `close_event` keeps its signature (released app calls it). Filling
  `activity.event_id` happens inside it.
- New columns nullable or defaulted; RLS/grant rules from
  docs/architecture.md → Backend apply.

## Migrations and the released app

Per AGENTS.md, phones keep the old build after `db push`.
- Additive and safe: template column, report column, `activity.event_id`,
  new Mentorat type per account, onboarding step 4, `seed_workflows` body
  update with the same parameters, `close_event` body update with the same
  parameters.
- Removing the 3 workflows for every account (and their `workflow_next`
  rows, and the people's current position on them; their history stays) is a
  data deletion. The user accepted it. Builder must check the released app
  tolerates a person whose workflow vanished and an onboarding without a
  "next" — if not, the deletion goes in a second release.
- Existing accounts: insert Mentorat with its template in the account's
  language, and append step 4 to the workflow still named "Onboarding".
  Language: same source `seed_workflows` uses / the account's stored locale.
- Recurring series: occurrences generated from a series copy the series
  notes. Prep notes written on one occurrence must stay on that occurrence
  (the existing "this event / all following" scope dialog handles it; check
  report fields are never copied from series to occurrences).
- PR fills the template's **Database** section; summary states safety for
  the released app. No Edge Function involved (confirm).

## Copy

- New UI strings in `lib/l10n/app_en.arb` only, each with a description;
  French via Weblate; informal register (*tu*).
- Seeded type name and field labels are user data, written per language in
  the seed / migration, not ARB.

## Process

- Create the GitHub issue on the project board first (branch
  `feature/<issue>-event-reports`).
- **Figma mockups before code** (file and per-issue section convention in
  memory): event screen before/during the call on phone and web, the report
  view (bottom sheet and side panel), the history row with report preview,
  the type editor's report section.
- Widget tests for the event screen report section, the report view and the
  history row; unit test for "previous report" selection if it lives in Dart;
  SQL test for the migration (template seeded, step 4 appended, workflows
  removed, RLS on any new table). Goldens for new `@Preview`s via CI.

## Left to the builder

- Storage shape (within the constraints above) and whether "previous report"
  is an RPC or a client query.
- Save mechanics for report fields.
- Exact placement inside the event screen, subject to Figma review.
- Splitting into several PRs (e.g. data + editor, then event screen, then
  history, then defaults/onboarding).
