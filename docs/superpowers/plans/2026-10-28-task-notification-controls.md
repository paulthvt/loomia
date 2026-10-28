# Task notification controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Tasks switch in Settings → Notifications and a bell beside a task's time; a task pushes only when both are on.

**Architecture:** Two boolean columns, both `default true` (`notification_settings.task_enabled`, `task.alert`), filtered in `claim_task_alerts` and copied to the next repeating task. The app maps them onto `NotificationSettings.tasks` and `Task.alert` / `TaskDraft.alert`, adds a switch to `NotificationSettingsForm` and a bell to the task form's time field. The Edge Function doesn't change.

**Tech Stack:** Flutter (Riverpod, material_ui), Supabase Postgres + pgTAP.

**Spec:** `docs/superpowers/specs/2026-10-28-task-notification-controls-design.md` (issue #389). Figma: "Task notifications — #389", node 463:14966.

## Global Constraints

- Migration additive only; safe for the released app. `supabase db push` before or with the app release. No Edge Function deploy.
- Both columns `not null default true`.
- Copy in `lib/l10n/app_en.arb` only, every key with a description; informal register.
- Icons from the app's set (`Icons.*_rounded`), theme values only, no hard-coded colours or sizes.
- Branch `feature/389-task-notifications`; Conventional Commits; PR body `Closes #389` and the **Database** section filled.
- Checks before done: `dart format .`, `flutter analyze` (No issues found!), `flutter test`. pgTAP via `supabase test db` when the local stack runs, else CI's "Supabase migrations" job.

## Rulings made while planning

- `NotificationSettings.any` keeps meaning summary or month-end (time and days, and `PushScope`'s launch prompt). A new `NotificationSettings.pushes` (`any || tasks`) decides the form's "notifications are off on this phone" line. The launch prompt stays on `any`: anyone with a timed task was already asked when they set it.
- Settings list row (`settings_page.dart:351`): the time when `any`; **Tasks** when only `tasks`; **Off** otherwise.
- The switch-off line is two keys, a sentence and a link, so it translates: `taskAlertsOff` "Task notifications are off." and the link `taskAlertsTurnOn` "Turn them on in Settings". The Figma frame shows only "Settings" as the link; the whole phrase as the link is the translation-safe form.
- `alert` joins the `task_set_updated_at` column list: toggling the bell on a task made by a tick is an edit, so #376's undo keeps it.
- The bell's on colour is the `IconButton`'s selected colour (`colorScheme.primary`), via `isSelected` + `selectedIcon`.

## Review Focus

- The released app upserts `notification_settings` without `task_enabled`: the switch must keep its value (Task 1, pgTAP).
- A bell turned off on the task a tick made, then Undo: the tick's task must survive as edited (Task 1, pgTAP).
- Postponing a task with the bell off keeps it off (Task 3).
- Settings still loading, or no row: the bell is not greyed (Task 3).
- Web (no push on this device): the bell still shows and saves; pushes go to her phones (Task 3).

---

### Task 1: Migration and pgTAP

**Files:**
- Create: `supabase/migrations/<timestamp>_task_alert_controls.sql` (`supabase migration new task_alert_controls`)
- Create: `supabase/tests/task_alert_controls_test.sql`

**Interfaces:**
- Produces: columns `notification_settings.task_enabled boolean`, `task.alert boolean`; `claim_task_alerts`, `complete_task`, `delete_task` with the same signatures.

- [ ] **Step 1: Write `task_alert_controls_test.sql`** (style of `task_time_test.sql`: users, a Paris settings row, tasks due `2026-10-27 14:00`, `pg_temp.claimed(p_now)`), asserting:
  - `alert` and `task_enabled` default to true on a fresh row;
  - a task with `alert = false` is not claimed at `2026-10-27 13:00:30+00`; the same with `alert = true` is;
  - with `task_enabled = false`, nothing of that owner is claimed;
  - `upsert` of a settings row without `task_enabled` (columns of `toRow` before this change) keeps `task_enabled = false`;
  - `complete_task` on a weekly task with `alert = false` makes a next task with `alert = false`; `delete_task(..., false)` likewise;
  - updating only `alert` changes `updated_at`, and leaves `alerted_for` as it was;
  - as `authenticated`, the owner can `update` `alert` and `task_enabled`; `alerted_for` still not.
- [ ] **Step 2: Run** `supabase test db` → FAIL (columns missing).
- [ ] **Step 3: Write the migration:** add both columns `not null default true`; `grant update (alert) on public.task to authenticated`; `grant update (task_enabled) on public.notification_settings to authenticated`; recreate `task_set_updated_at` with `alert` in its `update of` list; `create or replace` `complete_task` and `delete_task` from `20261026213314_task_time.sql`, adding `alert` to each `insert` beside `due_time`; `create or replace claim_task_alerts` with `and s.task_enabled and t.alert` in its `where`. Header comment links the spec.
- [ ] **Step 4: Run** `supabase test db` → all pass, `schema_rls_test.sql` included.
- [ ] **Step 5: Commit** `feat(db): a switch and a bell for task pushes`.

### Task 2: The Tasks switch

**Files:**
- Modify: `lib/features/notifications/domain/notification_settings.dart`
- Modify: `lib/features/notifications/data/notifications_repository.dart:19` (select list)
- Modify: `lib/features/notifications/presentation/notification_settings_form.dart:60-96`
- Modify: `lib/features/settings/presentation/settings_page.dart:349-353`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/notifications/domain/notification_settings_test.dart`, `test/features/notifications/presentation/notification_settings_section_test.dart`

**Interfaces:**
- Produces: `NotificationSettings({…, bool tasks = true})`, `final bool tasks`, `copyWith({bool? tasks})`, `bool get pushes => any || tasks`; row key `task_enabled`.

- [ ] **Step 1: Failing tests:**
  - unit: `fromRow` reads `task_enabled: false` into `tasks == false`; `toRow` writes `'task_enabled'`; `==` differs on `tasks`;
  - widget `'the Tasks switch: on by default, off saves'`: no row → the **Tasks** tile is on; tap it → `notifications.saved.single.tasks == false`, `push.asked == 0`;
  - widget `'turning Tasks on asks the phone'`: row with `tasks: false`, `FakePush()` → tap → `push.asked == 1`, saved `tasks == true`;
  - widget `'only Tasks on: time and days stay off'`: `NotificationSettings(timeZone: 'Europe/Paris')` → the time tile is disabled;
  - widget `'only Tasks on, refused: the warning'`: same settings, `FakePush(isAllowed: false)` → `'notificationsPermissionOff'` copy shows;
  - widget `'the Settings row shows Tasks when only tasks push'`.
- [ ] **Step 2: Run** `flutter test test/features/notifications` → FAIL.
- [ ] **Step 3: Implement:** the field everywhere in the model; `task_enabled` in the repository's select; a third `SwitchListTile` (title `notificationsTasks` "Tasks", subtitle `notificationsTasksBody` "At the time set on a task, when its bell is on.") wired through `turn`; the warning condition `settings.pushes && allowed == false`; the Settings row `switch` gains `final s? when s.tasks => l10n.notificationsTasks` after the `any` case.
- [ ] **Step 4: Run** `flutter test test/features/notifications test/features/settings` → PASS.
- [ ] **Step 5: Commit** `feat(notifications): a Tasks switch`.

### Task 3: The bell

**Files:**
- Modify: `lib/features/tasks/domain/task.dart` (`Task`, `TaskDraft`)
- Modify: `lib/features/tasks/data/task_repository.dart` (`_columns`, `_draftColumns`, `taskFromRow`)
- Modify: `lib/features/tasks/presentation/task_sheet.dart` (state, `_postpone`, `_save`, `_timeField`)
- Modify: `test/features/tasks/fake_task_repository.dart` (carry `alert` like `dueTime`)
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/tasks/presentation/task_sheet_test.dart` (the `time` group)

**Interfaces:**
- Consumes: `NotificationSettings.tasks` (Task 2), `notificationSettingsProvider(owner)`.
- Produces: `Task.alert` (`bool`, constructor default `true`), `TaskDraft.alert` (`bool`), column `alert`.

- [ ] **Step 1: Failing tests** in the `time` group, tooltips found by `find.byTooltip`:
  - `'a time shows the bell, on'`: pick a time → `Don't notify me` present; no time → no bell;
  - `'the bell off saves alert false'`: tap it → tooltip `Notify me at this time`; save → `alert == false`;
  - `'off stays off when the time changes'`: editing `alert: false`, pick another time → still off; saved `alert == false`;
  - `'a time added again starts on'`: editing `alert: false`, ✕ then add a time → on;
  - `'Tasks off: the bell greyed and the line'`: `FakeNotificationsRepository(NotificationSettings(tasks: false, timeZone: 'Europe/Paris'))` → the bell's `onPressed == null`, `Task notifications are off.` and `Turn them on in Settings` show, and `Notifications are off on this phone.` doesn't even with `FakePush(isAllowed: false)`; tapping the link opens Settings → Notifications;
  - `'no settings row: not greyed'`: default fake → bell enabled, no line;
  - `'bell back on asks the phone'`: editing timed `alert: false`, `FakePush()` → tap bell, save → `push.asked == 1`; editing timed `alert: true`, save → `push.asked == 0` (the existing `'a task that had a time asks nothing again'` keeps passing);
  - `'postponing keeps the bell off'`: past its time, `alert: false` → In 15 min → `alert == false`;
  - `'on web: the bell shows and saves'`: no push here → bell present, toggles, saves.
- [ ] **Step 2: Run** `flutter test test/features/tasks` → FAIL.
- [ ] **Step 3: Model and data:** `alert` on `Task` (default `true`) and `TaskDraft`; `alert` in `_columns`, `'alert': draft.alert` in `_draftColumns`, `row['alert'] as bool? ?? true` in `taskFromRow`. Update every `TaskDraft` literal (`task_sheet.dart:99` passes `editing.alert`).
- [ ] **Step 4: Form:** `late bool _alert = widget.editing?.alert ?? true`; `_pickTime` sets `_alert = true` when `_time` was null; the draft carries `_alert`. Arming: `final notifies = _time != null && _alert; final notified = editing?.dueTime != null && (editing?.alert ?? false); final arms = notifies && !notified;` replacing `_save`'s `arms`. In `_timeField`, put the chip and an `IconButton(isSelected: _alert, icon: Icon(Icons.notifications_off_outlined), selectedIcon: Icon(Icons.notifications_active_rounded), tooltip: _alert ? taskAlertOn : taskAlertOff, onPressed: tasksOff || _saving ? null : toggle)` in a `Row`; `tasksOff` reads `ref.watch(notificationSettingsProvider(owner)).value?.tasks == false` (loading or no row: not off). Under it, when `time != null && tasksOff`: the `taskAlertsOff` text and a `TextButton` `taskAlertsTurnOn` doing what the existing Settings link does; the existing permission line only when `!tasksOff`.
- [ ] **Step 5: Copy:** `taskAlertOn` "Don't notify me", `taskAlertOff` "Notify me at this time", `taskAlertsOff` "Task notifications are off.", `taskAlertsTurnOn` "Turn them on in Settings", each described.
- [ ] **Step 6: Run** `dart format . && flutter analyze && flutter test` → No issues, all pass.
- [ ] **Step 7: Commit** `feat(tasks): a bell to choose whether a timed task notifies`.

### Task 4: Ship

- [ ] **Step 1:** Tick this plan's boxes; note any deviation at the end.
- [ ] **Step 2:** `git push -u origin feature/389-task-notifications`; open the PR (title under 70 chars, `Closes #389`, Database: `supabase db push` before or with the release, additive, safe for the released app, no function deploy). Goldens: regenerate through CI only if a preview changed.
- [ ] **Step 3:** CI green (format/analyze/test, Supabase migrations).
