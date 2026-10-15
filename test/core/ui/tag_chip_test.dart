import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/tag_chip.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    home: Scaffold(body: Center(child: child)),
  ),
);

Color? _fill(WidgetTester tester) =>
    ((tester.widget(
              find.byType(AnimatedContainer),
            ) as AnimatedContainer).decoration!
            as BoxDecoration)
        .color;

void main() {
  testWidgets('plain and on take the container; off the sunken surface', (
    tester,
  ) async {
    await _pump(tester, const TagChip(label: 'Lyon', color: TagColor.sage));
    expect(_fill(tester), TagColor.sage.light.container);

    await _pump(
      tester,
      TagChip(
        label: 'Lyon',
        color: TagColor.sage,
        selected: true,
        onTap: () {},
      ),
    );
    await tester.pumpAndSettle();
    expect(_fill(tester), TagColor.sage.light.container);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await _pump(
      tester,
      TagChip(
        label: 'Lyon',
        color: TagColor.sage,
        selected: false,
        onTap: () {},
      ),
    );
    await tester.pumpAndSettle();
    expect(_fill(tester), LoomiaColors.light.surfaceSunken);
    expect(find.byType(TagDot), findsOneWidget);
  });

  testWidgets('a tap calls onTap, on a 32px target at least', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      TagChip(label: 'Lyon', color: TagColor.sage, onTap: () => taps++),
    );
    await tester.tap(find.text('Lyon'));
    expect(taps, 1);
    expect(
      tester.getSize(find.byType(InkWell)).height,
      greaterThanOrEqualTo(tagTapTarget),
    );
  });

  testWidgets('five tags: three dots, +2, every name read out', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      TagDots(
        tags: [
          for (final (i, color) in TagColor.values.take(5).indexed)
            (name: 'T$i', color: color),
        ],
      ),
    );
    expect(find.byType(TagDot), findsNWidgets(3));
    expect(find.text('+2'), findsOneWidget);
    expect(find.bySemanticsLabel('Tags: T0, T1, T2, T3, T4'), findsOneWidget);
    handle.dispose();
  });
}
