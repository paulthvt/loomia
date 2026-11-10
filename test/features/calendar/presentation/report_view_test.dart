import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/domain/event_report.dart';
import 'package:loomia/features/calendar/presentation/report_view.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

const List<ReportEntry> _report = [
  (label: 'Topics covered', text: 'Her first orders'),
  (label: 'Issues encountered', text: ''),
  (label: 'To do', text: 'Pick her kit'),
];

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sections in order, the empty one left out, no Open event', (
    tester,
  ) async {
    await _pump(
      tester,
      ReportView(report: _report, day: DateTime(2026, 10, 8)),
    );

    expect(find.text('Thursday, October 8'), findsOneWidget);
    expect(find.text('Topics covered'), findsOneWidget);
    expect(find.text('Her first orders'), findsOneWidget);
    expect(find.text('Issues encountered'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Topics covered')).dy,
      lessThan(tester.getTopLeft(find.text('To do')).dy),
    );
    expect(find.text('Open event'), findsNothing);
  });

  testWidgets('Open event, with a way to open it', (tester) async {
    var opened = false;
    await _pump(
      tester,
      ReportView(
        report: _report,
        day: DateTime(2026, 10, 8),
        onOpenEvent: () => opened = true,
      ),
    );

    await tester.tap(find.text('Open event'));
    expect(opened, isTrue);
  });

  testWidgets('the sheet closes before it opens the event', (tester) async {
    var opened = false;
    await _pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showReportSheet(
            context,
            report: _report,
            day: DateTime(2026, 10, 8),
            onOpenEvent: () => opened = true,
          ),
          child: const Text('Show'),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    expect(find.byType(ReportView), findsOneWidget);
    await tester.tap(find.text('Open event'));
    await tester.pumpAndSettle();

    expect(opened, isTrue);
    expect(find.byType(ReportView), findsNothing);
  });

  testWidgets('wider: a side panel, closed by its button', (tester) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 440,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showReportSheet(
                context,
                report: _report,
                day: DateTime(2026, 10, 8),
              ),
              child: const Text('Show'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();
    // Beside the pane, which stays in view.
    expect(tester.getTopRight(find.byType(ReportView)).dx, lessThan(1000));
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();

    expect(find.byType(ReportView), findsNothing);
  });
}
