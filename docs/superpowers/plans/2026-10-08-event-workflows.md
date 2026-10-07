# Event Workflows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An event has an event workflow: its type ("Workshop"), a checklist of steps N days before or after it, and, per stage, the person workflow that people who were there start. Marking who was there starts those workflows, replacing each person's current one (#153).

**Architecture:** One migration adds `event_workflow`, `event_workflow_step` and `event_step_done`, gives `event` its workflow and three stage columns, replaces `mark_event_done` so it also moves people onto their stage's workflow, and seeds a "Workshop" event workflow (the seed for new accounts, plus a one-off insert for existing ones). Dart gets an `EventWorkflow` model and repository in `lib/features/workflows/`, loaded by `eventWorkflowsProvider` after the seed. Settings → Workflows gains an Events section and an editor. The event form picks the event workflow and the after-the-event workflows. The event screen shows the checklist and the mapping, and "Who was there?" says what happens next.

**Tech Stack:** Supabase Postgres + pgTAP, Flutter (`material_ui`), `flutter_riverpod` 3, `go_router`.

**Spec:** `docs/superpowers/specs/2026-10-07-calendar-design.md`: §1 #153, `mark_event_done`, Seeding; §2 `stepDue`, `cameSummary`; §3 Event 2 and 4, New / edit event, Workflow settings → Events. Figma: [Calendar — #150](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=257-4672), frames "Settings / Workflows — events", "Settings / Event workflow editor", "New event sheet", "Event — upcoming", "Who was there sheet".

## Global Constraints

- No new dependency. Don't touch `pubspec.lock`.
- Schema only via `supabase migration new event_workflows`. pgTAP in `supabase/tests/event_workflow_test.sql`, run in CI; no local Docker for agents.
- New tables: RLS enabled, four owner policies on `owner_id = (select auth.uid())`, `revoke all ... from anon, authenticated`, then explicit grants, in the same migration. Composite FKs `(id, owner_id)` between owned tables. Functions: `security invoker set search_path = ''`, `revoke execute ... from public, anon`, `grant execute ... to authenticated`.
- "Today" is the device's (`today()`), sent as `p_today`.
- Dart: `package:loomia/...` imports; Material from `package:material_ui/material_ui.dart`; the domain imports no Flutter; repository methods throw `PeopleFailure` only (`guardPeople`).
- Theme from `colorScheme`, `LoomiaColors`, `AppSpacing`, `AppRadii`; `FilledButton.tonal` takes `style: AppTheme.tonal(context)`.
- Routing: paths in `routes.dart` first; no path literals in widgets.
- Copy: English only, in `lib/l10n/app_en.arb`, every key with a description; `flutter gen-l10n`. No string concatenation in the UI: a sentence with parts is one ARB message with placeholders. Informal register. Attendance words: "was there", "missed it". Never "came", "recruit", or a score.
- Every async UI handler reads `ref` and `context` values before its first `await`, and checks `context.mounted` (or `mounted`) after it.
- Quality gate: `dart format .`, `flutter analyze` ("No issues found!"), full `flutter test`.
- Goldens from CI only.
- Branch `feature/153-event-workflows`; PR body `Closes #153`.

## Rulings made while planning

- **Event steps are ordered by `days`, then label.** There's no `position` and no drag to reorder: a checklist around a date is chronological. The spec's `position numeric` is dropped.
- **Starting a person's workflow** sets `workflow_id`, `at_position` to its first step's position (0 when it has none, as `startOn` in `progress.dart` does), `last_tick = p_today`, and `paused_at = null`.
- **A null stage column means "keep their workflow".** A deleted workflow sets the column to null (`on delete set null`), which reads the same.
- **The event workflow is required for new events** (chips, the first one preselected). Events from before #153 keep `event_workflow_id` null and show no checklist.
- **Choosing an event workflow in the form** fills the title when it is empty or still equals the previous workflow's name, and copies the three stage workflows. You can change them per event.
- **`eventWorkflowsProvider`** awaits `workflowsProvider` first, so the seed has run before the event workflows are listed.
- **Unticking a checklist step** deletes its `event_step_done` row. Ticking writes `done_on = today()`. A done event's checklist stays tickable (spec §3, Event 5).
- **The "what happens next" summary** counts the people still ticked, per stage: "2 prospects start Samples", "1 team member keeps their workflow".

## Review Focus

1. Marking who was there moves a prospect who was there onto the event's prospect workflow, at its first step, unpaused, from the device's today. Someone whose stage has no mapping keeps their workflow, and someone who missed it is untouched. Pinned in Task 1.
2. A deleted person workflow leaves the event workflow and the events with "keep their workflow", not a dangling id. Pinned in Task 1.
3. The seed gives a new account "Workshop" once. Existing accounts get it once from the migration, mapped to their current defaults (null where they have none). The seed is pinned in Task 1; the backfill is read in review, because the test database starts with no accounts.
4. A step's due date is the event's local day plus `days`, negative included, across a month end. Pinned in Task 2.
5. Choosing another event workflow in the form doesn't overwrite a title the user typed. Pinned in Task 4.

---
### Task 1: Event workflows in the database

**Files:**
- Create: `supabase/migrations/<timestamp>_event_workflows.sql` (`supabase migration new event_workflows`; if the CLI is missing, a UTC `YYYYMMDDHHMMSS` later than every file in `supabase/migrations/`)
- Create: `supabase/tests/event_workflow_test.sql`

**Interfaces:**
- Produces:
  - `event_workflow (id, owner_id, name, prospect_workflow_id, customer_workflow_id, team_workflow_id, created_at, updated_at)`
  - `event_workflow_step (id, owner_id, event_workflow_id, label, days, note, created_at, updated_at)`, with `days` from −365 to 365
  - `event_step_done (event_id, step_id, owner_id, done_on)`
  - `event.event_workflow_id`, `event.prospect_workflow_id`, `event.customer_workflow_id`, `event.team_workflow_id`
  - `mark_event_done` with the same signature, now starting workflows
  - `seed_workflows` also creating "Workshop" / "Atelier"

- [ ] **Step 1: Write the pgTAP test** `supabase/tests/event_workflow_test.sql`

```sql
-- Event workflows (#153): an event's checklist, the workflows people who
-- were there start, and the seeded Workshop. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(16);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select public.seed_workflows('en', '2026-10-01');

-- 1-4: the seeded Workshop.
select is(
  (select count(*)::int from public.event_workflow where name = 'Workshop'), 1,
  'the seed creates Workshop'
);
select results_eq(
  $$ select s.label, s.days from public.event_workflow_step s
     join public.event_workflow w on w.id = s.event_workflow_id
     order by s.days $$,
  $$ values ('Remind everyone it''s tomorrow', -1),
            ('Send a thank-you and the notes', 1) $$,
  'with a reminder the day before and a thank-you the day after'
);
select is(
  (select prospect_workflow_id from public.event_workflow),
  (select id from public.workflow where stage = 'prospect' and is_default),
  'prospects who were there start the default prospect workflow'
);
select ok(
  (select team_workflow_id is null from public.event_workflow),
  'the team keeps their workflow'
);

-- 5: once.
select public.seed_workflows('en', '2026-10-02');
select is(
  (select count(*)::int from public.event_workflow), 1,
  'seeding again creates no second Workshop'
);

-- 6-7: constraints.
select throws_ok(
  $$ insert into public.event_workflow (name) values ('  ') $$,
  '23514', null,
  'an event workflow has a name'
);
select throws_ok(
  $$ insert into public.event_workflow_step (event_workflow_id, label, days)
     select id, 'Too far', 400 from public.event_workflow $$,
  '23514', null,
  'a step is within a year of the event'
);

-- 8-11: who was there starts the workflow for their stage.
insert into public.person (id, name, stage, workflow_id, at_position, last_tick, paused_at)
select '00000000-0000-0000-0000-0000000000a1', 'Claire', 'prospect', id, 3,
       '2026-09-01', now()
  from public.workflow where name = 'Health professionals';
insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a2', 'Marie', 'customer'),
  ('00000000-0000-0000-0000-0000000000a4', 'Léa', 'prospect');
insert into public.person (id, name, stage, workflow_id, at_position, last_tick)
select '00000000-0000-0000-0000-0000000000a3', 'Bruno', 'team', id, 2, '2026-09-01'
  from public.workflow where stage = 'team';

insert into public.event (id, title, starts_at, event_workflow_id,
                          prospect_workflow_id, customer_workflow_id)
select '00000000-0000-0000-0000-0000000000e1', 'Workshop', '2026-10-08 17:00+00',
       w.id, w.prospect_workflow_id, w.customer_workflow_id
  from public.event_workflow w;
insert into public.event_attendee (event_id, person_id)
select '00000000-0000-0000-0000-0000000000e1', id from public.person;
select public.mark_event_done(
  '00000000-0000-0000-0000-0000000000e1',
  array['00000000-0000-0000-0000-0000000000a1',
        '00000000-0000-0000-0000-0000000000a2',
        '00000000-0000-0000-0000-0000000000a3']::uuid[],
  '2026-10-09'
);

select results_eq(
  $$ select w.name, p.at_position, p.last_tick, p.paused_at is null
     from public.person p join public.workflow w on w.id = p.workflow_id
     where p.name = 'Claire' $$,
  $$ values ('Samples', 1::numeric, '2026-10-09'::date, true) $$,
  'a prospect who was there starts Samples at its first step, today, unpaused'
);
select is(
  (select w.name from public.person p join public.workflow w on w.id = p.workflow_id
   where p.name = 'Marie'),
  'New customer',
  'a customer who was there starts New customer'
);
select results_eq(
  $$ select w.name, p.at_position from public.person p
     join public.workflow w on w.id = p.workflow_id where p.name = 'Bruno' $$,
  $$ values ('Getting started', 2::numeric) $$,
  'no mapping for the team: Bruno keeps his workflow and his place'
);
select ok(
  (select workflow_id is null from public.person where name = 'Léa'),
  'someone who missed it is untouched'
);

-- 12-13: a deleted workflow reads as "keep their workflow".
delete from public.workflow where name = 'Samples';
select ok(
  (select prospect_workflow_id is null from public.event_workflow),
  'the event workflow forgets a deleted workflow'
);
select ok(
  (select prospect_workflow_id is null from public.event),
  'so does the event'
);

-- 14-15: ticking a checklist step.
select lives_ok(
  $$ insert into public.event_step_done (event_id, step_id, done_on)
     select '00000000-0000-0000-0000-0000000000e1', id, '2026-10-07'
     from public.event_workflow_step where days = -1 $$,
  'a step is ticked'
);
select throws_ok(
  $$ insert into public.event_step_done (event_id, step_id, done_on)
     select '00000000-0000-0000-0000-0000000000e1', id, '2026-10-07'
     from public.event_workflow_step where days = -1 $$,
  '23505', null,
  'a step is ticked once'
);

-- 16: as B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int
   from public.event_workflow, public.event_workflow_step, public.event_step_done),
  0,
  'another user sees none of it'
);

select * from finish();
rollback;
```

