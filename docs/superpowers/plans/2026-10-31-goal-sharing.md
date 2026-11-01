# Goal Sharing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A mentor invites a team member with a code; once the member accepts, the member's month (and, if they choose, progress and About me) shows on the mentor's contact page in place of the hand-typed aims.

**Architecture:** Two new owner-scoped tables (`share_invite`, `share_link`) plus `about_me`. Every cross-account read and the accept go through `security definer` functions that check the link; no existing policy is widened. Flutter side is a new `lib/features/sharing/{data,domain,presentation}` feature, consumed by the contact page, settings and onboarding.

**Tech Stack:** Supabase Postgres (RLS, plpgsql, pgTAP), Flutter, `flutter_riverpod`, `go_router`. No new dependency.

**Spec:** `docs/superpowers/specs/2026-10-31-goal-sharing-design.md`

## Global Constraints

- No new runtime dependency. "Copy link" uses `Clipboard` from `package:flutter/services.dart`; no share-sheet package.
- Migration is additive only: new enum, tables, functions; `month_progress` keeps its exact signature (body replaced). Fill the PR template's **Database** section: safe for the released app, no Edge Function to deploy.
- Every new table: RLS on, owner policies, `revoke all … from anon, authenticated` then explicit grants, in the same migration. `supabase/tests/schema_rls_test.sql` must pass.
- Copy in `lib/l10n/app_en.arb` only, every key with `@description`, informal register. Never "upline", "downline", "frontline", "recruit", "mentor" in UI copy: names only ("Share your goals with {name}?").
- Imports `package:loomia/...`; Material from `package:material_ui/material_ui.dart`.
- Theme tokens only (`colorScheme`, `AppSpacing`, `AppRadii`); layout via `context.screenSize`.
- Routes added to `lib/app/router/routes.dart` before the `GoRoute`.
- New UI patterns (invite sheet, code entry, "Shared by" section, Sharing page) mocked in Figma file `spz2vsSK8gbt1Ok2rW1sdQ`, page "04 — Screens (Light)", section "Goal sharing — #147", before their task is coded.
- Code alphabet `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (no 0/O, 1/I/L), length 8, shown `ABCD-EFGH`, case-insensitive; single use; expires 14 days after creation; one open invite per contact.
- Shared items: `activity_targets` (default on), `progress` (default off), `about_me` (default off). Volume and level are implicit in the link.
- Branch `feature/147-goal-sharing`; Conventional Commits; PR body `Closes #147`.

## Review Focus

1. **Code typed loosely** (`abcd efgh`, `abcd-efgh`, pasted with spaces or a trailing newline) — accepted as `ABCDEFGH`. Pinned in Task 2 (`normaliseCode`) and Task 1 (SQL accepts lowercase).
2. **Member already shares and enters another code** — refused with "You already share with {name}", the existing link untouched. Pinned in Task 1 test 9.
3. **Member turns an item off** — the server stops returning it on the mentor's next read, not only the UI. Pinned in Task 1 tests 13–14.
4. **Mentor deletes the contact, or either account is deleted** — link and open invite gone; member's Sharing page falls back to the code field. Pinned in Task 1 test 16.
5. **Shared item empty** (no plan for the month) — "{name} hasn't set this yet", not the mentor's notes. Pinned in Task 6 widget test.

---

### Task 0: Issue, branch, mockups

**Files:** none in repo.

- [ ] **Step 1:** Create the issue "Goal sharing between Loomia users" on the project board (link the spec), note its number `147`.
- [ ] **Step 2:** `git switch -c feature/147-goal-sharing main`; commit the spec and this plan: `docs(sharing): spec and plan for goal sharing (#147)`.
- [ ] **Step 3:** Mock in Figma (section "Goal sharing — #147"): invite sheet (code, Copy link, Cancel invite), contact "Aiming for" section in three states (no link with Invite button; invite sent; Shared by Marie with progress), Sharing page (no link with code field; preview with switches; linked with switches + Stop sharing + About me), onboarding "Got an invite code?" step, `/invite/:code` page signed out. Get the user's OK before Task 5.

### Task 1: Migration and pgTAP

**Files:**
- Create: `supabase/migrations/<timestamp>_goal_sharing.sql` (via `supabase migration new goal_sharing`)
- Create: `supabase/tests/goal_sharing_test.sql`

