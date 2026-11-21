# Turnstile on email auth — plan

**Goal:** every email auth call sends a Turnstile token; `[auth.captcha]` stays off (PR 1 of the spec's rollout).
**Architecture:** `Captcha` (data) owns token rules and a platform `solve`; `AuthRepository` asks it for a token before each email call; one hidden `CaptchaHost` at the app root holds the mobile web view.
**Tech Stack:** `webview_flutter` (mobile), `package:web` + `dart:js_interop` (web).
**Spec:** docs/superpowers/specs/2026-11-21-turnstile-design.md

## Global Constraints

- Pub from `https://pub.dev` (`PUB_HOSTED_URL=https://pub.dev`), exact versions, reason in the pubspec comment.
- No `Podfile`: iOS stays SPM-only.
- `config.toml` unchanged.

## Rulings made while planning

- **The repository fetches the token, not the pages.** The spec had pages pass it; reading it inside `AuthRepository` leaves the four pages and their tests untouched, and Google/Apple never ask.
- **One web view, at the app root, not one per page.** A `CaptchaHost` in `LoomiaApp.builder`, 1×1 under the app, mounted only while signed out. One controller can't sit in two pages that are both on the stack (login under forgot password).
- **Prefetch starts when the host mounts** and again after each token is taken.
- Tests can't create a web view: the host renders nothing when `WebViewPlatform.instance` is null.

## Review Focus

The web view running while 1×1 and under the app (checked on devices before PR 2); JS interop on the web.

### Task 1: Captcha rules

- [x] `test/features/auth/data/captcha_test.dart`: single use; a token older than 4 min is replaced; an error is retried once then `AuthFailure.captcha`; 15 s without an answer is an error.
- [x] `lib/features/auth/data/captcha.dart`: `Captcha(solve, {now})`, `warm()`, `token()`.
- [x] `AuthFailure.captcha`, `authFailureFrom` maps `captcha_failed`, copy key `authFailureCaptcha`.

### Task 2: Platform solvers and the host

- [x] `captcha_page.dart` (the HTML), `captcha_solver_io.dart` (web view + channel), `captcha_solver_web.dart` (script + hidden div), conditional import.
- [x] `CaptchaHost` in `LoomiaApp.builder`.

### Task 3: Repository

- [x] `AuthRepository(client, captcha)`; `signIn`, `signUp`, `sendPasswordReset`, `resendConfirmation` pass `captchaToken`.
- [x] Test: those four send the token (fake HTTP client), OAuth doesn't ask.

### Task 4: Ship

- [x] Checks, iOS simulator build without `Podfile`, PR; `loomia-site` PR (Turnstile + Privacy Addendum).
