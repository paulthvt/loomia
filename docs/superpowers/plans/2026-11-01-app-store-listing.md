# App Store listing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The App Store listing (text EN/FR, category, age rating, review notes, iPhone and iPad screenshots) lives in `ios/fastlane/metadata/` and is sent to App Store Connect by a manual workflow.

**Architecture:** `deliver`'s folder layout under `ios/fastlane/`, checked by a plain Dart test in the normal CI. A new `upload_listing` lane finds the editable App Store version and runs `deliver` without a binary. `.github/workflows/store-listing.yaml` (`workflow_dispatch`, macOS) feeds it a release's `store-screenshots.zip`. The screenshot test gains two Apple sizes and neutral sample data.

**Tech Stack:** fastlane 2.241.2 (`ios/Gemfile.lock`), Dart `flutter_test`, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-01-app-store-listing-design.md`

## Global Constraints

- French in *tu*; no "recruit", rank, downline, PV/OV, "Elite", essential oil, lavender, peppermint, income claims, anywhere in the listing or the screenshot data.
- Apple limits: name ≤ 30, subtitle ≤ 30, promotional text ≤ 170, keywords ≤ 100 (comma-separated, no spaces after commas), description ≤ 4000.
- URLs on `https://getloomia.app`; French files use the `/fr` paths.
- The lane never submits for review, never uploads a binary, never touches prices or App Privacy.
- No secret value in the repo: `ASC_DEMO_USER`, `ASC_DEMO_PASSWORD` and `ASC_REVIEW_PHONE` are GitHub secrets (the repo is public).
- Actions pinned by commit SHA, as in `release.yaml`.

## Rulings made while planning

- **The listing check is a Dart test** (`test/store_listing_test.dart`), not Ruby: it runs in the existing `flutter test` job with no new CI step.
- **The neutral-data rule is pinned by a test** in the same file that reads `test/store_screenshots_test.dart` as text and fails on the MLM word list. Cheap, and it catches a sample added later.
- **The screenshot mapping lives in the lane** (Ruby, ~15 lines), checked by running the lane with `dry_run:true`, which stops after laying out the folders. No Ruby test framework is added.
- **The demo account email is a secret too,** `ASC_DEMO_USER`: it is Paul's personal address and the repo is public.

## Review Focus

1. A French field over Apple's limit (subtitle especially): the test fails with the field and its length. (Task 2.)
2. A missing file in one language (e.g. `fr-FR/keywords.txt`): the test fails naming it, rather than `deliver` uploading an empty field. (Task 2.)
3. No editable App Store version: the lane stops with "Create a version in App Store Connect first", not a fastlane stack trace. (Task 3, by reading the code path; no live test.)
4. A tag whose `store-screenshots.zip` predates this change (no `iphone-6.9`/`ipad-13` folders): the lane stops with "No App Store screenshots in this release", instead of wiping the listing's screenshots with `overwrite_screenshots`. (Task 3, `dry_run`.)
5. Trailing newlines in metadata files: `deliver` trims them, but the length test counts trimmed text. (Task 2.)

---

### Task 1: Neutral sample data and the App Store sizes

**Files:**
- Modify: `test/store_screenshots_test.dart` (devices map, `_book()`, `_events()`, `_history()`)
- Modify: `README.md` → *App icons* (the device list)