**Interfaces — Produces (SQL):**
- `create type public.share_item as enum ('activity_targets', 'progress', 'about_me');`
- `public.share_invite(id uuid pk, owner_id uuid default auth.uid(), person_id uuid, code text unique, expires_at timestamptz default now() + interval '14 days', created_at)`; `unique (person_id)`; `foreign key (person_id, owner_id) references public.person (id, owner_id) on delete cascade`. RLS: owner select / delete. Grants: `select, delete`.
- `public.share_link(id uuid pk, mentor_id uuid, member_id uuid unique references auth.users on delete cascade, person_id uuid unique, items public.share_item[] not null default '{activity_targets}', created_at, updated_at)`; `foreign key (person_id, mentor_id) references public.person (id, owner_id) on delete cascade`; `check (mentor_id <> member_id)`. RLS: select and delete where `mentor_id` or `member_id` = `(select auth.uid())`; update where `member_id` = uid. Grants: `select, delete`, `update (items)`. `set_updated_at` trigger.
- `public.about_me(owner_id uuid pk default auth.uid() references auth.users on delete cascade, why text, own_goal text, updated_at)`. Owner RLS for select/insert/update/delete; grants all four.
- `create_share_invite(p_person_id uuid) returns public.share_invite` — invoker. Raises `P0001 'not_team'` unless the caller's person is `stage = 'team'`. Upserts on `person_id` with a fresh code and `expires_at`. Code from `extensions.gen_random_bytes`, each byte mod 31 into the alphabet; retry on unique violation.
- `share_invite_preview(p_code text) returns text` — definer; the mentor's `first_name` from `auth.users.raw_user_meta_data`. Raises the accept errors below except it does not consume.
- `accept_share_invite(p_code text, p_items public.share_item[]) returns void` — definer. Normalises `upper(regexp_replace(p_code, '[^A-Za-z0-9]', '', 'g'))`. Errors, all `P0001`: `'invite_invalid'` (unknown/expired), `'invite_own'`, `'already_sharing'`. Inserts the link with `items = p_items`, deletes the invite.
- `my_share() returns table (mentor_first_name text, items public.share_item[])` — definer, the caller's link as member; zero rows when none.
- `month_progress_for(p_owner uuid, p_month date, p_starts timestamptz, p_ends timestamptz)` — definer, same columns as `month_progress`, every table read filtered by `owner_id = p_owner`. `revoke execute … from public, anon, authenticated`.
- `month_progress(...)` — `create or replace`, same signature and invoker, body `select * from public.month_progress_for((select auth.uid()), p_month, p_starts, p_ends)`. Existing `goals_test.sql` must still pass.
- `shared_goals(p_person_id uuid, p_month date, p_starts timestamptz, p_ends timestamptz) returns table (member_first_name text, items public.share_item[], plan jsonb, level_now text, progress jsonb, why text, own_goal text)` — definer. Zero rows unless a link has `person_id = p_person_id and mentor_id = auth.uid()` and the person is `stage = 'team'`. `plan` = the member's `month_plan` row for `p_month` as jsonb (only `own_volume_target, team_volume_target, level_target` plus, when `activity_targets` shared, the four count targets), null when no row. `level_now` = `level_actual` of the member's latest closed month. `progress` (jsonb of `month_progress_for`) only when `progress` shared; `why`/`own_goal` only when `about_me` shared. Each function: `set search_path = ''`, `revoke execute from public, anon`, `grant execute to authenticated`.

- [ ] **Step 1: Write the failing pgTAP test** `goal_sharing_test.sql`, users A (mentor), B (member), C (stranger); A owns team person P and prospect Q. Tests, in order:
  1. `create_share_invite(P)` returns a code matching `^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$`, `expires_at` ≈ now() + 14 days.
  2. Second `create_share_invite(P)` replaces it: one row, different code.
  3. `create_share_invite(Q)` throws `not_team`.
  4. As C, `select from share_invite` is empty.
  5. As B, `share_invite_preview(lower(code))` returns A's first name.
  6. As A, `accept_share_invite(code, '{}')` throws `invite_own`.
  7. As B, `accept_share_invite('ZZZZZZZZ', '{}')` throws `invite_invalid`; an invite with `expires_at` in the past (set as postgres) throws `invite_invalid`.
  8. As B, accept with `'{activity_targets}'` succeeds; the invite row is gone; the code reused throws `invite_invalid`.
  9. As B, accepting a second invite from C's team person throws `already_sharing`; B's link still names A.
  10. As B, `my_share()` returns A's first name and `{activity_targets}`.
  11. As C, `shared_goals(P, …)` returns zero rows; `select from share_link` empty.
  12. B has a month_plan for 2026-10 with all targets; as A, `shared_goals` returns `plan->>'own_volume_target'`, `plan->>'prospects_target'` set, `progress` null, `why` null.
  13. As B, `update share_link set items = '{}'`; as A, `plan ? 'prospects_target'` is false.
  14. As B, set items `'{progress,about_me}'` and an about_me row; as A, `progress->>'prospects'` and `why` returned.
  15. As A, `update share_link set items = …` changes nothing (0 rows); as A, P moved to `customer`: `shared_goals` zero rows; moved back: rows again.
  16. As A, delete P: `share_link` row gone (checked as postgres).
  17. As B, `month_progress(...)` still counts only B's own book.
