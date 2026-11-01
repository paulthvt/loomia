# Invite links open the app — design

Issue: [#440](https://github.com/paulthvt/loomia/issues/440), part of
[#420](https://github.com/paulthvt/loomia/issues/420). Builds on goal sharing
(`2026-10-31-goal-sharing-design.md`, #147). Found while testing #424.

## Intent

A mentor sends an invite link. When the member taps it on their phone, the
web app opens, and they have to sign in again there, even though Loomia is
installed and they're already signed in. The link should open the app
straight onto the invite, on Android and on iOS. Without the app installed,
it keeps opening the web page, as today.

## Goals

- **The app opens on tap.** On a phone with Loomia installed, tapping
  `https://app.getloomia.app/invite/<code>` opens the app on the accept screen
  with the code filled in. Signed out, the app shows sign-in first, as the
  web page does today.
- **The same link works everywhere.** It opens the web app on a computer, or
  on a phone without Loomia.
- **Invites already sent keep working.** Links of the form
  `https://app.getloomia.app/#/invite/<code>`, sent by #419 and #424, still
  reach the invite.

## Non-goals

- Other deep links: a contact, a task. The same mechanism allows them later.
- A store fallback page ("Get the app") for phones without Loomia.
- Deferred deep links (install, then land on the invite).

## Anti-goals

- **Web sign-in keeps working.** Sign-in with email, Google and Apple, email
  confirmation and password reset on the web must not break.
- **The app doesn't open for every URL.** Only `/invite/…` opens it. The
  rest of `app.getloomia.app` stays the web app, even on a phone with
  Loomia.

## How it works

### Clean URLs on the web

- The web app switches from `#` URLs to path URLs, with
  `usePathUrlStrategy()` from `flutter_web_plugins`, which is in the SDK.
  App Links on Android and universal links on iOS match paths only. They
  can't see anything after `#`.
- **Hosting is already ready.** `wrangler.jsonc` serves `index.html` for any
  unknown path (`not_found_handling: "single-page-application"`).
- **Old links.** At the very start of `main`, before
  `Supabase.initialize` reads the URL and before the router starts, the web app checks whether the
  URL has a `#` fragment that starts with `/`. If so, it replaces the URL
  with that path, using `replaceState` so that Back doesn't return to it.
  That covers `/#/invite/X` and any other old bookmark.
- **The invite link** becomes
  `https://app.getloomia.app${Routes.inviteLocation(code)}`, without `#`.
  The invite sheet's copied link and displayed link both change, and its
  tests with them.
- **Web sign-in.** Today the redirect is `Uri.base.origin`, and Supabase adds
  `?code=` for PKCE. That already sits before any `#`, so it isn't affected.
  The builder verifies each flow on the preview URL: email confirm, password
  reset, Google, Apple.

### Android App Links

- `web/.well-known/assetlinks.json` declares the package `app.loomia` and two
  SHA-256 fingerprints, both given by the user (Play Console → Protected
  with Play → Play Store protection → Play App Signing):
  - the Play app signing key:
    `E3:B6:39:FC:A3:7E:09:E3:4F:82:44:22:A4:15:75:B0:91:E4:63:88:C8:FA:87:A1:6F:F2:BB:09:61:B2:6D:07`
  - the upload key, so that sideloaded builds verify too:
    `13:40:11:27:F6:6D:08:DA:E8:91:C7:62:AE:32:11:9F:80:F8:25:57:86:9D:4C:CF:31:D0:CD:BD:F4:A6:BA:1D`
- `AndroidManifest.xml` gets a new intent filter on the main activity:
  `android:autoVerify="true"`, `VIEW`, `DEFAULT` and `BROWSABLE`, with
  `https`, host `app.getloomia.app` and `pathPrefix="/invite/"`.
- **Routing.** Flutter's deep linking is on by default (Flutter 3.27 and
  later), so the path reaches go_router, which already has
  `/invite/:code` (`InviteLinkPage`). The existing
  `io.supabase.loomia://login-callback/` filter stays as it is.

### iOS universal links

- `web/.well-known/apple-app-site-association` (JSON, no file extension):

  ```json
  {"applinks": {"details": [{"appIDs": ["378X654D2A.app.loomia"],
    "components": [{"/": "/invite/*"}]}]}}
  ```

- `web/_headers` serves it with `Content-Type: application/json`.
- `ios/Runner/Runner.entitlements` gets
  `com.apple.developer.associated-domains = ["applinks:app.getloomia.app"]`.
- **One entitlements file.** `Runner.entitlements` serves both Debug and
  Release, and the new key has the same value in both, so no second file is
  needed.
- **Done by hand by the user:** turn on **Associated Domains** for the App ID
  `app.loomia` in the Apple Developer portal, regenerate the App Store
  distribution provisioning profile, and replace the CI secret
  `IOS_APPSTORE_PROFILE`, which ios/fastlane's `signing` lane reads. Until
  then, an iOS build with the entitlement fails to sign. **Order:** the
  portal and profile first, then merge.
- **TestFlight is enough.** Universal links are checked against the domain's
  file, not against the store channel. A TestFlight build with the
  entitlement opens links once the file is live on `app.getloomia.app`. No
  App Store submission is needed.

### Hosting the two files

- **The plan's first step, before anything else is built:** check that the
  files reach Cloudflare. Flutter copies `web/` into `build/web`, and
  Cloudflare serves `build/web`. The builder must verify both of these:
  - `.well-known/` ends up in `build/web` (it's a dot directory);
  - wrangler uploads it (its asset upload may skip dot directories; an
    `.assetsignore` or a copy step fixes that).
- **Check on the preview URL:**
  - `https://<preview>/.well-known/assetlinks.json` returns the JSON;
  - `apple-app-site-association` returns it with `application/json`.
- **Live, without releasing the mobile apps** (the user doesn't want the
  stores live yet). Android and iOS read the files from the link's own
  domain, so a preview URL can't stand in. `promote.yaml` gains a
  **`web`** choice for `track`. With it, the workflow makes that tag's web
  version live on `app.getloomia.app` and skips the Play move and the
  "mark final" step; `alpha`, `beta` and `production` behave as before.
  After merge and release, the user runs
  `gh workflow run Promote -f tag=<tag> -f track=web`. Universal and App Links are only verified against
  the live domain. On Android, verification runs at install and update. On
  iOS, through Apple's CDN, which can lag for hours.

## Constraints

- No new dependency. `flutter_web_plugins` is part of the Flutter SDK; add
  it to `pubspec.yaml` as `sdk: flutter`, with the reason in a comment.
- Routes come from `routes.dart`, with no path literal in widgets.
- Tests:
  - the invite link built without `#`;
  - the old-fragment rewrite as a pure function: `/#/invite/AB` →
    `/invite/AB`, `/#/` → `/`, no fragment → unchanged, a fragment that
    isn't a path (`#access_token=…`) → unchanged;
  - the manifest and entitlements contents (string checks are enough).
- This changes how web URLs look. Note it in the PR, and that sign-in was
  checked on the preview.

## Left to the builder

- Where the fragment rewrite lives (`main.dart` before `runApp`, or a web-only
  helper behind a conditional import).
- Whether to also add the upload key's fingerprint (recommended, for
  sideloaded and testing builds).
- How `.well-known` reaches the upload, if the first-step check shows it
  doesn't.

## Needs from the user

1. ~~The SHA-256 fingerprints~~: given, see Android App Links.
2. Associated Domains turned on for `app.loomia`, a regenerated distribution
   profile, and the CI secret updated.
3. After merge and release, a web-only promote
   (`gh workflow run Promote -f tag=<tag> -f track=web`) so the files are
   live on `app.getloomia.app`.
