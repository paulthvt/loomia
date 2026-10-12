# Repeating workflows — design

Issue: #296. No Figma section: the only new control is a switch in the
existing workflow editor, next to *Default for new …*, and a word in
existing rows.

## Intent

Some follow-ups never end: a weekly check-in with each person on the team,
asking a customer every month how their supplies are going. Today a
workflow runs once and stops at Done, so the user picks it again by hand
each time it ends, or forgets to.

A workflow can now **start over**: after its last step, the first step
comes back. One step on repeat is "every week"; several steps loop as a
cycle. A group call with the whole team is not a workflow: it is one event
with many people, see `2026-10-12-repeating-events-design.md`.

## Decisions

| Question | Decision |
| --- | --- |
| What repeats | The whole workflow, not a step. No "this step forever, nothing after it" rule, and multi-step cycles work. A step that should come back alone is a one-step workflow, and "Getting started then weekly" is Follow with when the first one is done. |
| Repeat N times | Not built. N rounds is N copies of a step; duplicating steps in the editor does it. Add a count if someone asks. |
| Where it is stored | `workflow.repeats boolean not null default false`. |
| The rule | `complete_step`, on the last step of a repeating workflow, moves to the first step's position instead of past the end. `current_step_id` and `due_on` stay as they are: the first step is due its `days` after the last tick. |
| Step 1's days | "After the start" on the first round, "after the last step" on later ones. One number, no second field. |
| Calendar anchoring | None. Days count from the tick, as everywhere: ticking a weekly step on Wednesday brings it back next Wednesday. A fixed weekday is an event. |
| A loop of zero days | Refused by the editor: Repeat needs the steps to add up to at least 1 day, or a one-step loop would be due again the moment it is ticked. Not checked in Postgres (a check across rows); the editor is the only writer. |
| Done | A repeating workflow is never Done. "How did it end?" and the Done cards never show for it. Leaving it is Change workflow or Pause, which exist. |
| Switching Repeat on | People already Done stay Done (`at_position` is past the end); Follow with… restarts them. Nobody comes back "3 months late". |
| Switching Repeat off | People mid-round finish this round, then are Done. |
| Seeded workflows | Unchanged. "Refill check-in" is a natural loop, but seeded workflows are the user's own data; the switch is one tap. |
| Today, push | Nothing to change: they read `due_on`. |
| Loyalty forecast | `loyalty_forecast` walks forward to the end of the round only. A loyalty step reached by wrapping within the month is not counted. `ponytail:` comment there. |

## 1. Data

`supabase migration new repeating_workflows`.

```sql
alter table public.workflow
  add column repeats boolean not null default false;
```

The table-level `update` grant already covers the column.

`complete_step` is replaced (`create or replace`, copy of the latest one in
`20261010130800_loyalty_on_person.sql`), only the next position changes:

```sql
select coalesce(
         min(s.position),
         case when w.repeats
           then (select min(f.position) from public.workflow_step f
                 where f.workflow_id = w.id)
           else 1e9
         end)
  into next_position
  from public.workflow w
  left join public.workflow_step s
    on s.workflow_id = w.id and s.position > step.position
  where w.id = step.workflow_id
  group by w.id, w.repeats;
```

The history entry, the loyalty start and the refusal of a stale tick are
unchanged. A loyalty step ticked again on a later round starts nothing: the
person already has `loyalty_since`.

### Client

- `Workflow` gains `repeats` (`bool`, default false); `WorkflowRepository`
  maps it both ways and writes it on save.
- `test/features/workflows/server_rule.dart`: `positionAfter` wraps to the
  first step's position when `workflow.repeats`. It is the only Dart copy of
  the rule.

## 2. Domain

`lib/features/workflows/domain/workflow.dart`:

- `bool canRepeat(List<WorkflowStep> steps)`: at least one step, and the
  days add up to at least 1.

`progressOf` is unchanged: a repeating workflow never has a null
`currentStepId` unless it was Done before Repeat was switched on.

## 3. Screens

### Workflow editor

Under the steps, before *Default for new …*: a `SwitchListTile`
"Start over after the last step". Subtitle when on, "Step 1 comes back
{days} days after the last step". Disabled while `canRepeat` is false, with
the subtitle "Needs at least 1 day across the steps". Saved like the
default switch.

While the workflow repeats, the step sheet refuses a change that makes
`canRepeat` false (days set to 0 on the only non-zero step, deleting the
last step with days) with its `FormError` "A repeating workflow needs at
least 1 day across its steps". Same for Delete on a step row.

Step 1's line in the list: "When you start" becomes "When you start, then
right after the last step" for 0 days, and "{days} days after the start or
the last step" otherwise, only while the workflow repeats.

### Rows that name a workflow

"· Repeats" after the step count, where the step count shows today:
the Workflow settings rows ("Weekly check-in · 1 step · Repeats") and the
Follow with radio rows. The NEXT STEP card's trailing text stays
"Weekly check-in · 1 of 1".

### Copy

New `app_en.arb` keys, each with a description: `workflowRepeats`,
`workflowRepeatsOn`, `workflowRepeatsNeedsDays`, `workflowRepeatsBadge`,
`workflowStepRepeatFirst`, `workflowStepRepeatFirstSameDay`,
`workflowRepeatsStepError`.

## 4. Delivery

One PR for #296: the migration, the pgTAP cases, the model and repository,
the fake, the editor switch and guards, the rows.

## 5. Testing

- SQL (`workflow_test.sql`): ticking the last step of a repeating workflow
  moves back to the first step, due its days after the tick, and writes the
  step entry; a non-repeating one still ends; switching Repeat off mid-round
  ends after the last step; a Done person stays Done when Repeat is switched
  on; a loyalty step ticked on a second round keeps `loyalty_since`.
- Unit: `canRepeat` (no steps, all zero, one non-zero); the fake's
  `positionAfter` wrap.
- Widget: the editor switch on, off and disabled; the step sheet refusing
  the last day on a repeating workflow; the NEXT STEP card ticking the last
  step comes back to step 1 instead of Done; "· Repeats" in Settings and
  Follow with.
- Goldens: the workflow editor preview with Repeat on, regenerated through
  CI.

## Out of scope

Repeat N times, a fixed weekday, a round counter, repeating a single step
inside a longer workflow, several workflows per person.
