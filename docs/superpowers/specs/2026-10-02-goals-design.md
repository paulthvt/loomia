# Goals — design

Epic: #136 (sub-issues #137–#149, and #100). Figma: "Goals — mobile" and the
frames listed under *Figma* below. Calendar is a separate epic (#150), sketched
at the end so the navigation stays coherent.

## Intent

Goals answers "what did I say I would do this month, and where am I?". The
user plans the month, sees progress on what the app can count, and closes the
month by comparing plan and result. Pace is stated, never judged (guardrail
#4): nothing red, nothing compared to another person, "the goal is yours to
move".

Built from a real user's practice (a dōTERRA consultant). Her month has:

- **Own volume** (PV): what she sells, plus her own orders. Tracked all month.
- **Team volume** and **rank**: linked, computed by the company. Not tracked
  here; she states a target, and an actual at the end of the month.
- **New prospects**, **new customers** and **new team members**: people
  added to her book.
- **Loyalty setups** (LRP, Loyalty Rewards Program): a step in a customer's
  workflow. The app can forecast how many fall in the month.

## Decisions

| Question | Decision |
| --- | --- |
| Which objectives | Own volume, team volume, level, new prospects, new customers, new team members, loyalty setups. All optional. |
| Tracked vs declared | Own volume, prospects, customers, team members, loyalty: computed from the book. Team volume, level: target and actual typed by the user. |
| Period | Calendar month. One plan per month. |
| When to plan and review | One flow, "Close September, plan October", open from the 3 last days of a month through the 5 first days of the next. |
| MLM vocabulary | Generic logic and copy. A **business model** (`Other` default, `dōTERRA`) swaps in PV, OV, ranks, LRP. Asked at onboarding. Pulls in #100. |
| Company config storage | A Dart const map keyed by business model. No tables: two companies, ranks rarely change. Move to the DB when a third company arrives or a ladder must change without a release. |
| Rank requirements, live OV, "63 PV to next rank" | Not built. Needs the downline's private books (#67) and a copy of the compensation plan we cannot keep accurate. |
| Team member's rank and volume | Facts the user writes on the member's contact page: rank now, rank aimed for (with an optional month), volume a month. Stated in conversation, never read from the member's book (#67). Never on the Team tab, never summed or compared. |
| Custom terms for Other | Not built. Neutral defaults until someone asks. |
| Ranks | A private target the user sets for themselves. Never a badge, never shown outside Goals, never compared. `design-principles.md` records the exception. |
| Own orders | Logged from Goals, an `order` activity with no person. |
| Sales on a contact | The `order` activity gets an optional amount. History reads "Order · 100 PV". |
| Which step is a loyalty setup | A toggle on a workflow step: "Counts as a loyalty setup". |
| Suggested targets | Average of the last 3 closed months; loyalty from the forecast. No AI. |
| Navigation | Today · Contacts · Team · Goals until the Calendar epic. Sidebar gains Goals. |
| Habits ("What you said you would do") | Not built. Parked issue. |
| Upline sees my plan | Not built. Needs connections (#67); Personal plan, opt-in per member (#147). |
| Push reminder for the ritual | Not built. Waits for FCM. |
| Currency | None. An amount is a plain number in the business model's unit. |

## 1. Business model

`user_metadata.business_model`: absent (Other) or `'doterra'`. Read where the
display name is read (`auth_repository.dart`). Asked once, on the first-run
`/start` screen, as its own first step (see *First run* below):

> **Which company do you work with?**
> - **dōTERRA**: dōTERRA terms, volumes and ranks
> - **Other**: neutral terms

Changeable in Settings → Account. Accounts created before this ship are Other.

The configuration is a const map in
`lib/core/business_model/business_model.dart`. It lives in `core/` because
contacts, goals, onboarding and settings all read it. Widgets read
`BusinessModel` fields, never `if (doterra)`:

| Field | Other | dōTERRA |
| --- | --- | --- |
| own volume | Volume | PV |
| team volume | Team volume | OV |
| level | Level (free text) | Rank (list below, or free text) |
| loyalty | Loyalty orders | LRPs |

Rank list (dōTERRA), confirmed by the user on 2026-10-04: Manager, Director,
Executive, Elite, Premier, Silver, Gold, Platinum, Diamond, Blue Diamond,
Presidential Diamond. There is no Consultant rank. Rank names are proper nouns
and are not translated. The stored value is the label. A label missing from the
list (the company renamed a rank) is shown as stored.

Used only as a planning prefill (revised 2026-10-05): picking a rank when
planning fills the team volume (OV) with what it usually needs, and the user
can change it; nothing checks or judges a rank. Diamond and above need
branches only and prefill nothing. The figures are OV: Manager 500 OV, Director 1 000, Executive
2 000, Elite 3 000, Premier 5 000 with 2 Executive branches, Silver 9 000 with
3 Elite branches, Gold 15 000 with 3 Premier branches, Platinum 27 000 with
3 Silver branches, Diamond 4 Silver branches, Blue Diamond 5 Gold branches,
Presidential Diamond 6 Platinum branches.

The app shows dōTERRA words only because the user picked dōTERRA. Other stays
fully neutral, and no copy says "MLM".

## 2. Database — one migration

`supabase migration new goals`.

**Amounts and own orders on `activity`:**

```sql
alter table public.activity
  add column amount numeric(12,2) check (amount > 0),
  add column loyalty_setup boolean not null default false,
  alter column person_id drop not null;
-- amount only on orders; no person only on an order with an amount;
-- an order needs text or an amount; loyalty_setup only on step entries.
```

The `(person_id, owner_id)` foreign key stays. A null `person_id` skips it
(MATCH SIMPLE). The existing text rule relaxes for `order`: text or amount.

**Loyalty flag on steps:** `workflow_step.loyalty_setup boolean not null
default false`. `complete_step` copies it onto the `step` activity it inserts,
so renaming or deleting the step does not change past counts.

**First stage on `person`:** `first_stage person_stage not null`, set by a
`before insert` trigger from `stage`, backfilled from `stage`. It tells "added
as a prospect" apart from "moved to prospect".

**Team member facts on `person`:** `current_level text`, `target_level
text`, `target_level_by date` (first day of a month, nullable),
`monthly_volume_target numeric(12,2) check (> 0)`. All nullable, shown only
while the person is at the `team` stage and kept if they move, like the other
facts from #60. The existing RLS covers them.

**`month_plan`:**

| Column | Type | Note |
| --- | --- | --- |
| id, owner_id, created_at, updated_at | usual | |
| month | date | first day of the month, `check (extract(day from month) = 1)` |
| own_volume_target | numeric(12,2) | nullable |
| team_volume_target | numeric(12,2) | nullable |
| level_target | text | nullable |
| prospects_target, customers_target, team_members_target, loyalty_target | int | nullable, `>= 0` |
| loyalty_forecast | int | what was suggested when planning |
| own_volume_actual, prospects_actual, customers_actual, team_members_actual, loyalty_actual | numeric / int | frozen at close |
| team_volume_actual, level_actual | numeric / text | typed at close |
| closed_at | timestamptz | null while the month is open |

`unique (owner_id, month)`. RLS on, four owner policies, `revoke all … from
anon, authenticated`, then explicit grants. Same migration.

**`month_progress(p_month date)`** returns one row: own volume, new
prospects, new customers, new team members, loyalty setups for the month. Security invoker.
- own volume: `sum(amount)` of `order` activities with `happened_on` in the
  month, with or without a person.
- new prospects: people with `first_stage = 'prospect'` and `created_at` in
  the month (local date, see #48).
- new customers: distinct people with a `stage` activity to `customer` in the
  month.
- new team members: distinct people with a `stage` activity to `team` in the
  month, plus people with `first_stage = 'team'` and `created_at` in the month.
- loyalty: `step` activities with `loyalty_setup` in the month.

**`loyalty_forecast(p_month date)`** returns an int: distinct customers whose
workflow is not paused and that reach a loyalty step in the month. Due dates
are walked from the current step: the first is `due_on(person)`, each next one
is the previous one plus `days`. A late loyalty step counts in the current
month.

Closing a month writes the five tracked actuals from `month_progress` and
`closed_at` in one RPC, `close_month(p_month, team_volume_actual,
level_actual)`. After that, editing an old activity does not change the
record.

pgTAP: `supabase/tests/goals_test.sql` covers the constraints, the progress
counts, the forecast walk, the frozen close, and owner isolation.

## 3. Domain (Dart, `lib/features/goals/domain/`)

- `MonthPlan`: the row. `Progress`: the five counts.
- `pace(target, done, today)` gives the projected month end and whether it is
  on pace. It is null in the first 3 days of the month, when a projection
  means nothing.
- `ritualWindow(today)` gives the month to close and the month to plan, or
  null. From day `daysInMonth - 2` it closes the current month. Up to day 5 it
  closes the previous one.
- `suggest(closedPlans)`: per objective, the rounded mean of the last 3 closed
  actuals. Null with no history.

Unit tests for each, no Flutter.

## 4. Screens

**Goals tab** (`/goals`). App bar `11 DAYS LEFT IN SEPTEMBER` / "Goals".
- No plan this month: an empty state, "What are you aiming for this month?",
  and `Plan September`.
- Plan:
  - GoalCard for own volume ("1 840 of 2 800 PV", bar, "On pace");
  - StatTiles, 2 × 2: new prospects, new customers, new team members and
    loyalty setups ("2 of 3 · 1 more likely");
  - a declared row ("Aiming for Elite · OV 6 000");
  - the pace card;
  - `Log my own order`.
- Tapping the volume card lists this month's orders (contacts' and own), each
  removable.
- `PAST MONTHS`: plan vs result, one row per closed month.
- Desktop/tablet: one 624px column, like Today.

**Close and plan** (`/goals/close`, full screen, two steps).
1. *How did September go?*: each objective, planned vs done. Each tracked
   value is a row: the label, "7 of 8" and a progress bar, with a check when
   the plan is reached. Over the plan, the bar is full. Under the plan, the bar
   stays neutral: no red, no "missed". Tracked values are not editable. Team volume and level are typed. `Next`.
2. *What are you aiming for in October?*: each objective with its suggestion
   prefilled. Loyalty reads "3 customers reach their LRP step in October. How
   many do you aim for?" `Save`.
The first time, with no past month, only step 2 shows, for the current month.

**First run** (`/start`) has two steps, one decision each:
1. "Welcome" / "Which company do you work with?" / "So Loomia speaks your
   language. You can change it in Settings." Two cards, dōTERRA and Other.
   Tapping a card saves the choice and moves on. No Next button, no
   preselection.
2. The existing "Who do you already work with?" screen, with a back button to
   step 1.

Both steps live under `/start`, with the step as local state, so the router
guard stays as it is. Back from step 2 returns to step 1.

**Team member contact page:** WHAT THEY ARE AIMING FOR gains, after "Their
why":
- "Rank now": Executive;
- "Aiming for": Elite by March 2027;
- "Each month": Aims for 100 PV.

The Other business model reads "Level now", "Aiming for" and "Each month:
Aims for 100". The edit sheet uses a rank picker for dōTERRA and free text for
Other, a month picker for "By" (Cupertino on iOS, Material elsewhere), and a
number field for the volume. "Their own goal" stays free text, in their words.

**Log activity sheet:** kind Order shows an amount field (unit from the
business model). Own order: the same sheet without a person.

**Workflow editor:** each step gets the "Counts as a loyalty setup" switch.

**Today:**
- under the hero, one line for own volume: "960 PV to go · 11 days left" or
  "On pace". Tapping it opens Goals. Hidden without a plan.
- while the ritual window is open and the month is not closed: a card, "Close
  September, plan October".

## 5. Copy

EN in `app_en.arb` with descriptions, informal. Business-model vocabulary goes
through ARB keys with a `select` on the business model. No "recruit", no "downline", no
"leaderboard". A rank only appears where the user typed or picked it.

## 6. Known ceilings

- Contacts imported at first run as prospects count as new prospects that
  month. Acceptable for a first month. Add an `imported` marker if users
  complain.
- The forecast assumes each step is done on its due day. It is a suggestion,
  not a promise, and the copy says "likely".

## Figma

Updated frames:
- Goals — mobile (revised, no habits), Goals — empty, Goals — desktop;
- Close month (step 1, step 2);
- Log order with amount, own order;
- Today with the goal line and the ritual card;
- Workflow step with the loyalty switch;
- Team member contact page and its edit sheet, with rank and PV;
- First run: the business model question;
- Navigation — after Calendar (4 tabs).

## Later in this epic (parked issues)

Habits. Upline visibility (#147, Personal plan). Push reminders for the ritual (FCM). AI
help to set targets.

## Calendar epic (sketch, designed when started)

- `Calendar` tab, month view by default. An event has a type (workshop, …),
  start, place and notes.
- Attendees from contacts: invited or came.
- Workflow settings gain an **Events** section: one follow-up workflow per
  event type. Marking an event done gives everyone who came that workflow,
  **replacing** their current one, starting that day.
- Today lists today's events.
- This epic's first PR swaps the Team tab for Calendar, giving Today · Calendar
  · Contacts · Goals. Team becomes the Contacts `Team` filter, and WORTH A
  CHECK-IN moves onto Today. The Team tab returns with the team plan.
- Later: export to the device calendar.
