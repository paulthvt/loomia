import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:material_ui/material_ui.dart';

/// Captures the theme as a widget actually sees it.
Future<(ThemeData, LoomiaColors)> _resolve(
  WidgetTester tester,
  ThemeData theme,
) async {
  late ThemeData resolved;
  late LoomiaColors colors;
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) {
          resolved = Theme.of(context);
          colors = LoomiaColors.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return (resolved, colors);
}

void main() {
  for (final (name, theme, expected) in <(String, ThemeData, LoomiaColors)>[
    ('light', AppTheme.light, LoomiaColors.light),
    ('dark', AppTheme.dark, LoomiaColors.dark),
  ]) {
    group(name, () {
      testWidgets('LoomiaColors resolves from the theme', (tester) async {
        final (resolved, colors) = await _resolve(tester, theme);

        expect(colors.borderSubtle, expected.borderSubtle);
        expect(colors.accent, expected.accent);
        expect(resolved.colorScheme.primary, const Color(0xFFA75C15));
      });

      testWidgets('typography and shape come from the tokens', (tester) async {
        final (resolved, _) = await _resolve(tester, theme);

        expect(resolved.textTheme.titleMedium!.fontSize, 17);
        expect(
          resolved.textTheme.titleMedium!.fontFamily,
          AppTypography.fontFamily,
        );
        // Unmapped slots keep the Material default but inherit the family.
        expect(
          resolved.textTheme.displayLarge!.fontFamily,
          AppTypography.fontFamily,
        );
        expect(resolved.cardTheme.elevation, 0);
        expect(
          resolved.cardTheme.shape,
          isA<RoundedRectangleBorder>().having(
            (s) => s.borderRadius,
            'radius',
            BorderRadius.circular(AppRadii.card),
          ),
        );
      });
    });
  }

  test('primary ink flips between modes, the primary fill does not', () {
    expect(AppColors.light.primary, AppColors.dark.primary);
    expect(
      LoomiaColors.light.primaryText,
      isNot(LoomiaColors.dark.primaryText),
    );
  });

  test('numerals are tabular so goal values do not shift', () {
    expect(
      AppTypography.numericLarge.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
    expect(
      AppTypography.numeric.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  double contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  test('white text on primary meets AA in both modes', () {
    for (final scheme in [AppColors.light, AppColors.dark]) {
      expect(
        contrast(scheme.onPrimary, scheme.primary),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('white text on primary hover meets AA in both modes', () {
    for (final colors in [LoomiaColors.light, LoomiaColors.dark]) {
      expect(
        contrast(AppColors.light.onPrimary, colors.primaryHover),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('quiet hero ink meets AA where hero text sits', () {
    // Text sits in the gradient's dark top-left (spec, Hero gradient).
    for (final colors in [LoomiaColors.light, LoomiaColors.dark]) {
      final under = colors.heroGradient.colors.first;
      final quiet = Color.alphaBlend(colors.onHeroQuiet, under);
      expect(contrast(quiet, under), greaterThanOrEqualTo(4.5));
    }
  });

  test('primary ink meets AA on its surface', () {
    for (final colors in [LoomiaColors.light, LoomiaColors.dark]) {
      expect(
        contrast(colors.primaryText, colors.surfaceDefault),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('brand is the Loomia ochre and lerps', () {
    expect(LoomiaColors.light.brand, const Color(0xFFE8964A));
    expect(
      LoomiaColors.light.lerp(LoomiaColors.dark, 1).brand,
      LoomiaColors.dark.brand,
    );
  });

  test('hero gradient is rosewood to apricot, darker in dark mode', () {
    expect(LoomiaColors.light.heroGradient.colors, [
      const Color(0xFF82424F),
      const Color(0xFFE39A68),
    ]);
    expect(LoomiaColors.dark.heroGradient.colors, [
      const Color(0xFF4F2530),
      const Color(0xFFA8623F),
    ]);
  });

  test('white meets AA on both hero starts', () {
    for (final colors in [LoomiaColors.light, LoomiaColors.dark]) {
      expect(
        contrast(const Color(0xFFFFFFFF), colors.heroGradient.colors.first),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  test('muted chrome ink meets AA on chrome', () {
    for (final colors in [LoomiaColors.light, LoomiaColors.dark]) {
      final composited = Color.alphaBlend(colors.onChromeMuted, colors.chrome);
      expect(contrast(composited, colors.chrome), greaterThanOrEqualTo(4.5));
    }
  });

  test('canvas is the warm Horizon canvas', () {
    expect(AppColors.light.surface, const Color(0xFFF6F2ED));
  });

  testWidgets('cards have no border and one soft shadow in light', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final card = AppTheme.card(ctx);
    expect(card.border, isNull);
    expect(card.boxShadow, LoomiaColors.light.cardShadow);
  });

  testWidgets('cards in dark are surfaceDefault, not the sunken colour', (
    tester,
  ) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) {
            ctx = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final card = AppTheme.card(ctx);
    expect(card.color, const Color(0xFF1E1A15));
    expect(card.border, isNull);
    expect(card.boxShadow, LoomiaColors.dark.cardShadow);
    expect(AppTheme.heroCard(ctx).color, const Color(0xFF1E1A15));
  });
}
