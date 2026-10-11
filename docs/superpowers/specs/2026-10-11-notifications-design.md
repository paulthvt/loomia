# Notifications — design

Epic: #267 (sub-issues #268–#270). Figma: [Notifications — #267](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=311-6975), on page
"04 — Screens (Light)". Fulfils the push notes of
`2026-09-29-today-due-steps-design.md` ("a user timezone, FCM tokens and a
scheduled job that runs `due_on <= <user's local date>`") and
`2026-10-08-reminders-design.md` ("Push: later, from the same `due_on`").

## Intent

Loomia is opened when the user remembers to. One push a day, at the time and on
the days they set aside for their business, brings them back to Today: "3
people are worth a message today". It says what Today says, never more, never
when there is nothing to do, and never unless they asked for it.

## Decisions

| Question | Decision |
| --- | --- |
| Default | **Off.** Design principle 4: no push before the user opts into that nudge. 19:00 and Monday–Friday are prefilled, so turning it on is one tap. |
| Asking | A card on Today, once: "Want a nudge at 19:00 on weekdays?" Turn on (then the OS permission) or Not now. Either answer creates the settings row, and the card shows only while there is none. |
| Kinds | One: the daily summary. A separate reminder or step push would land the same day as the summary with the same item. `kind` is a column so the next kind needs no new table. |
| What it counts | People with a workflow step (`due_on`) or a reminder due today or late, in the user's local date: Today's headline count. Event checklist steps and "How did Workshop go?" later; their rule is Dart-only today and would move to SQL first. |
| Nothing due | Nothing sent. |
| Time per reminder | No. Everything due is a day, not an instant; a time per item means a picker on every reminder and a push per item. The summary time is "when I work on my business". Revisit if users ask. |
| Quiet hours | Not in this version. The only push goes at a time the user chose; quiet hours would only fight that choice, and a switch with no effect is not shown. They come with event pushes ("Workshop in 1 hour"), the first push whose time the user doesn't pick. |
| Weekdays | ISO 8601, `smallint` 1 = Monday … 7 = Sunday. Same as Dart `DateTime.weekday` and Postgres `isodow`: no mapping anywhere. Chips are ordered from `MaterialLocalizations.firstDayOfWeekIndex`. |
| Times shown | In the locale's format (`formatTimeOfDay`): "7:00 PM" in English, "19:00" in French, the card's copy included. Stored as `time`. |
| Weekday chips | The file's `Chip` component as a `FilterChip`, a check when selected. Seven wrap onto two lines on mobile, one line on desktop. English starts on Sunday (Flutter's `en`), so Mon–Fri sit mid-row. |
| No day selected | Not possible: the last selected chip can't be unselected. The database refuses an empty array too. |
| Time zone | The device's IANA name (`flutter_timezone`; Dart's `timeZoneName` gives "CET", not "Europe/Paris"). Written on launch when it differs from the stored one, so travel follows. Shown read-only. No picker: detection would overwrite it. Add one if detection is seen failing. |
| Several devices | The zone of the last device launched wins. The summary goes to every registered device. |
| Scheduling | No job queue, no per-user timer. pg_cron every 15 minutes calls one Edge Function, which asks Postgres who is due **now** and sends. Counting at send time means nothing stale is ever sent. |
| DST | Never convert a local time to a UTC instant. Each run compares the user's wall clock (`now() at time zone time_zone`) with `summary_time`. Nonexistent local time (spring forward): sent by the first run after it. Repeated local time (fall back): sent once, the claim is per local date. |
| Catch-up window | `[summary_time, summary_time + 3 h)`. A missed cron run still delivers; a summary never arrives in the middle of the night. |
| Duplicates | `notification_sent (owner_id, kind, local_date)` primary key, claimed before sending. Concurrent or repeated runs claim nothing twice. |
| Guarantee | At most one summary per user per local day. A crash between claim and send loses that day's summary; nothing is ever sent twice. Exception: a time zone change that moves the local date back (flying west) can give a second one. |
| Retries | A temporary FCM failure (429, 5xx, network) on every device releases the claim; the next run retries, at most 3 attempts per day. No backoff beyond the 15-minute cron. |
| Copy | In the app, not on the server. The push carries a localisation key and its arguments; the OS renders it from the app's strings (FCM `body_loc_key` / APNs `loc-key`). A data-only push formatted by Dart would be dropped on iOS when the app was swiped away, and is throttled when it isn't. |
| Strings source | ARB stays the only source. `tool/push_strings.dart` writes every `push*` key into `android/app/src/main/res/values/push_strings.xml` and `ios/Runner/Localizable.strings`, committed; the l10n sync runs it; a test fails when they are stale. A committed output, not a build step. |
| Push language | The app's language on that device (the user's choice, else the device's), stored with its token. Every language sits in the one base strings file, keys suffixed `_en`, `_fr`; the sender picks the suffix (fallback `_en`). So the push follows the in-app choice, which plain OS lookup would not, and no per-language Xcode setup. |
| Plurals | The sender picks `_one` (count = 1) or `_other`. Right for EN and FR (0 is never sent). A language with more plural forms needs real CLDR rules there. |
| Lock screen | Counts only, never a name. `data: {type: "daily_summary"}`; a tap opens `/today`. |
| Platforms | Android and iOS. Web push needs a service worker and VAPID key, and on iOS only reaches installed PWAs: later. The settings are editable on the web all the same. |
| Permission | The OS is authoritative. No token without permission. Denied: the switch stays on but Settings says notifications are off in the phone's settings. |
| Firebase | `firebase_core` + `firebase_messaging` only. No Firebase Auth, no Firestore. Config files stay uncommitted (AGENTS.md); CI's build job writes them from secrets. |
| Send auth | The Edge Function holds the FCM service account (Supabase secret) and gets an OAuth token for FCM HTTP v1. pg_cron calls it through pg_net with a shared secret from Vault, `verify_jwt = false` as for `delete-account`. |

