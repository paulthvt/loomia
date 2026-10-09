import 'dart:typed_data';

import 'package:loomia/core/photos/photo_picker.dart';

/// Returns [picked] (null: cancelled) and counts the calls.
class FakePhotoPicker implements PhotoPicker {
  FakePhotoPicker([this.picked]);

  Uint8List? picked;
  int picks = 0;

  @override
  Future<Uint8List?> pick() async {
    picks++;
    return picked;
  }
}
