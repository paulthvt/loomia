# Event Attendees Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** People from the contacts can be invited to an event. Once the event has started, "Mark who was there" records who came, writes an `Event` entry in each of their histories, and makes the attendance read-only (#152).

**Architecture:** One migration adds `event_attendee`, `event.done_at`, the `'event'` activity kind and the `mark_event_done` RPC. `CalendarEvent` gains its attendees, loaded with the event through a PostgREST embed (`*, event_attendee(person_id, came)`). Attendance writes go through `EventsController` and reload the events; marking done also reloads the people (`last_contact_on` moves) and every open history. The event screen gets a People section, a picker sheet, the "Who was there?" sheet and a done banner. Calendar rows show "6 invited" / "4 were there".

**Tech Stack:** Supabase Postgres + pgTAP, Flutter (`material_ui`), `flutter_riverpod` 3.

**Spec:** `docs/superpowers/specs/2026-10-07-calendar-design.md` §1 (#152), §3 Event (points 3–5), §2 (`cameSummary` is #153 and is not built here). Figma: [Calendar — #150](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=257-4672), frames "Event — upcoming", "Who was there sheet", "Event — done".

## Global Constraints

- No new dependency.
- Schema only via `supabase migration new event_attendees`. pgTAP in `supabase/tests/event_attendee_test.sql`, run in CI (`supabase test db`); no local Docker for agents.
- New table: RLS enabled, owner policies on `owner_id = (select auth.uid())`, `revoke all ... from anon, authenticated`, then explicit grants, in the same migration. Functions: `security invoker set search_path = ''`, `revoke execute ... from public, anon`, `grant execute ... to authenticated`.
- Foreign keys between owned tables are composite `(id, owner_id)`, as in `workflow` and `activity`.
- "Today" is the device's (`today()`), sent to the server as `p_today`.
- Dart: `package:loomia/...` imports; Material from `package:material_ui/material_ui.dart`; the domain imports no Flutter; repository methods throw `PeopleFailure` only (`guardPeople`).
- Theme from `colorScheme`, `LoomiaColors`, `AppSpacing`, `AppRadii`. A widget-specific size is a named `static const`. `FilledButton.tonal` takes `style: AppTheme.tonal(context)`.
- Copy: English only, in `lib/l10n/app_en.arb`, every key with a description; `flutter gen-l10n` after edits. No string concatenation in the UI: a sentence with parts is one ARB message with placeholders (French word order differs). Attendance words: "Who was there?", "Was there", "Missed it". Never "came", "recruit", or a score.
- Quality gate: `dart format .`, `flutter analyze` ("No issues found!"), full `flutter test`.
- Goldens come from CI only (README → Golden tests).
- Branch `feature/152-event-attendees`; PR body `Closes #152`.

## Rulings made while planning

- **Removing someone:** a trailing close button on their row ("Remove Claire from the event"), only while the event isn't done. The Figma's stage chip moves into the subtitle: "Prospect · invited".
- **Done is enforced by the database too:** attendee insert, update and delete policies refuse an event whose `done_at` is set. `mark_event_done` sets `came` before `done_at`, so its own update passes.
- **"Mark who was there"** shows once `startsAt` has passed, the event isn't done, and it has at least one attendee. Unticking everyone is allowed: the event is done with nobody there.
- **No "What happens next" summary** in the sheet: it describes workflows, which are #153.
- **An `Event` history entry** behaves like a `Step` entry: not offered in Log something, editable and deletable from the history, and it counts as the last contact (`last_contact_on` already counts every kind but `stage`).
- **After any attendance change the events reload** rather than patching locally: the embed is the source of truth, and the lists are small.
- **The picker** is a `LoomiaDialog` with a search field and the book's people as checkable `ContactRow`s, without the people already invited.

## Review Focus

1. Someone deleted from the contacts disappears from the event (FK cascade), and the event screen never shows an attendee it can't find in the book. Pinned in Tasks 1 and 4.
2. Marking done twice (two devices) is refused, and the second attempt shows the failure without changing anything. Pinned in Tasks 1 and 2.
3. An id that is not an attendee is refused by `mark_event_done`, and nothing is written. Pinned in Task 1.
4. After marking done, the contact's history shows "Event" with the event's title on the device's today, and Today's check-ins see them as talked to. Pinned in Tasks 1 and 4.
5. A done event's attendance can't be changed, from the UI or straight against the table. Pinned in Tasks 1 and 4.

---
### Task 1: Attendees in the database

**Files:**
- Create: `supabase/migrations/<timestamp>_event_attendees.sql` (`supabase migration new event_attendees`; if the CLI is missing, a UTC `YYYYMMDDHHMMSS` later than every existing migration)
- Create: `supabase/tests/event_attendee_test.sql`

**Interfaces:**
- Produces:
  - `event.done_at timestamptz`
  - `unique (id, owner_id)` on `event`
  - `activity_kind` value `'event'`
  - table `event_attendee (event_id, person_id, owner_id, came, created_at)`
  - `mark_event_done(p_event uuid, p_came uuid[], p_today date) returns public.event`

- [ ] **Step 1: Write the pgTAP test** `supabase/tests/event_attendee_test.sql`

```sql
-- Event attendees (#152): who is invited, who was there, and marking an
-- event done. Run with `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(14);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

insert into public.person (id, name, stage) values
  ('00000000-0000-0000-0000-0000000000a1', 'Claire', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a2', 'Sarah', 'prospect'),
  ('00000000-0000-0000-0000-0000000000a3', 'Marie', 'customer'),
  ('00000000-0000-0000-0000-0000000000a4', 'Léa', 'prospect');
insert into public.event (id, title, starts_at) values
  ('00000000-0000-0000-0000-0000000000e1', 'Workshop', '2026-10-08 17:00+00');

-- 1-2: inviting.
select lives_ok(
  $$ insert into public.event_attendee (event_id, person_id) values
       ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1'),
       ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a2'),
       ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a3') $$,
  'people are invited'
);
select throws_ok(
  $$ insert into public.event_attendee (event_id, person_id) values
       ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1') $$,
  '23505', null,
  'someone is invited once'
);

-- 3: a deleted contact leaves the event.
delete from public.person where id = '00000000-0000-0000-0000-0000000000a3';
select is(
  (select count(*)::int from public.event_attendee), 2,
  'deleting a person removes them from the event'
);

-- 4-5: refusals, nothing written.
select throws_ok(
  $$ select public.mark_event_done('00000000-0000-0000-0000-0000000000e1',
       array['00000000-0000-0000-0000-0000000000ff']::uuid[], '2026-10-08') $$,
  'P0001', null,
  'someone not invited cannot be marked as there'
);
select is(
  (select done_at from public.event), null,
  'a refused call leaves the event open'
);

-- 6-10: marking done.
select lives_ok(
  $$ select public.mark_event_done('00000000-0000-0000-0000-0000000000e1',
       array['00000000-0000-0000-0000-0000000000a1']::uuid[], '2026-10-09') $$,
  'the event is marked done'
);
select ok(
  (select done_at is not null from public.event),
  'done_at is set'
);
select results_eq(
  $$ select person_id::text, came from public.event_attendee order by person_id $$,
  $$ values ('00000000-0000-0000-0000-0000000000a1', true),
            ('00000000-0000-0000-0000-0000000000a2', false) $$,
  'who was there, and who missed it'
);
select results_eq(
  $$ select person_id::text, kind::text, text, happened_on
     from public.activity where kind = 'event' $$,
  $$ values ('00000000-0000-0000-0000-0000000000a1', 'event', 'Workshop',
             '2026-10-09'::date) $$,
  'only who was there gets an Event entry, on the device''s day'
);
select throws_ok(
  $$ select public.mark_event_done('00000000-0000-0000-0000-0000000000e1',
       array[]::uuid[], '2026-10-09') $$,
  'P0001', null,
  'an event is marked done once'
);

-- 11-12: a done event's attendance is read-only.
select throws_ok(
  $$ insert into public.event_attendee (event_id, person_id) values
       ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a4') $$,
  '42501', null,
  'nobody joins a done event'
);
delete from public.event_attendee;
update public.event_attendee set came = false;
select is(
  (select count(*)::int from public.event_attendee where came), 1,
  'a done event''s attendance neither changes nor goes'
);

-- 13-14: as B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.event_attendee), 0,
  'another user sees nobody'
);
select throws_ok(
  $$ select public.mark_event_done('00000000-0000-0000-0000-0000000000e1',
       array[]::uuid[], '2026-10-09') $$,
  'P0002', null,
  'another user cannot mark it done'
);

