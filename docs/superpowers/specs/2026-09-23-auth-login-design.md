# Auth — Supabase, sign-in and registration

Issue [#21](https://github.com/paulthvt/folo-mlm/issues/21). Design decided
2026-09-23. Mockups: [Figma → Folo](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Folo),
page `04 — Screens (Light)` at y=1200, cloned to `05 — Screens (Dark)`.

This is the first feature in the app. It introduces the first backend
dependency, the first route guard, and the first feature folder.

---

## 1. Scope

In:

- Welcome screen with Google, Apple and email paths.
- Email + password sign-in and registration (first name collected at signup).
- Email confirmation, with a "check your inbox" screen and resend.
- Password reset: request a link, then choose a new password from the link.
- Route guard and session persistence: signed out reaches only the auth
  screens, signed in never sees them, a returning user is restored on launch.
- Sign out.

Out, and why:

- **Account deletion** — required by the App Store eventually, not by a first
  login. Its own issue.
- **Magic links** — the chosen methods already cover passwordless-ish entry via
  Google and Apple.
- **A profiles table** — nothing yet queries another person's name. See §5.
- **Native Google/Apple SDKs** — see §4.
- **Onboarding after signup** — signup lands on Today. There is nothing to
  onboard into yet.

## 2. Screens and routes

```
/welcome            signed-out root
/login
/register
/forgot-password
/check-inbox        two copies: email confirmation | reset requested
/reset-password     reached by deep link only
```

`/check-inbox` takes its copy from query parameters
(`?reason=confirm|reset&email=…`) rather than a router `extra` object, so a
reload on web does not land on a screen with no content.

The signed-in destination is `/` (`Routes.dashboard`), which is where the
dashboard already lives. It becomes `/today` when that screen is built.

| Route | Content |
| --- | --- |
| `/welcome` | Wordmark, `Know what to do next.`, the promise sentence, three buttons (Google, Apple, `Continue with email` → `/login`), footer `New here? Create an account`. |
| `/login` | Back, `Welcome back`, email, password (reveal toggle), `Forgot password?`, `Sign in`, footer to `/register`. |
| `/register` | Back, `Create your account`, first name, email, password (helper `At least 8 characters`), `Create account`, legal line, footer to `/login`. |
| `/forgot-password` | Back, `Reset your password`, email, `Send reset link`, `Back to sign in`. |
| `/check-inbox` | EmptyState: title, body naming the address, `Resend email`. One screen, title and body passed in. |
| `/reset-password` | `Choose a new password`, new password + confirm, `Save and sign in`. No back button — there is nowhere to go back to from a deep link. |

Social buttons appear on `/welcome` only. A user who signed up with Google must
not be offered a competing email form on the same screen as their real path.

Paths are added to `lib/app/router/routes.dart` before the `GoRoute`s, per
CLAUDE.md.

## 3. Layout

Signed-out screens carry no navigation — no BottomNav, no Sidebar.

Single column capped at 400, centred, flat on `surface/canvas`. No card: a card
around a form is chrome, and at 400 wide the column already reads as one object
(design principle #6).

One widget tree per screen. Across `mobile` / `tablet` / `desktop` only two
things change: the column centres horizontally, and vertical rhythm steps from
`space/lg` to `space/xl`. Every other screen in this product restructures across
size classes; these deliberately do not, because a form has one column at every
width.

Components are instances of the existing library. Three additions, built
2026-09-23:

| Component | Why |
| --- | --- |
| `FormError` | `semantic/error-container`, `radius/md`, 20px glyph, `body-sm` in `semantic/error`, `message` TEXT property. TextField's Error state is field-level; "we could not sign you in" belongs to the form. |
| `Brand/Google` | The Google G. **Placeholder artwork** — replace with the asset from Google's Sign-In branding guidelines. |
| `Brand/Apple` | The Apple mark. **Placeholder artwork**: the app ships Apple's own logo (`assets/images/apple_logo.png`, #22). |

The password reveal toggle is the existing TextField with
`showTrailingIcon`. No new component.

## 4. Supabase

Project `Folo`, ref `cskjeqspecsyqioietrj`, region eu-west-1, created
2026-09-20. It already existed; no project was created for this issue.

One new dependency: **`supabase_flutter`**. Reason recorded in the pubspec
comment. It carries session persistence and deep-link handling, so this issue
adds no `app_links`, no `shared_preferences`, no `google_sign_in`, no
`sign_in_with_apple`.

**Client config lives in the repo.** `lib/core/supabase/supabase_config.dart`
holds the project URL and the publishable key (`sb_publishable_…`, not the
legacy anon JWT — those keep working only until the end of 2026). It is passed
to `Supabase.initialize` as `anonKey`; the parameter name is historical, the key
type is not. The publishable key is designed to be public and ships inside
every binary regardless; Row Level Security is the actual boundary. This keeps
CLAUDE.md's "no `--dart-define-from-file`" rule intact. The service-role key
never enters the repo, the client, or any config file.

**OAuth runs through `signInWithOAuth`** — a system browser redirect, one code
path on Android, iOS and Web, no extra dependency. The cost is that users get a
browser sheet instead of the native account picker, and iOS review may
eventually want the native Sign in with Apple sheet. Upgrade path when it does:
`google_sign_in` + `sign_in_with_apple` feeding `signInWithIdToken`, which
changes only `AuthRepository` — no screen changes.

**Deep links** are the one genuinely fiddly part of this issue. Both email
confirmation and password recovery land back in the app:

- Redirect target: `io.supabase.folo://login-callback/`.
- Android: intent filter on that scheme in `AndroidManifest.xml`.
- iOS: `CFBundleURLTypes` entry in `Info.plist`.
- Web: the deployed origin, plus `http://localhost` for development.
- All of them registered in the project's allowed redirect URLs.

`supabase_flutter` handles the callback and emits `passwordRecovery` on
`onAuthStateChange`; the router sends that event to `/reset-password`.

**Dashboard settings** (not reachable from this repo, done once by hand):
email confirmations **on**; minimum password length **8** (the default is 6, so
the client is not the only gate); Google and Apple providers enabled with their
client IDs and secrets; redirect URLs as above.

## 5. Data

First name goes in the auth user's `user_metadata` at signup
(`options.data: {'first_name': …}`). Google returns a name, which is
written to the same field on first sign-in if it is empty. Apple's web flow
returns none, so the first run asks for it (#22,
`2026-10-29-sign-in-with-apple-design.md`).

No `profiles` table, no migration, no RLS policy, no trigger. Today's greeting
reads the name from the current session. The table becomes necessary when
another person's name must be queryable — the Team screen — and that is its own
issue, with its own policies.

## 6. Structure

```
lib/core/supabase/
  supabase_config.dart          URL + publishable key
  supabase_provider.dart        the client, as a Provider

lib/features/auth/
  domain/
    auth_failure.dart           enum: the failures the UI can react to
    auth_validation.dart        pure field validators
  data/
    auth_repository.dart        the only file that imports supabase_flutter
    auth_failure_mapping.dart   AuthException → AuthFailure
  presentation/
    welcome_page.dart
    login_page.dart
    register_page.dart
    forgot_password_page.dart
    check_inbox_page.dart
    reset_password_page.dart
    auth_failure_copy.dart      AuthFailure → user-facing copy
    widgets/auth_scaffold.dart  centred capped column + optional back button
    widgets/form_error.dart
    widgets/submit_button.dart  holds the loading state
    widgets/password_field.dart reveal toggle
```

`Supabase.initialize` runs in `main()` before `runApp`.

`domain/` exists for exactly two things: `AuthFailure`, which both `data` and
`presentation` must name, and the validators. Without it, `presentation` would
import from `data` and the layering rule would be broken on the first feature.
There is no interface and no single-implementation abstraction.

No controller. Each screen owns its own submit state (`busy`, `failure`) in
`setState` — it is local widget state by CLAUDE.md's rule, and a Notifier per
form would be indirection with one consumer. Session state, which *is* shared,
lives in the repository's stream and is watched by the router.

`AuthRepository` exposes `signIn`, `signUp`, `signInWithGoogle`,
`signInWithApple`, `sendPasswordReset`, `updatePassword`, `signOut`,
`hasSession`, `isRecoveringPassword` and an auth-change `Stream`. Every method
throws `AuthFailure`; no `supabase_flutter` type crosses into `presentation`.

## 7. Guard and session

`appRouterProvider` watches the auth state stream and refreshes the router on
every change.

| State | Redirect |
| --- | --- |
| No session, route is not an auth route | `/welcome` |
| Session, route is an auth route | `/` |
| Recovering a password | `/reset-password`, and `/reset-password` is never redirected away from even with a session — the recovery link signs the user in before they choose the new password |

`Supabase.initialize` restores a stored session before `runApp`, so the first
redirect already knows the answer and no auth screen flashes on launch.

Sign out sits in the Sidebar account block on desktop. On mobile there is no
settings screen yet, so it goes in Today's TopAppBar trailing action as a single
overflow item. When a settings screen exists it moves there.

## 8. Errors, loading, validation

Field-level, checked before any network call, rendering TextField
`State=Error`: email shape, empty first name, password shorter than 8,
mismatched confirmation.

Form-level, rendering `FormError`:

| Cause | Copy |
| --- | --- |
| Wrong credentials | `Email or password is incorrect.` |
| Email not confirmed | `Confirm your email first. We can send the link again.` + resend |
| Rate limited | `Too many attempts. Try again in a few minutes.` |
| Network / unreachable | `We could not reach Folo. Check your connection.` |
| Anything else | `Something went wrong. Try again.` |

Two rules here are security, not copy preference:

1. A failed sign-in never says which field was wrong and never reveals whether
   an account exists.
2. `/forgot-password` always confirms identically — *"If an account exists for
   that address, we sent a link."* — so it cannot be used to probe for
   registered addresses.

While a request is in flight the submitting Button shows its loading state
(label swaps for a spinner, width held) and the fields are disabled. No
full-screen spinner: the screen is already the smallest possible context.

## 9. Testing

- Widget test per screen against a fake `AuthRepository`: renders, validates,
  calls the repository once, shows `FormError` on failure.
- Unit tests for `auth_form_validation` and `auth_error_copy`.
- Unit test for the redirect logic: signed out → `/welcome`, signed in →
  `/today`, recovery → `/reset-password`.
- No test hits the live project.

`dart format .`, `flutter analyze` clean, `flutter test` green before the PR.

## 10. Known debt this ships with

- Both brand marks are placeholder artwork.
- `Brand/*` and `FormError` exist in Figma but not in Flutter until
  implementation.
- No account deletion.
- No profiles table, so no screen can show another person's name yet.
- OAuth is a browser redirect, not a native sheet.
