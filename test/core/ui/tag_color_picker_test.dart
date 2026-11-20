import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/tag_color_picker.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> pump(WidgetTester tester, ValueChanged<TagColor>? onPick) =>
      tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: TagColorPicker(selected: TagColor.sky, onPick: onPick),
          ),
        ),
      );

  testWidgets('a disabled picker says so to screen readers (#516)', (
    tester,
  ) async {
    await pump(tester, null);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Violet')),
      isSemantics(label: 'Violet', hasEnabledState: true, isEnabled: false),
    );

    await pump(tester, (_) {});
    expect(
      tester.getSemantics(find.bySemanticsLabel('Violet')),
      isSemantics(label: 'Violet', hasEnabledState: true, isEnabled: true),
    );
  });
}
