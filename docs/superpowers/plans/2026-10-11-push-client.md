# Push client Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A signed-in phone with notifications allowed has its FCM token in `device_token`, with the app's language. A push opens Today. The push copy is ARB keys that the OS renders from generated native strings. No UI, no permission prompt (#268).

**Architecture:** `firebase_core` + `firebase_messaging` behind one `Push` class in `features/notifications/data/`. Firebase is optional at build and run time: without its config files the app builds, and `Push` is a no-op. `PushScope` wraps the shell, registers with the resolved locale, and routes taps. `register_device` (security definer) moves a token between accounts.

**Tech Stack:** Flutter 3.47 (`material_ui`), `flutter_riverpod` 3, `supabase_flutter` 2, `firebase_core` 4.15, `firebase_messaging` 16.7, Google services Gradle plugin 4.5.0, pgTAP.

**Spec:** `docs/superpowers/specs/2026-10-11-notifications-design.md` §1 `device_token`, §3, §5. Figma: [Notifications — #267](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=311-6975) (lock screen frames only).

## Global Constraints

- **Dart imports:** `package:loomia/...`; Material from `package:material_ui/material_ui.dart`.
- **Copy:** English only in `lib/l10n/app_en.arb`, with a description.
- **Quality gate per task:** `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`; SQL tasks also `supabase test db`.
- **Branch:** `feature/268-push-client` off `main`. PR body `Closes #268`. The local `pubspec.lock` mirror drift is stashed; dependencies resolve against pub.dev (`PUB_HOSTED_URL=https://pub.dev`).
- **Never commit** `google-services.json`, `GoogleService-Info.plist`, `lib/firebase_options.dart`.

## Rulings made while planning

- **No `firebase_options.dart`, no FlutterFire CLI.** `Firebase.initializeApp()` without options reads the native files. A failure (no file, web, tests) means no push, logged at INFO.
- **The native files are optional.** Android applies the Google services plugin only when `android/app/google-services.json` exists. iOS copies `ios/Runner/GoogleService-Info.plist` into the bundle in a build phase, when it exists. CI and fresh clones build without Firebase.
- **Sign-out deletes the FCM token on the device**, not the row: the session is already gone when the account turns null, so RLS would refuse the delete. FCM then answers UNREGISTERED and the sender drops the row (#269). So `device_token` has no client grant; `register_device` is the only way in. Spec updated.
- **The language is `Localizations.localeOf(context)`**: the user's choice, else the device's, already resolved by `MaterialApp`.
- **Push only when allowed.** `register` reads `getNotificationSettings()` and does nothing unless authorised or provisional. Android below 13 counts as authorised.
- **iOS strings at the bundle root** (`ios/Runner/Localizable.strings`, not in an `.lproj`): every language is in it, keys suffixed. Verified on device with the first test push (#269).
- **Android small icon** `ic_notification`: the launcher foreground's two white paths, refit to 24 dp. Without it Android draws the colour launcher icon as a white square.
- **A literal `%` is `%%`** in both generated files: the sender always passes `loc_args`, so the OS always formats.

## Review Focus

1. A token is registered only when notifications are allowed, and moves to the account that registered it last. Pinned by `device_token_test.sql`.
2. The app builds and runs with no Firebase files. Pinned by CI's `apk` and `web` builds and by `flutter test`.
3. Generated strings match the ARB files. Pinned by `push_strings_test.dart`.

---

### Task 1: `device_token` and `register_device`

**Files:**
- Create: `supabase/migrations/<ts>_device_tokens.sql`, `supabase/tests/device_token_test.sql`

- [x] **Step 1: Failing test.** pgTAP: as user A, `register_device('t1','android','fr')` makes one row owned by A with locale `fr`; again as B moves it to B with `ios`/`en`, still one row (`now()` is fixed inside the test's transaction, so `last_seen_at` is not compared); a call without a user raises `42501`; `authenticated` cannot insert or delete `device_token` directly; blank token and locale `'french'` raise `23514`.
- [x] **Step 2: Migration.** Enum `device_platform ('android','ios')`. Table per spec §1 (`token text primary key check (length(token) between 1 and 4096)`, `locale text not null check (locale ~ '^[a-z]{2,3}$')`), index on `owner_id`. RLS, `device_token_select_own` policy, `revoke all … from anon, authenticated`, no grant. `register_device(p_token text, p_platform device_platform, p_locale text) returns void`, `security definer`, `search_path = ''`, raises `42501` when `auth.uid()` is null, upserts on `token` setting owner, platform, locale, `last_seen_at = now()`. Execute: revoke from public, anon; grant to authenticated.
- [x] **Step 3:** `supabase db reset && supabase test db`, `supabase db lint --fail-on error`.

### Task 2: Push strings from the ARB files

**Files:**
- Create: `tool/push_strings.dart`, `test/tool/push_strings_test.dart`, `android/app/src/main/res/values/push_strings.xml`, `ios/Runner/Localizable.strings`
- Modify: `lib/l10n/app_en.arb`, `ios/Runner.xcodeproj/project.pbxproj`, `.github/workflows/l10n-sync.yaml`

- [x] **Step 1: Copy.** `pushSummaryBody`: `{count, plural, =1{One person is worth a message today} other{{count} people are worth a message today}}`, `count` an `int` placeholder, described as the daily summary's lock-screen line (no names; the OS renders it from the native strings).
- [x] **Step 2: Failing tests.** `pushStrings({'en': arb, 'fr': arb})` → entries `push_summary_body_one_en`, `push_summary_body_other_en` with `{count}` → arg 1; a plain key gets no plural suffix; `toAndroidXml` escapes `'`, `"`, `&`, `<`, `%` and writes `%1$s`; `toIosStrings` escapes `"`, `\` and `%` and writes `%1$@`; an unsupported plural case (`=0`, `few`) throws; the committed files equal the generator's output for the committed ARB files.
- [x] **Step 3: Implement** `tool/push_strings.dart`: reads `lib/l10n/app_*.arb`, keeps keys starting with `push`, splits a whole-message plural into `one` (`=1`, `one`) and `other`, maps placeholders to positions in `@key.placeholders` order, writes both files with a "Generated by tool/push_strings.dart" header. `main` writes the files.
- [x] **Step 4:** `dart run tool/push_strings.dart`. Add `Localizable.strings` to the Runner group and Resources phase in `project.pbxproj`.
- [x] **Step 5:** l10n sync runs `dart run tool/push_strings.dart` after translate, and its `add-paths` gain both generated files.
- [x] **Step 6:** Quality gate.

### Task 3: Firebase on Android and iOS

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock`, `android/settings.gradle.kts`, `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `ios/Runner.xcodeproj/project.pbxproj`, `.gitignore`, `.github/workflows/release.yaml`
- Create: `android/app/src/main/res/drawable/ic_notification.xml`, `ios/Runner/Runner.entitlements`

- [x] **Step 1:** `PUB_HOSTED_URL=https://pub.dev flutter pub add firebase_core:^4.15.0 firebase_messaging:^16.7.0`, each with a pubspec comment (push for the daily summary, #268; no Auth or Firestore).
- [x] **Step 2: Android.** `com.google.gms.google-services` 4.5.0 `apply false` in settings; applied in the app module only if `google-services.json` exists. Manifest meta-data `com.google.firebase.messaging.default_notification_icon` → `@drawable/ic_notification`.
- [x] **Step 3: iOS.** `Runner.entitlements` with `aps-environment` `development` (distribution signing swaps it for production), `CODE_SIGN_ENTITLEMENTS` on the Runner target's three configurations. A Run Script phase copying `GoogleService-Info.plist` into the app when present.
- [x] **Step 4:** `.gitignore` the two Firebase files and `lib/firebase_options.dart`. `release.yaml` writes `google-services.json` from `secrets.GOOGLE_SERVICES_JSON` when set, before the Android builds.
- [x] **Step 5:** `flutter build apk --debug` and `flutter build ios --no-codesign --debug` without the files. Quality gate.

### Task 4: `Push`, `PushScope`

**Files:**
- Create: `lib/features/notifications/data/device_repository.dart`, `lib/features/notifications/data/push.dart`, `lib/features/notifications/presentation/push_scope.dart`, `test/features/notifications/fake_push.dart`, `test/features/notifications/presentation/push_scope_test.dart`
- Modify: `lib/app/router/app_router.dart`, `test/app/app_harness.dart`

- [x] **Step 1: Failing test.** `PushScope` around a router with Today and a second page, `pushProvider` overridden by `FakePush`: registers once with `en`; with the app in `fr`, `fr`; a locale change registers again; an `opened` event on the second page goes to Today.
- [x] **Step 2: `DeviceRepository.register(token, platform, locale)`**: `rpc('register_device')` inside `guardPeople`.
- [x] **Step 3: `Push`**: lazy `Firebase.initializeApp()` on Android and iOS only, failure → INFO and no-op. `register(locale)`: allowed check, iOS waits for the APNs token (none → return; `onTokenRefresh` catches up), `getToken`, save; one `onTokenRefresh` subscription re-saves with the last locale. `opened`: `getInitialMessage` then `onMessageOpenedApp`, as `Stream<void>`. `forget()`: `deleteToken`. Errors are logged, never thrown. `pushProvider` calls `forget` when `accountProvider` goes from an account to null.
- [x] **Step 4: `PushScope`**: `didChangeDependencies` registers when the language code changed; `opened` → `context.go(Routes.today)`. The shell route builds `PushScope(child: AppShell(…))`. The harness overrides `pushProvider` with `FakePush`.
- [x] **Step 5:** Quality gate.

### Task 5: Docs

**Files:**
- Modify: `docs/architecture.md`, `README.md`, `AGENTS.md`

- [x] **Step 1:** architecture.md: a *Push* section (optional Firebase files, `Push` the only Firebase code, token lifecycle, strings generated from ARB); FCM out of "Not yet present". AGENTS.md stack row: Push — FCM, Android and iOS. README: Firebase setup (project, the two files, APNs key, `GOOGLE_SERVICES_JSON` secret) and how a token is checked (`select * from device_token` in Studio).
- [x] **Step 2:** Quality gate. (The spec's sign-out change went to #271.)
