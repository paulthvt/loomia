import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/layout/content_columns.dart';
import 'package:material_ui/material_ui.dart';

const _main = Key('main');
const _side = Key('side');

Future<void> _pump(WidgetTester tester, double width) {
  tester.view
    ..physicalSize = Size(width, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ContentColumns(
            main: [SizedBox(key: _main, height: 100)],
            side: [SizedBox(key: _side, height: 50)],
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('desktop: side to the right at 400, main at most 624', (
    tester,
  ) async {
    await _pump(tester, 1440);

    expect(tester.getSize(find.byKey(_side)).width, 400);
    expect(tester.getSize(find.byKey(_main)).width, 624);
    expect(
      tester.getTopLeft(find.byKey(_side)).dx,
      greaterThan(tester.getTopRight(find.byKey(_main)).dx),
    );
    expect(
      tester.getTopLeft(find.byKey(_side)).dy,
      tester.getTopLeft(find.byKey(_main)).dy,
    );
  });

  testWidgets('a wide window centres the pair', (tester) async {
    await _pump(tester, 1920);

    final left = tester.getTopLeft(find.byKey(_main)).dx;
    final right = 1920 - tester.getTopRight(find.byKey(_side)).dx;
    expect(left, moreOrLessEquals(right, epsilon: 1));
  });

  testWidgets('a narrow desktop shrinks main, never side', (tester) async {
    await _pump(tester, 1024);

    expect(tester.getSize(find.byKey(_side)).width, 400);
    expect(tester.getSize(find.byKey(_main)).width, lessThan(624));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile: main then side, full width', (tester) async {
    await _pump(tester, 390);

    expect(
      tester.getTopLeft(find.byKey(_side)).dy,
      greaterThan(tester.getTopLeft(find.byKey(_main)).dy),
    );
    expect(tester.getSize(find.byKey(_side)).width, 390);
  });
}
