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

Those project settings (email confirmations, minimum password length, the Google
provider, Site URL, redirect URLs) live in `supabase/config.toml`, not in the
dashboard. Sign in with Apple is not wired up — it needs a paid Apple Developer
account (issue #22).

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

After a PR merges, apply it to the hosted project (one-off `supabase login` and
`supabase link --project-ref cskjeqspecsyqioietrj` first):

```bash
supabase db push                            # pending migrations
supabase functions deploy                   # every function in supabase/functions/
supabase config diff                        # config.toml vs hosted, read-only
SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=... supabase config push
```

`config push` shows each change and asks before writing it. `config.toml`
references the Google client secret through that variable, so set it before
pushing (it is in Google Cloud Console, never in this repo).

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
the web:

```bash
flutter test test/store_screenshots_test.dart --dart-define=STORE_SCREENSHOTS=true
```

They land in `build/store/<device>/<language>/`, numbered in listing order, and
every release attaches them as `store-screenshots.zip`. Upload them by hand too.
The devices and screens are in the test.

## Translations

English lives in `lib/l10n/app_en.arb` and is the source of truth. Every other
language is machine-translated by Google Gemini (`tool/translate.dart`) and
arrives as a pull request to review.

- **Adding a string:** add the key *and its description* to `app_en.arb`. The
  description is what the translator reads — a key without one gets translated
  blind. Merging to `main` runs the *l10n sync* workflow, which opens (or
  updates) one pull request, `chore/l10n-sync`, with every language. Review the
  copy and merge.
- **What gets translated:** only keys missing from a language, or whose English
  changed since they were translated. `lib/l10n/translation_sources.json`
  records the English each translation was made from. Keys removed from English
  are removed everywhere.
- **Fixing a translation:** edit the translated `.arb` directly, in the sync
  pull request or any other. The next run leaves it alone until its English
  changes.
- **Adding a language:** commit `lib/l10n/app_xx.arb` containing only
  `{"@@locale": "xx"}`, then run *l10n sync* (or wait for Monday). The app
  supports it with no code change — `supportedLocales` is generated from the
  files present.
- **Register:** Loomia is an assistant, so it speaks informally wherever the
  language distinguishes — French says *tu* (*ton, ta, tes*, « Consulte »),
  never *vous*. The rule is in the prompt in `tool/translate.dart`;
  `test/l10n/french_register_test.dart` fails a sync that slips back to *vous*.
  Imperatives have no marker word, so check them in review.

The workflow needs the `GEMINI_API_KEY` repository secret: a free-tier key from
[Google AI Studio](https://aistudio.google.com/apikey), no billing. Locally:
`GEMINI_API_KEY=... dart run tool/translate.dart`. The models are a list at
the top of `tool/gemini.dart`. The free tier is rate-limited and often
overloaded — a 429, 500 or 503 is retried on the next model in the list for
about two minutes, then the run fails; re-run it later. Google may use free-tier requests to
improve its products, which is acceptable because the input is only public UI
copy.

Generated Dart (`lib/l10n/app_localizations*.dart`) is not committed. Run
`flutter gen-l10n` after changing an ARB file, or just `flutter run`.

## Releases

release-please keeps a Release PR open on `main`. Merging it tags the version,
builds a signed AAB and APK, publishes a GitHub **pre-release** with the APK and
web build, and uploads the AAB to Play **internal testing**
(`.github/workflows/release.yaml`).

Every release starts there. To ship one further, promote the same build — no
rebuild:

```bash
gh workflow run Promote -f tag=v0.2.0 -f track=alpha        # closed testing
gh workflow run Promote -f tag=v0.2.0 -f track=production   # also marks the GitHub release final
```

Promote from the workflow only, never from the Play Console, so the GitHub
pre-release flags keep matching what users get. Production needs a closed test
first on a personal developer account (12 testers opted in for 14 days).

versionCode comes from the tag: `major*10000 + minor*100 + patch`.

### Web

The web build follows the same path on Cloudflare (`wrangler.jsonc`, a Worker
with static assets only). Each release uploads a version tagged with the
release, served at the `internal` preview URL
(`https://internal-loomia.<account>.workers.dev`) but not live. Promote to
`production` makes that exact version live on `loomia.thevenot.me`. Rolling
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
gh release download v0.2.0 -p release-notes.json   # edit it, then
gh release upload v0.2.0 release-notes.json --clobber
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
   template, limited to your account and the `thevenot.me` zone, then:

   ```bash
   gh secret set CLOUDFLARE_API_TOKEN
   gh secret set CLOUDFLARE_ACCOUNT_ID   # dashboard → Workers & Pages, right column
   ```

   The Worker must exist before a version can be uploaded to it, so deploy once
   by hand: `flutter build web --release && npx wrangler deploy`. Then in
   Workers & Pages → `loomia` → *Settings → Domains & Routes*, add the custom
   domain `loomia.thevenot.me` (Cloudflare creates the DNS record and
   certificate). Moving to another domain later: add the new custom domain,
   update `site_url` and `additional_redirect_urls` in `supabase/config.toml`,
   remove the old one.

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
