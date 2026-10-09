import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/photos/photo_repository.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:material_ui/material_ui.dart';

/// The user's own photo (#241): the one they uploaded, else their Google
/// picture, else null (initials).
final accountPhotoProvider = Provider<ImageProvider?>((ref) {
  final account = ref.watch(accountProvider);
  if (account?.avatarPath case final path?) {
    return ref.watch(photoProvider(path));
  }
  if (account?.googlePicture case final url?) {
    // Google's default is 96 px, blurry at 56 dp on a 3× screen.
    return NetworkImage(googlePictureAt(url, 256));
  }
  return null;
});

/// [url] asking Google for a [px] square: its URLs end in `=s96-c`. One
/// without a size is left as it is.
String googlePictureAt(String url, int px) =>
    url.replaceFirst(RegExp(r'=s\d+(-c)?$'), '=s$px-c');
