# Plain events — design

Issue: #300. No Figma section: one more chip in the existing Type row.
Supersedes, in `2026-10-07-calendar-design.md`, "Event workflow (chips,
required from #153, sets the title)" and "coming does [write history]" as
far as contact is concerned. Comes before #298.

## Intent

Not every event is a workshop that hands people on to a workflow. A weekly
team call is a time, a link and the people on it: no checklist, nothing to
start afterwards, and no reason for Today to ask who came.

## Decisions

| Question | Decision |
| --- | --- |
| Type on a new event | Optional. A **None** chip first in the Type row, selected by default. The form no longer picks the first event workflow. |
| An event with no type | No checklist, no After the event block (already hidden without a type or a mapping). |
| Changing to None | Clears the event workflow and the copied mapping. |
| Today's "How did it go?" | Only for an event that maps at least one stage to a workflow: marking it is what starts them. Others are not asked about. |
| Mark who was there | Unchanged on the event page, for any event with people, once started. |
| Is being there contact | No. `last_contact_on` ignores `event` entries: being at a group event is not a conversation, so Worth a check-in still flags someone you only saw on a call. The entry stays in their history. |

## 1. Data

`supabase migration new plain_events`. `last_contact_on` replaced:

```sql
create or replace function public.last_contact_on(p public.person) returns date
language sql stable security invoker set search_path = '' as $$
  select max(a.happened_on) from public.activity a
  where a.person_id = p.id and a.kind not in ('stage', 'event')
$$;
```

Grants unchanged (`create or replace` keeps them).

## 2. Domain

`lib/features/today/domain/today_events.dart`: `toMark` keeps only events
whose `followUps` is not empty. `CalendarEvent.canMarkDone` is unchanged:
the event page still offers it.

## 3. Screens

`event_form.dart`: the Type row gains a `ChoiceChip` "None"
(`eventTypeNone`, new `app_en.arb` key with a description) before the event
workflows, selected when `_eventWorkflowId` is null; selecting it clears
the event workflow and `_followUps`. The `listenManual` that picks the
first event workflow goes. The row shows whenever event workflows exist,
as today.

## 4. Delivery

One PR for #300.

## 5. Testing

- SQL (`last_contact_test.sql`): an `event` entry does not move
  `last_contact_on`; a call after it does.
- Unit: `todayEvents` leaves out a past event with people and no mapping,
  keeps one with a mapping.
- Widget: New event opens with None selected and saves without an event
  workflow; picking a type then None clears the After the event block.
- Goldens: the event form preview, if its default changed, regenerated
  through CI.
