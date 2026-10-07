# Calendar — design

Epic: #150 (sub-issues #151–#155). Figma: section "Calendar — #150" on page
"04 — Screens (Light)". Supersedes the *Calendar epic* sketch at the end of
`2026-10-02-goals-design.md`.

## Intent

Events are the moments a relationship business runs on: a workshop, a product
evening, a training. The calendar answers "what is coming up, and what do I do
around it?": reminders before, follow-ups after, and everyone who came carried
into the right workflow without retyping anything.

## Decisions

| Question | Decision |
| --- | --- |
| Calendar library | None. A month grid is a 7-column `GridView` and `DateTime` arithmetic. Syncfusion is proprietary (Community License caps revenue and team size, a key to register) and, like `table_calendar`, built on the frozen `flutter/material.dart`: it would not see this app's `Theme` or `MaterialLocalizations` (architecture.md → Design packages). Revisit with a week or day view. |
| Views | Month only, plus the selected day's events. |
| Event fields | Title, start (date and time), optional end time, place (free text, can be a video link), notes, attendees. From #153 also an event workflow. No recurrence. |
| Event workflow | A new kind of workflow, and the event's type: "Workshop". It holds a checklist and, per stage, the person workflow that people who came start. |
| Checklist | Steps for the user about the event, not per attendee: "Remind everyone it's tomorrow". Each step is `days` from the event date, signed: −1 the day before, 0 the day of, +1 the day after. Ticked once. |
| Stage mapping | One person workflow (or none, "Keep current workflow") per stage. Set on the event workflow, copied onto the event when it is created, changeable per event. |
| Attendees | Picked from contacts. Invited, then came or not. An invite writes no history; coming does. |
| Who gets a workflow | Only people marked as came. It **replaces** their current workflow and ends a pause, starting that day. No mapping for their stage: their workflow stays. |
| Marking done | By hand, once the start has passed: "Mark who came", everyone ticked by default, a summary of what will happen, Done. One transaction. |
| Undo | None. A done event's attendance is read-only; the checklist stays tickable. Add undo when someone asks. |
| Several workflows per person | Later. Until then, replacing is the rule. |
| Navigation | Today · Calendar · Contacts · Goals. The Team tab goes: Contacts `Team` filter for the list, WORTH A CHECK-IN onto Today. `/team` redirects to `/contacts` (no filter in the URL today; add one if links to Team matter). Comes back with the team plan. |
| Team summary card | Dropped with the tab. Returns with the team plan. |
| Device calendar export | Later (#155). |

## 1. Data

Every table: `owner_id uuid not null default auth.uid() references auth.users
on delete cascade`, `created_at`/`updated_at` with the `set_updated_at`
trigger where rows change, RLS enabled with the four owner policies, `revoke
all ... from anon, authenticated` then explicit grants, all in the migration
that creates it. Foreign keys between owned tables are composite
`(id, owner_id)`, as in `workflow`.

### #151 — `event`

| Column | Type | Note |
| --- | --- | --- |
| `id` | uuid | |
| `title` | text not null | `check (length(trim(title)) > 0)` |
| `starts_at` | timestamptz not null | |
| `ends_at` | timestamptz | `check (ends_at is null or ends_at > starts_at)` |
| `place` | text | |
| `notes` | text | |

Index on `(owner_id, starts_at)`: the calendar reads one month at a time.

### #152 — `event_attendee`

| Column | Type | Note |
| --- | --- | --- |
| `event_id` | uuid | FK `event`, on delete cascade |
| `person_id` | uuid | FK `person`, on delete cascade |
| `came` | boolean not null default false | |

Primary key `(event_id, person_id)`. `event` gains `done_at timestamptz`.

`activity_kind` gains `'event'`; the activity's `text` is the event title.

### #153 — event workflows

`event_workflow`: `id`, `name` (non-blank), and `prospect_workflow_id`,
`customer_workflow_id`, `team_workflow_id`, each a nullable FK to `workflow`,
`on delete set null`. Three columns, not a mapping table: `person_stage` has
exactly three values and real FKs keep the mapping consistent.

`event_workflow_step`: `id`, `event_workflow_id` (FK, cascade), `position
numeric` (sparse, `unique (event_workflow_id, position)`, same rule as
`workflow_step`), `label` (non-blank), `days int` (signed), `note`.

`event` gains `event_workflow_id` (nullable FK, `on delete set null`: the
event keeps its title and loses its checklist) and the same three
`*_workflow_id` columns, copied from the event workflow when the event is
created. Events created before #153 have no workflow.

`event_step_done`: `event_id` (FK, cascade), `step_id` (FK
`event_workflow_step`, cascade), `done_on date`. Primary key `(event_id,
step_id)`. Unticking deletes the row.

### `mark_event_done(p_event uuid, p_came uuid[], p_today date)`

`security invoker`, `search_path = ''`, executable by `authenticated` only. In
one transaction:

1. Lock the event row. Not found or `done_at` set: raise (`P0002`, `P0001`).
2. `came = (person_id = any(p_came))` on every attendee. An id in `p_came`
   that is not an attendee: raise.
3. For each person who came: an `'event'` activity with the event title on
   `p_today`; if the event's column for their stage is not null, `workflow_id`
   = it, `at_position = 1`, `last_tick = p_today`, `paused_at = null`.
4. `done_at = now()`. Return the event.

#152 ships it without step 3's workflow part; #153 replaces it.

### Seeding

`seed_workflows` also creates one event workflow, "Workshop" / "Atelier":

| days | EN | FR |
| --- | --- | --- |
| −1 | Remind everyone it's tomorrow | Rappeler à tout le monde que c'est demain |
| +1 | Send a thank-you and the notes | Envoyer un merci et les notes |

Mapping: prospects start the default prospect workflow, customers the default
customer workflow, team keeps theirs. The #153 migration inserts it once for
every account already in `workflow_seeded`, mapped to that account's current
defaults (null where it has none).

## 2. Domain (Dart)

`lib/features/calendar/domain/`:

- `monthDays(DateTime month, int firstDayOfWeek)`: the grid's days, whole
  weeks, leading and trailing days of the neighbouring months included. Built
  from calendar dates (`DateTime(y, m, d)`), never by adding 24-hour
  durations, so a DST change does not skip or repeat a day.
- `stepDue(Event event, EventWorkflowStep step)`: the event's local date plus
  `step.days`.
- `cameSummary(attendees, came, event)`: per stage, how many start which
  workflow and how many keep theirs. Feeds the Mark who came sheet.

The repository lives in `lib/features/calendar/data/`. Event workflows sit with
workflows: `lib/features/workflows/` gains the event workflow model,
repository methods and settings screens.

## 3. Screens

Routes in `routes.dart`: `/calendar`, `/calendar/new`, `/calendar/:id`,
`/settings/workflows/events/:id`.

### Calendar tab

- **Mobile:** top bar with the month name, ‹ › and a `Today` chip. The month
  grid: weeks start on `MaterialLocalizations.firstDayOfWeekIndex`, days
  outside the month dimmed, up to 3 dots for a day's events, a ring on today,
  the selected day filled. Horizontal swipe changes month. Below the grid, the
  selected day: event rows "19:00 · Workshop · Place · 6 invited" (or "4
  came" once done). Empty: "Nothing planned". FAB: New event, prefilled with
  the selected day at 19:00.
- **Desktop / tablet:** the grid on the left, the selected day on the right;
  an opened event replaces the day pane, like the Contacts list/detail shell.

### Event

Top to bottom:

1. Title, date and time, place (a link opens in the browser), notes. Edit and
   Delete (confirmed) in the top bar.
2. **Checklist** (from #153): each step with "1 day before" / "On the day" /
   "1 day after" and its date, the resolve ring of #192.
3. **People** (from #152): attendee rows (`ContactRow`), Add people (the
   multi-select picker of #180), remove from the row menu.
4. Once the start has passed and not done: **Mark who came**. A sheet: the
   attendees with checkboxes, all ticked; the summary ("3 prospects start
   Samples · 1 customer starts New customer · 2 keep their workflow"); Done.
5. Done: a "Done · 4 came" banner; attendees show came / didn't come,
   read-only.

### New / edit event

A sheet on mobile, a dialog on desktop. Event workflow (chips, required from
#153, sets the title), title, date and start time and optional end time
(platform pickers, architecture.md), place, notes, and a collapsed **After the
event** block: one picker per stage, prefilled from the event workflow.

### Workflow settings → Events

A section under the stage sections. Rows: "Workshop · 2 steps · Prospects
start Samples". New event workflow. The editor, following `workflow_editor`:
name; steps with "N days before / On the day / N days after"; After the event,
one picker per stage, "Keep current workflow" for none. Deleting one leaves
its events with their title and no checklist.

## 4. Today

Below the hero, in order:

1. **Events**, only when it has items:
   - today's events: "Workshop · 19:00 · 6 invited", tap opens it;
   - past events not done: "How did Workshop go? · Tue", Mark who came opens
     the same sheet;
   - checklist steps due today or overdue: "Remind everyone it's tomorrow ·
     Workshop Wed", the resolve ring ticks it.
   The headline still counts people only.
2. **Priority**: person steps, unchanged.
3. **Worth a check-in**: moved from Team, `checkInItems()` as is, only when
   someone qualifies.

## 5. Navigation

Bottom bar and sidebar: Today · Calendar · Contacts · Goals; Settings stays
where it is. `/team` redirects to `/contacts` (no filter in the URL today; add one if links to Team matter). `TeamPage`, its
summary card and their copy are deleted; `checkIns` and `checkInItems()` stay
and are used by Today.

## 6. Delivery

| PR | Scope |
| --- | --- |
| #151 | `event`, Calendar tab, add / edit / delete, the navigation swap and check-ins on Today. |
| #152 | `event_attendee`, `done_at`, the picker, Mark who came writing history. |
| #153 | Event workflows, their settings, the checklist, the mapping on the event, `mark_event_done` starting workflows, the seeded Workshop. |
| #154 | The Events section on Today. |
| #155 | Parked: export to the device calendar. |

## 7. Testing

- Unit: `monthDays` (first day of week Monday and Sunday, a month starting on
  that day, February in a leap year, a DST change), `stepDue` (negative, zero,
  positive), `cameSummary` (null mapping, mixed stages, nobody came).
- SQL: `schema_rls_test.sql` covers the new tables. `mark_event_done`: refuses
  an event already done or another owner's; replaces the workflow, resets
  position and pause, writes history; a null mapping keeps the workflow;
  people who did not come are untouched.
- Widget: Calendar on mobile and desktop, event before and after done, the Mark
  who came sheet, Today with Events and Worth a check-in, four tabs and the
  `/team` redirect.
- Goldens: one per new `@Preview`, regenerated through CI.
