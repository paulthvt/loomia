import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/event_row.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  // The app's localization delegates load this; a plain test does it here.
  setUpAll(() => initializeDateFormatting('en'));
  final l10n = lookupAppLocalizations(const Locale('en'));
  final tuesday = DateTime(2026, 10, 13);

  test('repeatLine: the weeks, the weekday, and the end day', () {
    expect(
      repeatLine(l10n, everyWeeks: 1, firstOn: tuesday),
      'Every week on Tuesday',
    );
    expect(
      repeatLine(
        l10n,
        everyWeeks: 2,
        firstOn: tuesday,
        untilOn: DateTime(2026, 12, 15),
      ),
      'Every 2 weeks on Tuesday · until December 15',
    );
    expect(
      repeatLine(
        l10n,
        everyWeeks: 4,
        firstOn: tuesday,
        untilOn: DateTime(2027, 3, 2),
      ),
      'Every 4 weeks on Tuesday · until March 2, 2027',
    );
  });

  testWidgets(
    'an event that is over steps back: no fill, its bar faded (#516)',
    (tester) async {
      Future<(Color?, Color?)> row(DateTime? now, {TagColor? color}) async {
        final event = CalendarEvent(
          id: 'e1',
          title: 'Workshop',
          startsAt: DateTime(2026, 10, 8, 9),
          endsAt: DateTime(2026, 10, 8, 10),
          color: color,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: EventRow(event: event, now: now, onTap: () {}),
            ),
          ),
        );
        final fill = tester
            .widget<Material>(
              find
                  .descendant(
                    of: find.byType(EventRow),
                    matching: find.byType(Material),
                  )
                  .first,
            )
            .color;
        final bar = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: find.byType(EventRow),
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((box) => (box.decoration as BoxDecoration).color)
            .whereType<Color>()
            .first;
        return (fill, bar);
      }

      final colors = AppTheme.light.extension<LoomiaColors>()!;
      expect(await row(DateTime(2026, 10, 8, 9, 30)), (
        colors.surfaceDefault,
        AppTheme.light.colorScheme.primary,
      ));
      expect(await row(null), (
        colors.surfaceDefault,
        AppTheme.light.colorScheme.primary,
      ));
      expect(await row(DateTime(2026, 10, 8, 11)), (
        Colors.transparent,
        AppTheme.light.colorScheme.primary.withValues(alpha: 0.5),
      ));
      final sky = TagColor.sky.light.ink;
      expect(await row(DateTime(2026, 10, 8, 9, 30), color: TagColor.sky), (
        colors.surfaceDefault,
        sky,
      ));
      expect(await row(DateTime(2026, 10, 8, 11), color: TagColor.sky), (
        Colors.transparent,
        sky.withValues(alpha: 0.5),
      ));
    },
  );

  testWidgets(
    "eventInk: the type's colours; without one, white and the accent (#516)",
    (tester) async {
      Future<TagInk> ink(TagColor? color) async {
        late TagInk result;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (context) {
                result = eventInk(
                  context,
                  CalendarEvent(
                    id: 'e1',
                    title: 'Workshop',
                    startsAt: DateTime(2026, 10, 8, 9),
                    color: color,
                  ),
                );
                return const SizedBox();
              },
            ),
          ),
        );
        return result;
      }

      expect(await ink(TagColor.sage), TagColor.sage.light);
      expect(await ink(null), (
        container: AppTheme.light.extension<LoomiaColors>()!.surfaceDefault,
        ink: AppColors.light.primary,
      ));
    },
  );
}
