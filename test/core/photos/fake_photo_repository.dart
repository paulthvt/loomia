import 'dart:async';
import 'dart:typed_data';

import 'package:loomia/core/photos/photo.dart';
import 'package:loomia/core/photos/photo_repository.dart';

/// Records calls; uploads return `u1/new` unless [nextPath] says otherwise.
class FakePhotoRepository implements PhotoRepository {
  /// One entry per call, e.g. `upload(image/jpeg)`, `discard(u1/old)`.
  final List<String> calls = <String>[];

  String nextPath = 'u1/new';

  /// Thrown by the next upload when set.
  Object? failWith;

  @override
  Future<String> upload(Uint8List bytes) async {
    final type = imageType(bytes) ?? (throw const FormatException('image'));
    calls.add('upload($type)');
    final failure = failWith;
    if (failure != null) throw failure;
    return nextPath;
  }

  @override
  Future<void> discard(List<String> paths) async {
    if (paths.isEmpty) return;
    calls.add('discard(${paths.join(', ')})');
  }

  @override
  Future<String> signedUrl(String path) async {
    calls.add('signedUrl($path)');
    return 'https://photos.test/$path';
  }
}

/// The first bytes of a JPEG: enough for [imageType].
final Uint8List jpegBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0]);
