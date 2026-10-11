# Daily summary sender Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Every 15 minutes, each user whose summary time has come on a selected day, in their own time zone, with someone due, gets one push "3 people are worth a message today" on every registered phone. Never twice the same local day (#269).

**Architecture:** Postgres decides who is due (`claim_daily_summaries`) and claims them in `notification_sent`. pg_cron calls `run_daily_summary()`, which posts to the Edge Function `send-daily-summary` through pg_net. The function sends FCM HTTP v1 messages carrying loc keys, then drops dead tokens or releases the claim.

**Tech Stack:** Postgres 17 (pg_cron, pg_net, Vault), pgTAP, Supabase Edge Functions (Deno 2, `npm:@supabase/server@1.8.0`), FCM HTTP v1.

**Spec:** `docs/superpowers/specs/2026-10-11-notifications-design.md` §1, §2, §4. No UI.

## Global Constraints

- **Schema** only through `supabase migration new`; RLS, owner policies, `revoke all … from anon, authenticated`, explicit grants in the same migration.
- **Quality gate per task:** `supabase db reset`, `supabase db lint --fail-on error`, `supabase test db`; Deno tasks also `deno test supabase/functions` and `deno check`. `flutter analyze` / `flutter test` stay green (nothing in `lib/` changes).
- **Branch:** `feature/269-daily-summary-sender` off `main`. PR body `Closes #269`. The local `pubspec.lock` mirror drift stays stashed.
- **Logs:** ids and counts only, never a token or a name.

## Rulings made while planning

- **`claim_daily_summaries(p_now timestamptz default now())`.** Service role only, so the extra argument exposes nothing, and pgTAP can pin the instant (`now()` is frozen for a whole test transaction).
- **The function authenticates with a named secret key, `cron`** (`withSupabase({ auth: 'secret:cron' })`), not a custom shared secret: the package already validates it, and it rotates from the dashboard. The key lives in Vault as `send_daily_summary_key` next to `send_daily_summary_url`. Spec §7 updated.
- **The handler gets its clients, FCM sender and clock injected** (`handle(deps)`), so the Deno test drives the whole flow without network.
- **FCM auth by hand:** the service account's RS256 JWT signed with WebCrypto, exchanged at `oauth2.googleapis.com/token`, cached until 5 minutes before expiry. No Google library.
- **No locale fallback.** The stored locale comes from `Localizations.localeOf`, always one of the app's languages, and the installed app ships the strings for all of them.
- **Outcome per token:** 2xx → sent; `UNREGISTERED`, `SENDER_ID_MISMATCH`, or `INVALID_ARGUMENT` with a field violation on `message.token` → drop; 429, 5xx, a thrown error → retry; any other answer (a bad payload, credentials) → failed: our bug, logged, the day kept, since a retry won't fix it. A bare `INVALID_ARGUMENT` is not a dead token. The claim is released only when nothing was sent and at least one send would retry. A failure reading the devices releases every claim of the run.
- **The service role needs `due_on` and `current_step_id`**: their migration revoked execute from public. Granted here.
- **Window arithmetic is `local::time - summary_time < '3 hours'`**, not `summary_time + '3 hours'`, which wraps at midnight (22:00 + 3 h = 01:00).
- **`run_daily_summary()`** also deletes `notification_sent` rows older than 30 days. Without both Vault secrets it raises a log line and returns: CI and a fresh local stack have no function to call.

## Review Focus

1. Nobody gets two summaries for one local day, whatever the run count. Pinned by `daily_summary_test.sql` (double run, DST fall back, release limits).
2. The local wall clock decides, across zones and DST. Pinned by the Paris/New York and 2026-03-29 / 2026-10-25 cases.
3. A dead token is dropped, a temporary failure retried, and a push carries no name. Pinned by `send-daily-summary/handler_test.ts`.

---

### Task 1: Tables and rules

**Files:**
- Create: `supabase/migrations/<ts>_daily_summary.sql`, `supabase/tests/daily_summary_test.sql`

