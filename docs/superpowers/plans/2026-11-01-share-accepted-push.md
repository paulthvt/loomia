# Invite-Accepted Push Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a member accepts an invite, the mentor who opted in gets a push "{contact} now shares their goals with you" that opens the contact page.

**Architecture:** A new `share_accepted` notification kind, `share_link.notified_at`, `notification_settings.sharing_enabled`, and a `claim_share_accepted`/`release_share_accepted` pair in the style of task alerts. A fourth job in the `send-daily-summary` Edge Function sends it via loc key; the app ships the strings, declares the kind in `push_kinds`, routes the tap, and offers the opt-in in Settings and in the invite sheet.

**Tech Stack:** Supabase Postgres + pgTAP, Deno Edge Function, Flutter + Riverpod.

**Spec:** `docs/superpowers/specs/2026-11-01-share-accepted-push-design.md`

## Global Constraints

- Branch `feature/423-share-accepted-push`, based on `feature/147-goal-sharing`; rebase onto `main` once #419 merges, before opening the PR. Conventional Commits with `(#423)`.
- Migrations additive only; the enum value goes in its own migration file before the one using it (pattern: `20261013132000_month_ritual_kind.sql`).
- Claim/release functions: `security invoker`, `set search_path = ''`, `revoke execute … from public, anon, authenticated`, `grant execute … to service_role` (pattern: `claim_task_alerts` in `20261026213314_task_time.sql`).
- New setting column: `notification_settings.sharing_enabled boolean not null default false`, `grant update (sharing_enabled) … to authenticated` (pattern: `task_enabled` in `20261028093219_task_alert_controls.sql`).
- Push copy key `pushShareAccepted` in `lib/l10n/app_en.arb` with `@description`, placeholder `name`; generated strings via `dart run tool/push_strings.dart`, committed. Never a push when sharing stops; no member account data in the push (use `person.name`).
- No new dependency. Theme tokens only; Material from `package:material_ui/material_ui.dart`; `package:loomia/...` imports.
- PR Database section: additive, safe for the released app; **`supabase functions deploy send-daily-summary` by hand after merge**.

## Review Focus

1. **Release day:** existing links (accepted before this ships) must never push — backfill `notified_at`. Pinned in Task 1 test 1.
2. **Opt-out mentor:** `sharing_enabled` false → link stays unclaimed (not stamped), so turning it on later does not push old news beyond 24 h. Pinned in Task 1 tests 2 and 4.
3. **Phone with old app** (no `share_accepted` in `push_kinds`) gets nothing — existing `handle()` filter. Pinned in Task 3 test.
4. **Contact deleted or off the team** between accept and claim → no push. Pinned in Task 1 test 5.
5. **Invite sheet on web / setting already on** → no switch shown. Pinned in Task 5 tests.

---

### Task 1: Database

**Files:**
- Create: `supabase/migrations/<ts1>_share_accepted_kind.sql` (`supabase migration new share_accepted_kind`)
- Create: `supabase/migrations/<ts2>_share_accepted_push.sql` (`supabase migration new share_accepted_push`)
- Create: `supabase/tests/share_accepted_push_test.sql`

**Interfaces — Produces:**
- `alter type public.notification_kind add value 'share_accepted';`
- `public.share_link.notified_at timestamptz` (nullable); migration runs `update public.share_link set notified_at = created_at;`
- `public.notification_settings.sharing_enabled boolean not null default false`
- `public.claim_share_accepted(p_now timestamptz default now()) returns table (owner_id uuid, link_id uuid, person_id uuid, name text, notified_at timestamptz)` — one statement: links with `notified_at is null` whose mentor has `sharing_enabled`: those with `created_at >= p_now - interval '24 hours'` and whose `person.stage = 'team'` are stamped `notified_at = p_now` and returned (`owner_id` = mentor, `name` = `person.name`); older ones are stamped and not returned.
- `public.release_share_accepted(p_link uuid, p_at timestamptz) returns void` — `notified_at = null where id = p_link and notified_at = p_at`.

