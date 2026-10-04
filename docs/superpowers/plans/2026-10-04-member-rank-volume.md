# A team member's rank and volume — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** On a team member's contact page, WHAT THEY ARE AIMING FOR gains, after
"Their why": "Rank now" (Executive), "Aiming for" (Elite by March 2027) and
"Each month" (Aims for 100 PV). The edit sheet picks a rank from the dōTERRA
list (free text for Other), a month for "By", and a number for the volume.
Issue #139, part of epic #136.

**Architecture:** One migration adds four nullable columns to `person`, with
checks. `BusinessModel.levels` holds the dōTERRA rank list as a const (empty
for Other). `Person` gains four fields, mapped by the repository. Copy goes
through ARB `select` on `model.name`; `ContactDetails` takes the model as a
parameter. A new `pickMonth` next to `pickDay` picks the month.

**Tech Stack:** Supabase Postgres + pgTAP, Flutter, `flutter_riverpod`, ARB
l10n (`intl` `yMMMM` for the month, `decimalPattern` for the volume),
`flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-02-goals-design.md` §1 (rank list),
§2 *Team member facts on `person`*, §4 *Team member contact page*. Figma:
contact detail `213:3238`, edit sheet `213:3379`.

## Global Constraints

- Imports: `package:loomia/...` only; Material from `package:material_ui/material_ui.dart`, Cupertino from `package:cupertino_ui/cupertino_ui.dart`.
- No hard-coded colour, radius, font size or spacing.
- No new dependency. No route added.
- Copy in `lib/l10n/app_en.arb` only, every key with a description, informal. Do not edit `app_fr.arb`. Edit the ARB textually (never a JSON rewrite). Run `flutter gen-l10n` after editing.
- Widgets never `if (doterra)`: words come through ARB `select` on `model.name`; the picker-or-text choice reads `model.levels.isEmpty`.
- Rank names are proper nouns: not translated, not in the ARB. The stored value is the label. A stored label missing from the list is shown as stored, and kept on save.
- Never on the Team tab, never summed, never compared. Shown only while `person.stage == Stage.team`; kept if they move.
- Rank requirements (volumes, branches) are **not** app data. They go in the spec as reference only.
- Schema only via `supabase migration new`. No Docker on the dev machine: `supabase test db` runs in CI (`Supabase migrations` job); check that job before claiming the SQL works. Deploy is the user's `supabase db push` after merge.
- Units in edit labels, not as a field suffix: a suffix with semantics trips `node.isMergedIntoParent` in `LabeledField`'s `MergeSemantics` (#138).
- No golden changes expected (previews show people with no rank, and pass `BusinessModel.other`). If one fails, regenerate through CI, never locally.
- Quality gate: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`.
- Branch `feature/139-member-rank-volume` off `main`. Conventional Commits. PR fills `.github/pull_request_template.md`, **Ticket**: `Closes #139`.

**Skipped:** a clear button on "By". Clearing "Aiming for" drops the month;
picking a new month replaces it. Add one if someone wants a target with no
month after setting one.

## Review Focus

1. "Aiming for" cleared while "By" is set: the save drops the month (the database refuses a month with no target). → Task 4, `clearing Aiming for drops By`.
2. A stored rank missing from the list ("Wellness Advocate"): the page shows it, the picker shows it selected, and a save keeps it. → Task 3 `an unknown rank reads as stored`, Task 4 `an unknown rank stays picked`.
3. A saved month in the past opens the month picker without an assertion (`first` must not be after the initial month). → Task 4, `a past month opens the picker`.
4. Editing WHAT YOU KNOW alone keeps rank, target, month and volume. → Task 4, `editing what you know keeps the rank`.
5. A member moved to customers: the values stay in the row, the page hides them. → Task 3, `a customer shows no rank`.

---

### Task 1: Migration, pgTAP, and the spec

**Files:**
- Create: `supabase/migrations/<timestamp>_member_aims.sql` (via `supabase migration new member_aims`)
- Create: `supabase/tests/member_aims_test.sql`
- Modify: `docs/superpowers/specs/2026-10-02-goals-design.md` (§1 rank list)

**Interfaces:**
- Produces: columns `person.current_level text`, `person.target_level text`, `person.target_level_by date`, `person.monthly_volume_target numeric(12,2)`, all nullable.

- [ ] **Step 1: Write the pgTAP test**

`supabase/tests/member_aims_test.sql`:

```sql
-- A team member's rank and volume: a month is the first of a month and needs
-- a target, a volume is above 0. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Claire', 'team');

select lives_ok(
  $$ update public.person set current_level = 'Executive',
       target_level = 'Elite', target_level_by = '2027-03-01',
       monthly_volume_target = 100
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  'a rank, a target by a month and a volume save'
);
select is(
  (select monthly_volume_target from public.person
    where id = '00000000-0000-0000-0000-0000000000a1'), 100::numeric,
  'the volume is stored as given'
);
select throws_ok(
  $$ update public.person set target_level_by = '2027-03-15'
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  '23514', null,
  'a month that is not the first of a month is refused'
);
select throws_ok(
  $$ update public.person set target_level = null
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  '23514', null,
  'a month with no target is refused'
);
select throws_ok(
  $$ update public.person set monthly_volume_target = 0
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  '23514', null,
  'a volume of 0 is refused'
);
select lives_ok(
  $$ update public.person set current_level = null, target_level = null,
       target_level_by = null, monthly_volume_target = null
     where id = '00000000-0000-0000-0000-0000000000a1' $$,
  'all four can be cleared'
);

select * from finish();
rollback;
```

