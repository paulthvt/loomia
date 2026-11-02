# Invite Links Open the App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `https://app.getloomia.app/invite/<code>` opens the installed app on Android and iOS, still opens the web app elsewhere, and old `/#/invite/<code>` links keep working.

**Architecture:** Path URLs on web (`usePathUrlStrategy`) with an old-fragment rewrite at the top of `main`; verification files served from `web/.well-known/`; an `autoVerify` intent filter and the Associated Domains entitlement scoped to `/invite/`; a `web` track in `promote.yaml` to make a web version live without touching the stores.

**Tech Stack:** Flutter (web, Android, iOS), go_router, Cloudflare Workers static assets (wrangler), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-02-invite-links-open-app-design.md`

## Global Constraints

- Branch `feature/440-invite-links-open-app`; Conventional Commits with `(#440)`.
- No new dependency: `flutter_web_plugins` is `sdk: flutter`, with a pubspec comment giving the reason.
- Only `/invite/` opens the app: Android `pathPrefix="/invite/"`, iOS component `"/invite/*"`.
- Android package `app.loomia`; fingerprints exactly as in the spec (app signing `E3:B6:…:6D:07`, upload `13:40:…:BA:1D`).
- iOS app ID `378X654D2A.app.loomia`; entitlement `applinks:app.getloomia.app`.
- Paths from `Routes` (`Routes.inviteLocation`), no path literal in widgets.
- Do not merge before the user confirms the Apple portal and profile steps (spec → Needs from the user).

## Review Focus

1. **A Supabase callback on web** (`/?code=…`, or an error fragment like `#error=…`) is untouched by the fragment rewrite. Pinned in Task 2's rewrite tests.
2. **An old bookmark `/#/contacts/x`** lands on `/contacts/x`. Pinned in Task 2.
3. **`.well-known` missing from the Cloudflare upload**, so links silently never verify. Pinned by Task 1's check and Task 6's preview fetch.
4. **The AASA served as `application/octet-stream`**, which iOS ignores. Pinned in Task 6's `curl -I`.
5. **A promote to `alpha`, `beta` or `production` changes behaviour.** Pinned in Task 5: the existing `if:` conditions stay for those tracks.

---

### Task 1: Do the dot files reach Cloudflare?

**Files:** none committed unless a fix is needed (then `.assetsignore` or `wrangler.jsonc`).

- [ ] **Step 1:** Create a throwaway `web/.well-known/probe.txt`, then run `flutter build web --release`. Expected: `build/web/.well-known/probe.txt` exists.
- [ ] **Step 2:** `npx --yes wrangler@4.147.0 deploy --dry-run --outdir /tmp/wr` (or `versions upload --dry-run`). Check whether its asset list includes `.well-known/probe.txt`. If wrangler skips dot directories, rule on the fix (an `.assetsignore` that re-includes it, or the documented option), and ledger it.
- [ ] **Step 3:** Delete the probe. Commit only if a config fix was needed: `fix(web): upload .well-known (#440)`.

### Task 2: Path URLs on web, the old-fragment rewrite, and the invite link

**Files:**
- Create: `lib/app/router/legacy_fragment.dart`
- Modify: `lib/main.dart` (top of `main`), `pubspec.yaml`, `lib/features/sharing/presentation/invite_sheet.dart` (`_inviteLink`)
- Test: `test/app/router/legacy_fragment_test.dart`, `test/features/sharing/presentation/invite_sheet_test.dart`

**Interfaces — Produces:** `Uri? legacyFragmentTarget(Uri url)`. Returns the URL to switch to when `url.fragment` starts with `/`: the fragment's path and query, on the same origin, with the original query dropped. Returns null otherwise. On web only, `main` calls it first, then `window.history.replaceState(null, '', target.toString())` (via `package:web`, or `dart:js_interop`; whichever is already available, with no new package), then `usePathUrlStrategy()`. On other platforms nothing runs (`kIsWeb` guard).

- [ ] **Step 1: Failing tests.**
  - `legacyFragmentTarget(Uri.parse('https://app.getloomia.app/#/invite/ABCDEFGH'))` → `'https://app.getloomia.app/invite/ABCDEFGH'`
  - `…/#/` → `'https://app.getloomia.app/'`
  - `…/#/contacts/p1?tab=history` → `…/contacts/p1?tab=history`
  - `…/?code=abc` → null
  - `…/#access_token=x&type=recovery` → null
  - `…/invite/AB` → null
  - Invite sheet: the copied link is `https://app.getloomia.app/invite/ABCDEFGH`, displayed as `app.getloomia.app/invite/ABCDEFGH`.
- [ ] **Step 2:** Run them. FAIL.
- [ ] **Step 3:** Implement. Add `flutter_web_plugins: sdk: flutter` to the pubspec, with the comment "path URLs on web, so App Links and universal links can match `/invite/` (#440)".
- [ ] **Step 4:** Run the focused tests, then `flutter analyze`. PASS, "No issues found!". Then `flutter build web --release` succeeds.
- [ ] **Step 5:** Commit `feat(web): path URLs, old # links still land (#440)`.

### Task 3: The verification files

**Files:**
- Create: `web/.well-known/assetlinks.json`, `web/.well-known/apple-app-site-association`
- Modify: `web/_headers`
- Test: `test/web/well_known_test.dart`

**Contents:**
- `assetlinks.json`: one statement, `relation: ["delegate_permission/common.handle_all_urls"]`, `target: {namespace: "android_app", package_name: "app.loomia", sha256_cert_fingerprints: [<app signing>, <upload>]}`.
- AASA: the JSON from the spec.
- `_headers` gains:
  ```
  /.well-known/apple-app-site-association
    Content-Type: application/json
  ```

- [ ] **Step 1: Failing test.** The test reads both files with `dart:io`, parses the JSON, and asserts the package, both fingerprints, the appID, and the component `"/": "/invite/*"`. It also asserts that `_headers` contains the AASA content-type rule.
- [ ] **Step 2:** Run it. FAIL. **Step 3:** Write the files. **Step 4:** Run it. PASS.
- [ ] **Step 5:** Commit `feat(sharing): verification files for app and universal links (#440)`.

### Task 4: Android intent filter and iOS entitlement

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml` (main activity, after the login-callback filter), `ios/Runner/Runner.entitlements`
- Test: `test/platform/app_links_config_test.dart`

**Contents:**
- Manifest: `<intent-filter android:autoVerify="true">` with `VIEW`, `DEFAULT`, `BROWSABLE` and `<data android:scheme="https" android:host="app.getloomia.app" android:pathPrefix="/invite/"/>`, plus a comment pointing to #440 and `web/.well-known/assetlinks.json`.
- Entitlements: `com.apple.developer.associated-domains` → `<array><string>applinks:app.getloomia.app</string></array>`, with a comment saying the App ID needs the capability and the profile must be regenerated.

- [ ] **Step 1: Failing test.** It reads both files and asserts the manifest contains `android:autoVerify="true"`, `android:host="app.getloomia.app"` and `android:pathPrefix="/invite/"`, and the entitlements contain `applinks:app.getloomia.app`.
- [ ] **Step 2:** Run it. FAIL. **Step 3:** Edit both files. **Step 4:** Run it, then `flutter build apk --debug`. PASS.
- [ ] **Step 5:** Commit `feat(sharing): invite links open the app on Android and iOS (#440)`.

### Task 5: A web-only promote

**Files:**
- Modify: `.github/workflows/promote.yaml`, README.md → Web (or Releases): one line on `track=web`

**Changes:**
- `track` options become `[alpha, beta, production, web]`, with a comment: "web: make this tag's web version live on app.getloomia.app; the stores are untouched".
- The Ruby setup and "Move the build on Play" steps get `if: inputs.track != 'web'`.
- "Make the web version live" gets `if: inputs.track == 'production' || inputs.track == 'web'`.
- "Mark the GitHub release final" stays `production` only.

- [ ] **Step 1:** Edit. Then validate with `actionlint`, or with `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/promote.yaml'))"` when actionlint isn't installed. It parses.
- [ ] **Step 2:** Commit `ci(web): promote the web alone (#440)`.

### Task 6: Finish

- [ ] **Step 1:** Run `dart format .`, `flutter analyze` ("No issues found!"), `flutter test` and `graphify update .`.
- [ ] **Step 2:** Push, then open the PR (template; `Closes #440`). In the PR:
  - the manual Apple steps, which must be done before merge;
  - "after merge and release: `gh workflow run Promote -f tag=<tag> -f track=web`";
  - web URLs changing from `#/` to paths.
- [ ] **Step 3:** After the release's preview upload, check:
  - `curl -s https://internal-loomia.<account>.workers.dev/.well-known/assetlinks.json` returns the JSON;
  - `curl -sI …/.well-known/apple-app-site-association` returns `content-type: application/json`;
  - opening `…/#/invite/ABCDEFGH` lands on `/invite/ABCDEFGH`.

  Then ask the user to try web sign-in on the preview: email, Google, Apple, password reset.
- [ ] **Step 4:** Regenerate goldens through CI if a preview changed.
