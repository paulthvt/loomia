# Profile photos — design

Epic: #238 (sub-issues #239–#241). Figma: [Profile photos — #238](https://www.figma.com/design/spz2vsSK8gbt1Ok2rW1sdQ/Loomia?node-id=286-5902), on page
"04 — Screens (Light)". The camera badge, upload ring and photo menu are drawn
in the frames, not components; the faces are stand-ins from pravatar.cc.

## Intent

A face is recognised faster than initials. Contacts and the user get a photo
where one exists: uploaded by hand, brought from the phone's address book, or,
for the user, the Google picture. Initials stay the fallback everywhere.

## Decisions

| Question | Decision |
| --- | --- |
| Where files live | A private Supabase Storage bucket `avatars`, folder `<owner_id>/`. Photos of contacts are third parties' personal data: never public. |
| Size | 256 px on the long side, resized on the device. The largest avatar is 56 dp, 168 px at 3×. About 15–20 KB a photo: the free tier's 1 GB holds ~50,000, and its 10 GB egress a month is the real limit. No server-side transform (Pro plan only on hosted). |
| Bucket limits | 256 KB per file, `image/jpeg`, `image/png`, `image/webp`. A larger file is refused by Storage, not just by the app. |
| File names | A new random name per upload (`<owner_id>/<uuid>`), the old file deleted after. A URL then never points at a changed image, so no cache goes stale. |
| Showing | A signed URL per path, valid 7 days, cached in a Riverpod family for the session; `Image.network` caches the bytes. One request per avatar on screen. |
| Picker | `image_picker` (flutter.dev): the system photo picker on Android and iOS (no permission prompt), a file dialog on the web. It resizes with `maxWidth`/`maxHeight`. |
| Camera | Not now: a camera permission on both phones for little gain. Add when asked. |
| Cropping | None: centre-cropped into the circle (`BoxFit.cover`). A crop screen means another package. Add if centre-cropping proves wrong. |
| The user's photo | `avatar_path` in user metadata (like `locale`), file `<owner_id>/<uuid>`. No `person` row for the user. |
| Order for the user | Uploaded photo, else the Google picture, else initials. Removing the upload shows the Google picture again. |
| Google picture | `avatar_url` from user metadata. Supabase fills it from Google's default `profile` scope and refreshes it on each Google sign-in: used as is, not copied. Apple and email accounts have none. |
| Phone import | The thumbnail (`ContactProperty.photoThumbnail`) of the people ticked only, uploaded as is (already small, typically 96–150 px). Over 256 KB: skipped. A failed upload never fails the import. |
| Re-import | The import only creates people. Existing ones are not touched, photo included. |
| Removing | "Remove photo" clears the column or metadata, then deletes the file. |
| Deleting | Deleting contacts deletes their files. Deleting the account empties the user's folder in `delete-account` before deleting the user: Storage objects do not cascade. |
| A "me" contact | Not here. Linking Loomia users (username, doTERRA username, upline/frontline) needs a profile other users can read: a `profile` table. Its migration moves `avatar_path` there and adds a storage read rule for linked users. |

## 1. Storage and data

### #239 — migration

- Bucket: `insert into storage.buckets (id, name, public, file_size_limit,
  allowed_mime_types) values ('avatars', 'avatars', false, 262144,
  '{image/jpeg,image/png,image/webp}')`. In the migration, not the dashboard,
  so local and hosted match.
- Policies on `storage.objects`: select, insert, update, delete, each
  `to authenticated using / with check (bucket_id = 'avatars' and
  (storage.foldername(name))[1] = (select auth.uid())::text)`.
- `person.photo_path text`. Null: no photo.

Storage RLS is the boundary: a `photo_path` pointing into someone else's
folder signs nothing.

## 2. Domain and data (Dart)

- `Person.photoPath`, read and written by `PeopleRepository` like the other
  columns.
- `Account.avatarPath` (from `avatar_path`) and `Account.googlePicture` (from
  `avatar_url`), read in `AuthRepository`.
- `lib/features/contacts/data/photo_repository.dart`:
  - `upload(Uint8List bytes, String contentType) → path`: puts
    `<uid>/<uuid>`.
  - `remove(List<String> paths)`.
  - `signedUrl(String path) → String`.
- `photoUrlProvider`: a family on the path, `keepAlive`, returning the signed
  URL.
  `// ponytail: one request per avatar; createSignedUrls in a batch if lists
  feel slow.`
- Setting a photo: upload, write the new path, remove the old file. Writing
  the path fails: remove the new file. The old one stays until the write
  succeeds.
- `PeopleRepository.delete(ids)`: reads their paths, deletes the rows, then
  removes the files. A failed file removal is reported to Sentry, not to the
  user.
  `// ponytail: an orphan file is possible; sweep the bucket against person.photo_path if it ever matters.`

## 3. Screens

### `LoomiaAvatar`

Gains `ImageProvider? photo`. With one: the image, circular, `BoxFit.cover`,
the initials shown until it loads and if it fails. `Semantics` still reads the
name. `LoomiaAvatarGroup` and `ContactRow` pass a photo through. Every place
that shows a person passes it: contact list, contact header, Today, Calendar
attendees, pickers. The sidebar, the mobile top bar and Settings show the
user's.

### Contact header

The header avatar (56) is tappable, with a small camera badge. Tapping opens a
menu: **Choose photo** and, when there is one, **Remove photo**. While
uploading: a progress ring over the avatar. Errors: the screen's usual
snackbar.

### Settings → Account

The same avatar control at the top, for the user. Remove shows the Google
picture when there is one, so the menu reads **Remove photo** either way.

### Add / edit someone

No photo field. The photo is set from the contact once saved, so the sheet
stays short.

## 4. Phone import (#240)

`PhoneContactsRepository.read()` adds `ContactProperty.photoThumbnail`;
`PhoneContact` gains `Uint8List? photo`. The import rows show it. After the
ticked people are saved, their photos are uploaded and their `photo_path` set,
a few at a time. The import screen does not wait for the uploads: they fill in
as they finish. The content type comes from the bytes (JPEG or PNG
signature); anything else is skipped.

## 5. Google picture (#241)

`Account.googlePicture` feeds the user's avatar as a `NetworkImage` when there
is no `avatarPath`. Nothing to ask: the scope is already granted at sign-in.

## 6. Delivery

| PR | Scope |
| --- | --- |
| #239 | Bucket and policies, `photo_path`, `image_picker`, `PhotoRepository`, `photoUrlProvider`, `LoomiaAvatar` with a photo everywhere, the control on the contact header and Settings → Account, deleting files with contacts and with the account. |
| #240 | Thumbnails read and uploaded by the phone import. |
| #241 | The Google picture as the user's fallback. |

`image_picker` needs, in the pubspec comment, its reason: nothing in the SDK
opens the photo picker or a file dialog. iOS shows the PHPicker, which asks
no permission, but `Info.plist` still gets `NSPhotoLibraryUsageDescription`
as the package README requires. Android uses the system photo picker.

## 7. Testing

- SQL `avatars_test.sql`: a user can insert, read and delete in their own
  folder; cannot read, insert or delete in another's; `anon` can do nothing;
  a file over 256 KB or of another type is refused.
- Unit: the content-type sniff (JPEG, PNG, other); the user's photo order
  (upload, Google, none).
- Widget: `LoomiaAvatar` with a photo, with a failing one (initials), without;
  the contact header menu with and without a photo; Settings → Account
  showing the Google picture.
- Goldens: one per new or changed `@Preview`, regenerated through CI. Golden
  photos come from a bundled test asset (`MemoryImage`), never the network.
