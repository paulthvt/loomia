import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/hero_panel.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('HeroPanel', () {
    testWidgets('hero panel paints the theme gradient', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: HeroPanel(children: [Text('Test')])),
        ),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(HeroPanel),
          matching: find.byType(DecoratedBox),
        ),
      );

      final decoration = decoratedBox.decoration as BoxDecoration;
      expect(decoration.gradient, equals(LoomiaColors.light.heroGradient));
    });

    testWidgets('screen-top hero pads by the status bar', (tester) async {
      const statusBarHeight = 47.0;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const MediaQuery(
            data: MediaQueryData(
              padding: EdgeInsets.only(top: statusBarHeight),
            ),
            child: Scaffold(
              body: HeroPanel(
                shape: HeroShape.screenTop,
                children: [Text('Test')],
              ),
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find.descendant(
          of: find.byType(HeroPanel),
          matching: find.byType(Padding),
        ),
      );

      expect(
        padding.padding.resolve(TextDirection.ltr).top,
        greaterThanOrEqualTo(statusBarHeight),
      );
    });

    testWidgets('hero panel wraps a long title without overflow', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(
            body: SizedBox(
              width: 360,
              child: HeroPanel(
                children: [
                  LoomiaTopBar(
                    onHero: true,
                    title: 'Good afternoon, Marie-Charlotte Delacroix-Fontaine',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('hero card has the dark hairline only in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: HeroCard(child: Text('Test'))),
        ),
      );

      final lightContainer = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(HeroCard),
          matching: find.byType(DecoratedBox),
        ),
      );

      final lightDecoration = lightContainer.decoration as BoxDecoration;
      final lightBorder = lightDecoration.border as Border?;
      expect(
        lightBorder?.top.color ?? Colors.transparent,
        equals(LoomiaColors.light.heroCardBorder),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(body: HeroCard(child: Text('Test'))),
        ),
      );

      await tester.pumpAndSettle();

      final darkContainer = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(HeroCard),
          matching: find.byType(DecoratedBox),
        ),
      );

      final darkDecoration = darkContainer.decoration as BoxDecoration;
      final darkBorder = darkDecoration.border as Border?;
      expect(
        darkBorder?.top.color ?? Colors.transparent,
        equals(LoomiaColors.dark.heroCardBorder),
      );
    });
  });
}