select * from finish();
rollback;
```

- [ ] **Step 2: Create the migration**

Run: `supabase migration new event_attendees`

- [ ] **Step 3: Write it**

```sql
-- Event attendees (#152): who is invited to an event, who was there, and
-- marking it done. Event workflows (#153) build on mark_event_done.

alter type public.activity_kind add value 'event';

alter table public.event
  add column done_at timestamptz,
  -- Target of event_attendee's composite foreign key.
  add constraint event_id_owner_key unique (id, owner_id);

create table public.event_attendee (
  event_id uuid not null,
  person_id uuid not null,
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  came boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (event_id, person_id),
  foreign key (event_id, owner_id)
    references public.event (id, owner_id) on delete cascade,
  foreign key (person_id, owner_id)
    references public.person (id, owner_id) on delete cascade
);

create index event_attendee_person_id_owner_id_idx
  on public.event_attendee (person_id, owner_id);

alter table public.event_attendee enable row level security;

-- Once an event is done its attendance is history: no one joins, leaves or
-- changes. mark_event_done writes `came` before it sets done_at.
create function public.event_open(p_event uuid) returns boolean
language sql stable security invoker set search_path = '' as $$
  select exists (
    select 1 from public.event where id = p_event and done_at is null
  )
$$;

create policy event_attendee_select_own on public.event_attendee
  for select to authenticated using (owner_id = (select auth.uid()));
create policy event_attendee_insert_own on public.event_attendee
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and public.event_open(event_id));
create policy event_attendee_update_own on public.event_attendee
  for update to authenticated
  using (owner_id = (select auth.uid()) and public.event_open(event_id))
  with check (owner_id = (select auth.uid()));
create policy event_attendee_delete_own on public.event_attendee
  for delete to authenticated
  using (owner_id = (select auth.uid()) and public.event_open(event_id));

revoke all on public.event_attendee from anon, authenticated;
grant select, insert, update, delete on public.event_attendee to authenticated;

-- Marks who was there, in one transaction: their flags, an Event entry in
-- each of their histories on the device's p_today, then done_at. plpgsql, so
-- the new 'event' value is not resolved while this migration is still open.
create function public.mark_event_done(
  p_event uuid, p_came uuid[], p_today date
) returns public.event
language plpgsql security invoker set search_path = '' as $$
declare
  marked public.event;
begin
  select * into marked from public.event where id = p_event for update;
  if not found then
    raise exception 'event % not found', p_event using errcode = 'P0002';
  end if;
  if marked.done_at is not null then
    raise exception 'event % is already done', p_event using errcode = 'P0001';
  end if;
  if exists (
    select 1 from unnest(p_came) as c(person_id)
    where not exists (
      select 1 from public.event_attendee a
      where a.event_id = p_event and a.person_id = c.person_id
    )
  ) then
    raise exception 'someone marked as there is not invited to event %', p_event
      using errcode = 'P0001';
  end if;

  update public.event_attendee
    set came = (person_id = any(p_came))
    where event_id = p_event;
  insert into public.activity (person_id, kind, text, happened_on)
    select a.person_id, 'event', marked.title, p_today
    from public.event_attendee a
    where a.event_id = p_event and a.came;
  update public.event set done_at = now()
    where id = p_event
    returning * into marked;
  return marked;
end $$;

revoke execute on function public.event_open(uuid) from public, anon;
revoke execute on function public.mark_event_done(uuid, uuid[], date)
  from public, anon;
grant execute on function public.event_open(uuid) to authenticated;
grant execute on function public.mark_event_done(uuid, uuid[], date)
  to authenticated;
```

`event_open` reads `event` under the caller's RLS, so another user's event never counts as open.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/*_event_attendees.sql supabase/tests/event_attendee_test.sql
git commit -m "feat(calendar): invite people to an event and mark who was there"
```

CI's `Supabase migrations` job runs the tests on the PR. Don't push the migration to the hosted project.

---
### Task 2: Attendees in the app's data

**Files:**
- Modify: `lib/features/calendar/domain/calendar_event.dart`
- Modify: `lib/features/calendar/data/event_repository.dart`
- Modify: `lib/features/calendar/presentation/calendar_controller.dart`
- Modify: `lib/features/contacts/domain/activity.dart`, `lib/features/contacts/presentation/people_copy.dart`
- Modify: `lib/l10n/app_en.arb` (`activityKindEvent`)
- Modify: `test/features/calendar/fake_event_repository.dart`
- Test: `test/features/calendar/data/event_repository_test.dart`, `test/features/calendar/domain/calendar_event_test.dart`, `test/features/calendar/presentation/calendar_controller_test.dart`

**Interfaces:**
- Consumes: Task 1's table, embed and RPC.
- Produces:
  - `typedef Attendee = ({String personId, bool came});`
  - `CalendarEvent.attendees` (`List<Attendee>`, default `const []`), `CalendarEvent.doneAt` (`DateTime?`), and the getters `done`, `cameCount`, plus `bool canMarkDone(DateTime now)`
  - `EventRepository.invite(String eventId, Iterable<String> personIds)`, `uninvite(String eventId, String personId)`, `markDone(String eventId, Iterable<String> came, DateTime today)`, all `Future<void>`
  - `EventsController.invite`, `uninvite`, `markDone`, with the same signatures
  - `ActivityKind.event` (not `byUser`), and `kindLabel` gives `l10n.activityKindEvent` ("Event")
  - `FakeEventRepository` implements the three new methods, recording `invite(<eventId>:<ids joined by ,>)`, `uninvite(<eventId>:<personId>)` and `markDone(<eventId>:<ids joined by ,>)`

- [ ] **Step 1: Add the copy** to `app_en.arb`, after `activityKindStep`

```json
  "activityKindEvent": "Event",
  "@activityKindEvent": {
    "description": "Kind of history entry: the person was at one of the user's events (a workshop, a training). The entry's title is the event's title."
  },
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Add to `test/features/calendar/data/event_repository_test.dart`:

```dart
  test('reads the attendees and when it was marked done', () {
    final event = eventFromRow({
      'id': 'e1',
      'title': 'Workshop',
      'starts_at': '2026-10-08T17:00:00+00:00',
      'ends_at': null,
      'place': null,
      'link': null,
      'notes': null,
      'done_at': '2026-10-09T08:00:00+00:00',
      'event_attendee': [
        {'person_id': 'p1', 'came': true},
        {'person_id': 'p2', 'came': false},
      ],
    });

    expect(event.doneAt, DateTime.utc(2026, 10, 9, 8));
    expect(event.done, isTrue);
    expect(event.attendees, [
      (personId: 'p1', came: true),
      (personId: 'p2', came: false),
    ]);
    expect(event.cameCount, 1);
  });

  test('a row without the embed has nobody invited', () {
    final event = eventFromRow({
      'id': 'e1',
      'title': 'Workshop',
      'starts_at': '2026-10-08T17:00:00+00:00',
    });

    expect(event.attendees, isEmpty);
    expect(event.done, isFalse);
  });
```

The second test means `eventFromRow` must read missing keys as null. Use `row['ends_at']`, `row['done_at']` and `row['event_attendee']` with null-safe casts.

Add to `test/features/calendar/domain/calendar_event_test.dart`:

```dart
  group('canMarkDone', () {
    final starts = DateTime(2026, 10, 8, 19);
    CalendarEvent event({
      List<Attendee> attendees = const [(personId: 'p1', came: false)],
      DateTime? doneAt,
    }) => CalendarEvent(
      id: 'e1',
      title: 'Workshop',
      startsAt: starts,
      attendees: attendees,
      doneAt: doneAt,
    );

    test('once it has started, with someone invited', () {
      expect(event().canMarkDone(starts), isTrue);
      expect(event().canMarkDone(DateTime(2026, 10, 9)), isTrue);
    });

    test('not before it starts, not with nobody, not twice', () {
      expect(event().canMarkDone(DateTime(2026, 10, 8, 18, 59)), isFalse);
      expect(event(attendees: const []).canMarkDone(starts), isFalse);
      expect(event(doneAt: starts).canMarkDone(starts), isFalse);
    });
  });
```

Add to `test/features/calendar/presentation/calendar_controller_test.dart`. Extend `_container` to also override `peopleRepositoryProvider` with a `FakePeopleRepository` and `activityRepositoryProvider` with a `FakeActivityRepository`; pass them in.

```dart
  test('invite and uninvite reload the event with its people', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);

    await events.invite('e1', ['p1', 'p2']);
    expect(
      container.read(eventsProvider(_owner)).value!.single.attendees,
      [(personId: 'p1', came: false), (personId: 'p2', came: false)],
    );

    await events.uninvite('e1', 'p1');
    expect(
      container.read(eventsProvider(_owner)).value!.single.attendees,
      [(personId: 'p2', came: false)],
    );
    expect(fake.calls.where((call) => call == 'list()'), hasLength(3));
  });

  test('marking done reloads the events and the people', () async {
    final fake = FakeEventRepository([_workshop]);
    final people = FakePeopleRepository();
    final container = _container(fake, people: people);
    await container.read(eventsProvider(_owner).future);
    await container.read(peopleProvider(_owner).future);
    final listed = people.calls.where((call) => call == 'list()').length;
    final events = container.read(eventsProvider(_owner).notifier);
    await events.invite('e1', ['p1', 'p2']);

    await events.markDone('e1', ['p1'], DateTime(2026, 10, 9));
    await container.read(peopleProvider(_owner).future);

    final done = container.read(eventsProvider(_owner)).value!.single;
    expect(done.done, isTrue);
    expect(done.attendees, [
      (personId: 'p1', came: true),
      (personId: 'p2', came: false),
    ]);
    expect(fake.calls, contains('markDone(e1:p1)'));
    expect(
      people.calls.where((call) => call == 'list()').length,
      listed + 1,
    );
  });
