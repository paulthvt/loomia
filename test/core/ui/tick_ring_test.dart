import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/tick_ring.dart';
import 'package:material_ui/material_ui.dart';

Widget _ring({
  required bool selected,
  bool reduce = false,
  VoidCallback? tap,
}) => MaterialApp(
  theme: AppTheme.light,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
    child: child!,
  ),
  home: Scaffold(
    body: Center(
      child: TickRing(selected: selected, onPressed: tap, tooltip: 'Done'),
    ),
  ),
);

CheckPainter? _painter(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byType(TickRing),
      matching: find.byType(CustomPaint),
    ),
  );
  for (final paint in paints) {
    if (paint.painter case final CheckPainter check) return check;
  }
  return null;
}

void main() {
  testWidgets('empty: the faint check icon, no drawing', (tester) async {
    await tester.pumpWidget(_ring(selected: false));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(_painter(tester), isNull);
  });

  testWidgets('selected: the check is drawn over 240ms', (tester) async {
    await tester.pumpWidget(_ring(selected: false));
    await tester.pumpWidget(_ring(selected: true));
    await tester.pump(AppMotion.medium ~/ 2);
    expect(_painter(tester)!.progress, inExclusiveRange(0, 1));
    await tester.pump(AppMotion.medium ~/ 2);
    expect(_painter(tester)!.progress, 1);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('no longer selected: it un-draws in 120ms', (tester) async {
    await tester.pumpWidget(_ring(selected: false));
    await tester.pumpWidget(_ring(selected: true));
    await tester.pumpAndSettle();
    await tester.pumpWidget(_ring(selected: false));
    await tester.pump(AppMotion.fast ~/ 2);
    expect(_painter(tester)!.progress, inExclusiveRange(0, 1));
    await tester.pump(AppMotion.fast ~/ 2);
    expect(_painter(tester), isNull);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('built selected: drawn at once', (tester) async {
    await tester.pumpWidget(_ring(selected: true));
    expect(_painter(tester)!.progress, 1);
  });

  testWidgets('reduce motion: the whole check fades in over 120ms', (
    tester,
  ) async {
    await tester.pumpWidget(_ring(selected: false, reduce: true));
    await tester.pumpWidget(_ring(selected: true, reduce: true));
    await tester.pump(AppMotion.fast ~/ 2);
    expect(_painter(tester)!.progress, 1);
    final fade = tester.widget<Opacity>(
      find.descendant(
        of: find.byType(TickRing),
        matching: find.byType(Opacity),
      ),
    );
    expect(fade.opacity, inExclusiveRange(0, 1));
    await tester.pump(AppMotion.fast ~/ 2);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(TickRing),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      1,
    );
  });

  testWidgets('keeps the ring button: tooltip and tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_ring(selected: false, tap: () => taps++));
    await tester.tap(find.byTooltip('Done'));
    expect(taps, 1);
    expect(tester.getSize(find.byType(IconButton)).width, 48);
  });
}
