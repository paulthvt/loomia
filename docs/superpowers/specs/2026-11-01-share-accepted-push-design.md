# Tell me when an invite is accepted — design

Issue: [#423](https://github.com/paulthvt/loomia/issues/423), part of
[#420](https://github.com/paulthvt/loomia/issues/420). Builds on goal sharing
(`2026-10-31-goal-sharing-design.md`, #147) and the pushes from
`send-daily-summary`: the daily summary (#269), the month-end push (#148) and
task times (#377), plus their controls (#389).

## Intent

A mentor sends an invite and then waits. Today the only way to find out the
member accepted is to reopen the contact page. A push closes that loop at the
moment it matters, and it gives the mentor a reason to go and look at the
goals that just arrived.

## Goals

- When an invite is accepted, the person who sent it gets a push:
  "{contact} now shares their goals with you". Tapping it opens that contact's
  page.
- It's opt-in, offered at the moment it makes sense: right after the mentor
  sends an invite.
- One setting covers sharing pushes, in Settings → Notifications.

## Non-goals

- A push to the member.
- A push for anything other than an accepted invite: no reminder that an
  invite is still open, no notice when an invite expires.
- Email.
- An in-app inbox or badge.

## Anti-goals

- **Never a push when sharing stops**, when an item is turned off, or when a
  link is removed (#147 anti-goal: the mentor isn't told).
- **No push before the user opts in** (design principle 4, as with the daily
  summary nudge).
- **No member account data on a locked phone.** The push names the contact
  the way the mentor wrote it on their card (`person.name`, the mentor's own
  data, like a task title). It never uses the member's account name.
- **No burst of old news at release.** Links accepted before this ships never
  trigger a push.
- **No blank push.** A phone whose installed app doesn't know the new push
  text gets nothing.

## How it works

### Opting in

- **Settings → Notifications** gets a **Sharing** switch, off by default,
  stored as `notification_settings.sharing_enabled`. It sits with the
  existing switches and follows their behaviour: it needs push permission,
  shows the OS-refused warning, and creates the settings row with the
  device's time zone when none exists.
- **The invite sheet** (`invite_sheet.dart`) shows a switch under Copy link:
  "Tell me when {name} accepts". It is bound to the same setting, and is shown
  only where push works (Android and iOS; not on web) and while the setting
  is off. Once on, the line disappears from the sheet; the setting stays in
  Settings.
  - **Turning it on** asks the OS for permission if that hasn't been granted,
    through the existing `Push.ask` flow, and saves the setting only when
    permission is granted.
  - **If the OS refuses**, the switch stays off and a short line explains
    where to change it, reusing the existing refused copy if it fits.
- **My call:** one setting for every sharing push, rather than one per
  invite. It's simpler, and later sharing pushes (#420: "Julie shared a
  workflow") reuse it.

### Sending

- `share_link` gets `notified_at timestamptz`, nullable. The migration sets
  it to `created_at` on every existing row, so links accepted before this
  ships are never pushed.
- `claim_share_accepted(p_now timestamptz default now())` is service-role
  only, in the style of `claim_task_alerts`. It sets `notified_at = p_now` on
  links where:
  - `notified_at is null`,
  - the mentor's `sharing_enabled` is true,
  - the link was created within the last 24 hours (an older one is stale
    news, and gets `notified_at` stamped without a push),
  - and the mentor's contact for the member is still on the team.

  It returns `owner_id` (the mentor), `link_id`, `person_id`, `person.name`
  and the `notified_at` it stamped.
- `release_share_accepted(p_link uuid, p_at timestamptz)` hands a claim back
  after a failed send. It clears `notified_at` only when it still equals
  `p_at`, like `release_task_alert(p_task, p_for)`.
- A fourth job, `shareAcceptedJob`, is added to `send-daily-summary` next to
  the summary, task and ritual jobs. The cron already calls the function
  every minute, so the push arrives within about a minute of the accept.
- **The message** is a loc key with the contact name as its argument,
  `push_share_accepted_<locale>`, built from an ARB key `pushShareAccepted`
  by `tool/push_strings.dart`. Its data is
  `{ type: 'share_accepted', person: <person_id> }`.
- **A tap** goes through the existing push-tap handling (`push.dart` →
  `push_scope.dart`) to `Routes.contactLocation(personId)`.

### Old apps

The push uses a loc key that only the new app ships. The mechanism already
exists: `device_token.push_kinds` (#148). Each phone saves the push kinds its
app can show, and the sender skips phones without the kind, as it does for
`month_ritual` and `task`. So:

- Add a value `share_accepted` to `public.notification_kind`. Do this in its
  own migration file before the one that uses it, as
  `20261013132000_month_ritual_kind.sql` does, because a new enum value can't
  be used in the same transaction.
- The new app adds `share_accepted` to the push kinds it saves
  (`device_repository.dart`).
- The job's kind is `share_accepted`, so the existing device filter applies.

## Data and safety

- **Additive migration.** New columns, a new setting with a default, new
  functions. The backfill only fills the new column. It is safe for the
  released app.
- **Access.** The claim and release functions are `service_role` only:
  revoke from `public`, `anon` and `authenticated`, as for the other claim
  functions. They read only the mentor's own contact name.
- **Edge Function.** `send-daily-summary` changes, so it needs
  `supabase functions deploy send-daily-summary` by hand after merge. The
  Release workflow only pushes the database. The migration is safe to apply
  before the function: until the function is deployed, nothing claims links.
- **Tests.** pgTAP for the claim:
  - the opt-in is respected,
  - backfilled links are never claimed,
  - links older than 24 hours are skipped and stamped,
  - a contact no longer on the team gets nothing,
  - a link is claimed once,
  - release works.

  Deno `handler_test.ts` for the job and the message. Widget tests for the
  invite sheet switch (shown, hidden on web, hidden once on) and the
  Settings switch.

## Constraints

- The push copy goes in `app_en.arb` (`pushShareAccepted`, with a
  description), informal register, and names only. Run
  `dart run tool/push_strings.dart` and commit the generated files.
- No new dependency.
- New UI is only a switch row in an existing sheet and an existing settings
  pattern. It reuses the existing components, so no mockup is needed.

## Left to the builder

- Exact copy for the invite sheet line and the refused case.
- Whether the job also needs a release path for a contact that was deleted
  between the claim and the send. The claim already returns nothing for one.
- Sequencing: this branch starts from `feature/147-goal-sharing`. Rebase it
  onto `main` once #419 is merged.
