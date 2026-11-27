import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/presentation/month_grid.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  /// The circle behind [day]'s number.
  BoxDecoration circle(WidgetTester tester, String day) =>
      tester
              .widget<Container>(
                find
                    .ancestor(
                      of: find.text(day),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  for (final (mode, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('month grid on the hero marks today with a ring and the '
        'selected day filled ($mode)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          home: Scaffold(
            body: MonthGrid(
              month: DateTime(2026, 10),
              selected: DateTime(2026, 10, 8),
              today: DateTime(2026, 10, 7),
              counts: const {},
              onSelect: (_) {},
              onHero: true,
            ),
          ),
        ),
      );
      final colors = theme.extension<LoomiaColors>()!;
      final onHero = colors.onHero;

      final today = circle(tester, '7');
      expect(today.color, isNull);
      expect(today.border, Border.all(color: onHero, width: 1.5));

      final selected = circle(tester, '8');
      expect(selected.color, onHero);
      expect(selected.border, isNull);
      expect(
        tester.widget<Text>(find.text('8')).style?.color,
        colors.onHeroFill,
      );
      expect(tester.widget<Text>(find.text('9')).style?.color, onHero);
      // September 30, before the month.
      expect(
        tester.widget<Text>(find.text('30').first).style?.color,
        onHero.withValues(alpha: 0.35),
      );
    });
  }

  testWidgets(
    'a row is one 48 dp square, the number in a 36 dp circle (#561)',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light,
          home: Scaffold(
            body: MonthGrid(
              month: DateTime(2026, 11),
              selected: DateTime(2026, 11, 5),
              today: DateTime(2026, 11, 5),
              counts: {DateTime(2026, 11, 9): 3},
              onSelect: (_) {},
            ),
          ),
        ),
      );
      DayCell cell(int day) => tester.widget<DayCell>(
        find.byWidgetPredicate(
          (w) => w is DayCell && w.day == DateTime(2026, 11, day),
        ),
      );
      Offset at(int day) => tester.getTopLeft(find.byWidget(cell(day)));

      expect(at(9).dy - at(2).dy, 48);
      expect(tester.getSize(find.byWidget(cell(2))).height, 48);
      expect(
        tester.getSize(
          find
              .ancestor(of: find.text('5'), matching: find.byType(Container))
              .first,
        ),
        const Size.square(36),
      );
    },
  );

  test('the ink on the hero\'s white is the same in both modes', () {
    expect(
      AppTheme.dark.extension<LoomiaColors>()!.onHeroFill,
      AppTheme.light.extension<LoomiaColors>()!.onHeroFill,
    );
  });
}
