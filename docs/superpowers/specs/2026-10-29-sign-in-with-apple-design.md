# Sign in with Apple — design

Issue: [#22](https://github.com/paulthvt/loomia/issues/22), under the iOS
epic [#400](https://github.com/paulthvt/loomia/issues/400). Builds on auth
(`2026-09-23-auth-login-design.md`), whose rules hold unless changed here.
Figma: section "Sign in with Apple — #22" on page "04 — Screens (Light)"
([node 471:15413](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/?node-id=471-15413)):
Welcome light and dark, the name step on phone, with its error, and at
desktop width. Component `SignInWithAppleButton` (Light / Dark) on the
Components page. The Welcome frames follow `welcome_page.dart`, not the
older #21 frame, which still says "Folo".

## Intent

App Review guideline 4.8 asks for Sign in with Apple when an app offers
Google sign-in, so the App Store submission (#398) waits on it. #21 removed
the button rather than ship it broken; the paid membership now exists (#396).

## Goals

- **Continue with Apple** on the Welcome screen, on iPhone, iPad, Android
  and web, between Google and email.
- An account made with Apple on one platform signs in on the others.
- A new account without a name is asked for one in the first run.
- The Supabase secret Apple needs can be regenerated in one command, and
  someone is warned before it expires.

## Non-goals

- The native iOS sheet (`sign_in_with_apple` + `signInWithIdToken`). The
  upgrade path from #21 still holds and changes only `AuthRepository`.
- Revoking Apple's tokens when an account is deleted (see Decisions).
- Linking an Apple identity to an existing account from Settings.

## Anti-goals

- A new runtime dependency.
- Loomia's Apple setup under the employer team: everything here is team
  `378X654D2A` (#396).
- The `.p8` key or the generated secret in the repo or in CI logs.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Flow | `signInWithOAuth(OAuthProvider.apple, redirectTo: _redirect)` on every platform, like Google: a browser sheet on iOS and Android, a redirect on web. | Paul. One path, no dependency. |
| iOS entitlement | None. The web flow doesn't use `ASAuthorization`, so `Runner.entitlements` keeps only push, although the App ID has the capability (next row). Don't "fix" that by adding the entitlement. | Nothing to add. |
| App ID capability | **Sign In with Apple** turned on for `app.loomia` in the portal: the Services ID needs it as its primary App ID. | Apple requires it. |
| Profiles after that | Changing the App ID's capabilities likely invalidates the App Store profile. If the portal shows it Invalid, regenerate it and replace `IOS_APPSTORE_PROFILE` (README → Releases → iOS). Xcode remakes the development one. | Otherwise the next TestFlight upload fails at signing. |
| Services ID | `app.loomia.signin`, domain `cskjeqspecsyqioietrj.supabase.co`, return URL `https://cskjeqspecsyqioietrj.supabase.co/auth/v1/callback`. | Supabase's callback. Name: *my call*. |
| Supabase config | `[auth.external.apple]`: `enabled = true`, `client_id = "app.loomia.signin"`, secret stays `env(SUPABASE_AUTH_EXTERNAL_APPLE_SECRET)`. Pushed by hand with `supabase config push`, both provider secrets set. Locally the secret is unset, so Apple sign-in doesn't work against the local stack, like Google. | `config.toml` is the source of truth (AGENTS.md). |
| The secret | A JWT signed ES256 with the `.p8`. Header: `kid` = Key ID. Claims: `iss` = team, `iat` = now, `exp` = now + 180 days (Apple's maximum), `aud` = `https://appleid.apple.com`, `sub` = Services ID. | Apple's format. |
| Generating it | A fastlane lane, `bundle exec fastlane apple_auth_secret key:<path.p8> key_id:<id>` in `ios/`, printing the secret and its expiry date: `JWT.encode(claims, OpenSSL::PKey::EC.new(File.read(key)), 'ES256', { kid: key_id })`. `jwt` (3.3.0) comes with fastlane; not added to the `Gemfile`. | No new stack or dependency; Ruby stays in `ios/`. *(My call.)* |
| Expiry warning | The lane also prints `gh variable set APPLE_AUTH_SECRET_EXPIRES --body <date>`. A weekly scheduled workflow fails when that date is under 30 days away, and GitHub emails the failure. | In the repo, no server, no extra secret. *(My call.)* |
| Where the `.p8` lives | Paul's password manager, like `distribution.p12`. Never a GitHub secret: config push is by hand. | Least exposure. |
| Button look | Apple's "white with outline" style in light (white fill, black outline, black mark and text), "white" in dark (no outline). Full width, same height as Google's, label **Continue with Apple**. Style in `app_theme.dart`; the black and white are Apple's, not theme colours, like Google's 18 px mark. | Apple's HIG allows only black, white or white-outline. White-outline in light matches the outlined Google button. Figma. |
| Button height | The theme's button minimum (48), like Google and email. The mocks draw 44, as for every button there. | Code wins; the three must match. |
| The mark | Apple's official logo from Apple Design Resources, one monochrome PNG at 1x/2x/3x in `assets/images/`, tinted with the button's foreground. Not the Figma `Brand/Apple` shape, which was drawn from a public SVG. | Apple's file is the only allowed source. |
| Order | Google, Apple, email, as in #21. | Same size and prominence is what 4.8 asks. |
| Copy | `authContinueWithApple`: **Continue with Apple**, description says Apple stays untranslated. | Matches Google's key. |
| Cancel | Closing Apple's sheet returns to Welcome with no error, as Google. | Same SDK path. |
| The name | **Never arrives.** Apple sends it once, in the callback's `user` form field; Supabase's web callback reads only the `id_token`, which has no name ([apple.go](https://github.com/supabase/auth/blob/master/internal/api/provider/apple.go) `GetUserData`; [Supabase docs](https://supabase.com/docs/guides/auth/social-login/auth-apple)). Every Apple user starts with an empty `first_name`; `_backfillFirstName` does nothing for them. | Found in review. |
| Handling the missing name | A **name step** opens the first run when the account has no name: one First name field and **Continue**, then the company step as today. Required, like on sign-up. | Paul. Covers Apple, and any Google account without a name. |
| When the name step shows | Decided once when the first run opens: `first_name` empty **and** no provider name (`full_name` / `name`) in the metadata. Exposed as `Account.needsName`. | Google's backfill is fire-and-forget and may land after the first run opens; checking the provider name too means a Google user never sees the step. *(My call.)* |
| Saving it | `updateFirstName`, validated by `firstNameFieldError` (sign-up's). A failure shows the `FormError` and stays on the step. | Same path as sign-up and Settings. |
| Back | From the company step, back (button or gesture) returns to the name step when it was shown, prefilled. From the name step, nothing: it's the first step, as the company step is today. | Same rule as the existing two steps. |
| Already-onboarded users | Never see it: the first run only opens for `onboarded == false`. | Apple users don't exist yet. |
| Copy | Eyebrow **Welcome** (existing), title **What should we call you?**, body **Your first name, for your greeting on Today.**, field **First name** (existing `authFirstNameLabel`), button **Continue** (new key). Empty name: the existing sign-up error **Enter your first name.** | Figma. |
| Name step layout | `AuthScaffold`, as the company step: eyebrow, title, body, the field, a full-width Continue. On desktop, the 400 px auth column, centred. | Figma. |
| Private relay email | Accepted as the account's email. An OAuth user has no password, so neither confirmation nor reset email goes to it, and no relay sender registration is needed. A future feature that emails users must register Loomia's sender with Apple's relay first. | Nothing sends to it today. |
| Same email as an existing account | Supabase links the Apple identity to it when Apple's email is the real, verified address. A relay address makes a separate account. | Supabase's default. |
| Token revocation on delete | Not in #22. Apple's account-deletion page says apps *should* revoke tokens; the web flow leaves Apple's refresh token with Supabase, out of the app's reach. Deleting the Supabase user is what `delete-account` does today. If App Review asks, a follow-up issue. | Cost is large (store the token, sign a second JWT in the Edge Function) for a "should". *(My call.)* |
| Released app | Unaffected: the old build has no Apple button, and enabling a provider changes nothing for other users. No migration. | |

## Behaviour

- **Welcome:** the Apple button between Google and email. Tapping it while
  another sign-in is starting does nothing (`_busy`, as today). A failure
  shows the existing `FormError`.
- **First sign-in with Apple:** Apple asks for name and email (share or
  hide); Loomia gets neither name nor, if hidden, the real email. The first
  run starts with the name step, then the company and people steps.
- **Later sign-ins:** straight in, any platform.

## Code

- `supabase/config.toml`, `[auth.external.apple]`: `enabled = false` →
  `true`, `client_id = ""` → `"app.loomia.signin"`. Without both, a push
  with the secret set changes nothing.
- `AuthRepository.signInWithApple()`, new (the #21 spec lists it, the code
  never had it), next to `signInWithGoogle()`; the
  "Apple … not wired up" comments in `auth_repository.dart` and
  `welcome_page.dart` go.
- `FakeAuthRepository.signInWithApple()`, new, records `signInWithApple()`.
- `WelcomePage`: the button, styled from the theme.
- `Account.needsName`, filled by `AuthRepository.account`.
- `FirstRunPage`: a third local step, `FirstRunNameStep`, before the
  company step when `needsName` was true at open. The step stays local
  state; the router's onboarding guard doesn't change.
- `ios/fastlane/Fastfile`: the `apple_auth_secret` lane.
- `.github/workflows/apple-secret-expiry.yaml`: weekly, reads the
  `APPLE_AUTH_SECRET_EXPIRES` variable, fails under 30 days (and when unset,
  once the provider is on).
- Docs: README (setup, rotation; the existing `config push` line gains the
  Apple secret, not a second line),
  `docs/design/screens.md` (the Apple path is built), and the Apple lines in
  the #21 spec that say "not wired up".

## Setup (Paul, once)

1. Portal: Sign In with Apple on `app.loomia`; the Services ID above; a key
   with Sign In with Apple, `.p8` downloaded (once only) to the password
   manager. Regenerate the App Store profile if it went Invalid.
2. `bundle exec fastlane apple_auth_secret …`, then the printed
   `gh variable set …`.
3. `SUPABASE_AUTH_EXTERNAL_GOOGLE_SECRET=… SUPABASE_AUTH_EXTERNAL_APPLE_SECRET=… supabase config push`
   after the PR merges.
4. Every 6 months: steps 2 and 3 again, when the workflow warns.

## Test plan

- Widget: the Welcome test offers the Apple path; tapping it calls
  `signInWithApple()`; a failure shows the error; the existing large text
  scale test still fits with three buttons.
- Unit: `needsName` is true only with no `first_name` and no provider name.
- Widget, first run: the name step shows when `needsName`, not otherwise;
  an empty name is refused; Continue saves through `updateFirstName` and
  moves to the company step; a failure stays; back from the company step
  returns to it, prefilled.
- The lane: its output decodes to the header and claims above (checked
  once by hand, recorded in the PR).
- On devices, against the hosted project: first sign-in on the iPhone with
  email hidden: the name step shows, the greeting then uses that name,
  Settings shows the relay address. Then the same account on web and
  Android, with no name step. To repeat a first sign-in, remove Loomia under
  the Apple ID's Sign in with Apple settings.

