import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/ui/scope_dialog.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Future<void> open(WidgetTester tester, {bool delete = false}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => pickScope(
              context,
              delete: delete,
              wording: ScopeWording.reminder,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a reminder is worded as a reminder (#486)', (tester) async {
    await open(tester);
    expect(find.text('Change a repeating reminder'), findsOneWidget);
    expect(find.text('This reminder'), findsOneWidget);
    expect(find.text('This and following reminders'), findsOneWidget);
  });

  testWidgets('deleting a reminder says so', (tester) async {
    await open(tester, delete: true);
    expect(find.text('Delete a repeating reminder'), findsOneWidget);
  });
}