- [ ] **Step 1: Failing pgTAP** (`share_accepted_push_test.sql`, users A mentor, B member, C member; links created as postgres): 
  1. A link already stamped by the backfill (`notified_at = created_at`) is never returned by `claim_share_accepted()`.
  2. A fresh link (`notified_at` null) with A's `sharing_enabled = false` → claim returns 0 rows and the link's `notified_at` stays null.
  3. Set `sharing_enabled = true` → claim returns 1 row with `owner_id = A`, `name = 'Julie'` (the person's name, not B's metadata `first_name`), `link_id`, `person_id`; a second claim returns 0 rows.
  4. A link with `created_at = now() - interval '25 hours'` → not returned, but `notified_at` is set afterwards.
  5. A link whose person is `stage = 'customer'` → not returned.
  6. `release_share_accepted(link, stamped_at)` clears it; claim returns it again; `release_share_accepted(link, other_time)` changes nothing.
  7. As `authenticated`, calling `claim_share_accepted()` raises permission denied.
- [ ] **Step 2:** `supabase db reset && supabase test db` — FAIL (function missing).
- [ ] **Step 3:** Write both migrations per Interfaces, with a header comment in the style of `20261026213314_task_time.sql`.
- [ ] **Step 4:** `supabase db reset && supabase test db` — all PASS; `bash tool/check_migrations.sh` exit 0.
- [ ] **Step 5:** Commit `feat(sharing): claim pushes for accepted invites (#423)`.

### Task 2: Push copy and the app's push kinds

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/features/notifications/data/device_repository.dart` (`pushKinds`)
- Generated: the files `tool/push_strings.dart` writes (e.g. `android/app/src/main/res/values*/push_strings.xml`, the iOS strings)
- Test: `test/tool/push_strings_test.dart` (existing staleness check), `test/features/notifications/data/` if a device repository test exists

**Interfaces — Produces:** ARB `pushShareAccepted`: `"{name} now shares their goals with you"`, `@pushShareAccepted.placeholders.name` (String), description saying it is the push to the person who sent an invite. Native key `push_share_accepted_<locale>` (check the tool's actual naming and use it in Task 3). `pushKinds` gains `'share_accepted'` with a `// #423` comment.

- [ ] **Step 1:** Add the ARB key, run `flutter test test/tool/push_strings_test.dart` — FAIL (stale).
- [ ] **Step 2:** `dart run tool/push_strings.dart`; add `'share_accepted'` to `pushKinds`.
- [ ] **Step 3:** `flutter test test/tool/push_strings_test.dart` plus device repository tests — PASS; `flutter analyze` "No issues found!".
- [ ] **Step 4:** Commit `feat(sharing): push strings for accepted invites (#423)`.

### Task 3: Edge Function job

**Files:**
- Modify: `supabase/functions/send-daily-summary/handler.ts`, `message.ts`, `index.ts`
- Test: `supabase/functions/send-daily-summary/handler_test.ts`

**Interfaces:**
- Consumes: `claim_share_accepted()` / `release_share_accepted(p_link, p_at)` (Task 1); native key from Task 2.
- Produces: `Kind` union gains `'share_accepted'`; `type ShareClaim = { owner_id: string; link_id: string; person_id: string; name: string; notified_at: string }` in `message.ts`; `shareAcceptedMessage(token: string, locale: string, claim: ShareClaim)` → loc key `push_share_accepted_${locale}`, args `[claim.name]`, `data: { type: 'share_accepted', person: claim.person_id }` (android `body_loc_key`/`body_loc_args`, apns `loc-key`/`loc-args`, as `summaryMessage`); `shareAcceptedJob(claim, release: (link: string, at: string) => Promise<void>): Job<ShareClaim>` with `kind: 'share_accepted'`; `index.ts` runs it as a fourth `run('share', …)` and includes `share` in the result and the 200 condition.

