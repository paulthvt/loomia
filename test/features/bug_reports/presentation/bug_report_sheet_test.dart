import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/bug_reports/presentation/bug_report_sheet.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late List<String> submitted;

  Future<void> pumpSheet(WidgetTester tester) async {
    submitted = [];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => bugReportSheet(
              context,
              (text, {extras}) async => submitted.add(text),
              null,
            ),
          ),
        ),
      ),
    );
  }

  FilledButton send(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Send'));

  testWidgets('shows the question and the public warning', (tester) async {
    await pumpSheet(tester);
    expect(find.text('What went wrong?'), findsOneWidget);
    expect(
      find.text('Posted publicly on GitHub: leave out names and numbers.'),
      findsOneWidget,
    );
  });

  testWidgets('Send waits for a comment', (tester) async {
    await pumpSheet(tester);
    expect(send(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    expect(send(tester).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'It froze');
    await tester.pump();
    expect(send(tester).onPressed, isNotNull);
  });

  testWidgets('a spinner replaces Send until the report is sent', (
    tester,
  ) async {
    final done = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                bugReportSheet(context, (text, {extras}) => done.future, null),
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'It froze');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    done.complete();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('Send submits the trimmed comment', (tester) async {
    await pumpSheet(tester);
    await tester.enterText(find.byType(TextField), '  It froze \n');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(submitted, ['It froze']);
  });
}
