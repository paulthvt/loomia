# Calendar Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Events exist and the Calendar tab shows them: a month grid, the selected day's events, add / edit / delete, and an event screen with directions and Join. Calendar replaces the Team tab, and WORTH A CHECK-IN moves onto Today on every size (#151).

**Architecture:** One migration adds `public.event`. A new feature, `lib/features/calendar/`, holds a pure domain (`calendar_event.dart`, `month_grid.dart`), a repository on `guardPeople`, and an `AsyncNotifier` family keyed by account, like `workflowsProvider`. The screens follow Contacts: on desktop a nested `ShellRoute` keeps the grid built while a pane on the right follows the URL (the selected day at `/calendar`, an event at `/calendar/:id`). On mobile and tablet, the calendar and an event are separate screens. Views are pure widgets (`CalendarView`, `EventView`), so previews and tests need no providers.

**Tech Stack:** Supabase Postgres + pgTAP, Flutter (`material_ui`, `cupertino_ui`), `flutter_riverpod` 3, `go_router`, `url_launcher` (already a dependency), `intl` (already a dependency).

**Spec:** `docs/superpowers/specs/2026-10-07-calendar-design.md` §1 (#151), §2, §3 (Calendar tab, Event, New / edit event), §5. Figma: [Calendar — #150](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=257-4672).

## Global Constraints

- No new dependency. No calendar package: the grid is built here (spec, Decisions).
- Schema only via `supabase migration new events`. pgTAP lives in `supabase/tests/event_test.sql` and runs in CI (`supabase test db`); there is no local Docker.
- New table: RLS enabled, four owner policies on `owner_id = (select auth.uid())`, `revoke all ... from anon, authenticated`, then `grant select, insert, update, delete ... to authenticated`, all in the same migration. `schema_rls_test.sql` enforces it.
- Table conventions: `id uuid primary key default gen_random_uuid()`, `owner_id uuid not null default auth.uid() references auth.users on delete cascade`, `created_at`/`updated_at timestamptz not null default now()`, and the `set_updated_at()` trigger.
- "Today" is the device's (`today()` in `lib/core/ui/pick_day.dart`). Instants are stored UTC and read with `toLocal()`.
- Dart: `package:loomia/...` imports; Material from `package:material_ui/material_ui.dart`, never `flutter/material.dart`; the domain imports no Flutter; repository methods throw `PeopleFailure` only (`guardPeople`); no interface with a single implementation.
- Theme: `Theme.of(context).colorScheme`, `LoomiaColors.of(context)`, `AppSpacing.*`, `AppRadii.*`. A widget-specific size is a named `static const` in its widget. No hard-coded colour.
- Responsive: branch on `context.screenSize`, never on pixel widths.
- Routing: add paths to `lib/app/router/routes.dart` first. No path literals in widgets.
- Pickers: `pickDay`, and the new `pickTime` (a Cupertino wheel on iOS, Material elsewhere).
- Copy: English only, in `lib/l10n/app_en.arb`, every key with a description; run `flutter gen-l10n` after editing. Informal register. No MLM or "recruit" vocabulary.
- `FilledButton.tonal` takes `style: AppTheme.tonal(context)`.
- Attendance copy ("Who was there?") is #152. Nothing in this plan mentions attendees.
- Quality gate before claiming done: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`.
- Commits: Conventional Commits, on branch `feature/151-calendar-tab` off `main`. The PR body has `Closes #151`.

## Rulings made while planning

- **New / edit is a sheet without a route** (`showEventForm`, like `showAddPerson`). The spec lists `/calendar/new`, but a modal has no URL anywhere else in the app.
- **All events load at once** (`EventRepository.list()`), ordered by `starts_at`, and are filtered in Dart. A user has dozens of events a year. The `(owner_id, starts_at)` index is there for when month-by-month loading is needed.
- **No event across midnight.** End is a time on the start's day and must be after the start. `ponytail:` comment in the form; add an end date if users ask.
- **Selection is UI state**, `calendarSelectionProvider` (`({DateTime month, DateTime day})`), not keyed by account. ‹ › selects the 1st of the new month, or today when it is the current month.
- **Link:** typed without a scheme, it gets `https://`. Anything else that isn't an http(s) address with a dotted host is refused in the form and by a DB check.
- **Directions:** `https://maps.apple.com/?q=` on iOS, `https://www.google.com/maps/search/?api=1&query=` everywhere else, opened with `url_launcher`. `_launch` moves out of `contact_page.dart` into `lib/core/ui/open_external.dart` so both screens share it.
- **`/team`** redirects to `/contacts` (no filter in the URL).
- **Store screenshots:** `calendar` takes `team`'s place.

## Review Focus

1. An event at 00:30 local time (the previous day in UTC) shows on its local day. Pinned in Task 2.
2. A link typed as `meet.google.com/abc` saves as `https://meet.google.com/abc`; `javascript:alert(1)` is refused by the form and by the table. Pinned in Tasks 1, 2 and 4.
3. Deleting the open event leaves for the calendar first, so its screen never flashes "not in your calendar". Pinned in Task 6.
4. A failed save keeps the form open with its message and the typed values. Pinned in Task 4.
5. The week starts on the locale's first day: Sunday in English, Monday in French. Pinned in Task 5.
6. Another user can't read, change or delete someone's events. Pinned in Task 1.

---

### Task 1: The `event` table

**Files:**
- Create: `supabase/migrations/<timestamp>_events.sql` (run `supabase migration new events`)
- Create: `supabase/tests/event_test.sql`

**Interfaces:**
- Produces: table `public.event (id, owner_id, title, starts_at, ends_at, place, link, notes, created_at, updated_at)`.

- [ ] **Step 1: Write the failing pgTAP test** in `supabase/tests/event_test.sql`

```sql
-- Events (#151): the calendar's table, scoped to its owner. Run with
-- `supabase test db`.
begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@example.com'),
  ('00000000-0000-0000-0000-00000000000b', 'b@example.com');

set local role authenticated;
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';

-- 1-2: a full event saves, owned by whoever wrote it.
select lives_ok(
  $$ insert into public.event
       (id, title, starts_at, ends_at, place, link, notes)
     values ('00000000-0000-0000-0000-0000000000e1', 'Workshop',
       '2026-10-08 17:00+00', '2026-10-08 19:00+00', 'Studio Lumière',
       'https://meet.google.com/abc', 'Bring the diffuser') $$,
  'an event saves'
);
select is(
  (select owner_id from public.event
    where id = '00000000-0000-0000-0000-0000000000e1'),
  '00000000-0000-0000-0000-00000000000a'::uuid,
  'owner_id defaults to the author'
);

-- 3-5: constraints.
select throws_ok(
  $$ insert into public.event (title, starts_at) values ('  ', now()) $$,
  '23514', null,
  'a title is not blank'
);
select throws_ok(
  $$ insert into public.event (title, starts_at, ends_at)
     values ('Call', '2026-10-08 17:00+00', '2026-10-08 16:00+00') $$,
  '23514', null,
  'an event ends after it starts'
);
select throws_ok(
  $$ insert into public.event (title, starts_at, link)
     values ('Call', now(), 'javascript:alert(1)') $$,
  '23514', null,
  'a link is a web address'
);

-- 6-7: as B.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000b", "role": "authenticated"}';
select is(
  (select count(*)::int from public.event), 0,
  'another user sees none of them'
);
update public.event set title = 'Taken';
delete from public.event;
select throws_ok(
  $$ insert into public.event (owner_id, title, starts_at)
     values ('00000000-0000-0000-0000-00000000000a', 'Planted', now()) $$,
  '42501', null,
  'another user cannot add an event for the owner'
);

-- 8: back as A, nothing moved.
set local request.jwt.claims =
  '{"sub": "00000000-0000-0000-0000-00000000000a", "role": "authenticated"}';
select is(
  (select title from public.event), 'Workshop',
  'another user can neither update nor delete it'
);

select * from finish();
rollback;
```

- [ ] **Step 2: Create the migration file**

Run: `supabase migration new events`
Expected: `Created new migration at supabase/migrations/<timestamp>_events.sql`. It is empty, so CI's `Supabase migrations` job fails on `relation "public.event" does not exist`. That is the red; there is no local Docker.

- [ ] **Step 3: Write the migration**

```sql
-- Events (#151): what is on the calendar. Attendees (#152) and event
-- workflows (#153) come later.

create table public.event (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users on delete cascade,
  title text not null check (length(trim(title)) > 0),
  starts_at timestamptz not null,
  ends_at timestamptz check (ends_at > starts_at),
  place text,
  -- A meeting link. The app adds https:// to a bare address.
  link text check (link ~* '^https?://'),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- The calendar reads by date. Today it loads everything; this is for when
-- it reads a month at a time.
create index event_owner_id_starts_at_idx
  on public.event (owner_id, starts_at);

create trigger event_set_updated_at before update on public.event
  for each row execute function public.set_updated_at();

alter table public.event enable row level security;

create policy event_select_own on public.event
  for select to authenticated using (owner_id = (select auth.uid()));
create policy event_insert_own on public.event
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy event_update_own on public.event
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy event_delete_own on public.event
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.event from anon, authenticated;
grant select, insert, update, delete on public.event to authenticated;
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/*_events.sql supabase/tests/event_test.sql
git commit -m "feat(calendar): add the event table"
```

CI's `Supabase migrations` job (`supabase test db`) has to pass `event_test.sql` and `schema_rls_test.sql` on the PR. Don't apply the migration to the hosted project: it ships through `supabase db push` after merge, as the earlier ones did.

---

### Task 2: Calendar domain

**Files:**
- Create: `lib/features/calendar/domain/calendar_event.dart`
- Create: `lib/features/calendar/domain/month_grid.dart`
- Test: `test/features/calendar/domain/calendar_event_test.dart`
- Test: `test/features/calendar/domain/month_grid_test.dart`

**Interfaces:**
- Produces:
  - `class CalendarEvent { String id; String title; DateTime startsAt; DateTime? endsAt; String? place; String? link; String? notes; DateTime get day; }`
  - `typedef EventDraft = ({String title, DateTime startsAt, DateTime? endsAt, String? place, String? link, String? notes});`
  - `List<CalendarEvent> byStart(Iterable<CalendarEvent> events)`
  - `List<CalendarEvent> eventsOn(List<CalendarEvent> events, DateTime day)`
  - `Map<DateTime, int> eventsPerDay(List<CalendarEvent> events)`
  - `String? normaliseLink(String text)`
  - `String shownLink(String link)`
  - `Uri mapsUri(String place, {required bool apple})`
  - `List<DateTime> monthDays(DateTime month, int firstDayOfWeek)`

- [ ] **Step 1: Write the failing tests**

`test/features/calendar/domain/month_grid_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/month_grid.dart';

// firstDayOfWeek as MaterialLocalizations.firstDayOfWeekIndex: 0 is Sunday.
const _sunday = 0;
const _monday = 1;

void main() {
  test('October 2026 from Monday: September 28 to November 1', () {
    final days = monthDays(DateTime(2026, 10), _monday);

    expect(days.length, 35);
    expect(days.first, DateTime(2026, 9, 28));
    expect(days.last, DateTime(2026, 11, 1));
  });

  test('from Sunday, the weeks start a day earlier', () {
    final days = monthDays(DateTime(2026, 10), _sunday);

    expect(days.first, DateTime(2026, 9, 27));
    expect(days.first.weekday, DateTime.sunday);
    expect(days.last, DateTime(2026, 10, 31));
  });

  test('a month that starts on the first weekday fills four weeks', () {
    final days = monthDays(DateTime(2026, 2), _sunday);

    expect(days.length, 28);
    expect(days.first, DateTime(2026, 2));
    expect(days.last, DateTime(2026, 2, 28));
  });

  test('a leap February', () {
    final days = monthDays(DateTime(2028, 2), _monday);

    expect(days.first, DateTime(2028, 1, 31));
    expect(days, contains(DateTime(2028, 2, 29)));
    expect(days.last, DateTime(2028, 3, 5));
  });

  test('every day once, at local midnight, across a DST change', () {
    for (final month in [DateTime(2026, 3), DateTime(2026, 10)]) {
      final days = monthDays(month, _monday);

      expect(days.every((day) => day.hour == 0 && day.minute == 0), isTrue);
      for (var i = 1; i < days.length; i++) {
        final before = days[i - 1];
        expect(days[i], DateTime(before.year, before.month, before.day + 1));
      }
    }
  });
}
```

`test/features/calendar/domain/calendar_event_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';

CalendarEvent _event(String id, DateTime startsAt) =>
    CalendarEvent(id: id, title: id, startsAt: startsAt);

void main() {
  test('an event just after local midnight is on that local day', () {
    // The previous day in UTC east of Greenwich.
    final late = _event('late', DateTime(2026, 10, 8, 0, 30).toUtc());

    expect(late.day, DateTime(2026, 10, 8));
    expect(eventsOn([late], DateTime(2026, 10, 8)), [late]);
    expect(eventsOn([late], DateTime(2026, 10, 7)), isEmpty);
  });

  test("a day's events, earliest first", () {
    final evening = _event('evening', DateTime(2026, 10, 8, 19));
    final lunch = _event('lunch', DateTime(2026, 10, 8, 12));
    final other = _event('other', DateTime(2026, 10, 9, 9));

    expect(eventsOn([evening, other, lunch], DateTime(2026, 10, 8)), [
      lunch,
      evening,
    ]);
    expect(byStart([evening, other, lunch]), [lunch, evening, other]);
  });

  test('events per local day', () {
    expect(
      eventsPerDay([
        _event('a', DateTime(2026, 10, 8, 10)),
        _event('b', DateTime(2026, 10, 8, 19)),
        _event('c', DateTime(2026, 10, 14, 19)),
      ]),
      {DateTime(2026, 10, 8): 2, DateTime(2026, 10, 14): 1},
    );
  });

  group('normaliseLink', () {
    test('adds https to a bare address', () {
      expect(
        normaliseLink(' meet.google.com/abc '),
        'https://meet.google.com/abc',
      );
    });

    test('keeps an http(s) link', () {
      expect(normaliseLink('https://zoom.us/j/1'), 'https://zoom.us/j/1');
      expect(normaliseLink('http://example.com'), 'http://example.com');
    });

    test('refuses what is not a web address', () {
      expect(normaliseLink(''), isNull);
      expect(normaliseLink('   '), isNull);
      expect(normaliseLink('hello'), isNull);
      expect(normaliseLink('ftp://example.com'), isNull);
      expect(normaliseLink('javascript:alert(1)'), isNull);
    });
  });

  test('a link is shown without its scheme', () {
    expect(shownLink('https://meet.google.com/abc'), 'meet.google.com/abc');
    expect(shownLink('http://example.com'), 'example.com');
  });

  test('directions open Apple Maps on iOS, Google Maps elsewhere', () {
    final apple = mapsUri('Studio Lumière, Lyon', apple: true);
    expect(apple.host, 'maps.apple.com');
    expect(apple.queryParameters, {'q': 'Studio Lumière, Lyon'});

    final google = mapsUri('Studio Lumière, Lyon', apple: false);
    expect(google.host, 'www.google.com');
    expect(google.path, '/maps/search/');
    expect(google.queryParameters, {
      'api': '1',
      'query': 'Studio Lumière, Lyon',
    });
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/calendar/domain`
Expected: FAIL, `Error: Couldn't resolve the package 'loomia' ... calendar_event.dart` (the files don't exist yet).

- [ ] **Step 3: Write the domain**

`lib/features/calendar/domain/month_grid.dart`:

```dart
/// The days a month grid shows for [month]: whole weeks, from the one that
/// holds the 1st to the one that holds the last day, each starting on
/// [firstDayOfWeek] (0 is Sunday, as `MaterialLocalizations.firstDayOfWeekIndex`).
/// Local midnights, built from calendar dates rather than by adding 24 hours,
/// so a DST change neither skips nor repeats a day.
List<DateTime> monthDays(DateTime month, int firstDayOfWeek) {
  final first = DateTime(month.year, month.month);
  // DateTime.weekday is 1 (Monday) to 7 (Sunday); % 7 makes Sunday 0.
  final lead = (first.weekday % 7 - firstDayOfWeek) % 7;
  final last = DateTime(month.year, month.month + 1, 0);
  final weeks = ((lead + last.day) / DateTime.daysPerWeek).ceil();
  return [
    for (var i = 0; i < weeks * DateTime.daysPerWeek; i++)
      DateTime(month.year, month.month, 1 - lead + i),
  ];
}
```

`lib/features/calendar/domain/calendar_event.dart`:

```dart
/// Something on the calendar: a workshop, a training. [startsAt] and
/// [endsAt] are instants; the calendar reads them in the device's time zone.
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.place,
    this.link,
    this.notes,
  });

  final String id;
  final String title;
  final DateTime startsAt;

  /// After [startsAt], the same day (the form has no end date).
  final DateTime? endsAt;

  /// Free text: an address, a café's name.
  final String? place;

  /// An http(s) address, for an online event.
  final String? link;
  final String? notes;

  /// The local calendar day it starts on, as local midnight.
  DateTime get day {
    final local = startsAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

/// What the form saves. Text is trimmed and empty text is null by then.
typedef EventDraft = ({
  String title,
  DateTime startsAt,
  DateTime? endsAt,
  String? place,
  String? link,
  String? notes,
});

/// Earliest first.
List<CalendarEvent> byStart(Iterable<CalendarEvent> events) =>
    [...events]..sort((a, b) => a.startsAt.compareTo(b.startsAt));

/// [events] starting on [day] (local midnight), earliest first.
List<CalendarEvent> eventsOn(List<CalendarEvent> events, DateTime day) =>
    byStart(events.where((event) => event.day == day));

/// How many events start on each local day; days without one are absent.
Map<DateTime, int> eventsPerDay(List<CalendarEvent> events) {
  final counts = <DateTime, int>{};
  for (final event in events) {
    counts.update(event.day, (count) => count + 1, ifAbsent: () => 1);
  }
  return counts;
}

/// [text] as an http(s) link: trimmed, `https://` added when there is no
/// scheme. Null when empty, or when it isn't a web address with a dotted
/// host, which also turns away `javascript:`.
String? normaliseLink(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return null;
  final link = trimmed.contains('://') ? trimmed : 'https://$trimmed';
  final uri = Uri.tryParse(link);
  if (uri == null ||
      !(uri.isScheme('http') || uri.isScheme('https')) ||
      !uri.host.contains('.')) {
    return null;
  }
  return link;
}

/// [link] as the event screen shows it: without `https://`.
String shownLink(String link) => link.replaceFirst(RegExp('^https?://'), '');

/// Directions to [place] in the maps app: Apple Maps on iOS, Google Maps
/// elsewhere (Android's Maps app opens these links; the web gets the site).
Uri mapsUri(String place, {required bool apple}) => apple
    ? Uri.https('maps.apple.com', '/', {'q': place})
    : Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': place,
      });
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/calendar/domain`
Expected: PASS (13 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/calendar/domain test/features/calendar/domain
git commit -m "feat(calendar): add events and the month grid's days"
```

