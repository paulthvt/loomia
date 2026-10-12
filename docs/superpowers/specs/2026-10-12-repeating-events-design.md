# Repeating events — design

Epic: #297 (sub-issues #298, #299). Figma: section "Repeating events —
#297" on page "04 — Screens (Light)", **to be mocked before planning**: the
Repeat and Ends fields in New event, the repeat line on the event, the
"This event / This and following events" dialog. Builds on
`2026-10-07-calendar-design.md`, whose "No recurrence" this replaces.

## Intent

A group call with the team every Tuesday at 19:00 is one moment with many
people, on a fixed weekday. Today the user creates it again each week. A
repeating event is written once and shows up every week on the calendar and
on Today, with its Join link and, when it has a type, its checklist.

A regular check-in with one person is a repeating workflow, not an event
(`2026-10-12-repeating-workflows-design.md`).

## Decisions

| Question | Decision |
| --- | --- |
| What an occurrence is | A real `event` row. People, Join, the checklist, Mark who was there and Today work on it unchanged; nothing in #150 learns about rules. |
| The rule | Every 1, 2 or 4 weeks, on the first day's weekday, at a local time in an IANA zone, forever or until a day. No monthly ("first Tuesday"), no daily, no count. Add them when asked. |
| Where the rule lives | `event_series`: the rule and the template (title, times, place, link, notes, event workflow, mapping), plus `event_series_attendee` for its people. |
| Generating occurrences | `extend_event_series(p_today)`, in Postgres: inserts each series' occurrences up to a year after `p_today`, from where it stopped last time (`generated_until`). `EventRepository.list` calls it before reading. Idempotent: `unique (series_id, series_on)`, series rows locked. |
| Forever | A rolling year. `ponytail:` the calendar shows nothing past a year ahead; extend to the month shown if someone browses that far. |
| Time and DST | Each start is `(day + local time) at time zone series.time_zone`, so 19:00 stays 19:00 across a clock change. The zone is the device's when the series is created (`flutter_timezone`, already used by push), checked by the existing `check_time_zone` trigger. |
| Deleting one occurrence | Deletes the row. It does not come back: generation only moves forward from `generated_until`. |
| Changing one, or the rest | Every edit, delete, add or remove of people on an occurrence asks "This event" or "This and following events". The pattern people know from their phone's calendar. |
| This event | Changes the row only. It stays in the series and is never regenerated. |
| This and following | Updates the series and every **not done** occurrence from this one on, in place: their ticks and people are kept. A new rule (weeks, day, end) deletes the not done occurrences from this one on and generates them again from this occurrence's new day. |
| Done occurrences | Never changed or deleted by a series change. Their attendance is history. |
| Ending a series | Delete → This and following: `until_on` the day before, not done occurrences from here deleted. From the first occurrence, the series row goes too; done occurrences stay, without a series. |
| Making an event repeat later | Edit a single event, set Repeat: it becomes the first occurrence of a new series, its people copied to the series. |
| People | New occurrences are invited from `event_series_attendee`. |
| After the event (mapping) | Copied to every occurrence like the other fields. A weekly team call has no type (#300), so nothing to start and Today does not ask who came. |
| Today, "How did it go?" | Only a series' latest past occurrence that is not done, among the events #300 asks about (those with a mapping). One row per series, not one per missed week. |
| Calendar row | Unchanged. The event page says how it repeats. |

## 1. Data

`supabase migration new repeating_events`. Conventions as in the calendar
spec: `owner_id` default and FK, timestamps and `set_updated_at`, RLS with
owner policies for each granted command, `revoke all ... from anon,
authenticated` then explicit grants, composite `(id, owner_id)` FKs.

### `event_series`

| Column | Type | Note |
| --- | --- | --- |
| `id` | uuid | `unique (id, owner_id)` |
| `title` | text not null | non-blank |
| `first_on` | date not null | the first occurrence's day; its weekday is the rule's |
| `starts_time` | time not null | local wall clock |
| `minutes` | int | `check (minutes > 0)`; null: no end time |
| `time_zone` | text not null | IANA name, `check_time_zone` trigger |
| `every_weeks` | smallint not null | `check (every_weeks in (1, 2, 4))` |
| `until_on` | date | `check (until_on is null or until_on >= first_on)` |
| `generated_until` | date | last day generated; null: none yet, read as `first_on - 1` |
| `place`, `link`, `notes` | text | same checks as `event` |
| `event_workflow_id`, `prospect_workflow_id`, `customer_workflow_id`, `team_workflow_id` | uuid | same FKs and `on delete set null` as `event` |

Grants: select, insert, update, delete.

### `event_series_attendee`

`series_id` (FK `event_series`, cascade), `person_id` (FK `person`,
cascade), primary key `(series_id, person_id)`. Grants: select, insert,
delete.

### `event`

Gains `series_id uuid` (FK `(series_id, owner_id)` → `event_series`,
`on delete set null (series_id)`) and `series_on date`: the day the rule
gave it, kept when "This event" moves it. Unique index
`(series_id, series_on) where series_id is not null`. Index on
`(series_id, owner_id)` for the FK.

### Functions

All `security invoker`, `search_path = ''`, executable by `authenticated`
only.

- `extend_event_series(p_today date) returns void`. For each series (RLS
  scopes them to the caller) where `coalesce(generated_until, first_on - 1)
  < least(p_today + 365, coalesce(until_on, 'infinity'))`, `for update`:
  inserts an `event` for each day `first_on + 7 * every_weeks * k` after it,
  up to
  that bound, the template copied, `starts_at` as above, `ends_at =
  starts_at + minutes`, its attendees from `event_series_attendee`, `on
  conflict do nothing`; then moves `generated_until`.
- `repeat_event(p_event uuid, p_every_weeks smallint, p_until date,
  p_time_zone text) returns event_series` (#299). Refuses an event already
  in a series or done. Creates the series from the event, copies its
  people, links the event as the first occurrence.
- `update_event_series(p_event uuid, <template fields>, p_every_weeks,
  p_until, p_first_on, p_today) returns void` (#299). The event must be an
  occurrence (`P0002` otherwise). Updates the series template. Same rule:
  updates the not done occurrences with `series_on >= ` this one's in place.
  New rule or day: deletes them, sets `first_on = p_first_on`,
  `generated_until = p_first_on - 1`, then `extend_event_series(p_today)`.
- `end_event_series(p_event uuid) returns void` (#299). `until_on =
  series_on - 1`, deletes the not done occurrences from this one on; when
  `until_on < first_on`, deletes the series.
- `set_series_attendees(p_event uuid, p_add uuid[], p_remove uuid[])
  returns void` (#299). Updates `event_series_attendee` and the not done
  occurrences from this one on.

A pgTAP file, `supabase/tests/event_series_test.sql`.

### Client

`CalendarEvent` gains `series` (`EventSeries?`: id, `everyWeeks`,
`untilOn`), read through the event's select (`event_series(id,
every_weeks, until_on)`). `EventRepository` gains `createSeries` (insert the
series and its people, then list), and the four RPCs for #299; `list` calls
`extend_event_series` with the device's today first. All through
`guardPeople`, as the rest of the calendar.

## 2. Domain

`lib/features/calendar/domain/`:

- `repeatLine(EventSeries series, DateTime firstDay)`: "Every week on
  Tuesday", "Every 2 weeks on Tuesday · until December 15", for the event
  page and the form.

`lib/features/today/domain/today_events.dart`: `toMark` keeps, per
`series.id`, only the latest occurrence. Events without a series are
unchanged.

The rule itself is not in Dart: occurrences come from Postgres.

## 3. Screens

### New / edit event

Under the date and times:

- **Repeat**: Doesn't repeat · Every week · Every 2 weeks · Every 4 weeks,
  the weekday named from the date ("Every week on Tuesday").
- **Ends**, only when it repeats: Never · On a day (the platform date
  picker, from the first day).

On an occurrence, Save asks the scope (below); a new rule or day is only
offered for "This and following" (the radio "This event" is disabled when
the rule changed). On a single event, setting Repeat calls `repeat_event`.

### Scope dialog

`LoomiaDialog`: title "Change a repeating event" / "Delete a repeating
event", radios "This event" (default) and "This and following events",
Cancel and the action. Used by Save, Delete and the People section's Add
people and Remove. Delete confirms in the same dialog, no second confirm.

### Event

Under the date line, `repeatLine`. Done occurrences show no scope dialog:
they are read-only as today.

### Copy

New `app_en.arb` keys, each with a description: the Repeat and Ends
labels and choices, the repeat line, the dialog's titles and radios.

## 4. Today

Unchanged apart from `toMark` (one per series). Today's events and
checklist steps come from the occurrences like any event.

## 5. Navigation

None. No new route: an occurrence opens at `/calendar/:id`.

## 6. Delivery

| PR | Scope |
| --- | --- |
| #298 | Migration (`event_series`, `event_series_attendee`, the `event` columns, `extend_event_series`), Repeat and Ends on New event, `list` extending, the repeat line, Today's one per series. Edits and deletes on an occurrence change that occurrence only. |
| #299 | `repeat_event`, `update_event_series`, `end_event_series`, `set_series_attendees`, the scope dialog on edit, delete and people. |

## 7. Testing

- SQL (`event_series_test.sql`): RLS on both tables; `extend_event_series`
  generates every 1, 2 and 4 weeks, stops at `until_on` and at a year,
  twice in a row adds nothing, a deleted occurrence is not regenerated, a
  DST week keeps the local time (Europe/Paris, last Sunday of October),
  people are copied. #299: `update_event_series` in place keeps ticks and
  people, a new rule regenerates and never touches a done occurrence;
  `end_event_series` from the middle and from the first;
  `set_series_attendees`; `repeat_event` refuses a done event.
  `schema_rls_test.sql` covers the tables.
- Unit: `repeatLine`; `todayEvents` with three past occurrences of one
  series (only the latest to mark) and a single event.
- Widget: New event with Repeat and Ends; the event page's repeat line; the
  scope dialog on Save, Delete and Remove; "This event" disabled on a rule
  change.
- Goldens: one per new `@Preview` (the form with Repeat on, the dialog),
  regenerated through CI.

## Out of scope

Monthly and daily rules, a count of occurrences, exceptions other than
editing or deleting an occurrence, a series list, export to the device
calendar (#155).
