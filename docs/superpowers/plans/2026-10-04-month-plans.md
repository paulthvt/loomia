# Month Plans and Progress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Month plans, live progress, the loyalty forecast and closing a month exist in the database, with their Dart domain rules and repository (#141). No screen yet: the Goals tab is #142.

**Architecture:** One migration, `goals`. It adds `person.first_stage`, the `month_plan` table, and three functions, `month_progress`, `loyalty_forecast` and `close_month`. Every rule that counts lives in Postgres once (architecture.md, #58). Dart gets `lib/features/goals/domain/` (plain classes and pure functions: `pace`, `ritualWindow`, `suggest`) and `lib/features/goals/data/goals_repository.dart`.

**Tech Stack:** Supabase Postgres + pgTAP, Dart (no Flutter in domain), `supabase_flutter`, `flutter_riverpod`.

**Spec:** `docs/superpowers/specs/2026-10-02-goals-design.md` §2 (from "First stage on person"), §3.

## Global Constraints

- Schema only via `supabase migration new goals`. pgTAP in `supabase/tests/goals_test.sql`, run in CI only (no Docker locally).
- New table: RLS on, four owner policies `owner_id = (select auth.uid())`, `revoke all on public.month_plan from anon, authenticated`, then `grant select, insert, update, delete ... to authenticated`, all in the same migration. `schema_rls_test.sql` enforces it.
- Table conventions (architecture.md): `id uuid primary key default gen_random_uuid()`, `owner_id uuid not null default auth.uid() references auth.users on delete cascade`, `created_at`/`updated_at timestamptz not null default now()`, `set_updated_at()` trigger.
- Functions: `security invoker set search_path = ''`, `revoke execute ... from public, anon`, `grant execute ... to authenticated`.
- "Today" is computed on the device, never on the server (architecture.md).
- Dart: `package:loomia/...` imports; domain has no Flutter import; every repository method throws `PeopleFailure` only (`guardPeople`); no interface with a single implementation.
- Quality gate: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`.

## Rulings made while planning

- **Local month bounds.** The spec counts people added "in the month (local date, see #48)", but the server doesn't know the device's time zone. `month_progress` and `close_month` therefore take the device's month as two instants, `p_starts` and `p_ends` (local midnight of the 1st of this month and of next month, sent as UTC). These bound every `timestamptz`: `person.created_at`, and the `created_at` of stage entries, whose `happened_on` defaults to the server's UTC date. User-picked dates (`happened_on` of orders and steps) are compared with `p_month`. The bounds are exact across daylight saving.
- **Late loyalty steps.** `loyalty_forecast(p_month)` counts a customer whose first upcoming loyalty step is due before the end of `p_month`, including one already late. A late step is still pending, so it lands in whichever month is being planned. No `p_today` is needed.
- **Closing twice is refused** (`P0001`, "month already closed"), so a closed record never moves. Closing a month with no plan inserts one holding only actuals.
- **New customers added as customers.** The spec counts new team members as stage entries to `team` plus people with `first_stage = 'team'`, but counts new customers by stage entries only. Someone added straight in as a customer this month is a new customer too, so customers follow the team rule.
- **Suggest:** the mean of the non-null actuals among the last 3 closed months, rounded. Team volume is included because its actual is typed at close. Level is not, because it isn't a number. Loyalty takes the forecast, not a mean (spec decisions table).

## Review Focus

1. A person added at 00:30 local on the 1st (still the previous day in UTC) counts in the new month. Pinned in Task 2 by bounds that are not UTC midnight.
2. A person moved prospect → customer → prospect → customer in one month counts once as a new customer. Pinned in Task 2.
3. An own order (no person) counts in own volume. Pinned in Task 2.
4. A paused customer, a prospect on a workflow with a loyalty step, and a customer whose loyalty step is already done are not forecast. Pinned in Task 3.
5. Another user can't read, write or close someone's plan. Pinned in Task 1 and Task 2.
6. Day 26 of a 28-day February opens the window, as do day 29 of a 31-day month and day 5. Day 6 doesn't. Pinned in Task 4.

---
### Task 1: `first_stage` and the `month_plan` table

**Files:**
- Create: `supabase/migrations/<timestamp>_goals.sql` (`supabase migration new goals`). Tasks 2 and 3 append to it.
- Create: `supabase/tests/goals_test.sql`. Tasks 2 and 3 append to it, raising `plan(N)`.

**Interfaces:**
- Produces: `person.first_stage public.person_stage not null`; table `public.month_plan` with the columns below; `unique (owner_id, month)`.

- [ ] **Step 1: Write the failing pgTAP test**

```sql
-- Goals (#141): month plans, live progress, the loyalty forecast and the
-- frozen close. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- 1-2: first stage.
insert into public.person (id, name, stage, first_stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Sarah', 'prospect', 'team');
select is(
  (select first_stage::text from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'),
  'prospect',
  'first_stage is the stage at insert, whatever the app sends'
);
update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';
select is(
  (select first_stage::text from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'),
  'prospect',
  'a stage change keeps first_stage'
);

-- 3-6: month_plan constraints.
select lives_ok(
  $$ insert into public.month_plan (month, own_volume_target, prospects_target)
     values ('2026-10-01', 500, 4) $$,
  'a plan for a month saves'
);
select throws_ok(
  $$ insert into public.month_plan (month) values ('2026-10-01') $$,
  '23505', null,
  'one plan per month'
);
select throws_ok(
  $$ insert into public.month_plan (month) values ('2026-11-02') $$,
  '23514', null,
  'a month is its first day'
);
select throws_ok(
  $$ insert into public.month_plan (month, prospects_target)
     values ('2026-12-01', -1) $$,
  '23514', null,
  'a count target is not negative'
);

-- 7-8: as B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.month_plan), 0,
  'another user sees no plan'
);
select lives_ok(
  $$ insert into public.month_plan (month) values ('2026-10-01') $$,
  'another user has their own October'
);

-- Back as A for the tasks below.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

select * from finish();
rollback;
```

- [ ] **Step 2: Watch it fail**

No local Docker: RED is CI's `Supabase migrations` job (or `supabase test db` where Docker runs). Expected: `column "first_stage" ... does not exist`.

- [ ] **Step 3: Write the migration**

```sql
-- Goals (#141): what a month aimed for, what it did, and closing it.
-- Counting rules live here once; the device sends its own month bounds
-- because "today" and the time zone are the device's (#48).

-- "Added as a prospect" apart from "moved to prospect".
alter table public.person add column first_stage public.person_stage;
update public.person set first_stage = stage;
alter table public.person alter column first_stage set not null;

create function public.person_first_stage() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  new.first_stage = new.stage;
  return new;
end $$;

create trigger person_first_stage before insert on public.person
  for each row execute function public.person_first_stage();

create table public.month_plan (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  month date not null check (extract(day from month) = 1),
  own_volume_target numeric(12,2) check (own_volume_target >= 0),
  team_volume_target numeric(12,2) check (team_volume_target >= 0),
  level_target text,
  prospects_target int check (prospects_target >= 0),
  customers_target int check (customers_target >= 0),
  team_members_target int check (team_members_target >= 0),
  loyalty_target int check (loyalty_target >= 0),
  -- What was suggested when planning, to compare with what happened.
  loyalty_forecast int check (loyalty_forecast >= 0),
  -- Frozen by close_month.
  own_volume_actual numeric(12,2),
  prospects_actual int,
  customers_actual int,
  team_members_actual int,
  loyalty_actual int,
  -- Typed at close: the company computes them, not the book.
  team_volume_actual numeric(12,2) check (team_volume_actual >= 0),
  level_actual text,
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, month)
);

create trigger month_plan_set_updated_at before update on public.month_plan
  for each row execute function public.set_updated_at();

alter table public.month_plan enable row level security;

create policy month_plan_select_own on public.month_plan
  for select to authenticated using (owner_id = (select auth.uid()));
create policy month_plan_insert_own on public.month_plan
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy month_plan_update_own on public.month_plan
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy month_plan_delete_own on public.month_plan
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.month_plan from anon, authenticated;
grant select, insert, update, delete on public.month_plan to authenticated;
```

`unique (owner_id, month)` serves as the owner index. `set_updated_at()` comes from `20260928144311_people.sql`.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/*_goals.sql supabase/tests/goals_test.sql
git commit -m "feat(goals): store month plans and each person's first stage"
```

---
### Task 2: `month_progress` and `close_month`

**Files:**
- Modify: `supabase/migrations/<timestamp>_goals.sql` (append)
- Modify: `supabase/tests/goals_test.sql`: insert before `select * from finish();` and raise `plan(8)` to `plan(15)`

**Interfaces:**
- Consumes: `person.first_stage`, `month_plan` (Task 1); `activity.amount` (#138), `activity.loyalty_setup` (#140).
- Produces:
  - `public.month_progress(p_month date, p_starts timestamptz, p_ends timestamptz)` returns one row `(own_volume numeric, prospects int, customers int, team_members int, loyalty int)`.
  - `public.close_month(p_month date, p_starts timestamptz, p_ends timestamptz, p_team_volume_actual numeric, p_level_actual text)` returns `public.month_plan`.

- [ ] **Step 1: Write the failing tests**

```sql
-- 9-11: progress. Dates (orders, steps) against the month; instants
-- (people added, stage entries) against the device's bounds, here now ± 1h.
insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a2', 'Léa', 'team'),
  ('00000000-0000-0000-0000-0000000000a3', 'Marc', 'customer');
-- Sarah (a1) went prospect -> customer in Task 1; back and forth once more.
update public.person set stage = 'prospect'
  where id = '00000000-0000-0000-0000-0000000000a1';
update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.activity (person_id, kind, amount, happened_on) values
  ('00000000-0000-0000-0000-0000000000a1', 'order', 100.50, '2026-10-02'),
  ('00000000-0000-0000-0000-0000000000a1', 'order', 50, '2026-09-30');
insert into public.activity (kind, amount, happened_on) values
  ('order', 80, '2026-10-03');
insert into public.activity (person_id, kind, text, happened_on, loyalty_setup) values
  ('00000000-0000-0000-0000-0000000000a3', 'step', 'Set up a refill routine', '2026-10-05', true),
  ('00000000-0000-0000-0000-0000000000a3', 'step', 'Set up a refill routine', '2026-09-29', true),
  ('00000000-0000-0000-0000-0000000000a3', 'step', 'Order arrived', '2026-10-05', false);

select results_eq(
  $$ select * from public.month_progress('2026-10-01',
       now() - interval '1 hour', now() + interval '1 hour') $$,
  $$ values (180.50::numeric, 1, 2, 1, 1) $$,
  'progress: own orders count, a customer counts once, added as customer counts'
);

-- Paris, March 2027: local midnight is 23:00 UTC on Feb 28.
insert into public.person (name, stage, created_at) values
  ('Nina', 'prospect', '2027-02-28 23:30+00'),
  ('Paul', 'prospect', '2027-02-28 22:30+00');
select is(
  (select prospects from public.month_progress('2027-03-01',
     '2027-02-28 23:00+00', '2027-03-31 22:00+00')),
  1,
  'someone added at 00:30 local on the 1st counts in the new month'
);

set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select results_eq(
  $$ select * from public.month_progress('2026-10-01',
       now() - interval '1 hour', now() + interval '1 hour') $$,
  $$ values (0::numeric, 0, 0, 0, 0) $$,
  'another user''s progress is their own'
);
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- 12-15: closing.
select results_eq(
  $$ select own_volume_target, own_volume_actual, prospects_actual,
            customers_actual, team_members_actual, loyalty_actual,
            team_volume_actual, level_actual, closed_at is not null
     from public.close_month('2026-10-01',
       now() - interval '1 hour', now() + interval '1 hour', 1200, ' Elite ') $$,
  $$ values (500::numeric, 180.50::numeric, 1, 2, 1, 1, 1200::numeric,
             'Elite'::text, true) $$,
  'closing freezes the progress, keeps the targets, takes the typed actuals'
);
insert into public.activity (kind, amount, happened_on) values
  ('order', 20, '2026-10-20');
select is(
  (select own_volume_actual from public.month_plan where month = '2026-10-01'),
  180.50::numeric,
  'a later order does not move a closed month'
);
select throws_ok(
  $$ select public.close_month('2026-10-01',
       now() - interval '1 hour', now() + interval '1 hour', null, null) $$,
  'P0001', null,
  'a month closes once'
);
select is(
  (select prospects_actual from public.close_month('2026-08-01',
     '2026-07-31 22:00+00', '2026-08-31 22:00+00', null, '')),
  0,
  'a month with no plan closes into a new record'
);
```

- [ ] **Step 2: Watch it fail**

CI (or `supabase test db`). Expected: `function public.month_progress(...) does not exist`.

- [ ] **Step 3: Append to the migration**

```sql
-- One row: what the month did so far. Dates the user picked (orders, steps)
-- are read against p_month; instants (people added, stage entries) against
-- the device's local month, [p_starts, p_ends).
create function public.month_progress(
  p_month date, p_starts timestamptz, p_ends timestamptz
) returns table (
  own_volume numeric, prospects int, customers int, team_members int,
  loyalty int
)
language sql stable security invoker set search_path = '' as $$
  with bounds as (
    select p_month as first_day, (p_month + interval '1 month')::date as next_month
  ),
  joined as (
    select a.person_id, a.stage from public.activity a
      where a.kind = 'stage'
        and a.created_at >= p_starts and a.created_at < p_ends
    union
    select p.id, p.first_stage from public.person p
      where p.created_at >= p_starts and p.created_at < p_ends
  )
  select
    (select coalesce(sum(a.amount), 0) from public.activity a, bounds b
      where a.kind = 'order'
        and a.happened_on >= b.first_day and a.happened_on < b.next_month),
    (select count(*)::int from public.person p
      where p.first_stage = 'prospect'
        and p.created_at >= p_starts and p.created_at < p_ends),
    (select count(distinct j.person_id)::int from joined j
      where j.stage = 'customer'),
    (select count(distinct j.person_id)::int from joined j
      where j.stage = 'team'),
    (select count(*)::int from public.activity a, bounds b
      where a.kind = 'step' and a.loyalty_setup
        and a.happened_on >= b.first_day and a.happened_on < b.next_month)
$$;

revoke execute on function public.month_progress(date, timestamptz, timestamptz)
  from public, anon;
grant execute on function public.month_progress(date, timestamptz, timestamptz)
  to authenticated;

-- Freezes the month's progress with the two actuals only the company knows.
-- A month closes once; one with no plan gets a record of actuals only.
create function public.close_month(
  p_month date, p_starts timestamptz, p_ends timestamptz,
  p_team_volume_actual numeric, p_level_actual text
) returns public.month_plan
language plpgsql security invoker set search_path = '' as $$
declare
  done record;
  closed public.month_plan;
begin
  select * into done from public.month_progress(p_month, p_starts, p_ends);
  insert into public.month_plan as m (
    month, own_volume_actual, prospects_actual, customers_actual,
    team_members_actual, loyalty_actual, team_volume_actual, level_actual,
    closed_at
  ) values (
    p_month, done.own_volume, done.prospects, done.customers,
    done.team_members, done.loyalty, p_team_volume_actual,
    nullif(trim(p_level_actual), ''), now()
  )
  on conflict (owner_id, month) do update set
    own_volume_actual = excluded.own_volume_actual,
    prospects_actual = excluded.prospects_actual,
    customers_actual = excluded.customers_actual,
    team_members_actual = excluded.team_members_actual,
    loyalty_actual = excluded.loyalty_actual,
    team_volume_actual = excluded.team_volume_actual,
    level_actual = excluded.level_actual,
    closed_at = excluded.closed_at
  where m.closed_at is null
  returning * into closed;
  if closed.id is null then
    raise exception 'month % already closed', p_month using errcode = 'P0001';
  end if;
  return closed;
end $$;

revoke execute on function
  public.close_month(date, timestamptz, timestamptz, numeric, text)
  from public, anon;
grant execute on function
  public.close_month(date, timestamptz, timestamptz, numeric, text)
  to authenticated;
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/*_goals.sql supabase/tests/goals_test.sql
git commit -m "feat(goals): count a month's progress and close it"
```

---
### Task 3: `loyalty_forecast`

**Files:**
- Modify: `supabase/migrations/<timestamp>_goals.sql` (append)
- Modify: `supabase/tests/goals_test.sql`: insert before `select * from finish();` and raise `plan(15)` to `plan(17)`

**Interfaces:**
- Consumes: `workflow_step.loyalty_setup` (#140); `person.workflow_id`, `at_position`, `last_tick`, `paused_at` (#57/#58).
- Produces: `public.loyalty_forecast(p_month date) returns int`.

- [ ] **Step 1: Write the failing tests**

```sql
-- 16-17: the forecast walks due dates from each customer's current step.
insert into public.workflow (id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f2', 'customer', 'Forecast');
insert into public.workflow_step (workflow_id, position, label, days, loyalty_setup) values
  ('00000000-0000-0000-0000-0000000000f2', 1, 'Thank them', 0, false),
  ('00000000-0000-0000-0000-0000000000f2', 2, 'Check in', 14, false),
  ('00000000-0000-0000-0000-0000000000f2', 3, 'Set up a refill routine', 21, true);
insert into public.person (name, stage, workflow_id, at_position, last_tick, paused_at) values
  -- Due Oct 1, Oct 15, then the loyalty step on Nov 5.
  ('On step 1', 'customer', '00000000-0000-0000-0000-0000000000f2', 1, '2026-10-01', null),
  -- Loyalty step due Sep 22: late, still to do.
  ('Late', 'customer', '00000000-0000-0000-0000-0000000000f2', 3, '2026-09-01', null),
  ('Paused', 'customer', '00000000-0000-0000-0000-0000000000f2', 3, '2026-09-01', now()),
  ('Done', 'customer', '00000000-0000-0000-0000-0000000000f2', 1e9, '2026-09-01', null),
  ('Not a customer', 'prospect', '00000000-0000-0000-0000-0000000000f2', 3, '2026-09-01', null);

select is(
  public.loyalty_forecast('2026-10-01'), 1,
  'October: the late one only; paused, done and prospects never'
);
select is(
  public.loyalty_forecast('2026-11-01'), 2,
  'November: the walk reaches Nov 5, and the late one is still to do'
);
```

- [ ] **Step 2: Watch it fail**

CI. Expected: `function public.loyalty_forecast(date) does not exist`.

- [ ] **Step 3: Append to the migration**

```sql
-- How many customers likely set up loyalty in p_month: those whose next
-- loyalty step comes due before the month ends. Due dates are walked from
-- the current step as due_on does: the last tick plus each step's days. A
-- late step is still to do, so it counts in the month being planned.
create function public.loyalty_forecast(p_month date) returns int
language sql stable security invoker set search_path = '' as $$
  select count(*)::int from public.person p
  where p.stage = 'customer' and p.paused_at is null
    and exists (
      select 1 from (
        select s.loyalty_setup,
               p.last_tick + (sum(s.days) over (order by s.position))::int as due
        from public.workflow_step s
        where s.workflow_id = p.workflow_id and s.position >= p.at_position
      ) walk
      where walk.loyalty_setup
        and walk.due < (p_month + interval '1 month')::date
    )
$$;

revoke execute on function public.loyalty_forecast(date) from public, anon;
grant execute on function public.loyalty_forecast(date) to authenticated;
```

Check the walk against `due_on` in `20260929132701_today_due_steps.sql` (or its latest `create or replace`). The first due date must be `last_tick + days` of the current step.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/*_goals.sql supabase/tests/goals_test.sql
git commit -m "feat(goals): forecast the month's loyalty setups"
```

---
### Task 4: Domain — `MonthPlan`, `Progress`, `pace`, `ritualWindow`, `suggest`

**Files:**
- Create: `lib/features/goals/domain/month_plan.dart`
- Create: `lib/features/goals/domain/goal_rules.dart`
- Delete: `lib/features/goals/.gitkeep`
- Test: `test/features/goals/domain/goal_rules_test.dart`

**Interfaces:**
- Produces:
  - `class Progress { double ownVolume; int prospects, customers, teamMembers, loyalty; }` (const constructor, all required).
  - `class MonthPlan`: `DateTime month` (local first of month), nullable targets `ownVolumeTarget`, `teamVolumeTarget` (`double?`), `levelTarget` (`String?`), `prospectsTarget`, `customersTarget`, `teamMembersTarget`, `loyaltyTarget`, `loyaltyForecast` (`int?`), `Progress? actual`, `double? teamVolumeActual`, `String? levelActual`, `DateTime? closedAt`, `bool get closed`.
  - `typedef Pace = ({double projected, bool onPace}); Pace? pace(num? target, num done, DateTime today)`
  - `typedef Ritual = ({DateTime close, DateTime plan}); Ritual? ritualWindow(DateTime today)`
  - `typedef Suggestion = ({double? ownVolume, double? teamVolume, int? prospects, int? customers, int? teamMembers}); Suggestion suggest(List<MonthPlan> plans)`

- [ ] **Step 1: Write the failing tests**

`test/features/goals/domain/goal_rules_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';

MonthPlan _closed(
  int month, {
  double ownVolume = 0,
  int prospects = 0,
  double? teamVolume,
}) => MonthPlan(
  month: DateTime(2026, month),
  actual: Progress(
    ownVolume: ownVolume,
    prospects: prospects,
    customers: 0,
    teamMembers: 0,
    loyalty: 0,
  ),
  teamVolumeActual: teamVolume,
  closedAt: DateTime(2026, month + 1),
);

void main() {
  group('pace', () {
    test('nothing in the first 3 days', () {
      expect(pace(2800, 100, DateTime(2026, 9, 3)), isNull);
    });

    test('nothing without a target', () {
      expect(pace(null, 100, DateTime(2026, 9, 19)), isNull);
    });

    test('projects the month end from the days gone', () {
      // 1 840 in 19 of 30 days: about 2 905 by the 30th.
      final result = pace(2800, 1840, DateTime(2026, 9, 19))!;
      expect(result.projected, closeTo(2905.26, 0.01));
      expect(result.onPace, isTrue);
    });

    test('behind when the projection falls short', () {
      expect(pace(2800, 1000, DateTime(2026, 9, 19))!.onPace, isFalse);
    });
  });

  group('ritualWindow', () {
    test('the last 3 days close this month and plan the next', () {
      expect(ritualWindow(DateTime(2026, 9, 28)), (
        close: DateTime(2026, 9),
        plan: DateTime(2026, 10),
      ));
      expect(ritualWindow(DateTime(2026, 12, 29))?.plan, DateTime(2027));
    });

    test('February opens on the 26th of 28', () {
      expect(ritualWindow(DateTime(2027, 2, 26))?.close, DateTime(2027, 2));
      expect(ritualWindow(DateTime(2027, 2, 25)), isNull);
    });

    test('the first 5 days close the previous month', () {
      expect(ritualWindow(DateTime(2026, 10, 5)), (
        close: DateTime(2026, 9),
        plan: DateTime(2026, 10),
      ));
      expect(ritualWindow(DateTime(2027, 1, 1))?.close, DateTime(2026, 12));
    });

    test('closed from the 6th until 3 days before the end', () {
      expect(ritualWindow(DateTime(2026, 10, 6)), isNull);
      expect(ritualWindow(DateTime(2026, 10, 28)), isNull);
    });
  });

  group('suggest', () {
    test('nothing without a closed month', () {
      final none = suggest([MonthPlan(month: DateTime(2026, 9))]);
      expect(none.ownVolume, isNull);
      expect(none.prospects, isNull);
    });

    test('the rounded mean of the last 3 closed months', () {
      final result = suggest([
        _closed(5, ownVolume: 9000, prospects: 9),
        _closed(6, ownVolume: 1000, prospects: 2),
        _closed(7, ownVolume: 1500, prospects: 3),
        _closed(8, ownVolume: 2000, prospects: 3),
        MonthPlan(month: DateTime(2026, 9)),
      ]);
      expect(result.ownVolume, 1500);
      expect(result.prospects, 3);
    });

    test('team volume from the months it was typed', () {
      final result = suggest([
        _closed(6, teamVolume: 4000),
        _closed(7),
        _closed(8, teamVolume: 5001),
      ]);
      expect(result.teamVolume, 4501);
    });
  });
}
```

- [ ] **Step 2: Run them**

Run: `flutter test test/features/goals`
Expected: compile errors, the `goal_rules.dart` and `month_plan.dart` imports don't exist.

- [ ] **Step 3: Implement**

`lib/features/goals/domain/month_plan.dart`:

```dart
/// What a month did: own volume (PV for dōTERRA) and four counts.
class Progress {
  const Progress({
    required this.ownVolume,
    required this.prospects,
    required this.customers,
    required this.teamMembers,
    required this.loyalty,
  });

  final double ownVolume;

  /// People added as prospects.
  final int prospects;

  /// People who became customers, or were added as one.
  final int customers;

  /// People who joined the team, or were added to it.
  final int teamMembers;

  /// Loyalty steps ticked.
  final int loyalty;
}

/// One month: what the user aimed for and, once closed, what happened.
/// Every target is optional.
class MonthPlan {
  const MonthPlan({
    required this.month,
    this.ownVolumeTarget,
    this.teamVolumeTarget,
    this.levelTarget,
    this.prospectsTarget,
    this.customersTarget,
    this.teamMembersTarget,
    this.loyaltyTarget,
    this.loyaltyForecast,
    this.actual,
    this.teamVolumeActual,
    this.levelActual,
    this.closedAt,
  });

  /// Local midnight on the 1st.
  final DateTime month;
  final double? ownVolumeTarget;
  final double? teamVolumeTarget;
  final String? levelTarget;
  final int? prospectsTarget;
  final int? customersTarget;
  final int? teamMembersTarget;
  final int? loyaltyTarget;

  /// What the forecast said when planning.
  final int? loyaltyForecast;

  /// Frozen at close; null while open.
  final Progress? actual;

  /// Typed at close: the company computes them, not the book.
  final double? teamVolumeActual;
  final String? levelActual;
  final DateTime? closedAt;

  bool get closed => closedAt != null;
}
```

`lib/features/goals/domain/goal_rules.dart`:

```dart
import 'package:loomia/features/goals/domain/month_plan.dart';

int _daysIn(DateTime day) => DateTime(day.year, day.month + 1, 0).day;

/// Where the month ends at this rate, and whether that reaches [target].
typedef Pace = ({double projected, bool onPace});

/// Null without a target, and in the first 3 days, when a projection means
/// nothing.
Pace? pace(num? target, num done, DateTime today) {
  if (target == null || today.day <= 3) return null;
  final projected = done / today.day * _daysIn(today);
  return (projected: projected.toDouble(), onPace: projected >= target);
}

/// The month to close and the month to plan, both the 1st at local midnight.
typedef Ritual = ({DateTime close, DateTime plan});

/// Open the last 3 days of a month (closing it) and the first 5 of the next
/// (closing the one before). Null in between.
Ritual? ritualWindow(DateTime today) {
  final month = DateTime(today.year, today.month);
  if (today.day >= _daysIn(today) - 2) {
    return (close: month, plan: DateTime(today.year, today.month + 1));
  }
  if (today.day <= 5) {
    return (close: DateTime(today.year, today.month - 1), plan: month);
  }
  return null;
}

/// Targets to start from. Loyalty comes from the forecast instead, and the
/// level is the user's own call.
typedef Suggestion = ({
  double? ownVolume,
  double? teamVolume,
  int? prospects,
  int? customers,
  int? teamMembers,
});

/// Per objective, the rounded mean of what the last 3 closed months did.
/// Null where none of them has a value.
Suggestion suggest(List<MonthPlan> plans) {
  final closed = [...plans.where((plan) => plan.closed)]
    ..sort((a, b) => b.month.compareTo(a.month));
  final last = closed.take(3).toList();
  double? mean(num? Function(MonthPlan plan) value) {
    final known = last.map(value).nonNulls.toList();
    if (known.isEmpty) return null;
    return known.reduce((a, b) => a + b) / known.length;
  }

  return (
    ownVolume: mean((plan) => plan.actual?.ownVolume)?.roundToDouble(),
    teamVolume: mean((plan) => plan.teamVolumeActual)?.roundToDouble(),
    prospects: mean((plan) => plan.actual?.prospects)?.round(),
    customers: mean((plan) => plan.actual?.customers)?.round(),
    teamMembers: mean((plan) => plan.actual?.teamMembers)?.round(),
  );
}
```

`git rm lib/features/goals/.gitkeep`.

- [ ] **Step 4: Run them**

Run: `flutter test test/features/goals`
Expected: all pass. Own volume is (2000 + 1500 + 1000) / 3 = 1500, prospects 8 / 3 rounds to 3, and team volume 4500.5 rounds to 4501.

- [ ] **Step 5: Commit**

```bash
git add -A lib/features/goals test/features/goals
git commit -m "feat(goals): month plan, pace, ritual window and suggested targets"
```

---
### Task 5: `GoalsRepository`

**Files:**
- Create: `lib/features/goals/data/goals_repository.dart`
- Test: `test/features/goals/data/goals_repository_test.dart`

**Interfaces:**
- Consumes: the three RPCs (Tasks 2-3), `month_plan` (Task 1), `MonthPlan`/`Progress` (Task 4), `guardPeople` and `dayColumn` from `lib/features/contacts/data/people_repository.dart`, `supabaseClientProvider`.
- Produces: `GoalsRepository` with `plans()`, `saveTargets(MonthPlan)`, `progress(DateTime month)`, `forecast(DateTime month)`, `close(DateTime month, {double? teamVolume, String? level})`; `goalsRepositoryProvider`; top-level `monthPlanFromRow`, `targetsToRow`, `progressFromRow`, `monthBounds`.

- [ ] **Step 1: Write the failing tests**

`test/features/goals/data/goals_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';

void main() {
  test('the local month as two instants', () {
    final (:starts, :ends) = monthBounds(DateTime(2026, 12));
    expect(starts, DateTime(2026, 12).toUtc());
    expect(ends, DateTime(2027).toUtc());
    expect(starts.isUtc, isTrue);
  });

  test('reads an open plan: targets, no actuals', () {
    final plan = monthPlanFromRow({
      'month': '2026-10-01',
      'own_volume_target': 500,
      'team_volume_target': null,
      'level_target': 'Elite',
      'prospects_target': 4,
      'customers_target': null,
      'team_members_target': null,
      'loyalty_target': 3,
      'loyalty_forecast': 2,
      'own_volume_actual': null,
      'prospects_actual': null,
      'customers_actual': null,
      'team_members_actual': null,
      'loyalty_actual': null,
      'team_volume_actual': null,
      'level_actual': null,
      'closed_at': null,
    });

    expect(plan.month, DateTime(2026, 10));
    expect(plan.ownVolumeTarget, 500.0);
    expect(plan.levelTarget, 'Elite');
    expect(plan.prospectsTarget, 4);
    expect(plan.loyaltyForecast, 2);
    expect(plan.closed, isFalse);
    expect(plan.actual, isNull);
  });

  test('reads a closed plan with its frozen actuals', () {
    final plan = monthPlanFromRow({
      'month': '2026-09-01',
      'own_volume_target': null,
      'team_volume_target': null,
      'level_target': null,
      'prospects_target': null,
      'customers_target': null,
      'team_members_target': null,
      'loyalty_target': null,
      'loyalty_forecast': null,
      'own_volume_actual': 180.5,
      'prospects_actual': 1,
      'customers_actual': 2,
      'team_members_actual': 1,
      'loyalty_actual': 1,
      'team_volume_actual': 1200,
      'level_actual': 'Elite',
      'closed_at': '2026-10-01T08:00:00+00:00',
    });

    expect(plan.closed, isTrue);
    expect(plan.actual!.ownVolume, 180.5);
    expect(plan.actual!.customers, 2);
    expect(plan.teamVolumeActual, 1200.0);
  });

  test('writes the targets and the forecast, never the actuals', () {
    final row = targetsToRow(
      MonthPlan(
        month: DateTime(2026, 11),
        ownVolumeTarget: 600,
        loyaltyForecast: 3,
        teamVolumeActual: 9,
      ),
    );

    expect(row['month'], '2026-11-01');
    expect(row['own_volume_target'], 600);
    expect(row['loyalty_forecast'], 3);
    // Cleared targets are written as null, not left as they were.
    expect(row.containsKey('prospects_target'), isTrue);
    expect(row['prospects_target'], isNull);
    expect(row.keys.where((key) => key.endsWith('_actual')), isEmpty);
    expect(row.containsKey('closed_at'), isFalse);
  });

  test('reads progress; numeric volume may come as an int', () {
    final progress = progressFromRow({
      'own_volume': 0,
      'prospects': 1,
      'customers': 2,
      'team_members': 0,
      'loyalty': 1,
    });

    expect(progress.ownVolume, 0.0);
    expect(progress.customers, 2);
  });
}
```

- [ ] **Step 2: Run them**

Run: `flutter test test/features/goals/data`
Expected: compile error, `goals_repository.dart` doesn't exist.

- [ ] **Step 3: Implement**

`lib/features/goals/data/goals_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `month_plan` table and the goal functions. Every method throws
/// [PeopleFailure] and nothing else. RLS scopes everything to the user.
class GoalsRepository {
  GoalsRepository(this._client);

  final SupabaseClient _client;

  /// Latest month first.
  Future<List<MonthPlan>> plans() => guardPeople(() async {
    final rows = await _client
        .from('month_plan')
        .select()
        .order('month', ascending: false);
    return rows.map(monthPlanFromRow).toList();
  });

  /// Creates or updates the plan's month with its targets and forecast.
  Future<MonthPlan> saveTargets(MonthPlan plan) => guardPeople(() async {
    final row = await _client
        .from('month_plan')
        .upsert(targetsToRow(plan), onConflict: 'owner_id,month')
        .select()
        .single();
    return monthPlanFromRow(row);
  });

  /// What [month] did so far, counted by the server in the device's month.
  Future<Progress> progress(DateTime month) => guardPeople(() async {
    final row = await _client
        .rpc<Object?>('month_progress', params: _monthParams(month))
        .single();
    return progressFromRow(row);
  });

  /// Customers likely to set up loyalty in [month].
  Future<int> forecast(DateTime month) => guardPeople(
    () => _client.rpc<int>(
      'loyalty_forecast',
      params: {'p_month': dayColumn(month)},
    ),
  );

  /// Freezes [month]'s progress with the two figures only the company
  /// knows. A month closes once: a second close is a failure.
  Future<MonthPlan> close(
    DateTime month, {
    double? teamVolume,
    String? level,
  }) => guardPeople(() async {
    final row = await _client
        .rpc<Object?>(
          'close_month',
          params: {
            ..._monthParams(month),
            'p_team_volume_actual': teamVolume,
            'p_level_actual': level,
          },
        )
        .select()
        .single();
    return monthPlanFromRow(row);
  });

  Map<String, Object?> _monthParams(DateTime month) {
    final (:starts, :ends) = monthBounds(month);
    return {
      'p_month': dayColumn(month),
      'p_starts': starts.toIso8601String(),
      'p_ends': ends.toIso8601String(),
    };
  }
}

final goalsRepositoryProvider = Provider<GoalsRepository>(
  (ref) => GoalsRepository(ref.watch(supabaseClientProvider)),
);

/// [month]'s local midnights, the 1st and the next 1st, as UTC: the server
/// counts people added between them, whatever its own time zone.
({DateTime starts, DateTime ends}) monthBounds(DateTime month) => (
  starts: DateTime(month.year, month.month).toUtc(),
  ends: DateTime(month.year, month.month + 1).toUtc(),
);

double? _number(Object? value) => (value as num?)?.toDouble();

MonthPlan monthPlanFromRow(Map<String, dynamic> row) {
  final closedAt = switch (row['closed_at']) {
    final String at => DateTime.parse(at),
    _ => null,
  };
  return MonthPlan(
    // A bare date parses as local midnight.
    month: DateTime.parse(row['month'] as String),
    ownVolumeTarget: _number(row['own_volume_target']),
    teamVolumeTarget: _number(row['team_volume_target']),
    levelTarget: row['level_target'] as String?,
    prospectsTarget: row['prospects_target'] as int?,
    customersTarget: row['customers_target'] as int?,
    teamMembersTarget: row['team_members_target'] as int?,
    loyaltyTarget: row['loyalty_target'] as int?,
    loyaltyForecast: row['loyalty_forecast'] as int?,
    actual: closedAt == null
        ? null
        : Progress(
            ownVolume: _number(row['own_volume_actual']) ?? 0,
            prospects: row['prospects_actual'] as int? ?? 0,
            customers: row['customers_actual'] as int? ?? 0,
            teamMembers: row['team_members_actual'] as int? ?? 0,
            loyalty: row['loyalty_actual'] as int? ?? 0,
          ),
    teamVolumeActual: _number(row['team_volume_actual']),
    levelActual: row['level_actual'] as String?,
    closedAt: closedAt,
  );
}

/// What planning writes. Actuals and `closed_at` are `close_month`'s.
Map<String, Object?> targetsToRow(MonthPlan plan) => {
  'month': dayColumn(plan.month),
  'own_volume_target': plan.ownVolumeTarget,
  'team_volume_target': plan.teamVolumeTarget,
  'level_target': plan.levelTarget,
  'prospects_target': plan.prospectsTarget,
  'customers_target': plan.customersTarget,
  'team_members_target': plan.teamMembersTarget,
  'loyalty_target': plan.loyaltyTarget,
  'loyalty_forecast': plan.loyaltyForecast,
};

Progress progressFromRow(Map<String, dynamic> row) => Progress(
  ownVolume: _number(row['own_volume']) ?? 0,
  prospects: row['prospects'] as int,
  customers: row['customers'] as int,
  teamMembers: row['team_members'] as int,
  loyalty: row['loyalty'] as int,
);
```

`.rpc(...).single()` on a set-returning function gives one row as a map. Check against `completeStep` in `people_repository.dart`, which chains `.select(_columns).single()`. If `progress` needs `.select()` before `.single()` to type-check, add it. `upsert(..., onConflict: 'owner_id,month')` lets the column default fill `owner_id` on insert. The real calls are exercised by #142's screens, not unit tests: the mapping functions are what's tested here.

- [ ] **Step 4: Run them**

Run: `flutter test test/features/goals`
Expected: all pass.

- [ ] **Step 5: Gate and commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: no changes left, "No issues found!", all pass.

```bash
git add lib/features/goals test/features/goals
git commit -m "feat(goals): read and write month plans, progress and the forecast"
```
