# Tags on contacts — design

Issue: #332. Figma: [Tags — #332](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=374-10284)
on page "04 — Screens (Light)"; components `TagChip`, `TagAction`, `Checkbox`
(Off / On / Mixed), `TagSheetRow`, `TagSwatch`, `TagDot` on the Components
page. Builds on the contacts list filter of
`2026-10-10-loyalty-on-contact-design.md` and the multi-select of #180.

## Intent

Stages say where someone is; tags say who they are to the user: "Workshop
May", "Lyon", "Sleep", "Neighbours". A person has any number of tags, each
with a name and a colour picked from a palette so tags tell apart at a
glance. The contacts list filters by them, and a filter plus Select all is a
group: move it, change its workflow, tag it, delete it. No separate "group"
object exists; a group is a tag.

## Decisions

| Question | Decision | Reason |
| --- | --- | --- |
| Group vs tag | One concept: tags. | A group is "everyone with this tag". Two objects for one idea is two screens to explain. |
| Owner | Per account, like workflows. Not shared with the team. | Nothing in the app is shared yet. |
| Colour | A fixed palette of 8 named keys, stored as a key, never as a hex. | Each key is a container/ink pair per mode, so a tag reads in light and dark and passes AA. A free hex would break dark mode and the theme rule (no literal colour). |
| Palette | `stone`, `sand`, `olive`, `sage`, `teal`, `sky`, `indigo`, `violet`. Hexes in Figma, tokens `tag/<key>/container` and `tag/<key>/ink`. | No red: "no red chip exists" (components.md #6). Kept apart from `accent` (date-anchored only) and from the stage chip's neutral. |
| Default colour | The first palette key no tag uses yet; all used, `stone`. | New tags differ from the existing ones without the user choosing. |
| Colour alone | Never carries meaning: the name is always shown, except the list-row dots, which carry the names as semantics. | Accessibility. |
| Name | Required, trimmed, 1–32 characters, unique per account ignoring case and accents (`searchKey`). | "lyon" and "Lyon" are the same group. 32 keeps chips one line. |
| Creating a tag | From the tag sheet, by typing a name that does not exist: "Create "Workshop May"". Also New tag in Settings → Tags. | Tags are made while tagging someone, not planned ahead. |
| Managing tags | Settings → Tags: rename, recolour, delete. Delete is confirmed: "Remove Lyon from 12 people?". | Rename and recolour must reach every person at once. |
| Tagging one person | Contact page, under the stage chip: their tags as chips and an Add tag / edit action opening the tag sheet. | Next to the other facts about who they are. |
| Tagging several | A fourth picked action, Tag, opens the same sheet with tri-state boxes: all, some, none of the picked have it. Ticking adds to all, unticking removes from all, a mixed box left alone changes nothing. | The Gmail-labels pattern; one write for the batch. |
| Writing | One RPC, `set_person_tags`, adds and removes for many people in one transaction. | All or nothing, like the other bulk writes. |
| Filter | A second chip row under Everyone · Prospects · … · LRP: one `FilterChip` per tag, sorted by name, shown once any tag exists. Several selected: people with **all** of them (AND), within the stage and LRP filter and the search. | Same as LRP: every chip narrows. OR is a later toggle if users ask. |
| Filter row overflow | Mobile: one horizontally scrolling row. Tablet and desktop: wraps. | Many tags must not push the list off a phone screen. |
| Filter in the URL | No, like the stage filter. | Nothing links to a filtered list. |
| Row marker | Up to 3 colour dots after the name on `ContactRow`, `+N` beyond; the row keeps its height. Semantics: "Tags: Lyon, Sleep". | The colour is the point of the request; full chips would crowd the stage chip. |
| Search | Does not match tag names. | The filter does it; mixing them makes "lyon" match the address and the tag. |
| Elsewhere | Not in this issue: the event people picker, Today, import, Add someone. Picker by tag is the first follow-up. | Keep the first PR to contacts. |
| History | Tagging writes no history entry. | A tag is a label, not something that happened with the person. |
| Dots | The row dots, the dot in an Off filter chip and the check in an On one use the tag's ink. | Only container and ink exist; the container is too pale to read as a dot. The Figma inks were brightened for this and still pass AA. |
| Filter chip states | Off: sunken surface, ink dot, `onSurfaceVariant` label. On: the tag's container, a check and the label in its ink. | Off must not look picked; On reads as the tag. |
| Delete confirmation's cancel | The existing `confirmDestructive` (Cancel), not Figma's "Keep". | One ConfirmDialog in the app. |

## 1. Data — one migration

`supabase migration new contact_tags`. Additive only: safe for the released
app, `supabase db push` before or after the release.

### `tag`

| Column | Type | Note |
| --- | --- | --- |
| `id` | uuid | |
| `owner_id` | uuid | `default auth.uid()`, cascade |
| `name` | text not null | `check (length(trim(name)) between 1 and 32)` |
| `color` | `public.tag_color` not null | enum of the 8 keys |
| `created_at`, `updated_at` | timestamptz | `set_updated_at` trigger |

`unique (id, owner_id)` for the composite FK. Uniqueness of the name is
checked by the app with `searchKey` (Postgres has no accent-folding without
`unaccent`); the server also has `unique (owner_id, lower(trim(name)))` as a
backstop. ponytail: "Léa" and "Lea" can both exist through a stale client;
add `unaccent` if that happens.

### `person_tag`

| Column | Type | Note |
| --- | --- | --- |
| `person_id` | uuid | FK `(person_id, owner_id)` → `person`, on delete cascade |
| `tag_id` | uuid | FK `(tag_id, owner_id)` → `tag`, on delete cascade |
| `owner_id` | uuid | `default auth.uid()` |

Primary key `(person_id, tag_id)`; index on `(tag_id, owner_id)` for the
delete count and cascade. Grants: `select, insert, delete` (no update: a row
is there or not). `person_id_owner_key` already exists (history migration).

Both tables: RLS on, four owner policies (three on `person_tag`), `revoke all
... from anon, authenticated` then the grants, in this migration.
`schema_rls_test.sql` covers them.

### `set_person_tags(p_people uuid[], p_add uuid[], p_remove uuid[])`

`security invoker`, `search_path = ''`, executable by `authenticated` only.
Inserts every `(person, tag)` of `p_people × p_add` that is missing (`on
conflict do nothing`), deletes every `p_people × p_remove`. RLS refuses
another owner's person or tag (the composite FKs fail the insert). A tag in
both arrays: raise `P0001`. Returns nothing; the app already knows the result.

### Reading

`PeopleRepository._columns` gains `person_tag(tag_id)`. `TagRepository`
(`lib/features/contacts/data/tag_repository.dart`) lists, adds, renames,
recolours and deletes tags. A tag's people are counted from the loaded book.

## 2. Domain (Dart)

`lib/features/contacts/domain/tag.dart`:

- `Tag { id, name, color }`. `TagColor` is the palette enum, declared in
  `lib/app/theme/app_colors.dart` beside its colours (it is a theme key, not
  business data).
- `Person.tagIds` (`Set<String>`, empty by default), read-only from the row.
- `nextTagColor(Iterable<Tag> tags)`: the first unused key, else `stone`.
- `tagNameTaken(String name, Iterable<Tag> tags, {String? except})`: by
  `searchKey`.
- `tagState(Tag tag, List<Person> people)`: all / some / none, for the bulk
  sheet.
- `StageFilter.shows` gains `tags` (`Set<String>`): the person has every one.

`tagsProvider` (autoDispose not needed: the list and contact page both read
it), sorted by `searchKey(name)`. `PeopleController.setTags(people, add,
remove)` calls the RPC, then updates each person's `tagIds` locally.

## 3. Screens

### Contact page

Under the stage chip (and the LRP line): the person's tags as `TagChip`s,
wrapping, then a small Add tag action (an outlined chip with `+` when they
have none, an edit icon when they have some). Tapping a tag chip opens the
tag sheet too. Same on mobile and desktop.

### Tag sheet

A sheet on mobile, a dialog on desktop, like the other contact sheets. Title
"Tags" (one person) or "Tag 4 people".

1. A search field: filters the list as you type. When the text matches no
   tag, the first row is "Create "<text>"", with the colour it will get;
   tapping it creates the tag and ticks it.
2. Every tag: colour dot, name, checkbox (tri-state for several people).
3. Done saves the change in one write; closing without Done saves nothing.
   No tags yet: the field and an empty line "Type a name to create your
   first tag".

Recolouring or renaming is not done here: Settings → Tags.

### Contacts list

- Under the stage / LRP chips, the tag chip row (see Decisions). An active
  tag chip uses its own colour, not Primary — the one exception to
  components.md #6's "active filter is Primary", recorded there.
- Rows: the tag dots after the name.
- Picking: a fourth action, **Tag** (`Icons.sell_outlined`), always enabled
  while something is picked; on the phone it takes its place in the bottom
  bar with the other three.
- No match with tags selected: the existing `contactsNoMatch`.

### Settings → Tags

A row in Settings under Workflows: "Tags · 6". The page: one row per tag
(dot, name, "12 people"), New tag, and tapping a row opens the tag editor.

Tag editor (sheet / dialog): name, the 8 colours as a swatch row (selected
one ringed, each swatch labelled for screen readers: "Sage"), Save, and
Delete (confirmed, with the count). A taken name shows "You already have a
tag called Lyon" under the field.

Route: `/settings/tags` in `routes.dart`.

### Components

`lib/core/ui/tag_chip.dart`: `TagChip(label, color, {onTap, selected})`, the
`LoomiaChip` shape (radius 8, caption) in the tag's container/ink. Used on the
contact page, the filter row and the sheet. Styling of the swatch ring and
the dots lives in `app_theme.dart` / the component, never in the screens.

## 4. Copy

EN in `app_en.arb`, each with a description: "Tags", "Add tag", "Tag",
"Tag {count} people", "Search or create a tag", "Create "{name}"", "Type a
name to create your first tag", "New tag" (also the editor's title when
creating; editing, the title is the tag's name), "Tag name", "You already have a tag called {name}",
"{count} people" (plural), "Remove {name} from {count} people?" (plural),
"Delete tag", "Tags: {names}" (semantics), the 8 colour names. FR from the
l10n sync, informal.

## 5. Delivery

One PR: migration, repositories, contact page, tag sheet (one and many),
filter row, row dots, Settings → Tags. Follow-up issues: tag filter in the
event people picker; "Tag everyone" on import.

## 6. Testing

- SQL `supabase/tests/tags_test.sql`: `set_person_tags` adds without
  duplicating, removes, refuses a tag in both arrays, refuses another
  owner's person or tag; deleting a tag or a person cascades; the
  case-insensitive name backstop. `schema_rls_test.sql` covers both tables.
- Unit: `nextTagColor` (none, some, all used), `tagNameTaken` (case, accents,
  `except` for a rename), `tagState`, `StageFilter.shows` with tags AND stage
  AND LRP.
- Widget: contact page with and without tags; the sheet creating a tag,
  ticking and Done, closing without Done; the bulk sheet's mixed box left
  alone; the filter row hidden then shown, two tags narrowing; Settings →
  Tags rename and delete confirmation.
- Goldens: one per new or changed `@Preview`, regenerated through CI.

## Figma

Section "Tags — #332" (16 frames): the palette board (light and dark, with
the contrast ratios), contact page with three tags and with none, the tag
sheet (one person, creating, empty, four people with mixed boxes), the
contacts list with Lyon and Sleep active and rows with dots and `+2`, the
picking bar with Tag, Settings with the Tags row, Settings → Tags, the
editor, "name taken", the delete confirmation, and desktop picking with the
tag dialog.

Not mocked, built from the existing patterns: Settings → Tags on desktop (the
settings pane, like Workflows) and the dark screens (the tokens' dark values).
`ContactRow` already keeps the name on one line with an ellipsis in code; the
Figma row change only caught the mock up with it.