```

If `FakePeopleRepository` records calls under another name, use what it records (read `test/features/contacts/fake_people_repository.dart`), and keep the assertion "the people were listed once more".

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/features/calendar`
Expected: compile errors, because `Attendee`, `doneAt`, `invite`, `uninvite` and `markDone` don't exist.

- [ ] **Step 4: The domain** (`calendar_event.dart`)

Add, above `CalendarEvent`:

```dart
/// Someone invited to an event, and whether they were there once it is
/// marked done.
typedef Attendee = ({String personId, bool came});
```

In `CalendarEvent`: add the constructor parameters `this.attendees = const [], this.doneAt,`, and:

```dart
  /// Who is invited, in no order: screens sort them by name.
  final List<Attendee> attendees;

  /// When "Mark who was there" was done. From then on attendance is history.
  final DateTime? doneAt;

  bool get done => doneAt != null;

  /// How many were there. Meaningful once [done].
  int get cameCount => attendees.where((attendee) => attendee.came).length;

  /// "Mark who was there" is offered from the start, until it is done, and
  /// only with someone to mark.
  bool canMarkDone(DateTime now) =>
      !done && attendees.isNotEmpty && !startsAt.isAfter(now);
```

- [ ] **Step 5: The repository** (`event_repository.dart`)

```dart
  /// Every column, and who is invited.
  static const String _columns = '*, event_attendee(person_id, came)';
```

