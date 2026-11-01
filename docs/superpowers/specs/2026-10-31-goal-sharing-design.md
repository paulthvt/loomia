# Goal sharing between Loomia users — design

Issue: [#147](https://github.com/paulthvt/loomia/issues/147), part of the epic [#67](https://github.com/paulthvt/loomia/issues/67). First step of connecting Loomia users to each other.
Builds on goals (`20261004100527_goals.sql`, the month plan and
`month_progress`), a team member's rank and volume
(`20261004071958_member_aims.sql`) and profile
(`20260929213946_team_profile.sql`).

## Intent

Someone mentoring a team today asks each team member, one by one, what
they are aiming for this month, then types it on that member's contact
page. They use those goals twice: to set their own month (their targets
depend on their team's), and to follow each member and give advice during
the month.

When the team member also uses Loomia, that asking and retyping is wasted
time. This feature lets the team member share their goals with the person
mentoring them, so the mentor sees them on the contact page without asking.

This is the first thing that links two Loomia accounts. Later steps will
share more (events, workflows a leader hands to their team, a view of the
connected team). The link is built so those can be added as new things to
share, not as a redesign.

Words: in this document the **mentor** is the person who invites (their
sponsor), the **member** is the person who shares. Neither word, nor
"upline", "frontline" or "downline", appears in the app: the copy uses
names ("Share your goals with Marie?"). The product must not read as an MLM
tool (AGENTS.md).

## Goals

- A mentor invites a team member from that member's contact page.
- The member accepts the invite, during onboarding or later, and their
  month plan shows on the mentor's contact page for them, in place of what
  the mentor typed by hand.
- The member decides, item by item, what else is shared, and can stop
  sharing at any time.
- The same flow for every company (doTERRA and Other), on Android, iOS and
  web.

## Non-goals (this version)

- A view of the connected team as a tree.
- Sharing workflows, events, or anything other than the items below.
- More than one mentor per member. doTERRA has an enroller and a sponsor;
  the sponsor is enough for now.
- Linking by company identifier (doTERRA ID) or by Loomia username.
- Detecting that a contact's email belongs to a Loomia account.
- The member starting the link. If they want to share first, they ask
  their mentor for an invite.
- Notifications about sharing (push or email).

## Relation to #67

#67 principle 2 says a lead sees "no counts" of a member's book. The
**Progress** item below does show counts from the member's book. It is the
user's decision (2026-10-31) to allow it as an opt-in the member turns on,
off by default, which keeps #67's "sent on purpose by its owner" rule.
#67 principle 4 (shared things in their own tables, no existing policy
changes meaning) holds: crossing goes through functions, not widened
policies.

## Anti-goals

Any of these makes the feature a failure even if it works:

- **Someone receives goals they should not.** No path lets a user claim to
  be someone's mentor, or read goals through an identifier they typed.
- **Revealing who uses Loomia.** Nothing tells a user whether an email,
  name or contact has an account.
- **Surveillance.** Progress during the month is never shared unless the
  member turned it on. The mentor is not told when a member stops sharing
  or turns an item off: the data just stops showing and their own notes
  come back.
- **Hidden sharing.** The member can always see exactly what their mentor
  sees.
- **Ranking language.** No leaderboards, no comparison between members, no
  "recruit", "upline" or "downline" in copy.

## Why invites, not identifiers

The first idea was that each user types their upline's identifier (doTERRA
ID, or a generated username for other companies) and their own. That was
rejected:

- Identifiers are unverified. Anyone can sign up with someone else's
  doTERRA ID and receive their team's goals.
- A typo sends goals to a stranger.
- It needs two schemes (doTERRA IDs, generated usernames) for one feature.

An invite from the mentor solves all three. It starts from a contact the
mentor already has, so the link lands on the right contact. The direction
is part of the invite, so nobody declares who is whose mentor. And the
member's acceptance is the consent.

## How it works

### Inviting

On a team member's contact page (stage `team`), the mentor taps **Invite
to share goals**. Loomia creates an invite for that contact and shows:

- a short code, and
- a link `https://app.getloomia.app/invite/<code>`, with the platform share
  sheet to send it however they already talk to that person.

The mentor's choices:

- The code is 8 characters from an alphabet without look-alikes (no 0/O,
  1/I/L), shown grouped (`ABCD-EFGH`), typed case-insensitively.
- An invite works once and expires after 14 days.
- One open invite per contact: inviting again replaces the previous code.
- The mentor can cancel an open invite from the contact page.
- While an invite is open the contact page says so ("Invite sent"), with
  the code to share again.

**Why a code inside a link:** the app has no universal links or app links,
only the `io.supabase.loomia://login-callback/` scheme. Universal links on
iOS need associated domains, which need the Apple Developer membership the
project does not have yet. The link works on web (and, if the builder adds
an Android App Link, on Android). On iOS, the member types or pastes the
code. Opening the app from the link on iOS is a later improvement, not
something this version depends on.

### Accepting

The member enters the code in either place:

- **Onboarding:** an optional step after the company step, "Got an invite
  code?", with Skip. Onboarding's existing step mechanism
  (`FirstRunPage`, local `_Step` state) gets one more step.
- **Settings → Sharing**, any time later.
- **The web link**, which opens the web app with the code filled in
  (signing in or up first if needed, then back to the code).

