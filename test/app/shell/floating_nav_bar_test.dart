import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/shell/floating_nav_bar.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(
  WidgetTester tester,
  int selected, {
  bool reduceMotion = false,
}) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: child!,
    ),
    home: Scaffold(
      bottomNavigationBar: FloatingNavBar(
        selected: selected,
        onSelect: (_) {},
        create: null,
        onCreate: null,
      ),
    ),
  ),
);

/// The amber pill behind the active tab.
Rect _pill(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byType(FloatingNavBar),
    matching: find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is ShapeDecoration &&
          (widget.decoration as ShapeDecoration).color ==
              AppTheme.light.colorScheme.primary,
    ),
  ),
);

Rect _tab(WidgetTester tester, String label) => tester.getRect(
  find.descendant(
    of: find.byType(FloatingNavBar),
    matching: find.bySemanticsLabel(label),
  ),
);

void main() {
  testWidgets('the pill slides to the new tab', (tester) async {
    await _pump(tester, 0);
    final from = _tab(tester, 'Today').left;
    expect(_pill(tester).left, from);

    await _pump(tester, 2);
    await tester.pump(const Duration(milliseconds: 210));
    final mid = _pill(tester).left;

    await tester.pumpAndSettle();
    final to = _tab(tester, 'Contacts');
    expect(mid, greaterThan(from));
    expect(mid, lessThan(to.left));
    expect(_pill(tester).left, to.left);
    expect(_pill(tester).right, to.right);
  });

  testWidgets('reduce motion uses the short transition', (tester) async {
    await _pump(tester, 0, reduceMotion: true);
    final from = _tab(tester, 'Today').left;
    await _pump(tester, 2, reduceMotion: true);
    await tester.pump(AppMotion.fast ~/ 2);
    final mid = _pill(tester).left;

    await tester.pump(AppMotion.fast ~/ 2);
    await tester.pump();
    final to = _tab(tester, 'Contacts');
    expect(mid, greaterThan(from));
    expect(mid, lessThan(to.left));
    expect(_pill(tester).left, to.left);
    expect(_pill(tester).right, to.right);
  });

  testWidgets('labels never overflow mid-animation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pump(tester, 0);
    for (final next in [2, 1, 3, 0]) {
      await _pump(tester, next);
      for (var ms = 0; ms <= 450; ms += 30) {
        await tester.pump(const Duration(milliseconds: 30));
        expect(tester.takeException(), isNull);
      }
    }
  });
}
