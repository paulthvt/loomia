# Reminders Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A person can carry one-off reminders ("Call back about the diffuser", due on a day) outside any workflow. They show under Next step on the contact page, join Today's Priority once due, and ticking one writes a `reminder` history entry. Log something can add one in the same save (#217: #218, #219).

**Architecture:** A `reminder` table embedded in the book's select (`reminder(id, text, due_on)` on `person`), so `Person.reminders` arrives with the people Today and the contact page already read. Writes go through `PeopleRepository` / `PeopleController` (add, edit, delete on the table; tick through the `complete_reminder` RPC, which writes the entry and deletes the row in one transaction). `Due` becomes a sealed class with `DueStep` and `DueReminder`; `dueToday` mixes both. One sheet, `showReminder`, adds and edits; its day picker, `ReminderDayField`, is reused by Log something, whose Remind me save goes through `log_with_reminder`.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase (Postgres, PostgREST), pgTAP.

**Spec:** `docs/superpowers/specs/2026-10-08-reminders-design.md`. Figma: [Reminders — #217](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=273-5276).

## Global Constraints

- No new dependency. Don't touch `pubspec.lock`. Stage only changed files by path (never `git add -A` / `git add .`): the user keeps untracked local files.
- Schema only through `supabase migration new <name>`; never edit an applied migration. The new table gets RLS, four owner policies, `revoke all ... from anon, authenticated` then explicit grants, and a pgTAP test, in the same PR.
- "Today" is the device's: `today()`. Days are `date` columns through `dayColumn()`; a bare date parses as local midnight.
- Dart: `package:loomia/...` imports; Material from `package:material_ui/material_ui.dart`; the domain imports no Flutter.
- Theme from `colorScheme`, `LoomiaColors`, `AppSpacing`, `AppRadii`; the ring is `ActionItem`'s.
- Copy: English only, in `lib/l10n/app_en.arb`, every key with a description; `flutter gen-l10n`. No concatenation in the UI. Informal register.
- Async handlers read `ref` / `context` values (and the `ScaffoldMessenger`) before the first `await`; failures through `writePeople` or `FormError`.
- The Today headline keeps counting people.
- Quality gate per task: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`; SQL tasks also `supabase db reset && supabase test db`. Goldens from CI only.
- Branches: `feature/218-reminders` (Tasks 1–7), then `feature/219-remind-me-on-log` off `main` once #218 is merged (Tasks 8–10). PR bodies `Closes #218` / `Closes #219`.

## Rulings made while planning

- **No `reminders/` feature folder.** The type lives in `person.dart`, the writes on `PeopleRepository` / `ActivityRepository`, the sheet in `contacts/presentation/reminder_sheet.dart`. A folder would hold one typedef and one sheet; the book is what carries reminders. The spec's Naming row says so.
- **`Person` copies through one private helper.** `withStatus` and the new `withReminders` both call `_copy(...)`, instead of a second thirty-field copy.
- **Reminders are sorted on the client**, not by PostgREST: `personFromRow` and `withReminders` sort by `due_on`, then `created_at`. `Reminder` keeps `createdAt` so an add or edit re-sorts locally without a fetch.
- **Add, edit and delete are not optimistic.** They wait for the server, then swap the person's reminders, like every other book write but `setStatus`.
- **Ticking is `completeReminder` → `_replace(person)`** plus `historyProvider(person.id)` invalidated, exactly like `completeStep`.
- **Today's slots and busy set are keyed by `Due.key`** (the step or reminder id) instead of the person id. A ticked step's slot still slides to the next step: the next step has a new key, so it slides in as a new row, which is what the step row already does inside its slot (`ValueKey(step.step.id)`).
- **`DueReminder` before `DueStep`** on the same day for the same person, as in the Figma Today frame.
- **The Today mock's "0 of 3 done", "about 10 minutes" and "See all"** are template leftovers; Today does not have them and this plan does not add them.
- **No confirmation on deleting a reminder**, from the edit sheet only.
- **The pgTAP file is `reminders_test.sql`**; Task 8 appends the `log_with_reminder` assertions to it.

## Review Focus

1. Another owner's reminder is invisible and cannot be inserted on another owner's person; `anon` has no grant. Pinned in Task 1.
2. `complete_reminder` writes one `reminder` entry, deletes the row, moves `last_contact_on`, and refuses a reminder already gone (a second device). Pinned in Task 1.
3. A paused person's due reminder is on Today; a future one is not; a person with a step and a reminder due has two rows and counts once in the headline. Pinned in Tasks 4–5.
4. Ticking a person's reminder on Today leaves their step's ring live, and the reverse. Pinned in Task 5.
5. Next step lists reminders in every workflow state, including paused and no workflow ("No workflow"). Pinned in Task 7.
6. Log something with Remind me saves both or neither. Pinned in Tasks 8 and 10.

---

## #218 — table, contact page, Today

### Task 1: The `reminder` table and `complete_reminder`

**Files:**
- Create: `supabase/migrations/<timestamp>_reminders.sql` (`supabase migration new reminders`)
- Create: `supabase/tests/reminders_test.sql`

- [x] **Step 1: Write the failing pgTAP test** `supabase/tests/reminders_test.sql`, shaped like `loyalty_step_test.sql`: two users `…0a` and `…0b`; as `a`, a person `…a1`; then `plan(9)`:
  - `lives_ok`: insert a reminder for `…a1` (`'Call back', '2026-10-15'`).
  - `throws_ok … '23514'`: a blank text (`'  '`).
  - `is(due_on)`: the row reads back `2026-10-15`.
  - `select public.complete_reminder(<id>, '2026-10-09')`; `results_eq` on `select kind::text, text, happened_on from activity where person_id = …a1` → `('reminder', 'Call back', '2026-10-09')`.
  - `is(count(*) from reminder, 0)`: the row is gone.
  - `is((select public.last_contact_on(p) from person p where id = …a1), '2026-10-09')`.
  - `throws_ok … 'P0002'`: `complete_reminder` on the same id again.
  - `a` inserts another reminder; with claims switched to `b`, `is(count(*) from reminder, 0)`: `b` sees none.
  - as `b`: `throws_ok … '23503'`: insert a reminder on `…a1`. Its `owner_id` defaults to `b`, so the composite FK `(person_id, owner_id)` finds no person.
- [x] **Step 2: Run** `supabase db reset && supabase test db`. Expected: `reminders_test.sql` fails (no table); `schema_rls_test.sql` passes.
- [x] **Step 3: Write the migration.**

```sql
-- Reminders (#217): a line of text for one person, due on a day, outside any
-- workflow. Ticked once: the history keeps what was done, the row goes.
alter type public.activity_kind add value 'reminder';

create table public.reminder (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  person_id uuid not null,
  text text not null check (length(trim(text)) > 0),
  due_on date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (person_id, owner_id)
    references public.person (id, owner_id) on delete cascade
);

create index reminder_person_id_owner_id_idx
  on public.reminder (person_id, owner_id);

create trigger reminder_set_updated_at before update on public.reminder
  for each row execute function public.set_updated_at();

alter table public.reminder enable row level security;
create policy reminder_select_own on public.reminder
  for select to authenticated using (owner_id = (select auth.uid()));
create policy reminder_insert_own on public.reminder
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy reminder_update_own on public.reminder
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy reminder_delete_own on public.reminder
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.reminder from anon, authenticated;
grant select, insert, delete on public.reminder to authenticated;
grant update (text, due_on) on public.reminder to authenticated;

-- Ticks a reminder: the history entry and the delete, in one transaction.
-- Gone already (ticked on another device, another owner's): refused.
create function public.complete_reminder(p_reminder uuid, p_on date)
returns public.person
language plpgsql security invoker set search_path = '' as $$
declare
  target public.reminder;
  done public.person;
begin
  select * into target from public.reminder where id = p_reminder for update;
  if not found then
    raise exception 'reminder % not found', p_reminder using errcode = 'P0002';
  end if;
  insert into public.activity (person_id, kind, text, happened_on)
    values (target.person_id, 'reminder', target.text, p_on);
  delete from public.reminder where id = p_reminder;
  select * into done from public.person where id = target.person_id;
  return done;
end $$;

revoke execute on function public.complete_reminder(uuid, date) from public, anon;
grant execute on function public.complete_reminder(uuid, date) to authenticated;
```

  `alter type ... add value` cannot be used in the same transaction as the value: the function body is not checked until it runs, so this is fine, but if `supabase db reset` complains, split the enum value into its own migration file first (`reminder_kind`).
- [x] **Step 4: Run** `supabase db reset && supabase test db`. Expected: all pass.
- [x] **Step 5: Commit** `feat(reminders): reminder table and complete_reminder`.

### Task 2: `Reminder` on `Person`, the `reminder` kind, the repository

**Files:**
- Modify: `lib/features/contacts/domain/person.dart`, `lib/features/contacts/domain/activity.dart`, `lib/features/contacts/presentation/people_copy.dart`, `lib/features/contacts/data/people_repository.dart`, `lib/l10n/app_en.arb`
- Modify: `test/features/contacts/fake_people_repository.dart`
- Test: `test/features/contacts/data/people_repository_test.dart` (row mapping), `test/features/contacts/fake_people_repository_test.dart`

- [ ] **Step 1: Failing tests.** In `people_repository_test.dart`: `personFromRow` with `'reminder': [{'id': 'r2', 'text': 'B', 'due_on': '2026-10-12', 'created_at': '…T10'}, {'id': 'r1', 'text': 'A', 'due_on': '2026-10-10', …}]` gives `reminders` ids `['r1', 'r2']` and `dueOn == DateTime(2026, 10, 10)`; no `reminder` key gives `const []`. `activityFromRow` with `kind: 'reminder'` gives `ActivityKind.reminder`, and `ActivityKind.reminder.byUser` is false.
- [ ] **Step 2: Run** `flutter test test/features/contacts/data`. Expected: compile errors.
- [ ] **Step 3: Implement.**
  - `person.dart`: `typedef Reminder = ({String id, String text, DateTime dueOn, DateTime createdAt});` with a doc line. `Person` gains `this.reminders = const []` / `final List<Reminder> reminders;` ("Open reminders, soonest first; from the book's select"). Move `withStatus`'s body into `Person _copy({ProspectStatus? Function()? status, List<Reminder>? reminders})` and add `Person withReminders(List<Reminder> reminders) => _copy(reminders: sortedReminders(reminders));`. Top-level `List<Reminder> sortedReminders(Iterable<Reminder>)`: by `dueOn`, then `createdAt`.
  - `activity.dart`: `ActivityKind.reminder`; `byUser` also excludes it.
  - `people_copy.dart` `kindLabel`: `ActivityKind.reminder => l10n.activityKindReminder`.
  - `app_en.arb`: `activityKindReminder` "Reminder" — "Kind of history entry: a reminder the user set and marked done. The entry's title is the reminder's text."
  - `people_repository.dart`: `_columns = '*, current_step_id, due_on, last_contact_on, reminder(id, text, due_on, created_at)'`; `personFromRow` reads `reminders: sortedReminders([for (final r in (row['reminder'] as List?) ?? const []) reminderFromRow(r as Map<String, dynamic>)])`; `reminderFromRow` top-level. Methods:

```dart
  /// A reminder for [personId]; the row as saved.
  Future<Reminder> addReminder(String personId, String text, DateTime dueOn) =>
      guardPeople(() async => reminderFromRow(await _client
          .from('reminder')
          .insert({'person_id': personId, 'text': text.trim(), 'due_on': dayColumn(dueOn)})
          .select('id, text, due_on, created_at')
          .single()));

  Future<Reminder> updateReminder(String id, String text, DateTime dueOn) => …update({'text': …, 'due_on': …}).eq('id', id)…;

  Future<void> deleteReminder(String id) =>
      guardPeople(() => _client.from('reminder').delete().eq('id', id));

  /// Ticks it: the history entry and the delete, in one transaction. One
  /// already gone (another device) is refused.
  Future<Person> completeReminder(String id, DateTime on) => …rpc('complete_reminder', params: {'p_reminder': id, 'p_on': dayColumn(on)}).select(_columns).single()…;
```

  - `FakePeopleRepository`: a `Map<String, List<Reminder>> reminders` store; `_served` attaches `reminders[id]`; the four methods record `addReminder(personId)` etc., `completeReminder` throws `PeopleFailure.unknown` for an unknown id, removes it and sets `lastContactOn: on` through `_with`. A test in `fake_people_repository_test.dart` pins the tick.
- [ ] **Step 4: Run** `flutter gen-l10n && flutter test`. Expected: pass (the `kindLabel` switch is exhaustive: analyze catches a missed case).
- [ ] **Step 5: Commit** `feat(reminders): reminders on Person and the repository`.

### Task 3: `PeopleController` writes

**Files:**
- Modify: `lib/features/contacts/presentation/people_controller.dart`
- Test: `test/features/contacts/presentation/people_controller_test.dart`

- [ ] **Step 1: Failing tests** with `FakePeopleRepository`: `addReminder(person, 'Call back', day)` → the book's person has it, sorted before a later one; `editReminder(person, reminder, 'X', day)` replaces it in place and re-sorts; `deleteReminder(person, reminder)` removes it; `completeReminder(person, reminder, today)` drops it, sets `lastContactOn`, invalidates `historyProvider(person.id)` (a listener counts a rebuild, as the `completeStep` test does); a failure rethrows `PeopleFailure` and leaves the book as it was.
- [ ] **Step 2: Run** the file. Expected: fail.
- [ ] **Step 3: Implement** next to `completeStep`:

```dart
  Future<void> addReminder(Person person, String text, DateTime dueOn) async {
    final added = await _repository.addReminder(person.id, text, dueOn);
    _withReminders(person.id, (list) => [...list, added]);
  }

  Future<void> editReminder(Person person, Reminder reminder, String text, DateTime dueOn) async {
    final saved = await _repository.updateReminder(reminder.id, text, dueOn);
    _withReminders(person.id, (list) => [for (final r in list) r.id == saved.id ? saved : r]);
  }

  Future<void> deleteReminder(Person person, Reminder reminder) async {
    await _repository.deleteReminder(reminder.id);
    _withReminders(person.id, (list) => [...list.where((r) => r.id != reminder.id)]);
  }

  /// The history entry and the delete, on the server; the person as it left them.
  Future<void> completeReminder(Person person, Reminder reminder, DateTime today) async {
    _replace(await _repository.completeReminder(reminder.id, today));
    if (ref.mounted) ref.invalidate(historyProvider(person.id));
  }

  void _withReminders(String id, List<Reminder> Function(List<Reminder>) change) => _change(
    (people) => [for (final p in people) p.id == id ? p.withReminders(change(p.reminders)) : p],
  );
```

- [ ] **Step 4: Run** `flutter test`. Expected: pass.
- [ ] **Step 5: Commit** `feat(reminders): add, edit, delete and tick through the book`.

### Task 4: `Due` with steps and reminders

**Files:**
- Modify: `lib/features/today/domain/due.dart`
- Modify (callers): `lib/features/today/presentation/today_preview.dart`, `test/features/today/today_goals_test.dart`, `test/features/today/today_events_test.dart`
- Test: `test/features/today/domain/due_test.dart`

- [ ] **Step 1: Failing tests** in `due_test.dart` (existing two kept, reading `(row as DueStep).step`):
  - a reminder due today and one late stay, one tomorrow falls out;
  - a paused person's due reminder stays (their step does not);
  - a person with no workflow and a due reminder is in;
  - one person with a reminder and a step on the same late day gives two rows, reminder first; `key`s are the reminder and step ids;
  - order across people: by day, then name.
- [ ] **Step 2: Run** the file. Expected: compile errors.
- [ ] **Step 3: Implement.**

```dart
/// Something worth doing with someone today: a workflow step or a reminder.
sealed class Due {
  const Due(this.person);
  final Person person;

  /// The day it is due, local midnight.
  DateTime get day;

  /// The step's or the reminder's id: one person can have both on Today.
  String get key;
}

final class DueStep extends Due {
  const DueStep(super.person, this.step);
  final OnStep step;
  @override DateTime get day => step.due;
  @override String get key => step.step.id;
}

final class DueReminder extends Due {
  const DueReminder(super.person, this.reminder);
  final Reminder reminder;
  @override DateTime get day => reminder.dueOn;
  @override String get key => reminder.id;
}
```

  `dueToday` collects `DueStep`s as today and, for every person (paused or not), `DueReminder`s with `!dueOn.isAfter(today)`; sorts by `day`, then `searchKey(name)`, then `person.id` (keeps a person's rows together), then reminders before the step, then the reminder order. Update the three callers' `_due` helpers to `DueStep(person, OnStep(...))`.
- [ ] **Step 4: Run** `flutter test test/features/today`. Expected: the domain passes; `today_page.dart` fails to compile until Task 5 (do Step 3 of Task 5's `_row` switch in the same commit if needed to keep the tree green).
- [ ] **Step 5: Commit** together with Task 5.

### Task 5: Today's Priority, mixed

**Files:**
- Modify: `lib/features/today/presentation/today_page.dart`, `lib/features/today/presentation/today_preview.dart`, `lib/l10n/app_en.arb`
- Test: `test/features/today/today_page_test.dart`

- [ ] **Step 1: Failing widget tests** (with the fake book):
  - Claire with a late reminder "Send her the price list" and a late step: two rows, "Send her the price list · Reminder" above the step's reason; the headline reads "One person is worth a message today".
  - ticking the reminder's ring calls `completeReminder(…)` on the fake and leaves the step ring enabled while it is in flight (a `Completer` in the fake holds it);
  - ticking the step leaves the reminder ring enabled;
  - a late reminder shows the `DateChip` ("2 days late"); one due today has none.
- [ ] **Step 2: Run.** Expected: fail.
- [ ] **Step 3: Implement.**
  - `todayHeadline`'s count becomes `{for (final d in due) d.person.id}.length`.
  - `_busy` holds `Due.key`; `_tick(Due due)` switches: `DueStep(:final person, :final step)` → `completeStep`, `DueReminder(:final person, :final reminder)` → `completeReminder(person, reminder, today())`, both through `writePeople`.
  - `_slots` / `_slotted` key by `due.key`.
  - `_row` switches on the `Due`: the step row unchanged (`step.due`); the reminder row:

```dart
      DueReminder(:final person, :final reminder) => ActionItem(
        key: ValueKey(reminder.id),
        name: person.name,
        reason: l10n.todayReminderReason(reminder.text),
        chip: reminder.dueOn.isBefore(day) ? DateChip(dueLabel(l10n, reminder.dueOn, day)) : null,
        onOpen: () => widget.onOpen(person),
        onResolve: () => widget.onTick(due),
        resolved: widget.busy.contains(due.key),
        resolveLabel: l10n.reminderMarkDone(reminder.text),
      ),
```

  - `app_en.arb`: `todayReminderReason` "{text} · Reminder" ("Second line of a reminder row on Today: what the user wrote, then the word Reminder, e.g. 'Call back about the diffuser · Reminder'."), `reminderMarkDone` "Mark '{text}' done" (screen-reader label of the ring).
  - `today_preview.dart`: the mobile and desktop samples gain one `DueReminder` (Sarah Lemaire, "Call back about the diffuser", due today), as in the Figma frame. Goldens change: regenerate through CI.
- [ ] **Step 4: Run** `flutter gen-l10n && flutter test`. Expected: pass but the Today goldens (Linux only; locally skipped).
- [ ] **Step 5: Commit** `feat(today): due reminders in Priority`.

### Task 6: The reminder sheet

**Files:**
- Create: `lib/features/contacts/presentation/reminder_sheet.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/contacts/presentation/reminder_sheet_test.dart`

- [ ] **Step 1: Failing widget tests** (the `form_harness.dart` pattern, the fake book, today 2026-10-08):
  - new: Save disabled-by-validation with an empty What ("Say what to do."); type "Call back", tap In a week, the line under the chips reads "Thursday, October 15"; Save → fake `addReminder(p1)` with `DateTime(2026, 10, 15)`; the sheet closes;
  - Tomorrow by default;
  - edit: the text and day prefilled, the matching chip selected (a day that matches none: Pick a day selected); Save → `updateReminder`; Delete → `deleteReminder`, no confirm;
  - a `PeopleFailure` keeps the sheet open with the failure copy.
- [ ] **Step 2: Run.** Expected: fail.
- [ ] **Step 3: Implement.**
  - `Future<void> showReminder(BuildContext context, Person person, {Reminder? editing})` → `LoomiaDialog.show` with a `ConsumerStatefulWidget` form like `_LogActivityForm` (`_saving`, `_failure`, `FormError`, Cancel / Save, Delete when editing). Writes `peopleProvider(owner).notifier.addReminder / editReminder / deleteReminder`, read before the first `await`.
  - Public `ReminderDayField({required DateTime value, required DateTime today, required ValueChanged<DateTime> onChanged, required String label})`: `LabeledField(label:)` over a `Wrap` of `ChoiceChip`s for `+1, +3, +7, +14` days (`addDays` from `progress.dart`) and Pick a day (`pickDay(context, initial: value, first: today, last: addDays(today, 365 * 2))`), then the day written under them (`dayLabel`-style long date: `MaterialLocalizations.formatFullDate`). Selected chip: the preset whose day equals `value`, else Pick a day.
  - `app_en.arb`, each with a description: `reminderNewTitle` "Remind me", `reminderEditTitle` "Edit reminder", `reminderWhat` "What", `reminderWhatRequired` "Say what to do.", `reminderWhen` → reuse `logWhen`; `reminderTomorrow` "Tomorrow", `reminderInDays` "{count, plural, =1{Tomorrow} other{In {count} days}}" (3), `reminderInWeeks` "{count, plural, =1{In a week} other{In {count} weeks}}", `reminderPickDay` "Pick a day", `reminderDelete` → reuse `historyDeleteConfirm`.
- [ ] **Step 4: Run** `flutter gen-l10n && flutter test`. Expected: pass.
- [ ] **Step 5: Commit** `feat(contacts): the reminder sheet`.

### Task 7: Reminders under Next step

**Files:**
- Modify: `lib/features/contacts/presentation/next_step_section.dart`, `lib/features/contacts/presentation/contacts_preview.dart` (if it shows `NextStepCard`), `lib/l10n/app_en.arb`
- Test: `test/features/contacts/presentation/next_step_card_test.dart`

- [ ] **Step 1: Failing widget tests** on `NextStepCard`:
  - two reminders (one 2 days late, one in 5 days) above the step: titles in order, reasons "2 days late" and "Due in 5 days", no `DateChip`; Add a reminder below the card;
  - the same with `Paused`, `Done` and `null` progress; with `null`, the body reads "No workflow";
  - tapping a reminder's ring calls `onTickReminder(reminder)`; tapping the row calls `onEditReminder(reminder)`; Add a reminder calls `onAddReminder`;
  - `NextStepSection` while workflows load: the reminders and Add a reminder still show above the spinner card.
- [ ] **Step 2: Run.** Expected: fail.
- [ ] **Step 3: Implement.**
  - `NextStepCard` gains `onTickReminder`, `onEditReminder`, `onAddReminder` and `busyReminders` (`Set<String>`, default empty). Its `build` becomes a `Column`: one `SlideSwap(child: ActionItem(key: ValueKey(r.id), name: person.name, title: r.text, reason: dueLabel(l10n, r.dueOn, today), onOpen: () => onEditReminder(r), onResolve: () => onTickReminder(r), resolved: busyReminders.contains(r.id), resolveLabel: l10n.reminderMarkDone(r.text)))` per reminder with `AppSpacing.ms` gaps, then the existing `SlideSwap` card, then `Align(start, TextButton.icon(icon: Icons.add_rounded, label: l10n.reminderAdd))`. The `SectionHeader` moves above the reminders, so it is not repeated: `_step` and `_Panel` take `showHeader: false` from here (or the header is lifted out of them; pick whichever leaves the smaller diff). With `null` progress and reminders, body `l10n.nextStepNoWorkflow`.
  - `NextStepSection`: `_busyReminders` set; `onTickReminder` → `_runReminder(r.id, (people) => people.completeReminder(person, r, today()))` through `writePeople`; `onEditReminder` → `showReminder(context, person, editing: r)`; `onAddReminder` → `showReminder(context, person)`. `_Waiting` gets the same reminders above it (pass them through, or render them from the section before `_Waiting`).
  - `app_en.arb`: `reminderAdd` "Add a reminder", `nextStepNoWorkflow` "No workflow".
  - Preview: a `NextStepCard` sample with the two reminders, as in Figma 273:5278. Goldens: regenerate through CI.
- [ ] **Step 4: Run** `flutter gen-l10n && dart format . && flutter analyze && flutter test`. Expected: pass but goldens.
- [ ] **Step 5: Commit** `feat(contacts): reminders under Next step`.
- [ ] **Step 6: PR** `feat(reminders): reminders on contacts and Today`, `Closes #218`; regenerate goldens through CI (testing steering), open the PNGs, commit them.

---

## #219 — Remind me in Log something

### Task 8: `log_with_reminder`

**Files:**
- Create: `supabase/migrations/<timestamp>_log_with_reminder.sql`
- Modify: `supabase/tests/reminders_test.sql`

- [ ] **Step 1: Failing assertions** appended (raise `plan`): `log_with_reminder(…a1, 'call', 'Called her', '2026-10-08', null, 'Call Claire back', '2026-10-15')` → one `call` entry and one reminder; with `p_remind = ' '` → `throws_ok '23514'` and no new `call` entry (count unchanged); with `p_kind = 'stage'` → refused by the activity policy, nothing written.
- [ ] **Step 2: Run** `supabase db reset && supabase test db`. Expected: fail.
- [ ] **Step 3: Implement.**

```sql
-- Log something with Remind me (#219): the entry and the reminder together,
-- so a failure leaves neither and a retry cannot log the entry twice.
create function public.log_with_reminder(
  p_person uuid, p_kind public.activity_kind, p_text text, p_on date,
  p_amount numeric, p_remind text, p_remind_on date
) returns void
language sql security invoker set search_path = '' as $$
  insert into public.activity (person_id, kind, text, happened_on, amount)
    values (p_person, p_kind, nullif(trim(p_text), ''), p_on, p_amount);
  insert into public.reminder (person_id, text, due_on)
    values (p_person, trim(p_remind), p_remind_on);
$$;

revoke execute on function public.log_with_reminder(uuid, public.activity_kind, text, date, numeric, text, date) from public, anon;
grant execute on function public.log_with_reminder(uuid, public.activity_kind, text, date, numeric, text, date) to authenticated;
```

  Match the text normalisation to `activityDraftToRow` (read it first; if it does not `nullif`, neither does this).
- [ ] **Step 4: Run.** Expected: pass.
- [ ] **Step 5: Commit** `feat(reminders): log_with_reminder`.

### Task 9: `addWithReminder` through the history

**Files:**
- Modify: `lib/features/contacts/data/activity_repository.dart`, `lib/features/contacts/presentation/history_controller.dart`, `test/features/contacts/fake_activity_repository.dart`
- Test: `test/features/contacts/presentation/history_controller_test.dart`

- [ ] **Step 1: Failing test:** `HistoryController.add(draft, remind: (text: 'Call back', dueOn: day))` calls the fake's `addWithReminder(p1)`, then reloads the history (the entry is listed) and invalidates `peopleProvider` (the book reloads, so the reminder arrives with it).
- [ ] **Step 2: Run.** Expected: fail.
- [ ] **Step 3: Implement.** `ActivityRepository.addWithReminder(String personId, ActivityDraft draft, String remind, DateTime remindOn)` → `rpc('log_with_reminder', params: {...})`, returns void. `HistoryController.add(ActivityDraft draft, {({String text, DateTime dueOn})? remind})`: without `remind`, as today; with it, call `addWithReminder`, then `ref.invalidateSelf()` instead of appending (the RPC returns nothing), then `_reloadBook()`. The fake records `addWithReminder(personId)` and stores the activity.
- [ ] **Step 4: Run** `flutter test`. Expected: pass.
- [ ] **Step 5: Commit** `feat(reminders): log an entry and a reminder in one save`.

### Task 10: The Remind me switch

**Files:**
- Modify: `lib/features/contacts/presentation/log_activity_sheet.dart`, `lib/l10n/app_en.arb`
- Test: `test/features/contacts/presentation/log_activity_sheet_test.dart`

- [ ] **Step 1: Failing widget tests:**
  - the switch "Remind me" is off; Save writes `add(p1)` as before;
  - on, after a Call: "Remind me on" chips with In a week selected and "Thursday, October 15" under them; "Reminder" prefilled "Call Claire back"; Save → `addWithReminder(p1)`;
  - on, after a Note: prefilled "Follow up with Claire"; switching kind after editing the reminder text keeps the typed text;
  - a blank reminder text: "Say what to do.", nothing saved;
  - not shown when editing an entry or logging an own order.
- [ ] **Step 2: Run.** Expected: fail.
- [ ] **Step 3: Implement.** In `_LogActivityFormState`: `_remind = false`, `_remindOn = addDays(today(), 7)`, `_remindText` controller, `_remindEdited` (set by its `onChanged`). Under What, when `person != null && _editing == null`: `SwitchListTile(title: Text(l10n.logRemindMe), value: _remind, onChanged: …)` (copy the loyalty switch row's styling if the sheet has one, as in Figma), then, when on, `ReminderDayField(label: l10n.logRemindOn, …)` and a `LabeledField(label: l10n.logReminder)` `TextFormField` with `reminderWhatRequired`. While `!_remindEdited`, the text follows the kind: `call` → `l10n.logRemindCallBack(firstName(person))`, else `l10n.logRemindFollowUp(firstName(person))`. `_submit` passes `remind:` to `HistoryController.add` when on.
  - `app_en.arb`: `logRemindMe` "Remind me", `logRemindOn` "Remind me on", `logReminder` "Reminder", `logRemindCallBack` "Call {name} back", `logRemindFollowUp` "Follow up with {name}", each with a description and the `name` placeholder.
- [ ] **Step 4: Run** `flutter gen-l10n && dart format . && flutter analyze && flutter test`. Expected: pass.
- [ ] **Step 5: Commit** `feat(contacts): Remind me in Log something`.
- [ ] **Step 6: PR** `feat(contacts): Remind me in Log something`, `Closes #219`. After both are merged, close #217 and `supabase db push` by hand.
