import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:loomia/core/photos/photo.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Photos in the private `avatars` bucket, one folder per user (#239). Rows
/// hold the path; the device signs a URL to show it. Errors come through as
/// thrown (`StorageException`, a socket error, [FormatException]): each
/// caller turns them into its own failure (`peopleFailureFrom`).
class PhotoRepository {
  PhotoRepository(this._client);

  final SupabaseClient _client;

  static const String _bucket = 'avatars';

  /// A week: URLs are cached for the session, and files never change under a
  /// path (each upload gets a new one).
  static const int _week = 7 * 24 * 60 * 60;

  StorageFileApi get _files => _client.storage.from(_bucket);

  /// Puts [bytes] under a new random name in the user's folder and returns
  /// the path. Not a JPEG, PNG or WebP: [FormatException].
  // ponytail: HEIC is refused, not converted; add a decode/re-encode if users
  // hit it.
  Future<String> upload(Uint8List bytes) async {
    final type =
        imageType(bytes) ?? (throw const FormatException('Not an image'));
    final path = '${_client.auth.currentUser!.id}/${_name()}';
    await _files.uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: type, cacheControl: '$_week'),
    );
    return path;
  }

  /// Best effort, never throws: a file left behind costs a few KB, a failure
  /// shown to the user would be about something they did not ask for.
  Future<void> discard(List<String> paths) async {
    if (paths.isEmpty) return;
    try {
      await _files.remove(paths);
    } catch (error, stack) {
      // Offline, the file staying behind is expected, not a bug.
      if (error is StorageException && storageUnreachable(error)) return;
      _log.severe('discard failed', error, stack);
    }
  }

  Future<String> signedUrl(String path) => _files.createSignedUrl(path, _week);

  static String _name() {
    final random = Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}

final photoRepositoryProvider = Provider<PhotoRepository>(
  (ref) => PhotoRepository(ref.watch(supabaseClientProvider)),
);

final _log = Logger('photos');

/// Storage never answered: `storage_client` wraps the socket or client error
/// and puts its type, not an HTTP status, in [StorageException.statusCode].
bool storageUnreachable(StorageException error) {
  final status = error.statusCode;
  return status != null && int.tryParse(status) == null;
}

/// Puts [bytes] (null: no photo) where [old] was. The new file first, then
/// [write] saves its path, then the old file goes. [write] failing: the new
/// file goes, the old one stays, and the error is rethrown.
Future<void> swapPhoto(
  PhotoRepository photos, {
  required Uint8List? bytes,
  required String? old,
  required Future<void> Function(String? path) write,
}) async {
  final path = bytes == null ? null : await photos.upload(bytes);
  try {
    await write(path);
  } catch (_) {
    if (path != null) await photos.discard([path]);
    rethrow;
  }
  if (old != null && old != path) await photos.discard([old]);
}

/// A signed URL per path, kept for the session.
// ponytail: one signed-URL request per photo on screen; createSignedUrls in a
// batch if long lists feel slow.
final photoUrlProvider = FutureProvider.family<String, String>(
  (ref, path) => ref.watch(photoRepositoryProvider).signedUrl(path),
);

/// The photo at [path], once its URL is known. Null without a path, while
/// loading, and when signing failed: the avatar shows initials.
final photoProvider = Provider.family<ImageProvider?, String?>((ref, path) {
  if (path == null) return null;
  final url = ref.watch(photoUrlProvider(path)).value;
  return url == null ? null : NetworkImage(url);
});
