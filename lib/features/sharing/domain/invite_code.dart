const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// Strips non-alphanumerics, upper-cases; null unless 8 chars from the alphabet.
String? normaliseCode(String input) {
  final cleaned = input.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  if (cleaned.length != 8) return null;
  for (final char in cleaned.split('')) {
    if (!_alphabet.contains(char)) return null;
  }
  return cleaned;
}

String formatCode(String code) =>
    '${code.substring(0, 4)}-${code.substring(4)}';

class Invite {
  const Invite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;
}
