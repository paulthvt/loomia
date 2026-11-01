# App Store listing — design

Issue: #398, epic #400. No new UI: no Figma section.

## Intent

Everything App Review needs besides the build: the store text in English and
French, category, age rating, App Privacy answers, review notes with a demo
account, and iPhone and iPad screenshots. Kept in the repo and sent to App
Store Connect by one manual workflow, so the listing is reviewed in PRs like
code and #399's `promote` lane can reuse the same files.

Success: App Store Connect shows a complete listing for the version waiting
in "Prepare for Submission", with nothing left to type there except the App
Privacy answers (by hand, once, from this spec).

Anti-goals: anything that reads as an MLM tool (rank, recruit, PV, essential
oils, income); a listing that changes on every release without anyone
deciding it; a workflow that needs Paul's Apple ID or Mac.

## Approaches

| Approach | Trade-off | |
| --- | --- | --- |
| Manual "Store listing" workflow (`workflow_dispatch`, macOS) running `fastlane upload_listing` with the App Store Connect API key | Nothing local; run only when the listing changes. ~10 min of macOS runner per run. | **Chosen** |
| Same lane, run locally only | Needs Ruby, the bundle and the `.p8` on the Mac each time; the key should stay in the password manager. | |
| Upload at every release from `release.yaml` | Always in sync, but every release touches the live listing, can fail while a version is in review, and blurs #399's "deliberate step to reach users". | |

## Decisions

| Question | Decision |
| --- | --- |
| Where the listing lives | `ios/fastlane/metadata/`, fastlane `deliver`'s layout: `en-US/` and `fr-FR/` text files, plus `review_information/`, `primary_category.txt`, `secondary_category.txt`, `copyright.txt`. |
| Text source | Written fresh from the site's copy (getloomia.app), not from the Play listing, which stays in Play Console. |
| Category | Business; secondary Productivity (`BUSINESS`, `PRODUCTIVITY`, the identifiers `deliver` expects). |
| Age rating | Every content question "none", no unrestricted web access, no gambling, no user-generated content shared with others: 4+. `ios/fastlane/rating_config.json`. |
| Review notes | Contact first name (Paul), last name (Thevenot) and email (`hello@getloomia.app`) and how to reach the sample data, in `review_information/`. The demo account email and password are the secrets `ASC_DEMO_USER` and `ASC_DEMO_PASSWORD`, the contact phone `ASC_REVIEW_PHONE` (the repo is public). |
| App Privacy labels | By hand in App Store Connect, once, from "App Privacy" below. fastlane's upload for them needs an Apple ID session, not the API key. |
| iPad | The app ships on iPad (`TARGETED_DEVICE_FAMILY = "1,2"`), so Apple requires iPad screenshots. |
| Screenshots | Two new devices in `test/store_screenshots_test.dart`: `iphone-6.9` (440×956 @3x = 1320×2868, bottom bar) and `ipad-13` (1032×1376 @2x = 2064×2752, tablet layout). Same four screens, every app language. Apple scales them down for the smaller devices. |
| Sample data | Neutral for every store, Play included: no essential oils, lavender, peppermint, PV, ranks or "New member training". Events become "Product evening", "Spring open house", "Team catch-up". The Play screenshots change at the next release. |
| Which screenshots get uploaded | The `store-screenshots.zip` of a release (workflow input `tag`), so the images match a shipped build. The lane maps `iphone-6.9` and `ipad-13`, `en` → `en-US`, `fr` → `fr-FR`, and replaces what's in App Store Connect. |
| Which version | Whatever version App Store Connect has in an editable state ("Prepare for Submission"; creating the app made one, `1.0`). The lane looks it up (`Spaceship::ConnectAPI` `get_edit_app_store_version`) and passes its string to `deliver` as `app_version`, so a version string that doesn't match a release never breaks a run. No editable version: the lane stops with "Create a version in App Store Connect first". Renaming it to the release's `2026.x.y` is #399's job when it attaches a build. Version-level text goes there; app-level text (name, subtitle, privacy URL) applies to the app. |
| API key | The existing `ASC_KEY_*` key has the App Manager role (#397), which can edit metadata, categories, age rating and review details. |
| Never | The lane never submits for review and never touches a build or a price. That is #399. |
| Checks | A plain Dart test, `test/store_listing_test.dart`, run by the normal CI: Apple's limits (name and subtitle ≤ 30, keywords ≤ 100 and comma-separated, promotional text ≤ 170, description ≤ 4000), every file present in both languages, French without *vous/votre/vos*, no MLM words (the site's list), URLs on `getloomia.app`. |

