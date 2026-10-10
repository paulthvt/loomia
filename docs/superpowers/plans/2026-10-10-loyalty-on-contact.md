# LRP on the contact Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The LRP becomes a fact about the person (`person.loyalty_since`). You can set it by hand from the contact page, or the workflow sets it when a loyalty step is ticked. Goals count people whose LRP started in the month. The contact page shows it, the history tells it, and the contacts list can filter on it (#255).

**Architecture:**
- **Server.** One server function, `set_loyalty`, owns the column and its history entries. `complete_step` calls it, so the two paths cannot differ. `month_progress` and `loyalty_forecast` read the column.
- **Client.** `PeopleRepository.setLoyalty` → `PeopleController.setLoyalty` → `showLoyalty` (the sheet) and a tappable line in the `ContactDetails` header. `StageFilter` gains an optional LRP chip.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase Postgres, pgTAP.

**Spec:** `docs/superpowers/specs/2026-10-10-loyalty-on-contact-design.md`. Figma: [LRP on the contact — #255](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=304-6527).

## Global Constraints

- **Schema** only through `supabase migration new <name>`. Never edit an applied migration.
- **Dart imports:** `package:loomia/...`. Material comes from `package:material_ui/material_ui.dart`.
- **Theme:** from `colorScheme`, `LoomiaColors`, `AppSpacing` and `AppRadii`. No literal sizes in widgets.
- **Copy:** English only, in `lib/l10n/app_en.arb`, every key with a description, then `flutter gen-l10n`. Business-model words go through a `select` on `model.name`.
- **Async handlers** read `ref` / `context` values (and the `ScaffoldMessenger`) before the first `await`.
- **Quality gate per task:** `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`. SQL tasks also run `supabase db reset && supabase test db`. Goldens come from CI only.
- **Branch:** `feature/255-loyalty-on-contact` off `main`. The PR body says `Closes #255`. Stage changed files by path only; the user keeps untracked local files.

## Rulings made while planning

- **Two migrations.** A value added by `alter type … add value` cannot be used in the transaction that adds it. Policies and checks naming `'loyalty_start'` would fail to apply. `loyalty_kinds` only adds the two enum values; `loyalty_on_person` does everything else.
- **`set_loyalty` is the "one internal function" from spec §1.** `complete_step` calls `perform public.set_loyalty(p_person, p_on, p_on)` before its own update, so the person it returns already carries `loyalty_since`. `set_loyalty` is `security definer` with its own owner check, so calling it straight is no more than the sheet does.
- **No future start day.** The picker's `last` is today. The server does not check: a future day only means it counts in a later month.
  `-- ponytail: no server check on a future loyalty_since; add one if another client appears.`
- **`loyalty_since` is not in `personToRow`.** Only `setLoyalty` writes it, so a stale copy saved by Edit never brings a stopped LRP back. This is the same rule as `photo_path`.
- **DB kind names are snake_case, Dart names camelCase.** `activityFromRow` looks a kind up through a two-entry map before `asNameMap()`. The app never writes these kinds (`byUser` is false, and `activityDraftToRow` asserts it), so only reading needs the map.
- **Loyalty entries carry no text.** The `Activity` assert allows that for them. The title comes from the kind ("Started LRP"). `kindLabel` returns null for them, so the meta is the day alone ("October 2"), as in Figma.
- **Header date is the locale's short month and day** (`MMMd`, with `yMMMd` when not this year). English reads "Since Oct 2", French "depuis le 2 oct.". The spec and Figma say "2 Oct"; this keeps the date format the history already uses.
- **One label key for the fact, the sheet title and the chip:** `loyaltyLabel`, "LRP" / "Loyalty orders".
- **Filter state** is a `bool _loyalty` next to `_stage` in `_ContactListState`. It applies only while the chip is shown, so stopping the last LRP never leaves an empty list behind a hidden chip.
- **Goals are not invalidated from contacts.** `completeStep` doesn't do it today either; the Goals tab reloads when opened.

## Review Focus

1. Setting, moving and stopping an LRP keeps the column and the history in step. The app cannot write, edit or delete a loyalty entry. Pinned in Task 1.
2. A customer counts once, in the month their LRP started. A backdated start and a start-then-stop in the same month don't count. Closed months don't move. Pinned in Task 1.
3. A loyalty step sets the LRP only when there is none. Pinned in Tasks 1 and 2 (fake).
4. Edit never writes `loyalty_since`. Pinned in Task 2.
5. Prospects get no LRP line; the chip shows only once someone has an LRP. Pinned in Tasks 4 and 5.

---

### Task 1: Database

**Files:**
- Create: `supabase/migrations/<ts>_loyalty_kinds.sql` (`supabase migration new loyalty_kinds`)
- Create: `supabase/migrations/<ts>_loyalty_on_person.sql` (`supabase migration new loyalty_on_person`)
- Create: `supabase/tests/loyalty_test.sql`

- [x] **Step 1: Write the failing test** `supabase/tests/loyalty_test.sql`, set up like `loyalty_step_test.sql`: users `…0a` and `…0b`, claims switched with `set local request.jwt.claims`. The person and workflow rows are inserted directly; one customer workflow has two steps with `loyalty_setup`. It asserts:
  - `has_column('public', 'person', 'loyalty_since')`.
  - `set_loyalty(p, '2026-10-02', '2026-10-10')`: `loyalty_since = '2026-10-02'`, and one `loyalty_start` entry on 10-02 with `text is null`.
  - The same call again changes nothing (still one entry).
  - `set_loyalty(p, '2026-09-20', …)`: the column and the start entry both move to 09-20, still one entry.
  - `set_loyalty(p, null, '2026-10-10')`: the column is null, and there is a `loyalty_stop` entry on 10-10.
  - As user `b`: `throws_ok` with `P0002` on `a`'s person.
  - As `a`, `throws_ok` for each of these:
    - an `insert into activity (person_id, kind) values (p, 'loyalty_start')`;
    - an `update activity set happened_on = …` on a loyalty entry, which returns 0 rows: check with `is((with u as (update … returning 1) select count(*) from u), 0::bigint)`;
    - a delete on a loyalty entry, which also affects 0 rows.
  - `complete_step` on the first loyalty step sets `loyalty_since` to `p_on` and writes a start entry. On the second loyalty step, `loyalty_since` is unchanged and there is no second start entry.
  - `month_progress('2026-10-01', '2026-10-01', '2026-11-01')` counts the person once in `loyalty`. A person with `loyalty_since = '2025-06-01'` counts 0. A start then stop in October counts 0.
  - `loyalty_forecast` skips a customer whose next step is a loyalty step once `loyalty_since` is set.
  - `close_month` for September, then setting an LRP in September: `loyalty_actual` keeps its frozen value.

  Run `supabase db reset && supabase test db`. It must fail with no column `loyalty_since`.

- [x] **Step 2: `loyalty_kinds`.**

```sql
-- LRP on the contact (#255), part 1. The kinds are added alone: a new enum
-- value cannot be used in the transaction that adds it.
alter type public.activity_kind add value 'loyalty_start';
alter type public.activity_kind add value 'loyalty_stop';
```

- [x] **Step 3: `loyalty_on_person`.** It contains, in order:
  - The column: `alter table public.person add column loyalty_since date;` with a comment: null means no LRP; written only by `set_loyalty`.
  - `entry_shape` dropped and recreated so the loyalty kinds may have no text: the rule from `20261003205256_order_amount.sql`, with `or kind in ('loyalty_start', 'loyalty_stop')` added to the text-required clause.
  - `activity_insert_own`, `activity_update_own` and `activity_delete_own` dropped and recreated with `kind not in ('stage', 'loyalty_start', 'loyalty_stop')` in place of `kind <> 'stage'`.
  - `set_loyalty(p_person uuid, p_since date, p_today date) returns public.person`. It is `language plpgsql security definer set search_path = ''`, and does the following:
    1. `select * into target from public.person where id = p_person and owner_id = (select auth.uid()) for update`. If nothing is found, raise with `P0002`.
    2. If `target.loyalty_since is not distinct from p_since`, return `target`.
    3. If `p_since` is null, insert a `loyalty_stop` entry on `p_today`.
    4. If `target.loyalty_since` is null, insert a `loyalty_start` entry on `p_since`.
    5. Otherwise, move the latest `loyalty_start` entry (`order by happened_on desc, created_at desc limit 1`) to `p_since`. If there is none (backfilled people), insert one.
    6. `update public.person set loyalty_since = p_since where id = p_person returning *`.

    Every insert passes `owner_id = target.owner_id`. Revoke execute from `public, anon`; grant it to `authenticated`.
  - `complete_step`: recreated from `20261004085415_loyalty_step.sql`, with `if step.loyalty_setup and target.loyalty_since is null then perform public.set_loyalty(p_person, p_on, p_on); end if;` after the step entry and before the update. Revoke and grant as before.
  - `month_progress`: recreated from `20261006131419_stage_since_import.sql`, with the loyalty column replaced by `(select count(*)::int from public.person p, bounds b where p.loyalty_since >= b.first_day and p.loyalty_since < b.next_month)`.
  - `loyalty_forecast`: recreated with `and p.loyalty_since is null`.
  - The backfill: `update public.person p set loyalty_since = f.first from (select person_id, min(happened_on) as first from public.activity where kind = 'step' and loyalty_setup group by person_id) f where f.person_id = p.id;`

- [x] **Step 4: Run** `supabase db reset && supabase test db`. Every test passes, including `goals_test.sql` and `loyalty_step_test.sql`. If an old count assertion relied on double-counting step entries, update it and say why in the commit.
- [x] **Step 5: Commit** `feat(db): loyalty_since on the person, set_loyalty (#255)`.

### Task 2: Dart model, repository and fakes

**Files:**
- Modify: `lib/features/contacts/domain/person.dart`, `lib/features/contacts/domain/activity.dart`
- Modify: `lib/features/contacts/data/people_repository.dart`, `lib/features/contacts/data/activity_repository.dart`
- Modify: `test/features/workflows/server_rule.dart`, `test/features/contacts/fake_people_repository.dart`
- Test: `test/features/contacts/data/people_repository_test.dart` (or the existing row test file for `personFromRow`), `test/features/contacts/data/activity_repository_test.dart`, `test/features/contacts/fake_people_repository_test.dart`

- [x] **Step 1: Failing tests:**
  - `personFromRow({..., 'loyalty_since': '2026-10-02'}).loyaltySince == DateTime(2026, 10, 2)`, and null when absent.
  - `personToRow(person)` has no `loyalty_since` key.
  - `activityFromRow({..., 'kind': 'loyalty_start', 'text': null})` gives `ActivityKind.loyaltyStart`.
  - In the fake: `completeStep` on a step with `loyaltySetup` sets `loyaltySince` to `on` once, and a second loyalty step leaves it. `setLoyalty` records `setLoyalty(id)`, sets or clears the field, and adds the start or stop entry to `activities.store`.
- [x] **Step 2: `Person`.** Add `final DateTime? loyaltySince;` with this doc: "The day their LRP started; null without one. Written only by `PeopleRepository.setLoyalty` and `complete_step`." Add it to the constructor and to `_copy`.
- [x] **Step 3: `ActivityKind`.**
  - Add `loyaltyStart` and `loyaltyStop`.
  - Change `byUser` to `!{stage, step, event, reminder, loyaltyStart, loyaltyStop}.contains(this)`.
  - Add `bool get isLoyalty => this == loyaltyStart || this == loyaltyStop;`.
  - In the `Activity` assert, let `isLoyalty` entries have null text.
- [x] **Step 4: Repository.**
  - In `personFromRow`: `loyaltySince: switch (row['loyalty_since']) { final String day => DateTime.parse(day), _ => null }`. Don't add it to `personToRow`, and extend that function's doc comment to say so.
  - Add `setLoyalty(String personId, DateTime? since, DateTime today)`, shaped like `completeStep`: rpc `set_loyalty` with `p_person`, `p_since` (`dayColumn` or null) and `p_today`, then `.select(_columns).single()`.
  - In `activityFromRow`: `const {'loyalty_start': ActivityKind.loyaltyStart, 'loyalty_stop': ActivityKind.loyaltyStop}[kind] ?? ActivityKind.values.asNameMap()[kind] ?? (throw …)`.
- [x] **Step 5: Fakes.**
  - `withServerFields` and `withLastContact` in `server_rule.dart` copy `loyaltySince`.
  - In the fake, `completeStep` applies the same rule as Task 1 Step 3, reading `WorkflowStep.loyaltySetup` (`lib/features/workflows/domain/workflow.dart`). Update that field's doc to "Ticking it starts their LRP, if they have none."
  - Add a fake `setLoyalty`.
- [x] **Step 6: Gate, then commit** `feat(contacts): loyaltySince on Person, setLoyalty (#255)`.

### Task 3: Copy and history rows

**Files:**
- Modify: `lib/l10n/app_en.arb` (then `flutter gen-l10n`)
- Modify: `lib/features/contacts/presentation/people_copy.dart`, `lib/features/contacts/presentation/history_section.dart`
- Test: `test/features/contacts/presentation/people_copy_test.dart`, `test/features/contacts/presentation/history_section_test.dart` (or the history widget test that exists)

- [x] **Step 1: ARB keys**, each with a description and the `model` String placeholder where it selects:
  - `loyaltyLabel`: `{model, select, doterra{LRP} other{Loyalty orders}}`
  - `contactLoyaltySince`: `{label} · Since {date}`, with `date` as DateTime, format `MMMd`
  - `contactLoyaltySinceWithYear`: the same, format `yMMMd`
  - `contactLoyaltyNone`: `{label} · None`
  - `loyaltySheetQuestion`: `When did it start?`
  - `loyaltySheetStop`: `{model, select, doterra{Stopped their LRP} other{Stopped their loyalty orders}}`
  - `historyLoyaltyStarted`: `{model, select, doterra{Started LRP} other{Started loyalty orders}}`
  - `historyLoyaltyStopped`: `{model, select, doterra{Stopped LRP} other{Stopped loyalty orders}}`
- [x] **Step 2: Failing tests.**
  - The `kindLabel` test becomes "null for stage and loyalty entries".
  - `activityTitle` returns "Started LRP" / "Stopped LRP" for dōTERRA and "Started loyalty orders" for Other.
  - `activityMeta` for a loyalty entry is the day alone.
  - The history widget test: a loyalty row has no edit or delete action.
- [x] **Step 3: Code.**
  - `kindLabel`: `ActivityKind.loyaltyStart || ActivityKind.loyaltyStop => null`.
  - `activityTitle`: before the stage switch, `if (activity.kind == ActivityKind.loyaltyStart) return l10n.historyLoyaltyStarted(model.name);`, and the same for stop.
  - `HistorySection`: `onTap` and `onDelete` are null when `activity.kind.isLoyalty`.
- [x] **Step 4: Gate, then commit** `feat(contacts): LRP rows in the history (#255)`.

### Task 4: The LRP line and sheet

**Files:**
- Create: `lib/features/contacts/presentation/loyalty_sheet.dart`
- Modify: `lib/features/contacts/presentation/people_controller.dart`, `contact_details.dart`, `contact_page.dart`
- Test: `test/features/contacts/presentation/loyalty_sheet_test.dart` (create), `contact_details_test.dart`, `people_controller_test.dart`

- [x] **Step 1: Failing tests.**
  - Controller: `setLoyalty(person, DateTime(2026, 10, 2), today)` replaces the person, and the history provider is invalidated (the same check as the `completeStep` test).
  - `ContactDetails`:
    - a customer with `loyaltySince` shows "LRP · Since Oct 2";
    - a customer without it shows "LRP · None";
    - a team member shows it;
    - a prospect doesn't;
    - Other reads "Loyalty orders · None";
    - tapping the line calls `onLoyalty`.
  - Sheet, with `FakePeopleRepository` behind the provider:
    - not set: "When did it start?", the field reads "Today, October 10", and there is no stop button. Save calls `setLoyalty(id)` with today and closes.
    - set: the field reads the stored day, and "Stopped their LRP" calls `setLoyalty` with null and closes.
    - a failure shows `peopleFailureCopy` and keeps the sheet open.
- [x] **Step 2: Controller.**

```dart
/// Starts, moves or stops (null [since]) their LRP; the server writes the
/// history entry.
Future<void> setLoyalty(Person person, DateTime? since, DateTime today) async {
  _replace(await _repository.setLoyalty(person.id, since, today));
  if (!ref.mounted) return;
  ref.invalidate(historyProvider(person.id));
}
```

- [x] **Step 3: Sheet.** `Future<void> showLoyalty(BuildContext context, Person person) => LoomiaDialog.show<void>(...)`, a `ConsumerStatefulWidget` copying `reminder_sheet.dart`'s saving, failure and actions pattern.
  - Title: `loyaltyLabel`. Body: `loyaltySheetQuestion`.
  - The day field reads `logWhenToday(day)` when the day is today, else `dayLabel`. Tapping it calls `pickDay(context, initial: _day, first: DateTime(2000), last: today())`.
  - Actions: Cancel, then Save (`material.saveButtonLabel`).
  - When `person.loyaltySince != null`, the `footer` is a `TextButton(loyaltySheetStop)`.
  - Read the model from `accountProvider`, as `HistorySection` does.
- [x] **Step 4: Header line.**
  - `ContactDetails` gains `required VoidCallback onLoyalty`. Under the `LoomiaChip`, when `person.stage != Stage.prospect`, add an `InkWell` with `borderRadius: AppRadii…`, a 48 px minimum height and `Semantics(button: true)`.
  - Its content is a `Row(mainAxisSize: min)`: the text (`contactLoyaltySince` / `…WithYear` / `contactLoyaltyNone`, styled like the `SectionHeader` action, primary, as in Figma) and `Icon(Icons.chevron_right)` sized to the text.
  - `ContactPage` passes `onLoyalty: () => unawaited(showLoyalty(context, person))`.
  - Update every other `ContactDetails(` call site (previews, tests) with a no-op.
- [x] **Step 5: Gate, then commit** `feat(contacts): LRP line and sheet on the contact page (#255)`.

### Task 5: LRP filter on the contacts list

**Files:**
- Modify: `lib/features/contacts/presentation/stage_filter.dart`, `contact_list.dart`
- Test: `test/features/contacts/presentation/stage_filter_test.dart` (create if absent), `contact_list_test.dart`

- [x] **Step 1: Failing tests.**
  - `StageFilter.shows(Stage.customer, loyalty: true, person)` is true only for a customer with `loyaltySince`, and `loyalty: false` keeps the stage rule.
  - List: with nobody on LRP there is no "LRP" chip. With one, tapping the chip shows only them, and Customers + LRP combine.
  - With Other, the chip reads "Loyalty orders".
- [x] **Step 2: `StageFilter`.**
  - Add `this.loyaltyLabel` (null hides the chip), `this.loyalty = false` and `this.onLoyaltyChanged`.
  - After the `ChoiceChip`s, add `if (loyaltyLabel != null) FilterChip(label: Text(loyaltyLabel!), selected: loyalty, onSelected: onLoyaltyChanged)`.
  - `shows(Stage? stage, Person person, {bool loyalty = false}) => (stage == null || person.stage == stage) && (!loyalty || person.loyaltySince != null)`.
- [x] **Step 3: `ContactList`.**
  - Add `bool _loyalty = false` and `final anyLoyalty = widget.people.any((p) => p.loyaltySince != null)`.
  - Filter with `loyalty: _loyalty && anyLoyalty`.
  - Pass `loyaltyLabel: anyLoyalty ? l10n.loyaltyLabel(widget.model.name) : null`.
  - `ContactList` is a plain `StatefulWidget`, so it takes `required this.model` (a `BusinessModel`). `ContactsPage` passes `ref.watch(accountProvider)?.businessModel ?? BusinessModel.other`, as `ContactPage` does. Update the preview and test call sites.
- [x] **Step 4: Gate, then commit** `feat(contacts): LRP filter on the contacts list (#255)`.

### Task 6: Previews, goldens, docs, PR

**Files:**
- Modify: `lib/features/contacts/presentation/contacts_preview.dart`
- Modify: `docs/superpowers/specs/2026-10-02-goals-design.md` (one line under *Which step is a loyalty setup*, pointing to the #255 spec)
- Regenerate through CI: `test/goldens/contact_mobile_light.png`, `contact_mobile_dark.png`, `contacts_mobile_*.png`, `team_member_mobile_light.png`, `contacts_desktop_light.png`, plus any new one

- [ ] **Step 1:** Give the sample customer in `contacts_preview.dart` `loyaltySince: DateTime(2026, 10, 2)`, so the contact preview shows the line and the list preview shows the chip. Add one `@Preview` for the sheet, `loyaltySheetMobileLight`.
- [ ] **Step 2:** Run the gate, push the branch, and regenerate the goldens through CI (testing steering). Open each PNG and check it against the Figma frames before committing them.
- [ ] **Step 3:** Run `graphify update .`. Open the PR "feat(contacts): LRP on the contact, counted in goals" with `Closes #255`. List the manual step: `supabase db push` after merge.