Test 16's cross join is 0 as soon as any table reads empty, and all three are empty for B. The backfill for accounts seeded before this migration can't be exercised here: the test database starts empty. The migration's `with` block is reviewed instead.

- [ ] **Step 2: Create the migration**

Run: `supabase migration new event_workflows`

- [ ] **Step 3: Write it**

```sql
-- Event workflows (#153): an event's type and checklist (steps N days before
-- or after it), and per stage the person workflow that people who were
-- there start. mark_event_done starts them; seed_workflows adds Workshop.

create table public.event_workflow (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  name text not null check (length(trim(name)) > 0),
  -- Null: people at that stage keep their workflow.
  prospect_workflow_id uuid,
  customer_workflow_id uuid,
  team_workflow_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id),
  foreign key (prospect_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (prospect_workflow_id),
  foreign key (customer_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (customer_workflow_id),
  foreign key (team_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (team_workflow_id)
);

-- Ordered by days: a checklist around a date is chronological.
create table public.event_workflow_step (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  event_workflow_id uuid not null,
  label text not null check (length(trim(label)) > 0),
  -- From the event's day: -1 the day before, 0 the day of, 1 the day after.
  days int not null check (days between -365 and 365),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id),
  foreign key (event_workflow_id, owner_id)
    references public.event_workflow (id, owner_id) on delete cascade
);

create index event_workflow_step_event_workflow_id_owner_id_idx
  on public.event_workflow_step (event_workflow_id, owner_id);

-- The event's own copy: set from its event workflow when it is created,
-- changeable per event. Deleting the event workflow keeps the event and
-- its title, without a checklist.
alter table public.event
  add column event_workflow_id uuid,
  add column prospect_workflow_id uuid,
  add column customer_workflow_id uuid,
  add column team_workflow_id uuid,
  add foreign key (event_workflow_id, owner_id)
    references public.event_workflow (id, owner_id) on delete set null (event_workflow_id),
  add foreign key (prospect_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (prospect_workflow_id),
  add foreign key (customer_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (customer_workflow_id),
  add foreign key (team_workflow_id, owner_id)
    references public.workflow (id, owner_id) on delete set null (team_workflow_id);

create table public.event_step_done (
  event_id uuid not null,
  step_id uuid not null,
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  done_on date not null,
  primary key (event_id, step_id),
  foreign key (event_id, owner_id)
    references public.event (id, owner_id) on delete cascade,
  foreign key (step_id, owner_id)
    references public.event_workflow_step (id, owner_id) on delete cascade
);

create trigger event_workflow_set_updated_at before update on public.event_workflow
  for each row execute function public.set_updated_at();
create trigger event_workflow_step_set_updated_at
  before update on public.event_workflow_step
  for each row execute function public.set_updated_at();

alter table public.event_workflow enable row level security;
alter table public.event_workflow_step enable row level security;
alter table public.event_step_done enable row level security;

create policy event_workflow_select_own on public.event_workflow
  for select to authenticated using (owner_id = (select auth.uid()));
create policy event_workflow_insert_own on public.event_workflow
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy event_workflow_update_own on public.event_workflow
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy event_workflow_delete_own on public.event_workflow
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy event_workflow_step_select_own on public.event_workflow_step
  for select to authenticated using (owner_id = (select auth.uid()));
create policy event_workflow_step_insert_own on public.event_workflow_step
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy event_workflow_step_update_own on public.event_workflow_step
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy event_workflow_step_delete_own on public.event_workflow_step
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy event_step_done_select_own on public.event_step_done
  for select to authenticated using (owner_id = (select auth.uid()));
create policy event_step_done_insert_own on public.event_step_done
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy event_step_done_update_own on public.event_step_done
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy event_step_done_delete_own on public.event_step_done
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.event_workflow, public.event_workflow_step,
  public.event_step_done from anon, authenticated;
grant select, insert, update, delete on public.event_workflow,
  public.event_workflow_step, public.event_step_done to authenticated;
```

Then, in the same file:
- **`mark_event_done`:** `create or replace function public.mark_event_done(p_event uuid, p_came uuid[], p_today date)`, the body from `20261007000001_event_attendees.sql` with one statement added between the `insert into public.activity` and the `update public.event set done_at`:

```sql
  -- Who was there starts the workflow for their stage, in place of the one
  -- they are on, from today; no mapping for their stage keeps theirs.
  update public.person p
    set workflow_id = mapped.workflow_id,
        at_position = coalesce(
          (select min(s.position) from public.workflow_step s
           where s.workflow_id = mapped.workflow_id),
          0),
        last_tick = p_today,
        paused_at = null
    from (
      select a.person_id,
             case pe.stage
               when 'prospect' then marked.prospect_workflow_id
               when 'customer' then marked.customer_workflow_id
               else marked.team_workflow_id
             end as workflow_id
      from public.event_attendee a
      join public.person pe on pe.id = a.person_id
      where a.event_id = p_event and a.came
    ) mapped
    where p.id = mapped.person_id and mapped.workflow_id is not null;
```

  Keep the grants on the function as they are (`create or replace` keeps them; repeat the revoke/grant lines anyway, as `20261004085415_loyalty_step.sql` does for `seed_workflows`).

- **`seed_workflows`:** `create or replace function public.seed_workflows(p_lang text, p_today date)`, the whole body copied from `20261004085415_loyalty_step.sql`, with this added after the `update public.person ...` that starts people on their defaults and before `insert into public.workflow_seeded default values;`:

```sql
  -- Workshop: remind the day before, thank the day after; prospects and
  -- customers who were there start their stage's default.
  insert into public.event_workflow (name, prospect_workflow_id, customer_workflow_id)
    values (
      case when fr then 'Atelier' else 'Workshop' end,
      (select id from public.workflow where stage = 'prospect' and is_default),
      (select id from public.workflow where stage = 'customer' and is_default)
    )
    returning id into new_id;
  insert into public.event_workflow_step (event_workflow_id, label, days) values
    (new_id, case when fr then 'Rappeler à tout le monde que c''est demain'
                  else 'Remind everyone it''s tomorrow' end, -1),
    (new_id, case when fr then 'Envoyer un merci et les notes'
                  else 'Send a thank-you and the notes' end, 1);
```

  Then repeat its `revoke execute` / `grant execute` lines.

- **Accounts seeded before this migration** get Workshop once, in the language their seeded workflows are in:

```sql
-- Accounts seeded before #153: Workshop once, in the language of their
-- seeded workflows, mapped to their current defaults (none: keep theirs).
with seeded as (
  select s.owner_id,
         exists (
           select 1 from public.workflow w
           where w.owner_id = s.owner_id
             and w.name in ('Échantillons', 'Nouveau client', 'Premiers pas')
         ) as fr
  from public.workflow_seeded s
  where not exists (
    select 1 from public.event_workflow e where e.owner_id = s.owner_id
  )
), created as (
  insert into public.event_workflow
    (owner_id, name, prospect_workflow_id, customer_workflow_id)
  select seeded.owner_id,
         case when seeded.fr then 'Atelier' else 'Workshop' end,
         (select w.id from public.workflow w
          where w.owner_id = seeded.owner_id and w.stage = 'prospect' and w.is_default),
         (select w.id from public.workflow w
          where w.owner_id = seeded.owner_id and w.stage = 'customer' and w.is_default)
  from seeded
  returning id, owner_id, name
)
insert into public.event_workflow_step (owner_id, event_workflow_id, label, days)
select c.owner_id, c.id, v.label, v.days
from created c
cross join lateral (values
  (case when c.name = 'Atelier' then 'Rappeler à tout le monde que c''est demain'
        else 'Remind everyone it''s tomorrow' end, -1),
  (case when c.name = 'Atelier' then 'Envoyer un merci et les notes'
        else 'Send a thank-you and the notes' end, 1)
) as v(label, days);
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/*_event_workflows.sql supabase/tests/event_workflow_test.sql
git commit -m "feat(calendar): add event workflows and start them when an event is done"
```

