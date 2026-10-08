# Reminders — design

Issue: #217. Figma: [Reminders — #217](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=273-5276),
on page "04 — Screens (Light)": Next step with reminders (273:5278), Today
(273:5371), Remind me (274:5464), Edit reminder (274:5646), Log something
with Remind me on (274:5832) and off (274:6013).

## Intent

Not everything a user owes a person fits a workflow. They call Marie, she asks
to be called back in a week; they promise Lucas the price list. A reminder is
that promise written down: a line of text, for one person, due on a day. It
sits with the workflow step under Next step on the contact page and, once due,
in Today's Priority. Ticking it records what was done in the history, like a
step.

A reminder is the "real date" design principle #4 talks about: the user set
it, so it earns its place on Today.

## Decisions

| Question | Decision |
| --- | --- |
| What a reminder is | Text (non-blank) and a due day, for one person. Several open at once per person. No time of day, no repeat. |
| Workflow | None. A reminder neither moves nor ticks a step, and a step does not touch reminders. |
| Pause | Stops the workflow only. A paused person's reminders still show, on the contact page and on Today. |
| Done | Ticking writes a history entry, kind `reminder`, with the reminder's text, on the day ticked, then deletes the reminder. One transaction. It counts as contact (`last_contact_on`), so a quiet team member called back leaves Worth a check-in. |
| Undo | None, like a step. The history entry can be deleted from the history. |
| Where it is stored | Its own table, embedded in the book's select (`reminder(...)` on `person`, like `event_step_done` on `event`). Today and the contact page read the same people; one refresh covers both. No new provider. |
| Due rule | The column itself. Nothing to compute, so no server function and nothing in `server_rule.dart`. |
| Today | Due reminders (due today or earlier) join Priority, mixed with workflow steps, in the same cap and Show more. Not a section of their own. |
| Today's headline | Still counts people: someone with a step and a reminder due is one person worth a message. |
| Late | On Today, the same accent `DateChip` as a late step. On the contact page, no chip: the reason already reads "2 days late", as on the step card. Never red. |
| Creating one | "Add a reminder" in Next step, and an optional Remind me in Log something. |
| Log something + Remind me | One RPC writes the entry and the reminder together, so a failure leaves neither and a retry cannot duplicate the entry. Without Remind me, the sheet writes as today. |
| Picking the day | Chips Tomorrow · In 3 days · In a week · In 2 weeks, then Pick a day (`pickDay`, from today); the day picked written under them. Labelled "When" in the reminder sheet, "Remind me on" in Log something, which already has a When. |
| Naming | "Reminder" in the UI (design principles: "Reminders are offers"). Code in `contacts/`, next to the book that carries it (decided while planning): a feature folder would hold one type and one sheet. |
| Push | Later, with FCM, from the same `due_on` column. |

## 1. Data

`supabase migration new reminders`.

`activity_kind` gains `'reminder'`. The `stage_entry_shape` check already
requires text on non-stage entries.

### `reminder`

| Column | Type | Note |
| --- | --- | --- |
| `id` | uuid | `default gen_random_uuid()` |
| `owner_id` | uuid | the usual default and FK |
| `person_id` | uuid not null | FK `(person_id, owner_id)` → `person (id, owner_id)`, on delete cascade |
| `text` | text not null | `check (length(trim(text)) > 0)` |
| `due_on` | date not null | |
| `created_at`, `updated_at` | timestamptz | `set_updated_at` trigger |

Index on `person_id`. RLS with the four owner policies, `revoke all` from
`anon, authenticated`, then grant select, insert, delete, and
`update (text, due_on)` to `authenticated`. A pgTAP test in
`supabase/tests/reminders_test.sql`.

### `complete_reminder(p_reminder uuid, p_on date) returns person`

`security invoker`, `search_path = ''`, executable by `authenticated` only.
Locks the reminder; not found (another owner's, or already ticked on another
device): raise `P0002`. Inserts the `'reminder'` activity with the text on
`p_on`, deletes the reminder, returns the person row, so the client selects it
with the book's columns and replaces the person.

### `log_with_reminder(p_person uuid, p_kind activity_kind, p_text text, p_on date, p_amount numeric, p_remind text, p_remind_on date) returns void`

Same security. Inserts the activity as the Log sheet does today, then the
reminder. RLS and the table checks refuse a bad kind, blank text or another
owner's person; anything refused rolls both back.

