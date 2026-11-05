# In-app bug reports Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allowlisted testers unlock a bug-report mode with seven taps on the Settings version, report from any screen with an annotated screenshot and a comment, and the report becomes an issue on `paulthvt/loomia` with the screenshot stored on Paul's NAS.

**Architecture:** A new feature `lib/features/bug_reports/` (domain: log buffer, report model; data: repository, device facts; presentation: mode, overlay button, sheet, controller). `feedback` 3.2.0 does capture and drawing, wrapped inside `MaterialApp.router`'s `builder`. A new Edge Function `supabase/functions/report-bug/` checks `app_metadata.bug_reporter`, PUTs the PNG over WebDAV and creates the GitHub issue.

**Tech Stack:** Flutter (`material_ui`, Riverpod, `logging`, `package_info_plus`), `feedback` 3.2.0, Supabase Edge Functions (Deno, `npm:@supabase/server@1.8.0`), GitHub REST, WebDAV.

**Spec:** `docs/superpowers/specs/2026-11-05-bug-reports-design.md`

## Global Constraints

- Branch `feature/463-bug-reports`; every PR fills **Ticket** with `Closes #463`.
- One new runtime dependency: `feedback: 3.2.0`, with a pubspec comment giving the reason. No `device_info_plus`, no `shared_preferences`.
- Imports are `package:loomia/...`; Material from `package:material_ui/material_ui.dart`, never `flutter/material.dart`.
- No hard-coded colour, radius, font size or spacing in widgets; the feedback theme is built in `lib/app/theme/app_theme.dart`.
- English copy only, in `lib/l10n/app_en.arb`, each key with a description; run `flutter gen-l10n`.
- Nothing goes on the public issue that names a person: no email (reporter is the user id), error **type** and `code` only, UUIDs as `:id`.
- No migration. One `supabase/config.toml` block: `[functions.report-bug] verify_jwt = false`.
- Limits: comment 1–5000 chars; PNG ≤ 5 MB decoded, PNG magic bytes; logs ≤ 200 entries; title `Bug report: ` + first comment line cut at 60 chars.
- Done means `dart format .`, `flutter analyze` (No issues found!), `flutter test`, `deno check supabase/functions/*/index.ts`, `deno test supabase/functions` all pass.

## Rulings made while planning

- The issue number comes back to the app as `{ "issue": <int> }`; the app shows "Sent as #<n>".
- The repository has no unit test of its own: it is one `functions.invoke` call and the repo has no HTTP mocking. The JSON shape is pinned by `BugReport.toJson` (Task 2) and the function's parser (Task 5).
- `logBuffer` is one top-level instance fed in `main.dart` before `runApp`; `logBufferProvider` exposes it so tests override it.
- Device facts read the route from `routerProvider` (`routerDelegate.currentConfiguration.uri.path`), scrubbed.
- The function reads the allowlist with `supabaseAdmin.auth.admin.getUserById`, not JWT claims.

## Review Focus

1. A non-allowlisted user calling `report-bug` directly gets 403 and nothing is uploaded: Task 5 `rejects a user without the flag before any upload`.
2. Retry after a GitHub failure reuses the same file name, so the NAS gets one file: Task 5 `a retry overwrites the same file`, Task 6 `retry resends the same report id`.
3. A PostgrestException whose message carries row values never reaches the report: Task 1 `keeps only the type and code of an error`.
4. Sign-out while the mode is on hides the button: Task 3 `sign-out turns the mode off`.
5. Dropping the button short of the ✕ keeps the mode on and leaves the button where it was dropped: Task 7 `a drop away from the target keeps the mode`.

---

### Task 1: Log buffer and scrubber

**Files:**
- Create: `lib/features/bug_reports/domain/log_buffer.dart`
- Modify: `lib/main.dart` (feed `logBuffer` from `Logger.root.onRecord` in every build mode, before `SentryFlutter.init`)
- Test: `test/features/bug_reports/domain/log_buffer_test.dart`

