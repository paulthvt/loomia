# Plain Events Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An event can have no type: New event opens with a "None" chip selected, and choosing None clears the event workflow and the After the event mapping. Today asks "How did … go?" only for events that start a workflow for someone. Being at an event is no longer contact (#300).

**Architecture:** One migration replaces `last_contact_on` to ignore `event` entries; the fake people repository's copy of that rule follows. `todayEvents` filters `toMark` on `followUps.isNotEmpty`. `EventForm` drops the `listenManual` that picks the first event workflow and gains a None chip. No new provider, table or dependency.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase (Postgres, pgTAP).

**Spec:** `docs/superpowers/specs/2026-10-12-plain-events-design.md`. No Figma section (one chip in an existing row); the None chip is drawn in [Repeating events — #297](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=323-8181), frame 323:8183.

## Global Constraints

- One migration, made with `supabase migration new plain_events`. Never edit an applied one.
- No new dependency. Stage only changed files by path.
- Dart: `package:loomia/...` imports; Material from `package:material_ui/material_ui.dart`.
- Copy: English only, in `lib/l10n/app_en.arb`, every key with a description; `flutter gen-l10n`. `app_fr.arb` untouched.
- Quality gate per task: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`; `supabase test db` for Task 1. Goldens from CI only (none expected: `EventForm` has no `@Preview`, and `today_preview.dart` builds `TodayEvents` by hand).
- Branch `feature/300-plain-events`; PR body `Closes #300`.

## Rulings made while planning

- **Choosing None keeps the title.** `_choose` replaces a title still equal to the previous type's name; None doesn't, since "Workshop" may be the title the user wants. `_typeName` is left as it was, so picking a type again still replaces an untouched title.
- **The None chip shows whenever event workflows exist**, like the row today. With none, there is no row and the event has no type, as now.
- **`canMarkDone` is unchanged.** The event page still offers Mark who was there for any started event with people; only Today's list narrows.
- **Loyalty entries still count as contact.** The spec only drops `event`; `loyaltyStart` / `loyaltyStop` keep counting, as they do today.
- **The fake follows the rule.** `FakePeopleRepository`'s last-contact computation (`fake_people_repository.dart:55`) skips `ActivityKind.event` too, so widget tests agree with Postgres.

## Review Focus

1. A new event saves with `eventWorkflowId == null` and empty `followUps` unless a type is picked. Pinned in Task 3.
2. None after a type clears both the event workflow and the mapping, and hides After the event. Pinned in Task 3.
3. Today leaves out a started event with people and no mapping; the event page still offers marking. Pinned in Task 2.
4. An `event` entry never moves `last_contact_on`, in Postgres and in the fake. Pinned in Task 1.

---

### Task 1: `last_contact_on` ignores events

**Files:**
- Create: `supabase/migrations/<timestamp>_plain_events.sql` (`supabase migration new plain_events`)
- Modify: `supabase/tests/last_contact_test.sql`
- Modify: `test/features/contacts/fake_people_repository.dart`
- Modify: `test/features/contacts/fake_people_repository_test.dart`

- [x] **Step 1: Failing pgTAP case.** In `last_contact_test.sql`, `plan(4)` → `plan(5)`; add person `…a5` 'At a call' (`team`) with a `call` on `2026-09-10` and an `event` on `2026-09-25`:

```sql
select is(
  (select public.last_contact_on(p) from public.person p
   where p.id = '00000000-0000-0000-0000-0000000000a5'),
  '2026-09-10'::date, 'being at an event is no contact');
```

  `supabase test db` fails on it.
- [x] **Step 2: Migration.**

```sql
-- Plain events (#300): being at a group event is not a conversation, so it
-- no longer moves last_contact_on; Worth a check-in still flags someone only
-- seen on a call. The event entry stays in their history.
create or replace function public.last_contact_on(p public.person) returns date
language sql stable security invoker set search_path = '' as $$
  select max(a.happened_on) from public.activity a
  where a.person_id = p.id and a.kind not in ('stage', 'event')
$$;
```

  `create or replace` keeps the grants. `supabase test db` passes.
- [x] **Step 3: The fake.** `fake_people_repository.dart:55`: `entry.kind != ActivityKind.stage && entry.kind != ActivityKind.event`; the comment reads "As last_contact_on: the latest entry that is neither a stage change nor an event".
- [x] **Step 4: Fake test.** In `fake_people_repository_test.dart`, a person with a `call` then a later `event` entry reads `lastContactOn` = the call's day.

### Task 2: Today asks only about events that start a workflow

**Files:**
- Modify: `lib/features/today/domain/today_events.dart`
- Modify: `test/features/today/domain/today_events_test.dart`
- Modify: `test/features/today/today_events_test.dart`, `test/features/today/today_page_test.dart` (fixtures)

- [x] **Step 1: Failing unit test.** In `domain/today_events_test.dart`, `_event` gains `Map<Stage, String> followUps = const {Stage.prospect: 'samples'}`, passed to `CalendarEvent`, so the existing cases keep their meaning. New case:

```dart
  test('an event that starts no workflow is not asked about', () {
    final plain = _event('plain', DateTime(2026, 10, 7, 19), followUps: const {});
    final mapped = _event('mapped', DateTime(2026, 10, 7, 20));
    final morning = _event('morning', DateTime(2026, 10, 8, 8), followUps: const {});

    final shown = todayEvents([plain, mapped, morning], const [], _morning);

    expect(shown.toMark, [mapped]);
    expect(shown.today, [morning]);
  });
```

- [x] **Step 2: The rule.** In `todayEvents`, the `toMark` filter gains `event.followUps.isNotEmpty &&`. The doc comment: "events started within [todayEventsDays] days that can be marked done and start a workflow for someone". A plain event that started earlier today is not to mark, so `today` keeps it (its `if (!toMark.contains(event))`): add that to the new case with a plain event at `DateTime(2026, 10, 8, 8)` expected in `shown.today`.
- [x] **Step 3: Fixtures.** Only `today_page_test.dart:490` loads a started event through the repository and expects "How did … go?"; it gains `followUps: const {Stage.prospect: 'samples'}`. Found while implementing: `today_events_test.dart`'s `_training` and the `:237`/`:243` events are handed to the view as a built `TodayEvents`, or are tomorrow's, so `todayEvents` never filters them; they are unchanged.

### Task 3: None on the event form

**Files:**
- Modify: `lib/features/calendar/presentation/event_form.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `test/features/calendar/presentation/event_form_test.dart`

- [x] **Step 1: Failing widget tests** in `event_form_test.dart`:
  - "a new event has no type" (replaces "a new event is a Workshop: its title, its stages"): with `_seeded()`, the None chip is selected, the title is empty, After the event is absent; type a title, Save; `eventWorkflowId` is null and `followUps` empty.
  - "Workshop, then None: no type, no After the event": tap Workshop (title becomes Workshop, After the event shows), tap None; After the event is gone, the title is still Workshop; Save; `eventWorkflowId` null, `followUps` empty.
  - "after the event: prospects can keep theirs" taps Workshop first.
- [x] **Step 2: Copy.** `app_en.arb`:

```json
  "eventTypeNone": "None",
  "@eventTypeNone": {
    "description": "First choice in the event form's Type row: the event has no event workflow, so no checklist and nothing starts after it. Selected by default on a new event."
  },
```

  `@eventType`'s description gains "Optional: None by default." `flutter gen-l10n`.
- [x] **Step 3: The form.**
  - `initState`: delete the `listenManual` block and its comment; a new event starts with `_eventWorkflowId == null`, `_followUps` empty.
  - The Type row's `Wrap` gets, before the event workflows:

```dart
                    ChoiceChip(
                      label: Text(l10n.eventTypeNone),
                      selected: _eventWorkflowId == null,
                      onSelected: (_) => setState(() {
                        _eventWorkflowId = null;
                        _followUps = const {};
                      }),
                    ),
```

  - The After the event condition stays `_eventWorkflowId != null || _followUps.isNotEmpty`: None makes both false.
- [x] **Step 4: Gate.** `dart format .`, `flutter analyze`, `flutter test`, `supabase test db`; `graphify update .`. Open the PR, `Closes #300`.
