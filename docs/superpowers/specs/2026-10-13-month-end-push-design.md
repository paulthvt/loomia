# Month-end push — design

Issue: #148, part of the Goals epic #136. Figma: [Month-end push — #148](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=334-8738), on
page "04 — Screens (Light)". Builds on
`2026-10-11-notifications-design.md` (settings, claims, the sender, push
strings) and `2026-10-02-goals-design.md` (the close-and-plan ritual). Closes
that spec's "Push reminder for the ritual: waits for FCM".

> Changed by `2026-10-18-draft-then-close-design.md` (#354): the last 3 days
> only plan next month (a draft), the month is closed from the 1st, and the
> push goes out once per half.

## Intent

Closing a month is the one thing Goals asks of the user each month, and it is
easy to let slip: the window is three days at the end of a month and five at the
start of the next. One push, when the window opens, saying what the Today card
says: "Close September, plan October · See how the month went, then pick what
you aim for in October. About two minutes." Never when there is nothing left
to close or plan, never twice a month, never unless asked.

## Decisions

| Question | Decision |
| --- | --- |
| Opt-in | Its own switch, **off** by default: design principle 4 is per kind of nudge, and turning on the daily summary was not a yes to this one. `notification_settings.ritual_enabled`. |
| Where it is offered | Settings → Notifications, a second switch "Month-end review". And on the plan step of the close-and-plan flow, the moment the user has just done it: "Remind me when October ends", on a phone with push. No new Today card: Today already has one card that asks once. |
| A row created from the plan step | Saved with the summary off, so Today's daily-summary card no longer asks. Accepted: the user has answered about notifications once, and Settings has the other switch. |
| When | At the user's summary time, on the first of their days that falls in the window. The time is "when I work on my business" (notifications spec); an 8-day window always holds every weekday. Same 3-hour catch-up window as the summary. |
| What it waits for | The Today card's rule (`pendingRitual`): the month to close was planned and isn't closed, or the month to plan has no plan. Nothing pending at that run: nothing sent. A month closed early in the window sends nothing. |
| How often | At most once per window. The claim's `local_date` is the month to plan (its 1st): both halves of a window (Sep 28–30, Oct 1–5) claim the same row. |
| Same rule twice | The window rule moves to Postgres for the sender (`pending_ritual`); Today and Goals keep the Dart `pendingRitual` over the plans they already load. Both pinned by the same cases (pgTAP mirrors `goal_rules_test.dart`). This bends the "one rule in Postgres" convention: the rule is calendar arithmetic over rows the client already holds, and an RPC would add a round trip to three screens for the same answer. Move the client to the RPC if the two ever disagree. |
| Copy | The card's title and body, exactly: the three `ritual*` keys become `pushRitualTitle`, `pushRitualBody`, `pushRitualPlanBody`, and `pushRitualPlanTitle` ("Plan {month}", French from `goalsPlanMonth`) is added. The card reads them, `tool/push_strings.dart` ships them to the phone. One source, so they cannot drift. French moves with the keys; `translation_sources.json` is left to the sync, which records them on its next run without retranslating. |
| Title | The push has a title and a body (`title_loc_key`, APNs `title-loc-key`), like the card. The daily summary stays body only. |
| Month names | Formatted by the sender in the device's language (`Intl.DateTimeFormat(locale, {month: 'long'})`), passed as loc args. A month name is data, not copy; Dart's `MMMM` and ICU's long month agree for EN and FR ("October", "octobre"), pinned by a Deno test. |
| Lock screen | Month names only, no figure, no name. `data: {type: "month_ritual"}`. |
| Tap | Opens Today, as every push does; the card is there with its Start button. No routing on `data.type` until a push needs a screen Today doesn't lead to. |
| Same moment as the summary | Two notifications at the summary time, at most once a month. Merging them would make one push say two things. |
| Older apps | A phone running a build without the new strings would show a raw key (iOS) or nothing (Android). `device_token.push_kinds` lists the kinds the installed app renders; `register_device` takes it, older apps leave the default `{daily_summary}`. The sender only sends a kind to devices that list it. |
| A language missing a push key | `tool/push_strings.dart` writes the English text under that language's key. Between a merge and the l10n sync, a build still has every key in every language. This also makes true the "fallback `_en`" the notifications spec promised. |
| Edge Function | Still `send-daily-summary` (renaming means a new deploy and new Vault secrets): one run sends summaries, then month-end reviews. The handler becomes per-kind. |

## 1. Data

Two migrations: `alter type … add value` cannot be used in the transaction
that adds it (precedent: `loyalty_kinds` / `loyalty_on_person`).

1. `notification_kind` gains `'month_ritual'`.
2. Then:
   - `notification_settings.ritual_enabled boolean not null default false`,
     `grant update (ritual_enabled)` to `authenticated`.
   - `device_token.push_kinds notification_kind[] not null default
     '{daily_summary}'`.
   - `register_device(p_token, p_platform, p_locale, p_kinds
     notification_kind[] default '{daily_summary}')` replaces the 3-argument
     one (dropped, recreated), writing `push_kinds` on insert and on conflict.
   - `pending_ritual(p_owner uuid, p_on date) returns table (to_close date,
     to_plan date, closes boolean)`: no row outside the window or when nothing
     is left. Window: `p_on` on or after the 3rd-to-last day of its month
     closes that month; day 1–5 closes the previous one. `closes` = a
     `month_plan` of `to_close` exists with `closed_at is null`; a row is
     returned when `closes` or no `month_plan` of `to_plan` exists.
   - `claim_month_rituals(p_now timestamptz default now()) returns table
     (owner_id uuid, to_close date, to_plan date, closes boolean)`: as
     `claim_daily_summaries`, with `ritual_enabled`, `pending_ritual(owner,
     local::date)` instead of the count, and `notification_sent (owner_id,
     'month_ritual', to_plan)`. Same 3 attempts.
   - `release_month_ritual(p_owner uuid, p_plan date)`.
   - The three functions: `service_role` only.

`run_daily_summary()` already deletes claims older than 30 days; a window's
claim (dated the 1st) outlives its window by 25 days and never meets the
next one.

## 2. Sender

`message.ts` gains `ritualMessage(token, locale, claim)`:

| | closes | plan only |
| --- | --- | --- |
| title | `push_ritual_title_<locale>` [to_close, to_plan] | `push_ritual_plan_title_<locale>` [to_plan] |
| body | `push_ritual_body_<locale>` [to_plan] | `push_ritual_plan_body_<locale>` [] |

`handler.ts` runs one kind at a time: a job gives `claim()`, `release(claim)`,
`message(claim, device)` and its kind; devices that don't list the kind are
skipped, and a claim with no device left is kept, as today. `index.ts` runs the
summary job, then the month-end job, and returns both results.

## 3. App

- `NotificationSettings` gains `ritual` (`ritual_enabled`) and `any`
  (either push on).
- **Settings → Notifications:** a second `SwitchListTile` in the first group,
  "Month-end review" / "When it's time to close the month and plan the next."
  Time and days apply to both: enabled while either switch is on. The
  permission warning shows while either is on. The Settings row shows the time
  while either is on, "Off" otherwise. `PushScope` asks the OS when either is on.
- **Plan step** (close flow and Plan alone), on a phone with push, above Save:
  a `SwitchListTile` "Remind me when {month} ends" / "One note at {time} when
  it's time to close it." Saves at once, apart from the plan. Turning it on
  asks the OS first; refused, nothing is saved and it stays off. No row yet:
  one is created with the device's zone and the summary off.
- `Push.register` sends `push_kinds: [daily_summary, month_ritual]`.
- `RitualCard` reads the `pushRitual*` keys.

## 4. Testing

- pgTAP `month_ritual_test.sql`: `pending_ritual` on the window edges (28th
  of a 30-day month, the 27th, Feb 26 2027, the 5th, the 6th), planned and
  open, closed with the next planned, closed with the next unplanned, no plan
  at all, another owner's plan ignored. `claim_month_rituals` with `p_now`
  pinned: switch off, day not selected, before and inside the time window,
  nothing pending, a second run and the next day of the same window claim
  nothing, release then claim, a fourth attempt refused, the summary's claim
  untouched. `register_device` with and without kinds. Column grants.
- Deno: `ritualMessage` for EN and FR, both cases, month names, no text in
  the payload; the handler skips a device without the kind.
- Dart: `NotificationSettings` row round-trip; `push_strings` English
  fallback and committed files; Settings form with the second switch and the
  Off row; the plan-step switch (shown with push, hidden without, refused
  permission saves nothing); `Push.register` kinds.
- Goldens: the changed Settings previews and one new plan-step preview,
  regenerated through CI.

## 5. Delivery

One PR, #148. After merge: `supabase db push`, then `supabase functions deploy
send-daily-summary`. The month-end push reaches a phone once it runs a release
built after the merge.