**Interfaces:**
- Produces: `String scrubIds(String text)` (every UUID → `:id`); `class LogEntry { final DateTime time; final String level; final String logger; final String message; final String? error; final String? stack; Map<String, Object?> toJson(); }`; `class LogBuffer { LogBuffer({int capacity = 200}); void add(LogRecord record); List<LogEntry> get entries; }`; `final logBuffer = LogBuffer();`; `final logBufferProvider = Provider<LogBuffer>((_) => logBuffer);`

- [x] **Step 1: Write the failing tests**

```dart
test('keeps the last 200, oldest dropped', () {
  final b = LogBuffer();
  for (var i = 0; i < 205; i++) b.add(LogRecord(Level.INFO, 'm$i', 'x'));
  expect(b.entries.length, 200);
  expect(b.entries.first.message, 'm5');
});
test('replaces UUIDs with :id', () {
  expect(scrubIds('→ /contacts/3f2b8c1e-9a4d-4e6b-8c2f-1a2b3c4d5e6f/edit'),
      '→ /contacts/:id/edit');
});
test('keeps only the type and code of an error', () {
  final b = LogBuffer()..add(LogRecord(Level.WARNING, 'x', 'people',
      const PostgrestException(message: 'Ana 0612345678', code: '23505',
          details: 'Key (name)=(Ana)')));
  expect(b.entries.single.error, 'PostgrestException 23505');
  // AuthException: 'AuthException <code>'; any other: runtimeType only.
});
test('a stack trace only for SEVERE', () { /* INFO with stack → null; SEVERE → non-null, ids scrubbed */ });
test('toJson has time (UTC ISO), level, logger, message, error, stack', () { ... });
```

- [x] **Step 2: Run `flutter test test/features/bug_reports/domain/log_buffer_test.dart`** — Expected: FAIL, `log_buffer.dart` not found.
- [x] **Step 3: Implement `log_buffer.dart`** with a `ListQueue`; the UUID regex is `[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}`; messages go through `scrubIds`. In `main.dart`, add `Logger.root.onRecord.listen(logBuffer.add);` outside the `!kReleaseMode` block, with a comment pointing at #463.
- [x] **Step 4: Run the test** — Expected: PASS.
- [x] **Step 5: Commit** `feat(bug-reports): keep the last 200 log lines, cleaned (#463)`

### Task 2: Report model and device facts

**Files:**
- Create: `lib/features/bug_reports/domain/bug_report.dart`
- Create: `lib/features/bug_reports/data/device_facts.dart`
- Test: `test/features/bug_reports/domain/bug_report_test.dart`

**Interfaces:**
- Consumes: `LogEntry` (Task 1).
- Produces: `class BugReport { const BugReport({required String id, required String comment, required Uint8List screenshot, required Map<String, Object?> facts, required List<LogEntry> logs}); Map<String, Object?> toJson(); }` with keys `id`, `comment`, `screenshot` (base64), `facts`, `logs`; `Future<Map<String, Object?>> collectDeviceFacts({required String route, required Locale locale, required Size size, required Brightness brightness})` returning `appVersion`, `buildNumber`, `platform` (`kIsWeb ? 'web' : defaultTargetPlatform.name`), `osVersion` (null on web, else `Platform.operatingSystemVersion`), `locale`, `route` (scrubbed), `screen` (`'390x844'`), `brightness`.

- [x] **Step 1: Write the failing tests:** `toJson` base64-encodes the screenshot and round-trips through `base64Decode`; `logs` is a list of `LogEntry.toJson()` maps; `comment` is trimmed.
- [x] **Step 2: Run** `flutter test test/features/bug_reports/domain/bug_report_test.dart` — Expected: FAIL.
- [x] **Step 3: Implement** both files. `device_facts.dart` is under `data/` because it reads the platform; `dart:io` is imported only behind `kIsWeb` (use `package:flutter/foundation.dart` + a conditional import if `dart:io` breaks the web build).
- [x] **Step 4: Run the test and `flutter build web --release`** — Expected: PASS, web builds.
- [x] **Step 5: Commit** `feat(bug-reports): the report and the device facts it carries (#463)`

### Task 3: Allowlist flag and the mode

