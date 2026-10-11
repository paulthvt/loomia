# Notification settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The user turns the daily summary on from a one-time card on Today or from Settings → Notifications, picks its time and days, and sees the time zone it follows; the zone tracks the phone (#270).

**Architecture:** `NotificationsRepository` reads and upserts the `notification_settings` row; `notificationSettingsProvider(owner)` holds it (null = never answered) and saves optimistically. `Push` gains `available`, `allowed()`, `ask()`. `PushScope` writes the device zone on launch when it moved. A pure `NotificationSettingsForm` is the screen; `NotificationSettingsSection` wires it. `TodayView` gets a `nudge` slot below Priority.

**Tech Stack:** Flutter 3.47 (`material_ui`), `flutter_riverpod` 3, `flutter_timezone` 5.1.1, `intl`.

**Spec:** `docs/superpowers/specs/2026-10-11-notifications-design.md` §3. Figma: [Notifications — #267](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=311-6975).

## Global Constraints

- **Dart imports:** `package:loomia/...`; Material from `package:material_ui/material_ui.dart`.
- **Copy:** English only in `lib/l10n/app_en.arb`, each key described.
- **Quality gate per task:** `dart format .`, `flutter analyze`, `flutter test`. Goldens from CI only.
- **Branch:** `feature/270-notification-settings`. PR body `Closes #270`.

## Rulings made while planning

- **No row is "not answered".** The card shows while the provider holds null, push is available and an account is signed in. Either answer saves a row, so the card goes on every device.
- **Settings toggled on with the OS refusing stays on** (spec: the warning says where to fix it). The Today card saves a refusal as off. The screen re-reads the permission on resume, for a return from the phone's settings.
- **Optimistic saves.** The value shows at once; a failure puts the saved one back and shows `FormError`. An unchanged value saves nothing.
- **Zone fallback `UTC`** when `flutter_timezone` fails, marked `ponytail:`; never written over a stored zone (`deviceTimeZoneProvider` is null then, `followDevice` skips).
- **The harness has no push by default** (`FakePush(isAvailable: false)`), so the card stays out of every existing Today test.
- **Weekday names from `DateFormat.E`**, order from `MaterialLocalizations.firstDayOfWeekIndex`.

## Review Focus

1. The card asks once, and only where push works. Pinned by `nudge_card_test.dart`.
2. Every change saves once and survives a failure honestly. Pinned by `notification_settings_section_test.dart`.
3. The zone follows the phone, and never creates a row. Pinned by `push_scope_test.dart`.

---

### Task 1: Model and repository

- [x] `NotificationSettings` (defaults, `fromRow`/`toRow`), `weekdayOrder`, `toggleDay`; `notification_settings_test.dart`.
- [x] `NotificationsRepository.load/save` (upsert; checked as `authenticated` against the column grants).

### Task 2: Push and the controller

- [x] `Push.available`, `allowed()`, `ask()`; `FakePush` grows `isAvailable`, `isAllowed`, `grant`, `asked`.
- [x] `notificationSettingsProvider`, `deviceTimeZoneProvider`, `pushAvailableProvider`; `PushScope` calls `followDevice`.

### Task 3: Settings → Notifications

- [x] Route `/settings/notifications`, `SettingsSection.notifications`, the Preferences row (time or Off).
- [x] `NotificationSettingsForm` per the Figma; `NotificationSettingsSection` with load, error, ask, resume check.
- [x] Previews: on, off (dark), permission off.

### Task 4: Today card

- [x] `NudgeCard`, `TodayView.nudge`, `TodayPage._nudge` / `_answerNudge`. Preview `Nudge — light`.

### Task 5: Docs

- [x] architecture.md *Push*, README *Push notifications*.
