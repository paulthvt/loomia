import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/shell/floating_nav_bar.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../load_fonts.dart';

Future<void> _pump(
  WidgetTester tester,
  int selected, {
  bool reduceMotion = false,
  bool withCreate = false,
  Locale locale = const Locale('en'),
}) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
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
        create: withCreate
            ? (label: 'New task', icon: Icons.add_rounded, run: (_, _) async {})
            : null,
        onCreate: withCreate ? () {} : null,
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
    final from = _pill(tester).left;
    expect(_pill(tester).center.dx, _tab(tester, 'Today').center.dx);

    await _pump(tester, 2);
    await tester.pump(const Duration(milliseconds: 210));
    final mid = _pill(tester).left;

    await tester.pumpAndSettle();
    final to = _tab(tester, 'Contacts');
    expect(mid, greaterThan(from));
    expect(mid, lessThan(_pill(tester).left));
    expect(_pill(tester).center.dx, moreOrLessEquals(to.center.dx));
    expect(_pill(tester).width, 60);
  });

  testWidgets('reduce motion uses the short transition', (tester) async {
    await _pump(tester, 0, reduceMotion: true);
    final from = _pill(tester).left;
    await _pump(tester, 2, reduceMotion: true);
    await tester.pump(AppMotion.fast ~/ 2);
    final mid = _pill(tester).left;

    await tester.pump(AppMotion.fast ~/ 2);
    await tester.pump();
    final to = _tab(tester, 'Contacts');
    expect(mid, greaterThan(from));
    expect(mid, lessThan(_pill(tester).left));
    expect(_pill(tester).center.dx, moreOrLessEquals(to.center.dx));
    expect(_pill(tester).width, 60);
  });

  testWidgets('nothing overflows mid-slide at text scale 2', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pump(tester, 0, withCreate: true);
    for (final next in [2, 1, 3, 0]) {
      await _pump(tester, next, withCreate: true);
      for (var ms = 0; ms <= 450; ms += 30) {
        await tester.pump(const Duration(milliseconds: 30));
        expect(tester.takeException(), isNull);
      }
    }
  });

  group('icons only', () {
    setUpAll(loadAppFonts);

    for (final locale in const [Locale('en'), Locale('fr')]) {
      for (final scale in const [1.0, 2.0]) {
        testWidgets('no label in $locale at text scale $scale', (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          for (var index = 0; index < 4; index++) {
            await _pump(tester, index, withCreate: true, locale: locale);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              find.descendant(
                of: find.byType(FloatingNavBar),
                matching: find.byType(Text),
              ),
              findsNothing,
            );
          }
        });
      }
    }
  });

  testWidgets('four equal tabs, the pill centred on the selected one', (
    tester,
  ) async {
    const labels = ['Today', 'Calendar', 'Contacts', 'Goals'];
    for (final (index, label) in labels.indexed) {
      await _pump(tester, index, withCreate: true);
      await tester.pumpAndSettle();
      final widths = [for (final name in labels) _tab(tester, name).width];
      for (final width in widths) {
        expect(width, moreOrLessEquals(widths.first));
        expect(width, greaterThanOrEqualTo(48));
      }
      final pill = _pill(tester);
      final tab = _tab(tester, label);
      expect(pill.center.dx, moreOrLessEquals(tab.center.dx));
      expect(pill.center.dy, moreOrLessEquals(tab.center.dy));
      expect(pill.size, const Size(60, 44));
    }
  });

  testWidgets('every tab has a tooltip, selected or not', (tester) async {
    await _pump(tester, 1);
    for (final label in ['Today', 'Calendar', 'Contacts', 'Goals']) {
      expect(find.byTooltip(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('a tab is a 52-high target TalkBack can activate', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var picked = -1;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Scaffold(
          bottomNavigationBar: FloatingNavBar(
            selected: 0,
            onSelect: (index) => picked = index,
            create: null,
            onCreate: null,
          ),
        ),
      ),
    );

    final contacts = find.descendant(
      of: find.byType(FloatingNavBar),
      matching: find.bySemanticsLabel('Contacts'),
    );
    expect(
      tester.getSemantics(contacts),
      matchesSemantics(
        label: 'Contacts',
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
      ),
    );
    expect(
      tester.getSemantics(
        find.descendant(
          of: find.byType(FloatingNavBar),
          matching: find.bySemanticsLabel('Today'),
        ),
      ),
      matchesSemantics(
        label: 'Today',
        isButton: true,
        hasTapAction: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    final node = tester.getSemantics(contacts);
    node.owner!.performAction(node.id, SemanticsAction.tap);
    expect(picked, 2);

    // An inactive tab takes the bar's full height, not the 44 of its pill.
    final rect = tester.getRect(contacts);
    final inkWell = tester.getRect(
      find.ancestor(
        of: find.byIcon(Icons.people_outline),
        matching: find.byType(InkWell),
      ),
    );
    expect(rect.height, greaterThanOrEqualTo(48));
    expect(inkWell.height, greaterThanOrEqualTo(48));
    handle.dispose();
  });

  testWidgets('the active tab shows its filled icon, the others outlined', (
    tester,
  ) async {
    await _pump(tester, 2);

    expect(find.byIcon(Icons.people), findsOneWidget);
    expect(find.byIcon(Icons.people_outline), findsNothing);
    expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month_outlined), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
  });
}