- [ ] **Step 2: Create the migration**

Run: `supabase migration new member_aims`
Expected: prints `Created new migration at supabase/migrations/<timestamp>_member_aims.sql`.

Content:

```sql
-- A team member's rank and volume (#139): facts the user writes on the
-- member's contact page, in conversation. Never computed, never compared.
-- The existing person RLS covers them.
alter table public.person
  add column current_level text,
  add column target_level text,
  add column target_level_by date,
  add column monthly_volume_target numeric(12,2),
  add constraint person_target_level_by_month
    check (extract(day from target_level_by) = 1),
  add constraint person_target_level_by_needs_target
    check (target_level_by is null or target_level is not null),
  add constraint person_monthly_volume_target_positive
    check (monthly_volume_target > 0);
```

(`check` passes on null, so the first and last constraints allow empty columns.)

- [ ] **Step 3: Record the confirmed ranks in the spec**

In `docs/superpowers/specs/2026-10-02-goals-design.md` §1, replace the
paragraph that starts `Rank list (dōTERRA): Consultant, …` and ends
`… is shown as stored.` with:

```markdown
Rank list (dōTERRA), confirmed by the user on 2026-10-04: Manager, Director,
Executive, Elite, Premier, Silver, Gold, Platinum, Diamond, Blue Diamond,
Presidential Diamond. There is no Consultant rank. Rank names are proper nouns
and are not translated. The stored value is the label. A label missing from
the list (the company renamed a rank) is shown as stored.

For reference only — **not used by the app** (rank requirements are not
built, see the decisions table): Manager 500 PV, Director 1 000, Executive
2 000, Elite 3 000, Premier 5 000 with 2 Executive branches, Silver 9 000 with
3 Elite branches, Gold 15 000 with 3 Premier branches, Platinum 27 000 with
3 Silver branches, Diamond 4 Silver branches, Blue Diamond 5 Gold branches,
Presidential Diamond 6 Platinum branches.
```

- [ ] **Step 4: Check the SQL parses locally as far as possible**

Run: `git diff --stat && cat supabase/migrations/*_member_aims.sql`
Expected: the migration and the test exist. The real run is CI's
`Supabase migrations` job on the PR; `schema_rls_test.sql` still passes there
(no new table).

- [ ] **Step 5: Commit**

```bash
git add supabase/migrations/*_member_aims.sql supabase/tests/member_aims_test.sql docs/superpowers/specs/2026-10-02-goals-design.md
git commit -m "feat(contacts): store a team member's rank and volume"
```

### Task 2: The rank list, `Person`, and the repository

**Files:**
- Modify: `lib/core/business_model/business_model.dart`
- Modify: `lib/features/contacts/domain/person.dart`
- Modify: `lib/features/contacts/data/people_repository.dart` (`personFromRow`, `personToRow`)
- Test: `test/core/business_model/business_model_test.dart`
- Test: `test/features/contacts/data/people_repository_test.dart`

**Interfaces:**
- Consumes: Task 1's columns.
- Produces:
  - `List<String> BusinessModel.levels` — dōTERRA's 11 ranks lowest first; `const []` for Other.
  - `Person.currentLevel` (`String?`), `Person.targetLevel` (`String?`), `Person.targetLevelBy` (`DateTime?`, local midnight on the first of a month), `Person.monthlyVolumeTarget` (`double?`). Named constructor params of the same names; `withStatus` copies them.
  - `personToRow` writes `current_level`, `target_level`, `target_level_by` (`yyyy-MM-dd` via `dayColumn`), `monthly_volume_target`.

- [ ] **Step 1: Write the failing tests**

Append to `test/core/business_model/business_model_test.dart`, inside `main`:

```dart
  test("dōTERRA's ranks, lowest first; Other has none", () {
    expect(BusinessModel.doterra.levels, [
      'Manager',
      'Director',
      'Executive',
      'Elite',
      'Premier',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Blue Diamond',
      'Presidential Diamond',
    ]);
    expect(BusinessModel.other.levels, isEmpty);
  });
```

In `test/features/contacts/data/people_repository_test.dart`, add after
`reads a team member's own profile`:

```dart
    test("reads a team member's rank and volume", () {
      final person = personFromRow(
        _row({
          'stage': 'team',
          'prospect_status': null,
          'current_level': 'Executive',
          'target_level': 'Elite',
          'target_level_by': '2027-03-01',
          'monthly_volume_target': 100,
        }),
      );

      expect(person.currentLevel, 'Executive');
      expect(person.targetLevel, 'Elite');
      expect(person.targetLevelBy, DateTime(2027, 3));
      expect(person.monthlyVolumeTarget, 100.0);
    });

    test('reads no rank and no volume as null', () {
      final person = personFromRow(_row());
      expect(person.currentLevel, isNull);
      expect(person.targetLevel, isNull);
      expect(person.targetLevelBy, isNull);
      expect(person.monthlyVolumeTarget, isNull);
    });
```

