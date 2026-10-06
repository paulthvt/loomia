# Edit history entries — design

Date: 2026-10-06. Issue: #187, follow-up to #179 (#184).

## Why

The only way to fix a history entry today is to delete it and log it again.
Separately, #184 made a person's "since" editable, but the history entry for
that stage change keeps its original date, so the two can disagree.

## What can be edited

| Kind | Editable | Through |
| --- | --- | --- |
| Note, call, message, meeting | text, day | the activity row |
| Order | text, day, amount | the activity row |
| Step | text, day | the activity row |
| The latest stage entry | day only | the person's `stage_since` |
| Older stage entries | nothing | — |

Kind, person and stage never change. A step entry's new day doesn't move
the next step: what comes next follows `person.last_tick`, not the history.

## Database (one migration)

- **Update on `activity`:** a policy `activity_update_own`, for the owner and
  `kind <> 'stage'` in both `using` and `with check`. The grant is
  column-level: `grant update (text, happened_on, amount)`. The existing
  `stage_entry_shape` / order constraints keep applying, so an edit can't
  produce what an insert couldn't.
- **The stage entry follows "since":** an `after update of stage_since`
  trigger on `person`, only when the stage itself didn't change (a stage
  change already writes its own entry with `now()`). It moves the latest
  stage entry's `created_at` to the new `stage_since`. It runs as
  `security definer`, like `person_stage_changed`, because stage entries are
  never writable by the app.
- **Why `created_at`:** a stage entry's day is already the local day of its
  `created_at` (`Activity.day`), and goals already count stage entries by
  `created_at` against device-local bounds. Moving it moves both, with no
  change to `month_progress`. For a stage entry, `created_at` means "when
  the stage began"; the migration comment says so.
- **Closed months:** unchanged. `month_plan` actuals are frozen at close, so
  an edit only affects open months.
- **Last contact:** computed from `happened_on`, so it follows edits as it
  stands.

## App

- **`ActivityRepository.update(Activity activity, ActivityDraft draft)`:**
  writes `text`, `happened_on` and `amount` only (same normalisation as
  `activityDraftToRow`) and returns the row.
- **`HistoryController.edit(Activity, ActivityDraft)`:** waits for the
  server like `add`, replaces the entry, reloads the book (last contact).
- **A stage entry's day** saves through `PeopleController.save(person,
  stageSince: day)` from #184, then invalidates the history so the moved
  entry is re-read.
- **The sheet:** `showEditActivity(context, person, activity)` reuses
  `_LogActivityForm`, prefilled.
  - Title "Edit", no kind chips.
  - A stage entry shows the When field only. Its picker runs from the
    previous stage entry's day (none if there isn't one) to today.
  - Actions are Cancel and Save, plus Delete for anything but a stage entry.
    Delete confirms the way long-press does, then closes the sheet.
- **History section:** tapping an entry opens the sheet. Long-press and
  right-click still delete. Older stage entries aren't tappable.
- **Copy:** EN keys only, with descriptions (title "Edit", plus the
  screen-reader action if needed).

## Known ceilings

- The edit form's "since" field (#184) has no lower bound. Moving "since"
  before an earlier stage entry leaves the history out of order. Only the
  history sheet is bounded.
- Own orders on the Goals page aren't editable yet. The same sheet fits
  when someone asks.

## Tests

- **SQL** (`edit_history_test.sql`):
  - an owner edits text, day and amount;
  - kind, person and stage can't be updated (column grant);
  - stage entries can't be updated directly;
  - another user can't update the entry;
  - editing `stage_since` moves the latest stage entry only, and
    `month_progress` follows it;
  - a stage change still writes `now()`.
- **Dart:**
  - repository row mapping;
  - `HistoryController.edit` (replace, failure leaves the list);
  - widget tests for editing a note, an order amount, a stage entry's day
    (saves since, history re-read), Delete from the sheet, and an older
    stage entry not opening.