---

### Task 3: Repository, controller and selection

**Files:**
- Create: `lib/features/calendar/data/event_repository.dart`
- Create: `lib/features/calendar/presentation/calendar_controller.dart`
- Create: `test/features/calendar/fake_event_repository.dart`
- Modify: `test/app/app_harness.dart` (an `events` parameter)
- Test: `test/features/calendar/data/event_repository_test.dart`
- Test: `test/features/calendar/presentation/calendar_controller_test.dart`

**Interfaces:**
- Consumes: `CalendarEvent`, `EventDraft`, `byStart` (Task 2); `guardPeople` (`lib/features/contacts/data/people_repository.dart`); `supabaseClientProvider`; `today()`.
- Produces:
  - `class EventRepository { Future<List<CalendarEvent>> list(); Future<CalendarEvent> add(EventDraft); Future<CalendarEvent> update(String id, EventDraft); Future<void> remove(String id); }`
  - `eventRepositoryProvider`
  - `CalendarEvent eventFromRow(Map<String, dynamic>)`, `Map<String, Object?> draftToEventRow(EventDraft)`
  - `eventsProvider` (`AsyncNotifierProvider.family<EventsController, List<CalendarEvent>, String?>`, keyed by account email) with `add(EventDraft)`, `save(String id, EventDraft)`, `remove(String id)`
  - `typedef CalendarSelection = ({DateTime month, DateTime day})`, `calendarSelectionProvider` with `select(DateTime)`, `shift(int)`, `toToday()`
  - `FakeEventRepository` (test): `store`, `calls` (`list()`, `add(<title>)`, `update(<id>)`, `remove(<id>)`), `failWith`
  - `pumpLoomia(..., FakeEventRepository? events)`

- [ ] **Step 1: Write the failing tests**

`test/features/calendar/data/event_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/data/event_repository.dart';

void main() {
  test('reads a row: instants in UTC, blank text as null', () {
    final event = eventFromRow({
      'id': 'e1',
      'title': 'Workshop',
      'starts_at': '2026-10-08T17:00:00+00:00',
      'ends_at': null,
      'place': '  ',
      'link': 'https://meet.google.com/abc',
      'notes': 'Bring the diffuser',
    });

    expect(event.id, 'e1');
    expect(event.title, 'Workshop');
    expect(event.startsAt, DateTime.utc(2026, 10, 8, 17));
    expect(event.endsAt, isNull);
    expect(event.place, isNull);
    expect(event.link, 'https://meet.google.com/abc');
    expect(event.notes, 'Bring the diffuser');
  });

  test('writes a draft: local times as UTC instants', () {
    final row = draftToEventRow((
      title: 'Workshop',
      startsAt: DateTime(2026, 10, 8, 19),
      endsAt: DateTime(2026, 10, 8, 21),
      place: 'Studio Lumière',
      link: null,
      notes: null,
    ));

    expect(row, {
      'title': 'Workshop',
      'starts_at': DateTime(2026, 10, 8, 19).toUtc().toIso8601String(),
      'ends_at': DateTime(2026, 10, 8, 21).toUtc().toIso8601String(),
      'place': 'Studio Lumière',
      'link': null,
      'notes': null,
    });
  });
}
```

`test/features/calendar/fake_event_repository.dart`:

```dart
import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';

/// In-memory events that record calls and fail on demand.
class FakeEventRepository implements EventRepository {
  FakeEventRepository([Iterable<CalendarEvent> events = const []]) {
    store.addAll(events);
  }

  final List<CalendarEvent> store = [];

  /// One entry per call, e.g. `add(Workshop)`.
  final List<String> calls = [];

  /// Thrown by calls started while set. Use a `PeopleFailure`.
  Object? failWith;

  var _next = 0;

  void _record(String call) {
    calls.add(call);
    final failure = failWith;
    if (failure != null) throw failure;
  }

  static CalendarEvent _fromDraft(String id, EventDraft draft) =>
      CalendarEvent(
        id: id,
        title: draft.title,
        startsAt: draft.startsAt,
        endsAt: draft.endsAt,
        place: draft.place,
        link: draft.link,
        notes: draft.notes,
      );

  @override
  Future<List<CalendarEvent>> list() async {
    _record('list()');
    return byStart(store);
  }

  @override
  Future<CalendarEvent> add(EventDraft draft) async {
    _record('add(${draft.title})');
    final event = _fromDraft('new${++_next}', draft);
    store.add(event);
    return event;
  }

  @override
  Future<CalendarEvent> update(String id, EventDraft draft) async {
    _record('update($id)');
    final event = _fromDraft(id, draft);
    store[store.indexWhere((saved) => saved.id == id)] = event;
    return event;
  }

  @override
  Future<void> remove(String id) async {
    _record('remove($id)');
    store.removeWhere((event) => event.id == id);
  }
}
```