### Client

`PeopleRepository._columns` gains `reminder(id, text, due_on)`. `Person` gains
`reminders: List<Reminder>`, sorted by `due_on` then `created_at`, and
`withReminders(...)` next to `withStatus`. `Reminder` is
`({String id, String text, DateTime dueOn})`, in `person.dart`.

`PeopleRepository` gains `addReminder`, `updateReminder`, `deleteReminder`
on the table and `completeReminder` (the RPC, returns the person).
`ActivityRepository` gains `addWithReminder` (`log_with_reminder`). All
through `guardPeople`.

The writes go through `PeopleController` (it owns the book): add, edit and
delete swap the person's reminders with `withReminders`; complete replaces the
person and invalidates `historyProvider(person.id)`; Log with reminder
reloads the person's history and the book, as `HistoryController.add` does.

## 2. Domain

`lib/features/today/domain/due.dart` grows to both kinds:

```dart
sealed class Due { Person get person; DateTime get day; String get key; }
final class DueStep implements Due { /* person, OnStep step */ }
final class DueReminder implements Due { /* person, Reminder reminder */ }
```

`dueToday(people, workflows, today)` returns steps and reminders due on or
before `today`, sorted by day, then name, then reminders before the step on
the same day and person. `key` is the step or reminder id: Today's slots are
keyed by it instead of the person id, since one person can now have two rows.

## 3. Contact page — Next step

Top to bottom, inside the section:

1. **Reminders**, soonest first: `ActionItem` rows, title the text, reason
   the due label (`dueLabel`, "2 days late" when past, no chip), the resolve
   ring. A tap opens the reminder sheet to edit.
2. **The workflow card**, unchanged in each of its states. With no workflow
   and at least one reminder, its body reads "No workflow" instead of
   "Nothing planned".
3. **Add a reminder**, a text button, in every state, also while the
   workflows load.

Reminders show while paused, above the Paused card.

### Reminder sheet

`LoomiaDialog`: a sheet on mobile, a dialog elsewhere. Title "Remind me" (new)
or "Edit reminder". Fields: What (required, multi-line), When (the day chips,
then Pick a day; the picked day shown under them). Actions: Cancel, Save;
editing also has Delete, no confirm (the reminder is one line, re-typed in
seconds). Failures show in the sheet with `FormError`, as Log something does.

## 4. Log something — Remind me

Under What, a `SwitchListTile` "Remind me", off by default; on, its fields
are labelled "Remind me on" and "Reminder"; not shown when
editing an entry or logging an own order. On: the When chips (In a week
preselected) and a What field prefilled from the kind: a call, "Call {name}
back"; anything else, "Follow up with {name}". Save writes through
`log_with_reminder`.

## 5. Today

Priority rows are `Due`s. A step row is unchanged. A reminder row:
`ActionItem(name: person.name, reason: "{text} · Reminder", chip: late ?
DateChip(dueLabel) : null)`, the ring completes it, the row opens the person.
The busy set holds row keys, not person ids, so ticking a person's step leaves
their reminder's ring live.

## 6. Delivery

| PR | Scope |
| --- | --- |
| #218 | Migration (`reminder`, `complete_reminder`, the `'reminder'` kind), the book's select, the contact page section and sheet, Today's mixed Priority. |
| #219 | `log_with_reminder` and Remind me in Log something. |


## 7. Testing

- SQL: `reminders_test.sql`: RLS (another owner's reminder is invisible, not
  insertable on another owner's person); `complete_reminder` writes the entry
  and deletes the reminder, refuses a reminder already gone, moves
  `last_contact_on`; `log_with_reminder` writes both, and neither when the
  reminder text is blank. `schema_rls_test.sql` covers the table.
- Unit: `dueToday` with steps and reminders mixed (order, a paused person's
  reminder kept, a future one left out, two rows for one person).
- Widget: Next step with reminders in each workflow state; add, edit, delete
  and tick through the sheet; Today with a step and a reminder for the same
  person, ticking one leaves the other; Log something with Remind me on and
  off.
- Goldens: the `NextStepCard` and Today previews gain a reminder; regenerated
  through CI.

## Out of scope

Push notifications, times of day, repeating reminders, undo, reminders that
belong to no person, a list of all reminders.