In the `personToRow writes snake_case values …` test, add to the `Person(...)`:

```dart
        currentLevel: ' ',
        targetLevel: 'Elite',
        targetLevelBy: DateTime(2027, 3),
        monthlyVolumeTarget: 99.5,
```

and to the expected map, after `'stuck_on': null,`:

```dart
      'current_level': null,
      'target_level': 'Elite',
      'target_level_by': '2027-03-01',
      'monthly_volume_target': 99.5,
```

Add one more test after it:

```dart
  test('personToRow writes no month when there is none', () {
    final row = personToRow(
      Person(
        id: 'p1',
        name: 'Claire',
        stage: Stage.team,
        stageSince: DateTime.utc(2026, 3, 4),
      ),
    );
    expect(row['target_level_by'], isNull);
    expect(row['monthly_volume_target'], isNull);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/core/business_model/business_model_test.dart test/features/contacts/data/people_repository_test.dart`
Expected: compile errors — `levels`, `currentLevel`, `targetLevel`, `targetLevelBy`, `monthlyVolumeTarget` are not defined.

- [ ] **Step 3: Add `levels`**

In `lib/core/business_model/business_model.dart`, after `stored`:

```dart

  /// A team member's possible ranks, lowest first, as the company writes them
  /// (proper nouns, never translated). Empty when Loomia does not know the
  /// company's ladder: the user types the level instead.
  List<String> get levels => switch (this) {
    other => const [],
    doterra => const [
      'Manager',
      'Director',
      'Executive',
      'Elite',
      'Premier',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Blue Diamond',
      'Presidential Diamond',
    ],
  };
```

- [ ] **Step 4: Add the four fields to `Person`**

In `lib/features/contacts/domain/person.dart`:

Constructor, after `this.why,`:

```dart
    this.currentLevel,
    this.targetLevel,
    this.targetLevelBy,
    this.monthlyVolumeTarget,
```

Fields, after `final String? why;`:

```dart

  /// Their rank or level now, as the user picked or typed it. This and the
  /// three after it are what the member said in conversation, never read
  /// from their book (#67), never summed or compared.
  final String? currentLevel;

  /// The rank they are aiming for.
  final String? targetLevel;

  /// The month they aim to reach [targetLevel] by: local midnight on the
  /// first of that month. Only with a [targetLevel].
  final DateTime? targetLevelBy;

  /// The volume they aim for each month, in the business model's unit.
  final double? monthlyVolumeTarget;
```

In `withStatus`, after `why: why,`:

```dart
    currentLevel: currentLevel,
    targetLevel: targetLevel,
    targetLevelBy: targetLevelBy,
    monthlyVolumeTarget: monthlyVolumeTarget,
```

- [ ] **Step 5: Map them in the repository**

In `personFromRow`, after `why: _text(row['why']),`:

```dart
    currentLevel: _text(row['current_level']),
    targetLevel: _text(row['target_level']),
    targetLevelBy: switch (row['target_level_by']) {
      // A bare date parses as local midnight.
      final String by => DateTime.parse(by),
      _ => null,
    },
    monthlyVolumeTarget: (row['monthly_volume_target'] as num?)?.toDouble(),
```

In `personToRow`, after `'stuck_on': _text(person.stuckOn),`:

```dart
  'current_level': _text(person.currentLevel),
  'target_level': _text(person.targetLevel),
  'target_level_by': switch (person.targetLevelBy) {
    final DateTime by => dayColumn(by),
    null => null,
  },
  'monthly_volume_target': person.monthlyVolumeTarget,
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/core/business_model/business_model_test.dart test/features/contacts/data/people_repository_test.dart`
Expected: all pass.

- [ ] **Step 7: Run the whole suite**

Run: `flutter analyze && flutter test`
Expected: "No issues found!" and all tests pass (fake repositories store `Person` objects, so nothing else changes).

- [ ] **Step 8: Commit**

```bash
git add lib/core/business_model/business_model.dart lib/features/contacts/domain/person.dart lib/features/contacts/data/people_repository.dart test/core/business_model/business_model_test.dart test/features/contacts/data/people_repository_test.dart
git commit -m "feat(contacts): read and write a team member's rank and volume"
```

### Task 3: The copy, and the contact page

**Files:**
- Modify: `lib/l10n/app_en.arb` (after `@factWhy`, line ~679)
- Modify: `lib/features/contacts/presentation/contact_details.dart` (constructor, `aimingFor` at ~369)
- Modify: `lib/features/contacts/presentation/contact_page.dart:108`
- Modify: `lib/features/contacts/presentation/contacts_preview.dart:134`
- Test: `test/features/contacts/presentation/contact_details_test.dart`

