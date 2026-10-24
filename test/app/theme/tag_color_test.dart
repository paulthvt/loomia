import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:material_ui/material_ui.dart';

double _contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  test("the snackbar's action is AA on the snackbar, both modes (#372)", () {
    for (final scheme in [AppColors.light, AppColors.dark]) {
      expect(
        _contrast(scheme.inversePrimary, scheme.inverseSurface),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  for (final color in TagColor.values) {
    test('${color.name} ink is AA on its container, both modes', () {
      for (final ink in [color.light, color.dark]) {
        expect(_contrast(ink.ink, ink.container), greaterThanOrEqualTo(4.5));
      }
    });

    test('${color.name} dot reads on the sunken surface, both modes', () {
      expect(
        _contrast(color.light.ink, LoomiaColors.light.surfaceSunken),
        greaterThanOrEqualTo(3),
      );
      expect(
        _contrast(color.dark.ink, LoomiaColors.dark.surfaceSunken),
        greaterThanOrEqualTo(3),
      );
    });
  }
}
