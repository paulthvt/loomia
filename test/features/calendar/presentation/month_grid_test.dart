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

  testWidgets('month grid on the hero marks today with a ring and the '
      'selected day filled', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
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
    final onHero = AppTheme.light.extension<LoomiaColors>()!.onHero;
    final scheme = AppTheme.light.colorScheme;

    final today = circle(tester, '7');
    expect(today.color, isNull);
    expect(today.border, Border.all(color: onHero, width: 1.5));

    final selected = circle(tester, '8');
    expect(selected.color, onHero);
    expect(selected.border, isNull);
    expect(
      tester.widget<Text>(find.text('8')).style?.color,
      scheme.onPrimaryContainer,
    );
    expect(tester.widget<Text>(find.text('9')).style?.color, onHero);
    // September 30, before the month.
    expect(
      tester.widget<Text>(find.text('30').first).style?.color,
      onHero.withValues(alpha: 0.35),
    );
  });
}