**Files:**
- Modify: `lib/features/auth/domain/account.dart` (add `final bool bugReporter;`, default `false`, doc comment: `app_metadata.bug_reporter`, set by hand, #463)
- Modify: `lib/features/auth/data/auth_repository.dart` (`bugReporter: bugReporterFrom(user.appMetadata)` in `account`; top-level `bool bugReporterFrom(Map<String, dynamic>? appMetadata)` next to `needsNameFrom`)
- Create: `lib/features/bug_reports/presentation/bug_report_mode.dart`
- Test: `test/features/auth/data/bug_reporter_test.dart`, `test/features/bug_reports/presentation/bug_report_mode_test.dart`

**Interfaces:**
- Consumes: `accountProvider`, `authRepositoryProvider.changes`.
- Produces: `final bugReportModeProvider = NotifierProvider<BugReportMode, bool>(BugReportMode.new);` with `void turnOn()`, `void turnOff()`; `bool bugReporterFrom(Map<String, dynamic>? appMetadata)`.

- [x] **Step 1: Write the failing tests:** `bugReporterFrom({'bug_reporter': true})` is true; `{'bug_reporter': 'true'}`, `{}`, `null` are false. Mode: starts false; `turnOn` → true; `turnOn` for an account with `bugReporter: false` stays false; **sign-out turns the mode off** (emit `AuthChange.signedOut` on `FakeAuthRepository`).
- [x] **Step 2: Run both tests** — Expected: FAIL.
- [x] **Step 3: Implement.** `BugReportMode.build` listens to `accountProvider` and returns false when the account is null or not a reporter.
- [x] **Step 4: Run** — Expected: PASS.
- [x] **Step 5: Commit** `feat(bug-reports): allowlist flag and the in-memory mode (#463)`

### Task 4: Seven taps on the version

**Files:**
- Modify: `lib/features/settings/presentation/settings_page.dart` (the footer `Text` at the version line)
- Modify: `lib/l10n/app_en.arb` (`bugReportsOn`: "Bug reports on")
- Test: `test/features/settings/presentation/settings_page_test.dart`

**Interfaces:**
- Consumes: `bugReportModeProvider` (Task 3), `Account.bugReporter`.

- [x] **Step 1: Write the failing tests:** seven taps on the version text (each 500 ms apart) for a `bugReporter` account turn the mode on and show "Bug reports on"; six taps don't; seven taps with a 2.1 s gap after the third don't; seven taps for a non-reporter do nothing and show no snackbar.
- [x] **Step 2: Run** — Expected: FAIL.
- [x] **Step 3: Implement** a small `ConsumerStatefulWidget` `_VersionFooter` in the same file: tap counter, a 2 s `Timer` reset, `GestureDetector(behavior: HitTestBehavior.opaque)` around the existing `Text`. Only a reporter's taps count. Run `flutter gen-l10n`.
- [x] **Step 4: Run** — Expected: PASS.
- [x] **Step 5: Commit** `feat(bug-reports): unlock with seven taps on the version (#463)`

### Task 5: The `report-bug` Edge Function

**Files:**
- Create: `supabase/functions/report-bug/handler.ts`, `supabase/functions/report-bug/index.ts`
- Modify: `supabase/config.toml` (`[functions.report-bug]` with `verify_jwt = false` and the same comment as `delete-account`)
- Test: `supabase/functions/report-bug/handler_test.ts`

**Interfaces:**
- Consumes: the JSON from `BugReport.toJson` (Task 2).
- Produces: `POST` → `200 { issue: number }`; `400 { error: 'invalid' }`; `403 { error: 'not_allowed' }`; `502 { error: 'upload_failed' | 'issue_failed' }`; `500 { error: 'not_configured' }` when a secret is missing. `handler.ts` exports `type Deps = { isReporter(id: string): Promise<boolean>; put(name: string, png: Uint8Array): Promise<string /* url */>; createIssue(title: string, body: string): Promise<number> }`, `parse(json: unknown): Report | null`, `issueTitle(comment: string): string`, `issueBody(r: Report, userId: string, screenshotUrl: string): string`, `handle(userId: string, json: unknown, deps: Deps, today: string): Promise<Response>`.

- [x] **Step 1: Write the failing Deno tests:** `rejects a user without the flag before any upload` (put/createIssue never called, 403); `parse` refuses an empty comment, 5001 chars, a non-PNG, a PNG over 5 MB, 201 logs, a non-UUID id; `issueTitle('Button is gone\nmore')` is `'Bug report: Button is gone'` and a 100-char line is cut to 60 with `…`; `issueBody` contains the comment, a facts table, the screenshot URL as a link (not `![]`), logs inside `<details>`, the user id, and no `@`; `a retry overwrites the same file` (two calls with one id → `put` called with the same `<today>-<id>.png` both times); upload failure → 502 and `createIssue` not called; issue failure → 502 `issue_failed`.
- [x] **Step 2: Run `deno test supabase/functions/report-bug`** — Expected: FAIL.
- [x] **Step 3: Implement `handler.ts`** (pure), then `index.ts`: `withSupabase({ auth: 'user' })`, 405 unless POST, secrets `GITHUB_ISSUES_TOKEN`, `NAS_WEBDAV_URL`, `NAS_WEBDAV_USER`, `NAS_WEBDAV_PASSWORD`; `isReporter` via `ctx.supabaseAdmin.auth.admin.getUserById(id)` → `app_metadata.bug_reporter === true`; `put` is a `fetch` PUT with Basic auth and `Content-Type: image/png`; `createIssue` POSTs to `https://api.github.com/repos/paulthvt/loomia/issues` with `labels: ['bug-report']`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`. Logs carry the user id and status codes only. A `ponytail:` comment on the orphan PNG when the issue fails.
- [x] **Step 4: Run `deno test supabase/functions` and `deno check supabase/functions/*/index.ts`** — Expected: PASS.
- [x] **Step 5: Commit** `feat(bug-reports): report-bug Edge Function to the NAS and GitHub (#463)`

### Task 6: Repository, sheet and sending

**Files:**
- Modify: `pubspec.yaml` (`feedback: 3.2.0` with its comment: screenshot, drawing and the panel around the app for bug reports, #463; imports the frozen `flutter/material.dart`, so its sheet is replaced and its toolbar themed)
- Create: `lib/features/bug_reports/data/bug_report_repository.dart`
- Create: `lib/features/bug_reports/presentation/bug_report_sheet.dart`
- Create: `lib/features/bug_reports/presentation/bug_report_controller.dart`
- Modify: `lib/app/theme/app_theme.dart` (`static FeedbackThemeData feedback(ColorScheme scheme)`)
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/bug_reports/presentation/bug_report_sheet_test.dart`, `test/features/bug_reports/presentation/bug_report_controller_test.dart`, `test/features/bug_reports/fake_bug_report_repository.dart`

**Interfaces:**
- Consumes: `BugReport`, `collectDeviceFacts` (Task 2), `logBufferProvider` (Task 1), `supabaseClientProvider`, `guardAuth`.
- Produces: `class BugReportRepository { BugReportRepository(SupabaseClient client); Future<int> send(BugReport report); }` (`functions.invoke('report-bug', body: report.toJson())`, reads `issue`); `final bugReportRepositoryProvider = Provider<BugReportRepository>(...)`; `Widget bugReportSheet(BuildContext context, OnSubmit onSubmit, ScrollController? scrollController)` matching `FeedbackBuilder`; `final bugReportControllerProvider = NotifierProvider<BugReportController, BugReportSendState>(...)` with `Future<void> submit(UserFeedback feedback, {required Map<String, Object?> facts})` and `Future<void> retry()`; `sealed class BugReportSendState` = `Idle` | `Sending` | `Sent(int issue)` | `Failed(BugReport report)`.
- ARB keys: `bugReportCommentLabel` "What went wrong?", `bugReportCommentHelper` "Posted publicly on GitHub: leave out names and numbers.", `bugReportSend` "Send", `bugReportSent` "Sent as #{number}" (int placeholder), `bugReportFailed` "Couldn't send", `bugReportRetry` "Retry".

- [x] **Step 1: Write the failing tests:** the sheet shows the label and helper, Send is disabled on an empty or blank comment, enabled after typing; tapping Send calls `onSubmit` with the trimmed text. Controller with `FakeBugReportRepository`: submit sends comment, the PNG bytes, the buffer's entries and a fresh UUID id → `Sent(123)`; failure → `Failed`; **retry resends the same report id** and the same bytes.
- [x] **Step 2: Run both** — Expected: FAIL.
- [x] **Step 3: Implement.** The sheet uses the theme's filled `TextField` (`minLines: 3`, `maxLines: 6`, `maxLength: 5000`) and a `FilledButton` (pill from the theme). `AppTheme.feedback`: `background: scheme.scrim.withValues(alpha: .4)`, `feedbackSheetColor: scheme.surface`, `activeFeedbackModeColor: scheme.primary`, `drawColors: [scheme.primary, scheme.tertiary, scheme.onSurface, scheme.surface]`, `bottomSheetDescriptionStyle`/`bottomSheetTextInputStyle` from the text theme.
- [x] **Step 4: Run** — Expected: PASS.
- [x] **Step 5: Commit** `feat(bug-reports): the sheet and sending, with retry (#463)`

### Task 7: The floating button, wiring and docs

**Files:**
- Create: `lib/features/bug_reports/presentation/bug_report_overlay.dart`
- Modify: `lib/app/app.dart` (`builder`: `BetterFeedback(theme: AppTheme.feedback(light scheme), darkTheme: AppTheme.feedback(dark scheme), themeMode: <same as app>, feedbackBuilder: bugReportSheet, child: BugReportOverlay(child: LaunchSplash(child: child!)))` inside the existing `AnnotatedRegion`)
- Modify: `lib/l10n/app_en.arb` (`bugReportButton` "Report a bug", `bugReportDismissTarget` "Turn off bug reports", `bugReportsOff` "Bug reports off"; reuse `tickUndo` only if its description fits, else `bugReportUndo` "Undo")
- Modify: `docs/architecture.md` (Logging: the log buffer and what it keeps; Edge Functions: `report-bug`), `README.md` (by-hand setup from the spec's "By hand, Paul")
- Test: `test/features/bug_reports/presentation/bug_report_overlay_test.dart`, `test/app/app_test.dart` (one case)

**Interfaces:**
- Consumes: `bugReportModeProvider` (Task 3), `bugReportControllerProvider`, `bugReportSheet`, `AppTheme.feedback` (Task 6), `collectDeviceFacts` (Task 2), `routerProvider`.
- Produces: `class BugReportOverlay extends ConsumerStatefulWidget { const BugReportOverlay({required Widget child}); }`

- [ ] **Step 1: Write the failing tests:** with the mode off there is no button; with it on the button shows on Today, Contacts and Settings (`pumpLoomia`, navigate via the router); tapping it opens the feedback panel and hides the button; dragging onto the ✕ turns the mode off, shows "Bug reports off", Undo turns it back on; **a drop away from the target keeps the mode** and the button stays at the drop point; a drop in the bottom band (not on the ✕) settles just above the band; with a snackbar showing, the snackbar's action is hit-testable (tap Undo while the button sits at its start position); the ✕ only shows while dragging; a controller `Sent(42)` shows "Sent as #42", `Failed` shows "Couldn't send" with Retry calling `retry()`.
- [ ] **Step 2: Run** — Expected: FAIL.
- [ ] **Step 3: Implement** the overlay as a `Stack` with a positioned 48 dp button (`primaryContainer`, bug icon, `Semantics` label) clamped to the safe area and kept out of the bottom band (bottom inset + navigation bar height + 88 dp), starting at the right edge just above it, and the ✕ target bottom centre while dragging (Figma `BugReportDropTarget`: Idle, Over filled with the ink colour and larger); drop within 48 px of the target's centre turns the mode off. Tap: collect facts (route from `routerProvider`), then `BetterFeedback.of(context).show((f) => controller.submit(f, facts: facts))`. Snackbars through `ScaffoldMessenger.of(context)` captured before any `await`. If the sheet doesn't see Loomia's `Theme` inside `builder`, move `BetterFeedback` above `MaterialApp` and wrap the sheet in `Theme` + `Localizations` (spec → Left to the builder).
- [ ] **Step 4: Run all checks** (`dart format .`, `flutter analyze`, `flutter test`, the Deno pair) — Expected: all pass. Run on an iOS simulator and Chrome: unlock, draw, Send against a local `supabase functions serve` with stub secrets.
- [ ] **Step 5: Commit** `feat(bug-reports): floating report button on every screen (#463)`