**Interfaces:**
- Consumes: Task 2's `Person` fields.
- Produces:
  - `ContactDetails({required BusinessModel model, ...})`.
  - ARB, used again by Task 4: `factLevelNow(String model)`, `factAimingFor`, `factAimingForBy(String level, DateTime month)`, `factEachMonth`, `factEachMonthValue(String model, num amount)`, `editBy`, `editEachMonth(String model)`, `editLevelNone`. Generated argument order follows the `placeholders` map order, as `historyOrder(String model, num amount)` does.

- [ ] **Step 1: Add the copy**

In `lib/l10n/app_en.arb`, insert after the `@factWhy` block (textually, keep the
file's two-space indent):

```json
  "factLevelNow": "{model, select, doterra{Rank now} other{Level now}}",
  "@factLevelNow": {
    "description": "Label of a team member's rank or level today, as the user picked or typed it. dōTERRA says rank. Also the edit form field.",
    "placeholders": {
      "model": { "type": "String" }
    }
  },
  "factAimingFor": "Aiming for",
  "@factAimingFor": {
    "description": "Label of the rank or level a team member is aiming for. Also the edit form field."
  },
  "factAimingForBy": "{level} by {month}",
  "@factAimingForBy": {
    "description": "Value of Aiming for when they set a month, e.g. 'Elite by March 2027'. The level is a rank name, never translated.",
    "placeholders": {
      "level": { "type": "String" },
      "month": { "type": "DateTime", "format": "yMMMM" }
    }
  },
  "factEachMonth": "Each month",
  "@factEachMonth": {
    "description": "Label of the volume a team member aims for each month."
  },
  "factEachMonthValue": "{model, select, doterra{Aims for {amount} PV} other{Aims for {amount}}}",
  "@factEachMonthValue": {
    "description": "Value of Each month, e.g. 'Aims for 100 PV'. PV is not translated. Other: the number alone.",
    "placeholders": {
      "model": { "type": "String" },
      "amount": { "type": "num", "format": "decimalPattern" }
    }
  },
  "editBy": "By",
  "@editBy": {
    "description": "Edit form field under Aiming for: the month they aim to reach it by. Opens a month picker."
  },
  "editEachMonth": "{model, select, doterra{Each month (PV)} other{Each month}}",
  "@editEachMonth": {
    "description": "Edit form field: the volume a team member aims for each month. dōTERRA shows the unit, PV, not translated.",
    "placeholders": {
      "model": { "type": "String" }
    }
  },
  "editLevelNone": "Not set",
  "@editLevelNone": {
    "description": "First choice of the rank pickers: no rank picked."
  },
```

Run: `flutter gen-l10n`
Expected: no output, no error; `lib/l10n/app_localizations.dart` gains
`String factLevelNow(String model);` … `String factEachMonthValue(String model, num amount);`.
French falls back to English until the l10n sync PR.

- [ ] **Step 2: Write the failing tests**

In `test/features/contacts/presentation/contact_details_test.dart`:

Add `import 'package:loomia/core/business_model/business_model.dart';`.

Give `_pump` a parameter `BusinessModel model = BusinessModel.other,` and pass
`model: model,` to `ContactDetails`.

Add after `a team member with no profile yet still gets the section`:

```dart
  Person member({
    Stage stage = Stage.team,
    String? currentLevel = 'Executive',
    DateTime? by,
    double? volume = 100,
  }) => Person(
    id: 'p1',
    name: 'Claire Martin',
    stage: stage,
    stageSince: DateTime.utc(2026, 3, 4),
    why: 'More time with my kids',
    ownGoal: 'Pay for the holidays',
    currentLevel: currentLevel,
    targetLevel: 'Elite',
    targetLevelBy: by,
    monthlyVolumeTarget: volume,
  );

  testWidgets('dōTERRA: rank now, aiming for by a month, PV each month', (
    tester,
  ) async {
    await _pump(
      tester,
      member(by: DateTime(2027, 3)),
      model: BusinessModel.doterra,
    );

    expect(find.text('Rank now'), findsOneWidget);
    expect(find.text('Executive'), findsOneWidget);
    expect(find.text('Aiming for'), findsOneWidget);
    expect(find.text('Elite by March 2027'), findsOneWidget);
    expect(find.text('Each month'), findsOneWidget);
    expect(find.text('Aims for 100 PV'), findsOneWidget);
    // After their why, before their own goal.
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Their why'), lessThan(top('Rank now')));
    expect(top('Rank now'), lessThan(top('Aiming for')));
    expect(top('Aiming for'), lessThan(top('Each month')));
    expect(top('Each month'), lessThan(top('Their own goal')));
  });

  testWidgets('Other: level now, a target with no month, a bare number', (
    tester,
  ) async {
    await _pump(tester, member(volume: 99.5));

    expect(find.text('Level now'), findsOneWidget);
    expect(find.text('Rank now'), findsNothing);
    expect(find.text('Elite'), findsOneWidget);
    expect(find.text('Aims for 99.5'), findsOneWidget);
  });

  testWidgets('an unknown rank reads as stored', (tester) async {
    await _pump(
      tester,
      member(currentLevel: 'Wellness Advocate'),
      model: BusinessModel.doterra,
    );

    expect(find.text('Wellness Advocate'), findsOneWidget);
  });

  testWidgets('no rank and no volume: those rows are left out', (
    tester,
  ) async {
    await _pump(
      tester,
      member(currentLevel: null, volume: null),
      model: BusinessModel.doterra,
    );

    expect(find.text('Rank now'), findsNothing);
    expect(find.text('Each month'), findsNothing);
    expect(find.text('Aiming for'), findsOneWidget);
  });

  testWidgets('a customer shows no rank, even if saved', (tester) async {
    await _pump(
      tester,
      member(stage: Stage.customer, by: DateTime(2027, 3)),
      model: BusinessModel.doterra,
    );

    expect(find.text('Executive'), findsNothing);
    expect(find.text('Elite by March 2027'), findsNothing);
    expect(find.text('Aims for 100 PV'), findsNothing);
  });
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/features/contacts/presentation/contact_details_test.dart`
Expected: compile error — `ContactDetails` has no parameter `model`.

- [ ] **Step 4: Take the model, show the three facts**

In `lib/features/contacts/presentation/contact_details.dart`:

Add `import 'package:loomia/core/business_model/business_model.dart';`.

Constructor: after `required this.person,` add `required this.model,`. Field,
after `final Person person;`:

```dart

  /// Which words a team member's rank and volume use.
  final BusinessModel model;
```

In `aimingFor`, after `(l10n.factWhy, person.why, null),`:

```dart
            (l10n.factLevelNow(model.name), person.currentLevel, null),
            (
              l10n.factAimingFor,
              switch ((person.targetLevel, person.targetLevelBy)) {
                (final String level, final DateTime by) =>
                  l10n.factAimingForBy(level, by),
                (final level, _) => level,
              },
              null,
            ),
            (
              l10n.factEachMonth,
              switch (person.monthlyVolumeTarget) {
                final double amount => l10n.factEachMonthValue(
                  model.name,
                  amount,
                ),
                null => null,
              },
              null,
            ),
```

Update the comment above `aimingFor` to:
`// Their own aims, in their words: nothing to rank or compare. A rank is a fact they told you, never summed or shown elsewhere.`

- [ ] **Step 5: Pass the model from the two callers**

`lib/features/contacts/presentation/contact_page.dart:108`, after `person: person,`:

```dart
      model: ref.watch(accountProvider)?.businessModel ?? BusinessModel.other,
```

(add `import 'package:loomia/core/business_model/business_model.dart';`).

`lib/features/contacts/presentation/contacts_preview.dart:134`, after
`person: person ?? _sample.first,`:

```dart
  model: BusinessModel.other,
```

(same import).

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/features/contacts/presentation/contact_details_test.dart`
Expected: all pass.

- [ ] **Step 7: Run the whole suite**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all pass, goldens unchanged (the preview's
people have no rank).

- [ ] **Step 8: Commit**

```bash
git add lib/l10n lib/features/contacts/presentation/contact_details.dart lib/features/contacts/presentation/contact_page.dart lib/features/contacts/presentation/contacts_preview.dart test/features/contacts/presentation/contact_details_test.dart
git commit -m "feat(contacts): show a team member's rank and volume"
```

### Task 4: The edit sheet, and `pickMonth`

**Files:**
- Modify: `lib/core/ui/pick_day.dart`
- Modify: `lib/features/contacts/presentation/edit_person_form.dart`
- Modify: `docs/design/screens.md` (§7 *Contact detail* and *Edit details*)
- Test: `test/features/contacts/presentation/edit_person_form_test.dart`

**Interfaces:**
- Consumes: Task 2's `BusinessModel.levels` and `Person` fields; Task 3's ARB keys; `parseAmount(String input, String locale)` and `l10n.logAmountInvalid` from #138.
- Produces: `Future<DateTime?> pickMonth(BuildContext context, {required DateTime initial, required DateTime first, required DateTime last})` — the first of the picked month at local midnight, null when dismissed.

**Form behaviour** (one place, read before the steps):
- After "Their why", in this order: Rank now / Level now, Aiming for, By (only while Aiming for has a value), Each month (PV) / Each month.
- Rank fields: a `DropdownButtonFormField<String?>` when `model.levels` is non-empty, first item "Not set" (null), then the levels, then the stored label if the list lacks it. Free text otherwise.
- By: tap opens `pickMonth`; `first` is the earlier of the saved month and this month, `last` ten years after this month. Shown with `MaterialLocalizations.formatMonthYear`.
- Each month: number keyboard, empty allowed, else `parseAmount(typed, l10n.localeName)` must read it or `logAmountInvalid` shows. A saved value starts as plain digits and a dot (`100`, `99.5`), which `parseAmount` reads back in every language. A French user sees `99.5`, not `99,5` — ponytail: switch to a locale format in `didChangeDependencies` if it bothers anyone.
- Save: `targetLevelBy` is null when Aiming for is empty. When the aims are not asked (`EditPart.facts`, or not on the team), all four are kept from the person.
- Every `LabeledField` in the form gets a `ValueKey`: By appears above same-typed fields, and without keys Flutter hands one field's state to the next (#138).

- [ ] **Step 1: Write the failing tests**

In `test/features/contacts/presentation/edit_person_form_test.dart`, add imports:

```dart
import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/auth/domain/account.dart';
```

Add inside `main`, after `a section asks only for its own fields and keeps the rest`:

```dart
  group("a team member's rank and volume", () {
    const doterra = Account(
      firstName: 'Pauline',
      email: 'p@example.com',
      businessModel: BusinessModel.doterra,
    );
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);

    Person member({
      String? currentLevel,
      String? targetLevel,
      DateTime? by,
      double? volume,
    }) => Person(
      id: 'p2',
      name: 'Léa Martin',
      stage: Stage.team,
      stageSince: DateTime.utc(2026, 3, 4),
      why: 'More time with my kids',
      needs: 'Sleep',
      currentLevel: currentLevel,
      targetLevel: targetLevel,
      targetLevelBy: by,
      monthlyVolumeTarget: volume,
    );

    Future<void> edit(
      WidgetTester tester,
      Person person, {
      Account account = const Account(
        firstName: 'Pauline',
        email: 'p@example.com',
      ),
      EditPart part = EditPart.everything,
    }) {
      people = FakePeopleRepository([person]);
      return pumpFormHarness(
        tester,
        people: people,
        account: account,
        open: (context) => showEditPerson(context, person, part),
        result: (_) {},
      );
    }

    Finder labeled(String label) => find.widgetWithText(LabeledField, label);

    Future<void> pick(WidgetTester tester, String label, String level) async {
      await tester.ensureVisible(labeled(label));
      await tester.tap(
        find.descendant(
          of: labeled(label),
          matching: find.byType(DropdownButtonFormField<String?>),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(level).last);
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('dōTERRA: ranks from the list, a month, PV each month', (
      tester,
    ) async {
      await edit(tester, member(), account: doterra);

      double top(String label) => tester.getTopLeft(labeled(label)).dy;
      expect(top('Their why'), lessThan(top('Rank now')));
      expect(top('Rank now'), lessThan(top('Aiming for')));
      expect(top('Aiming for'), lessThan(top('Each month (PV)')));
      expect(top('Each month (PV)'), lessThan(top('Their own goal')));
      // No month until there is something to aim for.
      expect(labeled('By'), findsNothing);

      await pick(tester, 'Rank now', 'Executive');
      await pick(tester, 'Aiming for', 'Elite');
      expect(labeled('By'), findsOneWidget);
      await tester.ensureVisible(labeled('By'));
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();
      // The picker opens on this month; OK keeps it.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('Each month (PV)'));
      await tester.enterText(field('Each month (PV)'), '100');
      await save(tester);

      final saved = people.store['p2']!;
      expect(saved.currentLevel, 'Executive');
      expect(saved.targetLevel, 'Elite');
      expect(saved.targetLevelBy, thisMonth);
      expect(saved.monthlyVolumeTarget, 100);
      expect(saved.why, 'More time with my kids');
    });

    testWidgets('Other: levels are typed, the volume has no unit', (
      tester,
    ) async {
      await edit(tester, member());

      expect(labeled('Rank now'), findsNothing);
      await tester.ensureVisible(field('Level now'));
      await tester.enterText(field('Level now'), 'Bronze');
      await tester.enterText(field('Aiming for'), 'Silver');
      await tester.pump();
      expect(labeled('By'), findsOneWidget);
      await tester.ensureVisible(field('Each month'));
      await tester.enterText(field('Each month'), '250');
      await save(tester);

      final saved = people.store['p2']!;
      expect(saved.currentLevel, 'Bronze');
      expect(saved.targetLevel, 'Silver');
      expect(saved.targetLevelBy, isNull);
      expect(saved.monthlyVolumeTarget, 250);
    });

    testWidgets('clearing Aiming for drops By; a saved volume is kept', (
      tester,
    ) async {
      await edit(
        tester,
        member(targetLevel: 'Elite', by: DateTime(2027, 3), volume: 99.5),
      );

      expect(find.text('March 2027'), findsOneWidget);
      expect(find.text('99.5'), findsOneWidget);
      await tester.ensureVisible(field('Aiming for'));
      await tester.enterText(field('Aiming for'), '');
      await tester.pump();
      expect(labeled('By'), findsNothing);
      await save(tester);

      final saved = people.store['p2']!;
      expect(saved.targetLevel, isNull);
      expect(saved.targetLevelBy, isNull);
      expect(saved.monthlyVolumeTarget, 99.5);
    });

    testWidgets('an unknown rank stays picked and is kept', (tester) async {
      await edit(
        tester,
        member(currentLevel: 'Wellness Advocate'),
        account: doterra,
      );

      expect(find.text('Wellness Advocate'), findsOneWidget);
      await save(tester);

      expect(people.store['p2']!.currentLevel, 'Wellness Advocate');
    });

    testWidgets('"Not set" clears a rank', (tester) async {
      await edit(tester, member(currentLevel: 'Executive'), account: doterra);

      await pick(tester, 'Rank now', 'Not set');
      await save(tester);

      expect(people.store['p2']!.currentLevel, isNull);
    });

    testWidgets('a past month opens the picker and is kept', (tester) async {
      await edit(tester, member(targetLevel: 'Elite', by: DateTime(2020)));

      await tester.ensureVisible(find.text('January 2020'));
      await tester.tap(find.text('January 2020'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(people.store['p2']!.targetLevelBy, DateTime(2020));
    });

    testWidgets(
      'iOS: a month-and-year wheel that starts at a past month',
      (tester) async {
        await edit(tester, member(targetLevel: 'Elite', by: DateTime(2020)));

        await tester.ensureVisible(find.text('January 2020'));
        await tester.tap(find.text('January 2020'));
        await tester.pumpAndSettle();
        final wheel = tester.widget<CupertinoDatePicker>(
          find.byType(CupertinoDatePicker),
        );
        expect(wheel.mode, CupertinoDatePickerMode.monthYear);
        expect(wheel.minimumDate, DateTime(2020));
        expect(wheel.maximumDate, DateTime(thisMonth.year + 10, thisMonth.month));
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.byType(CupertinoDatePicker), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );

    testWidgets('a bad volume is refused', (tester) async {
      await edit(tester, member());

      await tester.ensureVisible(field('Each month'));
      await tester.enterText(field('Each month'), '0');
      await save(tester);

      expect(
        find.text('Use a number above 0, like 100 or 99.5.'),
        findsOneWidget,
      );
      expect(people.store['p2']!.monthlyVolumeTarget, isNull);
    });

    testWidgets('editing what you know keeps the rank and volume', (
      tester,
    ) async {
      await edit(
        tester,
        member(
          currentLevel: 'Executive',
          targetLevel: 'Elite',
          by: DateTime(2027, 3),
          volume: 100,
        ),
        account: doterra,
        part: EditPart.facts,
      );

      expect(labeled('Rank now'), findsNothing);
      await tester.enterText(field('Needs'), 'Sleep, stress');
      await save(tester);

      final saved = people.store['p2']!;
      expect(saved.needs, 'Sleep, stress');
      expect(saved.currentLevel, 'Executive');
      expect(saved.targetLevel, 'Elite');
      expect(saved.targetLevelBy, DateTime(2027, 3));
      expect(saved.monthlyVolumeTarget, 100);
    });
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/features/contacts/presentation/edit_person_form_test.dart`
Expected: the new tests FAIL (no "Rank now" / "Level now" / "Each month" field); the existing ones pass.

- [ ] **Step 3: Add `pickMonth`**

In `lib/core/ui/pick_day.dart`, share the platform test and give `_Wheel` a mode:

```dart
bool get _wheel => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
```

In `pickDay`, replace `!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS`
with `_wheel`. Add after `pickDay`:

```dart
/// The first of a month between [first] and [last], as local midnight; null
/// when dismissed. A month-and-year wheel on iOS; elsewhere the Material
/// calendar opened on its years, of which only the month is kept.
Future<DateTime?> pickMonth(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) async {
  final picked = _wheel
      ? await showCupertinoModalPopup<DateTime>(
          context: context,
          builder: (_) => _Wheel(
            mode: CupertinoDatePickerMode.monthYear,
            initial: initial,
            first: first,
            last: last,
          ),
        )
      : await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          initialDatePickerMode: DatePickerMode.year,
        );
  return picked == null ? null : DateTime(picked.year, picked.month);
}
```

`_Wheel`: add `this.mode = CupertinoDatePickerMode.date,` to the constructor,
`final CupertinoDatePickerMode mode;` to the fields, and
`mode: widget.mode,` in place of `mode: CupertinoDatePickerMode.date,`.

- [ ] **Step 4: The form's state**

In `lib/features/contacts/presentation/edit_person_form.dart`, add imports:

```dart
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/contacts/domain/activity.dart' show parseAmount;
```

In `_EditPersonFormState`, after `_controllers`:

```dart
  // A team member's rank and volume: picked or typed, kept as they are when
  // this form does not ask for them.
  late String? _levelNow = widget.person.currentLevel;
  late String? _aimingFor = widget.person.targetLevel;
  late DateTime? _by = widget.person.targetLevelBy;
  // Plain digits and a dot: parseAmount reads them back in every language
  // (French reads a dot as the decimal too). No context here, so dispose can
  // create it safely.
  late final _volume = TextEditingController(
    text: switch (widget.person.monthlyVolumeTarget) {
      final double volume when volume % 1 == 0 => volume.toInt().toString(),
      final double volume => volume.toString(),
      null => '',
    },
  );

  Future<void> _pickBy() async {
    final now = today();
    final thisMonth = DateTime(now.year, now.month);
    final initial = _by ?? thisMonth;
    final by = await pickMonth(
      context,
      initial: initial,
      // A saved month in the past stays reachable.
      first: initial.isBefore(thisMonth) ? initial : thisMonth,
      last: DateTime(thisMonth.year + 10, thisMonth.month),
    );
    if (by != null && mounted) setState(() => _by = by);
  }
```

Dispose `_volume` with the controllers (in `dispose`, before `super.dispose()`:
`_volume.dispose();`).

- [ ] **Step 5: Save them**

In `_submit`, before `setState(() { _saving = true; ...`:

```dart
    final aims = _asks(_Field.why);
    final volume = aims
        ? parseAmount(_volume.text, AppLocalizations.of(context).localeName)
        : p.monthlyVolumeTarget;
```

In the `Person(...)`, after `why: _text(_Field.why),`:

```dart
              currentLevel: _levelNow,
              targetLevel: _aimingFor,
              // The database refuses a month with nothing to aim for.
              targetLevelBy: _aimingFor == null ? null : _by,
              monthlyVolumeTarget: volume,
```

(`_levelNow`, `_aimingFor`, `_by` start from the person, so they are kept when
not asked.)

- [ ] **Step 6: The fields**

In `build`, after `final failure = _failure;`:

```dart
    final model =
        ref.watch(accountProvider)?.businessModel ?? BusinessModel.other;
```

Give `input`'s `LabeledField` a key: `key: ValueKey(field),`.

After `input`, add:

```dart
    // dōTERRA picks from its ranks; Other types its own words. A stored
    // label the list lacks (a renamed rank) stays a choice.
    Widget level(
      String label,
      String? value,
      ValueChanged<String?> onChanged,
    ) => LabeledField(
      key: ValueKey(label),
      label: label,
      child: model.levels.isEmpty
          ? TextFormField(
              initialValue: value,
              textCapitalization: TextCapitalization.words,
              onChanged: (typed) =>
                  onChanged(typed.trim().isEmpty ? null : typed.trim()),
            )
          : DropdownButtonFormField<String?>(
              initialValue: value,
              items: [
                DropdownMenuItem(child: Text(l10n.editLevelNone)),
                for (final name in [
                  ...model.levels,
                  if (value != null && !model.levels.contains(value)) value,
                ])
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: onChanged,
            ),
    );

    final rankAndVolume = [
      level(
        l10n.factLevelNow(model.name),
        _levelNow,
        (value) => _levelNow = value,
      ),
      level(
        l10n.factAimingFor,
        _aimingFor,
        (value) => setState(() => _aimingFor = value),
      ),
      if (_aimingFor != null)
        LabeledField(
          key: const ValueKey('by'),
          label: l10n.editBy,
          child: InkWell(
            onTap: _pickBy,
            child: InputDecorator(
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              child: Text(
                switch (_by) {
                  final DateTime by => material.formatMonthYear(by),
                  null => '',
                },
              ),
            ),
          ),
        ),
      LabeledField(
        key: const ValueKey('volume'),
        label: l10n.editEachMonth(model.name),
        child: TextFormField(
          controller: _volume,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            final typed = (value ?? '').trim();
            return typed.isEmpty || parseAmount(typed, l10n.localeName) != null
                ? null
                : l10n.logAmountInvalid;
          },
        ),
      ),
    ];
```

In the fields loop, replace `for (final field in fields.where(_asks)) input(field),` with:

```dart
                  for (final field in fields.where(_asks)) ...[
                    input(field),
                    if (field == _Field.why) ...rankAndVolume,
                  ],
```

If the analyzer reports `initialValue` is not a parameter of
`DropdownButtonFormField` in this SDK, use `value:` and ledger a ruling. If a
`node.isMergedIntoParent` assertion appears on the dropdown inside
`LabeledField`, wrap the dropdown in `Semantics(label: label, child: ExcludeSemantics(...))`
only if needed, and ledger it.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/features/contacts/presentation/edit_person_form_test.dart`
Expected: all pass, the existing ones included.

- [ ] **Step 8: Update the screen doc**

In `docs/design/screens.md` §7, replace the sentence `There is no rank and no volume.`
with:

```markdown
After their why come "Rank now", "Aiming for" ("Elite by March 2027") and
"Each month" ("Aims for 100 PV"); Other reads "Level now" and a bare number
([#139](https://github.com/paulthvt/loomia/issues/139)). They are what the
member said, typed by the user: never on the Team tab, never summed or
compared. The edit sheet picks a rank from the company's list (free text for
Other), a month for "By" once there is a target, and a number.
```

- [ ] **Step 9: Run the whole suite**

Run: `dart format . && flutter analyze && flutter test`
Expected: "No issues found!", all pass, no golden diff.

- [ ] **Step 10: Commit**

```bash
git add lib/core/ui/pick_day.dart lib/features/contacts/presentation/edit_person_form.dart docs/design/screens.md test/features/contacts/presentation/edit_person_form_test.dart
git commit -m "feat(contacts): edit a team member's rank and volume"
```

### Task 5: Gate and pull request

**Files:** none new.

- [ ] **Step 1: Quality gate**

Run: `dart format --set-exit-if-changed . && flutter analyze && flutter test`
Expected: no formatting change, "No issues found!", all tests pass.

- [ ] **Step 2: Final review**, then the pull request **only with the user's OK**

Push `feature/139-member-rank-volume`, open the PR from
`.github/pull_request_template.md` with **Ticket** `Closes #139`. Check the
`Supabase migrations` CI job (pgTAP `member_aims_test.sql`) before calling the
SQL done. After merge, the user runs `supabase db push` (VPN off).
