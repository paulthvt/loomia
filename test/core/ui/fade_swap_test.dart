import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/fade_swap.dart';
import 'package:loomia/core/ui/tick_ring.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, String label, double height) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 300,
              child: FadeSwap(
                duration: AppMotion.medium,
                child: SizedBox(
                  key: ValueKey(label),
                  height: height,
                  child: Text(label),
                ),
              ),
            ),
          ),
        ),
      ),
    );

double _opacity(WidgetTester tester, String label) {
  final fade = find.ancestor(
    of: find.text(label),
    matching: find.byType(FadeTransition),
  );
  if (fade.evaluate().isEmpty) return 1;
  return tester.widget<FadeTransition>(fade.first).opacity.value;
}

void main() {
  testWidgets('a new key: the new one is in place, the old fades over it', (
    tester,
  ) async {
    await _pump(tester, 'Monday', 200);
    await _pump(tester, 'Tuesday', 100);
    await tester.pump(AppMotion.medium ~/ 2);
    expect(_opacity(tester, 'Tuesday'), 1);
    expect(_opacity(tester, 'Monday'), inExclusiveRange(0, 1));
    final height = tester.getSize(find.byType(FadeSwap)).height;
    expect(height, inExclusiveRange(100, 200));
    await tester.pumpAndSettle();
    expect(find.text('Monday'), findsNothing);
    expect(tester.getSize(find.byType(FadeSwap)).height, 100);
  });

  testWidgets('the leaving child ignores taps', (tester) async {
    await _pump(tester, 'Monday', 200);
    await _pump(tester, 'Tuesday', 100);
    await tester.pump(AppMotion.medium ~/ 2);
    expect(
      find.ancestor(
        of: find.text('Monday'),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );
  });

  testWidgets('waits for a check being drawn in the old child', (tester) async {
    Widget ringed({required bool ticked}) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: 300,
          child: FadeSwap(
            duration: AppMotion.slow,
            child: Row(
              key: const ValueKey('due'),
              children: [
                const Text('Last row'),
                TickRing(selected: ticked, tooltip: 'Tick'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpWidget(ringed(ticked: false));
    await tester.pumpWidget(ringed(ticked: true));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: SizedBox(
            width: 300,
            child: FadeSwap(
              duration: AppMotion.slow,
              child: Text('All done', key: ValueKey('done')),
            ),
          ),
        ),
      ),
    );
    await tester.pump(AppMotion.medium + const Duration(milliseconds: 200));
    expect(find.text('All done'), findsNothing);
    await tester.pump(AppMotion.slow - const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.text('All done'), findsOneWidget);
  });

  testWidgets('the same key: nothing moves', (tester) async {
    await _pump(tester, 'Monday', 200);
    await tester.pumpAndSettle();
    await _pump(tester, 'Monday', 200);
    await tester.pump(AppMotion.medium ~/ 2);
    expect(find.text('Monday'), findsOneWidget);
    expect(_opacity(tester, 'Monday'), 1);
    expect(tester.getSize(find.byType(FadeSwap)).height, 200);
  });
}
