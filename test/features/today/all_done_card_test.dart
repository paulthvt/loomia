import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/today/presentation/all_done_card.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, {String firstName = 'Pauline'}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AllDoneCard(done: 15, firstName: firstName)),
        ),
      );

  testWidgets('all done shows the badge, title and warm line', (tester) async {
    await pump(tester);

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.text("You're all done for today"), findsOneWidget);
    expect(find.textContaining('Congrats, Pauline'), findsOneWidget);
    expect(find.text('15 of 15 done'), findsOneWidget);
    final competitive = RegExp(r'streak|score|rank', caseSensitive: false);
    for (final text in tester.widgetList<Text>(find.byType(Text))) {
      expect(text.data ?? '', isNot(contains(competitive)));
    }
  });

  testWidgets('no first name: the warm line goes without', (tester) async {
    await pump(tester, firstName: '');

    expect(
      find.text(
        "Congrats — that's everyone and every task. When someone is worth a "
        "message, they'll show up here.",
      ),
      findsOneWidget,
    );
  });

  testWidgets('the confetti is hidden from screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);

    // The confetti adds no node of its own: what it paints over is the card's.
    final confetti = find.byKey(AllDoneCard.confettiKey);
    expect(confetti, findsOneWidget);
    expect(
      find.ancestor(of: confetti, matching: find.byType(ExcludeSemantics)),
      findsWidgets,
    );
    expect(
      tester.getSemantics(confetti),
      same(tester.getSemantics(find.byType(AllDoneCard))),
    );
    handle.dispose();
  });

  group('AllDoneBand', () {
    Future<void> pumpBand(WidgetTester tester, {String firstName = 'Pauline'}) {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 1128,
              child: AllDoneBand(
                header: const Text('Good morning, Pauline'),
                done: 15,
                firstName: firstName,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('the band shows the greeting, title, warm line and count', (
      tester,
    ) async {
      await pumpBand(tester);

      expect(find.text('Good morning, Pauline'), findsOneWidget);
      expect(find.text("You're all done for today"), findsOneWidget);
      expect(find.textContaining('Congrats, Pauline'), findsOneWidget);
      expect(find.text('15 of 15 done'), findsOneWidget);
      final competitive = RegExp(r'streak|score|rank', caseSensitive: false);
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        expect(text.data ?? '', isNot(contains(competitive)));
      }
    });

    testWidgets("the band's text sits on the hero inset", (tester) async {
      await pumpBand(tester);

      for (final text in [
        find.text("You're all done for today"),
        find.textContaining('Congrats, Pauline'),
        find.text('15 of 15 done'),
      ]) {
        expect(
          find.ancestor(of: text, matching: find.byKey(AllDoneBand.panelKey)),
          findsOneWidget,
        );
        expect(
          tester.widget<Text>(text).style!.color,
          LoomiaColors.light.onHero,
        );
      }
    });

    testWidgets("the band's art is hidden from screen readers", (tester) async {
      final handle = tester.ensureSemantics();
      await pumpBand(tester);

      final confetti = find.byKey(AllDoneBand.confettiKey);
      expect(confetti, findsOneWidget);
      for (final art in [confetti, find.byIcon(Icons.check_rounded)]) {
        expect(
          find.ancestor(of: art, matching: find.byType(ExcludeSemantics)),
          findsWidgets,
        );
      }
      handle.dispose();
    });

    testWidgets('the band: no first name, the warm line goes without', (
      tester,
    ) async {
      await pumpBand(tester, firstName: '');

      expect(
        find.text(
          "Congrats — that's everyone and every task. When someone is worth a "
          "message, they'll show up here.",
        ),
        findsOneWidget,
      );
    });

    testWidgets('the band is read greeting first, then the panel', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpBand(tester);

      // The panel reads the title and the line, then the bar's count.
      expect(
        find.bySemanticsLabel(RegExp("^You're all done for today\nCongrats")),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('15 of 15 done'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('%')), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(AllDoneBand.panelKey)).dy,
        greaterThan(
          tester.getBottomLeft(find.text('Good morning, Pauline')).dy,
        ),
      );
      handle.dispose();
    });
  });
}
