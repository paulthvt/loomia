# Event Invitations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Event types say whether they gather several people (`event_workflow.is_group`). Someone added to a group event starts *invited*. Three days after the invite, or after the last follow-up, Today shows "Follow up Marc about Huiles et sommeil · Thu" with Going / Followed up / Remove until they are going, removed, or the event's day has passed. The event page shows Invited / Going per person, with a row menu. The daily push counts them (#314, part of #313).

**Architecture:** One migration:
- adds `is_group`, and `going`, `invited_on`, `followed_up_on` on `event_attendee`;
- adds a `before insert` trigger that sets `going` from the event's type when the insert leaves it null;
- adds the computed field `follow_up_on(event_attendee)`, the only copy of the 3-day rule, selected through the existing embed;
- replaces `extend_event_series`, `set_series_attendees` and `due_people_count`.

Going and Followed up are plain updates: the table already grants `update` under `event_open`. In Dart:
- `Attendee` becomes a class with defaults;
- `EventRepository` gains `setGoing` and `followedUp`, and `invite` sends the device's day;
- `dueToday` takes the events and adds `DueFollowUp`;
- `ActionItem` gains an `actions` slot for rows that need buttons instead of the ring. Event steps (#315) reuse it.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase (Postgres, pgTAP).

**Spec:** `docs/superpowers/specs/2026-10-13-workflows-events-design.md` (Decisions: Group or individual, Invitation; §1 Event types; §4 Today, Event page, Settings). Figma: [Workflows & events — #313](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=358-8961), frames "Today — new rows" (ActionItem — follow up), "Event — invited / going", "Settings / Event type editor — several people".

## Global Constraints

- One migration, `supabase migration new event_invitations`. Never edit an applied one.
- No new dependency. Stage only changed files by path.
- The 3-day rule lives in Postgres (`follow_up_on`). `test/features/workflows/server_rule.dart` is the only Dart copy, for the fakes.
- Dart: `package:loomia/...` imports; Material from `package:material_ui/material_ui.dart`. Theme values only. `FilledButton.tonal` takes `style: AppTheme.tonal(context)`.
- Async handlers read `ref` / `context` / the `ScaffoldMessenger` before the first `await`.
- Copy: English only, in `lib/l10n/app_en.arb`, every key with a description; `flutter gen-l10n`.
- Quality gate: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`, `supabase test db`. Goldens through CI.
- Branch `feature/314-event-invitations` off `main`; PR body `Closes #314`.

## Rulings made while planning

- **The default for `going` is decided by a trigger, not the client.** The app, `extend_event_series` and `set_series_attendees` all insert attendees, so the rule has one home: `going is null` takes `not is_group` of the event's type, and `true` for a plain event. The column has no default, so a null reaches the trigger. NOT NULL is checked after `before` triggers.
- **Series attendees are going.** They are regulars. Inviting the whole list to a year of generated occurrences would put a follow-up for every week on Today. Both series functions insert `going = true`.
- **Plain updates, no RPCs.** The spec named `set_going` and `follow_up_invite`. The table-level `update` grant and the `event_open` policy already allow exactly these writes, and neither needs a transaction across tables.
- **Going is one way.** The menu offers Going only while invited. A wrong tap is fixed with Remove, then adding them again. Add "Not going yet" if someone asks.
- **No history entry.** Following up writes no activity, and Today's done counter doesn't move: the row leaves, and the bar's total shrinks. Attendance becomes history when the event is marked done.
- **Shown until the event's day ends, not until its start.** Today and `due_people_count` both keep a follow-up while the event's local day is today or later. The push has no clock time, so this is the rule both can apply. Two copies of that filter, Dart and SQL, each pinned by a test.
- **`due_people_count` reads the zone from `notification_settings`** (UTC when there is no row) to put the event on a local day. The sender only claims owners who have a row.
- **`Attendee` becomes a class** with `==`/`hashCode` and defaults (`came: false`, `going: true`). A record would need all six fields in the 15 places that build one. `EventPerson` becomes `({Person person, Attendee attendee})`.
- **The row menu is a `PopupMenuButton`** on every size, like the desktop branch of `contact_details.dart`. A bottom sheet for three items is more than this needs.
- **The stage stays in the subtitle** ("Prospect · going"). `ContactRow` has no chip slot, and adding one is outside this issue.
- **`ActionItem.actions`** is a `List<Widget>?` drawn as a `Wrap` under the text. When given, the ring is not drawn. The follow-up row's buttons are tonal Going, then text Followed up and text Remove, as in Figma.

## Review Focus

1. A new attendee on a group-typed event is invited; on an individual type, a plain event, or through a series, going. Pinned in Task 1.
2. `follow_up_on`: invited_on + 3, then followed_up_on + 3; null once going or once the event is done. Pinned in Task 1; the fake follows in Task 2.
3. Today and the push count the same people for a follow-up, including "event day passed → gone". Pinned in Task 1 (SQL) and Task 5 (`dueToday`).
4. Going / Followed up / Remove on Today each write once and the row leaves. Pinned in Task 5.

---

### Task 1: Migration and pgTAP

**Files:**
- Create: `supabase/migrations/<timestamp>_event_invitations.sql`
- Create: `supabase/tests/event_invitation_test.sql`

- [ ] **Step 1: Failing pgTAP.**

  Fixtures:
  - one owner with `notification_settings` (`time_zone` 'Europe/Paris');
  - event types "Workshop" (`is_group` true) and "Wellness check" (false);
  - a workshop on 2026-10-20 19:00 Paris, a wellness check, a plain event;
  - a weekly series with one attendee, generated with `extend_event_series('2026-10-13')`.

  Cases:
  - insert without `going`: workshop → false, wellness check → true, plain → true;
  - explicit `going = true` on the workshop is kept;
  - `invited_on` set by the insert is kept;
  - generated occurrences' attendees are going;
  - `set_series_attendees` adds them going;
  - `follow_up_on`:
    - invited 2026-10-10, not going → 2026-10-13;
    - `followed_up_on` 2026-10-14 → 2026-10-17;
    - `going` → null;
    - after `mark_event_done` → null;
  - `due_people_count` (as `service_role`):
    - on 10-13, the invited person counts once even with a reminder also due;
    - on 10-12, they don't count;
    - on 10-21, the day after the workshop, they don't count.
- [ ] **Step 2: Migration.**

```sql
alter table public.event_workflow
  add column is_group boolean not null default true;

-- Existing attendees were all going: there was no other state.
alter table public.event_attendee
  add column going boolean not null default true,
  add column invited_on date not null default current_date,
  add column followed_up_on date;
alter table public.event_attendee alter column going drop default;

-- A new attendee on a group type is invited; anywhere else, going. An
-- insert that says which keeps it (the series functions say going).
create function public.event_attendee_going() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if new.going is null then
    new.going := coalesce(
      (select not w.is_group
       from public.event e
       join public.event_workflow w on w.id = e.event_workflow_id
       where e.id = new.event_id),
      true);
  end if;
  return new;
end $$;

create trigger event_attendee_going before insert on public.event_attendee
  for each row execute function public.event_attendee_going();

-- The day to follow up someone not yet going: 3 days after the invite or
-- the last follow-up. Null once going or once the event is done.
-- ponytail: 3 days for every type; a column on event_workflow if one
-- needs another delay.
create function public.follow_up_on(a public.event_attendee) returns date
language sql stable security invoker set search_path = '' as $$
  select coalesce(a.followed_up_on, a.invited_on) + 3
  where not a.going and public.event_open(a.event_id)
$$;
```

  - `extend_event_series` and `set_series_attendees`: `create or replace`, copied from `20261013053701_repeating_events.sql`. Their `insert into public.event_attendee` gains `going` = `true`, and `invited_on` = `p_today` in the first and `current_date` in the second.
  - `due_people_count`: `create or replace` from `20261011162920_daily_summary.sql`, with a third `or exists` on `event_attendee a join event e`: `a.person_id = p.id and public.follow_up_on(a) <= p_on and (e.starts_at at time zone z)::date >= p_on`. Here `z` is `coalesce((select time_zone from public.notification_settings where owner_id = p_owner), 'UTC')`. Update its comment.
  - Grants: `follow_up_on` and the trigger function revoked from `public, anon`, `follow_up_on` granted to `authenticated` (PostgREST selects it). `create or replace` keeps the others.
  - `supabase test db` passes, `schema_rls_test.sql` included.

### Task 2: Models, repositories, fakes

**Files:**
- Modify: `lib/features/calendar/domain/calendar_event.dart`, `lib/features/calendar/data/event_repository.dart`, `lib/features/calendar/presentation/calendar_controller.dart`
- Modify: `lib/features/workflows/domain/event_workflow.dart`, `lib/features/workflows/data/event_workflow_repository.dart`
- Modify: `test/features/workflows/server_rule.dart`, `test/features/calendar/fake_event_repository.dart`, `test/features/workflows/fake_event_workflow_repository.dart`, and every `(personId: …, came: …)` literal (`calendar_preview.dart`, `calendar_controller_test.dart`, `calendar_page_test.dart`, `event_page_test.dart`, `today_preview.dart` and others `flutter analyze` finds)
- Test: `test/features/calendar/data/event_repository_test.dart`, `test/features/calendar/presentation/calendar_controller_test.dart`, `test/features/workflows/data/event_workflow_repository_test.dart`

- [ ] **Step 1: Failing tests.**
  - Row mapping reads `going`, `invited_on`, `followed_up_on`, `follow_up_on` (dates as local midnights, nulls kept), and `is_group` (missing → true).
  - Controller:
    - `invite('e1', ['p1'], day)` records the day;
    - `setGoing('e1', 'p1')` leaves `p1` going, with no follow-up day;
    - `followedUp('e1', 'p1', day)` moves the follow-up day to day + 3;
    - on a series occurrence, `invite` still goes through `setSeriesPeople`.
- [ ] **Step 2: Model.** `Attendee` becomes a class:
  - fields:
    - `personId`;
    - `came` (false);
    - `going` (true);
    - `invitedOn` (`DateTime?`);
    - `followedUpOn` (`DateTime?`);
    - `followUpOn` (`DateTime?`, doc: "The server's `follow_up_on`: when to follow up someone not yet going; null once going or done.");
  - `==` and `hashCode` over all six fields, and a `toString` for test failures;
  - `CalendarEvent` gains `int get goingCount`;
  - `EventWorkflow` gains `final bool isGroup` (default true, doc: "Several people per event: people added start invited.").
- [ ] **Step 3: Repositories.**
  - `_columns` embeds `event_attendee(person_id, came, going, invited_on, followed_up_on, follow_up_on)`. `eventFromRow` maps them with `DateTime.parse`, as `stepsDone` does.
  - `invite(eventId, personIds, DateTime on)` sends `invited_on: dayColumn(on)` and no `going`.
  - `setGoing(eventId, personId)` updates `{'going': true}`.
  - `followedUp(eventId, personId, DateTime on)` updates `{'followed_up_on': dayColumn(on)}`.
  - Each filters on both keys and is wrapped in `guardPeople`.
  - `EventWorkflowRepository.setGroup(String id, bool on)` mirrors `rename`. `eventWorkflowFromRow` reads `row['is_group'] as bool? ?? true`.
- [ ] **Step 4: Controller.** `EventsController.invite(eventId, personIds, on)` passes `on` to `invite`; the series branch is unchanged. `setGoing(eventId, personId)` and `followedUp(eventId, personId, on)` call the repository, then `_reload()`, like `tick`. Update `_invite` in `event_page.dart` to pass `today()`.
- [ ] **Step 5: Fakes.**
  - `server_rule.dart` gains `DateTime? followUpOn(Attendee attendee, {required bool done})`: `null` when going or done, else `addDays(followedUpOn ?? invitedOn!, 3)`. Doc it as the Dart copy of `follow_up_on`.
  - The fake event repository:
    - stores `going` on invite as the trigger would (`isGroup` of the event's type from an injected list, true when absent), plus `invitedOn`;
    - implements `setGoing` and `followedUp`;
    - recomputes `followUpOn` through `followUpOn(...)` on every write.
  - The fake event workflow repository gains `setGroup`.

### Task 3: Event page

**Files:**
- Modify: `lib/features/calendar/presentation/event_page.dart`, `who_was_there_sheet.dart`, `calendar_preview.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/calendar/presentation/event_page_test.dart`

- [ ] **Step 1: Failing widget tests.**
  - Before done:
    - a going attendee reads "Prospect · going";
    - an invited one reads "Prospect · invited Oct 1";
    - one followed up reads "Prospect · invited Oct 1 · followed up Oct 5".
  - The row menu (tooltip "More for Claire"):
    - shows Going, Followed up and Remove from the event while invited, and only Remove from the event while going;
    - each item calls `onGoing`, `onFollowedUp` or `onRemove` with the person.
  - With someone invited, the People header reads "People · 5 · 2 going".
  - Done: unchanged ("was there" / "missed", no menu).
- [ ] **Step 2: Copy.**
  - `eventPersonGoing` ({stage});
  - `eventPersonInvitedOn` ({stage}, {invited} as DateTime `MMMd`);
  - `eventPersonFollowedUp` ({stage}, {invited}, {followed} as `MMMd`);
  - `eventPersonMore` ({name});
  - `eventGoing` "Going";
  - `eventFollowedUp` "Followed up";
  - `eventRemoveFromEvent` "Remove from the event";
  - `eventPeopleGoing` ({count}, {going}) "People · {count} · {going} going".

  Each key is described. `eventPersonInvited` stays for a row with no invite day, i.e. the old rows' fallback; delete it if nothing uses it after this task. `flutter gen-l10n`.
- [ ] **Step 3: View.**
  - `EventPerson` is `({Person person, Attendee attendee})`; `eventPeople` fills it.
  - `EventView`:
    - gains `onGoing` and `onFollowedUp` (`void Function(Person)`);
    - the trailing `IconButton` becomes a `PopupMenuButton<VoidCallback>` with the items above;
    - `_status` follows the copy;
    - the header uses `eventPeopleGoing` when someone is not going and the event is not done.
  - `EventPane` wires `onGoing` / `onFollowedUp` to the controller with `today()`, through the same SnackBar-on-`PeopleFailure` pattern as `_uninvite`.
  - `who_was_there_sheet.dart` reads `attendee` in its three destructures.
  - The 'Event — light' preview gets one invited and one followed-up attendee.

### Task 4: Event type editor

**Files:**
- Modify: `lib/features/workflows/presentation/event_workflow_editor.dart`, `workflows_preview.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/workflows/presentation/event_workflow_editor_test.dart`

- [ ] **Step 1: Failing widget test.** "Several people" is on for a group type. Turning it off calls `onGroup(false)`, and it is disabled while saving.
- [ ] **Step 2: Copy.** `eventWorkflowGroup` "Several people" and `eventWorkflowGroupNote` "On: people you add start as invited, and Today reminds you to follow up." (#315 extends it with planning). Both described.
- [ ] **Step 3:** `_Control.group`, plus `EventWorkflowEditorView.onGroup` (`Future<void> Function(bool)`). After the steps group: `SettingsGroup([SwitchListTile(value: workflow.isGroup, title: …, onChanged: busy ? null : (on) => _run(_Control.group, () => widget.onGroup(on)))])`, then the note in `bodySmall` / `onSurfaceVariant`. `EventWorkflowEditor` wires `repository.setGroup`.

### Task 5: Today

**Files:**
- Modify: `lib/core/ui/action_item.dart`
- Modify: `lib/features/today/domain/due.dart`, `lib/features/today/presentation/today_page.dart`, `today_preview.dart`
- Modify: `lib/l10n/app_en.arb`
- Test: `test/features/today/domain/due_test.dart`, `test/features/today/today_page_test.dart`, `test/core/ui/action_item_test.dart` (create if absent)

- [ ] **Step 1: Failing tests.**
  - `dueToday(people, workflows, events, today)`:
    - an invited attendee whose `followUpOn` is today or earlier yields one `DueFollowUp`, keyed `'<event>:<person>'`;
    - one whose day is tomorrow does not;
    - none once the event's day is before today;
    - none for a person not in the book;
    - the same day, ordering is the person's reminders, then the follow-up, then the step.
  - `ActionItem` with `actions` shows them and no ring.
  - Today page:
    - the row reads "Follow up Marc about Huiles et sommeil · Tue";
    - Going calls `setGoing`, Followed up calls `followedUp` with today, Remove calls `uninvite`; each makes the row leave;
    - a `PeopleFailure` shows the SnackBar and keeps the row;
    - the headline counts Marc once alongside his reminder.
- [ ] **Step 2: Copy.** `todayFollowUp` "Follow up {name} about {event} · {day}" (`day` as DateTime `E`, like `todayStepFor`) and `todayRemoveInvite` "Remove", both described. Going and Followed up reuse `eventGoing` / `eventFollowedUp`.
- [ ] **Step 3: `ActionItem.actions`.** A `List<Widget>?` field, doc: "Buttons under the text, for an item resolved more than one way; replaces the ring." Rendered as `Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: actions)` after the chip, with `AppSpacing.sm` above. The ring is drawn only when `actions == null`.
- [ ] **Step 4: Domain.**
  - `final class DueFollowUp extends Due` holds the `CalendarEvent` and the `Attendee`. `day` is `attendee.followUpOn!` and `key` is `'${event.id}:${person.id}'`.
  - `dueToday` gains `List<CalendarEvent> events`. For each not-done event whose `day` is not before `today`, it adds every attendee with `followUpOn` on or before `today` whose person is in `people`.
  - The sort's tie-break switch ranks reminder < follow-up < step.
  - Update the doc comment.
- [ ] **Step 5: Page.**
  - `build` passes `calendarEvents.value ?? const []` to `dueToday`. Events are optional for the rows: a failed events load hides follow-ups, not the list.
  - `_row` maps `DueFollowUp` to `ActionItem` with:
    - `reason: l10n.todayFollowUp(firstName(person), event.title, event.startsAt)`, no detail;
    - `actions`: `FilledButton.tonal(style: AppTheme.tonal(context))` Going, then `TextButton` Followed up and `TextButton` Remove;
    - each disabled while `busy.contains(key)`.
  - `TodayView` gains `onGoing`, `onFollowedUp` and `onRemoveInvite` (`void Function(DueFollowUp)`).
  - `_TodayPageState` handles them with one helper: add the key to `_busy`, call the controller (`setGoing` / `followedUp(…, today())` / `uninvite`), SnackBar on `PeopleFailure`, then drop the key.
  - `_tick`'s switch gets `DueFollowUp() => throw StateError('no ring')`. The row has no ring, so this is unreachable.
  - `today_preview.dart`: the mobile and desktop samples gain one follow-up.

### Task 6: Gate

- [ ] `dart format .`, `flutter analyze`, `flutter test`, `supabase test db`; `graphify update .`.
- [ ] Push, regenerate goldens through CI (changed: `today_*`, `event_mobile_light`, `event_workflow_editor_light`), open the PNGs, commit them.
- [ ] PR `feat(calendar): invitations on group events`, body `Closes #314`, Figma frames linked.

## Found while implementing