`test/features/calendar/presentation/calendar_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';

import '../fake_event_repository.dart';

const _owner = 'p@example.com';

ProviderContainer _container(FakeEventRepository events) =>
    ProviderContainer.test(
      overrides: [eventRepositoryProvider.overrideWithValue(events)],
    );

EventDraft _draft(String title, DateTime startsAt) => (
  title: title,
  startsAt: startsAt,
  endsAt: null,
  place: null,
  link: null,
  notes: null,
);

final _workshop = CalendarEvent(
  id: 'e1',
  title: 'Workshop',
  startsAt: DateTime(2026, 10, 8, 19),
);

void main() {
  test('signed out: no events, and nothing asked', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);

    expect(await container.read(eventsProvider(null).future), isEmpty);
    expect(fake.calls, isEmpty);
  });

  test('add and save keep the list in order, without a reload', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    final events = container.read(eventsProvider(_owner).notifier);

    final coffee = await events.add(
      _draft('Coffee', DateTime(2026, 10, 8, 10)),
    );
    await events.save('e1', _draft('Workshop', DateTime(2026, 10, 7, 19)));

    expect(
      container.read(eventsProvider(_owner)).value!.map((event) => event.id),
      ['e1', coffee.id],
    );
    expect(fake.calls.where((call) => call == 'list()'), hasLength(1));
  });

  test('remove drops the event', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);

    await container.read(eventsProvider(_owner).notifier).remove('e1');

    expect(container.read(eventsProvider(_owner)).value, isEmpty);
    expect(fake.calls, contains('remove(e1)'));
  });

  test('a failed add throws and leaves the list as it was', () async {
    final fake = FakeEventRepository([_workshop]);
    final container = _container(fake);
    await container.read(eventsProvider(_owner).future);
    fake.failWith = PeopleFailure.network;

    await expectLater(
      container
          .read(eventsProvider(_owner).notifier)
          .add(_draft('Coffee', DateTime(2026, 10, 8, 10))),
      throwsA(PeopleFailure.network),
    );
    expect(container.read(eventsProvider(_owner)).value, [_workshop]);
  });

  group('selection', () {
    test('starts on today, in its month', () {
      final container = ProviderContainer.test();
      final now = today();

      expect(container.read(calendarSelectionProvider), (
        month: DateTime(now.year, now.month),
        day: now,
      ));
    });

    test('selecting a day of another month shows that month', () {
      final container = ProviderContainer.test();

      container
          .read(calendarSelectionProvider.notifier)
          .select(DateTime(2026, 9, 28));

      expect(container.read(calendarSelectionProvider), (
        month: DateTime(2026, 9),
        day: DateTime(2026, 9, 28),
      ));
    });

    test('another month selects its 1st; back to this one, today', () {
      final container = ProviderContainer.test();
      final selector = container.read(calendarSelectionProvider.notifier);
      final now = today();

      selector.shift(1);
      expect(
        container.read(calendarSelectionProvider).day,
        DateTime(now.year, now.month + 1),
      );

      selector.shift(-1);
      expect(container.read(calendarSelectionProvider).day, now);
    });
  });
}
```

- [ ] **Step 2: Run them to see them fail**

Run: `flutter test test/features/calendar/data test/features/calendar/presentation`
Expected: FAIL, `event_repository.dart` and `calendar_controller.dart` not found.

- [ ] **Step 3: Write the repository**

`lib/features/calendar/data/event_repository.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The `event` table. Every method throws [PeopleFailure] and nothing else.
/// RLS scopes everything to the user, and `owner_id` defaults to them.
class EventRepository {
  EventRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'event';

  /// Every event, earliest first.
  // ponytail: loads every event; read a month at a time (the starts_at
  // index is there) once someone has years of them.
  Future<List<CalendarEvent>> list() => guardPeople(() async {
    final rows = await _client.from(_table).select().order('starts_at');
    return rows.map(eventFromRow).toList();
  });

  Future<CalendarEvent> add(EventDraft draft) => guardPeople(() async {
    final row = await _client
        .from(_table)
        .insert(draftToEventRow(draft))
        .select()
        .single();
    return eventFromRow(row);
  });

  Future<CalendarEvent> update(String id, EventDraft draft) =>
      guardPeople(() async {
        final row = await _client
            .from(_table)
            .update(draftToEventRow(draft))
            .eq('id', id)
            .select()
            .single();
        return eventFromRow(row);
      });

  Future<void> remove(String id) =>
      guardPeople(() => _client.from(_table).delete().eq('id', id));
}

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(ref.watch(supabaseClientProvider)),
);

String? _text(Object? value) {
  final text = (value as String?)?.trim();
  return text == null || text.isEmpty ? null : text;
}

CalendarEvent eventFromRow(Map<String, dynamic> row) => CalendarEvent(
  id: row['id'] as String,
  title: row['title'] as String,
  startsAt: DateTime.parse(row['starts_at'] as String),
  endsAt: switch (row['ends_at']) {
    final String at => DateTime.parse(at),
    _ => null,
  },
  place: _text(row['place']),
  link: _text(row['link']),
  notes: _text(row['notes']),
);

Map<String, Object?> draftToEventRow(EventDraft draft) => {
  'title': draft.title,
  'starts_at': draft.startsAt.toUtc().toIso8601String(),
  'ends_at': draft.endsAt?.toUtc().toIso8601String(),
  'place': draft.place,
  'link': draft.link,
  'notes': draft.notes,
};
```

- [ ] **Step 4: Write the controller and the selection**

`lib/features/calendar/presentation/calendar_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';

/// One account's events, `eventsProvider(account?.email)`, earliest first.
/// Keyed by account for the same reason as `peopleProvider`. No automatic
/// retry: a failed load shows its error with Try again.
final eventsProvider =
    AsyncNotifierProvider.family<
      EventsController,
      List<CalendarEvent>,
      String?
    >(EventsController.new, retry: (error, _) => null);

class EventsController extends AsyncNotifier<List<CalendarEvent>> {
  EventsController(this.owner);

  /// The email of the account; null when signed out.
  final String? owner;

  @override
  Future<List<CalendarEvent>> build() async {
    final repository = ref.watch(eventRepositoryProvider);
    if (owner == null) return const [];
    return repository.list();
  }

  /// Saves a new event; the calendar shows it without a reload. Throws
  /// `PeopleFailure`, and then the list stays as it was.
  Future<CalendarEvent> add(EventDraft draft) async {
    final event = await ref.read(eventRepositoryProvider).add(draft);
    _put(event);
    return event;
  }

  /// Saves [id] as [draft]. Throws `PeopleFailure`.
  Future<CalendarEvent> save(String id, EventDraft draft) async {
    final event = await ref.read(eventRepositoryProvider).update(id, draft);
    _put(event);
    return event;
  }

  /// Throws `PeopleFailure`, and then the event stays.
  Future<void> remove(String id) async {
    await ref.read(eventRepositoryProvider).remove(id);
    if (!ref.mounted) return;
    state = AsyncData([
      for (final event in state.value ?? const <CalendarEvent>[])
        if (event.id != id) event,
    ]);
  }

  void _put(CalendarEvent saved) {
    if (!ref.mounted) return;
    state = AsyncData(
      byStart([
        for (final event in state.value ?? const <CalendarEvent>[])
          if (event.id != saved.id) event,
        saved,
      ]),
    );
  }
}

/// The month the grid shows (its 1st) and the selected day, both local
/// midnights.
typedef CalendarSelection = ({DateTime month, DateTime day});

/// What the Calendar shows. UI state: not per account, and it resets on
/// restart, to today.
final calendarSelectionProvider =
    NotifierProvider<CalendarSelector, CalendarSelection>(
      CalendarSelector.new,
    );

class CalendarSelector extends Notifier<CalendarSelection> {
  @override
  CalendarSelection build() => _on(today());

  static CalendarSelection _on(DateTime day) =>
      (month: DateTime(day.year, day.month), day: day);

  /// A day of a neighbouring month shows that month.
  void select(DateTime day) => state = _on(day);

  /// The month [delta] months away, with its 1st selected, or today when
  /// it is the current month.
  void shift(int delta) {
    final month = DateTime(state.month.year, state.month.month + delta);
    final now = today();
    select(month.year == now.year && month.month == now.month ? now : month);
  }

  void toToday() => select(today());
}
```

- [ ] **Step 5: Give the app harness the events**

In `test/app/app_harness.dart`, add `import 'package:loomia/features/calendar/data/event_repository.dart';` and `import '../features/calendar/fake_event_repository.dart';`. Add the parameter `FakeEventRepository? events,` after `goals`, and this override after `goalsRepositoryProvider`'s:

```dart
        eventRepositoryProvider.overrideWithValue(
          events ?? FakeEventRepository(),
        ),
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/calendar`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/features/calendar test/features/calendar test/app/app_harness.dart
git commit -m "feat(calendar): load and save events"
```

---

### Task 4: New / edit event

**Files:**
- Modify: `lib/core/ui/pick_day.dart` (add `pickTime`)
- Create: `lib/features/calendar/presentation/event_form.dart`
- Modify: `lib/l10n/app_en.arb`
- Create: `test/features/calendar/calendar_harness.dart`
- Test: `test/features/calendar/presentation/event_form_test.dart`

**Interfaces:**
- Consumes: `eventsProvider`, `EventDraft`, `normaliseLink` (Tasks 2–3); `LoomiaDialog`, `LabeledField`, `FormError`, `pickDay`, `peopleFailureCopy`, `accountProvider`.
- Produces:
  - `Future<TimeOfDay?> pickTime(BuildContext context, {required TimeOfDay initial})`
  - `Future<CalendarEvent?> showEventForm(BuildContext context, {CalendarEvent? event, DateTime? day})`
  - `pumpCalendarHarness(tester, {required FakeEventRepository events, required Future<Object?> Function(BuildContext) open, required void Function(Object?) result})` (test)
  - l10n keys: `calendarNewEvent`, `eventEdit`, `eventTitle`, `eventTitleRequired`, `eventDate`, `eventStarts`, `eventEnds`, `eventEndsNone`, `eventEndsBeforeStart`, `eventPlace`, `eventLink`, `eventLinkHint`, `eventLinkInvalid`, `eventNotes`.

- [ ] **Step 1: Add the copy** to `lib/l10n/app_en.arb`, before the closing brace (keep the file's two-space indentation)

```json
  "calendarNewEvent": "New event",
  "@calendarNewEvent": {
    "description": "Title of the form that adds an event to the calendar (a workshop, a training), and tooltip of the Calendar's add button."
  },
  "eventEdit": "Edit event",
  "@eventEdit": {
    "description": "Title of the form that changes an event, and tooltip of the edit button on an event's screen."
  },
  "eventTitle": "Title",
  "@eventTitle": {
    "description": "Label of the event form's field for what the event is called, e.g. 'Essential oils for sleep'."
  },
  "eventTitleRequired": "Give it a title",
  "@eventTitleRequired": {
    "description": "Error under the event form's Title field when it is empty."
  },
  "eventDate": "Date",
  "@eventDate": {
    "description": "Label of the event form's field for the day the event happens."
  },
  "eventStarts": "Starts",
  "@eventStarts": {
    "description": "Label of the event form's field for the time the event starts."
  },
  "eventEnds": "Ends",
  "@eventEnds": {
    "description": "Label of the event form's field for the time the event ends, on the same day."
  },
  "eventEndsNone": "Optional",
  "@eventEndsNone": {
    "description": "Shown in the event form's Ends field while no end time is set: setting one is optional."
  },
  "eventEndsBeforeStart": "It has to end after it starts.",
  "@eventEndsBeforeStart": {
    "description": "Error under the event form's Ends field when the end time is not after the start time."
  },
  "eventPlace": "Place",
  "@eventPlace": {
    "description": "Label of the event form's field for where the event happens: an address or a place's name. Tapping it later opens the maps app."
  },
  "eventLink": "Link",
  "@eventLink": {
    "description": "Label of the event form's field for an online meeting's web address."
  },
  "eventLinkHint": "For an online event",
  "@eventLinkHint": {
    "description": "Hint inside the empty Link field of the event form."
  },
  "eventLinkInvalid": "That doesn't look like a web link.",
  "@eventLinkInvalid": {
    "description": "Error under the event form's Link field when what was typed is not a web address."
  },
  "eventNotes": "Notes",
  "@eventNotes": {
    "description": "Label of the event form's field for free notes about the event, e.g. what to bring."
  }
```

Run: `flutter gen-l10n`
Expected: no output and exit code 0.

- [ ] **Step 2: Write the harness and the failing tests**

`test/features/calendar/calendar_harness.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../auth/fake_auth_repository.dart';
import 'fake_event_repository.dart';

