# Invite people when creating an event — design

Issue: [#446](https://github.com/paulthvt/loomia/issues/446). Builds on the
calendar (`2026-10-07-calendar-design.md`) and Plan on an event step (#315).

## Intent

Today, inviting people takes two steps: create the event, then open it and
use Add people. The New event form should take the people too, so one Save
creates the event with them in it.

No Figma mockup: the field is made of existing parts (a `LabeledField`,
Material `InputChip`s like the task sheet's time chip, `PhotoAvatar`, and
the existing people picker).

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| New events only, or editing too? | New events only. | The event page's People section already edits who is invited, with going / followed up and the occurrence scope. Two places to edit the same list would disagree. |
| How does it look? | A **People** field under the repeat rule: one chip per person (avatar, name, ×), then an **Add people** chip that opens the people picker. | Reuses the picker and the chip pattern of the task sheet; no new component. |
| A new repeating event? | The people join the whole series (`set_series_attendees` on the first occurrence). | Same as "This and following events" on the event page: a series is created to repeat with the same people. |
| One write or two? | Two: the event, then the people. If the second fails, the event stays, the form closes, and a snackbar says the people were not added. | Plan on an event step already works this way. One RPC is a new Postgres function for a rare failure. |
| Plan on an event step | The form opens with that person already picked; others can be added before Save. Plan stops inviting on its own after the form. | One flow for "an event with people", and Plan gains several people at once. Joining an existing group event is unchanged. |
| The book after inviting | Reloads when someone was invited. | An event step waits once its person is invited to an event of that type; the contact and Today rows must say so. |
| Database | No change. | `event_attendee` insert and `set_series_attendees` exist. No `supabase db push`. |

## Behaviour

- New event: People shows "Add people". Picking adds chips, sorted as
  picked; the picker hides who is already picked. × removes a chip.
- Save with nobody picked behaves as today.
- Save with people: the event saves, then they are invited on today's date.
  Going or not is the server's, as on the event page.
- Edit event: no People field.
- Plan (one person per event, or New on a group event): the form opens
  prefilled, the person's chip shown.