Use `.select(_columns)` in `list`, `add` and `update`. Add the three methods (import `dayColumn` from `people_repository.dart`, which is already imported):

```dart
  Future<void> invite(String eventId, Iterable<String> personIds) =>
      guardPeople(
        () => _client.from('event_attendee').insert([
          for (final personId in personIds)
            {'event_id': eventId, 'person_id': personId},
        ]),
      );

  Future<void> uninvite(String eventId, String personId) => guardPeople(
    () => _client
        .from('event_attendee')
        .delete()
        .eq('event_id', eventId)
        .eq('person_id', personId),
  );

  /// Who was there, an Event entry in each of their histories on [today],
  /// and the event done, in one transaction. An event already done, or an
  /// id that isn't invited, is refused.
  Future<void> markDone(
    String eventId,
    Iterable<String> came,
    DateTime today,
  ) => guardPeople(
    () => _client.rpc<Object?>(
      'mark_event_done',
      params: {
        'p_event': eventId,
        'p_came': came.toList(),
        'p_today': dayColumn(today),
      },
    ),
  );
```

In `eventFromRow`, add:

```dart
  doneAt: switch (row['done_at']) {
    final String at => DateTime.parse(at),
    _ => null,
  },
  attendees: [
    for (final attendee in (row['event_attendee'] as List?) ?? const [])
      (
        personId: (attendee as Map<String, dynamic>)['person_id'] as String,
        came: attendee['came'] as bool,
      ),
  ],
```

`draftToEventRow` is unchanged: the form never writes attendance.

- [ ] **Step 6: The controller** (`calendar_controller.dart`)

Import `people_controller.dart` and `history_controller.dart` from `lib/features/contacts/presentation/`. Add:

```dart
  /// Throws `PeopleFailure`, and then nobody is added.
  Future<void> invite(String eventId, Iterable<String> personIds) async {
    await ref.read(eventRepositoryProvider).invite(eventId, personIds);
    await _reload();
  }

  Future<void> uninvite(String eventId, String personId) async {
    await ref.read(eventRepositoryProvider).uninvite(eventId, personId);
    await _reload();
  }

  /// Marks who was there. Their histories and last contact move with it, so
  /// the book and any open history reload too. Throws `PeopleFailure`.
  Future<void> markDone(
    String eventId,
    Iterable<String> came,
    DateTime today,
  ) async {
    await ref.read(eventRepositoryProvider).markDone(eventId, came, today);
    if (!ref.mounted) return;
    ref
      ..invalidate(peopleProvider(owner))
      ..invalidate(historyProvider);
    await _reload();
  }

  /// The embed is the truth for attendance: read it again.
  Future<void> _reload() async {
    if (!ref.mounted) return;
    ref.invalidateSelf();
    await future;
  }
```

If an import cycle or an API difference gets in the way (for example `future` on a family notifier), follow how `WorkflowsController.edit` reloads, and keep the guarantee that the caller's `await` returns after the new list is in.

- [ ] **Step 7: The Event history kind**

In `activity.dart`, add `event` after `step` with a doc line ("written by the database when the person was at an event"), and make `byUser` `this != stage && this != step && this != event`. Update the enum's doc comment. In `people_copy.dart`, add `ActivityKind.event => l10n.activityKindEvent,` to `kindLabel`. Run `flutter analyze` and fix any other exhaustive `switch` on `ActivityKind` it points at, giving `event` what `step` gets.

- [ ] **Step 8: The fake**

In `FakeEventRepository`, add:

```dart
  CalendarEvent _with(
    String eventId,
    List<Attendee> Function(List<Attendee>) change, {
    DateTime? doneAt,
  }) {
    final index = store.indexWhere((event) => event.id == eventId);
    final event = store[index];
    final changed = CalendarEvent(
      id: event.id,
      title: event.title,
      startsAt: event.startsAt,
      endsAt: event.endsAt,
      place: event.place,
      link: event.link,
      notes: event.notes,
      attendees: change(event.attendees),
      doneAt: doneAt ?? event.doneAt,
    );
    store[index] = changed;
    return changed;
  }

  @override
  Future<void> invite(String eventId, Iterable<String> personIds) async {
    _record('invite($eventId:${personIds.join(',')})');
    _with(eventId, (attendees) => [
      ...attendees,
      for (final id in personIds) (personId: id, came: false),
    ]);
  }

  @override
  Future<void> uninvite(String eventId, String personId) async {
    _record('uninvite($eventId:$personId)');
    _with(eventId, (attendees) => [
      for (final attendee in attendees)
        if (attendee.personId != personId) attendee,
    ]);
  }

  @override
  Future<void> markDone(
    String eventId,
    Iterable<String> came,
    DateTime today,
  ) async {
    _record('markDone($eventId:${came.join(',')})');
    final there = came.toSet();
    _with(
      eventId,
      (attendees) => [
        for (final attendee in attendees)
          (personId: attendee.personId, came: there.contains(attendee.personId)),
      ],
      doneAt: DateTime.now(),
    );
  }
```

Also keep `update` and the draft mapping preserving `attendees` and `doneAt` from the stored event, so an edit doesn't drop who is invited.

- [ ] **Step 9: Run the tests**

Run: `flutter test test/features/calendar test/features/contacts`
Expected: PASS.

- [ ] **Step 10: Commit**

```bash
git add lib test
git commit -m "feat(calendar): load an event's people and mark who was there"
```

---
### Task 3: The people picker

**Files:**
- Create: `lib/features/calendar/presentation/people_picker.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/calendar/presentation/people_picker_test.dart`

**Interfaces:**
- Consumes: `Person`, `Stage` (`lib/features/contacts/domain/person.dart`), `searchKey`, `stageLabel` (`people_copy.dart`), `ContactRow` (with `checked`), `LoomiaDialog`, `AppTheme.search`.
- Produces: `Future<Set<String>?> pickPeople(BuildContext context, {required List<Person> people, Set<String> except = const {}})`, and the l10n keys `peoplePickerTitle`, `peoplePickerSearch`, `peoplePickerAdd`, `peoplePickerNobody`.

- [ ] **Step 1: Add the copy**

```json
  "peoplePickerTitle": "Add people",
  "@peoplePickerTitle": {
    "description": "Title of the sheet that picks contacts to invite to an event, and the action beside an event's People heading."
  },
  "peoplePickerSearch": "Search people",
  "@peoplePickerSearch": {
    "description": "Hint in the search field of the sheet that picks contacts to invite to an event."
  },
  "peoplePickerAdd": "{count, plural, =0{Add} =1{Add one person} other{Add {count} people}}",
  "@peoplePickerAdd": {
    "description": "Button that invites the picked contacts to the event. count is how many are picked; at 0 the button is disabled.",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "peoplePickerNobody": "Nobody else to add.",
  "@peoplePickerNobody": {
    "description": "Shown in the people picker when every contact matching the search is already invited, or there are no contacts."
  }
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests** `test/features/calendar/presentation/people_picker_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/presentation/people_picker.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