## The listing

URLs, same for both languages: support `https://getloomia.app/support`
(`/fr/support` in French), marketing `https://getloomia.app` (`/fr`),
privacy `https://getloomia.app/privacy` (`/fr/privacy`).

English, starting point (the builder writes the description in the same
voice, held to `docs/design/design-principles.md`):

- Name: **Loomia**
- Subtitle: **Know who to get back to today** (30)
- Promotional text: **Your contacts, follow-ups and plans in one calm place, so nobody falls through the cracks.**
- Keywords: follow-up, contacts, CRM, customers, reminders, relationships, small business, planner, clients (≤ 100)
- Description: what it is for (people running a business on relationships),
  then Today, Contacts, Calendar, the month plan, privacy (no ads, data in the
  EU, delete everything from Settings), and that it works on phone, tablet
  and the web with one account.

French, same structure, *tu*: subtitle « Sache qui recontacter aujourd’hui »
(≤ 30, shorten if needed), the site's French sentence as promotional text.

Copyright: `2026 Paul Thevenot`.

## App Privacy

Entered by hand, from the app as checked on 2026-10-30 (see the marketing
site spec). Tracking: **no**. Every type below is **linked to the user**,
purpose **App Functionality** unless said otherwise:

| Apple category | Type | Why |
| --- | --- | --- |
| Contact Info | Email address, Name | The account. |
| Contacts | Contacts | People the user picks from the address book. |
| User Content | Photos | Profile and contact photos the user adds. |
| User Content | Other user content | Notes, history, events, tasks, goals. |
| Identifiers | User ID | Account id, also on error reports. |
| Diagnostics | Crash data, Other diagnostic data | Sentry; purpose App Functionality. |

Not collected: location, health, financial info, browsing or search history,
usage data, purchases, device ID (the push token is not a device identifier
in Apple's sense). Revisit with #105 (purchases) and #114.

## Workflow

`.github/workflows/store-listing.yaml`, `workflow_dispatch` with one input, `tag`
(required), `macos-latest`, the existing secrets
`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8`, plus `ASC_DEMO_USER`, `ASC_DEMO_PASSWORD` and
`ASC_REVIEW_PHONE`. Steps: check out `main` (the listing's current text, which
can change without a release), download the tag's `store-screenshots.zip`,
`bundle exec fastlane upload_listing screenshots:<dir>`. The lane calls `deliver` with
`skip_binary_upload`, `submit_for_review: false`, `overwrite_screenshots`,
`run_precheck_before_submit: false`, `force: true`.

README → Releases → iOS gains the command and when to run it.

## By hand, once

1. App Privacy answers (above) in App Store Connect.
2. `gh secret set` for `ASC_DEMO_USER`, `ASC_DEMO_PASSWORD` and `ASC_REVIEW_PHONE`.
3. Run the workflow on the latest tag, then check the listing in App Store
   Connect.

## Not now

Play listing in the repo (`supply`), screenshots with captions or device
frames, preview videos, more languages, in-app events.

## Calls made while writing, for review

- The lane edits whichever version is editable instead of taking a version
  input: the version string only has to match a build at submission (#399).
- Review contact email `hello@getloomia.app`, not a personal address.
- `rating_config.json` follows the key schema of fastlane 2.241.2's
  `app_rating_config_path`; the builder checks it against that version.
- Content rights and export compliance are submission-time fields: #399
  (`ITSAppUsesNonExemptEncryption` is already `false` in `Info.plist`, #397).