- [ ] **Step 1: Failing Deno tests:** `shareAcceptedMessage('t', 'fr', claim)` has `android.notification.body_loc_key === 'push_share_accepted_fr'`, args `['Julie']`, `data` `{ type: 'share_accepted', person: 'p1' }`; `handle(deps, shareAcceptedJob(...))` sends to a device with `push_kinds: ['share_accepted']` and not to one with `['daily_summary', 'task_alert']`; a failed send calls release with `(link_id, notified_at)`.
- [ ] **Step 2:** `deno test supabase/functions` — FAIL.
- [ ] **Step 3:** Implement per Interfaces.
- [ ] **Step 4:** `deno check supabase/functions/*/index.ts && deno test supabase/functions` — PASS.
- [ ] **Step 5:** Commit `feat(sharing): send the accepted-invite push (#423)`.

### Task 4: Setting and tap route

**Files:**
- Modify: `lib/features/notifications/domain/notification_settings.dart`, `lib/features/notifications/presentation/notification_settings_form.dart`, `lib/features/notifications/presentation/push_scope.dart` (tap switch ~L36), `lib/l10n/app_en.arb`
- Test: `test/features/notifications/domain/notification_settings_test.dart`, `test/features/notifications/presentation/notification_settings_section_test.dart`, push scope test if present (else add one next to it)

**Interfaces — Produces:** `NotificationSettings.sharing` (`bool`, default `false`), in `copyWith`, `fromRow` (`row['sharing_enabled'] as bool? ?? false`), `toRow` (`'sharing_enabled'`), and the repository's `select` column list; `pushes` becomes `any || tasks || sharing`. Settings form: a fourth `SwitchListTile` after Tasks — `notificationsSharing` "Sharing", `notificationsSharingBody` "When someone accepts your invite to share their goals." — using the existing `turn(...)`. Push tap: `{'type': 'share_accepted', 'person': final String id} => Routes.contactLocation(id)`.

- [ ] **Step 1: Failing tests:** `fromRow` without the key → `sharing == false`; `toRow()['sharing_enabled']`; `pushes` true with only sharing; the Settings section shows "Sharing" and toggling it saves `sharing: true`; a tap with data `{type: share_accepted, person: p1}` navigates to `Routes.contactLocation('p1')`.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement. **Step 4:** Run — PASS; `flutter analyze` "No issues found!".
- [ ] **Step 5:** Commit `feat(sharing): sharing push setting and tap (#423)`.

### Task 5: Opt-in in the invite sheet

**Files:**
- Modify: `lib/features/sharing/presentation/invite_sheet.dart`, `lib/l10n/app_en.arb`
- Test: `test/features/sharing/presentation/invite_sheet_test.dart`

**Interfaces — Consumes:** `notificationSettingsProvider(owner)` and its `save`, `pushProvider.ask()`, `pushAvailableProvider`, `deviceTimeZoneProvider`, `NotificationSettings.sharing` (Task 4).

Behaviour: under Copy link, a `SwitchListTile` "Tell me when {name} accepts" (`inviteNotifyMe`, placeholder `name`), shown only when `pushAvailableProvider` is true and the loaded settings' `sharing` is not true. Turning it on: `ask()`; granted → `save((settings ?? NotificationSettings(timeZone: zone)).copyWith(sharing: true))`, after which the row disappears; refused → switch stays off and shows `notificationsPermissionOff` beneath it. A save failure shows the existing failure copy.

- [ ] **Step 1: Failing widget tests:** push available + settings off → switch shown; push unavailable → not shown; settings `sharing: true` → not shown; turning it on with `ask` granted saves `sharing: true` (fake notifications repository) and hides the row; with `ask` refused nothing is saved and `notificationsPermissionOff` text shows.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement. **Step 4:** Run — PASS; `flutter analyze` "No issues found!".
- [ ] **Step 5:** Commit `feat(sharing): offer the accepted-invite push when inviting (#423)`.

### Task 6: Finish

- [ ] **Step 1:** After #419 is merged: `git fetch && git rebase origin/main`, resolve, re-run everything.
- [ ] **Step 2:** `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`, `supabase db reset && supabase test db`, `deno test supabase/functions`, `bash tool/check_migrations.sh`.
- [ ] **Step 3:** `graphify update .`
- [ ] **Step 4:** Push, open the PR (template; Ticket `Closes #423`; Database: additive, safe for the released app; **after merge run `supabase functions deploy send-daily-summary`**). Regenerate goldens through CI if a preview changed.
