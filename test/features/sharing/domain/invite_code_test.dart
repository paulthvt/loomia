import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/sharing/domain/invite_code.dart';

void main() {
  group('normaliseCode', () {
    test('strips spaces and dashes, uppercases', () {
      expect(normaliseCode(' abcd-efgh\n'), 'ABCDEFGH');
      expect(normaliseCode('abcd efgh'), 'ABCDEFGH');
    });

    test('returns null for code with excluded character 0', () {
      expect(normaliseCode('ABCDEFG0'), null);
    });

    test('returns null for code with wrong length', () {
      expect(normaliseCode('ABCDEFG'), null);
      expect(normaliseCode('ABCDEFGHI'), null);
    });

    test('accepts valid 8-character code', () {
      expect(normaliseCode('ABCDEFGH'), 'ABCDEFGH');
      expect(normaliseCode('abcdefgh'), 'ABCDEFGH');
    });
  });

  group('formatCode', () {
    test('formats 8-character code with dash', () {
      expect(formatCode('ABCDEFGH'), 'ABCD-EFGH');
    });
  });
}
