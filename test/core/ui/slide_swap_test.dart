import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/slide_swap.dart';
import 'package:material_ui/material_ui.dart';

Widget _card(String label) =>
    SizedBox(key: ValueKey(label), height: 80, child: Text(label));

Future<void> _pump(WidgetTester tester, Widget? child) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        width: 300,
        child: SlideSwap(
          key: const ValueKey('slot'),
          padding: const EdgeInsets.only(top: 12),
          child: child,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a new key: the old card slides out to the left as the new one '
      'slides in from the right', (tester) async {
    await _pump(tester, _card('Step 1'));
    final start = tester.getTopLeft(find.text('Step 1')).dx;
    await _pump(tester, _card('Step 2'));
    await tester.pump(AppMotion.slow ~/ 2);

    expect(tester.getTopLeft(find.text('Step 1')).dx, lessThan(start));
    expect(tester.getTopLeft(find.text('Step 2')).dx, greaterThan(start));

    await tester.pumpAndSettle();
    expect(find.text('Step 1'), findsNothing);
    expect(tester.getTopLeft(find.text('Step 2')).dx, start);
  });

  testWidgets('no child: the card slides out and the slot closes, its gap '
      'too', (tester) async {
    await _pump(tester, _card('Step 1'));
    final start = tester.getTopLeft(find.text('Step 1')).dx;
    expect(tester.getSize(find.byType(SlideSwap)).height, 92);

    await _pump(tester, null);
    await tester.pump(AppMotion.slow ~/ 2);
    expect(tester.getTopLeft(find.text('Step 1')).dx, lessThan(start));

    await tester.pumpAndSettle();
    expect(find.text('Step 1'), findsNothing);
    expect(tester.getSize(find.byType(SlideSwap)).height, 0);
  });
}