- [x] **Step 1: Failing test.** pgTAP, owners A (Europe/Paris) and B (America/New_York):
  - `notification_settings`: A reads and writes only their row; empty days, day 8, `Mars/Olympus` refused (`23514`); no delete grant. `notification_sent`: `authenticated` cannot select.
  - `due_people_count`: a reminder due today counts, one due tomorrow doesn't; a paused person with a reminder counts once; a step due today counts; the same person with a step and a reminder counts once; another owner's people don't.
  - `claim_daily_summaries` as `service_role`, A at 19:00 Mon–Fri: Monday 18:55 nothing; 19:00 claimed with its count; 19:15 nothing (claimed); Saturday 19:00 nothing; Monday 22:01 nothing (window); disabled nothing; nobody due nothing. The same instant claims A at 19:00 Paris and not B (13:00 New York). Release then claim again: `attempts = 2`; a fourth claim after three releases refused.
  - DST, A with 02:30 every day: 2026-03-29 00:45 UTC nothing (01:45 CET), 01:00 UTC claimed (03:00 CEST); 2026-10-25 00:30 UTC claimed, 01:30 UTC (02:30 CET again) nothing.
  - Time zone change: A moves to America/New_York; a run at 19:00 New York the same local date stays claimed (nothing), the next local day is claimed.
  - `authenticated` cannot execute `claim_daily_summaries`, `release_daily_summary`, `drop_device_tokens`, `run_daily_summary`.
  - `drop_device_tokens(array['t1'])` deletes that row only.
- [x] **Step 2: Migration.** Spec §1 tables (`notification_kind` enum, `time_zone` trigger on `pg_timezone_names`, `set_updated_at`), §2 functions as `language sql`/`plpgsql`, `security invoker`, `search_path = ''`, execute for `service_role` only. Grant `due_on`, `current_step_id` to `service_role`.
- [x] **Step 3:** Quality gate.

### Task 2: Cron

**Files:**
- Create: `supabase/migrations/<ts>_daily_summary_cron.sql`
- Modify: `supabase/tests/daily_summary_test.sql`

- [x] **Step 1: Failing test.** `cron.job` has `send-daily-summary` at `*/15 * * * *`; `run_daily_summary()` without Vault secrets returns and posts nothing (`net.http_request_queue` empty); a 31-day-old `notification_sent` row is gone after it, a 29-day-old one stays.
- [x] **Step 2: Migration.** `create extension if not exists pg_cron` and `pg_net`; `run_daily_summary()` (`security definer`, reads `vault.decrypted_secrets`, `net.http_post(url, headers => {apikey, content-type})`); `cron.schedule`.
- [x] **Step 3:** Quality gate.

### Task 3: The Edge Function

**Files:**
- Create: `supabase/functions/send-daily-summary/{index.ts,handler.ts,message.ts,fcm.ts,handler_test.ts}`
- Modify: `supabase/config.toml`, `.github/workflows/ci.yaml`

- [x] **Step 1: Failing tests** (`handler_test.ts`, fakes for the db and FCM):
  - `summaryMessage('t', 'fr', 1)` → `push_summary_body_one_fr`, args `['1']`, on both `android.notification` and `apns.payload.aps.alert`; `3` → `_other_`; `data.type = 'daily_summary'`; no `title`/`body` text.
  - `outcome`: 200 sent; UNREGISTERED, SENDER_ID_MISMATCH and a `message.token` violation drop; a bare INVALID_ARGUMENT and 401 failed; 429, 503 retry. `fcmSender` signs a verifiable RS256 JWT and caches the OAuth token.
  - `handle`: two claims, A with two tokens (one sent, one unregistered) → one drop call `['a2']`, no release; B with one token returning 503 → release B; a claim with no tokens → nothing.
- [x] **Step 2: Implement.** `message.ts` (pure), `fcm.ts` (token exchange, `send`), `handler.ts` (`handle({claim, tokensOf, drop, release, send})`), `index.ts` wiring `withSupabase({ auth: 'secret:cron' })` and `FCM_SERVICE_ACCOUNT`. `[functions.send-daily-summary] verify_jwt = false`.
- [x] **Step 3:** CI migrations job: `denoland/setup-deno` (pinned SHA), `deno check supabase/functions/*/index.ts`, `deno test supabase/functions`.
- [x] **Step 4:** Quality gate.

### Task 4: Docs

**Files:**
- Modify: `docs/architecture.md`, `README.md`, `docs/superpowers/specs/2026-10-11-notifications-design.md`

- [x] **Step 1:** architecture.md *Push*: the sender (cron → function → RPC, the guarantee). README *Push notifications*: secrets, Vault, deploy, how to test a summary now. Spec §4/§7: the `cron` secret key.
- [x] **Step 2:** Quality gate.
