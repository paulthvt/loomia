# Sign in with Apple Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Continue with Apple on the Welcome screen on every platform through Supabase's web flow, a first-run name step for accounts that arrive without a name, and a one-command way to regenerate Apple's 6-month secret with a warning before it expires.

**Architecture:** `AuthRepository.signInWithApple()` beside `signInWithGoogle()` (`signInWithOAuth(OAuthProvider.apple)`); a white / white-outline button styled in `app_theme.dart`. `Account.needsName`, computed in `AuthRepository.account`, adds a local first step to `FirstRunPage`. Ruby stays in `ios/`: a fastlane lane signs the secret with the `jwt` gem fastlane already bundles; a weekly workflow reads a repo variable holding the expiry date.

**Tech Stack:** Flutter (Riverpod, go_router, material_ui, supabase_flutter), fastlane (Ruby, in `ios/`), GitHub Actions. No migration, no new dependency.

**Spec:** `docs/superpowers/specs/2026-10-29-sign-in-with-apple-design.md` (issue #22, epic #400). Figma: "Sign in with Apple — #22", node 471:15413.

## Global Constraints

- No new runtime dependency, no gem added to `ios/Gemfile`, no migration.
- No Sign in with Apple entitlement in `ios/Runner/Runner.entitlements`.
- Copy in `lib/l10n/app_en.arb` only, each key described; reuse existing keys where they say the same thing.
- Theme values only, except Apple's black and white, which sit in `app_theme.dart` with a comment, like Google's 18 px mark.
- `package:loomia/...` imports; Material from `material_ui`.
- The `.p8`, the generated secret and `distribution.p12` never enter the repo or a CI log. Stage files by name, never `git add .`.
- Branch `feature/22-sign-in-with-apple`; PR body `Closes #22`; goldens only through CI.
- Checks: `dart format .`, `flutter analyze` (No issues found!), `flutter test`.

## Rulings made while planning

- Button: `OutlinedButton.icon` with `appleButtonStyle(Brightness)` from `app_theme.dart`: light = white fill, black foreground, 1 px black side; dark = white fill, black foreground, no side. It inherits the outlined theme's 48 minimum height, pill shape and label style, so the three Welcome buttons match.
- The mark: `assets/images/apple_logo.png` (+ `2.0x/`, `3.0x/`), 18 high like Google's, from Apple Design Resources' "Sign in with Apple" logo pack, tinted black through `Image.asset(color:)`. If the pack can't be downloaded without Paul's login, stop and ask him for it; never ship the Figma shape.
- `Account.needsName` is a constructor field (default `false`, so existing `Account(...)` calls in tests are unchanged), set in `AuthRepository.account` to `firstName.isEmpty && providerName.isEmpty`, where `providerName` is `full_name ?? name`, trimmed — the same read `_backfillFirstName` does, pulled into one `_providerName(metadata)` helper both use.
- `FirstRunPage` reads `needsName` once in `initState` (`ref.read(authRepositoryProvider).account?.needsName ?? false`), so it becomes a `ConsumerStatefulWidget`. Steps become an enum `_Step { name, company, people }`; `PopScope.canPop` is true only on the first shown step; back from company goes to name when it was shown.
- `FirstRunNameStep({required String initial, required ValueChanged<String> onSaved})`: a `Form` with one `TextFormField` (`authFirstNameLabel`, `firstNameFieldError`, `textCapitalization: words`, `autofillHints: [AutofillHints.givenName]`, submit on done), a `FormError`, and a full-width `FilledButton` Continue. It saves through `updateFirstName`; the page keeps the saved value to prefill on back.
- Copy, new keys: `authContinueWithApple` "Continue with Apple" (description: "Apple" stays untranslated, Apple's required wording), `firstRunNameQuestion` "What should we call you?", `firstRunNameBody` "Your first name, for your greeting on Today.", `firstRunNameContinue` "Continue". Reused: `firstRunEyebrow`, `authFirstNameLabel`, `authFirstNameRequired` (through `firstNameFieldError`).
- The name step shows the eyebrow "Welcome"; the company step then drops it when the name step came first (it was said once, as the people step does today, Figma 212:3241).
- Preview + golden: `firstRunNameLight` (390×844). No Welcome preview exists today; none is added.
- The lane: `lane :apple_auth_secret do |options|` in the existing `platform :ios` block, `require 'jwt'` inside it. Options `key:` (path to `.p8`) and `key_id:`; team and Services ID are constants at the top of the Fastfile. It prints the secret, then `gh variable set APPLE_AUTH_SECRET_EXPIRES --repo paulthvt/loomia --body <YYYY-MM-DD>`. `UI.user_error!` when the key file is missing.
- `.github/workflows/apple-secret-expiry.yaml`: `schedule: cron '0 7 * * 1'` and `workflow_dispatch`; one step in bash reads `vars.APPLE_AUTH_SECRET_EXPIRES`, fails when it is unset or fewer than 30 days away, with a message naming the README section. No secret, `permissions: {}`.
- Welcome test for large text: the existing scale test keeps its assertion with the third button; if it overflows, that's a real bug to fix in the layout, not in the test.

## Review Focus

- A Google user is never shown the name step, even when the backfill hasn't landed when the first run opens (Task 3).
- Back and the system gesture between name and company, with the name prefilled; back from the name step leaves nothing behind (Task 3).
- The Apple button in dark mode is readable: white fill with black text, not the outlined theme's `primaryText` (Task 2).
- The lane's JWT: `kid` in the header, not the claims; `exp` = `iat` + 180 days exactly; nothing written to disk (Task 4).
- The expiry workflow can't leak anything: no secret in scope, `permissions: {}` (Task 4).

---

### Task 1: `signInWithApple` and `needsName`

**Files:**
- Modify: `lib/features/auth/domain/account.dart` (`needsName`)
- Modify: `lib/features/auth/data/auth_repository.dart` (`signInWithApple()`, `_providerName`, `needsName` in `account`; drop the "not wired up" comment)
- Modify: `test/features/auth/fake_auth_repository.dart` (`signInWithApple()` records `'signInWithApple()'`; `_copy`-style rebuilds keep `needsName`)
- Test: `test/features/auth/data/auth_repository_test.dart` (create if absent; else the existing repository test file)

**Interfaces:**
- Produces: `Future<void> AuthRepository.signInWithApple()`; `bool Account.needsName`.

- [x] **Step 1: Failing tests** for the account mapping, through a `SupabaseClient` whose `currentUser` metadata is set (or, if the repository has no seam for that, a plain test of a top-level `bool needsNameFrom(Map<String, dynamic> metadata)` used by `account`):
  - `{}` → true; `{'first_name': ' '}` → true;
  - `{'first_name': 'Pauline'}` → false;
  - `{'full_name': 'Pauline Martin'}` → false; `{'name': 'Pauline'}` → false; `{'full_name': '  '}` → true.
- [x] **Step 2: Run** the test → FAIL.
- [x] **Step 3: Implement** as in the Rulings; `_backfillFirstName` reads `_providerName` too.
- [x] **Step 4: Run** it and `test/features/auth` → PASS.
- [x] **Step 5: Commit** `feat(auth): sign in with Apple in the repository`.

### Task 2: The Apple button

**Files:**
- Create: `assets/images/apple_logo.png`, `assets/images/2.0x/apple_logo.png`, `assets/images/3.0x/apple_logo.png` (from Apple Design Resources)
- Modify: `lib/app/theme/app_theme.dart` (`appleButtonStyle`)
- Modify: `lib/features/auth/presentation/welcome_page.dart`
- Modify: `lib/l10n/app_en.arb` (`authContinueWithApple`)
- Test: `test/features/auth/presentation/welcome_page_test.dart`

**Interfaces:**
- Consumes: `signInWithApple()` (Task 1).
- Produces: `ButtonStyle appleButtonStyle(Brightness brightness)`.

- [x] **Step 1: Failing tests:**
  - `'offers Google, Apple, then email'`: the three labels, in that vertical order;
  - `'Apple starts the Apple sign-in'`: tap → fake records `signInWithApple()`;
  - `'a failed Apple sign-in shows the error'`: fake throws `AuthFailure.network` → its copy;
  - `'Apple is white with a black outline in light, white in dark'`: the button's resolved `backgroundColor` is white in both, `side` black in light and none in dark, foreground black in both;
  - the existing large-text test still passes with three buttons.
- [x] **Step 2: Run** `flutter test test/features/auth/presentation/welcome_page_test.dart` → FAIL.
- [x] **Step 3: Implement**: download the logo, `appleButtonStyle`, the button between Google and email (`_busy` handling as Google), the copy key; remove the "absent rather than broken" comment.
- [x] **Step 4: Run** it → PASS.
- [x] **Step 5: Commit** `feat(auth): Continue with Apple on the Welcome screen`.

### Task 3: The name step

**Files:**
- Modify: `lib/features/onboarding/presentation/first_run_page.dart` (`FirstRunNameStep`, steps enum, `needsName` at open, the company step's eyebrow)
- Modify: `lib/features/onboarding/presentation/first_run_preview.dart` (`firstRunNameLight`)
- Modify: `test/previews_test.dart` (`'first_run_name_light'`)
- Modify: `lib/l10n/app_en.arb` (`firstRunNameQuestion`, `firstRunNameBody`, `firstRunNameContinue`)
- Test: `test/features/onboarding/presentation/first_run_page_test.dart`

**Interfaces:**
- Consumes: `Account.needsName`, `updateFirstName` (Task 1).
- Produces: `FirstRunNameStep({required String initial, required ValueChanged<String> onSaved})`.

- [x] **Step 1: Failing tests** (fake account `onboarded: false`):
  - `'an account without a name is asked for it first'`: `needsName: true` → `What should we call you?`, no company question;
  - `'an account with a name starts at the company'`: `needsName: false` → the company question (the existing first test, unchanged);
  - `'an empty name is refused'`: Continue with the field empty → `Enter your first name.`, nothing recorded;
  - `'Continue saves the name and moves to the company'`: type "Pauline", Continue → fake records `updateFirstName(Pauline)`, the company question shown, no "Welcome" eyebrow on it;
  - `'a failed save stays on the name'`: fake throws → the failure copy, field still "Pauline";
  - `'back from the company returns to the name, filled'`: after saving, back button and then `tester.binding.handlePopRoute()` → the name step with "Pauline";
  - `'needsName read once'`: flip the fake's account to a name while on the name step → still on the name step;
  - `'an onboarded account never sees it'` keeps passing.
- [x] **Step 2: Run** `flutter test test/features/onboarding` → FAIL.
- [x] **Step 3: Implement** as in the Rulings, plus the copy keys.
- [x] **Step 4: Preview** `firstRunNameLight` (the step with an empty field), registered in `previews_test.dart`.
- [x] **Step 5: Run** `dart format . && flutter analyze && flutter test test/features/onboarding test/previews_test.dart` → PASS (the new golden is missing locally; it's made on CI).
- [x] **Step 6: Commit** `feat(onboarding): ask for a first name when the account has none`.

### Task 4: Supabase config, the secret lane, the expiry warning, docs

**Files:**
- Modify: `supabase/config.toml` (`[auth.external.apple]` `enabled = true`, `client_id = "app.loomia.signin"`)
- Modify: `ios/fastlane/Fastfile` (`apple_auth_secret` lane and the usage line in its header)
- Create: `.github/workflows/apple-secret-expiry.yaml`
- Modify: `README.md` (Sign in with Apple setup and rotation; the line at :45; the `config push` line at :78 gains `SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=...`), `docs/design/screens.md:216-218`, `docs/superpowers/specs/2026-09-23-auth-login-design.md` (its "not wired up" Apple lines)

- [x] **Step 1: Check, before the lane:** `cd ios && bundle exec ruby -e 'require "jwt"; puts JWT::VERSION::STRING'` prints a version. If not, stop: the spec's "no new gem" ruling needs revisiting with Paul.
- [x] **Step 2: The lane**, then verify with a throwaway key in `$KIROCREW_SCRATCH` (`openssl ecparam -name prime256v1 -genkey -noout | openssl pkcs8 -topk8 -nocrypt`): run it, decode the printed token's header and claims (`ruby -rjwt -e 'p JWT.decode(ARGV[0], nil, false)'`) → `alg ES256`, `kid` = the given id, `iss 378X654D2A`, `aud https://appleid.apple.com`, `sub app.loomia.signin`, `exp - iat = 15552000`. Record the decoded output (not the token) in the PR.
- [x] **Step 3: The workflow**, then check its date logic locally with the same bash: a date 10 days out → exit 1; 60 days out → exit 0; empty → exit 1. Parse the YAML (`ruby -ryaml -e 'YAML.load_file(ARGV[0])'`).
- [x] **Step 4: Config and docs.** README's setup lists Paul's steps from the spec's *Setup*, the 6-month rotation, and the App Store profile regeneration if it went Invalid.
- [x] **Step 5: Run** `dart format . && flutter analyze && flutter test` → No issues, all pass.
- [x] **Step 6: Commit** `feat(auth): turn on the Apple provider, with a secret lane and an expiry check`.

### Task 5: Ship

- [x] **Step 1:** Tick this plan; note deviations at the end.
- [x] **Step 2:** One fresh reviewer on the whole branch against the spec and this plan; fix what blocks.
- [ ] **Step 3:** `git push -u origin feature/22-sign-in-with-apple`; PR `Closes #22`, Database section: no migration, `supabase config push` by hand after merge with both provider secrets. Regenerate goldens through CI (`gh workflow run CI --ref feature/22-sign-in-with-apple -f update-goldens=true`), check the PNGs, commit them.
- [ ] **Step 4:** CI green.
- [ ] **Step 5 (Paul, after merge):** the spec's *Setup* steps 1–3, then the device checks in its *Test plan* on the iPhone, web and Android.

## Changes during implementation

- The mark: Apple's *left-aligned* logo (black, medium), which carries its own padding and is drawn 44 high, its size for a 44–48 button, not an 18 px mark tinted. The download is public (`Logo-Sign-in-with-Apple.dmg`), no login. Its dark-mode variant isn't needed: the foreground is black in both modes.
- The style is `AppTheme.signInWithApple(context)`, next to `AppTheme.tonal`, rather than a top-level `appleButtonStyle(Brightness)`.
- `needsName` is tested through a top-level `needsNameFrom(metadata)` (`test/features/auth/data/needs_name_test.dart`): the repository has no seam for a fake user.
- The lane prints the secret and the `gh variable set` line with `$stdout.puts`: fastlane prefixes `puts` with a timestamp, which would end up in a copied secret. Verified with a throwaway key: the token verifies with it, header `{kid, alg: ES256}`, claims `iss 378X654D2A`, `aud https://appleid.apple.com`, `sub app.loomia.signin`, `exp - iat = 15552000`.
- The expiry check's bash, run locally with GNU date: unset → 1, 10 days → 1, 60 days → 0.
- README: a new "Sign in with Apple" section under Auth, with the portal setup and the rotation.
- Locally, `nudge_card_test.dart` fails (3 tests) on `main` as well as here, so it's not this branch; CI passed it at the last merges (this Mac runs Flutter 3.47.0, pinned 3.47.7).
- Review (one fresh reviewer, whole branch): nothing blocking; the five Review Focus points hold. Its one suggestion (the fake's `markOnboarded` "drops" `onboarded`) doesn't apply: `Account.onboarded` defaults to `true`.