Before accepting, the member sees who they will share with (the mentor's
first name only — my call: the photo lives in the private `avatars`
bucket, readable by its owner only, and showing it would widen storage
access or need an Edge Function; a later version can add it) and
what will be shared, with the optional items' switches, off. Accept
creates the link.

Refused cases, each with a plain message that reveals nothing about other
users: unknown, expired, used or cancelled code; their own invite; they
already share with someone (they must stop that first: one mentor per
member).

### What is shared

Each link carries a set of shared items. In this version:

| Item | Default | What the mentor sees |
| --- | --- | --- |
| Volume and level | always on with the link | from the member's current-month `month_plan`: own volume target, team volume target, target level; and their current level |
| Activity targets | on | the same month's prospects, customers, team members and loyalty targets |
| Progress | off | how the current month is going: the member's `month_progress`, for the items shared above |
| Why and own goal | off | the member's own "why" and "own goal", from their About me |

- **Volume and level** is the reason for the link and cannot be turned off
  separately: to stop sharing it, the member stops sharing.
- **Activity targets** default on because the mentor plans their own
  month from them; the member can turn them off and share only volume
  and level. (Decided with the user.)
- **Current level** comes from the member's last closed month
  (`level_actual`).
- **About me:** today only the mentor writes "why" and "own goal", about
  the member, on the contact. The member has no place to write their own.
  This version adds an **About me** section in the member's settings with
  those two fields. It is theirs whether or not they share it.

Later items (events, workflows, …) are new values in the same set, each a
switch on the member's Sharing page.

### What the mentor's contact page shows

On the contact linked to the member:

- Shared items replace the mentor's hand-typed values: target level
  replaces target level; own volume and team volume replace the single
  monthly volume target; the current level replaces current level; About
  me replaces why and own goal. Activity targets have no hand-typed
  counterpart and are added. "Target level by" has no counterpart in the
  month plan and stays the mentor's own note. The section shows that it
  comes from the member ("Shared by Marie").
- **Shared but empty** (my call): when a shared item has no value (no
  plan for the month yet, no closed month, blank About me), the shared
  section says so ("Marie hasn't set this yet"); it does not fall back to
  the mentor's notes, which would blur what came from the member. The
  read function therefore tells "shared, empty" apart from "not shared".
- **Stage** (my call): the shared section shows only while the contact is
  on the team, like the profile fields. Moving the contact out of the team
  keeps the link; moving them back shows it again.
- Items not shared keep showing the mentor's own notes, editable as today.
- Hand-typed values are never deleted or overwritten. If sharing stops or
  an item is turned off, they show again.
- Progress, when shared, shows next to the targets the way the Goals page
  shows the user's own (`GoalLine`).
- The rest of the contact page (workflow, history, other profile fields) is
  unchanged.

The team list, Today and the mentor's own Goals page are unchanged in this
version.

### The member's Sharing page

In settings: who they share with, a switch per optional item, and **Stop
sharing**. Stopping removes the link at once. With no link, the page shows
the code field.

### The mentor's side of a link

On the linked contact, the mentor can also **Stop sharing**, which removes
the link. Deleting the contact removes the link.

## Data and access

The mentor/member relation is the first data that crosses accounts. Every
table today is owner-only under RLS. This design keeps that rule for
tables and crosses accounts only through functions that check the link.

- **Invite:** owned by the mentor, tied to their contact (`person`). The
  member never reads the table: accepting goes through a function that
  takes the code.
- **Link:** one row per member (unique on the member), naming the mentor,
  the mentor's contact and the shared items. The member and the mentor
  can each read and delete their own links. Changing shared items is the
  member's only.
- **Reading shared data:** a `security definer` function, called by the
  mentor with their contact id, returns only the items the link shares.
  No policy on `month_plan` or the member's other tables is widened.
- **About me:** stored for the member, owner-only like every table.
- **Mentor's first name** shown to the member when accepting and on the
  Sharing page comes from the same kind of function, never from reading
  another user's account.
- `month_progress` relies on RLS, not an owner filter; a definer wrapper
  must filter by the member's id explicitly.

Every new table follows docs/architecture.md → Backend: RLS on, owner
policies, `revoke all … from anon, authenticated` then explicit grants, in
the same migration; `schema_rls_test.sql` must pass. Cross-account
functions get pgTAP tests proving a stranger, an expired code and an
unshared item all return nothing.

The migration is additive only (new tables and functions), so it is safe
for the released app. No Edge Function is needed.

## Constraints

- Two runtime dependencies today; the share sheet and anything else must
  come from what is installed or the platform, or be justified in the
  pubspec comment (AGENTS.md).
- English copy in `app_en.arb` only, every key described, informal
  register (French *tu*).
- Layout follows `context.screenSize`; the Sharing page and the invite
  sheet follow existing settings and sheet patterns.
- New UI patterns (invite sheet, code entry, "Shared by" section) are
  mocked in Figma before coding (project convention).

## Left to the builder

- Table, column and function names; how the shared-items set is stored
  (enum array, rows per item).
- How a month is bounded when the mentor reads the member's progress: the
  member's time zone is not stored; using the mentor's device bounds is
  acceptable for this version.
- Whether the Android App Link for `/invite/<code>` lands in this version.
- Where the About me fields live (own table or alongside another per-user
  row).
- Whether the onboarding step comes before or after "who you already work
  with".
- Splitting the work into issues and pull requests.
