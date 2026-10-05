import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/business_model/business_model.dart';

void main() {
  test('nothing stored is Other', () {
    expect(BusinessModel.parse(null), BusinessModel.other);
  });

  test('doterra is read back', () {
    expect(BusinessModel.parse('doterra'), BusinessModel.doterra);
  });

  test('an unknown value reads as Other', () {
    expect(BusinessModel.parse('young_living'), BusinessModel.other);
    expect(BusinessModel.parse(42), BusinessModel.other);
  });

  test('Other is stored as nothing, so it round-trips', () {
    expect(BusinessModel.other.stored, isNull);
    expect(BusinessModel.doterra.stored, 'doterra');
    for (final model in BusinessModel.values) {
      expect(BusinessModel.parse(model.stored), model);
    }
  });

  test("dōTERRA's ranks, lowest first; Other has none", () {
    expect(BusinessModel.doterra.levels, [
      'Manager',
      'Director',
      'Executive',
      'Elite',
      'Premier',
      'Silver',
      'Gold',
      'Platinum',
      'Diamond',
      'Blue Diamond',
      'Presidential Diamond',
    ]);
    expect(BusinessModel.other.levels, isEmpty);
  });

  test(
    'dōTERRA: the OV each rank usually needs, where the ladder says one',
    () {
      final volumes = BusinessModel.doterra.levelVolumes;
      expect(volumes['Manager'], 500);
      expect(volumes['Elite'], 3000);
      expect(volumes['Platinum'], 27000);
      // From Diamond on, only branches count: no volume to suggest.
      expect(volumes['Diamond'], isNull);
      expect(BusinessModel.doterra.levels, containsAll(volumes.keys));
      expect(BusinessModel.other.levelVolumes, isEmpty);
    },
  );
}
