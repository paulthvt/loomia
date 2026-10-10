import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('offline says so, whatever the screen', (tester) async {
    var retries = 0;
    await _pump(
      tester,
      LoadFailed(
        offline: true,
        title: "Couldn't load today.",
        onRetry: () => retries++,
      ),
    );

    expect(find.text("You're offline"), findsOneWidget);
    expect(
      find.text(
        "Loomia can't be reached. Check your connection, then try again.",
      ),
      findsOneWidget,
    );
    expect(find.text("Couldn't load today."), findsNothing);

    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });

  testWidgets('anything else keeps the title and does not blame the '
      'connection', (tester) async {
    await _pump(
      tester,
      LoadFailed(offline: false, title: "Couldn't load today.", onRetry: () {}),
    );

    expect(find.text("Couldn't load today."), findsOneWidget);
    expect(
      find.text('Something went wrong on our side. Try again in a moment.'),
      findsOneWidget,
    );
    expect(find.text("You're offline"), findsNothing);
  });
}
