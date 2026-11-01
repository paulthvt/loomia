# iOS promote Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `gh workflow run Promote -f tag=<tag> -f track=<track>` also moves the tag's iOS build: to external TestFlight for alpha/beta, to App Store review (auto-release) for production.

**Architecture:** A `promote` lane in `ios/fastlane/Fastfile` and an independent `ios` job in `.github/workflows/promote.yaml`, beside the untouched Play job. The lane derives version and build number from the tag, finds the TestFlight build, then calls `upload_to_testflight(distribute_only:)` or `deliver(submit_for_review:)`.

**Tech Stack:** fastlane 2.241.2, GitHub Actions (macOS runner).

**Spec:** `docs/superpowers/specs/2026-11-01-ios-promote-design.md`

## Global Constraints

- No rebuild at promote time; the build is the one `release.yaml` uploaded for the tag.
- Build number = `year*10000 + month*100 + micro` from `vYYYY.MM.N`; version string = the tag without `v`.
- External group name exactly `External testers`.
- Production: `automatic_release: true`, `phased_release: false`, `skip_screenshots: true`, `skip_binary_upload: true`.
- The Play job and the "Mark the GitHub release final" step stay as they are.
- Actions pinned by commit SHA.

## Rulings made while planning

- **The tag → version/build mapping is a private lane helper** (`tag_build(tag)`), checked by a `dry_run:true` mode that prints version, build number, track and the notes it would send, and stops before any API call. No Ruby test framework, as in #398.
- **Notes come from `release-notes.json`** like Android: `notes:` option, a path. TestFlight takes `en-US`; production `release_notes` takes both keys.
- **"Already submitted" check** reads the app's App Store versions (`app.get_app_store_versions`) for one whose `version_string` is the tag's and whose state is `WAITING_FOR_REVIEW`, `IN_REVIEW`, `PENDING_DEVELOPER_RELEASE`, `PROCESSING_FOR_APP_STORE` or `READY_FOR_SALE`.
- **First version:** deliver's own `is_first_version` drops What's New; the lane always passes the notes.

## Deviations while building

- `tag_build` and `review_details` are plain Ruby methods at the top of the Fastfile, not private lanes: a fastlane lane only takes a hash.
- The lane looks the build up (`Build.all`, processing state `VALID`) before distributing: `upload_to_testflight` would otherwise poll for a missing build until the runner times out.

## Review Focus

1. A tag whose build is missing or still processing on TestFlight: a clear "Build <n> (<version>) is not on TestFlight" error. (Task 1, by reading; no live test.)
2. `notes:` path missing (old releases without `release-notes.json`): TestFlight fails clearly, since Beta App Review needs a changelog; production submits without What's New. (Task 1 dry run.)
3. A malformed tag (`2026.11.2`, `v2026.11`): `tag_build` raises "Tag must look like vYYYY.MM.N". (Task 1 dry run.)
4. Rerun after production submitted: "Already submitted: WAITING_FOR_REVIEW", exit non-zero, nothing changed. (Task 1, by reading.)
5. iOS failing must not mark Play's run red on the Play job: separate jobs, the run is red but Play's steps completed. (Task 2.)

---

### Task 1: The `promote` lane

**Files:**
- Modify: `ios/fastlane/Fastfile` (header comment, private lanes `tag_build`, `review_details`, lane `promote`)

**Interfaces:**
- Consumes: `api_key` (existing private lane), `metadata/`, `rating_config.json`.
- Produces: `bundle exec fastlane promote tag:<vYYYY.MM.N> track:<alpha|beta|production> notes:<release-notes.json> [dry_run:true]`.

- [x] **Step 1: `tag_build(tag)`** → `[version_string, build_number]`, regex `\Av(\d{4})\.(\d{1,2})\.(\d+)\z`, error "Tag must look like vYYYY.MM.N: '<tag>'".
- [x] **Step 2: Dry run first.** `promote` reads options, `tag_build`, loads notes if the file exists, prints `Would send <version> (<build>) to <target>` with the notes per language, and `next if options[:dry_run]`. Run: `cd ios && bundle exec fastlane promote tag:v2026.11.2 track:beta notes:<downloaded release-notes.json> dry_run:true` → `2026.11.2 (20261102) to External testers`. With `tag:2026.11.2` → the tag error. With a missing notes path and `track:beta` → "TestFlight needs release notes".
- [x] **Step 3: alpha/beta.** `api_key`; `upload_to_testflight(distribute_only: true, app_version:, build_number:, distribute_external: true, groups: ['External testers'], notify_external_testers: true, changelog: notes['en-US'])`. Wrap the build lookup error as "Build <n> (<version>) is not on TestFlight".
- [x] **Step 4: production.** `api_key`; find the app; "Already submitted" check (ruling above) → `UI.user_error!`; first-version check; `deliver(app_version:, build_number:, skip_binary_upload: true, skip_screenshots: true, metadata_path:, app_rating_config_path:, app_review_information: review_details, release_notes: (first ? nil : notes), submit_for_review: true, automatic_release: true, phased_release: false, run_precheck_before_submit: false, force: true, submission_information: { content_rights_contains_third_party_content: false, export_compliance_uses_encryption: false })`. Move `upload_listing`'s review hash into `review_details` and use it in both lanes.
- [x] **Step 5: Re-run Step 2's dry runs and `upload_listing ... dry_run:true`** (unchanged behaviour). Commit: `ci(ios): promote lane for TestFlight and the App Store`.

### Task 2: The `ios` job and the docs

**Files:**
- Modify: `.github/workflows/promote.yaml`, `README.md` → Releases (Promote section)

- [x] **Step 1: Rename the job `promote` → `play`** (same steps) and add `ios`: `macos-latest`, `timeout-minutes: 20`, checkout `main`, `ruby/setup-ruby` in `ios`, fetch `release-notes.json` as the Play job does, `bundle exec fastlane promote tag:"$TAG" track:"$TRACK" notes:"$GITHUB_WORKSPACE/release-notes.json"` with the `ASC_*` secrets. No `needs` between the two. The header comment says what each track means on each store.
- [x] **Step 2: README → Promote:** per track, Play vs iOS; production on iOS goes live after Apple's review (hours to days), automatically; the GitHub release turns final at Play production; by hand once: the "External testers" group and Pricing and Availability (free).
- [x] **Step 3: Check:** `ruby -ryaml -e 'YAML.load_file(".github/workflows/promote.yaml")'`; `flutter analyze`; `flutter test test/store_listing_test.dart`. Commit: `ci(release): promote iOS builds with Play`.

### Task 3: Ship

- [ ] **Step 1:** Whole-branch review; PR `ci(ios): promote iOS builds to external TestFlight and the App Store`, `Part of #399` (it closes after Step 3); CI green; merge.
- [ ] **Step 2, Paul:** create the "External testers" group, set Pricing and Availability to free.
- [ ] **Step 3:** `gh workflow run Promote -f tag=v2026.11.2 -f track=beta`, watch both jobs; the build shows in the group "Waiting for Review" (Beta App Review). Production is Paul's call, later.