/// A screen with one "Open" button that runs [open], signed in as Pauline
/// with [events]. What [open] resolves to goes to [result].
Future<void> pumpCalendarHarness(
  WidgetTester tester, {
  required FakeEventRepository events,
  required Future<Object?> Function(BuildContext context) open,
  required void Function(Object? value) result,
}) async {
  final auth = FakeAuthRepository()
    ..session = true
    ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
  addTearDown(auth.dispose);
  tester.view
    ..physicalSize = const Size(390, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        eventRepositoryProvider.overrideWithValue(events),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async => result(await open(context)),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
```

`test/features/calendar/presentation/event_form_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/event_form.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:material_ui/material_ui.dart';

import '../calendar_harness.dart';
import '../fake_event_repository.dart';

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(LabeledField, label),
  matching: find.byType(TextFormField),
);

final _day = DateTime(2026, 10, 8);

void main() {
  testWidgets('a new event on the day, at 19:00, with what was typed', (
    tester,
  ) async {
    final events = FakeEventRepository();
    Object? saved;
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (value) => saved = value,
    );

    expect(find.text('New event'), findsOneWidget);
    await tester.enterText(_field('Title'), ' Essential oils for sleep ');
    await tester.enterText(_field('Place'), 'Studio Lumière, Lyon');
    await tester.enterText(_field('Link'), 'meet.google.com/abc');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final event = events.store.single;
    expect(saved, event);
    expect(event.title, 'Essential oils for sleep');
    expect(event.startsAt, DateTime(2026, 10, 8, 19));
    expect(event.endsAt, isNull);
    expect(event.place, 'Studio Lumière, Lyon');
    expect(event.link, 'https://meet.google.com/abc');
    expect(event.notes, isNull);
  });

  testWidgets('a title is required', (tester) async {
    final events = FakeEventRepository();
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Give it a title'), findsOneWidget);
    expect(events.calls, isEmpty);
  });

  testWidgets('a link that is not a web address is refused', (tester) async {
    final events = FakeEventRepository();
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    await tester.enterText(_field('Title'), 'Call');
    await tester.enterText(_field('Link'), 'javascript:alert(1)');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text("That doesn't look like a web link."), findsOneWidget);
    expect(events.calls, isEmpty);
  });

  testWidgets('editing: prefilled, and an end before the start is refused', (
    tester,
  ) async {
    final event = CalendarEvent(
      id: 'e1',
      title: 'Workshop',
      startsAt: DateTime(2026, 10, 8, 19),
      // Not something the table keeps; here to reach the form's check.
      endsAt: DateTime(2026, 10, 8, 18),
      notes: 'Bring the diffuser',
    );
    final events = FakeEventRepository([event]);
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, event: event),
      result: (_) {},
    );

    expect(find.text('Edit event'), findsOneWidget);
    expect(find.text('Workshop'), findsOneWidget);
    expect(find.text('Bring the diffuser'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('It has to end after it starts.'), findsOneWidget);
    expect(events.calls, isEmpty);

    // Clearing the end time saves.
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(events.calls, ['update(e1)']);
    expect(events.store.single.endsAt, isNull);
  });

  testWidgets('a failed save keeps the form and what was typed', (
    tester,
  ) async {
    final events = FakeEventRepository()..failWith = PeopleFailure.network;
    await pumpCalendarHarness(
      tester,
      events: events,
      open: (context) => showEventForm(context, day: _day),
      result: (_) {},
    );

    await tester.enterText(_field('Title'), 'Workshop');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byType(FormError), findsOneWidget);
    expect(find.text('Workshop'), findsOneWidget);
    expect(find.text('New event'), findsOneWidget);
  });
}
```

`find.byTooltip('Delete')` is `MaterialLocalizations.deleteButtonTooltip` in English, the tooltip of the button that clears the end time.

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/features/calendar/presentation/event_form_test.dart`
Expected: FAIL, `event_form.dart` not found.

- [ ] **Step 4: Add `pickTime`** to `lib/core/ui/pick_day.dart`

Make `_Wheel.last` optional (`this.last,` in the constructor and `final DateTime? last;`), add a `use24hFormat` field passed to `CupertinoDatePicker`, and add the function after `pickMonth`:

```dart
/// A time of day; null when dismissed. A wheel on iOS, the Material dial
/// elsewhere, both in the device's 12- or 24-hour format.
Future<TimeOfDay?> pickTime(
  BuildContext context, {
  required TimeOfDay initial,
}) async {
  if (!_wheel) return showTimePicker(context: context, initialTime: initial);
  final now = DateTime.now();
  final picked = await showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (context) => _Wheel(
      mode: CupertinoDatePickerMode.time,
      initial: DateTime(
        now.year,
        now.month,
        now.day,
        initial.hour,
        initial.minute,
      ),
      use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    ),
  );
  return picked == null ? null : TimeOfDay.fromDateTime(picked);
}
```

In `_Wheel`:

```dart
  const _Wheel({
    this.mode = CupertinoDatePickerMode.date,
    required this.initial,
    this.first,
    this.last,
    this.use24hFormat = false,
  });

  final CupertinoDatePickerMode mode;

  final DateTime initial;
  final DateTime? first;
  final DateTime? last;

  /// Time mode only: hours as the device shows them.
  final bool use24hFormat;
```

and in `_WheelState.build`, add `use24hFormat: widget.use24hFormat,` to the `CupertinoDatePicker` arguments.

- [ ] **Step 5: Write the form**

`lib/features/calendar/presentation/event_form.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A new event on [day], or [event] to change: a sheet on mobile, a dialog
/// elsewhere. Resolves to the saved event, or null when dismissed.
Future<CalendarEvent?> showEventForm(
  BuildContext context, {
  CalendarEvent? event,
  DateTime? day,
}) => LoomiaDialog.show<CalendarEvent>(
  context,
  (_) => _EventForm(event: event, day: day),
);

/// A new event starts in the evening, when most workshops are.
const _defaultStart = TimeOfDay(hour: 19, minute: 0);

class _EventForm extends ConsumerStatefulWidget {
  const _EventForm({this.event, this.day});

  final CalendarEvent? event;
  final DateTime? day;

  @override
  ConsumerState<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends ConsumerState<_EventForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.event?.title);
  late final _place = TextEditingController(text: widget.event?.place);
  late final _link = TextEditingController(text: widget.event?.link);
  late final _notes = TextEditingController(text: widget.event?.notes);
  late DateTime _day;
  late TimeOfDay _start;
  TimeOfDay? _end;
  bool _endBeforeStart = false;
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    if (event == null) {
      _day = widget.day ?? today();
      _start = _defaultStart;
      return;
    }
    final starts = event.startsAt.toLocal();
    _day = DateTime(starts.year, starts.month, starts.day);
    _start = TimeOfDay.fromDateTime(starts);
    final ends = event.endsAt;
    _end = ends == null ? null : TimeOfDay.fromDateTime(ends.toLocal());
  }

  @override
  void dispose() {
    _title.dispose();
    _place.dispose();
    _link.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ponytail: the end is a time on the start's day, so nothing runs past
  // midnight; add an end date if someone needs it.
  DateTime _at(TimeOfDay time) =>
      DateTime(_day.year, _day.month, _day.day, time.hour, time.minute);

  Future<void> _pickDay() async {
    final day = await pickDay(
      context,
      initial: _day,
      first: DateTime(_day.year - 5),
      last: DateTime(_day.year + 5),
    );
    if (day != null && mounted) setState(() => _day = day);
  }

  Future<void> _pickStart() async {
    final time = await pickTime(context, initial: _start);
    if (time == null || !mounted) return;
    setState(() {
      _start = time;
      _endBeforeStart = false;
    });
  }

  Future<void> _pickEnd() async {
    final time = await pickTime(
      context,
      initial:
          _end ??
          TimeOfDay(
            hour: (_start.hour + 1) % TimeOfDay.hoursPerDay,
            minute: _start.minute,
          ),
    );
    if (time == null || !mounted) return;
    setState(() {
      _end = time;
      _endBeforeStart = false;
    });
  }

  void _clearEnd() => setState(() {
    _end = null;
    _endBeforeStart = false;
  });

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final startsAt = _at(_start);
    final end = _end;
    final endsAt = end == null ? null : _at(end);
    if (endsAt != null && !endsAt.isAfter(startsAt)) {
      setState(() => _endBeforeStart = true);
      return;
    }
    String? text(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    final EventDraft draft = (
      title: _title.text.trim(),
      startsAt: startsAt,
      endsAt: endsAt,
      place: text(_place),
      link: normaliseLink(_link.text),
      notes: text(_notes),
    );
    setState(() {
      _saving = true;
      _failure = null;
    });
    try {
      final events = ref.read(
        eventsProvider(ref.read(accountProvider)?.email).notifier,
      );
      final event = widget.event;
      final saved = event == null
          ? await events.add(draft)
          : await events.save(event.id, draft);
      if (mounted) Navigator.pop(context, saved);
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
    final material = MaterialLocalizations.of(context);
    final h24 = MediaQuery.alwaysUse24HourFormatOf(context);
    String time(TimeOfDay value) =>
        material.formatTimeOfDay(value, alwaysUse24HourFormat: h24);
    final failure = _failure;
    final end = _end;

    return Form(
      key: _form,
      child: LoomiaDialog(
        title: widget.event == null ? l10n.calendarNewEvent : l10n.eventEdit,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(material.saveButtonLabel),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
            LabeledField(
              label: l10n.eventTitle,
              child: TextFormField(
                controller: _title,
                autofocus: widget.event == null,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.eventTitleRequired
                    : null,
              ),
            ),
            LabeledField(
              label: l10n.eventDate,
              child: _Picker(
                text: material.formatMediumDate(_day),
                icon: Icons.calendar_today_outlined,
                onTap: _pickDay,
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                Expanded(
                  child: LabeledField(
                    label: l10n.eventStarts,
                    child: _Picker(
                      text: time(_start),
                      icon: Icons.schedule_rounded,
                      onTap: _pickStart,
                    ),
                  ),
                ),
                Expanded(
                  child: LabeledField(
                    label: l10n.eventEnds,
                    child: _Picker(
                      text: end == null ? l10n.eventEndsNone : time(end),
                      icon: Icons.schedule_rounded,
                      onTap: _pickEnd,
                      onClear: end == null ? null : _clearEnd,
                      error: _endBeforeStart
                          ? l10n.eventEndsBeforeStart
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            LabeledField(
              label: l10n.eventPlace,
              child: TextFormField(
                controller: _place,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
              ),
            ),
            LabeledField(
              label: l10n.eventLink,
              child: TextFormField(
                controller: _link,
                keyboardType: TextInputType.url,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(hintText: l10n.eventLinkHint),
                validator: (value) {
                  final text = (value ?? '').trim();
                  return text.isNotEmpty && normaliseLink(text) == null
                      ? l10n.eventLinkInvalid
                      : null;
                },
              ),
            ),
            LabeledField(
              label: l10n.eventNotes,
              child: TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A field that opens a picker, as Log something's day does. [onClear]
/// empties an optional one.
class _Picker extends StatelessWidget {
  const _Picker({
    required this.text,
    required this.icon,
    required this.onTap,
    this.onClear,
    this.error,
  });

  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final clear = onClear;
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          errorText: error,
          errorMaxLines: 2,
          suffixIcon: clear == null
              ? Icon(icon)
              : IconButton(
                  onPressed: clear,
                  tooltip: MaterialLocalizations.of(
                    context,
                  ).deleteButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
        child: Text(text),
      ),
    );
  }
}
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/calendar test/features/contacts`
Expected: PASS. The contacts suites cover the `pickDay` paths that `_Wheel` shares.

- [ ] **Step 7: Commit**

```bash
git add lib/core/ui/pick_day.dart lib/features/calendar lib/l10n/app_en.arb test/features/calendar
git commit -m "feat(calendar): add and edit an event"
```

---

### Task 5: The Calendar screen

**Files:**
- Modify: `lib/app/router/routes.dart`
- Modify: `lib/app/router/app_router.dart`
- Create: `lib/features/calendar/presentation/month_grid.dart`
- Create: `lib/features/calendar/presentation/event_row.dart`
- Create: `lib/features/calendar/presentation/calendar_page.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/calendar/presentation/calendar_page_test.dart`

**Interfaces:**
- Consumes: Tasks 2–4; `AccountButton` (`lib/app/shell/app_shell.dart`), `SectionHeader`, `EmptyState`.
- Produces:
  - `Routes.calendar = '/calendar'`, `Routes.calendarName`, `Routes.eventSegment = ':id'`, `Routes.eventName`, `Routes.eventLocation(String id)`
  - `MonthGrid({month, selected, today, counts, onSelect})`
  - `EventRow({event, onTap})`, `String timeLabel(BuildContext, DateTime)`, `String whenLabel(BuildContext, CalendarEvent)`
  - `DaySection({events, day, onOpen, onAdd, onRetry})`, `CalendarDayPane()`
  - `CalendarView({events, selection, today, onSelect, onShift, onToday, onOpen, onAdd, onRetry, pane, accountAction})`, `CalendarPage({pane})`, `void openEvent(BuildContext, String id)`
  - l10n keys: `calendarMonth`, `calendarToday`, `calendarPreviousMonth`, `calendarNextMonth`, `calendarDayTitle`, `calendarAdd`, `calendarNothingPlanned`, `calendarDaySemantics`, `calendarLoadFailed`, `eventOnline`.

- [ ] **Step 1: Add the copy** to `lib/l10n/app_en.arb`