- [x] **Step 1: Devices.** Add `'iphone-6.9': (Size(440, 956), 3.0), // 1320×2868, bottom bar` and `'ipad-13': (Size(1032, 1376), 2.0), // 2064×2752, icon rail`; replace the comment "No App Store sizes until there is an iOS listing" with which sizes are for which store.
- [x] **Step 2: Neutral data.** Marie's `needs` "Sleep, stress" → "Gift ideas"; notes → "Met at the Saturday market. Asked about the autumn range."; Lucas' `products` → "Starter set, Refill"; `needs` "Headaches" → "Monthly refill"; history "Asked about lavender for sleep" → "Asked about the autumn range"; events `e1` → "Product evening" at Studio Lumière, Lyon; `e2` "New member training" → "Team catch-up"; `e3` → "Spring open house", Chez Claire; `e4` "Workshop" stays. Workflow ids (`samples`, `health`, …) are internal, untouched.
- [x] **Step 3: Render once:** `flutter test test/store_screenshots_test.dart --dart-define=STORE_SCREENSHOTS=true`, then open `build/store/iphone-6.9/fr/1_today.png` and `build/store/ipad-13/en/2_contacts.png`. Expected: 1320×2868 with the bottom bar; 2064×2752 with the icon rail; no oils anywhere.
- [x] **Step 4: README:** the device list gains `iphone-6.9` and `ipad-13` "for the App Store, uploaded by the Store listing workflow".
- [x] **Step 5: Commit:** `test(store): App Store sizes and neutral sample data`.

### Task 2: The listing files and their check

**Files:**
- Create: `ios/fastlane/metadata/{en-US,fr-FR}/{name,subtitle,promotional_text,description,keywords,support_url,marketing_url,privacy_url}.txt`, `ios/fastlane/metadata/{copyright,primary_category,secondary_category}.txt`, `ios/fastlane/metadata/review_information/{first_name,last_name,email_address,notes}.txt`, `ios/fastlane/rating_config.json`
- Test: `test/store_listing_test.dart`

**Interfaces:**
- Produces: the folder `ios/fastlane/metadata/` in `deliver`'s layout; Task 3 passes it as `metadata_path`.

- [x] **Step 1: Write the failing test** `test/store_listing_test.dart`, reading files with `dart:io` (trimmed):

```dart
const languages = ['en-US', 'fr-FR'];
const limits = {'name': 30, 'subtitle': 30, 'promotional_text': 170, 'keywords': 100, 'description': 4000};
const fields = [...limits.keys, 'support_url', 'marketing_url', 'privacy_url'];
test('every field exists in every language and fits Apple\'s limit', ...)  // message: '$lang/$field: ${text.length} > $max'
test('keywords are comma-separated with no spaces', ...)          // !text.contains(', ')
test('URLs are on getloomia.app, French ones under /fr', ...)     // privacy: https://getloomia.app/privacy and /fr/privacy, etc.
test('French uses tu', ...)                                        // no \b(vous|votre|vos)\b in fr-FR/*
test('nothing reads as MLM', ...)                                  // listing + test/store_screenshots_test.dart, the site's regex plus lavender|peppermint
test('categories and review details are set', ...)                 // primary BUSINESS, secondary PRODUCTIVITY, first_name Paul, last_name Thevenot, email hello@getloomia.app
test('the age rating answers every question with none or false', ...) // rating_config.json values all 'NONE' or false
```

- [x] **Step 2: Run** `flutter test test/store_listing_test.dart`. Expected: FAIL, files missing.
- [x] **Step 3: Text.** English name, subtitle and promotional text verbatim from the spec; keywords `follow-up,contacts,CRM,customers,reminders,relationships,small business,planner,clients`; description in four short paragraphs as the spec lists them, plain text, no emoji. French the same in *tu*; subtitle « Sache qui recontacter aujourd’hui » is 33 characters: use « Qui recontacter aujourd’hui » (28). Copyright `2026 Paul Thevenot`. Categories `BUSINESS` / `PRODUCTIVITY`.
- [x] **Step 4: Review notes.** `notes.txt`: "Sign in with Continue with email and the demo account below. It holds sample contacts, events and a month plan. Sign in with Google and Apple work too but create an empty account."
- [x] **Step 5: `rating_config.json`** with the keys `deliver` 2.241.2 reads for `app_rating_config_path` (from its source, `deliver/lib/deliver/upload_metadata.rb`), every content descriptor `NONE`, every boolean `false`.
- [x] **Step 6: Run** `flutter test test/store_listing_test.dart`, then `dart format .`, `flutter analyze`. Expected: PASS, no issues.
- [x] **Step 7: Commit:** `chore(store): App Store listing in English and French`.

### Task 3: The lane, the workflow, the docs

