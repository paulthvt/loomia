# Edit history entries Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tap a history entry to edit it; a stage entry's day is the person's "since", kept in sync both ways.

**Architecture:** One migration gives `activity` an owner update policy with a column-level grant (`text`, `happened_on`, `amount`) and adds a `security definer` trigger that moves the latest stage entry's `created_at` when `person.stage_since` changes. The app gains `ActivityRepository.update`, `HistoryController.edit`, `PeopleRepository/Controller.setStageSince`, and an edit mode in the existing Log something sheet, opened by tapping an entry.

**Tech Stack:** Flutter, flutter_riverpod (no codegen), Supabase Postgres + pgTAP.

**Spec:** `docs/superpowers/specs/2026-10-06-edit-history-design.md`

## Global Constraints

- Material from `package:material_ui/material_ui.dart`, imports `package:loomia/...` only.
- No hard-coded colours, radii, font sizes or spacing: `AppSpacing.*`, `Theme.of(context)`.
- Copy: English in `lib/l10n/app_en.arb` only, every key with a description; informal register.
- Schema changes only via `supabase migration new`; never the dashboard.
- No new dependency.
- Branch `feature/187-edit-history`; Conventional Commits; PR body `Closes #187`.
- Before claiming done: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`, `supabase test db` (local DB: `supabase migration up --local` first — `supabase start` skips new migrations on an existing volume).
- Pickers: `pickDay` from `lib/core/ui/pick_day.dart` (Cupertino on iOS, Material elsewhere).

## Review Focus

1. Editing "since" from the contact edit form (#184) moves the history's stage entry too — same trigger; covered by the SQL test on `stage_since` updates, whichever screen wrote it.
2. A stage entry whose day is already before the previous stage entry (put there through the edit form): the picker must not assert (`initial < first`). Task 4 clamps `first` and tests it.
3. Picking the same day for a stage entry must not move its time to midnight (would reorder it against a same-day entry). Task 4 skips the write and tests it.
4. Saving an edit with the Step kind must not trip `activityDraftToRow`'s `byUser` assert. Task 2 uses a separate row builder; Task 4 tests a step edit.
5. The sheet opened on a history that is still loading or failed: only the stage path needs the list; Task 5 only makes entries tappable once the list is loaded (entries are only drawn then), so nothing to add — checked.

---

## File Structure

- Create `supabase/migrations/<timestamp>_edit_history.sql` — policy, grant, trigger.
- Create `supabase/tests/edit_history_test.sql` — pgTAP.
- Modify `lib/features/contacts/domain/activity.dart` — doc comment ("Never edited" goes).
- Modify `lib/features/contacts/data/activity_repository.dart` — `update`, `activityEditToRow`.
- Modify `lib/features/contacts/data/people_repository.dart` — `setStageSince`.
- Modify `lib/features/contacts/presentation/history_controller.dart` — `edit`.
- Modify `lib/features/contacts/presentation/people_controller.dart` — `setStageSince`.
- Modify `lib/features/contacts/presentation/log_activity_sheet.dart` — `showEditActivity`, edit mode.
- Modify `lib/features/contacts/presentation/history_section.dart` — tap to edit.
- Modify `lib/l10n/app_en.arb` — `editActivityTitle`.
- Test fakes: `test/features/contacts/fake_activity_repository.dart`, `test/features/contacts/fake_people_repository.dart`.
- Tests: `test/features/contacts/data/activity_repository_test.dart`, `test/features/contacts/presentation/history_controller_test.dart`, `test/features/contacts/presentation/log_activity_sheet_test.dart`, `test/features/contacts/presentation/contacts_page_test.dart`.

---

### Task 1: Database — update policy, column grant, stage entry follows "since"

**Files:**
- Create: `supabase/migrations/<timestamp>_edit_history.sql` (run `supabase migration new edit_history`)
- Create: `supabase/tests/edit_history_test.sql`

**Interfaces:**
- Produces: owners may `update public.activity set text/happened_on/amount` on non-stage rows; updating `person.stage_since` (without a stage change) moves the latest stage entry's `created_at`.

- [ ] **Step 1: Write the failing test** — `supabase/tests/edit_history_test.sql`:

```sql
-- Editing history (#187): the owner edits text, day and amount of their own
-- entries, nothing else; a stage entry follows the person's stage_since.
-- Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Sarah', 'prospect');
insert into public.activity (id, person_id, kind, text, amount, happened_on) values
  ('00000000-0000-0000-0000-0000000000c1',
   '00000000-0000-0000-0000-0000000000a1', 'order', 'Cream', 40, '2026-10-02');

-- 1-2: the owner edits text, day and amount.
select lives_ok(
  $$ update public.activity
       set text = 'Cream and soap', happened_on = '2026-10-01', amount = 55
       where id = '00000000-0000-0000-0000-0000000000c1' $$,
  'the owner edits text, day and amount'
);
select results_eq(
  $$ select text, happened_on, amount from public.activity
       where id = '00000000-0000-0000-0000-0000000000c1' $$,
  $$ values ('Cream and soap'::text, '2026-10-01'::date, 55::numeric) $$,
  'the edit is saved'
);

-- 3-4: kind and person are not editable.
select throws_ok(
  $$ update public.activity set kind = 'note'
       where id = '00000000-0000-0000-0000-0000000000c1' $$,
  '42501', null,
  'the kind cannot change'
);
select throws_ok(
  $$ update public.activity set person_id = null
       where id = '00000000-0000-0000-0000-0000000000c1' $$,
  '42501', null,
  'the person cannot change'
);

-- 5: an edit is held to the same shape as an insert.
select throws_ok(
  $$ update public.activity set text = ' '
       where id = '00000000-0000-0000-0000-0000000000c1' $$,
  '23514', null,
  'an edit is held to the same shape as an insert: no blank text'
);

-- Two stage changes; the first moved back as postgres, so they are apart.
update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';
reset role;
update public.activity set created_at = '2026-01-01 10:00+00'
  where kind = 'stage';
set local role authenticated;
update public.person set stage = 'team'
  where id = '00000000-0000-0000-0000-0000000000a1';

-- 6: stage entries are not edited directly (RLS filters them out).
update public.activity set happened_on = '2020-01-01' where kind = 'stage';
select is(
  (select count(*)::int from public.activity
     where kind = 'stage' and happened_on = '2020-01-01'),
  0,
  'a stage entry cannot be edited directly'
);

-- 7: another user edits nothing.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
update public.activity set text = 'Mine now'
  where id = '00000000-0000-0000-0000-0000000000c1';
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select is(
  (select text from public.activity
     where id = '00000000-0000-0000-0000-0000000000c1'),
  'Cream and soap',
  'another user cannot edit the entry'
);

-- 8: before the move, the team change counts this month.
select is(
  (select team_members from public.month_progress(current_date,
     now() - interval '1 hour', now() + interval '1 hour')),
  1,
  'joining the team today counts today'
);

-- 9-10: moving stage_since moves the latest stage entry only.
update public.person set stage_since = '2026-06-01 00:00+00'
  where id = '00000000-0000-0000-0000-0000000000a1';
select results_eq(
  $$ select stage::text, created_at from public.activity
       where kind = 'stage' order by created_at $$,
  $$ values ('customer'::text, '2026-01-01 10:00+00'::timestamptz),
            ('team'::text, '2026-06-01 00:00+00'::timestamptz) $$,
  'the latest stage entry follows stage_since; older ones stay'
);
select is(
  (select team_members from public.month_progress(current_date,
     now() - interval '1 hour', now() + interval '1 hour')),
  0,
  'goals follow the moved stage entry'
);

-- 11: a stage change still starts now.
update public.person set stage = 'customer'
  where id = '00000000-0000-0000-0000-0000000000a1';
select is(
  (select max(created_at) from public.activity where kind = 'stage'),
  now(),
  'a stage change writes its entry at now()'
);

select * from finish();
rollback;
```

- [ ] **Step 2: Run it to verify it fails**

Run: `supabase test db`
Expected: `edit_history_test.sql` fails at test 1 (`permission denied for table activity`).

- [ ] **Step 3: Write the migration** — `supabase migration new edit_history`, then:

```sql
-- Editing history (#187). The owner edits what they wrote: text, day and an
-- order's amount, never the kind, the person or the stage. The checks on
-- activity apply to an edit as to an insert.
create policy activity_update_own on public.activity
  for update to authenticated
  using (owner_id = (select auth.uid()) and kind <> 'stage')
  with check (owner_id = (select auth.uid()) and kind <> 'stage');

grant update (text, happened_on, amount) on public.activity to authenticated;

-- A stage entry is never edited directly: its day is the person's
-- stage_since. When stage_since moves without a stage change (an import
-- backdated, a correction), the latest stage entry moves with it. For a
-- stage entry, created_at is when the stage began: the history and goals
-- both read it. security definer for the same reason as
-- person_stage_changed: stage entries are not writable by the app.
create function public.person_stage_since_moved() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.activity set created_at = new.stage_since
    where id = (
      select a.id from public.activity a
        where a.person_id = new.id and a.owner_id = new.owner_id
          and a.kind = 'stage'
        order by a.created_at desc, a.id desc
        limit 1
    );
  return null;
end $$;

create trigger person_stage_since_moved
  after update of stage_since on public.person
  for each row
  when (old.stage_since is distinct from new.stage_since
        and old.stage is not distinct from new.stage)
  execute function public.person_stage_since_moved();
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `supabase migration up --local && supabase test db`
Expected: `All tests successful.` (every file, including `activity_test.sql` and `goals_test.sql`).

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_edit_history.sql supabase/tests/edit_history_test.sql
git commit -m "feat(contacts): let the owner edit history entries in the database"
```

---

### Task 2: Repositories — `ActivityRepository.update`, `PeopleRepository.setStageSince`

**Files:**
- Modify: `lib/features/contacts/data/activity_repository.dart`
- Modify: `lib/features/contacts/data/people_repository.dart`
- Modify: `lib/features/contacts/domain/activity.dart` (doc comment on `Activity`)
- Modify: `test/features/contacts/fake_activity_repository.dart`
- Modify: `test/features/contacts/fake_people_repository.dart`
- Test: `test/features/contacts/data/activity_repository_test.dart`

**Interfaces:**
- Produces:
  - `Map<String, dynamic> activityEditToRow(ActivityDraft draft)` — `{'happened_on', 'text', 'amount'}`, blank text null.
  - `Future<Activity> ActivityRepository.update(String id, ActivityDraft draft)`.
  - `Future<Person> PeopleRepository.setStageSince(String id, DateTime at)`.
  - Fakes: `FakeActivityRepository.update` records `update(<id>)`; `FakePeopleRepository.setStageSince` records `setStageSince(<id>)` and, when `activities` is set, moves the latest stage entry's `createdAt` to `at` (what the trigger does).

- [ ] **Step 1: Write the failing test** — add to `test/features/contacts/data/activity_repository_test.dart` (inside `main`):

```dart
  test('activityEditToRow writes the day, the text and the amount only', () {
    expect(
      activityEditToRow((
        kind: ActivityKind.step,
        happenedOn: DateTime(2026, 10, 1),
        text: ' Sent the samples ',
        amount: null,
      )),
      {'happened_on': '2026-10-01', 'text': 'Sent the samples', 'amount': null},
    );
    expect(
      activityEditToRow((
        kind: ActivityKind.order,
        happenedOn: DateTime(2026, 10, 2),
        text: ' ',
        amount: 55,
      )),
      {'happened_on': '2026-10-02', 'text': null, 'amount': 55},
    );
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/contacts/data/activity_repository_test.dart`
Expected: compile error, `activityEditToRow` not defined.

- [ ] **Step 3: Implement** — in `activity_repository.dart`:

Add after `addOwnOrder`:

```dart
  /// What an edit may change: the day, the text and an order's amount. The
  /// database refuses any other column, and stage entries altogether.
  Future<Activity> update(String id, ActivityDraft draft) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .update(activityEditToRow(draft))
            .eq('id', id)
            .select()
            .single();
        return activityFromRow(row);
      });
```

Replace the body of `activityDraftToRow` from `final text = draft.text.trim();` to the end with:

```dart
  return {
    'person_id': personId,
    'kind': draft.kind.name,
    ...activityEditToRow(draft),
  };
}

/// The columns an edit writes; [activityDraftToRow] adds whose and what kind.
/// Any kind, steps included: the kind itself is never written.
Map<String, dynamic> activityEditToRow(ActivityDraft draft) {
  assert(
    draft.amount == null || draft.kind == ActivityKind.order,
    'Only an order has an amount',
  );
  final text = draft.text.trim();
  return {
    'happened_on': dayColumn(draft.happenedOn),
    'text': text.isEmpty ? null : text,
    'amount': draft.amount,
  };
}
```

(Remove the now-duplicated amount assert from `activityDraftToRow`; keep its `byUser` assert.)

In `people_repository.dart`, after `setPlace`:

```dart
  /// Corrects the day their stage began. The database moves the latest stage
  /// entry in the history with it.
  Future<Person> setStageSince(String id, DateTime at) =>
      _write(id, {'stage_since': at.toUtc().toIso8601String()});
```

In `activity.dart`, change the `Activity` doc comment from `/// One thing in a person's history. Never edited, only deleted.` to:

```dart
/// One thing in a person's history. Its text, day and amount can be edited;
/// a stage entry's day is the person's [Person.stageSince].
```

In `fake_activity_repository.dart`, after `addOwnOrder`:

```dart
  @override
  Future<Activity> update(String id, ActivityDraft draft) async {
    await _record('update($id)');
    final index = store.indexWhere((entry) => entry.id == id);
    final before = store[index];
    final text = draft.text.trim();
    return store[index] = Activity(
      id: before.id,
      personId: before.personId,
      kind: before.kind,
      happenedOn: draft.happenedOn,
      text: text.isEmpty ? null : text,
      amount: draft.amount,
      createdAt: before.createdAt,
    );
  }

  /// What the trigger does when stage_since moves. Not a call.
  void moveLatestStage(String personId, DateTime at) {
    final stages = [
      for (final (index, entry) in store.indexed)
        if (entry.personId == personId && entry.kind == ActivityKind.stage)
          (index, entry),
    ]..sort((a, b) => b.$2.createdAt.compareTo(a.$2.createdAt));
    if (stages.isEmpty) return;
    final (index, latest) = stages.first;
    store[index] = Activity(
      id: latest.id,
      personId: latest.personId,
      kind: latest.kind,
      happenedOn: latest.happenedOn,
      stage: latest.stage,
      createdAt: at.toUtc(),
    );
  }
```

In `fake_people_repository.dart`, after `setStage`:

```dart
  @override
  Future<Person> setStageSince(String id, DateTime at) async {
    await _record('setStageSince($id)');
    final before = store[id]!;
    final moved = _with(
      before,
      stage: before.stage,
      stageSince: at.toUtc(),
      status: before.prospectStatus,
      place: before.place,
      pausedAt: before.pausedAt,
    );
    activities?.moveLatestStage(id, at);
    return moved;
  }
```

(`_with` is the fake's copy helper, used by `setStage`; it takes `stage`, `stageSince`, `status`, `place`, `pausedAt` as shown there — check its signature and drop any argument it defaults.)

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter analyze && flutter test test/features/contacts`
Expected: No issues; all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/contacts test/features/contacts
git commit -m "feat(contacts): update history entries and a person's stage since"
```

---

### Task 3: Controllers — `HistoryController.edit`, `PeopleController.setStageSince`

**Files:**
- Modify: `lib/features/contacts/presentation/history_controller.dart`
- Modify: `lib/features/contacts/presentation/people_controller.dart`
- Test: `test/features/contacts/presentation/history_controller_test.dart`

**Interfaces:**
- Consumes: `ActivityRepository.update(String, ActivityDraft)`, `PeopleRepository.setStageSince(String, DateTime)`.
- Produces:
  - `Future<void> HistoryController.edit(Activity activity, ActivityDraft draft)` — waits for the server, replaces the entry, re-sorts, reloads the book; a failure rethrows and leaves the list.
  - `Future<void> PeopleController.setStageSince(Person person, DateTime day)` — writes, replaces the person, invalidates `historyProvider(person.id)`.

- [ ] **Step 1: Write the failing tests** — add to `history_controller_test.dart`:

```dart
  test('edit waits for the server, then re-sorts the entry', () async {
    final world = _world([_note('a', 10), _note('b', 12)]);
    await world.container.read(historyProvider('p1').future);

    await world.container
        .read(historyProvider('p1').notifier)
        .edit(world.activities.store.first, (
          kind: ActivityKind.note,
          happenedOn: DateTime(2026, 9, 14),
          text: 'Moved',
          amount: null,
        ));

    expect(world.activities.calls.last, 'update(a)');
    expect(_ids(world.container), ['a', 'b']);
    expect(
      world.container.read(historyProvider('p1')).value!.first.text,
      'Moved',
    );
  });

  test('a failed edit rethrows and keeps the list', () async {
    final world = _world([_note('a', 10)]);
    await world.container.read(historyProvider('p1').future);
    world.activities.failWith = PeopleFailure.network;

    await expectLater(
      world.container
          .read(historyProvider('p1').notifier)
          .edit(world.activities.store.first, (
            kind: ActivityKind.note,
            happenedOn: DateTime(2026, 9, 10),
            text: 'Changed',
            amount: null,
          )),
      throwsA(PeopleFailure.network),
    );
    expect(
      world.container.read(historyProvider('p1')).value!.single.text,
      'Note a',
    );
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/contacts/presentation/history_controller_test.dart`
Expected: compile error, `edit` not defined.

- [ ] **Step 3: Implement** — in `history_controller.dart`, after `add`:

```dart
  /// Waits for the server; a failure rethrows and leaves the list as it was.
  Future<void> edit(Activity activity, ActivityDraft draft) async {
    final alive = ref.keepAlive();
    try {
      final edited = await _repository.update(activity.id, draft);
      _change(
        (entries) => [
          for (final entry in entries) entry.id == edited.id ? edited : entry,
        ],
      );
      _reloadBook();
    } finally {
      alive.close();
    }
  }
```

In `people_controller.dart`, after `moveTo`:

```dart
  /// Corrects the day their stage began, to [day] (local midnight). The
  /// database moves the latest stage entry with it, so the history reloads.
  Future<void> setStageSince(Person person, DateTime day) async {
    _replace(await _repository.setStageSince(person.id, day));
    if (ref.mounted) ref.invalidate(historyProvider(person.id));
  }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/contacts`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/contacts/presentation test/features/contacts/presentation/history_controller_test.dart
git commit -m "feat(contacts): edit a history entry and a stage's start from the controllers"
```

---

### Task 4: The edit sheet

**Files:**
- Modify: `lib/features/contacts/presentation/log_activity_sheet.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/contacts/presentation/log_activity_sheet_test.dart`

**Interfaces:**
- Consumes: `HistoryController.edit`, `PeopleController.setStageSince`, `historyProvider(personId)`.
- Produces: `Future<bool?> showEditActivity(BuildContext context, Person person, Activity activity)` — resolves `true` when the user tapped Delete (the caller confirms and deletes), otherwise null.

Behaviour:
- Title `l10n.editActivityTitle` ("Edit"); no kind chips; fields prefilled (`_day = activity.day`, text, amount written as in the edit form: whole numbers without `.0`).
- A stage entry shows only When. Its picker runs from `first` = the previous stage entry's `day` (the second stage entry in the loaded history, which is sorted latest first), or no bound; `first` is clamped to the entry's own day if later. Saving the same day closes without a write; another day calls `setStageSince(person, day)`.
- Any other kind saves `HistoryController.edit(activity, draft)` with the kind unchanged.
- Actions: Cancel, Save, and — except on a stage entry — a `TextButton` `l10n.historyDeleteConfirm` that pops `true`.
- The text field autofocuses only when adding.

- [ ] **Step 1: Add the copy** — in `app_en.arb`, after `logTitle`'s block:

```json
  "editActivityTitle": "Edit",
  "@editActivityTitle": {
    "description": "Title of the form that edits a history entry, opened by tapping it. Same fields as Log something, the kind fixed."
  },
```

Run: `flutter gen-l10n`. Check `git status` does not list `pubspec.lock`; if it does, `git checkout -- pubspec.lock`.

- [ ] **Step 2: Write the failing tests** — add to `log_activity_sheet_test.dart`, inside `main`, after the existing groups:

```dart
  group('edit', () {
    Future<Object?> openEdit(WidgetTester tester, Activity activity) async {
      Object? resolved;
      await pumpFormHarness(
        tester,
        people: FakePeopleRepository([_claire])..activities = activities,
        activities: activities,
        account: const Account(
          firstName: 'Pauline',
          email: 'p@example.com',
          businessModel: BusinessModel.doterra,
        ),
        open: (context) => showEditActivity(context, _claire, activity),
        result: (value) => resolved = value,
      );
      return resolved;
    }

    testWidgets('a note opens filled in, without kinds, and saves', (
      tester,
    ) async {
      final note = Activity(
        id: 'a1',
        personId: 'p1',
        kind: ActivityKind.note,
        happenedOn: DateTime(2026, 9, 10),
        text: 'Asked abot the cream',
        createdAt: DateTime.utc(2026, 9, 10, 12),
      );
      activities.store.add(note);
      await openEdit(tester, note);

      expect(find.text('Edit'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNothing);
      await tester.enterText(field('What happened'), 'Asked about the cream');
      await save(tester);

      expect(activities.calls.last, 'update(a1)');
      expect(activities.store.single.text, 'Asked about the cream');
      expect(activities.store.single.happenedOn, DateTime(2026, 9, 10));
    });

    testWidgets('an order keeps its amount, written plainly', (tester) async {
      final order = Activity(
        id: 'a1',
        personId: 'p1',
        kind: ActivityKind.order,
        happenedOn: DateTime(2026, 9, 10),
        amount: 40,
        createdAt: DateTime.utc(2026, 9, 10, 12),
      );
      activities.store.add(order);
      await openEdit(tester, order);

      expect(find.text('40'), findsOneWidget);
      await tester.enterText(field('Amount'), '55.5');
      await save(tester);

      expect(activities.store.single.amount, 55.5);
    });

    testWidgets('a step entry saves its new text', (tester) async {
      final step = Activity(
        id: 'a1',
        personId: 'p1',
        kind: ActivityKind.step,
        happenedOn: DateTime(2026, 9, 10),
        text: 'Thank them',
        createdAt: DateTime.utc(2026, 9, 10, 12),
      );
      activities.store.add(step);
      await openEdit(tester, step);

      await tester.enterText(field('What happened'), 'Thanked them by phone');
      await save(tester);

      expect(activities.store.single.kind, ActivityKind.step);
      expect(activities.store.single.text, 'Thanked them by phone');
    });

    testWidgets('Delete hands back to the history', (tester) async {
      final note = Activity(
        id: 'a1',
        personId: 'p1',
        kind: ActivityKind.note,
        happenedOn: DateTime(2026, 9, 10),
        text: 'Note',
        createdAt: DateTime.utc(2026, 9, 10, 12),
      );
      activities.store.add(note);
      Object? resolved;
      await pumpFormHarness(
        tester,
        people: FakePeopleRepository([_claire]),
        activities: activities,
        open: (context) => showEditActivity(context, _claire, note),
        result: (value) => resolved = value,
      );

      await tester.tap(find.widgetWithText(TextButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(resolved, isTrue);
      expect(activities.calls, isNot(contains('delete(a1)')));
    });

    testWidgets('a stage entry edits only its day, which is the since', (
      tester,
    ) async {
      activities.recordStage('p1', Stage.customer);
      final stage = activities.store.single;
      final people = FakePeopleRepository([_claire])..activities = activities;
      await pumpFormHarness(
        tester,
        people: people,
        activities: activities,
        open: (context) => showEditActivity(context, _claire, stage),
        result: (_) {},
      );

      expect(find.byType(TextFormField), findsNothing);
      expect(find.widgetWithText(TextButton, 'Delete'), findsNothing);
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '09/01/2026');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(people.calls.last, 'setStageSince(p1)');
      expect(people.store['p1']!.stageSince, DateTime(2026, 9).toUtc());
      expect(activities.store.single.day, DateTime(2026, 9));
    });

    testWidgets('a stage entry saved on the same day writes nothing', (
      tester,
    ) async {
      activities.recordStage('p1', Stage.customer);
      final stage = activities.store.single;
      final people = FakePeopleRepository([_claire])..activities = activities;
      await pumpFormHarness(
        tester,
        people: people,
        activities: activities,
        open: (context) => showEditActivity(context, _claire, stage),
        result: (_) {},
      );

      await save(tester);

      expect(people.calls, isNot(contains('setStageSince(p1)')));
      expect(find.text('Edit'), findsNothing);
    });

    testWidgets('a stage entry already before the previous one still opens '
        'its picker', (tester) async {
      // Customer on Sep 28 (fake time), then team, moved by the edit form to
      // Sep 1: before the customer entry.
      activities.recordStage('p1', Stage.customer);
      activities.recordStage('p1', Stage.team);
      activities.moveLatestStage('p1', DateTime(2026, 9));
      final team = activities.store.last;
      await pumpFormHarness(
        tester,
        people: FakePeopleRepository([_claire])..activities = activities,
        activities: activities,
        open: (context) => showEditActivity(context, _claire, team),
        result: (_) {},
      );

      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('OK'), findsOneWidget);
    });
  });
```

(`'What happened'` is `logWhat`, `'Amount'` is `logAmount`.)

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/contacts/presentation/log_activity_sheet_test.dart`
Expected: compile error, `showEditActivity` not defined.

- [ ] **Step 4: Implement** — in `log_activity_sheet.dart`:

After `showLogOwnOrder`:

```dart
/// Edit [activity] in [person]'s history: the same form, the kind fixed. A
/// stage entry asks only for its day, which is [Person.stageSince]. Resolves
/// true when Delete is tapped; the history confirms and deletes.
Future<bool?> showEditActivity(
  BuildContext context,
  Person person,
  Activity activity,
) => LoomiaDialog.show<bool>(
  context,
  (_) => _LogActivityForm(person: person, editing: activity),
);
```

`_LogActivityForm` gains `this.editing` (`final Activity? editing;` documented "Null when adding."). In the state:

```dart
  late final Activity? _editing = widget.editing;
  late final _text = TextEditingController(text: _editing?.text);
  late final _amount = TextEditingController(
    text: switch (_editing?.amount) {
      final double amount when amount % 1 == 0 => amount.toInt().toString(),
      final double amount => amount.toString(),
      null => '',
    },
  );
  late ActivityKind _kind =
      _editing?.kind ??
      (widget.person == null ? ActivityKind.order : ActivityKind.note);
  late DateTime _day = _editing?.day ?? today();

  bool get _stage => _editing?.kind == ActivityKind.stage;
```

(Replace the existing `_text`, `_amount`, `_kind`, `_day` declarations with these.)

`_pickDay` becomes:

```dart
  Future<void> _pickDay() async {
    final day = await pickDay(
      context,
      initial: _day,
      first: _stage ? _previousStageDay() : null,
      last: today(),
    );
    if (day != null && mounted) setState(() => _day = day);
  }

  /// A stage entry can't go before the stage before it. Clamped to its own
  /// day, which the edit form may already have put earlier.
  DateTime? _previousStageDay() {
    final entries = ref.read(historyProvider(widget.person!.id)).value;
    final stages = [
      for (final entry in entries ?? const <Activity>[])
        if (entry.kind == ActivityKind.stage) entry,
    ];
    final index = stages.indexWhere((entry) => entry.id == _editing!.id);
    if (index < 0 || index + 1 >= stages.length) return null;
    final previous = stages[index + 1].day;
    final own = _editing!.day;
    return previous.isAfter(own) ? own : previous;
  }
```

In `_submit`, after the draft is built, replace the `final person = widget.person; if (person == null) {...} else {...}` block with:

```dart
      final person = widget.person;
      final editing = _editing;
      if (person == null) {
        await ref.read(activityRepositoryProvider).addOwnOrder(draft);
        widget.onSaved?.call();
      } else if (editing == null) {
        await ref.read(historyProvider(person.id).notifier).add(draft);
      } else if (_stage) {
        if (_day != editing.day) {
          await ref
              .read(peopleProvider(ref.read(accountProvider)?.email).notifier)
              .setStageSince(person, _day);
        }
      } else {
        await ref.read(historyProvider(person.id).notifier).edit(editing, draft);
      }
```

and skip form validation for a stage entry: `if (!_stage && !_form.currentState!.validate()) return;`. The draft for a stage entry is unused; keep it built (its `text` is `''`).

Import `people_controller.dart` (`peopleProvider`).

In `build`:
- title: `_editing != null ? l10n.editActivityTitle : (person == null ? l10n.logOwnOrderTitle : l10n.logTitle(firstName(person)))`.
- actions: before Cancel, `if (_editing != null && !_stage) TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.historyDeleteConfirm)),`.
- chips: `if (person != null && _editing == null) Wrap(...)`.
- amount: `if (order && !_stage)` (order is already false for a stage entry; leave as `if (order)`).
- text field: `if (!_stage) LabeledField(...)`, and `autofocus: _editing == null`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `dart format . && flutter analyze && flutter test test/features/contacts`
Expected: No issues; all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/features/contacts/presentation/log_activity_sheet.dart lib/l10n/app_en.arb test/features/contacts/presentation/log_activity_sheet_test.dart
git commit -m "feat(contacts): edit sheet for history entries"
```

---

### Task 5: Tap an entry to edit it

**Files:**
- Modify: `lib/features/contacts/presentation/history_section.dart`
- Test: `test/features/contacts/presentation/contacts_page_test.dart`

**Interfaces:**
- Consumes: `showEditActivity(BuildContext, Person, Activity) → Future<bool?>`.

Behaviour: every entry is tappable except stage entries other than the latest. Tap opens `showEditActivity`; `true` runs the existing `_delete` (confirm, then delete). Long-press, right-click and the screen-reader Delete action stay as they are (not on stage entries).

- [ ] **Step 1: Write the failing tests** — add to `contacts_page_test.dart`, after `'a stage entry cannot be deleted'`:

```dart
  testWidgets('tapping an entry edits it', (tester) async {
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    await openMarie(tester);

    await reveal(tester, find.text('Ordered the cream'));
    await tester.tap(find.text('Ordered the cream'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ordered the cream'),
      'Ordered the cream and the soap',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(activities.calls, contains('update(a1)'));
    expect(find.text('Ordered the cream and the soap'), findsOneWidget);
  });

  testWidgets('Delete in the edit sheet confirms, then deletes', (
    tester,
  ) async {
    activities.store.add(_note('a1', 'Ordered the cream', 10));
    await openMarie(tester);

    await reveal(tester, find.text('Ordered the cream'));
    await tester.tap(find.text('Ordered the cream'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this entry?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(activities.calls, contains('delete(a1)'));
    expect(find.text('Ordered the cream'), findsNothing);
  });

  testWidgets('only the latest stage entry opens', (tester) async {
    activities.recordStage('p1', Stage.customer);
    activities.recordStage('p1', Stage.prospect);
    // Apart, so the customer entry is the older one.
    activities.moveLatestStage('p1', DateTime.utc(2026, 9, 29, 12));
    await openMarie(tester);

    await reveal(tester, find.text('Became a customer'));
    await tester.tap(find.text('Became a customer'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsNothing);

    await reveal(tester, find.text('Back to prospects'));
    await tester.tap(find.text('Back to prospects'));
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);
  });
```

(`'Back to prospects'` is `historyBackToProspects`, the title of a stage entry back to prospect.)

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/contacts/presentation/contacts_page_test.dart`
Expected: the three new tests fail (`Edit` not found).

- [ ] **Step 3: Implement** — in `history_section.dart`:

Import `log_activity_sheet.dart`. Add to the state:

```dart
  Future<void> _edit(Activity activity) async {
    final delete = await showEditActivity(context, widget.person, activity);
    if (delete == true && mounted) await _delete(activity);
  }
```

In `build`, before the `for` loop, find the latest stage entry (entries are sorted latest first):

```dart
          // Only the current stage's entry is its "since"; older ones stay.
          final latestStage = entries
              .where((entry) => entry.kind == ActivityKind.stage)
              .firstOrNull;
```

(This sits inside `else ...[`, so hoist it above the `return Column(` as `final latestStage = entries?.where(...).firstOrNull;`.)

Pass to `_Entry`:

```dart
              onTap:
                  activity.kind == ActivityKind.stage && activity != latestStage
                  ? null
                  : () => _edit(activity),
```

`_Entry` gains `required this.onTap` (`final VoidCallback? onTap;`). Its doc: "Tap edits it. Long-press, right-click, or the screen reader's Delete action removes it; stage entries can't be removed, and only the latest opens." Its `build`:

```dart
    final onDelete = this.onDelete;
    final onTap = this.onTap;
    if (onDelete == null && onTap == null) return item;
    final gestures = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onDelete,
      onSecondaryTap: onDelete,
      child: item,
    );
    if (onDelete == null) return gestures;
    return Semantics(
      container: true,
      customSemanticsActions: {
        CustomSemanticsAction(label: l10n.historyDeleteConfirm): onDelete,
      },
      child: gestures,
    );
```

- [ ] **Step 4: Run all checks**

Run: `dart format . && flutter analyze && flutter test && supabase test db`
Expected: No issues; all tests pass; `All tests successful.`

- [ ] **Step 5: Commit**

```bash
git add lib/features/contacts/presentation/history_section.dart test/features/contacts/presentation/contacts_page_test.dart
git commit -m "feat(contacts): tap a history entry to edit it"
```

---

### Task 6: Pull request

- [ ] **Step 1:** `git status` — only intended files; no `pubspec.lock`, no `devtools_options.yaml`.
- [ ] **Step 2:** `git push -u origin feature/187-edit-history`
- [ ] **Step 3:** `gh pr create --base main --title "feat(contacts): edit history entries"` with the template in `.github/pull_request_template.md`: Ticket `Closes #187`; What & why from the spec; checklist ticked as verified.
- [ ] **Step 4:** `graphify update .`
