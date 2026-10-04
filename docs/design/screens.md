# Screens — v1

Five product screens plus the six auth screens, built in Figma from component
instances only. Light on page `04 — Screens (Light)`, the same frames in dark on
`05 — Screens (Dark)` (clones bound to the `Dark` mode of `Loomia/color`, so they
are not a second design to maintain).

| Frame | Size | Page |
| --- | --- | --- |
| Today — mobile | 390 × 844 | 04 / 05 |
| Contacts — mobile | 390 × 844 | 04 / 05 |
| Contact detail — mobile | 390 × 844 | 04 / 05 |
| Team — mobile | 390 × 844 | 04 / 05 |
| Goals — mobile | 390 × 844 | 04 / 05 |
| Today — desktop | 1440 × 900 | 04 / 05 |
| Contacts — desktop | 1440 × 900 | 04 / 05 |
| Welcome — mobile | 390 × 844 | 04 / 05 |
| Sign in — mobile | 390 × 844 | 04 / 05 |
| Create account — mobile | 390 × 844 | 04 / 05 |
| Forgot password — mobile | 390 × 844 | 04 / 05 |
| Check inbox — mobile | 390 × 844 | 04 / 05 |
| Choose a new password — mobile | 390 × 844 | 04 / 05 |
| Welcome — desktop | 1440 × 900 | 04 / 05 |
| Sign in — desktop | 1440 × 900 | 04 / 05 |

Content is the same fictional book of ~420 contacts across every screen, so the
screens read as one product and not as seven mockups.

---

## 1. Today — the home

**Every size** — one column, 624px at most. Desktop keeps the sidebar and
uses the large top bar; mobile keeps the account button and the bottom nav.

Top bar (`TUESDAY, SEPTEMBER 29` / "Good morning, Pauline") → TodayHero →
`PRIORITY` + the people whose workflow step is due today or late.

The greeting follows the device clock: morning until noon, afternoon until
6 pm, evening after. Without a first name it is "Good morning" alone.

The hero says *"Three people are worth a message today"* — a sentence, not a
number, so it cannot read as a quota. It counts everyone due, not only the
rows shown.

Each ActionItem is a person: their name, then the reason it exists —
"Send the samples · Samples, step 2 of 5". The accent chip appears only when
the step is late ("2 days late"). The round button ticks the step, exactly as
on the contact page; the row then leaves, or shows the next step if that one
is due too. Tapping the row opens the person.

Oldest first. Five rows on a phone or tablet, six on desktop, then
`And 2 more waiting`, which shows the rest in place. Pull to refresh on every
size.

Loading is a spinner; a failed load says "Couldn't load today." with Try
again; nobody due is "You are up to date".