CI's `Supabase migrations` job runs the tests on the PR. Don't push the migration to the hosted project.

---
### Task 2: Event workflows in the app's data

**Files:**
- Create: `lib/features/workflows/domain/event_workflow.dart`
- Create: `lib/features/workflows/data/event_workflow_repository.dart`
- Create: `lib/features/workflows/presentation/event_workflows_controller.dart`
- Modify: `lib/features/calendar/domain/calendar_event.dart`, `lib/features/calendar/data/event_repository.dart`, `lib/features/calendar/presentation/calendar_controller.dart`
- Modify: every place that builds an `EventDraft` (`event_form.dart`, the fakes, the tests). Give the two new fields their defaults; Task 5 sets them from the form.
- Create: `test/features/workflows/fake_event_workflow_repository.dart`
- Modify: `test/features/calendar/fake_event_repository.dart`, `test/app/app_harness.dart` (an `eventWorkflows` parameter)
- Test: `test/features/workflows/domain/event_workflow_test.dart`, `test/features/workflows/data/event_workflow_repository_test.dart`, `test/features/workflows/presentation/event_workflows_controller_test.dart`, `test/features/calendar/domain/calendar_event_test.dart`, `test/features/calendar/data/event_repository_test.dart`, `test/features/calendar/presentation/calendar_controller_test.dart`

**Interfaces:**
- Produces, in `event_workflow.dart` (domain, no Flutter):

```dart
import 'package:loomia/features/contacts/domain/person.dart';

/// A step around an event: [days] from its day, signed. −1 is the day
/// before, 0 the day of, 1 the day after.
class EventWorkflowStep {
  const EventWorkflowStep({
    required this.id,
    required this.label,
    required this.days,
    this.note,
  });

  final String id;
  final String label;
  final int days;
  final String? note;
}

/// An event's type: its checklist, and per stage the person workflow that
/// people who were there start. A stage missing from [followUps] keeps
/// their workflow.
class EventWorkflow {
  EventWorkflow({
    required this.id,
    required this.name,
    required List<EventWorkflowStep> steps,
    this.followUps = const {},
  }) : steps = byDays(steps);

  final String id;
  final String name;

  /// Earliest first.
  final List<EventWorkflowStep> steps;

  /// Stage → person workflow id.
  final Map<Stage, String> followUps;
}

/// Chronological: by days, then by label.
List<EventWorkflowStep> byDays(Iterable<EventWorkflowStep> steps) =>
    List.unmodifiable(
      [...steps]..sort(
        (a, b) => a.days != b.days
            ? a.days.compareTo(b.days)
            : a.label.compareTo(b.label),
      ),
    );

/// The column of `event_workflow` and `event` holding [stage]'s workflow.
String followUpColumn(Stage stage) => '${stage.name}_workflow_id';

EventWorkflow? findEventWorkflow(List<EventWorkflow> all, String? id) =>
    all.where((workflow) => workflow.id == id).firstOrNull;
```

- `CalendarEvent` gains `final String? eventWorkflowId;`, `final Map<Stage, String> followUps;` (default `const {}`) and `final Map<String, DateTime> stepsDone;` (step id → the day it was ticked; default `const {}`).
- `EventDraft` gains `String? eventWorkflowId` and `Map<Stage, String> followUps`.
- In `calendar_event.dart`:
  - `DateTime stepDue(CalendarEvent event, EventWorkflowStep step)`
  - `typedef ThereLine = ({Stage stage, int count, String? workflowId});`
  - `List<ThereLine> thereSummary(Iterable<Stage> stagesThere, Map<Stage, String> followUps)`
- `EventWorkflowRepository`: `list()`, `create(String name)` → `EventWorkflow`, `save(String id, {required String name, required Map<Stage, String> followUps})`, `delete(String id)`, `addStep(String eventWorkflowId, {required String label, required int days, String? note})`, `updateStep(String stepId, {required String label, required int days, String? note})`, `removeStep(String stepId)`. Also `eventWorkflowRepositoryProvider` and `EventWorkflow eventWorkflowFromRow(Map<String, dynamic>)`.
- `eventWorkflowsProvider` (`AsyncNotifierProvider.family<EventWorkflowsController, List<EventWorkflow>, String?>`) with `Future<T> edit<T>(Future<T> Function(EventWorkflowRepository) write)`, and the top-level helper `Future<T> editEventWorkflows<T>(WidgetRef ref, Future<T> Function(EventWorkflowRepository) write)`, mirroring `editWorkflows`.
- `EventRepository.tick(String eventId, String stepId, DateTime on)` and `untick(String eventId, String stepId)`; `EventsController.tick` and `untick`, with the same signatures.
- `FakeEventWorkflowRepository` (store, calls, failWith; `samples()` returns one Workshop with the two seeded steps and `followUps: {Stage.prospect: 'samples', Stage.customer: 'new-customer'}`), and `pumpLoomia(..., FakeEventWorkflowRepository? eventWorkflows)` (default `FakeEventWorkflowRepository(FakeEventWorkflowRepository.samples())`).

- [ ] **Step 1: Write the failing tests**

`test/features/workflows/domain/event_workflow_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';

void main() {
  test('steps are in date order, then by name', () {
    final workflow = EventWorkflow(
      id: 'w',
      name: 'Workshop',
      steps: const [
        EventWorkflowStep(id: 'b', label: 'Thank', days: 1),
        EventWorkflowStep(id: 'c', label: 'Book the room', days: -7),
        EventWorkflowStep(id: 'a', label: 'Ask', days: 1),
      ],
    );

    expect(workflow.steps.map((step) => step.id), ['c', 'a', 'b']);
  });
}
```

Add to `test/features/calendar/domain/calendar_event_test.dart`:

```dart
  group('stepDue', () {
    CalendarEvent on(DateTime startsAt) =>
        CalendarEvent(id: 'e', title: 'Workshop', startsAt: startsAt);
    EventWorkflowStep step(int days) =>
        EventWorkflowStep(id: 's', label: 'Step', days: days);

    test('the event day plus days, before or after', () {
      final event = on(DateTime(2026, 10, 8, 19));
      expect(stepDue(event, step(-1)), DateTime(2026, 10, 7));
      expect(stepDue(event, step(0)), DateTime(2026, 10, 8));
      expect(stepDue(event, step(1)), DateTime(2026, 10, 9));
    });

    test('across a month end', () {
      expect(stepDue(on(DateTime(2026, 10, 1, 10)), step(-1)), DateTime(2026, 9, 30));
      expect(stepDue(on(DateTime(2026, 10, 31, 10)), step(1)), DateTime(2026, 11));
    });
  });

  test('who was there, per stage, with what they start', () {
    expect(
      thereSummary(
        [Stage.customer, Stage.prospect, Stage.prospect, Stage.team],
        {Stage.prospect: 'samples', Stage.customer: 'new-customer'},
      ),
      [
        (stage: Stage.prospect, count: 2, workflowId: 'samples'),
        (stage: Stage.customer, count: 1, workflowId: 'new-customer'),
        (stage: Stage.team, count: 1, workflowId: null),
      ],
    );
    expect(thereSummary(const [], const {}), isEmpty);
  });
```

`test/features/workflows/data/event_workflow_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/data/event_workflow_repository.dart';

void main() {
  test('reads a row with its steps and the stages it starts', () {
    final workflow = eventWorkflowFromRow({
      'id': 'w1',
      'name': 'Workshop',
      'prospect_workflow_id': 'samples',
      'customer_workflow_id': null,
      'team_workflow_id': null,
      'event_workflow_step': [
        {'id': 's2', 'label': 'Thank', 'days': 1, 'note': null},
        {'id': 's1', 'label': 'Remind', 'days': -1, 'note': 'By text'},
      ],
    });

    expect(workflow.name, 'Workshop');
    expect(workflow.followUps, {Stage.prospect: 'samples'});
    expect(workflow.steps.map((step) => step.id), ['s1', 's2']);
    expect(workflow.steps.first.note, 'By text');
  });
}
```

Add to `test/features/calendar/data/event_repository_test.dart`:

```dart
  test('reads the event workflow, the stages and the ticked steps', () {
    final event = eventFromRow({
      'id': 'e1',
      'title': 'Workshop',
      'starts_at': '2026-10-08T17:00:00+00:00',
      'event_workflow_id': 'w1',
      'prospect_workflow_id': 'samples',
      'customer_workflow_id': null,
      'team_workflow_id': 'getting-started',
      'event_step_done': [
        {'step_id': 's1', 'done_on': '2026-10-07'},
      ],
    });

    expect(event.eventWorkflowId, 'w1');
    expect(event.followUps, {
      Stage.prospect: 'samples',
      Stage.team: 'getting-started',
    });
    expect(event.stepsDone, {'s1': DateTime(2026, 10, 7)});
  });

  test('writes the event workflow and every stage, none as null', () {
    final row = draftToEventRow((
      title: 'Workshop',
      startsAt: DateTime(2026, 10, 8, 19),
      endsAt: null,
      place: null,
      link: null,
      notes: null,
      eventWorkflowId: 'w1',
      followUps: const {Stage.prospect: 'samples'},
    ));

    expect(row['event_workflow_id'], 'w1');
    expect(row['prospect_workflow_id'], 'samples');
    expect(row.containsKey('customer_workflow_id'), isTrue);
    expect(row['customer_workflow_id'], isNull);
    expect(row['team_workflow_id'], isNull);
  });
```

Update the existing `draftToEventRow` test to the new fields (`eventWorkflowId: null, followUps: const {}`) and its expected map (the four new keys as null).

