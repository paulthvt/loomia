import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/goal_card.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, GoalCard card) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: card),
  ),
);

void main() {
  testWidgets('a target draws the bar with its labels', (tester) async {
    await _pump(
      tester,
      const GoalCard(
        title: 'Own volume',
        value: '1,840',
        suffix: 'of 2,800 PV',
        progress: 0.66,
        pace: 'On pace',
        leading: '66% of what you planned',
        timeLeft: '11 days left',
      ),
    );

    expect(find.text('1,840'), findsOneWidget);
    expect(find.text('of 2,800 PV'), findsOneWidget);
    expect(find.text('On pace'), findsOneWidget);
    expect(find.byType(LoomiaProgressBar), findsOneWidget);
  });

  testWidgets('no target: the value alone, no bar', (tester) async {
    await _pump(
      tester,
      const GoalCard(
        title: 'Own volume',
        value: '1,840',
        suffix: 'PV this month',
      ),
    );

    expect(find.byType(LoomiaProgressBar), findsNothing);
  });

  testWidgets('a tap goes to onTap', (tester) async {
    var taps = 0;
    await _pump(
      tester,
      GoalCard(title: 'Own volume', value: '0', onTap: () => taps++),
    );

    await tester.tap(find.text('Own volume'));
    expect(taps, 1);
  });
}