- [ ] **Step 2:** `supabase test db` — expected FAIL (functions missing).
- [ ] **Step 3:** Write the migration per Interfaces. Header comment in the style of `20261004100527_goals.sql`: why a link, why definer functions are the only crossing.
- [ ] **Step 4:** `supabase db reset && supabase test db` — expected all pass, including `schema_rls_test.sql` and `goals_test.sql`.
- [ ] **Step 5:** Commit `feat(sharing): invites, links and shared goals in the database (#147)`.

### Task 2: Domain and repository

**Files:**
- Create: `lib/features/sharing/domain/share_item.dart`, `lib/features/sharing/domain/shared_goals.dart`, `lib/features/sharing/domain/invite_code.dart`
- Create: `lib/features/sharing/data/sharing_repository.dart`
- Test: `test/features/sharing/domain/invite_code_test.dart`, `test/features/sharing/data/sharing_repository_test.dart` (row mapping only, like the goals mapping tests), `test/features/sharing/fake_sharing_repository.dart`

**Interfaces — Produces:**
- `enum ShareItem { activityTargets, progress, aboutMe }` with `String get stored` (`activity_targets`…) and `static ShareItem? parse(String)`.
- `String? normaliseCode(String input)` — strips non-alphanumerics, upper-cases; null unless 8 chars from the alphabet. `String formatCode(String code)` → `ABCD-EFGH`.
- `class Invite { final String code; final DateTime expiresAt; }`
- `class MyShare { final String mentorFirstName; final Set<ShareItem> items; }`
- `class SharedGoals { final String memberFirstName; final Set<ShareItem> items; final MonthPlan? plan; final String? levelNow; final Progress? progress; final String? why; final String? ownGoal; }` — reuses `MonthPlan`/`Progress` from `lib/features/goals/domain/month_plan.dart`.
- `class AboutMe { final String? why; final String? ownGoal; }`
- `enum InviteFailure implements Exception { invalid, own, alreadySharing, notTeam, unknown }`
- `class SharingRepository(SupabaseClient)`, provider `sharingRepositoryProvider`:
  - `Future<Invite?> openInvite(String personId)`; `Future<Invite> createInvite(String personId)`; `Future<void> cancelInvite(String personId)`
  - `Future<String> previewInvite(String code)`; `Future<void> acceptInvite(String code, Set<ShareItem> items)` — map `P0001` messages to `InviteFailure`, others to `InviteFailure.unknown`.
  - `Future<MyShare?> myShare()`; `Future<void> setItems(Set<ShareItem> items)`; `Future<void> stopSharing()` (member: delete own link)
  - `Future<SharedGoals?> sharedGoals(String personId, DateTime month)` — `monthBounds`/`dayColumn` like `GoalsRepository._monthParams`; plan via `monthPlanFromRow` (add `month` from `p_month`), progress via `progressFromRow`.
  - `Future<void> stopSharingWith(String personId)` (mentor: delete link by `person_id`)
  - `Future<AboutMe> aboutMe()`; `Future<void> saveAboutMe(AboutMe)` — upsert, blank stored as null.
  - Non-invite methods wrap in `guardPeople`.

- [ ] **Step 1: Failing tests.** `normaliseCode(' abcd-efgh\n') == 'ABCDEFGH'`; `normaliseCode('abcd efgh') == 'ABCDEFGH'`; `normaliseCode('ABCDEFG0')` null (0 excluded); `normaliseCode('ABCDEFG')` null; `formatCode('ABCDEFGH') == 'ABCD-EFGH'`; `sharedGoalsFromRow` maps a row with `items: ['progress']`, `plan: null` to `items == {ShareItem.progress}`, `plan == null`; unknown item strings ignored.
- [ ] **Step 2:** `flutter test test/features/sharing` — FAIL.
- [ ] **Step 3:** Implement per Interfaces; `FakeSharingRepository` with settable fields and call counters for later widget tests.
- [ ] **Step 4:** `flutter test test/features/sharing` — PASS.
- [ ] **Step 5:** Commit `feat(sharing): sharing repository (#147)`.

### Task 3: Accept flow widget

**Files:**
- Create: `lib/features/sharing/presentation/accept_invite.dart`
- Test: `test/features/sharing/presentation/accept_invite_test.dart`
- Modify: `lib/l10n/app_en.arb`