`test/features/workflows/presentation/event_workflows_controller_test.dart`: build a `ProviderContainer.test` the way `workflows_controller_test.dart` does (auth, people, activities, workflows), plus `eventWorkflowRepositoryProvider` overridden with a `FakeEventWorkflowRepository`.

```dart
  test('lists the event workflows once the seed has run', () async {
    final world = _world();
    final listed = await world.container.read(
      eventWorkflowsProvider('p@example.com').future,
    );

    expect(listed.single.name, 'Workshop');
    expect(world.workflows.calls.first, startsWith('seed('));
  });

  test('signed out: none, nothing asked', () async {
    final world = _world();
    expect(await world.container.read(eventWorkflowsProvider(null).future), isEmpty);
    expect(world.eventWorkflows.calls, isEmpty);
  });

  test('a write reloads the list', () async {
    final world = _world();
    final owner = 'p@example.com';
    await world.container.read(eventWorkflowsProvider(owner).future);

    await world.container
        .read(eventWorkflowsProvider(owner).notifier)
        .edit((repository) => repository.create('Training'));
    final listed = await world.container.read(
      eventWorkflowsProvider(owner).future,
    );

    expect(listed.map((workflow) => workflow.name), containsAll(['Workshop', 'Training']));
  });
```

If `FakeWorkflowRepository` records the seed under another name, assert what it records: "the seed came before the event workflows were listed".

Add to `calendar_controller_test.dart`:

```dart
  test('ticking and unticking a step reload the event', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);

    await events.tick('e1', 's1', DateTime(2026, 10, 7));
    expect(
      container.read(eventsProvider(_owner)).value!.single.stepsDone,
      {'s1': DateTime(2026, 10, 7)},
    );

    await events.untick('e1', 's1');
    expect(container.read(eventsProvider(_owner)).value!.single.stepsDone, isEmpty);
    expect(fake.calls, containsAll(['tick(e1:s1)', 'untick(e1:s1)']));
  });
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/workflows test/features/calendar`
Expected: compile errors, because the new files and fields don't exist.

- [ ] **Step 3: Write the domain** (`event_workflow.dart` above). Then, in `calendar_event.dart`, import it and `person.dart`, add the three `CalendarEvent` fields with docs and the two `EventDraft` fields, and:

```dart
/// When [step] is due for [event]: the event's local day plus its days.
DateTime stepDue(CalendarEvent event, EventWorkflowStep step) {
  final day = event.day;
  return DateTime(day.year, day.month, day.day + step.days);
}

/// "Who was there?"'s summary line: how many were there at a stage, and the
/// workflow they start (null: they keep theirs).
typedef ThereLine = ({Stage stage, int count, String? workflowId});

/// One line per stage present in [stagesThere], in stage order.
List<ThereLine> thereSummary(
  Iterable<Stage> stagesThere,
  Map<Stage, String> followUps,
) {
  final counts = <Stage, int>{};
  for (final stage in stagesThere) {
    counts.update(stage, (count) => count + 1, ifAbsent: () => 1);
  }
  return [
    for (final stage in Stage.values)
      if (counts[stage] case final count?)
        (stage: stage, count: count, workflowId: followUps[stage]),
  ];
}
```

- [ ] **Step 4: Write the event workflow repository** `lib/features/workflows/data/event_workflow_repository.dart`, mirroring `workflow_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `event_workflow` and `event_workflow_step` tables. Every method
/// throws [PeopleFailure] and nothing else. RLS scopes everything to the
/// user. They are seeded with the person workflows (`seed_workflows`).
class EventWorkflowRepository {
  EventWorkflowRepository(this._client);

  final SupabaseClient _client;

  static const String _columns = '*, event_workflow_step(*)';

  Future<List<EventWorkflow>> list() => guardPeople(() async {
    final rows = await _client.from('event_workflow').select(_columns);
    return rows.map(eventWorkflowFromRow).toList();
  });

  /// A new one with no steps, and every stage keeping their workflow.
  Future<EventWorkflow> create(String name) => guardPeople(() async {
    final row = await _client
        .from('event_workflow')
        .insert({'name': name})
        .select(_columns)
        .single();
    return eventWorkflowFromRow(row);
  });

  Future<void> save(
    String id, {
    required String name,
    required Map<Stage, String> followUps,
  }) => guardPeople(() async {
    await _client
        .from('event_workflow')
        .update({'name': name, ...followUpsToRow(followUps)})
        .eq('id', id);
  });

  /// Its steps go with it; its events keep their title, without a checklist.
  Future<void> delete(String id) => guardPeople(() async {
    await _client.from('event_workflow').delete().eq('id', id);
  });

  Future<void> addStep(
    String eventWorkflowId, {
    required String label,
    required int days,
    String? note,
  }) => guardPeople(() async {
    await _client.from('event_workflow_step').insert({
      'event_workflow_id': eventWorkflowId,
      'label': label,
      'days': days,
      'note': note,
    });
  });

  Future<void> updateStep(
    String stepId, {
    required String label,
    required int days,
    String? note,
  }) => guardPeople(() async {
    await _client
        .from('event_workflow_step')
        .update({'label': label, 'days': days, 'note': note})
        .eq('id', stepId);
  });

  Future<void> removeStep(String stepId) => guardPeople(() async {
    await _client.from('event_workflow_step').delete().eq('id', stepId);
  });
}

final eventWorkflowRepositoryProvider = Provider<EventWorkflowRepository>(
  (ref) => EventWorkflowRepository(ref.watch(supabaseClientProvider)),
);

/// The three stage columns of [row], the missing ones left out.
Map<Stage, String> followUpsFromRow(Map<String, dynamic> row) => {
  for (final stage in Stage.values)
    if (row[followUpColumn(stage)] case final String id) stage: id,
};

/// Every stage column, null for "keep their workflow".
Map<String, Object?> followUpsToRow(Map<Stage, String> followUps) => {
  for (final stage in Stage.values) followUpColumn(stage): followUps[stage],
};

EventWorkflow eventWorkflowFromRow(Map<String, dynamic> row) => EventWorkflow(
  id: row['id'] as String,
  name: row['name'] as String,
  followUps: followUpsFromRow(row),
  steps: [
    for (final step in ((row['event_workflow_step'] as List?) ?? const [])
        .cast<Map<String, dynamic>>())
      EventWorkflowStep(
        id: step['id'] as String,
        label: step['label'] as String,
        days: step['days'] as int,
        note: step['note'] as String?,
      ),
  ],
);
```

