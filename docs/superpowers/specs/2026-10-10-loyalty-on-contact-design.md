# LRP on the contact — design

Issue: #255. Figma: section "LRP on the contact — #255" on page
"04 — Screens (Light)", to be mocked before planning. Builds on
`2026-10-02-goals-design.md` (loyalty setups, #140) and the stage-since rule of
#179.

## Intent

An LRP (loyalty setup; "loyalty orders" for Other) today exists only as a
ticked workflow step flagged "Counts as a loyalty setup". A customer who
starts one outside a workflow (in a conversation, at a workshop, before they
were in the book) never counts toward the month's goal, and nothing on their
page says they have one. The LRP becomes a fact about the person, with a
start day. The workflow step stays as one way of setting it.

## Decisions

| Question | Decision |
| --- | --- |
| Where it lives | `person.loyalty_since date`. Null: no LRP. Set: the day it started. Like `stage_since`. |
| Setting it by hand | From the contact page, a sheet with a date, today by default. An earlier day is allowed: someone imported with an LRP from last year does not count this month (#179). |
| Setting it from a workflow | `complete_step` on a loyalty step sets `loyalty_since` to the step's day, only when it is null. |
| What Goals counts | People whose `loyalty_since` falls in the month, not step entries. A workflow with two loyalty steps no longer counts the same person twice. Closed months stay as frozen by `close_month`. |
| Forecast | `loyalty_forecast` skips people who already have an LRP. |
| Stopping | "Stopped their LRP" in the sheet clears the column. Started and stopped in the same open month: it does not count. |
| History | "Started LRP" and "Stopped LRP" entries, written by the server, on both paths. The fact on the page is the source of truth; the history tells the story. |
| Editing those entries | Not editable, not deletable, like stage entries. Changing the start day in the sheet moves the latest "Started LRP" entry with it. |
| Which stages | Shown on customers and team members. Kept if the person moves stage, like the other facts; not shown on prospects. |
| A loyalty step for someone who already has an LRP | Still shown on Today and ticked as usual. It writes its step entry, does not move `loyalty_since`, and does not count again. |
| Contacts list | An "LRP" filter chip, combinable with the stage chips (Customers + LRP). Shown only once someone has an LRP. Not in the URL, like the stage filter. |
| Row marker on the contacts list | Not built. Add when the filter is not enough. |
| Wording | From the business model: "LRP" for dōTERRA, "Loyalty orders" for Other, as on the Goals tile. |

## 1. Data — one migration

`supabase migration new loyalty_on_person`.

- `person.loyalty_since date`, nullable. The existing RLS and grants cover it.
  The app writes it only through `set_loyalty` and `complete_step`; the edit
  form never sends it.
- `activity_kind` gains `'loyalty_start'` and `'loyalty_stop'`. The
  `entry_shape` check lets them have no text (they read from the kind). The
  insert, update and delete policies exclude them, as they exclude `'stage'`.
- Backfill: `loyalty_since` = the earliest `happened_on` of the person's step
  entries with `loyalty_setup`. No history entries are written for it: the
  step entries already tell it.

### `set_loyalty(p_person uuid, p_since date, p_today date)`

`security definer` (it writes entries the app cannot), `search_path = ''`,
checks the person's `owner_id = auth.uid()` (else `P0002`), executable by
`authenticated` only. Locks the person row, then:

| Before | `p_since` | Does |
| --- | --- | --- |
| null | a day | `loyalty_since = p_since`, a `loyalty_start` entry on `p_since`. |
| a day | another day | `loyalty_since = p_since`, the latest `loyalty_start` entry moves to `p_since` (none, from the backfill: one is written). |
| a day | null | `loyalty_since = null`, a `loyalty_stop` entry on `p_today`. |
| same | same | Nothing. |

Returns the person.

### `complete_step`

After inserting the step entry, when the step has `loyalty_setup` and the
person's `loyalty_since` is null: the same as `set_loyalty(p_person, p_on,
p_on)`. Shared through one internal function so the two paths cannot differ.

### Goals

`month_progress.loyalty`: `count(*)` of people with `loyalty_since >=
first_day and loyalty_since < next_month`. `loyalty_forecast` adds `and
p.loyalty_since is null`. `activity.loyalty_setup` stays: it still marks which
step entries were loyalty steps.

### pgTAP — `supabase/tests/loyalty_test.sql`

Setting, moving and stopping write and move the right entries; another
owner's person is refused; the app cannot insert, edit or delete a loyalty
entry; `complete_step` sets it once and a second loyalty step leaves it;
`month_progress` counts a person once, ignores a backdated start and a
start-then-stop in the month; the forecast skips people with an LRP; the
backfill picks the earliest step.

## 2. Dart

- `Person.loyaltySince` (`DateTime?`, a date). `ActivityKind` gains
  `loyaltyStart` and `loyaltyStop`, not `byUser`.
- `PeopleRepository.setLoyalty(person, since, today)` calls the RPC.
- `StageFilter.shows` stays; the list combines it with the LRP chip.

## 3. Screens

### Contact page

Customers and team members get one line in the details, under the stage:

- set: "LRP · Since 12 Oct" (the year when not this year);
- not set: "LRP · None".

Tapping it opens the sheet. Prospects do not get the line.

### LRP sheet

A sheet on mobile, a dialog on desktop, like the other contact sheets.

- Not set: "When did it start?", a date (platform picker, today by default),
  Save.
- Set: the same date, Save; under it a text button "Stopped their LRP", no
  confirmation (it is a fact, and setting it again is one tap).

### History

"Started LRP" and "Stopped LRP" rows, with the history's usual day and no
edit or delete action.

### Contacts list

After Everyone · Prospects · Customers · Team, a `FilterChip` "LRP", on or
off, shown once anyone in the book has `loyaltySince`. It filters within the
stage chosen.

## 4. Copy

EN in `app_en.arb`, each with a description and a `select` on the business
model: the fact label ("LRP" / "Loyalty orders"), "Since {date}", "None", the
sheet title and button, the two history rows ("Started LRP" / "Started loyalty
orders", "Stopped LRP" / "Stopped loyalty orders"), the filter chip. LRP is not
translated.

## 5. Testing

- SQL: the pgTAP file above; `schema_rls_test.sql` unchanged (no new table).
- Unit: the list filter, stage and LRP combined.
- Widget: the contact page with and without an LRP, on a customer and a
  prospect; the sheet setting, moving and stopping; the history rows; the
  chip hidden then shown.
- Fake: `test/features/workflows/server_rule.dart` sets `loyaltySince` on a
  loyalty step as `complete_step` does.
- Goldens: one per new or changed `@Preview`, regenerated through CI.