Under the hero, one line for the month's own volume ("960 PV to go · 11 days
left", "On pace · 11 days left", or "You reached what you planned"), which
opens Goals; hidden without a plan or a volume target. From the last 3 days
of a month to the 5th of the next, the close-and-plan card follows it
([#144](https://github.com/paulthvt/loomia/issues/144)). Stats, "You talked
to" and the desktop right column are gone until activity summaries exist. Nothing on Today is sample
data.

## 2. Contacts

**Mobile**

App bar → SearchField → filter chips (`Everyone` active, `Customers`,
`To follow up`, `Team`) → `NEEDS A NUDGE` (3, with the count as the header action)
→ `EVERYONE ELSE` → BottomNav.

The list is grouped by *whether the person needs something*, not alphabetically —
a 420-person alphabetical list is a database, and this product is not a database
(principle #3). Each row shows the last real contact; no completion meters.

**Desktop**

Sidebar → 440px list column (title + `Add` button, search, filters, grouped rows,
selected row washed with `primary/muted`) → 752px detail pane showing the selected
contact: header with actions, `NEXT STEP`, `HISTORY`, and a right column with
`WHAT YOU KNOW` plus the person's chips.

Selecting a row never navigates. This is the one screen whose desktop layout is
structurally different from mobile, and the reason is that a pointer can hold a
selection while a thumb cannot.

## 3. Contact detail (mobile)

"Back to contacts" bar → Avatar 56 + name (`headline`) + "Customer since March ·
Lyon" + two chips → `Message` / `Call` / overflow → `NEXT STEP` (one ActionItem) →
`HISTORY` (3 ActivityItems, "All 24") → BottomNav.

The screen answers one question: *what do I say to this person?* The next step is
above the history because the history is memory, not homework. The app bar title
is a back affordance, not a repeat of the name — the name is already the largest
thing on the screen (principle #2).

**`NEXT STEP`** sits between `WHERE IT STANDS` and `WHAT YOU KNOW`, on mobile and
in the desktop pane. It follows the person's workflow, one step at a time:

| State | Header | Card |
| --- | --- | --- |
| On a step | `NEXT STEP` · "Samples · 3 of 5" | The step as title; "Due today" / "Due in 3 days" / "2 days late", then the step's note; a round tick |
| Done, prospect | `SAMPLES — DONE` | "How did it end with Sarah?" — `Became a customer`, `Not now` (pauses) |
| Done, customer or team | `NEW CUSTOMER — DONE` | "All 4 steps are done with Claire." — `Follow with…` |
| Paused | `NEXT STEP` | "Paused since July 12" — `Resume` |
| No workflow | `NEXT STEP` | "Nothing planned" — `Follow with…` |
| Loading / failed | `NEXT STEP` | A small spinner / "Couldn't load the workflows" — `Try again` |

A tick completes the step today and waits for the server; on failure a SnackBar,
and the card stays. There are no progress bars or streaks: the count "3 of 5"
is where you are, not a score.

**Tapping the card** (any state with a workflow) opens the whole workflow at
`/contacts/:id/workflow`, above the person on mobile, in the pane on desktop.
Eyebrow "Marie Dupont · Step 3 of 5" (or "· Finished"), the workflow name as
title, then one rail row per step: before the current one greyed, the current
one on the selected-row wash with its due label and note and the same tick (or
"Paused since…" and `Resume`), after it "3 days later". Greyed means *before*,
not *done*: the history keeps a step's label, not which step it was, so no
done dates and no projected dates. Editing stays in Settings → Workflows.
Figma: "Workflow timeline — mobile".

The ⋯ menu adds `Change workflow` (the current one's name trailing) and
`Pause — not now`, or `Resume` while paused. Change stage and Change workflow
share the FOLLOW WITH block: the stage's workflows, "Nothing for now", and the
first step's day.

## 4. Team

App bar → a summary card ("6 people on your team" + AvatarGroup + "Two of them
could use a message this week. **Nobody is being measured here** — this is just who
might need you.") → `WORTH A CHECK-IN` (2 ActionItems about people, with the
reason: "Joined 3 weeks ago and has not added a contact yet") → `EVERYONE` (roster
of ContactRows) → BottomNav.

This is the screen most at risk of becoming an MLM tool, so it is the most
constrained: no volumes, no ranks, no comparison, no "downline". A team member is
a person who might need help, and the screen is built out of the same ActionItem
and ContactRow as Contacts. The copy states the rule out loud.

**Built** ([#101](https://github.com/paulthvt/loomia/issues/101)): the summary
card and `EVERYONE` (#102), then `WORTH A CHECK-IN` (#103): new on the team
(under 30 days, nothing logged since joining) or quiet (nothing logged for two
weeks). Its circle opens Log something. The summary says how many first. A
row's second line is "Team · talked yesterday", or "Team · joined 3 weeks ago"
until something is logged since joining. Tapping a member opens their contact
page under Contacts. Every size is one 624px column, like Today.

Not built: "has not added a contact yet". It would read the member's own book,
which stays private (#67).

## 5. Goals

App bar (`11 DAYS LEFT IN SEPTEMBER` / "Goals") → GoalCard (1 840 of 2 800, "On
pace") → two StatTiles framed against the user's own intent ("of 40 you aimed
for") → `WHAT YOU SAID YOU WOULD DO` (3 TaskItems, two settled) → a pace card:
"At this pace you finish the month at about 2 650. Two more conversations a week
closes the gap. No pressure — the goal is yours to move."

Pace is stated, never judged. Nothing is red, nothing is compared to another
person, and the largest numeral on the screen is smaller than the screen title
(guardrail #4).

**Built** ([#142](https://github.com/paulthvt/loomia/issues/142)): the Goals
tab (Today · Contacts · Team · Goals, and in the sidebar), one 624px column on
every size. No plan this month: "What are you aiming for this month?" and
`Plan September`. With a plan: the own-volume card (bar, percent and days
left when there is a target; pace from day 4), four tiles, the declared row
when there is a level or team volume, the pace card, `Change the plan`, and
`PAST MONTHS`. Planning is `/goals/plan`, full screen, for the current month:
each field starts from the saved plan, else from the last 3 closed months,
and loyalty from the forecast. `Log my own order` opens Your own order (an amount, no
person), and tapping the volume card lists the month's orders, contacts' and
own, each deletable ([#165](https://github.com/paulthvt/loomia/issues/165)).
From the last 3 days of a month to the 5th of the next, a card at the top
opens `/goals/close` ([#143](https://github.com/paulthvt/loomia/issues/143)):
"How did September go?" (each counted objective against its plan, a check
when reached, a neutral bar under it; team volume and rank typed), `Next`
closes it, then "What are you aiming for in October?" starts from the last 3
closed months. A month never planned skips to the plan; a closed month's plan
no longer changes.

## 6. Auth — welcome, sign in, register, reset

Added 2026-09-23 for [#21](https://github.com/paulthvt/loomia/issues/21). Full
design in
[docs/superpowers/specs/2026-09-23-auth-login-design.md](../superpowers/specs/2026-09-23-auth-login-design.md).

Six mobile frames and two desktop frames, all on the same shape: no navigation,
a single column capped at 400, centred, flat on `surface/canvas`. No card — a
card around a form is chrome (principle #6). This is the only part of the product
whose layout does **not** restructure across size classes; a form has one column
at every width, so only the horizontal centring and the vertical rhythm change.

Auth takes `space/lg` (24) horizontal padding rather than the `space/md` (16)
other mobile screens use. Because the column is capped and centred, this only
binds on mobile, where the full-width buttons otherwise crowd the screen edges.

`Welcome` carries the promise (`Know what to do next.`) and the three identity
paths. The social buttons live here and nowhere else, so a user who signed up
with Google is never shown a competing email form beside their real path.
`Sign in — mobile` is drawn in its **error state** to specify the form-level
failure: the clean state is trivially readable, the error state is the one with
decisions in it.

Three components were added to the library for these frames: `FormError`
(form-level errors, as opposed to TextField's field-level `State=Error`) and
`Brand/Google` / `Brand/Apple`, both placeholder artwork in Figma. The app ships
the official flat `G` from developers.google.com/identity instead
(`assets/images/google_g.png`); the Apple path is not built yet (issue #22).

`Choose a new password` has no back button: it is reached by a deep link, so
there is no previous screen to return to.

## 7. Contacts, stages & workflows

Added 2026-09-28 for [#53](https://github.com/paulthvt/loomia/issues/53).
Section `Contacts, stages & workflows` on both pages. It supersedes the filter
chips of §2 and the detail layout of §3.

One person moves **prospect → customer → team**, one stage at a time, and their
history follows them. Each stage has workflows: ordered steps, each due N days
after the previous one is ticked. The next step of a person's workflow is what
Today suggests.

| Frame | Size |
| --- | --- |
| Contacts — mobile (stages) | 390 × 844 |
| Contact detail — customer | 390 × 1107 |
| Contact detail — prospect | 390 × 1239 |
| Contact detail — team member | 390 × 1371 |
| Contact detail — prospect, workflow done | 390 × 1275 |
| Change stage sheet — mobile | 390 × 844 |
| Add someone sheet — mobile | 390 × 844 |
| Contact actions sheet — mobile | 390 × 844 |
| Log something sheet — mobile | 390 × 844 |
| Settings / Workflows — mobile | 390 × 844 |
| Settings / Workflow editor — mobile | 390 × 844 |
| Edit step sheet — mobile | 390 × 844 |
| Contacts — desktop (stages) | 1440 × 900 |

Detail frames are drawn full length where the screen scrolls.

**Contacts.** Filters are the stages (`Everyone` / `Prospects` / `Customers` /
`Team`). The stage is a neutral chip on each row. Grouping by need stays.

**Contact detail.** The order is: header, `Message` / `Call` / ⋯, then
`WHERE IT STANDS` for prospects only (Interested / Thinking it over / Not now /
No reply), `NEXT STEP` with the workflow name and position ("Samples · 3 of 5"),
`WHAT YOU KNOW` (FactRows, with Edit) and `HISTORY` (with Add). A team member
also has `WHAT THEY ARE AIMING FOR` above `WHAT YOU KNOW`: their why, own goal,
time they have, what they would love to do, strengths and where they are stuck,
in their words. After their why come "Rank now", "Aiming for" ("Elite by
March 2027") and "Each month" ("Aims for 100 PV"); Other reads "Level now" and
a bare number ([#139](https://github.com/paulthvt/loomia/issues/139)). They
are what the member said, typed by the user: never on the Team tab, never
summed or compared. The edit sheet picks a rank from the company's list (free
text for Other), aims only above the rank now, a month for "By" once there is
a target, and a number.

**Edit details** (from ⋯) is grouped as the page is: Name, then
`WHAT THEY ARE AIMING FOR` (team only), then `WHAT YOU KNOW`. A section's own
Edit asks only for that section's fields, titled with its name and without a
header. Frames: `Edit details sheet — team member` (drawn full length) and
`Edit sheet — what they are aiming for`.

**When a prospect's workflow ends**, `NEXT STEP` becomes a "How did it end with
Sarah?" card on `secondary/container` with no border. Its two choices ("Became a
customer" / "Not now") are Text buttons, so they cannot be mistaken for the
Message / Call pair above. This is the only place Loomia prompts a stage change.
Customer → team is never prompted: moving someone to the team is always the
user's own idea, from ⋯.

**⋯ holds every other action**: Log something, Move to customers, Move to team,
Change workflow, Pause — not now, Edit details, Delete. Delete is the only red
item. `HISTORY → Add` opens the same Log something sheet (note / call / message /
order / meeting, date, text). Order adds an amount in the business model's unit
(PV for dōTERRA, none for Other); the note is then optional, and the history
reads "Order · 100 PV". Ticking a step writes its own history entry.

**Workflows have one version.** Everyone on a workflow follows its current
steps. Done steps are history, with the label copied at tick time. Changing a
step's days recalculates the due date from the last tick. Removing the current
step moves the person to the next one. A step inserted before the current one is
skipped. A rename applies at once.

**Settings → Workflows** lists workflows by stage, with a default per stage. The
editor is a list of WorkflowSteps, and each one opens the Edit step sheet (what
to do, days after the previous step, note).

**Desktop** reuses the §2 split: stage filters in the list column, and the
detail pane holds `NEXT STEP` + `HISTORY` on the left and `WHAT YOU KNOW` on the
right.

Two components were added for these frames: `WorkflowStep` (number, label,
timing) and `FactRow` (label over value, hugs its height). One token was added:
`overlay/scrim`, black in both modes, used at 40% behind every sheet. The scrim
was previously bound to `text/primary`, which turned light in dark mode.

## 8. Settings → Workflows

A row "Workflows" in its own group above Preferences. On desktop the list and
the editor open in the Settings pane (the editor replaces the list, and its
back arrow returns to it); elsewhere each is pushed.

**List** — top bar "Workflows" → intro ("What you usually do with someone,
step by step. Loomia puts the next step on Today when it comes due.") → one
group per stage that has workflows (PROSPECTS, CUSTOMERS, TEAM), the default
first, each row trailing "Default · 5 steps" or "4 steps" and a chevron → a
tonal `New workflow` button. New workflow is a dialog (a bottom sheet on a
phone): Name, STAGE chips with Prospect picked, Cancel / Create; Create opens
the editor on it.

**Editor** — the stage as eyebrow, the name as title → Name field, saved when
it loses focus → STEPS with `Add a step`: a numbered row per step, "When you
start" or "3 days after", a drag handle, Move up / Move down for screen
readers → "Default for new prospects" switch → a footer on how steps come due
→ a red "Delete workflow" row, which asks first and says how many people
follow it. Opened after it was deleted elsewhere: "This workflow isn't here
anymore" and `Back to workflows`.

**Step** — "Step 2" or "New step": What to do, Days after the previous step
("Days after starting" for step 1, 0 to 365) with a live "Comes due 3 days
after you tick step 1." hint, an optional Note, a "Counts as a loyalty setup"
switch on customer and team workflows (an LRP for dōTERRA: ticking the step counts one for the month, kept
even if the step is later renamed or removed), a full-width `Save`, and
`Remove this step` centred under it, without a confirmation: people on it move
on and their history stays. No Cancel: the sheet closes by dragging it down.

Nothing is optimistic. A control is disabled while its write is in flight; a
failure says "Couldn't save. Check your connection and try again." — inline
in a dialog, which keeps what was typed, and as a snack bar in the editor,
which shows the saved state again.

---

## 9. First run & import from the phone

Added 2026-09-30 for [#61](https://github.com/paulthvt/loomia/issues/61).
Frames `First run — mobile`, `First run — web` and `Import contacts — mobile`.
Frames First run step 1 (210:3226) and step 2 (212:3241).

**First run** has two steps, shown once after sign-up, in the auth shape (one
column capped at 400, no navigation). Step 1 (`Welcome`, [#137](https://github.com/paulthvt/loomia/issues/137)):
`Which company do you work with?`, two cards, dōTERRA and Other. The tap is the
answer — no preselection, no Next — saved as `business_model` in the Supabase
user metadata (absent for Other) and changeable in Settings → Account. Step 2:
`Who do you already work with?`, with a back button to step 1. On a phone:
Import from your contacts (primary), Add someone, Skip for now. On the web
there is no address book to read, so Add someone is the primary and the body
says the phone app can import. Every way out of step 2 — Skip included — marks
the account (`onboarded`), so it never comes back, on any device. The step is
local state under `/start`: the router guard does not change. Importing stays
in Contacts: an icon in the toolbar and a text button under the empty state,
both absent on the web.

**Import** is a full screen: the eyebrow counts what is ticked, a search, a
reassurance line (`Only the people you tick are saved in Loomia.`), then one row
per phone contact with a checkbox. Nobody starts ticked. Someone who looks
already in Loomia — the same number (last nine digits), or with no number the
same name — says `Already in Loomia` instead of their number, and can still be
ticked: never merged. The footer picks one stage for everyone and imports them
in a single write, all on that stage's default workflow.

Refused access shows Open settings and reloads on return to the app. Only a
name, the first number and the first email are read; nothing else leaves the
phone.

WhatsApp, Instagram and Messenger have no API that lists someone's contacts,
so the phone's address book is the only source.

---

## Dark mode

The dark frames are clones with `setExplicitVariableModeForCollection` pointing at
the `Dark` mode — every fill resolves through a variable, so there is no second
set of values to keep in sync. Three things are worth looking at specifically:

- The hero keeps `primary/base` unchanged, so the one filled block still carries
  the brand on a near-black canvas; its secondary labels are white at 78%, which
  is why they hold in both modes.
- Accent chips become deep bronze containers with light amber ink instead of pale
  cream — the same meaning, re-tuned.
- Cards do not gain shadows; they step from `surface/canvas` to `surface/default`
  and keep the hairline.

---

## What these screens deliberately do not have

No onboarding tour beyond the two first-run steps, no notification centre, no analytics view, no team performance
comparison, no gamification of any kind. Each would need either a product decision or a feature that does not exist yet
(CLAUDE.md: don't scaffold for later).

The screens are a design artefact. Implementation order, routing and state are not
decided here.
