import 'dart:typed_data';

/// The image's MIME type from its first bytes: one of the three the `avatars`
/// bucket takes, or null.
String? imageType(Uint8List bytes) {
  bool startsWith(List<int> signature, [int at = 0]) {
    if (bytes.length < at + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[at + i] != signature[i]) return false;
    }
    return true;
  }

  if (startsWith(const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
  if (startsWith(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return 'image/png';
  }
  if (startsWith('RIFF'.codeUnits) && startsWith('WEBP'.codeUnits, 8)) {
    return 'image/webp';
  }
  return null;
}
