import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// The system photo picker on Android and iOS, a file dialog on the web.
class PhotoPicker {
  const PhotoPicker();

  /// The largest avatar is 56 dp, 168 px at 3×: 256 is sharp and ~20 KB.
  static const double _side = 256;

  /// Null when cancelled. Resized on the device, so the bucket's 256 KB limit
  /// holds.
  Future<Uint8List?> pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: _side,
      maxHeight: _side,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  }
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => const PhotoPicker());