## 1. Data

Conventions of `docs/architecture.md` → Backend: RLS, one owner policy per
command, `revoke all ... from anon, authenticated` then explicit grants, all
in the migration that creates the table.

### #268 — `device_token`

| Column | Type | Note |
| --- | --- | --- |
| `token` | text primary key | FCM registration token |
| `owner_id` | uuid not null | default `auth.uid()`, cascade |
| `platform` | `device_platform` enum | `'android'`, `'ios'` |
| `locale` | text not null | `'en'`, `'fr'`: the app's language on that device |
| `last_seen_at` | timestamptz not null default now() | |
| `created_at` | timestamptz | |

No grant to `authenticated`, a select-own policy for the schema test:
`register_device(p_token, p_platform, p_locale)` is the only way in. It is
`security definer`, checks `auth.uid()`, and upserts on `token`, moving it to
the caller. A phone signed into a second account would otherwise keep pushing
the first one's summary, and RLS would refuse the move. Called on every launch
(refreshes `last_seen_at` and `locale`) and on token refresh. Sign-out calls
`FirebaseMessaging.deleteToken()` on the device: the session is already gone,
so the row can't be deleted from there. FCM then answers UNREGISTERED and the
sender drops the row (§4).

### #269 — `notification_settings`

| Column | Type | Note |
| --- | --- | --- |
| `owner_id` | uuid primary key | default `auth.uid()`, cascade |
| `summary_enabled` | boolean not null default false | |
| `summary_time` | time not null default '19:00' | local wall clock |
| `summary_days` | smallint[] not null default '{1,2,3,4,5}' | ISO weekdays; `check (cardinality(summary_days) between 1 and 7 and summary_days <@ '{1,2,3,4,5,6,7}')` |
| `time_zone` | text not null | IANA; a trigger refuses a name missing from `pg_timezone_names` |
| `created_at`, `updated_at` | timestamptz | `set_updated_at` |

One row per user, no row = off. Grants: select, insert, update. No delete:
the account's cascade removes it.

### #269 — `notification_sent`

`owner_id`, `kind notification_kind` (`'daily_summary'`), `local_date date`,
`attempts smallint not null default 1`, `claimed_at timestamptz` (null =
released). Primary key `(owner_id, kind, local_date)`. RLS on, a select-own
policy for the schema test, no grant to `authenticated`: only the service role
touches it. Rows older than 30 days are deleted by the same cron.

## 2. Server rules (#269)

- `due_people_count(p_owner uuid, p_on date) returns int`: distinct people of
  `p_owner` with `due_on(person) <= p_on` or a `reminder` with
  `due_on <= p_on`. Same answer as `dueToday` in
  `lib/features/today/domain/due.dart`: a pause hides the step, not the
  reminders.
- `claim_daily_summaries() returns table (owner_id, local_date, count)`:
  executable by `service_role` only. For each enabled row with `local =
  now() at time zone time_zone`:
  `extract(isodow from local) = any(summary_days)`, `local::time >=
  summary_time`, `local::time < summary_time + interval '3 hours'` (a window
  past midnight is cut at midnight: the next day is another date),
  `due_people_count(owner_id, local::date) > 0`. Claims with
  `insert … on conflict do update set attempts = attempts + 1, claimed_at =
  now() where claimed_at is null and attempts < 3`, returning only the rows it
  claimed.
- `release_daily_summary(p_owner, p_date)`: `claimed_at = null`.
- `drop_device_tokens(p_tokens text[])`, service role: FCM said UNREGISTERED
  or the token is invalid.

## 3. Client (Dart)

`lib/features/notifications/`:

- `data/notifications_repository.dart`: settings read/upsert, time zone
  update (only when a row exists: the card still asks), `register_device`,
  token delete.