```json
  "calendarMonth": "{month}",
  "@calendarMonth": {
    "description": "Title of the Calendar screen: the month shown, e.g. 'October 2026'. The format follows the locale.",
    "placeholders": {
      "month": { "type": "DateTime", "format": "yMMMM" }
    }
  },
  "calendarToday": "Today",
  "@calendarToday": {
    "description": "Button on the Calendar screen that goes back to the current month and selects today."
  },
  "calendarPreviousMonth": "Previous month",
  "@calendarPreviousMonth": {
    "description": "Tooltip of the Calendar's button that shows the month before."
  },
  "calendarNextMonth": "Next month",
  "@calendarNextMonth": {
    "description": "Tooltip of the Calendar's button that shows the month after."
  },
  "calendarDayTitle": "{day}",
  "@calendarDayTitle": {
    "description": "Heading above the selected day's events on the Calendar screen, shown uppercased, e.g. 'Thursday, October 8'. The format follows the locale.",
    "placeholders": {
      "day": { "type": "DateTime", "format": "MMMMEEEEd" }
    }
  },
  "calendarAdd": "Add",
  "@calendarAdd": {
    "description": "Action beside the selected day's heading on the Calendar screen: adds an event on that day."
  },
  "calendarNothingPlanned": "Nothing planned",
  "@calendarNothingPlanned": {
    "description": "Shown under the selected day on the Calendar screen when it has no event."
  },
  "calendarDaySemantics": "{day}, {count, plural, =0{nothing planned} =1{one event} other{{count} events}}",
  "@calendarDaySemantics": {
    "description": "What a screen reader says for a day in the Calendar's month grid: the date, then how many events it has.",
    "placeholders": {
      "day": { "type": "DateTime", "format": "MMMMEEEEd" },
      "count": { "type": "int" }
    }
  },
  "calendarLoadFailed": "Couldn't load your calendar.",
  "@calendarLoadFailed": {
    "description": "Title of the error shown on the Calendar when the events could not be loaded."
  },
  "eventOnline": "Online",
  "@eventOnline": {
    "description": "Second line of an event's row on the Calendar when it has a meeting link and no place."
  }
```

Run: `flutter gen-l10n`
Expected: exit code 0.

- [ ] **Step 2: Add the routes** to `lib/app/router/routes.dart`, after `contactWorkflowLocation`

```dart
  static const String calendar = '/calendar';
  static const String calendarName = 'calendar';

  /// One event, nested under [calendar] so back returns to the month.
  static const String eventSegment = ':id';
  static const String eventName = 'event';

  static String eventLocation(String id) =>
      '$calendar/${Uri.encodeComponent(id)}';
```

- [ ] **Step 3: Write the failing tests**

`test/features/calendar/presentation/calendar_page_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_event_repository.dart';

final _workshop = CalendarEvent(
  id: 'e1',
  title: 'Essential oils for sleep',
  startsAt: DateTime(2026, 10, 8, 19),
  endsAt: DateTime(2026, 10, 8, 21),
  place: 'Studio Lumière, Lyon',
);

final _training = CalendarEvent(
  id: 'e2',
  title: 'New member training',
  startsAt: DateTime(2026, 10, 8, 14),
  link: 'https://meet.google.com/abc',
);

Future<void> _pump(
  WidgetTester tester, {
  List<CalendarEvent> events = const [],
  AsyncValue<List<CalendarEvent>>? value,
  CalendarSelection? selection,
  Locale locale = const Locale('en'),
  Size size = const Size(390, 1000),
  ValueChanged<DateTime>? onSelect,
  ValueChanged<int>? onShift,
  VoidCallback? onToday,
  void Function(CalendarEvent event)? onOpen,
  ValueChanged<DateTime>? onAdd,
  Widget? pane,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: CalendarView(
        events: value ?? AsyncData(events),
        selection:
            selection ?? (month: DateTime(2026, 10), day: DateTime(2026, 10, 8)),
        today: DateTime(2026, 10, 7),
        onSelect: onSelect ?? (_) {},
        onShift: onShift ?? (_) {},
        onToday: onToday ?? () {},
        onOpen: onOpen ?? (_) {},
        onAdd: onAdd ?? (_) {},
        onRetry: () {},
        pane: pane,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the month, its weeks from Sunday in English', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    expect(find.text('October 2026'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Sun')).dx,
      lessThan(tester.getCenter(find.text('Mon')).dx),
    );
    expect(
      find.bySemanticsLabel('Sunday, September 27, nothing planned'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('in French, the weeks start on Monday', (tester) async {
    await _pump(tester, locale: const Locale('fr'));

    expect(find.text('octobre 2026'), findsOneWidget);
    expect(
      tester.getCenter(find.text('lun.')).dx,
      lessThan(tester.getCenter(find.text('dim.')).dx),
    );
  });

  testWidgets('a day says how many events it has', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, events: [_workshop, _training]);

    expect(
      find.bySemanticsLabel('Thursday, October 8, 2 events'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('tapping a day selects it', (tester) async {
    DateTime? selected;
    await _pump(tester, onSelect: (day) => selected = day);

    await tester.tap(find.text('14'));

    expect(selected, DateTime(2026, 10, 14));
  });

  testWidgets('the arrows change month, Today comes back', (tester) async {
    final shifts = <int>[];
    var backToToday = false;
    await _pump(
      tester,
      onShift: shifts.add,
      onToday: () => backToToday = true,
    );

    await tester.tap(find.byTooltip('Next month'));
    await tester.tap(find.byTooltip('Previous month'));
    await tester.tap(find.text('Today'));

    expect(shifts, [1, -1]);
    expect(backToToday, isTrue);
  });

  testWidgets("the selected day's events, earliest first, open on tap", (
    tester,
  ) async {
    CalendarEvent? opened;
    await _pump(
      tester,
      events: [_workshop, _training],
      onOpen: (event) => opened = event,
    );

    expect(find.text('THURSDAY, OCTOBER 8'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('New member training')).dy,
      lessThan(tester.getTopLeft(find.text('Essential oils for sleep')).dy),
    );
    expect(find.text('7:00 PM'), findsOneWidget);
    expect(find.text('9:00 PM'), findsOneWidget);
    expect(find.text('Studio Lumière, Lyon'), findsOneWidget);
    // A link and no place.
    expect(find.text('Online'), findsOneWidget);

    await tester.tap(find.text('Essential oils for sleep'));
    expect(opened, _workshop);
  });

  testWidgets('an empty day says so; Add and the button add on it', (
    tester,
  ) async {
    final added = <DateTime>[];
    await _pump(
      tester,
      events: [_workshop],
      selection: (month: DateTime(2026, 10), day: DateTime(2026, 10, 9)),
      onAdd: added.add,
    );

    expect(find.text('Nothing planned'), findsOneWidget);
    await tester.tap(find.text('Add'));
    await tester.tap(find.byTooltip('New event'));

    expect(added, [DateTime(2026, 10, 9), DateTime(2026, 10, 9)]);
  });

  testWidgets('a failed load says so', (tester) async {
    await _pump(
      tester,
      value: AsyncError(Exception('offline'), StackTrace.empty),
    );

    expect(find.text("Couldn't load your calendar."), findsOneWidget);
  });

  testWidgets('desktop: the grid, and the pane beside it', (tester) async {
    await _pump(
      tester,
      size: const Size(1440, 900),
      pane: const Text('pane'),
    );

    expect(find.text('pane'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(
      tester.getCenter(find.text('October 2026')).dx,
      lessThan(tester.getCenter(find.text('pane')).dx),
    );
  });

  testWidgets('in the app: an event added today shows under today', (
    tester,
  ) async {
    final events = FakeEventRepository();
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 844),
      events: events,
    );
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('New event'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Title'),
        matching: find.byType(TextFormField),
      ),
      'Workshop',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Workshop'), findsOneWidget);
    expect(events.store.single.day, today());
  });
}
```

- [ ] **Step 4: Run them to see them fail**

Run: `flutter test test/features/calendar/presentation/calendar_page_test.dart`
Expected: FAIL, `calendar_page.dart` not found.

- [ ] **Step 5: Write the month grid**

`lib/features/calendar/presentation/month_grid.dart`:

```dart
import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/features/calendar/domain/month_grid.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A month as whole weeks (spec §3): the locale's first weekday first, the
/// neighbouring months' days dimmed, up to three dots for a day's events, a
/// ring on today, the selected day filled. Any day can be tapped, one of a
/// neighbouring month too.
class MonthGrid extends StatelessWidget {
  const MonthGrid({
    required this.month,
    required this.selected,
    required this.today,
    required this.counts,
    required this.onSelect,
    super.key,
  });

  /// The 1st of the month shown, local midnight.
  final DateTime month;
  final DateTime selected;
  final DateTime today;

  /// Events per local day; a day without any is absent.
  final Map<DateTime, int> counts;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final days = monthDays(
      month,
      MaterialLocalizations.of(context).firstDayOfWeekIndex,
    );
    final weekday = DateFormat.E(Localizations.localeOf(context).toString());
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: LoomiaColors.of(context).textMuted,
    );
    const week = DateTime.daysPerWeek;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xs,
      children: [
        // Each day says its full date already.
        ExcludeSemantics(
          child: Row(
            children: [
              for (final day in days.take(week))
                Expanded(
                  child: Text(
                    weekday.format(day),
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ),
            ],
          ),
        ),
        for (var start = 0; start < days.length; start += week)
          Row(
            children: [
              for (final day in days.sublist(start, start + week))
                Expanded(
                  child: _Day(
                    day: day,
                    inMonth: day.month == month.month,
                    selected: day == selected,
                    today: day == today,
                    past: day.isBefore(today),
                    count: counts[day] ?? 0,
                    onTap: () => onSelect(day),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.past,
    required this.count,
    required this.onTap,
  });

  static const double _circle = 40;
  static const double _ring = 1.5;
  static const double _dot = 6;
  static const int _maxDots = 3;

  final DateTime day;
  final bool inMonth;
  final bool selected;
  final bool today;
  final bool past;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LoomiaColors.of(context);
    final ink = selected
        ? scheme.onPrimary
        : today
        ? colors.primaryText
        : inMonth
        ? scheme.onSurface
        : colors.textDisabled;
    final number = selected || today
        ? theme.textTheme.labelLarge
        : theme.textTheme.bodyLarge;

    return Semantics(
      button: true,
      selected: selected,
      label: AppLocalizations.of(context).calendarDaySemantics(day, count),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: AppSpacing.xs,
            children: [
              Container(
                width: _circle,
                height: _circle,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? scheme.primary : null,
                  border: today && !selected
                      ? Border.all(color: scheme.primary, width: _ring)
                      : null,
                ),
                child: Text('${day.day}', style: number?.copyWith(color: ink)),
              ),
              SizedBox(
                height: _dot,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: AppSpacing.xs,
                  children: [
                    for (var i = 0; i < count.clamp(0, _maxDots); i++)
                      Container(
                        width: _dot,
                        height: _dot,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: past ? colors.textMuted : scheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Write the event row**

`lib/features/calendar/presentation/event_row.dart`:

```dart
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// [at] as a local time of day, in the device's 12- or 24-hour format.
String timeLabel(BuildContext context, DateTime at) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(at.toLocal()),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// "Thursday, October 8 · 7:00 PM – 9:00 PM".
String whenLabel(BuildContext context, CalendarEvent event) {
  final start = timeLabel(context, event.startsAt);
  final ends = event.endsAt;
  return AppLocalizations.of(context).eventWhen(
    event.day,
    ends == null ? start : '$start – ${timeLabel(context, ends)}',
  );
}

/// One event on the Calendar: its times, a bar, its title and where.
class EventRow extends StatelessWidget {
  const EventRow({required this.event, required this.onTap, super.key});

  static const double _timeWidth = 64;
  static const double _bar = 3;

