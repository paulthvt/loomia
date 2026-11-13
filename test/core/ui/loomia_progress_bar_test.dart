import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:material_ui/material_ui.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('$name: the hero bar stands out from the hero card', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: LoomiaProgressBar(value: 0.4, tone: ProgressTone.primary),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      // Non-text UI needs 3:1 against what it sits on (WCAG 1.4.11).
      expect(
        _contrast(bar.color!, theme.colorScheme.surfaceContainerLowest),
        greaterThanOrEqualTo(3),
      );
    });
  }
}
