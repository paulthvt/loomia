# Catch up — design

Issue: [#342](https://github.com/paulthvt/loomia/issues/342). Figma: section
"Catch up — #342" (node 386:12036) on page "04 — Screens (Light)". Revises the check-in
rules of `2026-09-30-team-tab-design.md` (#103) and Today's third block in
`2026-10-07-calendar-design.md` §4.

## Intent

Feedback from a team leader after her first import: her whole team landed in
WORTH A CHECK-IN at once. People who were on her team long before Loomia
have nothing logged, so the app read them as quiet (or, imported "since
today", as new). The section is a nudge, not a to-do list: it should wait
until Loomia has had a month to learn the relationship, speak up after a
month of silence rather than two weeks, and on a phone stay out of the way of
Priority until asked.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Name | EN "Catch up", FR « Prendre des nouvelles » (set by hand, see Copy). | « Prendre des nouvelles » is asking how someone is doing; "Catch up" is the English idiom for it and stays short in capitals. "Worth a check-in" read as a task. |
| After an import | Grace month: someone added to Loomia less than 30 days ago is not shown. | Loomia knows nothing about them yet; silence in the app is not silence in life. Counted from `person.created_at`, which an import never backdates. |
| Grace exception | **New** still shows during the grace month, but only for someone who reached Team inside Loomia: `stageSince` after `createdAt` (moved from Prospect or Customer). | That is the one case where the app saw them join. Someone added straight onto the team, by import or by hand, is the existing team; a recruit added directly as Team on day one loses New. Accepted: the common path is a prospect becoming team. |
| Quiet threshold | 30 days, was 14. | Her ask: a month without contact. |
| Quiet counted from | The last contact; when nothing was ever logged, the later of the joining day and the day they were added. | An import backdated to 2019 must not say "Quiet 80 months" or "joined on March 4" (no year). |
| Chip | Whole months: "Quiet a month", "Quiet 2 months" (`days ~/ 30`). | The threshold is a month; "Quiet 4 weeks" reads oddly next to it. |
| Mobile and tablet | Collapsed by default: the header with **Show**, and one summary line (avatar group and "4 people you could catch up with"). Show or tapping the line expands to the rows; the header then says **Hide**. | Today is about Priority; this is the nice-to-have. No chevron, no card header: `SectionHeader`'s action does it (components.md #10). |
| Open when nothing is due | Expanded by default when Priority is empty (up to date or all done). | Then it is the only thing left to do on Today. |
| Remembered | No. Resets on leaving Today, like "And N more waiting". | No setting for one toggle. Add one if users ask. |
| Desktop | Unchanged: rows in the side column, no Show / Hide. | The side column is already secondary. |
| Data | No migration. `Person` gains `createdAt`, from `created_at`, already in the `*` select. | Nothing new is stored. |

## Rules

`checkIns(List<Person> team, DateTime today)` in
`lib/features/team/domain/check_in.dart`, `today` local midnight. With
`joined` = `joinedOn(person)`, `added` = the local day of `createdAt`:

- **New**: `stageSince` after `createdAt`, joined less than 30 days ago, and
  nothing logged since joining. Chip `New`, reasons unchanged.
- Otherwise, **hidden** while `added` is less than 30 days ago.
- **Quiet**: `since` = `lastContactOn`, or when null the later of `joined`
  and `added`; shown when `since` is 30 days ago or more.
- One row per person, oldest `since` first, then `searchKey(name)`: unchanged.

Reasons:

- Last contact known: "You last talked on {date}" (unchanged).
- Nothing logged, `since` is the joining day: "Nothing is logged since they
  joined on {date}" (unchanged).
- Nothing logged, `since` is the day they were added: new, "Nothing is
  logged since you added them on {date}".

The constants (30, 30) live in `check_in.dart`, named.

## Screen

`checkInItems()` (`lib/features/team/presentation/check_in_items.dart`) gains
`collapsed` and `onToggle`:

- `onToggle` null (desktop): header without action, the rows. As today.
- Collapsed: `SectionHeader(title, actionLabel: Show, onAction: onToggle)`,
  then one tappable line: `LoomiaAvatarGroup` of the people's names and
  "{count} people you could catch up with" (plural). The whole line is one
  button for screen readers, labelled like Show.
- Expanded: `SectionHeader(… actionLabel: Hide …)`, then the rows.

`_TodayViewState` holds `_catchUpOpen` (`bool?`, null = follow the default:
open when the due list is empty, closed otherwise). On mobile and tablet it
passes `collapsed` and `onToggle`; on desktop neither.

## Copy

EN in `app_en.arb`, descriptions updated (no more "two weeks", no more
"Team screen"):

- `teamSectionCheckIn`: "Catch up". Description says it is shown in capitals
  and that FR is « Prendre des nouvelles ».
- `teamChipQuiet`: "{count, plural, =1{Quiet a month} other{Quiet {count} months}}".
- New: `teamReasonQuietAdded` "Nothing is logged since you added them on
  {date}", `todayCatchUpSummary` "{count, plural, =1{1 person you could catch
  up with} other{{count} people you could catch up with}}", `todayCatchUpShow`
  "Show", `todayCatchUpHide` "Hide".

FR: `teamSectionCheckIn` set by hand to « Prendre des nouvelles » in
`app_fr.arb`, with its `translation_sources.json` entry updated to the new
English so the l10n sync keeps it (README → Translations). The other keys come
from the sync PR; check the chip reads « Sans nouvelles depuis un mois ».

## Delivery

One PR, no migration (Database section: none, no `supabase db push`).

## Testing

- Unit `test/features/team/domain/check_in_test.dart`:
  - imported "since today", nothing logged: hidden on day 0 and 29, Quiet on
    day 30 with the added reason;
  - imported with a past joining day: hidden for 29 days, Quiet from day 30,
    counted from the day added;
  - moved Prospect → Team inside Loomia today: New, even when added this week;
  - added straight onto Team today: not New;
  - last contact 29 days ago: hidden; 30: Quiet a month; a log older than the
    add day, inside the grace month: hidden;
  - New wins over Quiet, ordering: unchanged.
- Widget `test/features/today/today_page_test.dart`: mobile collapsed by
  default with the summary line and no rows; Show expands, Hide collapses;
  expanded when nothing is due; desktop shows the rows and no Show.
- Goldens: Today's previews with check-ins change; a collapsed and an
  expanded mobile preview. Regenerated through CI.

## Figma

Section "Catch up — #342", mobile 390 wide:

1. Today with Priority rows and Catch up collapsed (4 people).
2. The same, expanded (Hide, 4 rows, one "Quiet a month", one "Nothing is
   logged since you added them on…", one New).
3. Today up to date, Catch up open by default.
4. Collapsed with one person.

Not mocked: desktop (unchanged), dark mode (tokens), FR (the same frames with
« PRENDRE DES NOUVELLES »; worth one frame if the length is a concern).
