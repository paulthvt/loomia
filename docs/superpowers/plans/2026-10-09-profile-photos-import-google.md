# Profile photos — phone import and Google picture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The phone import brings each ticked contact's photo (#240). The user's avatar falls back to their Google picture when they have not uploaded one (#241). Both are part of #238.

**Architecture:**
- **#240:** `PhoneContactsRepository.read()` also reads the thumbnail; `PhoneContact` gains `photo`. The import rows show it through a new `ContactRow.photo`. After `addAll`, the page hands the new people's thumbnails to `PeopleController.addPhotos`, which uploads them four at a time through the existing `swapPhoto` and `setPhoto`, in the background.
- **#241:** `Account.googlePicture` comes from `avatar_url` in user metadata. `accountPhotoProvider` returns the uploaded photo if there is one, else the Google picture, else null. The four places that show the user's avatar read it.

**Tech Stack:** Flutter (`material_ui`), `flutter_riverpod` 3, `flutter_contacts`, Supabase Storage (from #239).

**Spec:** `docs/superpowers/specs/2026-10-09-profile-photos-design.md` §4, §5. Figma: [Profile photos — #238](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=286-5902) (no new frames: these reuse #239's avatar).

## Global Constraints

- No new dependency, no migration. Stage only changed files by path. If `flutter test` rewrites `pubspec.lock` (this machine resolves through a private mirror), revert it and never commit it.
- Dart: `package:loomia/...` imports; Material from `package:material_ui/material_ui.dart`; `lib/core` never imports `lib/features`.
- Quality gate per task: `dart format .`, `flutter analyze` ("No issues found!"), `flutter test`. Goldens from CI only (none expected to change).
- Branches: `feature/240-import-photos` (Tasks 1–2), then `feature/241-google-picture` off `main` once #240 is merged (Task 3). PR bodies `Closes #240` / `Closes #241`.

## Rulings made while planning

- **Photos match people by insert order.** `addAll` sends one insert and PostgREST returns the rows in that order. So the n-th added person gets the n-th ticked contact's thumbnail, and duplicate names don't confuse it.
  `// ponytail: relies on insert order; match on a client-sent id if it ever breaks.`
- **Upload failures are silent.** That includes a thumbnail over 256 KB, an unknown format, or no connection. The person keeps initials and the import has already succeeded. `swapPhoto` already discards a file whose path failed to save.
- **Four at a time,** so a 200-person import doesn't open 200 connections. The batches stop if the book is disposed (signed out).
- **The thumbnail is uploaded as is** (typically 96–150 px, a few KB): no resize, no new package.
- **`ContactRow.photo` (an `ImageProvider`) is added next to `photoPath`.** The import rows have bytes, not a Storage path. `photo` wins when both are set.
- **The Google picture is asked for at 256 px.** Google's URLs end in `=s96-c`, which is blurry at 56 dp × 3; `googlePictureAt` rewrites the size, and leaves URLs without one untouched. CORS checked: `lh3.googleusercontent.com` answers `Access-Control-Allow-Origin: *`, so the web build can show it.
- **Remove photo with only a Google picture is not offered.** There's nothing of ours to remove. After removing an upload, the Google picture shows again.
- **`accountPhotoProvider` lives in `features/auth/presentation/`**, beside the account it reads. `core` may not import `accountProvider`.

## Review Focus

1. The n-th ticked contact's photo lands on the n-th added person; someone without a photo gets none. Pinned in Task 2.
2. A failed upload neither fails the import nor shows an error. Pinned in Task 2.
3. Order for the user's avatar: upload, then Google, then initials; Remove brings the Google picture back. Pinned in Task 3.

---

## #240 — photos from the phone import

### Task 1: Read the thumbnail, show it on the import rows

**Files:**
- Modify: `lib/features/contacts/domain/phone_contact.dart`, `lib/features/contacts/data/phone_contacts_repository.dart`, `lib/core/ui/contact_row.dart`, `lib/features/contacts/presentation/import_contacts_page.dart`
- Modify: `test/features/contacts/domain/phone_contact_test.dart`, `test/features/contacts/presentation/import_contacts_page_test.dart`, `test/core/ui/contact_row_test.dart`

- [x] **Step 1: Write the failing tests.**
  - `contact_row_test.dart`: `ContactRow(photo: MemoryImage(previewPhoto))` builds a `LoomiaAvatar` whose `photo` is that image, needing no `ProviderScope`.
  - `import_contacts_page_test.dart`: a phone contact with `photo: jpegBytes` shows a `LoomiaAvatar` with a `MemoryImage`; one without shows initials.
- [x] **Step 2: Run** them. Expected: compile failure.
- [x] **Step 3:** `PhoneContact` becomes `({String name, String? phone, String? email, Uint8List? photo})`. Add `photo: null` to every existing literal (12, all in tests).
- [x] **Step 4:** `read()` asks for `{ContactProperty.phone, ContactProperty.email, ContactProperty.photoThumbnail}` and maps `photo: contact.photo?.thumbnail`.
- [x] **Step 5:** `ContactRow` gains `final ImageProvider? photo` (doc: "Shown instead of [photoPath]'s: bytes not yet in Storage, as on the import"). `_Face` builds `LoomiaAvatar(name:, size: row, photo:)` when it is set, else `PhotoAvatar` as now. The import row passes `photo: switch (contact.photo) { final bytes? => MemoryImage(bytes), null => null }`.
- [x] **Step 6: Run** the gate.
- [x] **Step 7: Commit** `feat(contacts): show phone photos on the import (#240)`.

### Task 2: Upload the photos of the people imported

**Files:**
- Modify: `lib/features/contacts/presentation/people_controller.dart`, `lib/features/contacts/presentation/import_contacts_page.dart`
- Modify: `test/features/contacts/presentation/people_controller_test.dart`, `test/features/contacts/presentation/import_contacts_page_test.dart`

- [x] **Step 1: Write the failing tests.**
  - Controller: `addPhotos({'1': jpegBytes, '3': jpegBytes})` records `setPhoto(1, u1/new)` and `setPhoto(3, u1/new)`, and both have `photoPath` in the book. With `FakePhotoRepository.failWith` set, it completes without throwing and the book is unchanged.
  - Import page: tick a contact with a photo and one without, then Import. After `pumpAndSettle`, the people fake has exactly one `setPhoto(new-…, u1/new)`, for the person with the photo. The `importDone` snackbar shows as before.
- [x] **Step 2: Run** them. Expected: failures.
- [x] **Step 3: `PeopleController.addPhotos(Map<String, Uint8List> photos)`**:

```dart
  /// Photos for people just added, by person id: four at a time, in the
  /// background. One that fails is left out; that person keeps initials.
  Future<void> addPhotos(Map<String, Uint8List> photos) async {
    final storage = ref.read(photoRepositoryProvider);
    final people = _repository;
    final queue = photos.entries.toList();
    for (var at = 0; at < queue.length; at += 4) {
      await Future.wait([
        for (final MapEntry(key: id, value: bytes) in queue.skip(at).take(4))
          swapPhoto(
            storage,
            bytes: bytes,
            old: null,
            write: (path) async => _replace(await people.setPhoto(id, path)),
          ).catchError((Object _) {}),
      ]);
      if (!ref.mounted) return;
    }
  }
```

- [x] **Step 4: Import page:** after `addAll` returns `added`, pair `added[i]` with the i-th ticked contact (the same sorted `_selected` order the drafts used). Collect those with a photo, then `unawaited(controller.addPhotos({...}))` before the snackbar. Read the controller before the first `await`.
- [x] **Step 5: Run** the gate.
- [x] **Step 6: Device check** (Android): import two contacts, one with a photo in the address book. The photo appears in the list within seconds; the other keeps initials. Done by the user before #247 was merged.
- [x] **Step 7: Commit** `feat(contacts): bring photos from the phone import (#240)`. Push, PR `Closes #240`.

## #241 — the Google picture

### Task 3: The user's photo falls back to Google's

**Files:**
- Modify: `lib/features/auth/domain/account.dart`, `lib/features/auth/data/auth_repository.dart`, `test/features/auth/fake_auth_repository.dart`
- Create: `lib/features/auth/presentation/account_photo.dart`, `test/features/auth/presentation/account_photo_test.dart`
- Modify: `lib/app/shell/app_shell.dart`, `lib/features/settings/presentation/settings_page.dart`, `lib/features/settings/presentation/account_settings.dart`, `test/features/settings/presentation/settings_page_test.dart`

- [x] **Step 1: Write the failing tests.**
  - `googlePictureAt`:
    - `https://lh3.googleusercontent.com/a/x=s96-c` becomes `…=s256-c`;
    - a URL with no `=s<n>` suffix is unchanged. (It takes a non-null URL: the provider only calls it with one, so no null case.)
  - `accountPhotoProvider`, with a container, overriding `accountProvider` and `photoRepositoryProvider`:
    - with an `avatarPath`: a `NetworkImage` of the signed URL;
    - with only `googlePicture`: a `NetworkImage` of the 256 px Google URL;
    - with neither: null.
  - Settings, with an account that has `googlePicture` and no `avatarPath`:
    - the Account control shows an image;
    - its menu has no Remove photo;
    - after Choose photo, Remove photo appears, and removing it calls `updateAvatarPath(null)`.
- [x] **Step 2: Run** them. Expected: failures.
- [x] **Step 3:** `Account.googlePicture` (`String?`, doc: "The picture Google gave at sign-in (`avatar_url`, refreshed by Supabase on each Google sign-in); null for email and Apple accounts."). `AuthRepository.account` reads `metadata['avatar_url'] as String?`. The fake carries it through each copy.
- [x] **Step 4: `account_photo.dart`.**
  - `googlePictureAt(String? url, int px)`: replaces a trailing `=s\d+(-c)?` with `=s$px-c`.
  - `accountPhotoProvider = Provider<ImageProvider?>`:
    - `account?.avatarPath` set → `ref.watch(photoProvider(path))`;
    - else `googlePicture` set → `NetworkImage(googlePictureAt(url, 256))`;
    - else null.
- [x] **Step 5:** The shell sidebar and `AccountButton` (`app_shell.dart`) and the Settings list (`settings_page.dart`) go back from `PhotoAvatar(photoPath: account.avatarPath)` to `LoomiaAvatar(photo: ref.watch(accountPhotoProvider))`. So does `AccountSettings`'s control. Its `onRemove` stays tied to `avatarPath`.
- [x] **Step 6: Run** the gate.
- [ ] **Step 7: Device check:** sign in with Google on the web and on Android. The Google picture shows in the sidebar or top bar and in Settings. Upload a photo: it replaces the Google one. Remove it: the Google one is back.
- [x] **Step 8: Commit** `feat(auth): the Google picture as your photo (#241)`. Push, PR `Closes #241`.
