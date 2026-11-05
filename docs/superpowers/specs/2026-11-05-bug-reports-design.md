# In-app bug reports — design

Issue: #463. Figma: "Bug reports — #463" on "04 — Screens
(Light)", to mock (brief at the end).

## Intent

A few people Paul picks (his wife first) test Loomia on their own accounts.
When something looks wrong, they report it from the screen where it happened:
a screenshot they can draw on, a comment, and what the app was doing. The
report lands as an issue on `paulthvt/loomia`, next to the rest of the work,
with no share sheet and no copy-paste.

Prior art: Cytric Mobile's bug report mode (`cytric_mobile_cmc_app`,
`lib/presentation/widgets/bug_report/`): seven taps on the version unlock a
floating button; dragging it onto an ✕ turns the mode off.

## Goals, non-goals, anti-goals

- **Goals:** one tap from any screen to a report; the issue has enough to
  reproduce (device, version, route, recent logs); nothing secret in the app.
- **Non-goals:** reports from the general public, crash reporting (Sentry does
  that), video, attaching files other than the screenshot, editing or
  following up a report from the app.
- **Anti-goals:** a customer's name, phone or note reaching the public repo; a
  GitHub or NAS credential in the build; a hidden mode anyone can find by
  tapping seven times.

## Approaches