(`dayColumn` is not needed here. Drop the `people_repository.dart` import if analyze says it's unused, but keep `guardPeople`, which comes from it.)

- [ ] **Step 5: The provider** `lib/features/workflows/presentation/event_workflows_controller.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/workflows/data/event_workflow_repository.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';

/// One account's event workflows, `eventWorkflowsProvider(account?.email)`.
/// Waits for the person workflows first: their load is what seeds Workshop,
/// and a deleted workflow changes the stages these start. No automatic
/// retry.
final eventWorkflowsProvider =
    AsyncNotifierProvider.family<
      EventWorkflowsController,
      List<EventWorkflow>,
      String?
    >(EventWorkflowsController.new, retry: (error, _) => null);

class EventWorkflowsController extends AsyncNotifier<List<EventWorkflow>> {
  EventWorkflowsController(this.owner);

  final String? owner;

  @override
  Future<List<EventWorkflow>> build() async {
    final repository = ref.watch(eventWorkflowRepositoryProvider);
    if (owner == null) return const [];
    await ref.watch(workflowsProvider(owner).future);
    return repository.list();
  }

  /// Runs [write], then reloads. Rethrows its `PeopleFailure`.
  Future<T> edit<T>(
    Future<T> Function(EventWorkflowRepository repository) write,
  ) async {
    final result = await write(ref.read(eventWorkflowRepositoryProvider));
    if (ref.mounted) ref.invalidateSelf();
    return result;
  }
}

/// [EventWorkflowsController.edit] on the signed-in account, read at call
/// time.
Future<T> editEventWorkflows<T>(
  WidgetRef ref,
  Future<T> Function(EventWorkflowRepository repository) write,
) => ref
    .read(eventWorkflowsProvider(ref.read(accountProvider)?.email).notifier)
    .edit(write);
```

- [ ] **Step 6: The event's side** (`event_repository.dart`, `calendar_controller.dart`)
- `_columns` becomes `'*, event_attendee(person_id, came), event_step_done(step_id, done_on)'`.
- `eventFromRow` reads `event_workflow_id`, `followUps: followUpsFromRow(row)` (imported from `event_workflow_repository.dart`), and `stepsDone: {for (final done in (row['event_step_done'] as List?) ?? const []) (done as Map<String, dynamic>)['step_id'] as String: DateTime.parse(done['done_on'] as String)}`. A bare date parses as local midnight.
- `draftToEventRow` adds `'event_workflow_id': draft.eventWorkflowId, ...followUpsToRow(draft.followUps)`.
- Add:

```dart
  Future<void> tick(String eventId, String stepId, DateTime on) => guardPeople(
    () => _client.from('event_step_done').insert({
      'event_id': eventId,
      'step_id': stepId,
      'done_on': dayColumn(on),
    }),
  );

  Future<void> untick(String eventId, String stepId) => guardPeople(
    () => _client
        .from('event_step_done')
        .delete()
        .eq('event_id', eventId)
        .eq('step_id', stepId),
  );
```

- In `EventsController`, add `tick` and `untick`. Each calls the repository, then `_reload()`, like `invite`.

- [ ] **Step 7: The fakes and the harness**
- `FakeEventRepository`: `_fromDraft` and `_with` carry `eventWorkflowId`, `followUps` and `stepsDone`; `update` keeps the stored `stepsDone`; add `tick` (records `tick(<eventId>:<stepId>)` and adds to `stepsDone`) and `untick` (records `untick(<eventId>:<stepId>)` and removes it).
- `test/features/workflows/fake_event_workflow_repository.dart`: in-memory, mirroring `fake_workflow_repository.dart`. It records `list()`, `create(<name>)`, `save(<id>)`, `delete(<id>)`, `addStep(<id>)`, `updateStep(<id>)`, `removeStep(<id>)`, and has `failWith`. `samples()` returns:

```dart
  static List<EventWorkflow> samples() => [
    EventWorkflow(
      id: 'workshop',
      name: 'Workshop',
      followUps: const {
        Stage.prospect: 'samples',
        Stage.customer: 'new-customer',
      },
      steps: const [
        EventWorkflowStep(id: 'remind', label: "Remind everyone it's tomorrow", days: -1),
        EventWorkflowStep(id: 'thank', label: 'Send a thank-you and the notes', days: 1),
      ],
    ),
  ];
```

  Use the ids `FakeWorkflowRepository.samples()` really has for Samples and New customer (read it), so the stages point at workflows that exist.
- `pumpLoomia`: the `eventWorkflows` parameter and its override.

- [ ] **Step 8: Run the tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib test
git commit -m "feat(calendar): load event workflows and an event's checklist"
```

---
### Task 3: Settings → Workflows → Events

**Files:**
- Modify: `lib/app/router/routes.dart`, `lib/app/router/app_router.dart`, `lib/features/settings/presentation/settings_page.dart`
- Modify: `lib/features/workflows/presentation/workflows_settings.dart` (the Events section, New event workflow)
- Create: `lib/features/workflows/presentation/event_step_copy.dart` (`stepTiming`)
- Create: `lib/features/workflows/presentation/event_step_sheet.dart`
- Create: `lib/features/workflows/presentation/event_workflow_editor.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/workflows/presentation/event_workflow_editor_test.dart`, `test/features/workflows/presentation/workflows_settings_test.dart`, `test/features/workflows/presentation/event_step_copy_test.dart`

**Interfaces:**
- Consumes: Task 2's `eventWorkflowsProvider`, `editEventWorkflows`, `EventWorkflowRepository`, `EventWorkflow`, `findEventWorkflow`, `FakeEventWorkflowRepository`; `workflowsProvider`, `forStage`, `findWorkflow` (`workflow.dart`); `stageLabel`; `SettingsScroll`, `SettingsGroup`, `SectionHeader`, `LoomiaDialog`, `confirmDestructive`.
- Produces:
  - `Routes.settingsEventWorkflowSegment = 'events/:id'`, `Routes.settingsEventWorkflowName`, `Routes.settingsEventWorkflowLocation(String id)`
  - `SettingsPage({section, workflowId, eventWorkflowId})`
  - `String stepTiming(AppLocalizations l10n, int days)`, which gives "1 day before", "On the day" or "3 days after"
  - `void openEventWorkflow(BuildContext, String id)`, `Future<void> showNewEventWorkflow(BuildContext)`
  - `EventWorkflowEditor({id})`, `EventWorkflowEditorView`
  - `Future<void> showEventStepSheet(BuildContext context, EventWorkflow workflow, {EventWorkflowStep? step})`
  - l10n keys: `workflowsEvents`, `workflowsEventsHint`, `eventWorkflowNew`, `eventWorkflowAfter`, `eventWorkflowAfterHint`, `eventWorkflowKeep`, `eventWorkflowStage`, `eventWorkflowFooter`, `eventWorkflowDeleteBody`, `eventStepBefore`, `eventStepOnTheDay`, `eventStepAfter`, `eventStepWhen`, `eventStepWhenBefore`, `eventStepWhenAfter`, `eventStepDays`, `eventStepDaysInvalid`

- [ ] **Step 1: Add the copy**

```json
  "workflowsEvents": "Events",
  "@workflowsEvents": {
    "description": "Heading of the Events section in Settings → Workflows: event workflows, one per kind of event (a workshop, a training). Also the eyebrow above an event workflow's name in its editor."
  },
  "workflowsEventsHint": "Steps around an event, and the workflow people who were there start next.",
  "@workflowsEventsHint": {
    "description": "Line under the Events section in Settings → Workflows, explaining what an event workflow is."
  },
  "eventWorkflowNew": "New event workflow",
  "@eventWorkflowNew": {
    "description": "Button under the Events section, and title of the dialog that names a new event workflow (a kind of event, e.g. 'Training')."
  },
  "eventWorkflowAfter": "After the event",
  "@eventWorkflowAfter": {
    "description": "Heading of the part of an event workflow (and of an event) that says which workflow people who were there start, per stage."
  },
  "eventWorkflowAfterHint": "When you mark who was there, each person starts the workflow for their stage, in place of the one they're on.",
  "@eventWorkflowAfterHint": {
    "description": "Line under the After the event part of an event workflow's editor."
  },
  "eventWorkflowKeep": "Keep their workflow",
  "@eventWorkflowKeep": {
    "description": "Choice in the After the event pickers: people at that stage who were there stay on the workflow they're on."
  },
  "eventWorkflowStage": "{stage, select, prospect{Prospects who were there} customer{Customers who were there} other{Team members who were there}}",
  "@eventWorkflowStage": {
    "description": "Label of one After the event picker: the people of one stage who were at the event.",
    "placeholders": {
      "stage": { "type": "String" }
    }
  },
  "eventWorkflowFooter": "Each step comes due a number of days before or after the event. You can change what people start on a single event.",
  "@eventWorkflowFooter": {
    "description": "Footer of an event workflow's editor."
  },
  "eventWorkflowDeleteBody": "Events of this kind keep their title, without the steps.",
  "@eventWorkflowDeleteBody": {
    "description": "Body of the dialog confirming that an event workflow is deleted."
  },
  "eventStepBefore": "{days, plural, =1{1 day before} other{{days} days before}}",
  "@eventStepBefore": {
    "description": "When an event workflow step comes due, before the event. days is at least 1.",
    "placeholders": {
      "days": { "type": "int" }
    }
  },
  "eventStepOnTheDay": "On the day",
  "@eventStepOnTheDay": {
    "description": "When an event workflow step comes due: the day of the event. Also a choice in the step sheet."
  },
  "eventStepAfter": "{days, plural, =1{1 day after} other{{days} days after}}",
  "@eventStepAfter": {
    "description": "When an event workflow step comes due, after the event. days is at least 1.",
    "placeholders": {
      "days": { "type": "int" }
    }
  },
  "eventStepWhen": "When",
  "@eventStepWhen": {
    "description": "Label of the choice of when an event workflow step comes due: before, on the day, or after the event."
  },
  "eventStepWhenBefore": "Before",
  "@eventStepWhenBefore": {
    "description": "Choice in the step sheet: the step comes due some days before the event."
  },
  "eventStepWhenAfter": "After",
  "@eventStepWhenAfter": {
    "description": "Choice in the step sheet: the step comes due some days after the event."
  },
  "eventStepDays": "Days",
  "@eventStepDays": {
    "description": "Label of the number of days before or after the event that a step comes due."
  },
  "eventStepDaysInvalid": "Enter a number from 1 to 365.",
  "@eventStepDaysInvalid": {
    "description": "Error under the step sheet's Days field."
  }
```

Reuse these existing keys: `workflowName`, `workflowNameRequired`, `workflowSteps`, `workflowAddStep`, `workflowNoSteps`, `workflowDelete`, `workflowDeleteTitle`, `workflowDeleteConfirm`, `workflowMissingTitle`, `workflowMissingBody`, `workflowBackToList`, `stepNew`, `stepLabel`, `stepLabelRequired`, `stepNote`, `stepRemove`, `followWithSteps`.

- [ ] **Step 2: Write the failing tests**

`test/features/workflows/presentation/event_step_copy_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/workflows/presentation/event_step_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('before, on the day, after', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(stepTiming(l10n, -3), '3 days before');
    expect(stepTiming(l10n, -1), '1 day before');
    expect(stepTiming(l10n, 0), 'On the day');
    expect(stepTiming(l10n, 1), '1 day after');
  });
}
```

`test/features/workflows/presentation/event_workflow_editor_test.dart`, in the app through `pumpLoomia` with `FakeEventWorkflowRepository(FakeEventWorkflowRepository.samples())`, at `Size(390, 1200)`:

```dart
  testWidgets('Workflows lists the event workflows; one opens', (
    tester,
  ) async {
    final container = await pumpLoomia(tester, size: const Size(390, 1200));
    container.read(routerProvider).go(Routes.settingsWorkflows);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('EVENTS'), 200);
    expect(find.text('Workshop'), findsOneWidget);
    await tester.tap(find.text('Workshop'));
    await tester.pumpAndSettle();

    expect(find.text("Remind everyone it's tomorrow"), findsOneWidget);
    expect(find.text('1 day before'), findsOneWidget);
    expect(find.text('1 day after'), findsOneWidget);
    expect(find.text('Prospects who were there'), findsOneWidget);
  });

  testWidgets('a step three days before', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1200),
      eventWorkflows: eventWorkflows,
    );
    container
        .read(routerProvider)
        .go(Routes.settingsEventWorkflowLocation('workshop'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a step'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'What to do'),
        matching: find.byType(TextFormField),
      ),
      'Book the room',
    );
    await tester.tap(find.text('Before'));
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Days'),
        matching: find.byType(TextFormField),
      ),
      '3',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(eventWorkflows.calls, contains('addStep(workshop)'));
    expect(
      eventWorkflows.store.single.steps.first,
      isA<EventWorkflowStep>()
          .having((step) => step.label, 'label', 'Book the room')
          .having((step) => step.days, 'days', -3),
    );
  });

  testWidgets('prospects can keep their workflow', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1200),
      eventWorkflows: eventWorkflows,
    );
    container
        .read(routerProvider)
        .go(Routes.settingsEventWorkflowLocation('workshop'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Samples'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep their workflow').last);
    await tester.pumpAndSettle();

    expect(eventWorkflows.calls, contains('save(workshop)'));
    expect(
      eventWorkflows.store.single.followUps.containsKey(Stage.prospect),
      isFalse,
    );
  });

  testWidgets('a new event workflow opens on itself; delete goes back', (
    tester,
  ) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1200),
      eventWorkflows: eventWorkflows,
    );
    container.read(routerProvider).go(Routes.settingsWorkflows);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('New event workflow'), 200);
    await tester.tap(find.text('New event workflow'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Training');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('No steps yet.'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Delete workflow'), 200);
    await tester.tap(find.text('Delete workflow'));
    await tester.pumpAndSettle();
    expect(find.text('Events of this kind keep their title, without the steps.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(eventWorkflows.calls.where((call) => call.startsWith('delete(')), hasLength(1));
    expect(find.text('EVENTS'), findsOneWidget);
  });
```

Imports: `app_router.dart`, `routes.dart`, `labeled_field.dart`, `person.dart`, `event_workflow.dart`, `material_ui.dart`, the harness, and the fake. If the dialog's create button is labelled differently (look at `showNewWorkflow`, whose button says what `workflowsCreate` says), use the same label for the new dialog and in the test. The dropdown's finder may need adapting to the widget used (see Step 5); keep the behaviour asserted.

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/features/workflows`
Expected: compile errors.

- [ ] **Step 4: The routes and Settings**

In `routes.dart`, after `settingsWorkflowLocation`:

```dart
  /// One event workflow, nested under [settingsWorkflows]. Declared before
  /// [settingsWorkflowSegment] so `events/x` isn't read as a workflow id.
  static const String settingsEventWorkflowSegment = 'events/:id';
  static const String settingsEventWorkflowName = 'settingsEventWorkflow';

  static String settingsEventWorkflowLocation(String id) =>
      '$settingsWorkflows/events/${Uri.encodeComponent(id)}';
```

In `app_router.dart`, `_settingsPage` gains `String? eventWorkflowId` and passes it to `SettingsPage`. In the `settingsWorkflowsSegment` route's `routes`, put first:

```dart
                  GoRoute(
                    path: Routes.settingsEventWorkflowSegment,
                    name: Routes.settingsEventWorkflowName,
                    pageBuilder: (context, state) => _settingsPage(
                      context,
                      state,
                      SettingsSection.workflows,
                      eventWorkflowId: state.pathParameters['id'],
                    ),
                  ),
```

In `settings_page.dart`: add `eventWorkflowId` next to `workflowId` (field, docs, passed to `_Section`). The back fallback is `Routes.settingsWorkflows` when either id is set. In `_Section`, `SettingsSection.workflows` becomes:

```dart
      SettingsSection.workflows => switch ((workflowId, eventWorkflowId)) {
        (_, final String id) => _WorkflowPane(
          child: EventWorkflowEditor(key: ValueKey(id), id: id),
        ),
        (final String id, null) => _WorkflowPane(
          child: WorkflowEditor(key: ValueKey(id), id: id),
        ),
        (null, null) => SettingsScroll(
          title: l10n.settingsSectionWorkflows,
          child: const WorkflowsSettings(),
        ),
      },
```

Check the other places in `settings_page.dart` that read `workflowId` (the desktop pane, the selected state) and give `eventWorkflowId` the same treatment.

- [ ] **Step 5: The copy helper and the step sheet**

`lib/features/workflows/presentation/event_step_copy.dart`:

```dart
import 'package:loomia/l10n/app_localizations.dart';

/// When an event step comes due, from its signed [days]: "3 days before",
/// "On the day", "1 day after".
String stepTiming(AppLocalizations l10n, int days) => days < 0
    ? l10n.eventStepBefore(-days)
    : days == 0
    ? l10n.eventStepOnTheDay
    : l10n.eventStepAfter(days);
```

`lib/features/workflows/presentation/event_step_sheet.dart` mirrors `step_sheet.dart` (read it first): `showEventStepSheet` opens `LoomiaDialog.show`, and its form saves through `editEventWorkflows`, calling `addStep`/`updateStep`, or `removeStep` from the footer. The form:
- "What to do" (`stepLabel`, required, `stepLabelRequired`).
- "When": three `ChoiceChip`s, Before (`eventStepWhenBefore`), On the day (`eventStepOnTheDay`) and After (`eventStepWhenAfter`). A new step starts on Before. An edited step starts from the sign of its days.
- "Days" (`eventStepDays`): digits only, 1–365, else `eventStepDaysInvalid`. Shown only for Before and After; a new step starts at 1.
- "Note" (`stepNote`), optional.
- Saving computes `days = before ? -n : on ? 0 : n`.

Title: `stepNew` when adding; the step's label when editing. Pops itself on success, keeps what was typed and shows `FormError` on failure, as `StepForm` does.

- [ ] **Step 6: The editor** `lib/features/workflows/presentation/event_workflow_editor.dart`

`EventWorkflowEditor` (a `ConsumerWidget`) mirrors `WorkflowEditor`. It finds the event workflow in `eventWorkflowsProvider(owner)`: spinner while loading, `WorkflowsLoadError` on failure, and the `workflowMissingTitle`/`workflowMissingBody`/`workflowBackToList` empty state when it's gone. Otherwise it shows `SettingsScroll(eyebrow: l10n.workflowsEvents, title: workflow.name, child: EventWorkflowEditorView(...))`, with the person workflows from `workflowsProvider(owner).value ?? const []`.

`EventWorkflowEditorView` (stateful, like `WorkflowEditorView`; reuse its `_run`/busy pattern) shows, top to bottom:
1. The name: `LabeledField(workflowName)`, saved on submit and on focus loss when changed and non-blank, through `onSave(name: …, followUps: workflow.followUps)`.
2. `SectionHeader(workflowSteps, actionLabel: workflowAddStep, onAction: onAddStep)`, then a `SettingsGroup` of `ListTile(title: step.label, subtitle: stepTiming(l10n, step.days), onTap: () => onOpenStep(step))`, or `workflowNoSteps`.
3. `SectionHeader(eventWorkflowAfter)`, then a `SettingsGroup` with one `ListTile` per `Stage.values`: the title is `eventWorkflowStage(stage.name)`; the trailing widget is a `DropdownButton<String?>` (`underline: SizedBox.shrink()`) whose items are `null` → `eventWorkflowKeep`, then `forStage(workflows, stage)` by name. Its value is `workflow.followUps[stage]` when that id is still in the list, else null. On change, call `onSave(name: workflow.name, followUps: {...workflow.followUps}..[stage] = id)`, or remove the key when null. Under it, `eventWorkflowAfterHint` in `bodySmall` muted.
4. `eventWorkflowFooter`, then a `SettingsGroup` with the destructive `workflowDelete` row (as in `WorkflowEditorView`) that calls `onDelete`.

`EventWorkflowEditor._delete` runs `confirmDestructive(title: workflowDeleteTitle(name), body: eventWorkflowDeleteBody, action: workflowDeleteConfirm)`, then `editEventWorkflows(ref, (r) => r.delete(id))`, then `backOr(context, Routes.settingsWorkflows)` if still mounted.

- [ ] **Step 7: The Events section** (`workflows_settings.dart`)

`WorkflowsSettings` also watches `eventWorkflowsProvider(owner)` and passes `eventWorkflows: events.value ?? const []`, `onOpenEvent: (w) => openEventWorkflow(context, w.id)` and `onNewEvent: () => unawaited(showNewEventWorkflow(context))` to `WorkflowsView`. Add those three as required fields there. Update `workflows_preview.dart` and the existing tests that build `WorkflowsView`, giving them `eventWorkflows: const []` and no-op callbacks.

At the end of `WorkflowsView`, after the New workflow button:

```dart
        const SizedBox(height: AppSpacing.xl),
        SectionHeader(title: l10n.workflowsEvents),
        if (eventWorkflows.isNotEmpty)
          SettingsGroup(
            children: [
              for (final workflow in eventWorkflows)
                ListTile(
                  title: Text(workflow.name),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppSpacing.sm,
                    children: [
                      Text(l10n.followWithSteps(workflow.steps.length)),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                  onTap: () => onOpenEvent(workflow),
                ),
            ],
          ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.workflowsEventsHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonalIcon(
          onPressed: onNewEvent,
          style: AppTheme.tonal(context),
          icon: const Icon(Icons.add_rounded),
          label: Text(l10n.eventWorkflowNew),
        ),
```

Sort `eventWorkflows` by name before the list.

`openEventWorkflow` mirrors `openWorkflow`, with `Routes.settingsEventWorkflowLocation`. `showNewEventWorkflow` mirrors `showNewWorkflow` with only the name field: it creates through `editEventWorkflows(ref, (r) => r.create(name))`, then opens it.

- [ ] **Step 8: Run the tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add lib test
git commit -m "feat(workflows): edit event workflows in Settings"
```

---
### Task 4: The event form picks the event workflow

**Files:**
- Create: `lib/features/workflows/presentation/follow_up_picker.dart` (moved out of the editor)
- Modify: `lib/features/workflows/presentation/event_workflow_editor.dart` (use `FollowUpPicker`)
- Modify: `lib/features/calendar/presentation/event_form.dart`
- Modify: `test/features/calendar/calendar_harness.dart`
- Modify: `test/features/workflows/fake_event_workflow_repository.dart` (`samples()` gains a second event workflow, "Training", with no steps and no stages)
- Modify: `lib/l10n/app_en.arb` (`eventType`)
- Test: `test/features/calendar/presentation/event_form_test.dart`

**Interfaces:**
- Consumes: `eventWorkflowsProvider`, `workflowsProvider`, `EventWorkflow`, `forStage`; Task 2's `EventDraft.eventWorkflowId/followUps`.
- Produces:
  - `FollowUpPicker({required Stage stage, required List<Workflow> workflows, required String? value, required ValueChanged<String?> onChanged})`: a `DropdownButton<String?>` with "Keep their workflow" for null, then the stage's workflows by name. A `value` not among them shows as null.
  - In `pumpCalendarHarness`, also overrides `eventWorkflowRepositoryProvider`, `workflowRepositoryProvider`, `peopleRepositoryProvider` and `activityRepositoryProvider` with fakes (the samples by default), plus the parameter `FakeEventWorkflowRepository? eventWorkflows`.
  - l10n key: `eventType`.

- [ ] **Step 1: Add the copy**

```json
  "eventType": "Type",
  "@eventType": {
    "description": "Label of the event form's choice of event workflow: what kind of event it is (e.g. Workshop, Training). Choosing one fills the title and the after-the-event workflows."
  }
```

- [ ] **Step 2: Write the failing tests** (add to `event_form_test.dart`)

```dart
  testWidgets('a new event is a Workshop: its title, its stages', (
    tester,
  ) async {
    final events = FakeEventRepository();
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    expect(find.text('Workshop'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final saved = events.store.single;
    expect(saved.title, 'Workshop');
    expect(saved.eventWorkflowId, 'workshop');
    expect(saved.followUps, FakeEventWorkflowRepository.samples().first.followUps);
  });

  testWidgets('another type follows an untouched title', (tester) async {
    final events = FakeEventRepository();
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Training'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(events.store.single.title, 'Training');
    expect(events.store.single.followUps, isEmpty);
  });

  testWidgets('another type keeps a title that was typed', (tester) async {
    final events = FakeEventRepository();
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    await tester.enterText(_field('Title'), 'Essential oils for sleep');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Training'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(events.store.single.title, 'Essential oils for sleep');
    expect(events.store.single.eventWorkflowId, 'training');
  });

  testWidgets('after the event: prospects can keep theirs, for this event', (
    tester,
  ) async {
    final events = FakeEventRepository();
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    await tester.tap(find.text('After the event'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Samples'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep their workflow').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(events.store.single.followUps.containsKey(Stage.prospect), isFalse);
    expect(events.store.single.followUps[Stage.customer], isNotNull);
  });

  testWidgets('an event from before keeps having no type', (tester) async {
    final event = CalendarEvent(
      id: 'e1',
      title: 'Coffee',
      startsAt: DateTime(2026, 10, 8, 10),
    );
    final events = FakeEventRepository([event]);
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, event: event),
      result: (_) {},
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(events.store.single.eventWorkflowId, isNull);
    expect(events.store.single.title, 'Coffee');
  });
```

The existing tests that type a title and expect it saved still pass: a typed title is never overwritten. If the earlier "a new event on the day" test now sees the default type, keep its assertions on what was typed.

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/features/calendar/presentation/event_form_test.dart`

- [ ] **Step 4: Move the picker** into `follow_up_picker.dart`, and have the editor's After the event rows use it.

- [ ] **Step 5: The form** (`event_form.dart`)
- State: `String? _eventWorkflowId`, `Map<Stage, String> _followUps`, and the name of the type last chosen (`_typeName`).
- Editing: start from the event's `eventWorkflowId` and `followUps`; `_typeName` is the found workflow's name, or null.
- New event: in `initState`, `ref.listenManual(eventWorkflowsProvider(owner), (_, next) { … }, fireImmediately: true)`. Once there's a value and no type chosen yet, choose the first by name inside `setState`.
- Choosing a type: `void _choose(EventWorkflow workflow)`. If the title is empty, or still equals `_typeName`, set `_title.text = workflow.name`. Then set `_typeName = workflow.name`, `_eventWorkflowId = workflow.id`, `_followUps = {...workflow.followUps}`.
- UI, first in the form: `LabeledField(eventType)` with a `Wrap` of `ChoiceChip`s, one per event workflow by name, `selected: id == _eventWorkflowId`, `onSelected: (_) => setState(() => _choose(w))`. With no event workflows at all, the field isn't shown.
- After the Notes field: an `ExpansionTile(title: Text(l10n.eventWorkflowAfter), shape: const Border(), collapsedShape: const Border())` holding one row per `Stage.values`: `Text(l10n.eventWorkflowStage(stage.name))` and a `FollowUpPicker` over `workflowsProvider(owner).value ?? const []`. On change, update `_followUps` in `setState`. Only shown when `_eventWorkflowId != null` or `_followUps` isn't empty.
- The draft carries `eventWorkflowId: _eventWorkflowId, followUps: _followUps`.

- [ ] **Step 6: Run the tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib test
git commit -m "feat(calendar): an event's type sets its title and what people start"
```

---

### Task 5: The checklist, and what happens next

**Files:**
- Modify: `lib/features/calendar/presentation/event_page.dart`
- Modify: `lib/features/calendar/presentation/who_was_there_sheet.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/calendar/presentation/event_page_test.dart`

**Interfaces:**
- Consumes: `stepDue`, `thereSummary`, `ThereLine` (Task 2); `stepTiming` (Task 3); `eventWorkflowsProvider`, `workflowsProvider`, `findEventWorkflow`, `findWorkflow`; `EventsController.tick/untick`; `AppTheme.resolveRing`.
- Produces:
  - `EventView` gains `required List<EventWorkflowStep> steps`, `required void Function(EventWorkflowStep step, bool done) onTick` and `required Map<Stage, String> followUpNames` (stage → workflow name; a stage missing keeps theirs).
  - `showWhoWasThere` gains `required Map<Stage, String> followUpNames`.
  - l10n keys: `eventChecklist`, `eventStepDue`, `eventStepTick`, `eventStepUntick`, `eventFollowUpStarts`, `eventFollowUpKeeps`, `eventWhatHappensNext`, `eventThereStarts`, `eventThereKeeps`, `eventThereReplaces`

- [ ] **Step 1: Add the copy**

```json
  "eventChecklist": "Checklist",
  "@eventChecklist": {
    "description": "Heading of an event's steps (from its event workflow): things to do before and after the event."
  },
  "eventStepDue": "{timing} · {day}",
  "@eventStepDue": {
    "description": "Second line of a checklist step on an event: when it comes due relative to the event (e.g. '1 day before'), then the date, e.g. 'Wednesday, October 7'.",
    "placeholders": {
      "timing": { "type": "String" },
      "day": { "type": "DateTime", "format": "MMMMEEEEd" }
    }
  },
  "eventStepTick": "Mark \"{label}\" done",
  "@eventStepTick": {
    "description": "Screen reader label of the ring that ticks a checklist step on an event. label is the step.",
    "placeholders": {
      "label": { "type": "String" }
    }
  },
  "eventStepUntick": "Mark \"{label}\" not done",
  "@eventStepUntick": {
    "description": "Screen reader label of a ticked checklist step's ring, which unticks it. label is the step.",
    "placeholders": {
      "label": { "type": "String" }
    }
  },
  "eventFollowUpStarts": "Start {workflow}",
  "@eventFollowUpStarts": {
    "description": "On an event's After the event rows: the people of that stage who were there start this workflow. workflow is its name.",
    "placeholders": {
      "workflow": { "type": "String" }
    }
  },
  "eventFollowUpKeeps": "Keep their workflow",
  "@eventFollowUpKeeps": {
    "description": "On an event's After the event rows: people of that stage keep the workflow they're on."
  },
  "eventWhatHappensNext": "What happens next",
  "@eventWhatHappensNext": {
    "description": "Heading, shown uppercased, of the summary in the Who was there? sheet of what marking it done will do."
  },
  "eventThereStarts": "{count, plural, =1{1 {stage, select, prospect{prospect} customer{customer} other{team member}} starts {workflow}} other{{count} {stage, select, prospect{prospects} customer{customers} other{team members}} start {workflow}}}",
  "@eventThereStarts": {
    "description": "A line of the Who was there? summary: how many of a stage are ticked, and the workflow they will start. workflow is its name.",
    "placeholders": {
      "count": { "type": "int" },
      "stage": { "type": "String" },
      "workflow": { "type": "String" }
    }
  },
  "eventThereKeeps": "{count, plural, =1{1 {stage, select, prospect{prospect} customer{customer} other{team member}} keeps their workflow} other{{count} {stage, select, prospect{prospects} customer{customers} other{team members}} keep their workflow}}",
  "@eventThereKeeps": {
    "description": "A line of the Who was there? summary: how many of a stage are ticked and keep the workflow they're on.",
    "placeholders": {
      "count": { "type": "int" },
      "stage": { "type": "String" }
    }
  },
  "eventThereReplaces": "A new workflow replaces the one they're on.",
  "@eventThereReplaces": {
    "description": "Last line of the Who was there? summary, shown when someone will start a workflow."
  }
```

- [ ] **Step 2: Write the failing tests** (in `event_page_test.dart`; `_pumpView` gains `steps`, `onTick` and `followUpNames` with defaults)

```dart
  testWidgets('the checklist: when each step is due, tick and untick', (
    tester,
  ) async {
    final ticks = <(String, bool)>[];
    final event = CalendarEvent(
      id: 'e1',
      title: 'Workshop',
      startsAt: DateTime(2026, 10, 8, 19),
      eventWorkflowId: 'workshop',
      stepsDone: {'thank': DateTime(2026, 10, 9)},
    );
    await _pumpView(
      tester,
      event,
      steps: const [
        EventWorkflowStep(id: 'remind', label: "Remind everyone it's tomorrow", days: -1),
        EventWorkflowStep(id: 'thank', label: 'Send a thank-you and the notes', days: 1),
      ],
      onTick: (step, done) => ticks.add((step.id, done)),
    );

    expect(find.text('CHECKLIST'), findsOneWidget);
    expect(find.text('1 day before · Wednesday, October 7'), findsOneWidget);
    expect(find.text('1 day after · Friday, October 9'), findsOneWidget);

    await tester.tap(find.byTooltip('Mark "Remind everyone it\'s tomorrow" done'));
    await tester.tap(find.byTooltip('Mark "Send a thank-you and the notes" not done'));
    expect(ticks, [('remind', true), ('thank', false)]);
  });

  testWidgets('after the event: what each stage starts', (tester) async {
    await _pumpView(
      tester,
      _workshop,
      followUpNames: const {Stage.prospect: 'Samples'},
    );

    await tester.scrollUntilVisible(find.text('Start Samples'), 200);
    expect(find.text('Prospects who were there'), findsOneWidget);
    expect(find.text('Keep their workflow'), findsNWidgets(2));
  });

  testWidgets('who was there says what happens next', (tester) async {
    final started = DateTime.now().subtract(const Duration(hours: 1));
    final events = FakeEventRepository([
      CalendarEvent(
        id: 'e1',
        title: 'Workshop',
        startsAt: started,
        eventWorkflowId: 'workshop',
        followUps: FakeEventWorkflowRepository.samples().first.followUps,
        attendees: const [
          (personId: 'p1', came: false),
          (personId: 'p2', came: false),
        ],
      ),
    ]);
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1000),
      events: events,
      people: FakePeopleRepository([_claire, _sarah]),
    );
    container.read(routerProvider).go(Routes.eventLocation('e1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark who was there'));
    await tester.pumpAndSettle();

    expect(find.text('WHAT HAPPENS NEXT'), findsOneWidget);
    expect(find.text('1 prospect starts Samples'), findsOneWidget);
    expect(find.text('1 customer starts New customer'), findsOneWidget);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sarah Lemaire'));
    await tester.pumpAndSettle();
    expect(find.text('1 customer starts New customer'), findsNothing);
  });
```

`_claire` is a prospect and `_sarah` a customer (from #152's tests). "Samples" and "New customer" must be the names the workflows sample has for the ids in `FakeEventWorkflowRepository.samples()`.

- [ ] **Step 3: Run them to see them fail**

- [ ] **Step 4: The event screen**

In `EventPane`, also watch `eventWorkflowsProvider(owner)` and `workflowsProvider(owner)`:
- `steps`: `findEventWorkflow(eventWorkflows, event.eventWorkflowId)?.steps ?? const []`. A list that hasn't loaded gives no checklist yet.
- `followUpNames`: for each `Stage` in `event.followUps`, the name of `findWorkflow(workflows, id)`, skipping ids not found (a deleted workflow reads as "keep").
- `onTick`: reads the events notifier before awaiting, then `done ? notifier.tick(event.id, step.id, today()) : notifier.untick(event.id, step.id)`, with a SnackBar on `PeopleFailure`, as `_uninvite` does.
- `showWhoWasThere(..., followUpNames: followUpNames)`.

In `EventView`, after the notes and before the done banner or Mark button:

```dart
        if (steps.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l10n.eventChecklist),
          for (final step in steps)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(step.label),
              subtitle: Text(
                l10n.eventStepDue(
                  stepTiming(l10n, step.days),
                  stepDue(event, step),
                ),
              ),
              trailing: IconButton(
                onPressed: () =>
                    onTick(step, !event.stepsDone.containsKey(step.id)),
                isSelected: event.stepsDone.containsKey(step.id),
                tooltip: event.stepsDone.containsKey(step.id)
                    ? l10n.eventStepUntick(step.label)
                    : l10n.eventStepTick(step.label),
                style: AppTheme.resolveRing(context),
                icon: const Icon(Icons.check_rounded),
              ),
            ),
        ],
