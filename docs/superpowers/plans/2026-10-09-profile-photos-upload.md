# Profile photos — upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A contact and the user can have a photo, chosen from the phone's photo picker or the computer's file dialog, changed and removed. Wherever a person's or the user's avatar shows, the photo replaces the initials once it loads (#239, part of #238).

**Architecture:** A private Storage bucket `avatars`, one folder per user, guarded by RLS on `storage.objects`. A file is `<uid>/<random>`. A contact's path is in `person.photo_path`, the user's in user metadata `avatar_path`. `lib/core/photos/` holds what contacts and settings share: `PhotoRepository` (upload, discard, signed URL), `swapPhoto` (upload → write the path → discard the old file), `photoProvider` (path → `ImageProvider`, signed URL cached for the session), and `PhotoPicker` (`image_picker`, resized to 256 px). `LoomiaAvatar` takes an `ImageProvider?` and stays pure. `PhotoAvatar` resolves a path, and `ContactRow` and `ActionItem` use it. `AvatarControl` is the tappable 56 avatar: camera badge, Choose / Remove menu, upload ring.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, Supabase (Postgres, Storage, Edge Functions), `image_picker`, pgTAP.

**Spec:** `docs/superpowers/specs/2026-10-09-profile-photos-design.md`. Figma: [Profile photos — #238](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=286-5902).

## Global Constraints

- One new dependency: `image_picker`, with its reason in the pubspec comment. `flutter pub add image_picker` changes `pubspec.lock`; stage both. Stage only changed files by path (never `git add -A` / `git add .`): the user keeps untracked local files.
- Schema only through `supabase migration new <name>`; never edit an applied migration. The bucket is created in the migration, never the dashboard.
- Dart: `package:loomia/...` imports; Material from `package:material_ui/material_ui.dart`; `lib/core` never imports `lib/features`.
- Theme from `colorScheme`, `LoomiaColors`, `AppSpacing`, `AppRadii`; no literal sizes in widgets beyond the existing `AvatarSize` diameters.
- Copy: English only, in `lib/l10n/app_en.arb`, every key with a description; `flutter gen-l10n`. Informal register.
- Async handlers read `ref` / `context` values (and the `ScaffoldMessenger`) before the first `await`.
- Quality gate per task: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`; SQL tasks also `supabase db reset && supabase test db`. Goldens from CI only.
- Branch `feature/239-photo-upload` off `main` once the design PR (`chore/238-profile-photos-design`) is merged. PR body `Closes #239`.

## Rulings made while planning

- **The photo code lives in `lib/core/photos/`, not `features/contacts/data/`** as the spec's §2 says. The user's photo (Settings, shell) and contacts both use it, and `PhotoAvatar` in `core/ui` must reach it; `core` may not import a feature. Same reason `supabase_provider.dart` is in `core/`.
- **`LoomiaAvatar` stays a plain widget** taking `ImageProvider? photo`. `PhotoAvatar` (path → provider) is a `Consumer` only when the path is non-null. Previews and tests without photos therefore still need no `ProviderScope`.
- **`ContactDetails` takes an `ImageProvider? photo`**, resolved by `ContactPage`, like its other callbacks. The pure widget and its preview stay provider-free.
- **`photo_path` is not in `personToRow`.** Only `PeopleRepository.setPhoto` writes it, so a stale copy saved by Edit or a status tap never brings a removed photo back. Same rule as the stage.
- **Random file name from `Random.secure()`** (16 bytes, hex), not the transitive `uuid` package: no new direct dependency for one call.
- **The old file is discarded by the controller and the account screen, not by `PeopleRepository.delete`.** The controller already holds the people being removed, so no extra select. `PhotoRepository.discard` never throws: a failure goes to `Sentry.captureException` and is otherwise silent.
- **`StorageException` maps to `PeopleFailure.unknown`** in `peopleFailureFrom`. A refusal from Storage (too large, wrong type, policy) is not a connection problem. Photo errors reuse `peopleFailureCopy`; no new failure copy.
- **`core/photos` throws what it gets, callers map it** (found while implementing): `PeopleFailure` lives in a feature, and `core` may not import one. `PeopleController.setPhoto` and the account screen wrap `swapPhoto` in `guardPeople`.
- **No content-type copy for an unusable image.** `imageType` sniffs JPEG / PNG / WebP. Anything else (an HEIC the picker did not re-encode) throws a `FormatException` before upload, `PeopleFailure.unknown` once guarded: "Something went wrong. Try again."
  `// ponytail: HEIC is refused, not converted; add a decode/re-encode if users hit it.`
- **The busy ring is the control's own `setState`.** `AvatarControl` awaits its `onChoose` / `onRemove` future. That is purely local state, so no provider.
- **Photos show in previews only on the component board** (`ui_preview.dart`) and in one contact header preview, from `previewPhoto`: a generated 64×64 PNG embedded as bytes in `lib/core/ui/preview_photo.dart`, never the network. `previews_test.dart` precaches images under `runAsync` before the golden.
- **Bucket limits are pinned on the bucket row, not by upload.** The Storage API enforces `file_size_limit` and `allowed_mime_types`; Postgres does not. pgTAP checks the row and the policies, and the device check in Task 7 tries an oversize upload.
- **Direct deletes in pgTAP** need `set local storage.allow_delete_query = 'true'`, because Storage's `protect_objects_delete` trigger refuses them otherwise. RLS then decides, so another owner's delete removes 0 rows rather than raising.

## Review Focus

1. A user reads, writes and deletes only in their own folder; `anon` nothing. Pinned in Task 1.
2. A failed path write leaves the old photo in place and removes the new file; a successful one removes the old file. Pinned in Task 2.
3. Editing a contact or tapping a status never writes `photo_path`. Pinned in Task 4.
4. The avatar shows initials while loading, on failure and without a photo; the name stays its semantics label. Pinned in Task 3.
5. Deleting contacts or the account leaves no files behind (best effort for contacts, in the function for the account). Pinned in Tasks 4 and 7.

---

### Task 1: The `avatars` bucket and `person.photo_path`

**Files:**
- Create: `supabase/migrations/<timestamp>_avatars.sql` (`supabase migration new avatars`)
- Create: `supabase/tests/avatars_test.sql`

- [x] **Step 1: Write the failing pgTAP test** `supabase/tests/avatars_test.sql`, shaped like `person_rls_test.sql`: users `…0a` and `…0b`; `plan(10)`:
  - `results_eq` on `select public, file_size_limit, allowed_mime_types from storage.buckets where id = 'avatars'` → `(false, 262144, '{image/jpeg,image/png,image/webp}')`.
  - `has_column('public', 'person', 'photo_path')`.
  - As `a`: `lives_ok`: `insert into storage.objects (bucket_id, name) values ('avatars', '0000…000a/f1')`.
  - As `a`: `throws_ok … '42501'`: insert `('avatars', '0000…000b/f2')`.
  - As `a`: `throws_ok … '42501'`: insert `('avatars', 'f3')` (no folder).
  - As `a`: `is(count(*) from storage.objects where bucket_id = 'avatars', 1)`.
  - As `b`: `is(count(*) …, 0)`: `b` sees nothing of `a`'s.
  - As `b`, with `set local storage.allow_delete_query = 'true'`: `delete from storage.objects where name = '0000…000a/f1'`; back as `a`, `is(count(*) …, 1)`: still there.
  - As `a`, the same delete: `is(count(*) …, 0)`.
  - As `anon`: `is(count(*) from storage.objects where bucket_id = 'avatars', 0)`.
- [x] **Step 2: Run** `supabase db reset && supabase test db`. Expected: `avatars_test.sql` fails (no bucket).
- [x] **Step 3: Write the migration.**

```sql
-- Profile photos (#239). A private bucket: contacts' photos are third
-- parties' personal data. One folder per user, `<uid>/<random>`. 256 px
-- JPEGs are ~20 KB; the limit refuses anything far off.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', false, 262144,
        '{image/jpeg,image/png,image/webp}');

create policy avatars_select_own on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy avatars_insert_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy avatars_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'avatars'
              and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy avatars_delete_own on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars'
         and (storage.foldername(name))[1] = (select auth.uid())::text);

-- Null: initials. Written only on its own (PeopleRepository.setPhoto).
alter table public.person add column photo_path text;
```

- [x] **Step 4: Run** `supabase db reset && supabase test db`. Expected: all pass, `schema_rls_test.sql` included (the new column needs no grant change: `person` grants update on the table).
- [x] **Step 5: Commit** `feat(contacts): avatars bucket and photo_path (#239)`.

### Task 2: `lib/core/photos/`: sniff, repository, swap, provider, picker

**Files:**
- Modify: `pubspec.yaml`, `pubspec.lock` (`flutter pub add image_picker`), `ios/Runner/Info.plist`
- Modify: `lib/features/contacts/data/people_repository.dart` (`peopleFailureFrom`)
- Create: `lib/core/photos/photo.dart`, `lib/core/photos/photo_repository.dart`, `lib/core/photos/photo_picker.dart`
- Create: `test/core/photos/photo_test.dart`, `test/core/photos/swap_photo_test.dart`, `test/core/photos/fake_photo_repository.dart`, `test/core/photos/fake_photo_picker.dart`

- [x] **Step 1: Write the failing tests.**
  - `photo_test.dart`: `imageType` returns `image/jpeg` for `[0xFF, 0xD8, 0xFF, …]`, `image/png` for the 8-byte PNG signature, `image/webp` for `RIFF????WEBP`, null for `[0, 1, 2]` and for an empty list. `peopleFailureFrom(StorageException('x'))` is `PeopleFailure.unknown`.
  - `swap_photo_test.dart`, with `FakePhotoRepository` (records `upload(<type>)` / `discard(<paths>)`, returns `u1/new` from upload, `failWith`):
    - bytes and an old path: calls are `upload(image/jpeg)`, the write receives `u1/new`, then `discard(u1/old)`.
    - `bytes: null`: no upload, the write receives null, then `discard(u1/old)`.
    - no old path: nothing discarded.
    - the write throws: `discard(u1/new)`, `u1/old` kept, the error rethrown.
    - unknown bytes: throws `PeopleFailure.unknown`, no upload, no write.
- [x] **Step 2: Run** `flutter test test/core/photos`. Expected: compile failure.
- [x] **Step 3: `flutter pub add image_picker`** (1.2.4 at planning time), then put the comment above it in `pubspec.yaml`:

```yaml
  # The photo picker on Android and iOS, a file dialog on the web, resized on
  # the device (#239). Nothing in the SDK opens either.
  image_picker: ^1.2.4
```

  In `ios/Runner/Info.plist`, next to `NSContactsUsageDescription`:

```xml
	<key>NSPhotoLibraryUsageDescription</key>
	<string>Loomia uses the photo you pick as a contact's or your own picture.</string>
```

- [x] **Step 4: `lib/core/photos/photo.dart`**: the pure part.

```dart
import 'dart:typed_data';

/// The image's MIME type from its first bytes: one of the three the bucket
/// takes, or null.
String? imageType(Uint8List bytes) {
  bool starts(List<int> sig, [int at = 0]) =>
      bytes.length >= at + sig.length &&
      [for (var i = 0; i < sig.length; i++) bytes[at + i] == sig[i]].every((b) => b);
  if (starts([0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (starts([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) return 'image/png';
  if (starts('RIFF'.codeUnits) && starts('WEBP'.codeUnits, 8)) return 'image/webp';
  return null;
}
```

- [x] **Step 5: `lib/core/photos/photo_repository.dart`.**
  - `PhotoRepository(SupabaseClient client)` on bucket `avatars`.
  - `Future<String> upload(Uint8List bytes)`: `imageType(bytes) ?? (throw PeopleFailure.unknown)`. Path `'${uid}/${_name()}'` where `uid = _client.auth.currentUser!.id` and `_name()` is 16 `Random.secure()` bytes as hex. `uploadBinary(path, bytes, fileOptions: FileOptions(contentType: type, cacheControl: '604800'))`, through `guardPeople`. Returns the path.
  - `Future<void> discard(List<String> paths)`: empty → return. `storage.from('avatars').remove(paths)`; `catch (error, stack)` → `Sentry.captureException(error, stackTrace: stack)`, never rethrows.
  - `Future<String> signedUrl(String path)`: `createSignedUrl(path, 604800)` (7 days) through `guardPeople`.
  - `photoRepositoryProvider = Provider((ref) => PhotoRepository(ref.watch(supabaseClientProvider)))`.
  - `swapPhoto(PhotoRepository photos, {required Uint8List? bytes, required String? old, required Future<void> Function(String? path) write})`. Upload when `bytes != null`, then `write(path)`. On failure, `discard([path])` if uploaded, then rethrow. On success, `discard([old])` when `old != null && old != path`.
  - `photoUrlProvider = FutureProvider.family<String, String>((ref, path) => ref.watch(photoRepositoryProvider).signedUrl(path))`. Not auto-dispose: kept for the session. Add the comment `// ponytail: one signed-URL request per photo on screen; createSignedUrls in a batch if long lists feel slow.`
  - `photoProvider = Provider.family<ImageProvider?, String?>`: null path → null; else `ref.watch(photoUrlProvider(path)).value`, wrapped in `NetworkImage`, null while loading or failed.
  - In `people_repository.dart`, `peopleFailureFrom` gains `StorageException() => PeopleFailure.unknown,` before `Exception()`.
- [x] **Step 6: `lib/core/photos/photo_picker.dart`.** `PhotoPicker.pick() → Future<Uint8List?>`: `ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 256, maxHeight: 256, imageQuality: 85)`; null when cancelled, else `readAsBytes()`. `photoPickerProvider = Provider((ref) => const PhotoPicker())`. `FakePhotoPicker` returns a set `Uint8List?` and counts calls.
- [x] **Step 7: Run** `flutter test test/core/photos`, then the gate. Expected: green.
- [x] **Step 8: Commit** `feat(contacts): photo storage, picker and swap (#239)`.

### Task 3: Avatars show photos; the avatar control

**Files:**
- Modify: `lib/core/ui/loomia_avatar.dart`, `lib/core/ui/contact_row.dart`, `lib/core/ui/action_item.dart`, `lib/core/ui/ui_preview.dart`
- Create: `lib/core/ui/avatar_control.dart`, `lib/core/ui/preview_photo.dart`
- Modify: `lib/l10n/app_en.arb`, `test/previews_test.dart`
- Create: `test/core/ui/loomia_avatar_test.dart`, `test/core/ui/avatar_control_test.dart`

- [x] **Step 1: Write the failing tests.**
  - `loomia_avatar_test.dart`:
    - Without a photo: `find.text('MD')`.
    - With `MemoryImage(previewPhoto)`, after `tester.runAsync(precacheImage…)` and a pump: an `Image` is shown and the initials sit under it (still in the tree).
    - With a `MemoryImage` of junk bytes: no exception, `find.text('MD')` visible.
    - In each case, `tester.getSemantics(find.byType(LoomiaAvatar))` has label `Marie Dupont`.
    - `PhotoAvatar(photoPath: null)` builds with no `ProviderScope`.
  - `avatar_control_test.dart`:
    - Tapping opens a menu with "Choose photo" only when `onRemove` is null, and with both otherwise.
    - "Choose photo" calls `onChoose`. While its `Completer` is pending, a `CircularProgressIndicator` shows, the camera badge is gone and the control ignores taps. Once completed, the badge is back.
    - The control has a button semantics label "Change photo".
- [x] **Step 2: Run** them. Expected: compile failure.
- [x] **Step 3: `LoomiaAvatar`** gains `final ImageProvider? photo`. With one, the initials container is under, in a `Stack`, `ClipOval(child: Image(image: photo, width: d, height: d, fit: BoxFit.cover, frameBuilder: (_, child, frame, sync) => frame == null && !sync ? const SizedBox.shrink() : child, errorBuilder: (_, _, _) => const SizedBox.shrink(), excludeFromSemantics: true))`. `Semantics(label: name)` unchanged.
  `PhotoAvatar({required String name, String? photoPath, AvatarSize size})`: `photoPath == null` → `LoomiaAvatar(name:, size:)`; else `Consumer(builder: (_, ref, _) => LoomiaAvatar(name:, size:, photo: ref.watch(photoProvider(photoPath))))`.
  `ContactRow` and `ActionItem` gain `String? photoPath`, and use `PhotoAvatar` where they used `LoomiaAvatar`. `ContactRow`'s `_Face` passes it through.
- [x] **Step 4: `AvatarControl`** (`StatefulWidget`): `name`, `ImageProvider? photo`, `Future<void> Function() onChoose`, `Future<void> Function()? onRemove`.
  - Layout: a `MenuAnchor` around a `Stack` of `LoomiaAvatar(size: header, photo:)` and either a bottom-right camera badge or, while busy, a `CircularProgressIndicator` sized to the header diameter. The badge is a `primary` circle, `Icons.photo_camera_outlined` in `onPrimary`, 2 px `surface` ring, size `AvatarSize.inline.diameter`.
  - Menu items:
    - `MenuItemButton(leadingIcon: Icon(Icons.image_outlined), child: Text(l10n.photoChoose))`.
    - When `onRemove != null`, `MenuItemButton(leadingIcon: Icon(Icons.delete_outline_rounded), child: Text(l10n.photoRemove))`.
  - The tap target is an `InkWell(customBorder: CircleBorder())`, wrapped in `Semantics(button: true, label: l10n.photoChange)` with a `Tooltip` of the same text. Disabled while busy.
  - Busy: `setState(() => _busy = true)`, `try { await run(); } finally { if (mounted) setState(() => _busy = false); }`. Errors are the caller's to show.
- [x] **Step 5: Copy** in `app_en.arb`:
  - `photoChoose`: "Choose photo". Description: menu item on a contact's or your own avatar, opens the photo picker or a file dialog.
  - `photoRemove`: "Remove photo". Description: menu item, back to initials, or to the Google picture for your own.
  - `photoChange`: "Change photo". Description: screen-reader label and tooltip of the tappable avatar.

  Then run `flutter gen-l10n`.
- [x] **Step 6: Preview photo.** Generate a 64×64 PNG (two warm tones, a circle "face"): `python3 -c` with `zlib`/`struct`, no package. Embed it as `final Uint8List previewPhoto = base64Decode('…')` in `lib/core/ui/preview_photo.dart`, with the comment "Stand-in for previews and tests: never a real face, never the network."
- [x] **Step 7: `ui_preview.dart`**: under the Avatar row, a second row with `LoomiaAvatar(photo: MemoryImage(previewPhoto))` at each size. Below it, the three `AvatarControl` states from the Figma board: photo, no photo, and uploading. The uploading one uses an `initiallyBusy` constructor flag (default false, previews only), so a static preview can show the ring. Raise the `components_*` preview height in `previews_test.dart` if the board outgrows 1800.
  In `previews_test.dart`, after `pumpAndSettle`: `await tester.runAsync(() async { for (final element in find.byType(Image).evaluate()) { await precacheImage((element.widget as Image).image, element); } }); await tester.pumpAndSettle();`.
- [x] **Step 8: Run** the gate. Expected: green; `components_*` goldens differ on Linux (regenerated in CI).
- [x] **Step 9: Commit** `feat(ui): photo avatars and the avatar control (#239)`.

### Task 4: A person's photo in the book

**Files:**
- Modify: `lib/features/contacts/domain/person.dart`, `lib/features/contacts/data/people_repository.dart`, `lib/features/contacts/presentation/people_controller.dart`
- Modify: `test/features/contacts/fake_people_repository.dart`, `test/features/contacts/data/people_repository_test.dart`, `test/features/contacts/presentation/people_controller_test.dart`

- [x] **Step 1: Write the failing tests.**
  - Repository:
    - `personFromRow(_row({'photo_path': 'u1/abc'})).photoPath == 'u1/abc'`, and a blank path reads as null.
    - `personToRow(person)` has no `photo_path` key.
  - Controller (with `FakePhotoRepository` and `FakePeopleRepository` overridden):
    - `setPhoto(marie, bytes)`: the fake records `setPhoto(p1, u1/new)`, the book's Marie has `photoPath == 'u1/new'`, and her old `u1/old` is discarded.
    - `setPhoto(marie, null)`: the path is cleared and the old file discarded.
    - `remove(['p1', 'p2'])`, with only p1 having a photo, discards `[u1/old]` after the delete. A failed delete discards nothing.
- [x] **Step 2: Run** them. Expected: failures.
- [x] **Step 3: `Person.photoPath`** (`String?`, doc: "The Storage path of their photo; null shows initials."). Add it to the constructor and to `_copy`. `personFromRow` reads `photoPath: _text(row['photo_path'])`. Leave `personToRow` alone and say why in its doc: "nor the photo: only setPhoto writes it".
- [x] **Step 4: `PeopleRepository.setPhoto(String id, String? path) => _write(id, {'photo_path': path})`.** In the fake, record `setPhoto(id, path)` and update the store.
- [x] **Step 5: `PeopleController`:**

```dart
  /// [bytes] null removes it. The old file goes once the new path is saved.
  Future<void> setPhoto(Person person, Uint8List? bytes) => swapPhoto(
    ref.read(photoRepositoryProvider),
    bytes: bytes,
    old: (_find(person.id) ?? person).photoPath,
    write: (path) async =>
        _replace(await _repository.setPhoto(person.id, path)),
  );
```

  In `remove`, read `final photos = [for (final id in ids) ?_find(id)?.photoPath];` before the delete. After `_change`, call `unawaited(ref.read(photoRepositoryProvider).discard(photos))`. Capture the repository before the `await`.
- [x] **Step 6:** In `test/app/app_harness.dart`, `pumpLoomia` gains `FakePhotoRepository? photos` and `FakePhotoPicker? picker`, overriding `photoRepositoryProvider` and `photoPickerProvider` (defaults: new fakes). Run the gate. Expected: green.
- [x] **Step 7: Commit** `feat(contacts): a person's photo (#239)`.

### Task 5: Photos on the contact page and everywhere people show

**Files:**
- Modify: `lib/features/contacts/presentation/contact_details.dart`, `contact_page.dart`, `contact_list.dart`, `next_step_section.dart`, `contacts_preview.dart`
- Modify: `lib/features/calendar/presentation/people_picker.dart`, `event_page.dart`; `lib/features/today/presentation/today_page.dart`; `lib/features/team/presentation/check_in_items.dart`
- Modify: `test/features/contacts/presentation/contact_details_test.dart`, `contacts_page_test.dart`, `test/previews_test.dart`

- [x] **Step 1: Write the failing tests.**
  - `contact_details_test.dart`: the header is an `AvatarControl`. With `photo: null`, its menu has no "Remove photo". With a photo, it has one, and tapping it calls `onRemovePhoto`.
  - `contacts_page_test.dart`, on Marie's page via `pumpLoomia` with a `FakePhotoPicker` returning JPEG bytes:
    - Tap the avatar, then "Choose photo": the fakes record `upload(image/jpeg)` and `setPhoto(p1, …)`, and the menu now offers "Remove photo".
    - Picker returns null: no upload.
    - `FakePeopleRepository.failWith = PeopleFailure.network` on `setPhoto`: the snackbar shows `peopleFailureNetwork`, and the new file is discarded.
- [x] **Step 2: Run** them. Expected: failures.
- [x] **Step 3: `ContactDetails`** gains `ImageProvider? photo`, `Future<void> Function() onChoosePhoto`, `Future<void> Function()? onRemovePhoto`. The header's `LoomiaAvatar` becomes `AvatarControl(name: person.name, photo: photo, onChoose: onChoosePhoto, onRemove: person.photoPath == null ? null : onRemovePhoto)`.
- [x] **Step 4: `ContactPage`** passes `photo: ref.watch(photoProvider(person.photoPath))` and both handlers:

```dart
      onChoosePhoto: () async {
        final bytes = await ref.read(photoPickerProvider).pick();
        if (bytes == null || !context.mounted) return;
        await writePeople(context, ref, (people) => people.setPhoto(person, bytes));
      },
      onRemovePhoto: () =>
          writePeople(context, ref, (people) => people.setPhoto(person, null)),
```

  `writePeople` returns `Future<bool>`; wrap the remove as `() async { await writePeople(...); }` to match the type.
- [x] **Step 5: Every row passes `photoPath: person.photoPath`**: `contact_list.dart:321`, `people_picker.dart:107`, `event_page.dart:433` (`ContactRow`); `today_page.dart:567`, `check_in_items.dart:23` (`ActionItem`). Not `next_step_section.dart`: its items show an icon instead of the avatar, the person being on screen already. Leave `import_contacts_page.dart` alone (#240).
- [x] **Step 6: Preview**: in `contacts_preview.dart`, add `@Preview(group: 'Contacts', name: 'Person — photo — light', size: Size(390, 844))`, built from `_details(photo: MemoryImage(previewPhoto))`. Add `'contact_photo_mobile_light'` to `previews_test.dart`. Existing contact goldens change (the camera badge).
- [x] **Step 7: Run** the gate. Expected: green.
- [x] **Step 8: Commit** `feat(contacts): choose and remove a contact's photo (#239)`.

### Task 6: The user's photo

**Files:**
- Modify: `lib/features/auth/domain/account.dart`, `lib/features/auth/data/auth_repository.dart`, `test/features/auth/fake_auth_repository.dart`
- Modify: `lib/features/settings/presentation/account_settings.dart`, `settings_page.dart`; `lib/app/shell/app_shell.dart`
- Modify: `test/features/settings/presentation/settings_page_test.dart` (the real `account` getter has no unit test today; reading `avatar_path` is one line next to `locale`, checked on device in Task 7)

- [x] **Step 1: Write the failing tests** in `settings_page_test.dart`, Account section open, `FakePhotoPicker` returning JPEG bytes:
  - "Choose photo" records `upload(image/jpeg)` then `updateAvatarPath(u1/new)` on the fake auth. Then "Remove photo" records `updateAvatarPath(null)` and discards `u1/new`.
  - `updateAvatarPath` failing with an `AuthFailure`: a snackbar with `authFailureCopy`, and the new file discarded.
  - With `account.avatarPath` set and `photoProvider` overridden to a `MemoryImage`, the sidebar (desktop), the top-bar `AccountButton` (mobile) and the Settings list's leading avatar each show an `Image`.
- [x] **Step 2: Run** them. Expected: failures.
- [x] **Step 3: `Account.avatarPath`** (`String?`, doc: "The Storage path of the user's own photo (`avatar_path`); null shows initials."). `AuthRepository.account` reads `metadata['avatar_path'] as String?`. `updateAvatarPath(String? path) => _guard(() => _auth.updateUser(UserAttributes(data: {'avatar_path': path})))`. The fake records the call, rebuilds `account` with the path and emits `userUpdated`, like `updateLocale`.
- [x] **Step 4: `AccountSettings`**: above the first `SettingsGroup`, centred, an `AvatarControl` with:
  - `name: account.displayName`
  - `photo: ref.watch(photoProvider(account.avatarPath))`
  - `onChoose`: pick, then `_photo(bytes)`
  - `onRemove`: `account.avatarPath == null ? null : () => _photo(null)`
  - then `SizedBox(height: AppSpacing.xl)`.

  `_photo` captures the messenger and l10n, then `swapPhoto(ref.read(photoRepositoryProvider), bytes:, old: account.avatarPath, write: ref.read(authRepositoryProvider).updateAvatarPath)`. `on AuthFailure` shows `authFailureCopy`; anything else (the upload) `peopleFailureCopy(peopleFailureFrom(error))`, in a `SnackBar`. Not `guardPeople`: it would turn an `AuthFailure` into a generic one. It does not go through `run`/`FormError`: the Figma shows the ring on the avatar, not a form error.
- [x] **Step 5: The shell and the Settings list:** `app_shell.dart:191` and `:280`, `settings_page.dart:244` become `PhotoAvatar(photoPath: account.avatarPath)`: one argument each, the same resolver as the rows.
- [x] **Step 6: Run** the gate. Expected: green.
- [x] **Step 7: Commit** `feat(settings): your own photo (#239)`.

### Task 7: Account deletion, docs, device check

**Files:**
- Modify: `supabase/functions/delete-account/index.ts`, `docs/architecture.md`

- [x] **Step 1: `delete-account`** empties the folder before deleting the user (Storage objects don't cascade):

```ts
    const id = ctx.userClaims!.id
    const bucket = ctx.supabaseAdmin.storage.from('avatars')
    // Storage objects do not cascade with the user: empty their folder first.
    for (;;) {
      const { data, error } = await bucket.list(id, { limit: 1000 })
      if (error) {
        console.error('delete-account: list failed', error)
        return Response.json({ error: 'delete_failed' }, { status: 500 })
      }
      if (data.length === 0) break
      const { error: removeError } = await bucket.remove(data.map((f) => `${id}/${f.name}`))
      if (removeError) {
        console.error('delete-account: remove failed', removeError)
        return Response.json({ error: 'delete_failed' }, { status: 500 })
      }
    }
```

  Leave the existing `deleteUser(id)` call after it, unchanged.
- [x] **Step 2: `docs/architecture.md` → Backend:** one bullet: "Files live in Storage buckets created by migration. `avatars` is private, one folder per user (`<uid>/…`), guarded by policies on `storage.objects`; a row holds the path, never a URL, and the device signs URLs. Objects do not cascade with the user: `delete-account` empties the folder." In *Not yet present*, keep `profiles` and add "(the user's photo path is in `user_metadata` too, until linking users needs a profile others can read, #238)".
- [ ] **Step 3: Device check**, local stack (`supabase start`, `supabase functions serve`):
  - Android: choose a photo for Marie. It shows in the list, the header, Today and an event's attendees.
  - iOS: the same, with no permission prompt.
  - Web: the file dialog opens, and a 4 MB PNG comes back resized under 256 KB.
  - Remove the photo: the file is gone from Studio → Storage.
  - Upload a 300 KB file through Studio's API: refused (413).
  - Delete the account: the folder is empty.

  Note anything that does not hold in the PR.

  Done while implementing, against the local stack through the Storage API:
  - Own folder: 200.
  - 300 KB: 413.
  - `text/plain`: 415.
  - Another user's folder: 403 (RLS).
  - The signed URL serves the file; the public URL does not.
  - `delete-account` returns 204, leaving no objects and no user.
  - `flutter build web --release`, `apk --debug` and `ios --debug --no-codesign` all build.

  Left for a device: the photo picker on Android and iOS, the web file dialog's resize, and a photo showing in each place.
- [x] **Step 4: Run** the gate, then `graphify update .`.
- [x] **Step 5: Commit** `feat(auth): delete-account removes photos (#239)` and `docs: storage conventions (#239)`. Push `feature/239-photo-upload`, open the PR with `Closes #239`, then let CI regenerate the goldens.
