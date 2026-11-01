# Loomia

A cross-platform productivity app for people who run their business on
relationships: contacts, follow-ups, customers, prospects, team activity and
personal goals — all pointed at one question: **"What should I do today?"**

Current state: design system, auth (Supabase), localisation (EN/FR) and a Today
screen on sample data. No product data model yet.

## Platforms

| Platform | Status |
| --- | --- |
| Android | supported |
| iOS | supported |
| Web | supported, treated as a first-class responsive desktop app |

## Requirements

- Flutter 3.47+ / Dart 3.13+

## Running

```bash
flutter pub get
flutter run                 # current device
flutter run -d chrome       # web
```

### Auth and Supabase

The Supabase project URL and publishable key are committed in
`lib/core/supabase/supabase_config.dart` — the publishable key is public by
design and Row Level Security is the boundary. Nothing to configure locally.

Email confirmation, password recovery and Google sign-in return to
`io.supabase.loomia://login-callback/`. On web there is no custom scheme, so the
project's **Site URL** is where those links land: set it to the origin you
develop on and run web on a fixed port (`flutter run -d chrome --web-port 5000`).
Both that origin and the custom scheme must be listed under allowed redirect
URLs, or Supabase silently falls back to the Site URL.

Those project settings (email confirmations, minimum password length, the
Google and Apple providers, Site URL, redirect URLs) live in
`supabase/config.toml`, not in the dashboard.

### Sign in with Apple

