# Loyalty Setup Step Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A workflow step can be marked "Counts as a loyalty setup", and ticking it leaves a `step` history entry that keeps the flag (#140). The default "New customer" workflow comes with one.

**Architecture:** One migration adds `loyalty_setup` to `workflow_step` and to `activity`. It also replaces `complete_step` so the flag is copied when the step is ticked, and `seed_workflows` so the default "New customer" workflow ends on a loyalty step. Accounts that are already seeded get that step marked too. The Dart side adds `WorkflowStep.loyaltySetup`, sends it in the repository's `addStep`/`updateStep`, and adds a switch to the step sheet with business-model copy. No reader of `activity.loyalty_setup` yet: counting is #141.

**Tech Stack:** Flutter (`flutter_riverpod`, `material_ui`), Supabase Postgres + pgTAP.

**Spec:** `docs/superpowers/specs/2026-10-02-goals-design.md` §2 (Loyalty flag on steps), §4 (Workflow editor), §5 (Copy). Figma: Workflow step — loyalty switch (node 205:3185).

## Global Constraints

- Schema changes only via `supabase migration new`; pgTAP tests in `supabase/tests/`, run in CI only (no Docker locally).
- `complete_step` stays `security invoker set search_path = ''`, same signature `(uuid, uuid, date)`; keep its revoke/grant lines.
- `loyalty_setup` only on `step` entries (spec §2).
- Copy: English only in `lib/l10n/app_en.arb`, every key with a description, business-model words through `select` on `model.name` (`doterra` / `other`). Run `flutter gen-l10n` after editing.
- Material from `package:material_ui/material_ui.dart`; imports `package:loomia/...`.
- Theme values only from the theme; no hard-coded sizes or colours.
- Goldens: `workflow_step_light.png` changes. Never commit a locally made golden; regenerate through CI (README → Golden tests).
- Quality gate: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`.

## Review Focus

1. Renaming or deleting a loyalty step after it was ticked: the past `step` entry keeps `loyalty_setup = true` (pinned in Task 1).
2. Turning the switch off on an existing step: the update sends `false`, not "unchanged" (pinned in Task 3).
3. A note, call or order sent with `loyalty_setup = true` through the table grant: refused (pinned in Task 1).
4. Editing a step's label or days only: the flag already on stays on (pinned in Task 3).
5. Other business model: the hint has no "LRP" (pinned in Task 3).
6. An already seeded account: its untouched "Suggest a refill routine" step becomes a loyalty step, and a renamed or moved one is left alone. Not pinned: the backfill runs once, at migration time, before any test. Check it by reading the migration.

---

### Task 1: Database — the flag on steps and on step entries

**Files:**
- Create: `supabase/migrations/<timestamp>_loyalty_step.sql` (via `supabase migration new loyalty_step`)
- Create: `supabase/tests/loyalty_step_test.sql`

**Interfaces:**
- Produces: column `workflow_step.loyalty_setup boolean not null default false`; column `activity.loyalty_setup boolean not null default false` with constraint `loyalty_only_on_steps`; `complete_step` copies the flag; `seed_workflows` marks New customer's last step.

- [ ] **Step 1: Write the failing pgTAP test**

`supabase/tests/loyalty_step_test.sql`:

```sql
-- Loyalty setups (#140): a step can count as one, and ticking it copies the
-- flag onto the step entry, so renaming or deleting the step keeps the count.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.workflow (id, stage, name) values
  ('00000000-0000-0000-0000-0000000000f1', 'customer', 'New customer');
insert into public.workflow_step (id, workflow_id, position, label, days, loyalty_setup) values
  ('00000000-0000-0000-0000-0000000000e1',
   '00000000-0000-0000-0000-0000000000f1', 1, 'Welcome call', 0, false),
  ('00000000-0000-0000-0000-0000000000e2',
   '00000000-0000-0000-0000-0000000000f1', 2, 'Set up their LRP', 7, true);
insert into public.person (id, name, stage, workflow_id, at_position, last_tick) values
  ('00000000-0000-0000-0000-0000000000a1', 'Claire', 'customer',
   '00000000-0000-0000-0000-0000000000f1', 1, '2026-10-01');

select public.complete_step(
  '00000000-0000-0000-0000-0000000000a1',
  '00000000-0000-0000-0000-0000000000e1', '2026-10-02');
select is(
  (select loyalty_setup from public.activity where text = 'Welcome call'),
  false,
  'an ordinary step leaves an ordinary entry'
);

select public.complete_step(
  '00000000-0000-0000-0000-0000000000a1',
  '00000000-0000-0000-0000-0000000000e2', '2026-10-09');
select is(
  (select loyalty_setup from public.activity where text = 'Set up their LRP'),
  true,
  'a loyalty step leaves a loyalty entry'
);

update public.workflow_step set label = 'LRP', loyalty_setup = false
  where id = '00000000-0000-0000-0000-0000000000e2';
delete from public.workflow_step
  where id = '00000000-0000-0000-0000-0000000000e2';
select is(
  (select count(*)::int from public.activity where loyalty_setup), 1,
  'the entry keeps the flag after the step changes and goes'
);

select is(
  (select loyalty_setup from public.workflow_step
    where id = '00000000-0000-0000-0000-0000000000e1'),
  false,
  'a step is not a loyalty setup unless marked'
);
select throws_ok(
  $$ insert into public.activity (person_id, kind, text, loyalty_setup) values
     ('00000000-0000-0000-0000-0000000000a1', 'note', 'Hi', true) $$,
  '23514', null,
  'only a step entry is a loyalty setup'
);
select lives_ok(
  $$ insert into public.activity (person_id, kind, text) values
     ('00000000-0000-0000-0000-0000000000a1', 'note', 'Hi') $$,
  'other entries still save'
);

-- The seed: New customer ends on its loyalty step; nothing else is one.
select public.seed_workflows('en', '2026-10-04');
select results_eq(
  $$ select w.name, s.label from public.workflow_step s
     join public.workflow w on w.id = s.workflow_id
     where s.loyalty_setup $$,
  $$ values ('New customer'::text, 'Set up a refill routine'::text) $$,
  'the seed marks one loyalty step, at the end of New customer'
);
select is(
  (select s.position from public.workflow_step s
     join public.workflow w on w.id = s.workflow_id
     where w.name = 'New customer' and s.loyalty_setup),
  4::numeric,
  'it stays the last of the four steps'
);

select * from finish();
rollback;
```

`person.workflow_id`, `at_position` and `last_tick` come from `20260929085602_workflows.sql`. `current_step_id` (`20260929132701_today_due_steps.sql`) picks the first step at or after `at_position`. `complete_step` raises `P0002` when the step is not current, so a wrong setup fails loudly.

- [ ] **Step 2: Watch it fail**

No local Docker: the RED run is CI's `Supabase migrations` job, or `supabase test db` if Docker is available. Expected: fails on `column "loyalty_setup" ... does not exist`.

- [ ] **Step 3: Write the migration**

`supabase migration new loyalty_step`, then:

```sql
-- Loyalty setups (#140): a workflow step can count as one ("Counts as a
-- loyalty setup", an LRP for dōTERRA). Ticking it copies the flag onto the
-- step entry, so renaming or deleting the step keeps past counts. The
-- existing RLS and grants cover both columns.
alter table public.workflow_step
  add column loyalty_setup boolean not null default false;

alter table public.activity
  add column loyalty_setup boolean not null default false,
  add constraint loyalty_only_on_steps
    check (not loyalty_setup or kind = 'step');

create or replace function public.complete_step(p_person uuid, p_step uuid, p_on date)
returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.person;
  step public.workflow_step;
  next_position numeric;
  moved public.person;
begin
  select * into target from public.person where id = p_person for update;
  if target.id is null
    or public.current_step_id(target) is distinct from p_step then
    raise exception 'step % is not the current step of person %', p_step, p_person
      using errcode = 'P0002';
  end if;

  select * into step from public.workflow_step where id = p_step;
  select coalesce(min(s.position), 1e9) into next_position
    from public.workflow_step s
    where s.workflow_id = step.workflow_id and s.position > step.position;

  insert into public.activity (person_id, kind, text, happened_on, loyalty_setup)
    values (p_person, 'step', step.label, p_on, step.loyalty_setup);
  update public.person
    set at_position = next_position, last_tick = p_on
    where id = p_person
    returning * into moved;
  return moved;
end $$;

revoke execute on function public.complete_step(uuid, uuid, date) from public, anon;
grant execute on function public.complete_step(uuid, uuid, date) to authenticated;
```

The body is `20260929181039_edit_workflows.sql`'s, with only the insert changed. Diff the two before committing.

Then, in the same migration, `create or replace function public.seed_workflows(p_lang text, p_today date)`. Copy the whole function from `20260929181039_edit_workflows.sql` (lines 28 to its `end $$;`), then repeat its revoke/grant from `20260929085602_workflows.sql:200-203` (`create or replace` keeps them, but the repeat is cheap and matches `complete_step`). Make exactly two changes:

1. In the `'customer', true` (New customer) row, the last step becomes a loyalty step, with a third array element, and its label says the setup is done when ticked:

```sql
       case when fr then
         '[["Remercier pour la commande",0],["Commande reçue",5],["Prendre des nouvelles des produits",14],["Mettre en place un réassort régulier",21,true]]'
       else
         '[["Thank them for the order",0],["Order arrived",5],["Check in on the products",14],["Set up a refill routine",21,true]]'
       end::jsonb),
```

2. The step insert reads the third element, false when absent:

```sql
    insert into public.workflow_step (workflow_id, position, label, days, loyalty_setup)
      select new_id, s.ord, s.value ->> 0, (s.value ->> 1)::int,
             coalesce((s.value ->> 2)::boolean, false)
      from jsonb_array_elements(w.steps) with ordinality as s(value, ord);
```

"Suggest a refill routine" becomes "Set up a refill routine": ticking a step that only suggests it would count a setup that never happened. The seeded workflows are the same for every business model, so the label stays neutral ("refill routine", not "LRP").

Last, the already seeded accounts. The migration runs as the owner, so this reaches every account. It only marks the step still exactly as seeded: the last step of a workflow still named "New customer" / "Nouveau client", with its seeded label. Labels the user wrote are left alone:

```sql
-- Accounts seeded before #140: their New customer workflow, if still as
-- seeded, gets the same loyalty step. The label is the user's now and stays.
update public.workflow_step s
  set loyalty_setup = true
  from public.workflow w
  where w.id = s.workflow_id
    and w.stage = 'customer'
    and w.name in ('New customer', 'Nouveau client')
    and s.label in ('Suggest a refill routine', 'Proposer un réassort régulier');
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/*_loyalty_step.sql supabase/tests
git commit -m "feat(workflows): store whether a step is a loyalty setup"
```

---

### Task 2: Model and repository

**Files:**
- Modify: `lib/features/workflows/domain/workflow.dart` (`WorkflowStep`)
- Modify: `lib/features/workflows/data/workflow_repository.dart` (`addStep`, `updateStep`, `workflowFromRow`)
- Modify: `test/features/workflows/fake_workflow_repository.dart` (`addStep`, `updateStep`, `moveStep` copy the flag)
- Test: `test/features/workflows/data/workflow_repository_test.dart`

**Interfaces:**
- Consumes: column `workflow_step.loyalty_setup` (Task 1).
- Produces: `WorkflowStep.loyaltySetup` (`bool`, constructor `this.loyaltySetup = false`); `addStep(..., bool loyaltySetup = false)` and `updateStep(..., required bool loyaltySetup)`.

- [ ] **Step 1: Write the failing test**

In `workflow_repository_test.dart`, add `'loyalty_setup': true` to step `s2` of `row()` and `'loyalty_setup': false` to `s1`, then:

```dart
  test('reads which step is a loyalty setup', () {
    final workflow = workflowFromRow(row());

    expect([for (final s in workflow.steps) s.loyaltySetup], [false, true]);
  });
```

- [ ] **Step 2: Run it**

Run: `flutter test test/features/workflows/data/workflow_repository_test.dart`
Expected: compile error, `loyaltySetup` isn't defined for `WorkflowStep`.

- [ ] **Step 3: Implement**

`WorkflowStep`:

```dart
    this.note,
    this.loyaltySetup = false,
  });
  ...
  final String? note;

  /// Ticking it counts one loyalty setup (an LRP for dōTERRA) for the month.
  final bool loyaltySetup;
```

`workflowFromRow`, in the step: `loyaltySetup: step['loyalty_setup'] as bool,`.

`addStep` gains `bool loyaltySetup = false` and inserts `'loyalty_setup': loyaltySetup`. `updateStep` gains `required bool loyaltySetup` and updates `'loyalty_setup': loyaltySetup`. Required on update so a caller can't drop the flag by forgetting it.

Fake: same parameters; `addStep` and `updateStep` build `WorkflowStep(..., loyaltySetup: loyaltySetup)`, `moveStep` copies `loyaltySetup: step.loyaltySetup`. Leave the recorded `updateStep(...)` call string unchanged: `step_sheet_test.dart:83` and `workflow_editor_test.dart:347` match it exactly.

- [ ] **Step 4: Run it**

Run: `flutter test test/features/workflows`
Expected: all pass. `step_sheet.dart` fails to compile until it passes `loyaltySetup` to `updateStep`: pass `loyaltySetup: step.loyaltySetup` there for now. Task 3 replaces it.

- [ ] **Step 5: Commit**

```bash
git add lib/features/workflows test/features/workflows
git commit -m "feat(workflows): read and write whether a step is a loyalty setup"
```

---

### Task 3: Step sheet switch

**Files:**
- Modify: `lib/features/workflows/presentation/step_sheet.dart`
- Modify: `lib/features/workflows/presentation/workflows_preview.dart` (pass `model: BusinessModel.other`)
- Modify: `lib/l10n/app_en.arb`
- Modify: `docs/design/screens.md` §8 (Step paragraph)
- Test: `test/features/workflows/presentation/step_sheet_test.dart`

**Interfaces:**
- Consumes: `WorkflowStep.loyaltySetup`, `addStep(loyaltySetup:)`, `updateStep(loyaltySetup:)` (Task 2).
- Produces: `StepDraft = ({String label, int days, String? note, bool loyaltySetup})`; `StepForm({required BusinessModel model, ...})`.

- [ ] **Step 1: Copy**

`app_en.arb`, after `stepNote`:

```json
  "stepLoyalty": "Counts as a loyalty setup",
  "@stepLoyalty": {
    "description": "Switch on a workflow step: ticking this step means the person set up a loyalty order (an LRP for dōTERRA). Goals counts these."
  },
  "stepLoyaltyHint": "{model, select, doterra{When you tick this step, it counts as one LRP for the month.} other{When you tick this step, it counts as one loyalty order for the month.}}",
  "@stepLoyaltyHint": {
    "description": "Under the loyalty switch on a workflow step. dōTERRA: LRP (Loyalty Rewards Program, not translated). Other: neutral words.",
    "placeholders": {
      "model": { "type": "String" }
    }
  },
```

The Figma hint says "Goals counts one LRP for the month". The Goals tab doesn't exist until #142, so the hint doesn't name it. Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

In `step_sheet_test.dart`, let `open` take `Account account = const Account(firstName: 'Pauline', email: 'p@example.com')` and pass it to `pumpFormHarness`. Add:

```dart
  group('loyalty setup', () {
    const doterra = Account(
      firstName: 'Pauline',
      email: 'p@example.com',
      businessModel: BusinessModel.doterra,
    );

    Future<void> toggle(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Counts as a loyalty setup'));
      await tester.tap(find.text('Counts as a loyalty setup'));
      await tester.pump();
    }

    WorkflowStep step(int index) => workflows.store.first.steps[index];

    testWidgets('a new step can count as one', (tester) async {
      await open(tester, account: doterra);

      expect(
        find.text(
          'When you tick this step, it counts as one LRP for the month.',
        ),
        findsOneWidget,
      );
      await tester.enterText(field('What to do'), 'Set up their LRP');
      await toggle(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(workflows.store.first.steps.last.loyaltySetup, isTrue);
    });

    testWidgets('a step is not one unless switched on', (tester) async {
      await open(tester);

      await tester.enterText(field('What to do'), 'Say thanks');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(workflows.store.first.steps.last.loyaltySetup, isFalse);
    });

    testWidgets('switching it off is saved', (tester) async {
      await open(tester, index: 1);
      await toggle(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(step(1).loyaltySetup, isTrue);

      await open(tester, index: 1);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await toggle(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(step(1).loyaltySetup, isFalse);
    });

    testWidgets('editing the label keeps it on', (tester) async {
      await open(tester, index: 1);
      await toggle(tester);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      await open(tester, index: 1);
      await tester.enterText(field('What to do'), 'Send the kit');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(step(1).label, 'Send the kit');
      expect(step(1).loyaltySetup, isTrue);
    });

    testWidgets('Other: neutral words', (tester) async {
      await open(tester);

      expect(
        find.text(
          'When you tick this step, it counts as one loyalty order for the month.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('LRP'), findsNothing);
    });
  });
```

The second `open` in one test re-pumps the harness. If `pumpFormHarness` can't be pumped twice in one test, split the test in two: one seeds `workflows.store` with the flag already on (rebuild the `Workflow` with `loyaltySetup: true` on step 1) and switches it off. Imports: `business_model.dart`, `account.dart`, `workflow.dart`.

- [ ] **Step 3: Run them**

Run: `flutter test test/features/workflows/presentation/step_sheet_test.dart`
Expected: the five new tests FAIL (no "Counts as a loyalty setup").

- [ ] **Step 4: Implement**

`step_sheet.dart`:

- `StepDraft` gains `bool loyaltySetup`.
- `showStepSheet`'s `Consumer` passes `model: ref.watch(accountProvider)?.businessModel ?? BusinessModel.other`, `addStep(..., loyaltySetup: draft.loyaltySetup)` and `updateStep(..., loyaltySetup: draft.loyaltySetup)`.
- `StepForm` gains `required this.model` (`final BusinessModel model;`).
- State: `late bool _loyalty = widget.step?.loyaltySetup ?? false;`, and `loyaltySetup: _loyalty` in `_save`'s draft.
- After the Note field:

```dart
            SwitchListTile(
              value: _loyalty,
              title: Text(l10n.stepLoyalty),
              subtitle: Text(l10n.stepLoyaltyHint(widget.model.name)),
              contentPadding: EdgeInsets.zero,
              onChanged: _saving
                  ? null
                  : (on) => setState(() => _loyalty = on),
            ),
```

The Figma draws the switch in a field-like outlined box with "On" as text. A plain `SwitchListTile`, like the editor's "Default for new prospects", keeps one switch style in the app.

`workflows_preview.dart`: `model: BusinessModel.other` on the `StepForm`.

- [ ] **Step 5: Run them**

Run: `flutter test test/features/workflows`
Expected: all pass, except the `workflow_step_light` golden, which is compared on Linux only and skipped on macOS. CI regenerates it (README → Golden tests).

- [ ] **Step 6: Docs**

`docs/design/screens.md` §8 **Step**: after "an optional Note," add "a "Counts as a loyalty setup" switch (an LRP for dōTERRA; ticking the step counts one for the month, kept even if the step is later renamed or removed),".

- [ ] **Step 7: Gate and commit**

Run: `dart format . && flutter analyze && flutter test`
Expected: no format changes left, "No issues found!", all pass.

```bash
git add lib/features/workflows lib/l10n/app_en.arb test/features/workflows docs/design/screens.md
git commit -m "feat(workflows): mark a step as a loyalty setup"
```

Push, then regenerate the step golden through CI before merge.
