# Month-end push Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** One push per month-end window, at the user's summary time, saying what Today's close-and-plan card says, for users who turned it on in Settings or on the plan step (#148).

**Architecture:** `pending_ritual` puts the card's rule in Postgres; `claim_month_rituals` claims one `notification_sent` row per window (`kind 'month_ritual'`, `local_date` = month to plan). The `send-daily-summary` function runs a second job with a titled, loc-key message, only to devices whose `push_kinds` include it. The card's copy becomes `push*` keys shared with the push. The app gains a `ritual` setting, a second switch in Settings and one on the plan step.

**Tech Stack:** Postgres (pgTAP), Deno Edge Function, Flutter 3.47 (`material_ui`), `flutter_riverpod` 3, `intl`.

**Spec:** `docs/superpowers/specs/2026-10-13-month-end-push-design.md`. Figma: [Month-end push — #148](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=334-8738).

## Global Constraints

- **Schema** only through `supabase migration new`; never edit an applied migration.
- **Functions** `security invoker`, `search_path = ''`, `service_role` only, as in `20261011162920_daily_summary.sql`.
- **Dart imports:** `package:loomia/...`; Material from `package:material_ui/material_ui.dart`.
- **Copy:** English in `app_en.arb` with descriptions. French only moves with the renamed keys (§ Rulings).
- **Quality gate per task:** `dart format .`, `flutter analyze`, `flutter test`; `deno test supabase/functions`; `supabase test db`. Goldens from CI only.
- **Branch:** `feature/148-month-end-push`. PR body `Closes #148`.

## Rulings made while planning

- **Renamed keys keep their French.** `ritualCloseAndPlan`, `ritualBody`, `ritualPlanBody` are renamed in `app_en.arb` and `app_fr.arb`. `translation_sources.json` is not touched: `stale()` only sends keys missing from the target or whose recorded English changed, so the sync records the moved keys without retranslating them. `pushRitualPlanTitle` takes the French of `goalsPlanMonth`, the same English. The tool's English fallback covers any key a language still lacks.
- **Column names `to_close` / `to_plan`**, not `close` / `plan`: `close` is an SQL keyword.
- **The plan-step switch** is `RitualReminder` (providers) over `RitualReminderSwitch` (pure, previewed), in `lib/features/notifications/presentation/ritual_reminder.dart`. Its preview is the switch alone: on the 390×844 plan preview it sits below the fold.
- **`register_device` is dropped and recreated** with `p_kinds … default '{daily_summary}'`: an old app calling it with three named arguments resolves to the new one.
- **The ritual job runs after the summary job**, in the same request; a failure in one doesn't skip the other (each caught and logged on its own).
- **Plan-step switch refused by the OS saves nothing**, unlike Settings (which saves on and shows the warning): on the plan step there is no warning to explain an "on" that does nothing.
- **Month names in the sender** use `timeZone: 'UTC'` on a `YYYY-MM-01T00:00:00Z` date, so no zone can shift the month.

## Review Focus

1. Never twice a window, never with nothing pending, never to an app that can't render it. Pinned by `month_ritual_test.sql` and `handler_test.ts`.
2. The SQL rule matches `pendingRitual`. Pinned by the mirrored cases in `month_ritual_test.sql`.
3. The push says what the card says. Pinned by the shared keys and `push_strings_test.dart`.

---

### Task 1: Migrations and pgTAP

- [x] `supabase migration new month_ritual_kind`: `alter type public.notification_kind add value 'month_ritual';`
- [x] `supabase migration new month_ritual_push`, per spec §1:
  ```sql
  alter table public.notification_settings
    add column ritual_enabled boolean not null default false;
  grant update (ritual_enabled) on public.notification_settings to authenticated;

  alter table public.device_token
    add column push_kinds public.notification_kind[] not null
      default '{daily_summary}';

  drop function public.register_device(text, public.device_platform, text);
  -- recreated with p_kinds public.notification_kind[] default '{daily_summary}',
  -- push_kinds set on insert and on conflict; same revoke/grant.

  create function public.pending_ritual(p_owner uuid, p_on date)
  returns table (close date, plan date, closes boolean)
  language sql stable security invoker set search_path = '' as $$
    with w as (
      select case
        when p_on >= (date_trunc('month', p_on) + interval '1 month'
                      - interval '3 days')::date
          then date_trunc('month', p_on)::date
        when extract(day from p_on) <= 5
          then (date_trunc('month', p_on) - interval '1 month')::date
      end as close
    ), c as (
      select w.close, (w.close + interval '1 month')::date as plan,
        exists (select 1 from public.month_plan m
                where m.owner_id = p_owner and m.month = w.close
                  and m.closed_at is null) as closes
      from w where w.close is not null
    )
    select c.close, c.plan, c.closes from c
    where c.closes or not exists (
      select 1 from public.month_plan m
      where m.owner_id = p_owner and m.month = c.plan)
  $$;
  ```
  `claim_month_rituals(p_now)` copies `claim_daily_summaries`: `ritual_enabled`, `cross join lateral public.pending_ritual(s.owner_id, l.local::date) r`, insert `(owner_id, 'month_ritual', r.plan, p_now)`, returning `owner_id, close, plan, closes`. `release_month_ritual(p_owner, p_plan)`. Revoke from `public, anon, authenticated`; grant to `service_role`.
- [x] `supabase/tests/month_ritual_test.sql` (`begin; select plan(N); … rollback;`, fixtures as in `daily_summary_test.sql`): every case of spec §4, each `pendingRitual` case of `test/features/goals/domain/goal_rules_test.dart` mirrored by date.
- [x] `device_token_test.sql`: `register_device` without kinds gives `{daily_summary}`, with both kinds stores both, a re-register replaces them.

### Task 2: Push strings and copy

- [x] `pushStrings`: for every English `push*` key a language lacks, write the English parts under that language's native key. Test in `test/tool/push_strings_test.dart`: an `fr` ARB without `pushX` gets `push_x_fr` with the English text.
- [x] Rename in `app_en.arb`, `app_fr.arb`, `translation_sources.json`: `ritualCloseAndPlan` → `pushRitualTitle`, `ritualBody` → `pushRitualBody`, `ritualPlanBody` → `pushRitualPlanBody`. Add `pushRitualPlanTitle` "Plan {month}" (DateTime, `MMMM`). Descriptions say: shown on Today's card and as the month-end push; no names.
- [x] `RitualCard` reads the new keys (title in the plan-only case: `pushRitualPlanTitle`). Existing ritual card and Today tests pass unchanged in text.
- [x] `dart run tool/push_strings.dart`; commit `push_strings.xml` and `Localizable.strings`.
- [x] Settings and plan-step copy: `notificationsRitual` "Month-end review", `notificationsRitualBody` "When it's time to close the month and plan the next.", `planReminder` "Remind me when {month} ends", `planReminderBody` "One note at {time} when it's time to close it."

### Task 3: Sender

- [x] `message.ts`: `ritualMessage(token, locale, claim: {close, plan, closes})` per spec §2, `data.type 'month_ritual'`, Android `title_loc_key/args` + `body_loc_key/args`, APNs `title-loc-key/args` + `loc-key/args`; `monthName(date, locale)` via `Intl.DateTimeFormat(locale, {month: 'long', timeZone: 'UTC'})`.
- [x] `handler.ts`: `handle(deps, job)` where `job = {kind, claim(), release(claim), message(claim, device)}`; `Device` gains `push_kinds`; devices without `job.kind` are filtered out before sending. `Deps.send` takes `unknown`.
- [x] `index.ts`: select `push_kinds`; run the summary job (`claim_daily_summaries`, `release_daily_summary`, `summaryMessage`) then the ritual job (`claim_month_rituals`, `release_month_ritual`, `ritualMessage`), each in its own try; respond `{summary, ritual}`.
- [x] `handler_test.ts`: EN "Close September, plan October" args `['September', 'October']`, FR `['septembre', 'octobre']`, plan-only keys and args, no `title`/`body` text fields; a device listing only `daily_summary` gets no ritual and its claim is kept; existing summary tests through the new signature.

### Task 4: Settings model and Settings screen

- [x] `NotificationSettings.ritual` (default false): `copyWith`, `fromRow`/`toRow` (`ritual_enabled`), `==`, `hashCode`; `NotificationsRepository.load` selects it. Round-trip test in `notification_settings_test.dart`.
- [x] `DeviceRepository.register` sends `p_kinds: pushKinds` (const in `device_repository.dart`). Pinned on the SQL side by `device_token_test.sql`; the constant itself has no Dart test.
- [x] `NotificationSettingsForm`: second `SwitchListTile` in the first group; `onEnable` becomes `ValueChanged<NotificationSettings>?` (the settings to save before asking), used by both switches; time and days enabled, and the warning shown, while `enabled || ritual`. `NotificationSettingsSection` adapted.
- [x] Settings row: time while `enabled || ritual`, else Off. `PushScope._onLaunch` asks while either is on.
- [x] Widget tests in `notification_settings_section_test.dart`: turn on the review alone (asks, saves `ritual: true`), time enabled with only the review on, the row shows the time.

### Task 5: Plan-step switch

- [x] `RitualReminder` (`lib/features/notifications/presentation/ritual_reminder.dart`, a `ConsumerWidget`, `month` parameter): nothing unless `pushAvailableProvider` is true and settings have loaded; value `settings?.ritual ?? false`; on: `push.ask()`, granted → `save((settings ?? NotificationSettings(timeZone: zone)).copyWith(ritual: true))`; off: save `ritual: false`. A failure shows the snackbar copy as `_answerNudge` does.
- [x] `PlanForm` gains `Widget? reminder`, placed above Save; `PlanPage` and `ClosePage` pass `RitualReminder(month: plan month)`.
- [x] Tests `ritual_reminder_test.dart`: hidden without push, refused permission saves nothing, granted with no row creates one with summary off and the device zone, off saves off.
- [x] Previews `Notifications / Month-end review — light` and `Notifications / Plan reminder — light`; goldens from CI (with the changed Notifications ones).

### Task 6: Docs

- [x] architecture.md *Push*: the second kind, `push_kinds`, the per-kind job. Notifications spec: the "Kinds" row points here.
- [x] Goals spec: the "Push reminder for the ritual" row points here.
- [x] README *Push notifications*: nothing new to set up; deploy order (db push, then functions deploy).