**Files:**
- Modify: `ios/fastlane/Fastfile` (lane `upload_listing`), `.gitignore` (`ios/fastlane/screenshots/`), `README.md` → Releases → iOS
- Create: `.github/workflows/store-listing.yaml`

**Interfaces:**
- Consumes: `api_key` private lane; `ios/fastlane/metadata/` and `rating_config.json` (Task 2); a release's `store-screenshots.zip` unzipped to a folder with `<device>/<lang>/N_screen.png` (Task 1).

- [x] **Step 1: `lane :upload_listing do |options|`**, options `screenshots` (path to the unzipped folder, required) and `dry_run`:
  - copy `iphone-6.9/<lang>/*.png` and `ipad-13/<lang>/*.png` into `ios/fastlane/screenshots/<locale>/`, `en` → `en-US`, `fr` → `fr-FR`, prefixing the device so names don't collide; `UI.user_error!('No App Store screenshots in this release')` when neither device folder exists;
  - `dry_run`: list the copied files and stop;
  - otherwise `api_key`, then `version = Spaceship::ConnectAPI::App.find('app.loomia').get_edit_app_store_version(platform: Spaceship::ConnectAPI::Platform::IOS)`; `UI.user_error!('Create a version in App Store Connect first')` unless `version`;
  - `deliver(app_version: version.version_string, skip_binary_upload: true, skip_app_version_update: true, submit_for_review: false, overwrite_screenshots: true, run_precheck_before_submit: false, force: true, metadata_path:, screenshots_path:, app_rating_config_path:, app_review_information: { phone_number: ENV.fetch('ASC_REVIEW_PHONE'), demo_user: ENV.fetch('ASC_DEMO_USER'), demo_password: ENV.fetch('ASC_DEMO_PASSWORD') })`. The other review fields come from `metadata/review_information/`.
- [x] **Step 2: Header comment** of the Fastfile gains the lane's command line.
- [x] **Step 3: Check it locally:** run Task 1's render, then `cd ios && bundle exec fastlane upload_listing screenshots:../build/store dry_run:true`. Expected: 16 files listed (4 screens × 2 devices × 2 languages). With `build/store` holding only the Play folders: the "No App Store screenshots" error. Remove `ios/fastlane/screenshots/` after.
- [x] **Step 4: Workflow** `store-listing.yaml`: `on: workflow_dispatch` with input `tag` (required); `macos-latest`, `timeout-minutes: 20`, `permissions: contents: read`; checkout `main`, `ruby/setup-ruby` (`working-directory: ios`, `bundler-cache: true`), `gh release download "$TAG" -p store-screenshots.zip` and unzip to `$RUNNER_TEMP/store`, then `bundle exec fastlane upload_listing screenshots:$RUNNER_TEMP/store` with `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, `ASC_DEMO_USER`, `ASC_DEMO_PASSWORD`, `ASC_REVIEW_PHONE`.
- [x] **Step 5: README → Releases → iOS:** "Store listing" with the files, `gh workflow run "Store listing" -f tag=<tag>`, when to run it, the three secrets, and that App Privacy is answered by hand from the spec.
- [x] **Step 6: Run** `dart format .`, `flutter analyze`, `flutter test`; `ruby -ryaml -e 'YAML.load_file(".github/workflows/store-listing.yaml")'`.
- [x] **Step 7: Commit:** `ci(store): upload the App Store listing from a workflow`.

### Task 4: Ship

- [ ] **Step 1:** Whole-branch review, PR `chore(store): App Store listing, privacy labels and screenshots` with `Part of #398`, CI green, merge.
- [ ] **Step 2, Paul:** `gh secret set` for `ASC_DEMO_USER`, `ASC_DEMO_PASSWORD` and `ASC_REVIEW_PHONE`; App Privacy answers in App Store Connect from the spec's table.
- [ ] **Step 3:** After the next release (it carries the new screenshots): `gh workflow run "Store listing" -f tag=<tag>`, watch it, then Paul checks the listing in App Store Connect. Then #398 closes.