**Interfaces — Produces:** `class AcceptInvite extends ConsumerStatefulWidget { const AcceptInvite({this.initialCode, required this.onAccepted}); final String? initialCode; final VoidCallback onAccepted; }` — code field → Continue (calls `previewInvite`) → "Share your goals with {name}?", the always-shared line, a switch per `ShareItem` (activity targets on, others off) → Accept (calls `acceptInvite`, then `onAccepted`). With `initialCode`, previews on open.

Copy keys (English): `inviteCodeLabel` "Invite code", `inviteContinue` "Continue", `inviteShareWith` "Share your goals with {name}?", `inviteAlwaysShared` "Your volumes and level for the month", `shareItemActivityTargets` "Your targets for prospects, customers, team and loyalty", `shareItemProgress` "How your month is going", `shareItemAboutMe` "Your why and your own goal", `inviteAccept` "Share", `inviteErrorInvalid` "This code doesn't work. Ask for a new one.", `inviteErrorOwn` "That's your own invite.", `inviteErrorAlreadySharing` "You already share your goals. Stop that first in Settings → Sharing."

- [ ] **Step 1: Failing widget tests:** entering `abcd-efgh` and Continue calls `previewInvite('ABCDEFGH')` and shows "Share your goals with Marie?"; switches default activity on, progress off, about-me off; Accept calls `acceptInvite('ABCDEFGH', {ShareItem.activityTargets})` and `onAccepted`; `InviteFailure.alreadySharing` shows `inviteErrorAlreadySharing`; Continue disabled while `normaliseCode` is null.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement. **Step 4:** Run — PASS.
- [ ] **Step 5:** Commit `feat(sharing): accept an invite (#147)`.

### Task 4: Sharing settings page, About me, onboarding step, invite link route

**Files:**
- Create: `lib/features/sharing/presentation/sharing_page.dart`, `lib/features/sharing/presentation/invite_link_page.dart`, `lib/features/sharing/presentation/sharing_controller.dart`
- Modify: `lib/app/router/routes.dart`, `lib/app/router/app_router.dart`, `lib/app/router/auth_redirect.dart`, `lib/features/settings/presentation/settings_page.dart`, `lib/features/onboarding/presentation/first_run_page.dart`, `lib/l10n/app_en.arb`
- Test: `test/features/sharing/presentation/sharing_page_test.dart`, `test/features/sharing/presentation/invite_link_page_test.dart`, `test/app/router/auth_redirect_test.dart`, `test/features/onboarding/presentation/first_run_page_test.dart`

**Interfaces:**
- Consumes: `AcceptInvite`, `SharingRepository`.
- Produces: `Routes.settingsSharingSegment = 'sharing'`, `Routes.settingsSharing`, `Routes.settingsSharingName`; `Routes.invitePrefix = '/invite'`, `Routes.inviteSegment = '/invite/:code'`, `Routes.inviteName`, `static String inviteLocation(String code)`. `myShareProvider` (`FutureProvider.autoDispose<MyShare?>`), `aboutMeProvider`.
- `authRedirect`: a location starting with `'${Routes.invitePrefix}/'` returns null in every state except password recovery.
- Sharing page: no link → `AcceptInvite`; linked → "You share your goals with {name}", a `SwitchListTile` per item calling `setItems`, "Stop sharing" with a `LoomiaDialog` confirm calling `stopSharing`. Below, section "About me": two text fields (why, own goal) saved with a Save button through `saveAboutMe`.
- Settings page: a `ListTile` "Sharing" in the group with Workflows and Tags, subtitle "With {name}" or "Not sharing".
- `FirstRunPage`: `_Step.invite` between `company` and `people`; `FirstRunInviteStep(onDone, onBack)` with `AcceptInvite` and a Skip `TextButton`; `_previous` updated (`people → invite → company`).
- `InviteLinkPage(code)`: signed in → `AcceptInvite(initialCode: code, onAccepted: go settingsSharing)`; signed out → `formatCode(code)` large, body "Sign in or create your account, then enter this code.", buttons to `Routes.login` and `Routes.register`.

- [ ] **Step 1: Failing tests:** `authRedirect(hasSession: false, location: '/invite/ABCDEFGH')` is null; with `onboarded: false` also null; Sharing page linked state shows the name and toggling progress calls `setItems({activityTargets, progress})`; Stop sharing after confirm calls `stopSharing`; first run goes company → invite → people and back from people lands on invite; Skip on the invite step shows people; signed-out invite page shows `ABCD-EFGH`.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement. **Step 4:** Run — PASS.
- [ ] **Step 5:** Commit `feat(sharing): sharing settings, onboarding step and invite link (#147)`.