| Approach | Trade-off | Picked |
| --- | --- | --- |
| A. `feedback` 3.2.0 with Loomia's own bottom sheet (`feedbackBuilder`) and a `FeedbackThemeData` built from `colorScheme` | ~150 lines, proven flow (cmc_app). One dependency. The drawing toolbar keeps the package's shape. | **Yes.** A spike showed it opens, draws, takes text and returns a PNG (~150 KB) inside Loomia's `material_ui` app with no assertion. |
| B. Own capture (`RepaintBoundary.toImage`), `CustomPainter` drawing, `material_ui` sheet | ~350 lines, no dependency, every pixel on the design system | No: twice the code for a screen only testers see. |
| Screenshots on the public issue (GitHub attachments) | Simplest, but a public URL shows third parties' data; `gh --attach` is a CLI feature, not a documented REST API | No |
| A separate private repo for reports | Private images inline, but reports leave the project board | No, Paul wants one repo |

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Who can use it | `app_metadata.bug_reporter = true` on the auth user, set by Paul in SQL (below). The app reads `user.appMetadata` into `Account.bugReporter` where `AuthRepository` builds the account from `userMetadata`. The Edge Function re-reads it with `supabaseAdmin.auth.admin.getUserById(ctx.userClaims!.id)`, not from the JWT. | `app_metadata` is writable only with the service role, so no user can grant it to themselves. The admin read makes removal take effect at once, whatever the token says. No table, no migration. |
| Unlock | Seven taps on the Settings version footer, each within 2 s of the previous. Only when `bugReporter`; for anyone else the taps do nothing. Snackbar "Bug reports on". | cmc_app's gesture. Silent for others so it isn't discoverable. |
| Where the mode lives | A Riverpod `Notifier<bool>`, in memory. Off on restart and on sign-out. | No local persistence by design (docs/architecture.md → Not yet present). Seven taps again is cheap for a tester. |
| The button | A small round button (bug icon, `primaryContainer`), over every screen from `MaterialApp.router`'s `builder`, so it survives navigation. Draggable anywhere inside the safe area, starts bottom-right above the navigation bar, keeps its position in memory. Hidden while the feedback panel is open. | Same as cmc_app. |
| Turning it off | While dragging, an ✕ target appears bottom centre; dropping within ~48 px of its centre turns the mode off, with a snackbar "Bug reports off" and Undo. | cmc_app's gesture; Undo covers a slip. |
| Capture | `BetterFeedback` placed inside `MaterialApp.router`'s `builder` (around the router child), so its sheet inherits Loomia's `Theme` and localizations. Tap on the button calls `BetterFeedback.of(context).show`. | Inside rather than above the `MaterialApp`, unlike cmc_app, so our sheet is a normal `material_ui` widget. |
| Panel theme | `FeedbackThemeData` from the active `ColorScheme`: backdrop `scrim` at 60 %, sheet `surface`, active mode `primary`, pens `primary`, `tertiary`, `onSurface`, `surface`. Light and dark. | No hard-coded colour; red stays reserved for errors. |
| The sheet | Our own `feedbackBuilder`: filled multi-line field "What went wrong?", helper text "Posted publicly on GitHub: leave out names and numbers.", a pill `FilledButton` "Send", a spinner while sending. | The comment itself goes to a public issue. |
| Logs | Its own scrubber in `features/bug_reports/domain/`, stricter than Sentry's path and independent of it (no shared redactor exists). A ring buffer of the last 200 `logging` records, fed from `Logger.root.onRecord` in `main.dart` from launch, whatever the mode. Each entry: time, level, logger, message with UUIDs replaced by `:id`, error **type** only (plus `code` for `PostgrestException` / `AuthException`), stack trace for `SEVERE` only. | Messages already hold no personal data (docs/architecture.md → Logging); error text can (`details`, emails). The buffer must hold what happened before the tap. |
| Device facts | App version and build (`package_info_plus`), platform, `Platform.operatingSystemVersion` (not on web), locale, current route with ids as `:id`, logical screen size, light/dark. No `device_info_plus`. | Enough to reproduce; no new dependency. |
| Transport | The app posts one JSON body to the Edge Function `report-bug` through `functions.invoke`, behind `BugReportRepository` in `features/bug_reports/data/`: `comment`, `screenshot` (base64 PNG), `facts`, `logs`. | One call; widgets never call Supabase. |
| Function config | `[functions.report-bug] verify_jwt = false` in `supabase/config.toml`, like `delete-account`. | The platform's `verify_jwt` only understands legacy keys; `withSupabase` verifies the session itself. Without the block every call is a 401. |
| Function checks | `withSupabase({ auth: 'user' })`; 403 unless `app_metadata.bug_reporter === true`; 400 unless comment is 1–5000 chars, screenshot decodes to a PNG (magic bytes) of at most 5 MB, logs at most 200 entries. | The function is the real gate. |
| Spike result | `feedback` imports the frozen `flutter/material.dart`, so its own toolbar uses its theme and strings, not Loomia's: that is why the sheet is ours (`feedbackBuilder`) and the toolbar takes `FeedbackThemeData`. The spike ran it inside Loomia's app with no assertion and got the PNG and text back. | The one part not shown by the spike is whether our sheet sees Loomia's `Theme`; "Left to the builder" has the fallback. |
| Screenshot storage | The function PUTs the PNG over WebDAV to Paul's Synology NAS, `<NAS_WEBDAV_URL>/<yyyy-mm-dd>-<reportId>.png`, as a NAS user that can only write to that one shared folder. The WebDAV port is reachable from the internet with a trusted certificate and no IP or country limit (Paul, 2026-11-05). | Stays private; credentials only in function secrets. Edge Functions have no fixed egress IP and reject self-signed certificates. |
| Screenshot link | The issue links to the same WebDAV URL as text, not an inline image. Opening it asks for a NAS sign-in (Paul's own account, read access on the folder); the browser remembers it. | GitHub's image proxy can't sign in, so an inline image would show broken. |
| Issue | GitHub REST `POST /repos/paulthvt/loomia/issues` with a fine-grained token (Issues: write on that repo only), label `bug-report`. Title "Bug report: " + first line of the comment, cut at 60 chars. Body: comment, facts table, screenshot link, logs in a collapsed `<details>` code block, reporter as the user id (never the email). | The label lets the board filter them. |
| Partial failure | The app gives each report a UUID when Send is tapped and keeps it across retries; the file is `<yyyy-mm-dd>-<reportId>.png`. Upload first, then the issue. A NAS failure stops before GitHub (502, nothing created). A GitHub failure leaves the PNG; Retry PUTs the same name again, overwriting it, then retries the issue. | Retries never pile up files. At worst one PNG with no issue, when the tester gives up. |
| Result in the app | Success: snackbar "Sent as #123". Failure: snackbar "Couldn't send" with Retry, which resends the same report kept in memory until it goes or the app closes. | The panel closes on Send, so the draft must survive a failure. |
| Copy | English keys in `app_en.arb` with descriptions; French via Weblate, *tu*. "Bug report" is fine wording. | Conventions. |

## Tests

- Unit: the log buffer keeps 200, drops the oldest, replaces UUIDs, keeps only
  the error type and code, keeps stack traces for `SEVERE` only.
- Unit: the issue body and title builder in the function (Deno test beside
  `handler_test.ts`'s pattern): title cut, `<details>` logs, no email.
- Deno: validation and 403 with a stubbed fetch for NAS and GitHub.
- Widget: seven taps unlock for a `bugReporter` account and do nothing for
  another; six taps or a 2 s gap don't unlock.
- Widget: the button shows on Today, Contacts and Settings; drag onto ✕ turns
  it off, Undo brings it back.
- Widget: Send calls the repository with comment, PNG and logs; failure shows
  Retry, Retry resends.
- Repository: `functions.invoke` body shape (existing fake-client pattern).
- By hand: one report from iPhone, Android and web to a test issue; open the
  link signed out of the NAS (prompt) and signed in (image).

## By hand, Paul

- NAS: enable WebDAV Server over HTTPS; a shared folder `loomia-bug-reports`;
  a user `loomia-bugs` with read/write on that folder only and no other app
  rights; your own account with read on it.
- GitHub: fine-grained token, repository `paulthvt/loomia`, Issues read/write;
  create the `bug-report` label.
- `supabase secrets set GITHUB_ISSUES_TOKEN=… NAS_WEBDAV_URL=…
  NAS_WEBDAV_USER=loomia-bugs NAS_WEBDAV_PASSWORD=…`, then
  `supabase functions deploy report-bug` from up-to-date `main`.
- Allowlist a tester in the SQL editor:
  `update auth.users set raw_app_meta_data = raw_app_meta_data || '{"bug_reporter": true}' where email = '…';`
  It reaches the app at the next token refresh (up to an hour) or sign-in.

## Left to the builder

Button size and exact drag physics; snackbar durations; how the sheet keeps
its height above the keyboard; whether `BetterFeedback` inside `builder`
needs its own `Overlay`. If it can't live inside `builder`, put it above
`MaterialApp` and wrap the sheet in `Theme` and `Localizations` from the
app's.

## Left open, Paul's call

Whether the privacy policy should mention that testers' screenshots are kept
on a NAS you run. Not legal advice; it's the same question the Brevo line
answered.

## To mock

Section "Bug reports — #463": the button on Today (light and dark); the
drag with the ✕ target showing; the panel with Loomia's sheet (field, helper
text, Send); the "Sent as #123" and "Couldn't send · Retry" snackbars.

## Not now

Public reporting, a "my reports" list, video, automatic redaction of names in
screenshots, a dedicated reports table.