Person _person(String id, String name, Stage stage) => Person(
  id: id,
  name: name,
  stage: stage,
  stageSince: DateTime.utc(2026, 9),
);

final _book = [
  _person('p1', 'Claire Moreau', Stage.prospect),
  _person('p2', 'Marie Dupont', Stage.customer),
  _person('p3', 'Sarah Lemaire', Stage.prospect),
];

Future<void> _open(
  WidgetTester tester, {
  Set<String> except = const {},
  required void Function(Set<String>? picked) result,
}) async {
  tester.view
    ..physicalSize = const Size(390, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async =>
                  result(await pickPeople(context, people: _book, except: except)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picks several people, without those already invited', (
    tester,
  ) async {
    Set<String>? picked;
    await _open(tester, except: {'p3'}, result: (value) => picked = value);

    expect(find.text('Sarah Lemaire'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Add')).onPressed,
      isNull,
    );
    await tester.tap(find.text('Claire Moreau'));
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 2 people'));
    await tester.pumpAndSettle();

    expect(picked, {'p1', 'p2'});
  });

  testWidgets('search narrows the list and keeps who is picked', (
    tester,
  ) async {
    Set<String>? picked;
    await _open(tester, result: (value) => picked = value);

    await tester.tap(find.text('Claire Moreau'));
    await tester.enterText(find.byType(TextField), 'mari');
    await tester.pumpAndSettle();

    expect(find.text('Claire Moreau'), findsNothing);
    expect(find.text('Marie Dupont'), findsOneWidget);
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 2 people'));
    await tester.pumpAndSettle();

    expect(picked, {'p1', 'p2'});
  });

  testWidgets('nobody left to add says so', (tester) async {
    await _open(tester, except: {'p1', 'p2', 'p3'}, result: (_) {});

    expect(find.text('Nobody else to add.'), findsOneWidget);
  });

  testWidgets('dismissing picks nobody', (tester) async {
    var called = false;
    Set<String>? picked = {'x'};
    await _open(
      tester,
      result: (value) {
        called = true;
        picked = value;
      },
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(picked, isNull);
  });
}
```

If `searchKey` doesn't match "mari" inside "Marie Dupont" the way the Contacts search does, follow how `contact_list.dart` filters. The test's intent is "typing part of a name narrows the list".

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/features/calendar/presentation/people_picker_test.dart`
Expected: FAIL, `people_picker.dart` not found.

- [ ] **Step 4: Write the picker** `lib/features/calendar/presentation/people_picker.dart`

```dart
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// People to invite: [people] (the book, sorted by name) without [except],
/// searchable, several at once. A sheet on mobile, a dialog elsewhere.
/// Resolves to the ids picked, or null when dismissed.
Future<Set<String>?> pickPeople(
  BuildContext context, {
  required List<Person> people,
  Set<String> except = const {},
}) => LoomiaDialog.show<Set<String>>(
  context,
  (_) => _PeoplePicker(
    people: [
      for (final person in people)
        if (!except.contains(person.id)) person,
    ],
  ),
);

class _PeoplePicker extends StatefulWidget {
  const _PeoplePicker({required this.people});

  final List<Person> people;

  @override
  State<_PeoplePicker> createState() => _PeoplePickerState();
}

class _PeoplePickerState extends State<_PeoplePicker> {
  final Set<String> _picked = {};
  String _query = '';

  void _toggle(String id) => setState(() {
    if (!_picked.remove(id)) _picked.add(id);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = searchKey(_query);
    // ponytail: builds every row, inside the dialog's scroll view; a lazy
    // list if a book of thousands makes the sheet slow to open.
    final shown = query.isEmpty
        ? widget.people
        : [
            for (final person in widget.people)
              if (searchKey(person.name).contains(query)) person,
          ];

    return LoomiaDialog(
      title: l10n.peoplePickerTitle,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _picked.isEmpty
              ? null
              : () => Navigator.pop(context, {..._picked}),
          child: Text(l10n.peoplePickerAdd(_picked.length)),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.sm,
        children: [
          TextField(
            textInputAction: TextInputAction.search,
            decoration: AppTheme.search(context).copyWith(
              hintText: l10n.peoplePickerSearch,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                l10n.peoplePickerNobody,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: LoomiaColors.of(context).textMuted,
                ),
              ),
            )
          else
            for (final person in shown)
              ContactRow(
                name: person.name,
                subtitle: stageLabel(l10n, person.stage),
                checked: _picked.contains(person.id),
                onTap: () => _toggle(person.id),
              ),
        ],
      ),
    );
  }
}
```

If `AppTheme.search` already sets a prefix icon, drop the `prefixIcon` line. Match what `contact_list.dart` passes.

- [ ] **Step 5: Run the tests**

Run: `flutter test test/features/calendar/presentation/people_picker_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/calendar/presentation/people_picker.dart lib/l10n/app_en.arb test/features/calendar/presentation/people_picker_test.dart
git commit -m "feat(calendar): pick people to invite"
```

---
### Task 4: People on the event screen

**Files:**
- Modify: `lib/features/calendar/presentation/event_page.dart`
- Create: `lib/features/calendar/presentation/who_was_there_sheet.dart`
- Modify: `lib/features/calendar/presentation/event_row.dart` (the count on the row)
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/calendar/presentation/event_page_test.dart`, `test/features/calendar/presentation/calendar_page_test.dart`

**Interfaces:**
- Consumes: `CalendarEvent.attendees/done/cameCount/canMarkDone`, `EventsController.invite/uninvite/markDone` (Task 2); `pickPeople` (Task 3); `peopleProvider` (`people_controller.dart`); `openContact` (`contacts_page.dart`); `stageLabel`, `peopleFailureCopy` (`people_copy.dart`); `searchKey`.
- Produces:
  - `typedef EventPerson = ({Person person, bool came});`
  - `EventView` gains `required List<EventPerson> people`, `required DateTime now`, `required VoidCallback onAddPeople`, `required void Function(Person) onRemove`, `required void Function(Person) onOpenPerson` and `required VoidCallback onMarkDone`
  - `Future<void> showWhoWasThere(BuildContext context, {required CalendarEvent event, required List<EventPerson> people})`
  - l10n keys: `eventPeople`, `eventNoPeople`, `eventPersonInvited`, `eventPersonWasThere`, `eventPersonMissed`, `eventRemovePerson`, `eventMarkWhoWasThere`, `eventWhoWasThere`, `eventWhoWasThereBody`, `eventMarkDone`, `eventDoneBanner`, `eventInvitedCount`, `eventThereCount`, `eventRowLine`

- [ ] **Step 1: Add the copy**

```json
  "eventPeople": "People",
  "@eventPeople": {
    "description": "Heading of the list of contacts invited to an event, on the event's screen."
  },
  "eventNoPeople": "Nobody invited yet.",
  "@eventNoPeople": {
    "description": "Shown under an event's People heading when nobody is invited."
  },
  "eventPersonInvited": "{stage} · invited",
  "@eventPersonInvited": {
    "description": "Second line of an invited contact's row on an event, before the event is marked done. stage is their stage, e.g. 'Prospect'.",
    "placeholders": {
      "stage": { "type": "String" }
    }
  },
  "eventPersonWasThere": "{stage} · was there",
  "@eventPersonWasThere": {
    "description": "Second line of a contact's row on a done event when they were at it (in person or online). stage is their stage, e.g. 'Prospect'.",
    "placeholders": {
      "stage": { "type": "String" }
    }
  },
  "eventPersonMissed": "{stage} · missed it",
  "@eventPersonMissed": {
    "description": "Second line of a contact's row on a done event when they were invited but not there. Neutral, never a reproach. stage is their stage.",
    "placeholders": {
      "stage": { "type": "String" }
    }
  },
  "eventRemovePerson": "Remove {name} from the event",
  "@eventRemovePerson": {
    "description": "Tooltip of the button that takes an invited contact off an event. name is the contact's name.",
    "placeholders": {
      "name": { "type": "String" }
    }
  },
  "eventMarkWhoWasThere": "Mark who was there",
  "@eventMarkWhoWasThere": {
    "description": "Button on an event that has started: opens the sheet that records which invited contacts were there."
  },
  "eventWhoWasThere": "Who was there?",
  "@eventWhoWasThere": {
    "description": "Title of the sheet that records which invited contacts were at an event, in person or online."
  },
  "eventWhoWasThereBody": "Everyone is ticked. Untick anyone who missed it.",
  "@eventWhoWasThereBody": {
    "description": "Body of the Who was there? sheet: every invited contact starts ticked."
  },
  "eventMarkDone": "{count, plural, =0{Nobody was there} =1{Done · 1 was there} other{Done · {count} were there}}",
  "@eventMarkDone": {
    "description": "Button of the Who was there? sheet that saves it. count is how many are ticked.",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "eventDoneBanner": "{count, plural, =0{Done · nobody was there} =1{Done · 1 of {total} was there} other{Done · {count} of {total} were there}}",
  "@eventDoneBanner": {
    "description": "Banner on an event marked done. count is how many were there, total how many were invited.",
    "placeholders": {
      "count": { "type": "int" },
      "total": { "type": "int" }
    }
  },
  "eventInvitedCount": "{count, plural, =1{1 invited} other{{count} invited}}",
  "@eventInvitedCount": {
    "description": "On an event's row in the Calendar, before it is done: how many contacts are invited.",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "eventThereCount": "{count, plural, =0{nobody was there} =1{1 was there} other{{count} were there}}",
  "@eventThereCount": {
    "description": "On a done event's row in the Calendar: how many of the invited contacts were there.",
    "placeholders": {
      "count": { "type": "int" }
    }
  },
  "eventRowLine": "{where} · {people}",
  "@eventRowLine": {
    "description": "Second line of an event's row in the Calendar when it has both: where (a place, or 'Online') and the people count (eventInvitedCount or eventThereCount).",
    "placeholders": {
      "where": { "type": "String" },
      "people": { "type": "String" }
    }
  }
```

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

In `test/features/calendar/presentation/event_page_test.dart`, give `_pumpView` the new parameters (`people`, `now`, and the callbacks, defaulting to no-ops and to `DateTime(2026, 10, 8, 18)`, which is before `_workshop`'s start). Then add:

```dart
final _claire = Person(
  id: 'p1',
  name: 'Claire Moreau',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 9),
);
final _sarah = Person(
  id: 'p2',
  name: 'Sarah Lemaire',
  stage: Stage.customer,
  stageSince: DateTime.utc(2026, 9),
);

  testWidgets('before it starts: who is invited, add and remove', (
    tester,
  ) async {
    Person? removed;
    var adding = false;
    await _pumpView(
      tester,
      _workshop,
      people: [(person: _claire, came: false), (person: _sarah, came: false)],
      onAddPeople: () => adding = true,
      onRemove: (person) => removed = person,
    );

    await tester.scrollUntilVisible(find.text('Sarah Lemaire'), 200);
    expect(find.text('Prospect · invited'), findsOneWidget);
    expect(find.text('Customer · invited'), findsOneWidget);
    expect(find.text('Mark who was there'), findsNothing);

    await tester.tap(find.byTooltip('Remove Claire Moreau from the event'));
    await tester.tap(find.text('Add people'));
    expect(removed, _claire);
    expect(adding, isTrue);
  });

  testWidgets('once started: Mark who was there', (tester) async {
    var marking = false;
    await _pumpView(
      tester,
      _workshop,
      people: [(person: _claire, came: false)],
      now: DateTime(2026, 10, 8, 19, 5),
      onMarkDone: () => marking = true,
    );

    await tester.tap(find.text('Mark who was there'));
    expect(marking, isTrue);
  });

  testWidgets('done: the banner, who was there, nothing to change', (
    tester,
  ) async {
    final done = CalendarEvent(
      id: 'e1',
      title: 'Workshop',
      startsAt: DateTime(2026, 10, 8, 19),
      doneAt: DateTime(2026, 10, 9),
      attendees: const [
        (personId: 'p1', came: true),
        (personId: 'p2', came: false),
      ],
    );
    await _pumpView(
      tester,
      done,
      people: [(person: _claire, came: true), (person: _sarah, came: false)],
      now: DateTime(2026, 10, 9, 9),
    );

    expect(find.text('Done · 1 of 2 was there'), findsOneWidget);
    expect(find.text('Prospect · was there'), findsOneWidget);
    expect(find.text('Customer · missed it'), findsOneWidget);
    expect(find.text('Mark who was there'), findsNothing);
    expect(find.text('Add people'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });
```

And the in-app tests, with a book through `FakePeopleRepository([_claire, _sarah])`:

```dart
  testWidgets('in the app: invite from the picker, then remove', (
    tester,
  ) async {
    final events = FakeEventRepository([_tonight()]);
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1000),
      events: events,
      people: FakePeopleRepository([_claire, _sarah]),
    );
    container.read(routerProvider).go(Routes.eventLocation('e1'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Add people'), 200);
    await tester.tap(find.text('Add people'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Claire Moreau'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add one person'));
    await tester.pumpAndSettle();

    expect(events.calls, contains('invite(e1:p1)'));
    expect(find.text('Prospect · invited'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Claire Moreau from the event'));
    await tester.pumpAndSettle();

    expect(events.calls, contains('uninvite(e1:p1)'));
    expect(find.text('Nobody invited yet.'), findsOneWidget);
  });

  testWidgets('in the app: who was there, then the banner', (tester) async {
    final started = DateTime.now().subtract(const Duration(hours: 1));
    final events = FakeEventRepository([
      CalendarEvent(
        id: 'e1',
        title: 'Workshop',
        startsAt: started,
        attendees: const [
          (personId: 'p1', came: false),
          (personId: 'p2', came: false),
        ],
      ),
    ]);
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1000),
      events: events,
      people: FakePeopleRepository([_claire, _sarah]),
    );
    container.read(routerProvider).go(Routes.eventLocation('e1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark who was there'));
    await tester.pumpAndSettle();
    expect(find.text('Who was there?'), findsOneWidget);
    // Everyone starts ticked; Sarah missed it.
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Sarah Lemaire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done · 1 was there'));
    await tester.pumpAndSettle();

    expect(events.calls, contains('markDone(e1:p1)'));
    expect(find.text('Done · 1 of 2 was there'), findsOneWidget);
  });

  testWidgets('someone no longer in the book is not listed', (tester) async {
    final day = today();
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1000),
      events: FakeEventRepository([
        CalendarEvent(
          id: 'e1',
          title: 'Workshop',
          startsAt: DateTime(day.year, day.month, day.day, 19),
          attendees: const [
            (personId: 'p1', came: false),
            (personId: 'gone', came: false),
          ],
        ),
      ]),
      people: FakePeopleRepository([_claire]),
    );
    container.read(routerProvider).go(Routes.eventLocation('e1'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Claire Moreau'), 200);
    expect(find.byType(ContactRow), findsOneWidget);
  });
```

Imports to add: `person.dart`, `contact_row.dart`, `fake_people_repository.dart`. If the people repository fake takes its book another way, follow its constructor.

In `test/features/calendar/presentation/calendar_page_test.dart`, add:

```dart
  testWidgets("a row says how many are invited, or were there", (
    tester,
  ) async {
    await _pump(
      tester,
      events: [
        CalendarEvent(
          id: 'e1',
          title: 'Essential oils for sleep',
          startsAt: DateTime(2026, 10, 8, 19),
          place: 'Studio Lumière',
          attendees: const [
            (personId: 'p1', came: false),
            (personId: 'p2', came: false),
          ],
        ),
        CalendarEvent(
          id: 'e2',
          title: 'Training',
          startsAt: DateTime(2026, 10, 8, 10),
          doneAt: DateTime(2026, 10, 8, 12),
          attendees: const [(personId: 'p1', came: true)],
        ),
      ],
    );

    expect(find.text('Studio Lumière · 2 invited'), findsOneWidget);
    expect(find.text('1 was there'), findsOneWidget);
  });
```

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/features/calendar/presentation`
Expected: compile errors, because `EventView` has no `people`.

- [ ] **Step 4: The row's second line** (`event_row.dart`)

Replace the `where` computation with:

```dart
    final l10n = AppLocalizations.of(context);
    final where =
        event.place ?? (event.link == null ? null : l10n.eventOnline);
    final count = event.attendees.isEmpty
        ? null
        : event.done
        ? l10n.eventThereCount(event.cameCount)
        : l10n.eventInvitedCount(event.attendees.length);
    final line = where != null && count != null
        ? l10n.eventRowLine(where, count)
        : where ?? count;
```

and show `line` where `where` was shown.

- [ ] **Step 5: The Who was there sheet** `lib/features/calendar/presentation/who_was_there_sheet.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_page.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// "Who was there?": everyone invited, ticked; Done marks the event done
/// with whoever is still ticked (spec §3, Event 4).
Future<void> showWhoWasThere(
  BuildContext context, {
  required CalendarEvent event,
  required List<EventPerson> people,
}) => LoomiaDialog.show<void>(
  context,
  (_) => _WhoWasThere(event: event, people: people),
);

class _WhoWasThere extends ConsumerStatefulWidget {
  const _WhoWasThere({required this.event, required this.people});

  final CalendarEvent event;
  final List<EventPerson> people;

  @override
  ConsumerState<_WhoWasThere> createState() => _WhoWasThereState();
}

class _WhoWasThereState extends ConsumerState<_WhoWasThere> {
  late final Set<String> _there = {
    for (final (:person, came: _) in widget.people) person.id,
  };
  bool _saving = false;
  PeopleFailure? _failure;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      await ref
          .read(eventsProvider(ref.read(accountProvider)?.email).notifier)
          .markDone(widget.event.id, _there, today());
      if (mounted) Navigator.pop(context);
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = _failure;
    return LoomiaDialog(
      title: l10n.eventWhoWasThere,
      body: l10n.eventWhoWasThereBody,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.eventMarkDone(_there.length)),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xs,
        children: [
          if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
          for (final (:person, came: _) in widget.people)
            CheckboxListTile(
              value: _there.contains(person.id),
              onChanged: (ticked) => setState(() {
                if (ticked ?? false) {
                  _there.add(person.id);
                } else {
                  _there.remove(person.id);
                }
              }),
              title: Text(person.name),
              subtitle: Text(stageLabel(l10n, person.stage)),
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ),
    );
  }
}
```

If importing `event_page.dart` for `EventPerson` creates a cycle that bothers analyze, move `EventPerson` to the top of this file and import it from `event_page.dart` instead.

- [ ] **Step 6: The event screen** (`event_page.dart`)

Add `typedef EventPerson = ({Person person, bool came});` with the doc "An invited contact found in the book.". In `EventPane.build`, also watch the book, and build the people:

```dart
    final book = ref.watch(peopleProvider(ref.watch(accountProvider)?.email));
    final byId = {for (final person in book.value ?? const <Person>[]) person.id: person};
    // Someone deleted from the contacts on another device can linger until
    // the events reload; they are left out rather than shown nameless.
    final people = [
      for (final attendee in event.attendees)
        if (byId[attendee.personId] case final person?)
          (person: person, came: attendee.came),
    ]..sort(
        (a, b) => searchKey(a.person.name).compareTo(searchKey(b.person.name)),
      );
```

Pass to `EventView`:

```dart
      people: people,
      now: DateTime.now(),
      onAddPeople: () => unawaited(_invite(context, ref, event)),
      onRemove: (person) => unawaited(_uninvite(context, ref, event, person)),
      onOpenPerson: (person) => openContact(context, person.id),
      onMarkDone: () => unawaited(
        showWhoWasThere(context, event: event, people: people),
      ),
```

with these two methods in `EventPane`, next to `_edit`, using the same SnackBar-on-failure shape as `_delete`:

```dart
  Future<void> _invite(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final owner = ref.read(accountProvider)?.email;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final picked = await pickPeople(
      context,
      people: ref.read(peopleProvider(owner)).value ?? const [],
      except: {for (final attendee in event.attendees) attendee.personId},
    );
    if (picked == null || picked.isEmpty) return;
    try {
      await ref.read(eventsProvider(owner).notifier).invite(event.id, picked);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }

  Future<void> _uninvite(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
    Person person,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(eventsProvider(ref.read(accountProvider)?.email).notifier)
          .uninvite(event.id, person.id);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }
```

In `EventView`, add the new fields with docs, and after the notes block append:

```dart
        if (event.done) ...[
          const SizedBox(height: AppSpacing.lg),
          _DoneBanner(
            text: l10n.eventDoneBanner(event.cameCount, event.attendees.length),
          ),
        ] else if (event.canMarkDone(now)) ...[
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onMarkDone,
            child: Text(l10n.eventMarkWhoWasThere),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(
          title: l10n.eventPeople,
          actionLabel: event.done ? null : l10n.peoplePickerTitle,
          onAction: event.done ? null : onAddPeople,
        ),
        if (people.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              l10n.eventNoPeople,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: LoomiaColors.of(context).textMuted,
              ),
            ),
          )
        else
          for (final (:person, :came) in people)
            ContactRow(
              name: person.name,
              subtitle: _status(l10n, person, came),
              onTap: () => onOpenPerson(person),
              trailing: event.done
                  ? null
                  : IconButton(
                      onPressed: () => onRemove(person),
                      tooltip: l10n.eventRemovePerson(person.name),
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
```

with, in `EventView`:

```dart
  String _status(AppLocalizations l10n, Person person, bool came) {
    final stage = stageLabel(l10n, person.stage);
    if (!event.done) return l10n.eventPersonInvited(stage);
    return came
        ? l10n.eventPersonWasThere(stage)
        : l10n.eventPersonMissed(stage);
  }
```

and the banner at the end of the file:

```dart
/// "Done · 4 of 5 were there": attendance is history from here.
class _DoneBanner extends StatelessWidget {
  const _DoneBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.ms,
      ),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Row(
        spacing: AppSpacing.ms,
        children: [
          Icon(Icons.check_rounded, color: scheme.onSecondaryContainer),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

Imports: `section_header.dart`, `contact_row.dart`, `person.dart`, `search_key.dart`, `people_controller.dart`, `contacts_page.dart` (for `openContact`), `people_picker.dart`, `who_was_there_sheet.dart`. Update the event preview in `calendar_preview.dart` (`eventMobileLight`) to pass `people: const []`, `now: DateTime(2026, 10, 7, 9)` and no-op callbacks. Task 5 gives it real people.

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/calendar test/features/contacts test/features/today`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add lib test
git commit -m "feat(calendar): invite people and mark who was there"
```

---
### Task 5: Previews and goldens

**Files:**
- Modify: `lib/features/calendar/presentation/calendar_preview.dart`
- Modify: `test/previews_test.dart`
- Goldens (from CI only): `event_mobile_light.png`, `calendar_mobile_light.png`, `calendar_mobile_dark.png` and `calendar_desktop_light.png` change; `event_done_mobile_light.png` is new.

**Interfaces:**
- Consumes: `EventView`'s new parameters (Task 4) and `CalendarEvent.attendees/doneAt` (Task 2).
- Produces: `eventDoneMobileLight`.

- [ ] **Step 1: Give the previews people**

In `calendar_preview.dart`:
- Add `_people`: five `Person`s, as in the Figma: Claire Moreau (prospect), Sarah Lemaire (prospect), Amélie Rousseau (prospect), Marie Dupont (customer), Bruno Keller (team), ids `p1`–`p5`, `stageSince: DateTime.utc(2026, 9)`.
- Give `_events[1]` ("Essential oils for sleep") all five as attendees, `came: false`, and `_events[2]` ("New member training") three of them. That brings the Figma's "6 invited" style counts to the rows.
- `eventMobileLight`: `people` is the five sorted by name, `came: false`; `now: DateTime(2026, 10, 7, 9)` (before the start, so no Mark button).
- Add `eventDoneMobileLight` (`@Preview(group: 'Calendar', name: 'Event done — light', size: Size(390, 844))`): the same event with `doneAt: DateTime(2026, 10, 9, 9)`; Claire, Sarah, Marie and Bruno `came: true`, Amélie `came: false`; `now: DateTime(2026, 10, 9, 9)`.

Keep the `_app` helper and the fixed dates.

- [ ] **Step 2: List the new preview** in `test/previews_test.dart`

```dart
    'event_done_mobile_light': (const Size(390, 844), eventDoneMobileLight),
```

Run: `flutter test test/previews_test.dart`
Expected: PASS on macOS (rendering only).

- [ ] **Step 3: The quality gate**

Run: `dart format . && flutter analyze && flutter test`
Expected: no format changes, `No issues found!`, every test passing.

- [ ] **Step 4: Commit and push**

```bash
git add lib/features/calendar/presentation/calendar_preview.dart test/previews_test.dart
git commit -m "test(calendar): preview an event's people"
git push -u origin feature/152-event-attendees
```

If the push fails with "Connection closed … port 443":
`git -c credential.helper= -c credential.helper='!gh auth git-credential' push -u https://github.com/paulthvt/loomia.git feature/152-event-attendees`.

- [ ] **Step 5: Goldens from CI**

```bash
gh workflow run CI --ref feature/152-event-attendees -f update-goldens=true
gh run list --workflow CI --branch feature/152-event-attendees --event workflow_dispatch --limit 1
gh run watch <run-id>
gh run download <run-id> -n goldens -D /tmp/goldens-152
```

Copy into `test/goldens/` the PNGs that differ from the committed ones (`cmp`). They should be exactly the five listed under Files. Any other one that differs is a concern to report, not something to commit. Commit (`test(calendar): update the Calendar goldens for people`) and push.

The PR is opened by the controller after the final review, with `Closes #152`. After merge comes `supabase db push`, off the company VPN.
