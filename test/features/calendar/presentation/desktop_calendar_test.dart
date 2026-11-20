import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/desktop_calendar.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets("a month chip's bar: its type's colour, faded once over (#516)", (
    tester,
  ) async {
    Future<Color?> bar(DateTime now) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: MonthEventChip(
              event: CalendarEvent(
                id: 'e1',
                title: 'Workshop',
                startsAt: DateTime(2026, 10, 8, 19),
                endsAt: DateTime(2026, 10, 8, 21),
                color: TagColor.violet,
              ),
              now: now,
              onTap: () {},
            ),
          ),
        ),
      );
      return tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.color)
          .whereType<Color>()
          .first;
    }

    final violet = TagColor.violet.light.ink;
    expect(await bar(DateTime(2026, 10, 8, 12)), violet);
    expect(await bar(DateTime(2026, 10, 8, 22)), violet.withValues(alpha: 0.5));
  });
}
