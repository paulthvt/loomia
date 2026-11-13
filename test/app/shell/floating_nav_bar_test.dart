import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/shell/floating_nav_bar.dart';
import 'package:loomia/app/theme/app_spacing.dart';
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

  group('labels fit or hide', () {
    // Ahem's square glyphs are far wider than the real font.
    setUpAll(loadAppFonts);

    Future<void> phone(WidgetTester tester, double scale) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    testWidgets('every label shows in full at 390px', (tester) async {
      await phone(tester, 1);
      const labels = ['Today', 'Calendar', 'Contacts', 'Goals'];
      for (final (index, label) in labels.indexed) {
        await _pump(tester, index, withCreate: true);
        await tester.pumpAndSettle();
        final text = find.descendant(
          of: find.byType(FloatingNavBar),
          matching: find.text(label),
        );
        expect(text, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(text);
        final measured = TextPainter(
          text: paragraph.text,
          textScaler: paragraph.textScaler,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.width, measured.width);

        // The pill hugs icon, gap and label in its padding, as in the
        // mockup; the other three share the rest evenly.
        expect(
          _pill(tester).width,
          moreOrLessEquals(
            2 * AppSpacing.ms + 24 + AppSpacing.sm + measured.width,
          ),
        );
        final inactive = [
          for (final (other, name) in labels.indexed)
            if (other != index) _tab(tester, name).width,
        ];
        for (final width in inactive) {
          expect(width, moreOrLessEquals(inactive.first));
          expect(width, greaterThanOrEqualTo(48));
        }
        measured.dispose();
      }
    });

    testWidgets('a label too wide for the pill is hidden, still announced', (
      tester,
    ) async {
      await phone(tester, 2);
      final handle = tester.ensureSemantics();
      await _pump(tester, 1, withCreate: true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(FloatingNavBar),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(FloatingNavBar),
          matching: find.bySemanticsLabel('Calendar'),
        ),
        findsOneWidget,
      );
      // Icon-only, the pill is the 48px target.
      expect(_pill(tester).width, 48);
      handle.dispose();
    });
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
}
