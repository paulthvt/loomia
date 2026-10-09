import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/photos/photo.dart';

Uint8List _bytes(List<int> bytes) => Uint8List.fromList(bytes);

void main() {
  group('imageType', () {
    test('reads a JPEG, a PNG and a WebP from their first bytes', () {
      expect(imageType(_bytes([0xFF, 0xD8, 0xFF, 0xE0])), 'image/jpeg');
      expect(
        imageType(_bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0])),
        'image/png',
      );
      expect(
        imageType(
          _bytes([...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits]),
        ),
        'image/webp',
      );
    });

    test('anything else is null', () {
      expect(imageType(_bytes([0, 1, 2])), isNull);
      expect(imageType(_bytes([])), isNull);
      expect(imageType(_bytes('RIFF'.codeUnits)), isNull);
    });
  });
}
