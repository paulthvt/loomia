# Contact Tags Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** A person has any number of tags, each a name and one of 8 palette
colours (#332). The contact page shows and edits them, several picked people
are tagged in one write, the contacts list filters by them (AND) and marks
rows with dots, and Settings → Tags renames, recolours and deletes.

**Architecture:**
- **Migration:** `tag_color` enum, `tag`, `person_tag`, `set_person_tags`.
- **Theme:** `TagColor` enum in `app_colors.dart`, each key a light and a dark
  `(container, ink)` pair. No `ThemeExtension`: a tag colour is chosen by
  data, not by a widget's role.
- **Domain:** `Tag`, `Person.tagIds`, `nextTagColor`, `tagNameTaken`,
  `tagState`, `StageFilter.shows(tags:)`.
- **Data:** `TagRepository`; `PeopleRepository` reads `person_tag(tag_id)` and
  gains `setTags`.
- **UI:** `TagChip` / `TagDot` in `core/ui`, the tag sheet, the contact page
  row, the filter row and dots in `ContactList`, the Tag picked action,
  Settings → Tags with the editor.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase
(Postgres, pgTAP).

**Spec:** `docs/superpowers/specs/2026-10-15-contact-tags-design.md`. Figma:
[Tags — #332](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=374-10284).

## Global Constraints

- One migration, `supabase migration new contact_tags`.
- **Database:** additive only (an enum, two tables, a function). Safe for the
  released app; `supabase db push` before or after the release.
- No new dependency. Copy in `app_en.arb` only, each key described; FR comes
  from the l10n sync.
- No literal colour outside `app_colors.dart`. Chip and swatch styling lives
  in the components, never in screens.
- Gate: `dart format .`, `flutter analyze`, `flutter test`, `supabase test db`.
  Goldens through CI, never committed from a Mac.
- Branch `feature/332-contact-tags` off `main`; PR `Closes #332`, Database
  section filled.

## Rulings made while planning

- **`setTags` returns the people.** `PeopleRepository.setTags` calls the RPC,
  then selects `_columns` for those ids, like `_writeAll`; the controller
  `_replaceAll`s them. `Person` has no `copyWith`, and this keeps the server
  the source of `tagIds`.
- **A deleted tag needs no reload of the book.** The cascade removes its
  `person_tag` rows on the server; on the device, every reader resolves
  `person.tagIds` through `tagsProvider`, so an id with no tag is ignored.
  The list's selected filter drops ids no longer in `tagsProvider`. The next
  book reload clears them.
- **`tagsProvider` is a family by owner**, like `eventWorkflowsProvider`, with
  an `edit(write)` that reloads itself. Not `autoDispose`.
- **Name check on the device, backstop on the server.** A `23505` from the
  unique index maps to `PeopleFailure.unknown` and the editor shows the
  generic save error; the device check catches every normal case first.
- **The tag sheet holds its edits locally.** It keeps `add` / `remove` sets;
  a tag created in the sheet is written at once (it must have an id) and
  ticked, but the person's tags change only on Done. Closing without Done
  leaves the new tag existing and unused, which is fine.
- **Tri-state:** `Checkbox(tristate: true, value: null)` for "some". Tapping a
  mixed box ticks it (adds to all); tapping again unticks (removes from all);
  a third tap returns to mixed (no change). The cycle is the Material one.
- **Delete confirmation** uses `confirmDestructive`, with its Cancel.
- **Settings → Tags on desktop** is a `SettingsSection.tags` pane, the editor
  a `LoomiaDialog` on every size (it is a short form).

## Changed while implementing

- **No `peopleCount` query.** Settings → Tags and the delete confirmation count
  from the loaded book (`peopleWithTag`), which every screen has already.
- **Tap target 32 px, not 48,** for tag chips and the add / edit action, like
  the LRP line under the stage chip: 48 pushed the contact page's content
  down a full row. 32 still clears the 24 px minimum.
- **The colour sheet golden is unchanged.** The palette is shown by a new
  `Components / Tags` preview (`lib/core/ui/tag_preview.dart`, goldens
  `tags_light`, `tags_dark`) rather than squeezed into the 420×900 sheet.
- **`Person.withTagIds`** joins `withStatus` / `withReminders` on the private
  `_copy`, for the fake repository; still no general `copyWith`.
- **Copy:** the error key is `tagNameInUse` (the domain already has
  `tagNameTaken`); added `tagsDone`, `tagDeleteBody`, `tagsSummary`.

## Review Focus

1. `set_person_tags` is one transaction, refuses another owner's rows and a
   tag in both arrays. Pinned in Task 1.
2. A mixed box left alone changes nothing; Done writes once; closing writes
   nothing. Pinned in Task 6.
3. Two tags narrow (AND) within the stage, LRP and search. Pinned in Tasks 3
   and 8.
4. Every palette pair passes AA in both modes. Pinned in Task 2.

---

### Task 1: Migration and pgTAP

**Files:** Create `supabase/migrations/<ts>_contact_tags.sql`,
`supabase/tests/tags_test.sql`.

- [x] `supabase migration new contact_tags`, then:

```sql
-- Tags on contacts (#332): a name and a palette colour per tag, any number
-- per person. Additive: safe for the released app.

create type public.tag_color as enum
  ('stone', 'sand', 'olive', 'sage', 'teal', 'sky', 'indigo', 'violet');

create table public.tag (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 32),
  color public.tag_color not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id)
);

-- Backstop only: the app also folds accents (searchKey).
create unique index tag_owner_name_key on public.tag (owner_id, lower(trim(name)));

create trigger tag_set_updated_at before update on public.tag
  for each row execute function public.set_updated_at();

alter table public.tag enable row level security;
create policy tag_select_own on public.tag
  for select to authenticated using (owner_id = (select auth.uid()));
create policy tag_insert_own on public.tag
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy tag_update_own on public.tag
  for update to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy tag_delete_own on public.tag
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.tag from anon, authenticated;
grant select, insert, delete on public.tag to authenticated;
grant update (name, color) on public.tag to authenticated;

create table public.person_tag (
  person_id uuid not null,
  tag_id uuid not null,
  owner_id uuid not null default auth.uid(),
  primary key (person_id, tag_id),
  foreign key (person_id, owner_id)
    references public.person (id, owner_id) on delete cascade,
  foreign key (tag_id, owner_id)
    references public.tag (id, owner_id) on delete cascade
);

create index person_tag_tag_idx on public.person_tag (tag_id, owner_id);

alter table public.person_tag enable row level security;
create policy person_tag_select_own on public.person_tag
  for select to authenticated using (owner_id = (select auth.uid()));
create policy person_tag_insert_own on public.person_tag
  for insert to authenticated with check (owner_id = (select auth.uid()));
create policy person_tag_delete_own on public.person_tag
  for delete to authenticated using (owner_id = (select auth.uid()));

revoke all on public.person_tag from anon, authenticated;
grant select, insert, delete on public.person_tag to authenticated;

-- Adds every person × add, removes every person × remove, in one
-- transaction. Another owner's person or tag fails the composite FK.
create function public.set_person_tags(
  p_people uuid[], p_add uuid[], p_remove uuid[]
) returns void
language plpgsql security invoker set search_path = '' as $$
begin
  if p_add && p_remove then
    raise exception 'a tag is both added and removed' using errcode = 'P0001';
  end if;
  insert into public.person_tag (person_id, tag_id)
    select p, t from unnest(p_people) p, unnest(p_add) t
    on conflict do nothing;
  delete from public.person_tag
    where person_id = any (p_people) and tag_id = any (p_remove);
end $$;

revoke execute on function public.set_person_tags(uuid[], uuid[], uuid[])
  from public, anon;
grant execute on function public.set_person_tags(uuid[], uuid[], uuid[])
  to authenticated;
```

  Check the policy shapes against
  `supabase/migrations/20261008135516_reminders.sql` and follow them where
  they differ; `person (id, owner_id)` is already a composite key (the
  reminder and attendee FKs use it).

- [x] `supabase/tests/tags_test.sql`, two users as in `reminders_test.sql`:
  1. a tag saves; a blank name (`'  '`) and a 33-character name are refused
     (`23514`);
  2. `'Lyon'` then `' lyon '` for the same owner: `23505`; the same name for
     user b: allowed;
  3. `set_person_tags([p1, p2], [t1, t2], [])` makes 4 rows; running it again
     still 4;
  4. `set_person_tags([p1], [], [t1])` removes one row, leaves p2's;
  5. `set_person_tags([p1], [t1], [t1])` throws `P0001`;
  6. as b: adding a's tag to b's person, and b's tag to a's person, throw;
     b sees no `tag` or `person_tag` row of a;
  7. deleting t2 removes its `person_tag` rows; deleting p2 removes p2's;
  8. `anon` cannot execute `set_person_tags`.
- [x] `supabase test db`: `tags_test` and `schema_rls_test` green.

### Task 2: Palette tokens

**Files:** Modify `lib/app/theme/app_colors.dart`; test
`test/app/theme/tag_color_test.dart`.

- [x] In `app_colors.dart`, after `LoomiaColors`:

```dart
/// A tag's two colours in one mode: the chip's fill and its text, dot and
/// check.
typedef TagInk = ({Color container, Color ink});

/// The tag palette (#332), Figma `tag/<key>/container` and `tag/<key>/ink`.
/// Stored by name in `tag.color`; the order is the order new tags take.
/// No red: no chip is red (components.md #6).
enum TagColor {
  stone(
    light: (container: Color(0xFFECE8E3), ink: Color(0xFF6B6158)),
    dark: (container: Color(0xFF3A3631), ink: Color(0xFFDDD6CD)),
  ),
  sand(
    light: (container: Color(0xFFF2E7CF), ink: Color(0xFF7D5B0F)),
    dark: (container: Color(0xFF45391F), ink: Color(0xFFEBD7AA)),
  ),
  olive(
    light: (container: Color(0xFFE7E9CD), ink: Color(0xFF5F6614)),
    dark: (container: Color(0xFF3B3D1F), ink: Color(0xFFD6DAA6)),
  ),
  sage(
    light: (container: Color(0xFFDCEADC), ink: Color(0xFF36714A)),
    dark: (container: Color(0xFF283D2C), ink: Color(0xFFB9D9BE)),
  ),
  teal(
    light: (container: Color(0xFFD3EAE7), ink: Color(0xFF176D66)),
    dark: (container: Color(0xFF1E3D3A), ink: Color(0xFFA9DCD5)),
  ),
  sky(
    light: (container: Color(0xFFD8E7F3), ink: Color(0xFF285F94)),
    dark: (container: Color(0xFF20364A), ink: Color(0xFFB4D2EC)),
  ),
  indigo(
    light: (container: Color(0xFFDFE1F4), ink: Color(0xFF4A52AE)),
    dark: (container: Color(0xFF2C3058), ink: Color(0xFFC5CAF2)),
  ),
  violet(
    light: (container: Color(0xFFEBE0F2), ink: Color(0xFF7A47A6)),
    dark: (container: Color(0xFF3D2C4D), ink: Color(0xFFDCC6EE)),
  );

  const TagColor({required this.light, required this.dark});

  final TagInk light;
  final TagInk dark;

  TagInk of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
```

- [x] Test: for every key and both modes, the WCAG contrast of `ink` on
  `container` is ≥ 4.5 (`(L1 + 0.05) / (L2 + 0.05)` with
  `computeLuminance()`); and in light mode `ink` on
  `LoomiaColors.light.surfaceSunken` ≥ 3 (the Off chip's dot).
- [x] Add the 8 colours to `theme_preview.dart`'s colour sheet, one swatch per
  key and mode; its golden regenerates through CI.

### Task 3: Domain

**Files:** Create `lib/features/contacts/domain/tag.dart`; modify
`lib/features/contacts/domain/person.dart`,
`lib/features/contacts/presentation/stage_filter.dart`; test
`test/features/contacts/domain/tag_test.dart`, extend
`test/features/contacts/presentation/contact_list_test.dart` or a new
`stage_filter_test.dart`.

- [x] Tests first:
  - `nextTagColor([])` is `stone`; with `stone, sand` used, `olive`; all 8
    used, `stone`.
  - `tagNameTaken('lyon', [Lyon])`, `('Léa', [Lea])`, `(' Lyon ', [Lyon])`
    are true; `('Lyon', [Lyon], except: lyon.id)` is false.
  - `tagState(t, [a, b])`: both have it → `true`, one → `null`, none →
    `false` (the `Checkbox` tristate values).
  - `StageFilter.shows(customer, p, tags: {lyon, sleep})`: only a customer
    with both passes; with `loyalty: true` also needs the LRP; `tags: {}`
    shows everyone.
- [x] `tag.dart`:

```dart
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/search_key.dart';

class Tag {
  const Tag({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final TagColor color;
}

/// The first palette key no tag uses; all used, the first.
TagColor nextTagColor(Iterable<Tag> tags) {
  final used = {for (final tag in tags) tag.color};
  return TagColor.values.firstWhere(
    (color) => !used.contains(color),
    orElse: () => TagColor.values.first,
  );
}

/// Whether another tag than [except] already has [name], ignoring case,
/// accents and surrounding spaces.
bool tagNameTaken(String name, Iterable<Tag> tags, {String? except}) {
  final key = searchKey(name.trim());
  return tags.any((tag) => tag.id != except && searchKey(tag.name) == key);
}

/// For a box over [people]: true all have [tag], false none, null some.
bool? tagState(Tag tag, List<Person> people) {
  final having = people.where((p) => p.tagIds.contains(tag.id)).length;
  return having == 0 ? false : having == people.length ? true : null;
}
```

  `TagColor` lives in the theme (a theme key, spec §2), so the domain
  imports `app_colors.dart`; that is the one theme import in domain, and
  only for the enum. Check `searchKey` already trims; drop the `trim()` if
  so.
- [x] `Person.tagIds`: `final Set<String> tagIds;`, constructor default
  `const {}`, documented "ids from `person_tag`; may hold a tag deleted on
  another device until the next load".
- [x] `StageFilter.shows(..., {bool loyalty = false, Set<String> tags = const {}})`
  adds `&& person.tagIds.containsAll(tags)`.

### Task 4: Data

**Files:** Create `lib/features/contacts/data/tag_repository.dart`; modify
`people_repository.dart`; fakes `test/features/contacts/fake_tag_repository.dart`,
`fake_people_repository.dart`; tests next to the existing repository tests.

- [x] `PeopleRepository._columns` gains `, person_tag(tag_id)`;
  `personFromRow` reads `tagIds: {for (final r in row['person_tag'] as List? ?? const []) (r as Map)['tag_id'] as String}`.
  Pin in `people_repository_test.dart` with a row with two `person_tag`s and
  one with none.
- [x] `PeopleRepository.setTags(List<String> ids, Set<String> add, Set<String> remove)`:
  `rpc('set_person_tags', params: {'p_people': ids, 'p_add': [...add], 'p_remove': [...remove]})`,
  then `from(_table).select(_columns).inFilter('id', ids)`; inside
  `guardPeople`.
- [x] `TagRepository(SupabaseClient)` + `tagRepositoryProvider`:
  - `list()` → `select('id, name, color')`, mapped with
    `TagColor.values.byName`;
  - `add(String name, TagColor color)` → insert, `.select().single()`;
  - `update(Tag tag)` → `update({'name', 'color'}).eq('id', ...)`;
  - `delete(String id)`;
  - `peopleCount(String id)` → `from('person_tag').select().eq('tag_id', id).count(CountOption.exact)`.

  Every call in `guardPeople`; names are trimmed before writing.
- [x] `FakeTagRepository` (in-memory, `calls`, `failWith`, like
  `FakePeopleRepository`); `FakePeopleRepository.setTags` updates its store
  and records `setTags(ids, +add, -remove)`. `FakePeopleRepository` needs a
  way to build a `Person` with new `tagIds`: add a private helper there, not a
  `copyWith` on `Person`.

### Task 5: Providers

**Files:** Create `lib/features/contacts/presentation/tags_controller.dart`;
modify `people_controller.dart`; tests `tags_controller_test.dart`,
`people_controller_test.dart`.

- [x] `tagsProvider = AsyncNotifierProvider.family<TagsController, List<Tag>, String?>`
  (`retry: (_, _) => null`), sorted by `searchKey(name)`; `edit<T>(write)`
  runs the write then `invalidateSelf()`; `editTags(ref, write)` helper as
  `editEventWorkflows`.
- [x] `PeopleController.setTags(List<Person> people, Set<String> add, Set<String> remove)`:
  no-op when both empty; else `_replaceAll(await _repository.setTags(...))`.
  Test: one write for three people; nothing when both sets empty.

### Task 6: Components and the tag sheet

**Files:** Create `lib/core/ui/tag_chip.dart`,
`lib/features/contacts/presentation/tag_sheet.dart`; tests
`test/core/ui/tag_chip_test.dart`, `tag_sheet_test.dart`; previews + goldens.

- [x] `tag_chip.dart`:
  - `TagChip(label, color, {onTap, bool? selected})`: `selected == null` is
    Default (container, ink label); `false` is Off (`surfaceSunken`, an 8 px
    ink `TagDot`, `onSurfaceVariant` label); `true` is On (container, 14 px
    `Icons.check_rounded` in ink, ink label). Shape, padding and type as
    `LoomiaChip` (`AppRadii.sm`, `AppSpacing.sm`/`xs`, `AppTypography.caption`).
    With `onTap`, wrapped in `Semantics(button: true, selected: selected)`
    and an `InkWell` with the same radius; at least 48 px tap target
    (`MaterialTapTargetSize.padded` equivalent via `ConstrainedBox`).
  - `TagDot(color, {size = 8})`: a circle in `color.of(context).ink`.
  - `TagDots(tags)`: up to 3 dots, then `+N` in `caption`/`textMuted`;
    `Semantics(label: l10n.tagsSemantics(names))` with the dots excluded.
  - `TagAction({required bool empty, onTap})`: outlined chip "+ Add tag" when
    empty, else an edit-icon chip with tooltip/semantics "Edit tags".
  - `@Preview`s: the 8 colours × 3 states, light and dark; `TagDots` with 2
    and 5 tags.
- [x] Tests: Off/On/Default pick the right colours (read `DecoratedBox`); a
  tap calls `onTap`; `TagDots` with 5 shows 3 dots and "+2" and the semantics
  label lists all 5 names.
- [x] `showTagSheet(BuildContext context, List<Person> people) → Future<bool>`
  via `LoomiaDialog.show`, a `ConsumerStatefulWidget`:
  - title `tagsTitle` (one person) or `tagsTitleMany(count)`;
  - a search field (`AppTheme.search`, hint `tagsSearchHint`) filtering by
    `searchKey`;
  - when the trimmed text is not empty and `!tagNameTaken`, a first row
    "Create "<text>"" with a `TagDot(nextTagColor(tags))`: tapping writes
    `TagRepository.add` through `editTags`, clears the field, puts the new id
    in `add`;
  - one `CheckboxListTile` per tag (dot, name), `tristate: people.length > 1`,
    value = local override, else `tagState`;
  - empty (no tags, no text): `tagsEmpty` line;
  - actions: Cancel, Done. Done calls `PeopleController.setTags(people, add, remove)`
    and pops `true`; a `PeopleFailure` shows `FormError` like
    `change_workflow_sheet.dart`.
- [x] Sheet tests (fakes): one person, tick Sleep, Done → one
  `setTags([p1], +sleep, -)`; close without Done → no `setTags` call; type
  "Workshop May", tap Create → a tag in `FakeTagRepository`, ticked; four
  people with Lyon on two: the Lyon box is mixed, Done without touching it →
  no write (both sets empty); tick it → `+lyon` for all four.

### Task 7: Contact page

**Files:** Modify `lib/features/contacts/presentation/contact_details.dart`;
test `contact_details_test.dart`.

- [x] Under the stage chip / LRP line (`contact_details.dart` around the
  `LoomiaChip(label: stageLabel(...))`), a `Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs)`
  of the person's tags (resolved through `tagsProvider`, sorted) as
  `TagChip(onTap: open sheet)`, then `TagAction(empty: tags.isEmpty)`. Both
  open `showTagSheet(context, [person])`.
- [x] Tests: with two tags, both chips and the edit action; with none, "Add
  tag"; a tag id unknown to `tagsProvider` shows nothing; tapping Add tag
  opens the sheet.

### Task 8: Contacts list

**Files:** Modify `contact_list.dart`, `contacts_page.dart`,
`stage_filter.dart`; tests `contact_list_test.dart`, `contacts_page_test.dart`.

- [x] `ContactList` gains `required List<Tag> tags` and
  `required Future<bool> Function(List<Person>) onTag`; `contacts_page.dart`
  passes `ref.watch(tagsProvider(owner)).value ?? const []` and
  `(people) => showTagSheet(context, people)`.
- [x] State `Set<String> _tags = {}`; the effective filter is
  `_tags.intersection({for (final t in widget.tags) t.id})` (a deleted tag
  never keeps the list filtered), passed to `StageFilter.shows(tags:)`.
- [x] Under `StageFilter`, when `widget.tags` is not empty, a `TagFilter` (in
  `stage_filter.dart`): one `TagChip(selected: _tags.contains(id))` per tag;
  mobile a `SingleChildScrollView(scrollDirection: Axis.horizontal)` row,
  tablet and desktop a `Wrap` (branch on `context.screenSize.isMobile`).
- [x] `ContactRow` gains `Widget? titleTrailing`, shown after the name in a
  `Row` with the name `Flexible` (keeps its one-line ellipsis); the list
  passes `TagDots(tags: resolved)` when the person has any.
- [x] `_actions` gains, third (before Delete),
  `(label: l10n.tagsAction, short: l10n.tagsAction, icon: Icons.sell_outlined, destructive: false, onTap: picked.isEmpty ? null : () => _done(widget.onTag(picked)))`.
- [x] Tests: no tags → no tag row; with tags → the row; Lyon and Sleep on →
  only people with both, within Customers and the search; picking two then
  Tag opens the sheet with "Tag 2 people"; a row with 5 tags shows "+2".

### Task 9: Settings → Tags

**Files:** Modify `lib/app/router/routes.dart`, `app_router.dart`,
`settings_page.dart`; create
`lib/features/contacts/presentation/tags_settings.dart`,
`tag_editor.dart`; tests `tags_settings_test.dart`, `tag_editor_test.dart`,
`settings_page_test.dart`.

- [x] `routes.dart`: `settingsTagsSegment = 'tags'`,
  `settingsTags = '$settings/$settingsTagsSegment'`, `settingsTagsName`;
  then the `GoRoute` beside workflows in `app_router.dart`.
- [x] `SettingsSection.tags`: a `ListTile` under Workflows (`Icons.sell_outlined`,
  title `tagsTitle`, subtitle the count), the pane / pushed page as for
  workflows.
- [x] `TagsSettings`: rows `TagDot`, name, `tagsPeopleCount(n)` (counted from
  `peopleProvider` by `tagIds`, no extra query), and a New tag button; a row
  opens `showTagEditor(context, tag)`, New tag `showTagEditor(context, null)`.
- [x] `showTagEditor`: `LoomiaDialog` titled the tag's name or `tagNew`; a
  name field (`tagNameLabel`, max 32, error `tagNameTaken(name)` via
  `tagNameTaken(..., except: tag?.id)`); a swatch row of the 8 colours
  (`Semantics(label: colour name, selected:)`, the selected one ringed in
  `onSurface`); Save; for an existing tag a footer Delete tag →
  `confirmDestructive(title: tagDeleteTitle(name, count), action: tagDelete)`
  with `count` from `TagRepository.peopleCount`. New tags default to
  `nextTagColor`.
- [x] Tests: rename saves through `FakeTagRepository.update`; a taken name
  shows the error and does not save; delete asks "Remove Lyon from 12
  people?" and deletes on confirm; the swatch's semantics label is "Sage".

### Task 10: Copy, docs, gate

**Files:** `lib/l10n/app_en.arb`, `docs/design/components.md`.

- [x] Keys (each with a description), added in the task that first uses
  them: `tagsTitle` "Tags", `tagsAdd` "Add tag", `tagsEdit` "Edit tags",
  `tagsAction` "Tag", `tagsTitleMany` "Tag {count} people" (plural),
  `tagsSearchHint` "Search or create a tag", `tagsCreate` "Create
  \"{name}\"", `tagsEmpty` "Type a name to create your first tag", `tagNew`
  "New tag", `tagNameLabel` "Tag name", `tagNameTaken` "You already have a
  tag called {name}", `tagsPeopleCount` "{count} people" (plural),
  `tagDeleteTitle` "Remove {name} from {count} people?" (plural),
  `tagDelete` "Delete tag", `tagsSemantics` "Tags: {names}", and
  `tagColorStone` … `tagColorViolet`.
- [x] `components.md` #6: "An active tag filter chip takes its tag's
  colour, not Primary (#332)", plus a `TagChip` entry.
- [x] `dart format .`, `flutter analyze` (No issues found!), `flutter test`,
  `supabase test db`; `graphify update .`.
- [x] PR: summary, Database section ("additive; push before or after the
  release; safe for the released app"), `Closes #332`. Goldens via the CI
  regenerate procedure in README.