```

And, after the People section, while the event isn't done:

```dart
        if (!event.done && event.eventWorkflowId != null) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l10n.eventWorkflowAfter),
          for (final stage in Stage.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.eventWorkflowStage(stage.name)),
              trailing: Text(
                switch (followUpNames[stage]) {
                  final String name => l10n.eventFollowUpStarts(name),
                  null => l10n.eventFollowUpKeeps,
                },
              ),
            ),
        ],
```

Patch `calendar_preview.dart`'s two event previews to pass `steps: const []`, `onTick: (_, _) {}` and `followUpNames: const {}` so they compile. Task 6 fills them.

- [ ] **Step 5: What happens next** (`who_was_there_sheet.dart`)

Under the checkboxes, when `followUpNames` isn't empty or someone is ticked:

```dart
          if (_lines case final lines when lines.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: LoomiaColors.of(context).surfaceSunken,
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  Text(
                    l10n.eventWhatHappensNext.toUpperCase(),
                    style: AppTypography.overline.copyWith(
                      color: LoomiaColors.of(context).textMuted,
                    ),
                  ),
                  for (final line in lines)
                    Text(switch (widget.followUpNames[line.stage]) {
                      final String name => l10n.eventThereStarts(line.count, line.stage.name, name),
                      null => l10n.eventThereKeeps(line.count, line.stage.name),
                    }),
                  if (lines.any((line) => widget.followUpNames.containsKey(line.stage)))
                    Text(
                      l10n.eventThereReplaces,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
```

with:

```dart
  List<ThereLine> get _lines => thereSummary(
    [
      for (final (:person, came: _) in widget.people)
        if (_there.contains(person.id)) person.stage,
    ],
    widget.event.followUps,
  );
```

Only show the box when the event has an event workflow (`widget.event.eventWorkflowId != null`). Events from before keep the #152 sheet.

- [ ] **Step 6: Run the tests**

Run: `flutter test`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib test
git commit -m "feat(calendar): an event's checklist, and what marking it done starts"
```

---

### Task 6: Previews and goldens

**Files:**
- Modify: `lib/features/calendar/presentation/calendar_preview.dart`, `lib/features/workflows/presentation/workflows_preview.dart`
- Modify: `test/previews_test.dart`
- Goldens (from CI only): `event_mobile_light.png` and `event_done_mobile_light.png` change (checklist, After the event); `workflows_list_light.png` changes (the Events section); `event_workflow_editor_light.png` is new.

- [ ] **Step 1: The previews**
- `calendar_preview.dart`: the "Essential oils for sleep" event gets `eventWorkflowId: 'workshop'`, Samples and New customer as `followUps`, and Workshop's two steps. Its preview ticks the reminder (`stepsDone: {'remind': DateTime(2026, 10, 7)}`) with `followUpNames: {Stage.prospect: 'Samples', Stage.customer: 'New customer'}`. The done preview ticks both.
- `workflows_preview.dart`: `WorkflowsView` gets the seeded Workshop in `eventWorkflows`. Add `eventWorkflowEditorLight` (`@Preview(group: 'Workflows', name: 'Event workflow editor — light', size: Size(390, 844))`) showing `EventWorkflowEditorView` on Workshop inside the same app shell the other workflow previews use.

- [ ] **Step 2: List the new preview** in `test/previews_test.dart`:

```dart
    'event_workflow_editor_light': (const Size(390, 844), eventWorkflowEditorLight),
```

Run: `flutter test test/previews_test.dart`

- [ ] **Step 3: The quality gate**

Run: `dart format . && flutter analyze && flutter test`

- [ ] **Step 4: Commit and push**

```bash
git add lib test
git commit -m "test(calendar): preview event workflows"
git push -u origin feature/153-event-workflows
```

(If the push fails with "Connection closed … port 443": `git -c credential.helper= -c credential.helper='!gh auth git-credential' push -u https://github.com/paulthvt/loomia.git feature/153-event-workflows`.)

- [ ] **Step 5: Goldens from CI**

```bash
gh workflow run CI --ref feature/153-event-workflows -f update-goldens=true
gh run list --workflow CI --branch feature/153-event-workflows --event workflow_dispatch --limit 1
gh run watch <run-id>
gh run download <run-id> -n goldens -D /tmp/goldens-153
```

Copy into `test/goldens/` only the PNGs that differ (`cmp`). They should be the four listed under Files; report any other. Commit (`test(calendar): update the goldens for event workflows`) and push. Don't touch `pubspec.lock`.

The PR is opened by the controller after the final review. After merge comes `supabase db push`, off the company VPN.