- `data/push.dart`: Firebase init on Android and iOS, permission, token and
  `onTokenRefresh`, tap (`onMessageOpenedApp`, `getInitialMessage`) → `/today`.
- `domain/weekdays.dart`: `weekdayOrder(int firstDayOfWeekIndex)` → ISO days
  in display order; `toggleDay(days, day)` refusing to empty the set.
- `presentation/notification_settings.dart`, the Today card.

### #270 — Settings → Notifications

`SettingsSection.notifications`, route `/settings/notifications`, a row in the
Preferences group showing the summary time when on, "Off" otherwise. Following `language_settings.dart`:

1. **Daily summary**: switch; "A short note with the people worth a message
   today."
2. **Time**: a row opening `pickTime`, formatted with `formatTimeOfDay`.
3. **Days**: seven `FilterChip`s, short weekday names from
   `DateFormat.E(locale)`.
4. **Time zone**: "Time zone: Europe/Paris" and "Times are your local time."
5. Permission denied: "Notifications are off for Loomia in your phone's
   settings." Web: "Notifications come to the Android and iOS app."

Each change saves at once (no Save button); a failed save shows `FormError`
and the previous value. Time and days are disabled while the switch is off.

### #270 — Today card

Below Priority, while no settings row exists and on Android or iOS: "Want a
nudge at 19:00 on weekdays?" · Turn on · Not now. Turn on: OS permission;
granted → register the token, upsert `summary_enabled = true` with the
detected zone. Denied or Not now → upsert with `summary_enabled = false`.

## 4. Sender (#269)

`supabase/functions/send-daily-summary/index.ts`:

1. Check the shared secret header; anything else is 401.
2. `claim_daily_summaries()` with the service role.
3. For each claim, the owner's `device_token`s; per token, FCM HTTP v1
   `messages:send` with `android.notification.body_loc_key` /
   `body_loc_args` and `apns.payload.aps.alert.loc-key` / `loc-args`:
   `push_summary_body_<one|other>_<locale>`, `[count]`; `data.type`.
4. UNREGISTERED / INVALID_ARGUMENT → `drop_device_tokens`. All tokens failed
   temporarily → `release_daily_summary`. No token at all: claim kept.
5. Logs ids and counts only.

Payload building and key choice are a pure module with a `deno test`; CI's
migrations job gains `deno test supabase/functions`.

A migration enables `pg_cron` and `pg_net` and schedules the job
(`*/15 * * * *`), reading the function URL and secret from Vault. Without them
(CI, a fresh local stack) the job logs and does nothing.

## 5. Delivery

| PR | Scope |
| --- | --- |
| #268 | Firebase on both platforms, `device_token`, `register_device`, refresh, sign-out, tap → `/today`, `tool/push_strings.dart` and its test. No UI, no permission prompt. |
| #269 | `notification_settings`, `notification_sent`, the rules of §2, the Edge Function, cron. Verified by pgTAP and a test push to a registered device. |
| #270 | Time zone sync, Settings → Notifications, the Today card, copy. The controls ship when they already work. |

## 6. Testing

- pgTAP (`notifications_test.sql`): RLS on the three tables, `register_device`
  moving a token between accounts. `due_people_count`: step, reminder,
  paused with a reminder, done, another owner's. `claim_daily_summaries`
  with `now()` pinned: unselected weekday; before, inside and after the
  window; disabled; nothing due; a second run claims nothing; release then
  claim; a fourth attempt refused; Europe/Paris on 2026-03-29 (02:30 summary,
  sent at the 03:00 run) and 2026-10-25 (02:30 twice, one claim); the same
  instant for Europe/Paris and America/New_York; a zone change applying to
  the next run while a claimed day stays claimed.
- Deno: key per locale and count, fallback to `_en`, no name in any payload.
- Dart unit: `weekdayOrder` (Monday and Sunday first), `toggleDay` keeping the
  last day; `tool/push_strings.dart` escaping (French apostrophe, `%`) and
  the committed files being current.
- Widget: the settings screen loaded, toggled, saved, a failed save, denied
  permission, web; the Today card shown with no row, gone after either answer.
- Goldens: one per new `@Preview`, regenerated through CI.

## 7. Manual setup (not in the repo)

1. A Firebase project with the Android and iOS apps; `google-services.json`
   and `GoogleService-Info.plist` locally and as CI secrets.
2. An APNs auth key uploaded to Firebase; Push Notifications and Background
   Modes → Remote notifications capabilities in Xcode.
3. `supabase secrets set FCM_SERVICE_ACCOUNT=… CRON_SECRET=…`, then
   `supabase functions deploy send-daily-summary`.
4. Vault secrets `send_daily_summary_url` and `cron_secret` on the hosted
   project, after `supabase db push`.
5. Check: register a device, set the summary time a few minutes ahead, wait
   for the next quarter hour.
