import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/bug_reports/presentation/bug_report_sheet.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

final _title = find.widgetWithText(TextField, 'Title');
final _description = find.widgetWithText(TextField, 'What went wrong?');

void main() {
  late List<(String, Map<String, dynamic>?)> submitted;

  Future<void> pumpSheet(
    WidgetTester tester, {
    Future<void> Function()? wait,
  }) async {
    submitted = [];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                bugReportSheet(context, (text, {extras}) async {
                  submitted.add((text, extras));
                  await wait?.call();
                }, null),
          ),
        ),
      ),
    );
  }

  FilledButton send(WidgetTester tester) =>
      tester.widget(find.widgetWithText(FilledButton, 'Send'));

  testWidgets('shows a title, the question and the public warning', (
    tester,
  ) async {
    await pumpSheet(tester);
    expect(_title, findsOneWidget);
    expect(_description, findsOneWidget);
    expect(
      find.text('Posted publicly on GitHub: leave out names and numbers.'),
      findsOneWidget,
    );
  });

  testWidgets('Send waits for a title; the description is optional', (
    tester,
  ) async {
    await pumpSheet(tester);
    expect(send(tester).onPressed, isNull);
    await tester.enterText(_description, 'It froze on Today');
    await tester.pump();
    expect(send(tester).onPressed, isNull);
    await tester.enterText(_title, '   ');
    await tester.pump();
    expect(send(tester).onPressed, isNull);
    await tester.enterText(_title, 'Today froze');
    await tester.enterText(_description, '');
    await tester.pump();
    expect(send(tester).onPressed, isNotNull);
  });

  testWidgets('a spinner replaces Send until the report is sent', (
    tester,
  ) async {
    final done = Completer<void>();
    await pumpSheet(tester, wait: () => done.future);
    await tester.enterText(_title, 'Today froze');
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

  testWidgets('Send submits the trimmed description, the title in extras', (
    tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(_title, '  Today froze ');
    await tester.enterText(_description, '  After a swipe \n');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    final (text, extras) = submitted.single;
    expect(text, 'After a swipe');
    expect(extras, {'title': 'Today froze'});
  });
}
