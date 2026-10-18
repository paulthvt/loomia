# Draft, then close — design

Issue: #354, part of the Goals epic #136. Changes the close-and-plan
ritual of `2026-10-02-goals-design.md` and the month-end push of
`2026-10-13-month-end-push-design.md`. Figma: a new section "Draft, then
close — #354" on page "04 — Screens (Light)".

## Intent

Today the ritual opens on the last 3 days of a month and offers to close it
right away. That is not how people in direct sales work (as described by a
doTERRA user):

- The last days of a month are the busiest: last orders, adjustments. Nobody
  looks back then, and the month's numbers are still moving.
- Next month's goals are drafted **before** the month ends, partly their own
  numbers, partly targets handed down. Only a draft.
- The month is closed on the **1st** of the next one, when the numbers are
  final. The goals are reviewed and submitted then.

So the ritual splits in time: draft the plan in the last 3 days, close and
confirm from the 1st. No new step, no new screen: the same two steps, moved.

Closing on Sep 29 today freezes September's actuals (`close_month`) two days
early. This change fixes that too.

## Goals

- Last 3 days of a month: invite to plan next month. Planning only. Once
  drafted, the invitation shrinks to one line that reopens the draft, so it
  can change until the 1st (targets handed down may arrive on the 30th).
- From the 1st (local midnight) to the 5th: close the month just ended, then
  plan, step 2 prefilled with the draft. Saving step 2 is the approval.
- A month is never closed before it has ended.
- Two pushes per month-end instead of one: when drafting opens, and on the
  1st. Each one only if its half is still pending.

## Non-goals

- A draft state in the database. A plan is already editable until its month
  is closed (RLS on `closed_at`); a plan saved in the last 3 days *is* the
  draft. No `draft`/`approved_at` column.
- Sending goals to the company or upline. "Submit" in Loomia means saving
  one's own plan; the real submission happens outside the app.
- Changing what step 1 or step 2 contain, the suggestions, or the 5th as the
  end of the window.
- A new notification kind or a new settings switch.

## Anti-goals

- Anything that reads as pressure: no "you haven't drafted yet" second push,
  no countdown. Same tone as the current card.
- A closing offered while the month is still running.

## The rule

`ritualWindow` / `pendingRitual` (`lib/features/goals/domain/goal_rules.dart`)
and `pending_ritual` (SQL) change the same way:

| Day | Month to close | Month to plan | Asks |
| --- | --- | --- | --- |
| last 3 days of M | — (never `closes`) | M+1 | plan M+1; once it has a plan, still offered as "edit the draft" |
| 1st–5th of M+1 | M | M+1 | close M if planned and not closed; then plan M+1 |
| otherwise | — | — | nothing |

In the last 3 days the app's rule always returns something, with whether
M+1 is already drafted (shape of `PendingRitual` is the builder's call).
`pending_ritual` (SQL, push only) keeps asking only when M+1 has no plan: a
saved draft gets no push.

From the 1st, the card shows when M was planned and is open, **even if M+1
already has a plan** (the draft). Same as today's rule; it just no longer
fires before the 1st.

Accepted edge: M never planned, M+1 drafted. On the 1st nothing is pending:
nothing to close, the plan exists. The plan stays editable from Goals.

Accepted edge: she closes M on the 1st and leaves before step 2. The draft
stands as the plan; nothing asks again. Same as today.

## Screens

- **Today and Goals, last 3 days, M+1 unplanned:** `RitualCard` in its
  plan-only form ("Plan October" / "Pick a few numbers before the month
  starts."). Strings exist (`pushRitualPlanTitle`, `pushRitualPlanBody`).
  Start opens `ClosePage`, which shows `PlanForm` alone (no step number), as
  it does today when `closes` is false.
- **Today and Goals, last 3 days, M+1 drafted:** no card. One line in the
  `GoalLine` style (muted `bodyLarge`, chevron, whole row tappable), under
  the goal line: "October's plan is drafted. Change it before the 1st." It
  opens `ClosePage`, `PlanForm` alone, prefilled with the draft. Saving
  updates the draft; the line stays until the 1st.
- **Today and Goals, 1st–5th:** the card as today, "Close September, plan
  October". Two steps as today. Step 2 already prefills from the existing
  plan (`close_page.dart`, `PlanForm` gets `plan`).
- **Step 2 with a draft:** one line under the step title, "Started from your
  draft. Change anything, then save." (my call: the "Your last 3 months"
  hints stay per field, the line is enough to say the numbers are hers.)
  Without a draft, nothing changes.
- **Plan-step reminder copy** ("Remind me when October ends / One note at
  7:00 PM when it's time to close it") and the Settings switch subtitle
  ("When it's time to close the month and plan the next") stay true and stay
  as they are, unless the builder finds a sentence that now lies.

Figma, in the new section, from the existing frames:

- Today, Sept 29 (copy of 205:3087): the plan-only card.
- Today, Sept 29, drafted: the one-line form under the goal line. Goals
  mobile and desktop (229:3602) with the same line in place of the card.
- Today, Oct 1: the close card (current copy), with October's goal line
  from the draft.
- Step 2 with a draft (copy of 202:2930): the "Started from your draft" line.
- Push (copy of 334:8905): the two variants labelled by when they go out,
  "Sept 28, 7:00 PM" (plan) and "Oct 1, 7:00 PM" (close).
- Update the note of section 201:2587 ("open from the last 3 days of the
  month to the 5th") and of 334:8738 ("once per window").

## Push

Same switch (`ritual_enabled`), same kind (`month_ritual`), same time and
days, same copy and variants. What changes:

- **Twice per month-end at most:** once in the drafting half (plan variant)
  when M+1 has no plan, once in the closing half (close variant, or plan
  variant if only the plan is left). Today it is once per window because
  both halves claim the same `notification_sent` row (`local_date` = month to
  plan). Each half needs its own row. Which date keys the drafting half is
  the builder's call; it must be stable across the half's 3 days, distinct
  from the closing half's, and found again by `release_month_ritual`.
- Drafted already, or closed and planned: nothing for that half, as today.

## Released app

The Dart rule ships with the app; the SQL rule and sender change at merge.
Until a phone updates, its card still offers closing in the last 3 days, and
it may get the plan push on Sept 28 then see "Close September, plan October"
on Today. Harmless: same Start, same flow it has today.

The migration replaces `pending_ritual` (same parameters and return type,
`create or replace`) and whatever the claim key needs. If
`claim_month_rituals` or `release_month_ritual` change shape, only the Edge
Function calls them (`service_role`): `supabase db push` then `supabase
functions deploy send-daily-summary`, back to back. Safe for the released
app; the PR's Database section says so.

## Tests

- `goal_rules_test.dart`: last 3 days never `closes`, planned or not, and
  still pending once M+1 is drafted; 1st–5th
  as today; 1st with M planned and M+1 drafted still asks to close.
- `month_ritual_test.sql` mirrors those cases for `pending_ritual`;
  `claim_month_rituals`: one claim in the drafting half, one more on the 1st,
  none twice in the same half, release then claim per half.
- Widget: the drafted line on Today and Goals, tap opens the draft;
  `ClosePage` in the last 3 days shows the plan alone, prefilled when
  drafted; step 2 with a
  draft shows the line and the draft's values.
- Goldens: any preview whose copy changes, regenerated through CI.

## Left to the builder

- The claim key for the drafting half, and whether that changes the claim or
  release functions' signatures.
- How `PendingRitual` carries "drafted" (a field, or a third case).
- Where the "Started from your draft" line sits in `PlanForm`, and its key
  name (EN only, with a description).
- Whether any copy beyond that line needs to change.
