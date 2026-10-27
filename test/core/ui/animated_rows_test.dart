import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/animated_rows.dart';
import 'package:material_ui/material_ui.dart';

Widget _row(String label) =>
    SizedBox(key: ValueKey(label), height: 40, child: Text(label));

Future<void> _pump(
  WidgetTester tester,
  List<String> labels, {
  Duration delay = Duration.zero,
  bool reduce = false,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: AnimatedRows(
          spacing: 8,
          delay: delay,
          children: [for (final label in labels) _row(label)],
        ),
      ),
    ),
  ),
);

double _height(WidgetTester tester) =>
    tester.getSize(find.byType(AnimatedRows)).height;

void main() {
  testWidgets('first build: every row at once', (tester) async {
    await _pump(tester, ['A', 'B', 'C']);
    expect(_height(tester), 40 * 3 + 8 * 2);
  });

  testWidgets('a new row grows in over 240ms', (tester) async {
    await _pump(tester, ['A', 'B']);
    await _pump(tester, ['A', 'New', 'B']);
    await tester.pump(AppMotion.medium ~/ 2);
    expect(_height(tester), inExclusiveRange(88, 88 + 48));
    await tester.pumpAndSettle();
    expect(_height(tester), 88 + 48);
    expect(
      tester.getTopLeft(find.text('New')).dy,
      lessThan(tester.getTopLeft(find.text('B')).dy),
    );
  });

  testWidgets('a gone row folds out where it was', (tester) async {
    await _pump(tester, ['A', 'B', 'C']);
    await _pump(tester, ['A', 'C']);
    await tester.pump(AppMotion.medium ~/ 2);
    expect(find.text('B'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('B')).dy,
      lessThan(tester.getTopLeft(find.text('C')).dy),
    );
    await tester.pumpAndSettle();
    expect(find.text('B'), findsNothing);
    expect(_height(tester), 88);
  });

  testWidgets('the same rows rebuilt move nothing (a refresh)', (tester) async {
    await _pump(tester, ['A', 'B']);
    await tester.pumpAndSettle();
    await _pump(tester, ['A', 'B']);
    await tester.pump(AppMotion.medium ~/ 2);
    expect(_height(tester), 88);
    expect(
      tester
          .widgetList<SizeTransition>(find.byType(SizeTransition))
          .every((size) => size.sizeFactor.value == 1),
      isTrue,
    );
  });

  testWidgets('a delay holds the change that long', (tester) async {
    await _pump(tester, ['A'], delay: AppMotion.slow);
    await _pump(tester, ['A', 'B'], delay: AppMotion.slow);
    await tester.pump(AppMotion.slow - const Duration(milliseconds: 20));
    expect(_height(tester), 40);
    await tester.pumpAndSettle();
    expect(_height(tester), 88);
  });

  testWidgets('a row that comes back (Undo) grows back in', (tester) async {
    await _pump(tester, ['A', 'B']);
    await _pump(tester, ['A']);
    await tester.pump(AppMotion.medium ~/ 2);
    await _pump(tester, ['A', 'B']);
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(_height(tester), 88);
  });

  testWidgets('reduce motion: 120ms', (tester) async {
    await _pump(tester, ['A'], reduce: true);
    await _pump(tester, ['A', 'B'], reduce: true);
    await tester.pump(AppMotion.fast);
    expect(_height(tester), 88);
  });
}