The web flow on every platform, like Google (#22): Supabase's callback,
`https://cskjeqspecsyqioietrj.supabase.co/auth/v1/callback`, behind the
Services ID `app.loomia.signin`. Apple sends no name this way, so the first run
asks for one. Everything is under team `378X654D2A`.

One-time setup, in [Certificates, IDs & Profiles](https://developer.apple.com/account/resources/identifiers/list):

1. Identifiers → `app.loomia` → tick **Sign In with Apple** → Save. Don't add
   the entitlement to `Runner.entitlements`: the web flow doesn't use it.
   Changing the App ID can invalidate the App Store profile: if Profiles shows
   it *Invalid*, regenerate it and replace `IOS_APPSTORE_PROFILE` (iOS below),
   or the next TestFlight upload fails at signing.
2. Identifiers → **+** → Services IDs → `app.loomia.signin`, then
   **Configure** Sign In with Apple: primary App ID `app.loomia`, domain
   `cskjeqspecsyqioietrj.supabase.co`, return URL the callback above.
3. Keys → **+** → Sign In with Apple, configured with `app.loomia`. Download
   the `.p8` (only once) into the password manager and note its Key ID.
   Never commit it, never a GitHub secret.

The secret Supabase needs is a JWT signed with that key, valid 180 days at
most. Generate it, then store its expiry date for the weekly
"Apple secret expiry" workflow, which fails 30 days before:

```bash
cd ios && bundle exec fastlane apple_auth_secret key:<path/to/AuthKey.p8> key_id:<Key ID>
# prints the secret, then the gh variable set APPLE_AUTH_SECRET_EXPIRES … line to run
```

Then push it with `config push` (next section), both provider secrets set.
Every 6 months, when the workflow warns: the lane again, the printed
`gh variable set`, and `config push`.

### Database and project config

Needs the [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started)
and a running Docker (or Podman) engine.

```bash
supabase db start                           # local Postgres with every migration applied
supabase migration new <name>               # new file in supabase/migrations/
supabase db reset                           # re-apply everything from scratch
```

The app always talks to the hosted project; the local database is for writing
and testing migrations.

Migrations reach the hosted project by themselves: on every push to `main`,
the Release workflow's `database` job runs `supabase db push --dry-run`, then
`supabase db push`, before any build (#394). It needs two repository secrets:
`SUPABASE_ACCESS_TOKEN` (a personal access token, Account → Access Tokens)
and `SUPABASE_DB_PASSWORD` (the project's database password). The
"Migration guard" check fails a PR whose new migration would break the
released app (a drop, a rename, `set not null`, a column type, `truncate`,
`delete from`) or that edits an applied one; the `breaking-migration` label
lets the planned second step of a two-release change through.

The rest stays by hand after a merge (one-off `supabase login` and
`supabase link --project-ref cskjeqspecsyqioietrj` first):

```bash
supabase functions deploy                   # every function in supabase/functions/
supabase config diff                        # config.toml vs hosted, read-only
SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=... SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=... supabase config push
```

`config push` shows each change and asks before writing it. `config.toml`
references both provider secrets through those variables, so set them before
pushing: Google's is in Google Cloud Console, Apple's comes from
`fastlane apple_auth_secret` (Sign in with Apple above); neither is in this repo.

### Push notifications

Android and iOS only, through Firebase Cloud Messaging. Firebase is optional:
without its two config files the app builds and runs, and push is off. Neither
file is committed (`.gitignore`).

One-time setup:

1. In the [Firebase console](https://console.firebase.google.com), a project
   with an Android app `app.loomia` and an iOS app `app.loomia`.
2. Download `google-services.json` to `android/app/` and
   `GoogleService-Info.plist` to `ios/Runner/`.
3. iOS: in the Apple Developer account, an APNs auth key (`.p8`), uploaded to
   Firebase → Project settings → Cloud Messaging. The Push Notifications
   capability is already in `ios/Runner/Runner.entitlements`.
4. Release builds: `gh secret set GOOGLE_SERVICES_JSON < android/app/google-services.json`.

Checking a phone: sign in on a build with the files, tap Turn on on Today's
card (or Settings → Notifications) and allow notifications, then in Studio
`select platform, locale, last_seen_at from device_token`. A test push from
Firebase → Messaging to that token, tapped, opens Today.

The push copy is the `push*` keys of the ARB files. The phone renders it, from
`android/app/src/main/res/values/push_strings.xml` and
`ios/Runner/Localizable.strings`. Both are generated by
`dart run tool/push_strings.dart`, run on Weblate's pull request.

The daily summary and the month-end push are sent by the `send-daily-summary`
Edge Function, which pg_cron calls every 15 minutes. After a change to either,
`supabase functions deploy send-daily-summary` once the merge has pushed the
migrations (Release → `database`), from a checkout of up-to-date `main`: the
CLI deploys the code it runs in, and answers "No change found" when that is
an older branch.
Once, on the hosted project:

1. Firebase → Project settings → Service accounts → *Generate new private
   key*, then
   `supabase secrets set FCM_SERVICE_ACCOUNT="$(cat service-account.json)"`
   and delete the file.
2. Dashboard → Project settings → API keys: a new secret key named `cron`.
3. `supabase db push`, `supabase functions deploy send-daily-summary`.
4. In the SQL editor (the values never go in a migration):

   ```sql
   select vault.create_secret(
     'https://<project-ref>.supabase.co/functions/v1/send-daily-summary',
     'send_daily_summary_url');
   select vault.create_secret('sb_secret_…', 'send_daily_summary_key');
   ```

Checking a summary: with a registered phone, set Settings → Notifications to
a quarter hour a few minutes ahead, today selected, have someone due on Today,
and wait for that run. `select * from cron.job_run_details order by start_time
desc limit 5`, `net._http_response` and the function's logs show each run.
`delete from notification_sent where owner_id = '<id>'` to try again the same
day.

### Error reporting

Release builds send uncaught errors to [Sentry](https://sentry.io) (Flutter
project, free plan). The DSN is committed in `lib/main.dart`: it can only send
events. Debug and profile builds send nothing. PII is off: no email, no IP.

Web stack traces are minified until source maps are uploaded (not set up yet).

## Checks

```bash
dart format .
flutter analyze
flutter test
```

### Golden tests

`test/previews_test.dart` renders every `@Preview` and compares it against a PNG
in `test/goldens/`. Pixels are compared on Linux only, so a local `flutter test`
on macOS or Windows never catches a visual change — CI does. The PNGs must come
from CI too: never commit goldens generated on your machine.

When a preview changes on purpose (or a new `@Preview` is added to the test's
list), regenerate from the pushed branch:

```bash
gh workflow run CI --ref <branch> -f update-goldens=true
gh run list --workflow CI --branch <branch> --event workflow_dispatch --limit 1
gh run watch <run-id>
rm test/goldens/*.png   # drop stale files for renamed or removed previews
gh run download <run-id> -n goldens -D test/goldens
```

Open the PNGs and check them before committing — `--update-goldens` accepts
whatever renders. When the PR's CI fails on a golden, the diff images are in the
run's `golden-failures` artifact.

### App icons

Every launcher icon, the favicon and the web icons are rendered from one
geometry by `tool/brand/icons.sh` (needs `rsvg-convert`). Android 8.0+ draws the
same mark as a vector, `drawable/ic_launcher_foreground.xml`; the in-app
wordmark paints it in `lib/core/ui/loomia_wordmark.dart`. Change all three
together — the source is Figma `07 — Loomia logo`, E5b.

The same script writes the Play Store listing images to `store/play/` (512 px
icon, 1024×500 feature graphic). Play has no API for them in this pipeline:
upload them by hand in Play Console → Store listing.

Store screenshots show the whole app — navigation, account button — on a
sample book, in every app language: `phone` (1080×1920), `tablet-7`
(1200×1920) and `tablet-10` (2560×1600) for Play, `desktop` (2880×1800) for
the web, `iphone-6.9` (1320×2868) and `ipad-13` (2064×2752) for the App Store,
uploaded by the Store listing workflow (Releases → iOS):

```bash
flutter test test/store_screenshots_test.dart --dart-define=STORE_SCREENSHOTS=true
```

They land in `build/store/<device>/<language>/`, numbered in listing order, and
every release attaches them as `store-screenshots.zip`. Upload them by hand too.
The devices and screens are in the test.

## Translations

English lives in `lib/l10n/app_en.arb` and is the source of truth. Every other
language is translated in [Weblate](https://weblate.thevenot.me/projects/loomia/)
and arrives as a pull request.

- **Adding a string:** add the key *and its description* to `app_en.arb`. The
  description is what the translator reads — a key without one gets translated
  blind. Weblate picks up the merge to `main` and Gemini translates it, marked
  *Needs editing*. A string needing edit is still written to the ARB, so review
  it before merging.
- **Reviewing:** in Weblate. Approve or fix each string; the glossary and the
  project instructions hold the terms and the tone. Weblate opens (or updates)
  one pull request, `chore(l10n): sync translations`, from `weblate/l10n`.
  `.github/workflows/weblate-pr.yaml` regenerates the push copy on it after
  every Weblate push; merge it when CI is green.
- **Removing or renaming a string:** change the key in `app_en.arb` *and*
  delete the old one from every `app_xx.arb`, in the same pull request —
  `test/l10n/arb_keys_test.dart` fails on a key English no longer has.
  Weblate picks up the change from `main`.
- **Fixing a translation:** in Weblate, not in the ARB. Weblate force-pushes
  `weblate/l10n`, so a commit added there by hand is lost.
- **Adding a language:** in Weblate, *Start new translation*. The app supports
  it with no code change — `supportedLocales` is generated from the files
  present.
- **Register:** Loomia is an assistant, so it speaks informally wherever the
  language distinguishes — French says *tu* (*ton, ta, tes*, « Consulte »),
  never *vous*. The rule is in the Weblate project instructions and the Gemini
  engine's style; `test/l10n/french_register_test.dart` fails a pull request
  that slips back to *vous*. Imperatives have no marker word, so check them in
  review.

Weblate reaches the repository through its GitHub App, installed on this
repository only. `GEMINI_API_KEY` is now used only by the release notes
(`tool/release_notes.dart`): a free-tier key from
[Google AI Studio](https://aistudio.google.com/apikey), no billing. The models
are a list at the top of `tool/gemini.dart`; a 429, 500 or 503 is retried on
the next model for about two minutes.

Generated Dart (`lib/l10n/app_localizations*.dart`) is not committed. Run
`flutter gen-l10n` after changing an ARB file, or just `flutter run`.

## Releases

yeet keeps a Release PR open on `main` (`.yeet.yaml`). Versions are calendar
versions, `YYYY.MM.MICRO`: `2026.10.1` is the first release of October 2026,
tagged `v2026.10.1`. Merging the PR tags the version, builds a signed AAB and
APK, publishes a GitHub **pre-release** with the APK and web build, and uploads
the AAB to Play **internal testing** (`.github/workflows/release.yaml`).
Fastlane does both Play steps, the upload and Promote below
(`android/fastlane/Fastfile`, run from `android/`), with the
`PLAY_SERVICE_ACCOUNT_JSON` secret. To run a lane by hand, set that variable,
then once `bundle config set --local path vendor/bundle && bundle install`
(Homebrew's Ruby can't take the gems itself), and
`bundle exec fastlane promote tag:... track:...`. The same goes for `ios/`.

Every release starts there. To ship one further, promote the same build — no
rebuild:

```bash
gh workflow run Promote -f tag=v2026.10.1 -f track=alpha        # closed testing
gh workflow run Promote -f tag=v2026.10.1 -f track=production   # also marks the GitHub release final
```

Promote from the workflow only, never from the Play Console or App Store
Connect, so the GitHub pre-release flags keep matching what users get.
Production needs a closed test first on a personal developer account (12
testers opted in for 14 days).

The same command moves the iOS build, in its own job (`ios/fastlane/Fastfile`,
lane `promote`), so one store failing leaves the other alone:

| Track | Play | iOS |
| --- | --- | --- |
| `alpha` | closed testing | TestFlight group **External testers** |
| `beta` | open testing | TestFlight group **External testers** |
| `production` | live within hours; web live; GitHub release final | submitted for App Store review, live by itself once approved (hours to days) |

The first build of each version waits for Beta App Review before external
testers get it. Production renames the version open in App Store Connect to
the tag, attaches the build with the listing text from `main` and What's New
from `release-notes.json` (left out on the app's first version), and stops
with "Already submitted" if that version is already in review. Created by hand
once: the **External testers** group (TestFlight → External Testing), and
*Pricing and Availability* (free).

versionCode (and, with iOS, CFBundleVersion) comes from the tag:
`year*10000 + month*100 + micro`, so `v2026.10.1` is `20261001`. Tags before
2026.10 are semver (`0.11.0` is `1100`); `v2026.10.0` is only yeet's starting
point, never a release.

yeet runs as a GitHub App, so the Release PR gets CI (required on `main`): an
App on this account, installed on this repository only, with Contents and Pull
requests read and write and no webhook. Store its client ID and a private key:

```bash
gh variable set YEET_APP_ID --body "<client id>"
gh secret set YEET_APP_PRIVATE_KEY < <app>.private-key.pem
```

### Web

The web build follows the same path on Cloudflare (`wrangler.jsonc`, a Worker
with static assets only). Each release uploads a version tagged with the
release, served at the `internal` preview URL
(`https://internal-loomia.<account>.workers.dev`) but not live. Promote to
`production` makes that exact version live on `app.getloomia.app`. Rolling
back is `npx wrangler rollback`.

Auth links from the preview URL land on the live site: it is not in
`additional_redirect_urls`, so Supabase falls back to the Site URL.

### Release notes

`tool/release_notes.dart` turns the Features, Bug Fixes and Performance entries
of the release body into short store notes in every app language, with one
Gemini call (same `GEMINI_API_KEY`). They are attached to the GitHub release as
`release-notes.json`, at most 500 characters per language (Play's limit), and
that file is the only source: the internal testing upload and every Promote
send the same text. To change the wording, replace the asset before promoting:

```bash
gh release download v2026.10.1 -p release-notes.json   # edit it, then
gh release upload v2026.10.1 release-notes.json --clobber
```

A Gemini failure, or a release with nothing user-facing, ships without notes.

### One-time setup

1. **Upload key.** Keep `upload.jks` and its passwords in a password manager,
   never in the repo. Play App Signing holds the real app key, so a lost upload
   key can be reset from the Play Console.

   ```bash
   keytool -genkeypair -v -keystore upload.jks -alias upload \
     -keyalg RSA -keysize 2048 -validity 10000
   ```

2. **Play Console app.** Create the app with package `app.loomia` (permanent
   once created) and keep Play App Signing on. The API cannot publish the first
   build, so upload one by hand: put the key in `android/` with an
   `android/key.properties` (both git-ignored),

   ```properties
   storeFile=upload.jks
   storePassword=...
   keyAlias=upload
   keyPassword=...
   ```

   run `flutter build appbundle --release --build-number=1`, then upload
   `build/app/outputs/bundle/release/app-release.aab` to **Internal testing** and
   roll it out. Delete both files afterwards.

3. **Service account.** In a Google Cloud project, enable the *Google Play
   Android Developer API*, create a service account and download a JSON key. In
   Play Console → *Users and permissions*, invite its email with release
   permissions (testing tracks and production) on the app.

4. **Secrets.**

   ```bash
   base64 -i upload.jks | gh secret set ANDROID_KEYSTORE_BASE64
   gh secret set ANDROID_KEYSTORE_PASSWORD
   gh secret set ANDROID_KEY_ALIAS --body upload
   gh secret set ANDROID_KEY_PASSWORD
   gh secret set PLAY_SERVICE_ACCOUNT_JSON < service-account.json
   ```

5. **Cloudflare.** Create an API token from the *Edit Cloudflare Workers*
   template, limited to your account and the `getloomia.app` zone, then:

   ```bash
   gh secret set CLOUDFLARE_API_TOKEN
   gh secret set CLOUDFLARE_ACCOUNT_ID   # dashboard → Workers & Pages, right column
   ```

   The Worker must exist before a version can be uploaded to it, so deploy once
   by hand: `flutter build web --release && npx wrangler deploy`.

   The Worker's domains are the `routes` in `wrangler.jsonc`. Releases don't
   apply them; after changing the list, run `npx wrangler triggers deploy`
   (logged in with `npx wrangler login`; it needs a `build/web` folder, even
   an empty one). Cloudflare creates the DNS record and certificate. Moving
   to another domain: add it to `routes` and deploy the triggers, update
   `site_url` and `additional_redirect_urls` in `supabase/config.toml` and
   `supabase config push`, then replace the old domain with a proxied DNS
   record and a 301 Redirect Rule to the new one, path and query kept, so
   links and installed web apps keep working.

### iOS

The `ios` job of the Release workflow sends the same tag, with the same build
number, to **TestFlight**, for internal testers. Notes come from the English
entry of `release-notes.json`. Flutter builds the IPA, and fastlane
(`ios/fastlane/Fastfile`) signs and uploads it. Locally, Xcode's automatic
signing with team `378X654D2A` stays as it is; only CI switches to manual
signing. The PR check `Build ios` compiles without signing.

One-time setup, all in the Loomia team:

1. **App Store Connect API key.** In *Users and Access → Integrations*, create
   a team key with the **App Manager** role. Download the `.p8` (only once):

   ```bash
   gh secret set ASC_KEY_ID --body "<key id>"
   gh secret set ASC_ISSUER_ID --body "<issuer id>"
   base64 -i AuthKey_<key id>.p8 | gh secret set ASC_KEY_P8
   ```

2. **Distribution certificate.** In Xcode → Settings → Accounts → the team →
   *Manage Certificates* → **+** → *Apple Distribution*. Then in Keychain
   Access, export it with its private key as a `.p12` with a password:

   ```bash
   base64 -i distribution.p12 | gh secret set IOS_DISTRIBUTION_P12
   gh secret set IOS_DISTRIBUTION_P12_PASSWORD
   ```

3. **App Store profile.** In the developer portal, under *Profiles* → **+** →
   *App Store Connect*, choose App ID `app.loomia` and the certificate from
   step 2, and download it:

   ```bash
   base64 -i Loomia_App_Store.mobileprovision | gh secret set IOS_APPSTORE_PROFILE
   ```

4. **Firebase,** for push (#275): `gh secret set GOOGLE_SERVICE_INFO_PLIST <
   GoogleService-Info.plist`. Without it, the build has no push.

The certificate and the profile expire after a year. Before then, renew
both (steps 2 and 3) and replace the three secrets; an expired one fails the
`Signing` step and blocks no other platform. The first build of each version
reaches internal testers once Apple has processed it, usually in a few
minutes.

#### Store listing

The App Store listing lives in the repo: text in
`ios/fastlane/metadata/<en-US|fr-FR>/`, review contact and notes in
`metadata/review_information/`, categories and copyright beside them, the age
rating in `ios/fastlane/rating_config.json`. `test/store_listing_test.dart`
checks Apple's length limits, *tu* in French and the no-MLM wording on every
PR. Edit the files, merge, then send them with a release's screenshots:

```bash
gh workflow run "Store listing" -f tag=<tag>
```

It edits the version App Store Connect has open ("Prepare for Submission"),
and never uploads a build or submits for review. Run it after changing the
listing, or after a release whose screenshots should replace the current ones.
Secrets, once: `gh secret set` for `ASC_DEMO_USER` and `ASC_DEMO_PASSWORD`
(the demo account the reviewer signs in with) and `ASC_REVIEW_PHONE` (the
contact Apple calls). The repo is public, so none of them is a file.

**App Privacy** ("nutrition labels") is answered by hand in App Store
Connect: its API needs an Apple ID session, not the key. The answers are in
`docs/superpowers/specs/2026-11-01-app-store-listing-design.md` → App
Privacy; change them when a processor or a stored field changes.

## Tracking work

Work is tracked on the
[Loomia project board](https://github.com/users/paulthvt/projects/2). Every change
starts as an issue there.

1. Pick (or create) an issue on the board — that number is the ticket.
2. Branch off `main`: `feature/<issue>-<slug>`, `fix/<issue>-<slug>`,
   `chore/<issue>-<slug>` — e.g. `feature/21-today-screen`.
3. Open the PR with a Conventional Commit title and fill the **Ticket** section
   with `Closes #<issue>` so merging moves the card to Done.

## Architecture (short version)

```
lib/
  main.dart            # entry point, ProviderScope
  app/                 # app shell: root widget, router, theme
  core/                # cross-feature primitives (layout, constants, utils)
  features/<feature>/  # one folder per product area
```

Inside a feature:

```
features/contacts/
  presentation/   # widgets, screens, view state
  domain/         # entities and business rules
  data/           # repositories, API/DB access, DTOs
```

Layers are created **only when a feature needs them**. A feature that is pure UI
has just `presentation/`.

See [docs/architecture.md](docs/architecture.md) for the reasoning and the
conventions.

## Adding a feature

1. `mkdir -p lib/features/<name>/presentation`
2. Add the screen(s). Read colours/spacing from the theme, never hard-code them.
3. Add the path to `lib/app/router/routes.dart` and a `GoRoute` in
   `lib/app/router/app_router.dart`.
4. Add state with Riverpod providers next to the code that uses them
   (`presentation/` for UI state, `domain/` for business logic).
5. Add `domain/` and `data/` only when there is real logic or I/O.
6. Add tests under `test/features/<name>/`, mirroring the `lib/` path.