### Task 5: Mentor side — invite sheet

**Files:**
- Create: `lib/features/sharing/presentation/invite_sheet.dart`, `lib/features/sharing/presentation/contact_sharing_controller.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/sharing/presentation/invite_sheet_test.dart`

**Interfaces — Produces:**
- `contactSharingProvider` — `FutureProvider.autoDispose.family<ContactSharing, String>` (person id) returning `typedef ContactSharing = ({SharedGoals? shared, Invite? invite})`, `shared` from `sharedGoals(id, DateTime.now())`, `invite` from `openInvite(id)` only when `shared` is null.
- `Future<void> showInviteSheet(BuildContext context, {required String personId, required String name})` — opens with `createInvite` when no open invite; shows `formatCode`, the link `https://app.getloomia.app/invite/<code>`, "Copy link" (`Clipboard.setData`, then a SnackBar "Link copied"), "Cancel invite" (`cancelInvite`, close), body "Send this to {name}. It works once, for 14 days." Invalidates `contactSharingProvider(personId)` on close.

- [ ] **Step 1: Failing tests:** sheet with no open invite calls `createInvite` once and shows `ABCD-EFGH`; with an open invite does not create; Copy link puts `https://app.getloomia.app/invite/ABCDEFGH` on the clipboard (mock `SystemChannels.platform`); Cancel calls `cancelInvite`.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement. **Step 4:** Run — PASS.
- [ ] **Step 5:** Commit `feat(sharing): invite a team member (#147)`.

### Task 6: Mentor side — contact page shows shared goals

**Files:**
- Modify: `lib/features/contacts/presentation/contact_details.dart` (`aimingFor`, ~L452–486), `lib/features/contacts/presentation/contact_page.dart` (`ContactPane`), `lib/l10n/app_en.arb`
- Test: `test/features/contacts/presentation/contact_details_test.dart`

**Interfaces — Consumes:** `contactSharingProvider`, `showInviteSheet`, `SharedGoals`, `stopSharingWith`. **Produces:** `ContactDetails` gains `ContactSharing? sharing`, `VoidCallback onInvite`, `VoidCallback onStopSharing`.

Merge rules (team stage only; non-team unchanged, nothing shown):
- `sharing == null` or both null → today's section plus a tonal "Invite to share goals" button (`AppTheme.tonal(context)`).
- `invite != null` → today's section plus "Invite sent · {code}" row that reopens the sheet.
- `shared != null` → header "Shared by {name}" with an overflow "Stop sharing" (confirm dialog). Rows: Level now ← `levelNow`; Aiming for ← `plan.levelTarget`, keeping the person's `targetLevelBy` as "by {month}" when set; Own volume ← `plan.ownVolumeTarget`; Team volume ← `plan.teamVolumeTarget`; when `activityTargets` in items: prospects, customers, team members, loyalty targets as `GoalLine` with `progress` when `progress` in items; Why / Own goal ← shared values when `aboutMe` in items, else the person's own. Time available, would love to, strengths, stuck on stay the person's.
- `shared.plan == null` → in place of the plan rows, "{name} hasn't set this month yet". `aboutMe` shared but blank → "{name} hasn't written this yet".
- Hand-typed fields are never written; Edit still edits them.

- [ ] **Step 1: Failing widget tests:** shared plan replaces `monthlyVolumeTarget` (hand value absent, both shared volumes present); `targetLevelBy` kept beside the shared level; `activityTargets` absent hides count rows; `aboutMe` absent shows the person's own why; `plan == null` shows "Marie hasn't set this month yet"; customer stage shows no shared section; no link shows the Invite button and tapping calls `onInvite`.
- [ ] **Step 2:** Run — FAIL. **Step 3:** Implement; wire `ContactPane` to watch `contactSharingProvider(person.id)` only when `person.stage == Stage.team`. **Step 4:** Run — PASS.
- [ ] **Step 5:** Commit `feat(sharing): shared goals on the contact page (#147)`.

### Task 7: Finish

- [ ] **Step 1:** `dart format . && flutter analyze && flutter test` — "No issues found!", all pass. `supabase test db` — all pass.
- [ ] **Step 2:** `graphify update .`
- [ ] **Step 3:** Run the app (web), two accounts: invite, accept from `/invite/<code>` signed out then in, toggle progress, stop sharing from each side; check the mentor's hand notes return.
- [ ] **Step 4:** Open the PR with the template: Ticket `Closes #147`, Database section "additive; safe for the released app; no Edge Function".