  final CalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = LoomiaColors.of(context);
    final ends = event.endsAt;
    final where =
        event.place ??
        (event.link == null ? null : AppLocalizations.of(context).eventOnline);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      side: BorderSide(color: colors.borderSubtle),
    );

    return Material(
      color: colors.surfaceDefault,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.ms,
              children: [
                SizedBox(
                  width: _timeWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        timeLabel(context, event.startsAt),
                        style: theme.textTheme.labelLarge,
                      ),
                      if (ends != null)
                        Text(
                          timeLabel(context, ends),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const SizedBox(width: _bar),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppSpacing.xs,
                    children: [
                      Text(event.title, style: theme.textTheme.titleMedium),
                      if (where != null)
                        Text(
                          where,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

`whenLabel` uses `eventWhen`. Add it to `app_en.arb` now, since Task 6 is its only reader:

```json
  "eventWhen": "{day} · {time}",
  "@eventWhen": {
    "description": "When an event happens, on its screen: the date, then the time or 'start – end', e.g. 'Thursday, October 8 · 7:00 PM – 9:00 PM'.",
    "placeholders": {
      "day": { "type": "DateTime", "format": "MMMMEEEEd" },
      "time": { "type": "String" }
    }
  }
```

Run `flutter gen-l10n` again.

- [ ] **Step 7: Write the Calendar page**

`lib/features/calendar/presentation/calendar_page.dart`:

```dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_form.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Opens an event: in the pane beside the month on desktop, pushed above
/// the month elsewhere so back returns to it.
void openEvent(BuildContext context, String id) {
  final location = Routes.eventLocation(id);
  if (context.screenSize.isDesktop) {
    context.go(location);
  } else {
    unawaited(context.push(location));
  }
}

/// The Calendar destination. On desktop it also holds [pane]: the selected
/// day, or an event.
class CalendarPage extends ConsumerWidget {
  const CalendarPage({this.pane, super.key});

  final Widget? pane;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = eventsProvider(ref.watch(accountProvider)?.email);
    final selector = ref.read(calendarSelectionProvider.notifier);
    return CalendarView(
      events: ref.watch(provider),
      selection: ref.watch(calendarSelectionProvider),
      today: today(),
      onSelect: (day) {
        selector.select(day);
        // Desktop: an open event gives the pane back to the day.
        if (pane != null) context.go(Routes.calendar);
      },
      onShift: selector.shift,
      onToday: selector.toToday,
      onOpen: (event) => openEvent(context, event.id),
      onAdd: (day) => unawaited(showEventForm(context, day: day)),
      onRetry: () => ref.invalidate(provider),
      pane: pane,
      // With a sidebar, Settings is its account block instead.
      accountAction: context.screenSize.usesSideNavigation
          ? null
          : const AccountButton(),
    );
  }
}

/// Desktop's pane at `/calendar`: the selected day.
class CalendarDayPane extends ConsumerWidget {
  const CalendarDayPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = eventsProvider(ref.watch(accountProvider)?.email);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        DaySection(
          events: ref.watch(provider),
          day: ref.watch(calendarSelectionProvider).day,
          onOpen: (event) => openEvent(context, event.id),
          onAdd: (day) => unawaited(showEventForm(context, day: day)),
          onRetry: () => ref.invalidate(provider),
        ),
      ],
    );
  }
}

/// The screen as a function of its inputs, for previews and tests. Mobile
/// and tablet: the month, then the selected day, and an add button. Desktop
/// ([pane] set): the month on the left, [pane] on the right.
class CalendarView extends StatelessWidget {
  const CalendarView({
    required this.events,
    required this.selection,
    required this.today,
    required this.onSelect,
    required this.onShift,
    required this.onToday,
    required this.onOpen,
    required this.onAdd,
    required this.onRetry,
    this.pane,
    this.accountAction,
    super.key,
  });

  /// Fixed, like the Contacts list, so a resized window narrows the month.
  static const double _paneWidth = 440;

  /// A horizontal swipe faster than this changes month.
  static const double _swipe = 300;

  final AsyncValue<List<CalendarEvent>> events;
  final CalendarSelection selection;

  /// The device's today, local midnight.
  final DateTime today;

  final ValueChanged<DateTime> onSelect;

  /// −1 for the month before, 1 for the one after.
  final ValueChanged<int> onShift;
  final VoidCallback onToday;
  final void Function(CalendarEvent event) onOpen;

  /// Adds an event on the given day.
  final ValueChanged<DateTime> onAdd;
  final VoidCallback onRetry;
  final Widget? pane;

  /// Top-bar entry to Settings, where there is no sidebar to hold it.
  final Widget? accountAction;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final side = pane;
    final header = Row(
      children: [
        Expanded(
          child: Text(
            l10n.calendarMonth(selection.month),
            style: side == null
                ? theme.textTheme.headlineSmall
                : theme.textTheme.displaySmall,
          ),
        ),
        TextButton(onPressed: onToday, child: Text(l10n.calendarToday)),
        IconButton(
          onPressed: () => onShift(-1),
          tooltip: l10n.calendarPreviousMonth,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          onPressed: () => onShift(1),
          tooltip: l10n.calendarNextMonth,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        ?accountAction,
      ],
    );
    final grid = GestureDetector(
      // A swipe changes month, as in the phone's own calendar.
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() > _swipe) onShift(velocity < 0 ? 1 : -1);
      },
      child: MonthGrid(
        month: selection.month,
        selected: selection.day,
        today: today,
        counts: eventsPerDay(events.value ?? const []),
        onSelect: onSelect,
      ),
    );

    if (side != null) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxl,
                    vertical: AppSpacing.xl,
                  ),
                  children: [header, const SizedBox(height: AppSpacing.lg), grid],
                ),
              ),
              Container(
                width: _paneWidth,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: LoomiaColors.of(context).borderSubtle,
                    ),
                  ),
                ),
                child: side,
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => onAdd(selection.day),
        tooltip: l10n.calendarNewEvent,
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: ListView(
          // The bottom inset keeps the last row clear of the add button.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxxl + AppSpacing.lg,
          ),
          children: [
            header,
            const SizedBox(height: AppSpacing.md),
            grid,
            const Divider(height: AppSpacing.xl),
            DaySection(
              events: events,
              day: selection.day,
              onOpen: onOpen,
              onAdd: onAdd,
              onRetry: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// The selected day: its heading with Add, then its events, or what is
/// wrong with loading them.
class DaySection extends StatelessWidget {
  const DaySection({
    required this.events,
    required this.day,
    required this.onOpen,
    required this.onAdd,
    required this.onRetry,
    super.key,
  });

  final AsyncValue<List<CalendarEvent>> events;
  final DateTime day;
  final void Function(CalendarEvent event) onOpen;
  final ValueChanged<DateTime> onAdd;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // `.value` survives a failed refresh, so the rows stay on screen.
    final list = events.value;
    final List<Widget> body;
    if (list != null) {
      final today = eventsOn(list, day);
      body = today.isEmpty
          ? [
              Text(
                l10n.calendarNothingPlanned,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: LoomiaColors.of(context).textMuted,
                ),
              ),
            ]
          : [
              for (final (index, event) in today.indexed) ...[
                if (index > 0) const SizedBox(height: AppSpacing.ms),
                EventRow(event: event, onTap: () => onOpen(event)),
              ],
            ];
    } else if (events.hasError) {
      body = [
        EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l10n.calendarLoadFailed,
          body: l10n.contactsLoadErrorBody,
          actionLabel: l10n.contactsRetry,
          onAction: onRetry,
        ),
      ];
    } else {
      body = [const Center(child: CircularProgressIndicator())];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: l10n.calendarDayTitle(day),
          actionLabel: l10n.calendarAdd,
          onAction: () => onAdd(day),
        ),
        const SizedBox(height: AppSpacing.ms),
        ...body,
      ],
    );
  }
}
```

In `DaySection`, rename the local `today` to `onDay` if `flutter analyze` flags it for shadowing the imported `today()`.

- [ ] **Step 8: Route it** in `lib/app/router/app_router.dart`

Import `calendar_page.dart`. Add this `ShellRoute` inside the signed-in shell, right after the Today `GoRoute`:

```dart
          // Like Contacts: on desktop the month stays built beside a pane
          // that follows the URL; elsewhere the month and an event are
          // separate screens.
          ShellRoute(
            builder: (context, state, child) => context.screenSize.isDesktop
                ? CalendarPage(pane: child)
                : child,
            routes: [
              GoRoute(
                path: Routes.calendar,
                name: Routes.calendarName,
                pageBuilder: (context, state) =>
                    _calendarPage(context, state, null),
              ),
            ],
          ),
```

and this function next to `_contactsPage`:

```dart
/// Desktop: the pane beside the month, swapped without a transition (see
/// [_settingsPage]). Elsewhere: the month, or an event pushed above it.
Page<void> _calendarPage(
  BuildContext context,
  GoRouterState state,
  String? id,
) {
  if (context.screenSize.isDesktop) {
    return NoTransitionPage<void>(
      key: state.pageKey,
      name: state.name,
      child: const Scaffold(body: CalendarDayPane()),
    );
  }
  return MaterialPage<void>(
    key: state.pageKey,
    name: state.name,
    child: const CalendarPage(),
  );
}
```

Task 6 adds the event's child route and uses `id`.

- [ ] **Step 9: Run the tests**

Run: `flutter test test/features/calendar`
Expected: PASS. If the French test can't find `lun.`, print `DateFormat.E('fr').format(DateTime(2026, 10, 5))` and use what the installed `intl` gives (it is `lun.` in current CLDR).

- [ ] **Step 10: Commit**

```bash
git add lib/app/router lib/features/calendar lib/l10n/app_en.arb test/features/calendar
git commit -m "feat(calendar): show the month and the selected day"
```

---

### Task 6: The event screen

**Files:**
- Create: `lib/core/ui/open_external.dart`
- Modify: `lib/features/contacts/presentation/contact_page.dart` (use `openExternal`, delete `_launch`)
- Create: `lib/features/calendar/presentation/event_page.dart`
- Modify: `lib/app/router/app_router.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/calendar/presentation/event_page_test.dart`

**Interfaces:**
- Consumes: `whenLabel` (Task 5), `showEventForm` (Task 4), `eventsProvider` (Task 3), `mapsUri`, `shownLink` (Task 2), `confirmDestructive`, `backOr`, `peopleFailureCopy`, `AppTheme.tonal`.
- Produces:
  - `Future<void> openExternal(BuildContext context, Uri uri)`
  - `EventView({event, onEdit, onDelete, onOpenPlace, onJoin})`, `EventPane({id})`, `EventPage({id})`
  - route `/calendar/:id`
  - l10n keys: `eventJoin`, `eventDelete`, `eventDeleteTitle`, `eventDeleteBody`, `eventDeleteAction`, `eventNotFound`, `eventNotFoundBody`.

- [ ] **Step 1: Add the copy** to `lib/l10n/app_en.arb`

```json
  "eventJoin": "Join",
  "@eventJoin": {
    "description": "Button on an event's screen that opens its online meeting link."
  },
  "eventDelete": "Delete event",
  "@eventDelete": {
    "description": "Tooltip of the delete button on an event's screen."
  },
  "eventDeleteTitle": "Delete {title}?",
  "@eventDeleteTitle": {
    "description": "Title of the dialog that confirms deleting an event. title is the event's title.",
    "placeholders": {
      "title": { "type": "String" }
    }
  },
  "eventDeleteBody": "It goes from your calendar. Nobody else is told.",
  "@eventDeleteBody": {
    "description": "Body of the dialog that confirms deleting an event."
  },
  "eventDeleteAction": "Delete",
  "@eventDeleteAction": {
    "description": "Destructive button of the dialog that confirms deleting an event."
  },
  "eventNotFound": "This event isn't in your calendar any more.",
  "@eventNotFound": {
    "description": "Title shown when an event's link points to one that no longer exists."
  },
  "eventNotFoundBody": "It may have been deleted on another device.",
  "@eventNotFoundBody": {
    "description": "Body under eventNotFound."
  }
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing tests**

`test/features/calendar/presentation/event_page_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/event_page.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_event_repository.dart';

final _workshop = CalendarEvent(
  id: 'e1',
  title: 'Essential oils for sleep',
  startsAt: DateTime(2026, 10, 8, 19),
  endsAt: DateTime(2026, 10, 8, 21),
  place: 'Studio Lumière, Lyon',
  link: 'https://meet.google.com/abc',
  notes: 'Bring the diffuser',
);

/// Today at 19:00, so the Calendar lists it as it opens.
CalendarEvent _tonight() {
  final day = today();
  return CalendarEvent(
    id: 'e1',
    title: 'Workshop',
    startsAt: DateTime(day.year, day.month, day.day, 19),
  );
}

Future<void> _pumpView(
  WidgetTester tester,
  CalendarEvent event, {
  void Function(String place)? onOpenPlace,
  void Function(Uri link)? onJoin,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: EventView(
          event: event,
          onEdit: () {},
          onDelete: () {},
          onOpenPlace: onOpenPlace ?? (_) {},
          onJoin: onJoin ?? (_) {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('what, when, where, the link and the notes', (tester) async {
    String? place;
    Uri? joined;
    await _pumpView(
      tester,
      _workshop,
      onOpenPlace: (value) => place = value,
      onJoin: (value) => joined = value,
    );

    expect(find.text('Essential oils for sleep'), findsOneWidget);
    expect(
      find.text('Thursday, October 8 · 7:00 PM – 9:00 PM'),
      findsOneWidget,
    );
    expect(find.text('meet.google.com/abc'), findsOneWidget);
    expect(find.text('Bring the diffuser'), findsOneWidget);

    await tester.tap(find.text('Studio Lumière, Lyon'));
    await tester.tap(find.text('Join'));

    expect(place, 'Studio Lumière, Lyon');
    expect(joined, Uri.parse('https://meet.google.com/abc'));
  });

  testWidgets('no place, link or notes: only when', (tester) async {
    await _pumpView(
      tester,
      CalendarEvent(id: 'e2', title: 'Call', startsAt: DateTime(2026, 10, 8, 9)),
    );

    expect(find.text('Thursday, October 8 · 9:00 AM'), findsOneWidget);
    expect(find.text('Join'), findsNothing);
    expect(find.byIcon(Icons.place_outlined), findsNothing);
  });

  testWidgets('mobile: opens from the day, edits, back to the month', (
    tester,
  ) async {
    final events = FakeEventRepository([_tonight()]);
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 844),
      events: events,
    );
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workshop'));
    await tester.pumpAndSettle();
    expect(find.byType(EventPage), findsOneWidget);

    await tester.tap(find.byTooltip('Edit event'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Title'),
        matching: find.byType(TextFormField),
      ),
      'Product evening',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('Product evening'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarView), findsOneWidget);
    expect(find.text('Product evening'), findsOneWidget);
  });

  testWidgets('delete: confirmed, back on the month, never "not found"', (
    tester,
  ) async {
    final events = FakeEventRepository([_tonight()]);
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 844),
      events: events,
    );
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workshop'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete event'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Workshop?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump();
    expect(find.text("This event isn't in your calendar any more."), findsNothing);
    await tester.pumpAndSettle();

    expect(find.byType(CalendarView), findsOneWidget);
    expect(find.text('Workshop'), findsNothing);
    expect(events.calls, contains('remove(e1)'));
    expect(find.text("This event isn't in your calendar any more."), findsNothing);
  });

  testWidgets('desktop: the event opens in the pane, the month stays', (
    tester,
  ) async {
    final container = await pumpLoomia(
      tester,
      size: const Size(1440, 900),
      events: FakeEventRepository([_tonight()]),
    );
    container.read(routerProvider).go(Routes.calendar);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workshop'));
    await tester.pumpAndSettle();

    expect(find.byType(MonthGrid), findsOneWidget);
    expect(find.byType(EventView), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('a link to an event that is gone says so', (tester) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));
    container.read(routerProvider).go(Routes.eventLocation('nope'));
    await tester.pumpAndSettle();

    expect(find.text("This event isn't in your calendar any more."), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/features/calendar/presentation/event_page_test.dart`
Expected: FAIL, `event_page.dart` not found.

- [ ] **Step 4: Move the launcher into core**

`lib/core/ui/open_external.dart`:

```dart
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] in another app: the dialer, the maps app, the browser. When
/// nothing opens it, a SnackBar says so.
Future<void> openExternal(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  bool opened;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Exception {
    // No app for the scheme throws on some platforms instead of returning
    // false.
    opened = false;
  }
  if (!opened) {
    messenger.showSnackBar(SnackBar(content: Text(l10n.contactLaunchFailed)));
  }
}
```

In `contact_page.dart`: delete the `_launch` method, replace `onLaunch: (uri) => unawaited(_launch(context, uri)),` with `onLaunch: (uri) => unawaited(openExternal(context, uri)),`, add `import 'package:loomia/core/ui/open_external.dart';`, and drop the `url_launcher` import if nothing else there uses it.

- [ ] **Step 5: Write the event screen**

`lib/features/calendar/presentation/event_page.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/open_external.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/event_form.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// One event on mobile and tablet: a screen of its own above the month.
class EventPage extends StatelessWidget {
  const EventPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => backOr(context, Routes.calendar)),
      ),
      body: SafeArea(top: false, child: EventPane(id: id)),
    );
  }
}

/// An event found in the loaded calendar (there is no second fetch), wired
/// to editing, deleting and the other apps. Shared by [EventPage] and the
/// desktop pane.
class EventPane extends ConsumerWidget {
  const EventPane({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final provider = eventsProvider(ref.watch(accountProvider)?.email);
    final events = ref.watch(provider);
    final list = events.value;
    if (list == null) {
      return events.hasError
          ? Center(
              child: EmptyState(
                icon: Icons.cloud_off_outlined,
                title: l10n.calendarLoadFailed,
                body: l10n.contactsLoadErrorBody,
                actionLabel: l10n.contactsRetry,
                onAction: () => ref.invalidate(provider),
              ),
            )
          : const Center(child: CircularProgressIndicator());
    }
    final event = list.where((event) => event.id == id).firstOrNull;
    if (event == null) {
      return Center(
        child: EmptyState(
          icon: Icons.event_busy_outlined,
          title: l10n.eventNotFound,
          body: l10n.eventNotFoundBody,
        ),
      );
    }
    return EventView(
      event: event,
      onEdit: () => unawaited(showEventForm(context, event: event)),
      onDelete: () => unawaited(_delete(context, ref, event)),
      onOpenPlace: (place) => unawaited(
        openExternal(
          context,
          mapsUri(
            place,
            apple: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS,
          ),
        ),
      ),
      onJoin: (link) => unawaited(openExternal(context, link)),
    );
  }

  /// Leaves the event first, so its screen never shows it missing.
  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final events = ref.read(
      eventsProvider(ref.read(accountProvider)?.email).notifier,
    );
    final confirmed = await confirmDestructive(
      context,
      title: l10n.eventDeleteTitle(event.title),
      body: l10n.eventDeleteBody,
      action: l10n.eventDeleteAction,
    );
    if (!confirmed || !context.mounted) return;
    if (context.screenSize.isDesktop) {
      context.go(Routes.calendar);
    } else {
      final leaving = ModalRoute.of(context);
      backOr(context, Routes.calendar);
      await leaving?.completed;
    }
    try {
      await events.remove(event.id);
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }
}

/// The event as a function of its inputs, for previews and tests.
class EventView extends StatelessWidget {
  const EventView({
    required this.event,
    required this.onEdit,
    required this.onDelete,
    required this.onOpenPlace,
    required this.onJoin,
    super.key,
  });

  final CalendarEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Opens the maps app on the place.
  final void Function(String place) onOpenPlace;
  final void Function(Uri link) onJoin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final place = event.place;
    final link = event.link;
    final notes = event.notes;

    return ListView(
      padding: EdgeInsets.all(
        context.screenSize.isDesktop ? AppSpacing.lg : AppSpacing.md,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(event.title, style: theme.textTheme.headlineSmall),
            ),
            IconButton(
              onPressed: onEdit,
              tooltip: l10n.eventEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              onPressed: onDelete,
              tooltip: l10n.eventDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.ms),
        _Line(icon: Icons.schedule_rounded, text: whenLabel(context, event)),
        if (place != null)
          _Line(
            icon: Icons.place_outlined,
            text: place,
            onTap: () => onOpenPlace(place),
          ),
        if (link != null)
          _Line(
            icon: Icons.videocam_outlined,
            text: shownLink(link),
            trailing: FilledButton.tonal(
              style: AppTheme.tonal(context),
              onPressed: () => onJoin(Uri.parse(link)),
              child: Text(l10n.eventJoin),
            ),
          ),
        if (notes != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              notes,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// An icon and a line. With [onTap], the line reads as a link.
class _Line extends StatelessWidget {
  const _Line({
    required this.icon,
    required this.text,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final tap = onTap;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        spacing: AppSpacing.sm,
        children: [
          Icon(icon, color: muted),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: tap == null
                    ? muted
                    : LoomiaColors.of(context).primaryText,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
    return tap == null
        ? row
        : Semantics(link: true, child: InkWell(onTap: tap, child: row));
  }
}
```

- [ ] **Step 6: Route the event** in `lib/app/router/app_router.dart`

Import `event_page.dart`. Give the `Routes.calendar` `GoRoute` a child:

```dart
                routes: [
                  GoRoute(
                    path: Routes.eventSegment,
                    name: Routes.eventName,
                    pageBuilder: (context, state) => _calendarPage(
                      context,
                      state,
                      state.pathParameters['id'],
                    ),
                  ),
                ],
```

and make `_calendarPage` use `id`:

```dart
  if (context.screenSize.isDesktop) {
    return NoTransitionPage<void>(
      key: state.pageKey,
      name: state.name,
      child: Scaffold(
        body: id == null ? const CalendarDayPane() : EventPane(id: id),
      ),
    );
  }
  return MaterialPage<void>(
    key: state.pageKey,
    name: state.name,
    child: id == null ? const CalendarPage() : EventPage(id: id),
  );
```

- [ ] **Step 7: Run the tests**

Run: `flutter test test/features/calendar test/features/contacts`
Expected: PASS. The contacts suites check that the launcher move broke nothing.

- [ ] **Step 8: Commit**

```bash
git add lib/core/ui/open_external.dart lib/features/contacts/presentation/contact_page.dart lib/features/calendar lib/app/router lib/l10n/app_en.arb test/features/calendar
git commit -m "feat(calendar): open, edit and delete an event"
```

---

### Task 7: Calendar takes Team's place

**Files:**
- Modify: `lib/app/shell/app_shell.dart`
- Modify: `lib/app/router/app_router.dart`, `lib/app/router/routes.dart`
- Modify: `lib/features/today/presentation/today_page.dart`
- Delete: `lib/features/team/presentation/team_page.dart`, `lib/features/team/presentation/team_preview.dart`, `test/features/team/team_page_test.dart`, `test/features/team/team_desktop_test.dart`, `test/goldens/team_mobile_light.png`, `test/goldens/team_mobile_dark.png`, `test/goldens/team_desktop_light.png`
- Keep: `lib/features/team/domain/check_in.dart`, `lib/features/team/presentation/check_in_items.dart`, `test/features/team/domain/check_in_test.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`, `lib/l10n/translation_sources.json`
- Modify: `test/previews_test.dart`, `test/store_screenshots_test.dart`
- Test: `test/app/shell/app_shell_test.dart`, `test/features/today/today_goals_test.dart`

**Interfaces:**
- Consumes: `CalendarPage`, `CalendarView` (Task 5), `checkInItems` (unchanged).
- Produces: tabs Today · Calendar · Contacts · Goals; `/team` redirects to `/contacts`; l10n key `navCalendar`.

- [ ] **Step 1: Add the copy** to `lib/l10n/app_en.arb`, after `navContacts`

```json
  "navCalendar": "Calendar",
  "@navCalendar": {
    "description": "Navigation destination (bottom bar, sidebar) that opens the Calendar: the user's events, such as workshops."
  },
```

- [ ] **Step 2: Change the failing tests**

In `test/app/shell/app_shell_test.dart`, replace the import of `team_page.dart` with `import 'package:loomia/features/calendar/presentation/calendar_page.dart';`, `import 'package:loomia/app/router/app_router.dart';` and `import 'package:loomia/features/contacts/presentation/contacts_page.dart';` (for `ContactsPage`; skip it if `ContactList` is enough). Replace the two Team tests (`'mobile: Team is the third tab and opens the team'` and `'desktop: the sidebar opens the team'`) with:

```dart
  testWidgets('mobile: Calendar is the second tab and opens the month', (
    tester,
  ) async {
    await pumpLoomia(tester, size: const Size(390, 844));

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarView), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);
    expect(find.text('Team'), findsNothing);
  });

  testWidgets('desktop: the sidebar opens the Calendar', (tester) async {
    await pumpLoomia(tester, size: const Size(1440, 900));

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarView), findsOneWidget);
  });

  testWidgets('an old link to Team opens Contacts', (tester) async {
    final container = await pumpLoomia(tester, size: const Size(390, 844));

    container.read(routerProvider).go(Routes.team);
    await tester.pumpAndSettle();

    expect(find.byType(ContactList), findsOneWidget);
  });
```

Add `import 'package:loomia/app/router/routes.dart';` if it isn't there. In `'mobile: Goals is the fourth tab and opens Goals'`, `selectedIndex` stays 3.

In `test/features/today/today_goals_test.dart`, after `'desktop check-ins sit 12 apart, as on Team'`, add:

```dart
  testWidgets('mobile: the check-ins follow the day', (tester) async {
    await pump(
      tester,
      now: DateTime(2026, 9, 29, 9),
      size: const Size(390, 1600),
      checkIns: [
        (
          person: Person(
            id: 'Bruno',
            name: 'Bruno',
            stage: Stage.team,
            stageSince: DateTime(2026, 5),
            lastContactOn: DateTime(2026, 9),
          ),
          reason: CheckInReason.quiet,
          since: DateTime(2026, 9),
          days: 28,
        ),
      ],
    );

    expect(find.text('WORTH A CHECK-IN'), findsOneWidget);
    expect(find.text('Bruno'), findsOneWidget);
  });
```

If this file's `pump` takes no default due list, pass the same empty one the other tests in the file use.

Then port the integration test from the deleted team test into `test/features/today/today_page_test.dart`:

```dart
  testWidgets('a new team member is worth a check-in; logging clears it', (
    tester,
  ) async {
    final activities = FakeActivityRepository();
    final people = FakePeopleRepository([
      Person(
        id: 'bea',
        name: 'Bea Martin',
        stage: Stage.team,
        stageSince: addDays(today(), -9).toUtc(),
      ),
    ])..activities = activities;
    await pumpLoomia(
      tester,
      size: _tallPhone,
      people: people,
      activities: activities,
    );
    expect(find.text('WORTH A CHECK-IN'), findsOneWidget);

    await tester.tap(find.byTooltip('Log something with Bea'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Welcome call');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('WORTH A CHECK-IN'), findsNothing);
  });
```

with `import '../contacts/fake_activity_repository.dart';` and `import 'package:loomia/features/workflows/domain/progress.dart';` (for `addDays`) if they are missing.

- [ ] **Step 3: Run them to see them fail**

Run: `flutter test test/app/shell/app_shell_test.dart test/features/today`
Expected: FAIL. There is no 'Calendar' destination, `/team` still opens `TeamPage`, and mobile Today has no check-ins.

- [ ] **Step 4: Swap the destinations** in `lib/app/shell/app_shell.dart`

Mobile:

```dart
      const tabs = [
        Routes.today,
        Routes.calendar,
        Routes.contacts,
        Routes.goals,
      ];
```

with destinations, in order:

```dart
                  NavigationDestination(
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: l10n.navToday,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: l10n.navCalendar,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.people_outline),
                    label: l10n.navContacts,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.flag_outlined),
                    label: l10n.navGoals,
                  ),
```

Sidebar: replace the Team `_SidebarItem` with this one, moved up between Today and Contacts:

```dart
                _SidebarItem(
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: l10n.navCalendar,
                  selected: location.startsWith(Routes.calendar),
                  expanded: expanded,
                  onTap: () => context.go(Routes.calendar),
                ),
```

In the class comment, replace "Goals joins when it exists, never as a placeholder." with "Team returns with the team plan; until then the Contacts `Team` filter lists the team, and Today its check-ins."

- [ ] **Step 5: Redirect `/team`**

In `routes.dart`, change the doc above `team`:

```dart
  /// The old Team tab (before #151). Kept so a saved link lands on Contacts.
  static const String team = '/team';
  static const String teamName = 'team';
```

In `app_router.dart`, replace the Team `GoRoute` (and drop the `team_page.dart` import) with:

```dart
          GoRoute(
            path: Routes.team,
            name: Routes.teamName,
            redirect: (context, state) => Routes.contacts,
          ),
```

- [ ] **Step 6: Check-ins on Today, every size**

In `today_page.dart`, `_TodayViewState.build`, replace the `else ...content,` branch of the `ListView` children with:

```dart
                  else ...[
                    ...content,
                    // Desktop has them in the side column.
                    if (widget.checkIns.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      ...checkInItems(
                        l10n,
                        widget.checkIns,
                        onOpen: widget.onOpen,
                        onCheckIn: widget.onCheckIn ?? (_) {},
                      ),
                    ],
                  ],
```

Update the `checkIns` field's doc: "Team members worth a check-in: under the day on a phone, in the side column on desktop."

- [ ] **Step 7: Delete Team's screen and its copy**

```bash
git rm lib/features/team/presentation/team_page.dart \
  lib/features/team/presentation/team_preview.dart \
  test/features/team/team_page_test.dart \
  test/features/team/team_desktop_test.dart \
  test/goldens/team_mobile_light.png \
  test/goldens/team_mobile_dark.png \
  test/goldens/team_desktop_light.png
```

In `test/previews_test.dart`, drop the `team_preview.dart` import and the three `team_*` entries (keep `team_member_mobile_light`, which is a Contacts preview).

List the Team keys nothing reads any more:

```bash
for key in $(grep -oE '^  "(team[A-Za-z]*|navTeam)":' lib/l10n/app_en.arb | tr -d ' ":'); do
  grep -rqw "$key" lib --include='*.dart' --exclude='app_localizations*' || echo "$key"
done
```

Delete each printed key and its `@key` block from `app_en.arb`, the key from `app_fr.arb`, and its entry from the `fr` object of `translation_sources.json`. Keep the JSON valid: no trailing comma before a closing brace. `teamSectionCheckIn`, `teamChip*` and `teamReason*` are still read by `check_in_items.dart` and must not be printed.

Run: `flutter gen-l10n && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Store screenshots show the Calendar**

In `test/store_screenshots_test.dart`, replace `'team': Routes.team,` with `'calendar': Routes.calendar,`, pass `events: FakeEventRepository(_events()),` to `pumpLoomia`, and add, next to `_book()`:

```dart
/// Today's workshop and training, and two more later in the month.
List<CalendarEvent> _events() {
  final day = today();
  DateTime at(int days, int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day + days, hour, minute);
  return [
    CalendarEvent(
      id: 'e1',
      title: 'Essential oils for sleep',
      startsAt: at(0, 19),
      endsAt: at(0, 21),
      place: 'Studio Lumière, Lyon',
    ),
    CalendarEvent(
      id: 'e2',
      title: 'New member training',
      startsAt: at(0, 14),
      endsAt: at(0, 15),
      link: 'https://meet.google.com/abc-defg-hij',
    ),
    CalendarEvent(
      id: 'e3',
      title: 'Product evening',
      startsAt: at(6, 19, 30),
      place: 'Chez Claire',
    ),
    CalendarEvent(id: 'e4', title: 'Workshop', startsAt: at(13, 19)),
  ];
}
```

with imports `package:loomia/features/calendar/domain/calendar_event.dart` and `features/calendar/fake_event_repository.dart`.

Run: `flutter test test/store_screenshots_test.dart --dart-define=STORE_SCREENSHOTS=true --plain-name 'phone en calendar'`
Expected: PASS, and `build/store/phone/en/4_calendar.png` shows today's two events. Open it.

- [ ] **Step 9: Run everything**

Run: `flutter test`
Expected: PASS. The goldens are compared on Linux only.

- [ ] **Step 10: Commit**

```bash
git add -A lib test
git commit -m "feat(calendar): put Calendar in Team's place in the navigation"
```

---

### Task 8: Previews, goldens, and the pull request

**Files:**
- Create: `lib/features/calendar/presentation/calendar_preview.dart`
- Modify: `test/previews_test.dart`
- Create: `test/goldens/calendar_mobile_light.png`, `calendar_mobile_dark.png`, `calendar_desktop_light.png`, `event_mobile_light.png` (from CI only)

**Interfaces:**
- Consumes: `CalendarView`, `DaySection`, `EventView`.
- Produces: `calendarMobileLight`, `calendarMobileDark`, `calendarDesktopLight`, `eventMobileLight`.

- [ ] **Step 1: Write the previews**

`lib/features/calendar/presentation/calendar_preview.dart`:

```dart
import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/event_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// The Calendar and an event, for `flutter widget-preview start`, on a fixed
/// day so the goldens never follow the clock: the Figma's October 2026,
/// today the 7th, the 8th selected. Nothing in the app imports this file.
@Preview(group: 'Calendar', name: 'Mobile — light', size: Size(390, 844))
Widget calendarMobileLight() => _app(AppTheme.light, _calendar());

@Preview(group: 'Calendar', name: 'Mobile — dark', size: Size(390, 844))
Widget calendarMobileDark() => _app(AppTheme.dark, _calendar());

@Preview(group: 'Calendar', name: 'Desktop — light', size: Size(1440, 900))
Widget calendarDesktopLight() => _app(
  AppTheme.light,
  _calendar(
    pane: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        DaySection(
          events: AsyncData(_events),
          day: _selected,
          onOpen: (_) {},
          onAdd: (_) {},
          onRetry: () {},
        ),
      ],
    ),
  ),
);

@Preview(group: 'Calendar', name: 'Event — light', size: Size(390, 844))
Widget eventMobileLight() => _app(
  AppTheme.light,
  Scaffold(
    appBar: AppBar(leading: const BackButton()),
    body: EventView(
      event: _events[1],
      onEdit: () {},
      onDelete: () {},
      onOpenPlace: (_) {},
      onJoin: (_) {},
    ),
  ),
);

final _today = DateTime(2026, 10, 7);
final _selected = DateTime(2026, 10, 8);

/// As in the Figma: a done event on the 3rd, two on the 8th, one on the
/// 14th, two on the 21st, one on the 27th.
final _events = [
  CalendarEvent(
    id: 'e0',
    title: 'Workshop',
    startsAt: DateTime(2026, 10, 3, 10),
  ),
  CalendarEvent(
    id: 'e1',
    title: 'Essential oils for sleep',
    startsAt: DateTime(2026, 10, 8, 19),
    endsAt: DateTime(2026, 10, 8, 21),
    place: 'Studio Lumière, 4 rue Mercière, Lyon',
    link: 'https://meet.google.com/abc-defg-hij',
    notes: 'Bring the diffuser and ten sample vials. Doors open at 18:45.',
  ),
  CalendarEvent(
    id: 'e2',
    title: 'New member training',
    startsAt: DateTime(2026, 10, 8, 14),
    endsAt: DateTime(2026, 10, 8, 15),
    link: 'https://meet.google.com/abc-defg-hij',
  ),
  CalendarEvent(
    id: 'e3',
    title: 'Product evening',
    startsAt: DateTime(2026, 10, 14, 19, 30),
  ),
  CalendarEvent(
    id: 'e4',
    title: 'Workshop',
    startsAt: DateTime(2026, 10, 21, 10),
  ),
  CalendarEvent(
    id: 'e5',
    title: 'Training',
    startsAt: DateTime(2026, 10, 21, 18),
  ),
  CalendarEvent(
    id: 'e6',
    title: 'Workshop',
    startsAt: DateTime(2026, 10, 27, 19),
  ),
];

Widget _calendar({Widget? pane}) => CalendarView(
  events: AsyncData(_events),
  selection: (month: DateTime(2026, 10), day: _selected),
  today: _today,
  onSelect: (_) {},
  onShift: (_) {},
  onToday: () {},
  onOpen: (_) {},
  onAdd: (_) {},
  onRetry: () {},
  pane: pane,
);

Widget _app(ThemeData theme, Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // The preview is its own app: without the delegates, any component that
    // reads AppLocalizations throws here.
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: home,
  );
}
```

- [ ] **Step 2: List them** in `test/previews_test.dart`

Import `package:loomia/features/calendar/presentation/calendar_preview.dart` and add, after the Today entries:

```dart
    'calendar_mobile_light': (const Size(390, 844), calendarMobileLight),
    'calendar_mobile_dark': (const Size(390, 844), calendarMobileDark),
    'calendar_desktop_light': (const Size(1440, 900), calendarDesktopLight),
    'event_mobile_light': (const Size(390, 844), eventMobileLight),
```

Run: `flutter test test/previews_test.dart`
Expected: PASS on macOS. The previews render without an exception; pixels are compared on Linux only.

- [ ] **Step 3: The quality gate**

Run: `dart format . && flutter analyze && flutter test`
Expected: format changes nothing (or commit what it changes); `No issues found!`; all tests pass.

- [ ] **Step 4: Commit and push**

```bash
git add lib/features/calendar/presentation/calendar_preview.dart test/previews_test.dart
git commit -m "test(calendar): preview the Calendar and an event"
git push -u origin feature/151-calendar-tab
```

If the push fails with "Connection closed … port 443", push over HTTPS with the gh credential helper (memory: ssh-push-blocked-use-https).

- [ ] **Step 5: Goldens from CI** (README → *Golden tests*)

```bash
gh workflow run CI --ref feature/151-calendar-tab -f update-goldens=true
gh run list --workflow CI --branch feature/151-calendar-tab --event workflow_dispatch --limit 1
gh run watch <run-id>
rm test/goldens/*.png
gh run download <run-id> -n goldens -D test/goldens
```

Open the four new PNGs and compare them with the Figma frames (Calendar — mobile, Calendar — desktop, Event — upcoming). Check that no other golden changed (`git status test/goldens`). Then:

```bash
git add test/goldens
git commit -m "test(calendar): add the Calendar goldens"
git push
```

- [ ] **Step 6: Open the pull request**

Fill the repository's pull-request template (`.github/PULL_REQUEST_TEMPLATE.md`). The **Ticket** section has `Closes #151`. Mention:
- the rulings above (no `/calendar/new` route, all events loaded at once, no event across midnight);
- that the migration still has to be pushed to the hosted project after merge (`supabase db push`; on the company VPN it fails with a "temp role" error).

Run `graphify update .` afterwards to refresh the local graph.
