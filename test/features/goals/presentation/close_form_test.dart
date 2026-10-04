import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/close_form.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

final _september = DateTime(2026, 9);

Closing _closing({MonthPlan? plan, Progress? done}) => (
  ritual: (close: _september, plan: DateTime(2026, 10), closes: true),
  closing:
      plan ??
      MonthPlan(
        month: _september,
        ownVolumeTarget: 2800,
        teamVolumeTarget: 6000,
        levelTarget: 'Elite',
        prospectsTarget: 8,
        customersTarget: 6,
        teamMembersTarget: 1,
        loyaltyTarget: 2,
      ),
  done:
      done ??
      const Progress(
        ownVolume: 2650,
        prospects: 9,
        customers: 5,
        teamMembers: 1,
        loyalty: 2,
      ),
  forecast: 3,
  plans: const [],
);

void main() {
  late List<({double? teamVolume, String? level})> closes;
  Object? failWith;

  Future<void> pump(
    WidgetTester tester, {
    Closing? closing,
    BusinessModel model = BusinessModel.doterra,
  }) {
    closes = [];
    failWith = null;
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CloseForm(
            closing: closing ?? _closing(),
            model: model,
            onClose: ({teamVolume, level}) async {
              if (failWith case final failure?) throw failure;
              closes.add((teamVolume: teamVolume, level: level));
            },
          ),
        ),
      ),
    );
  }

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledField, label),
    matching: find.byType(TextFormField),
  );

  testWidgets('what the book counted against the plan', (tester) async {
    await pump(tester);
    // "Reached" is a semantics label.
    final semantics = tester.ensureSemantics();

    expect(find.text('STEP 1 OF 2'), findsOneWidget);
    expect(find.text('How did September go?'), findsOneWidget);
    expect(find.text('2,650 of 2,800 PV'), findsOneWidget);
    expect(find.text('9 of 8'), findsOneWidget);
    expect(find.text('5 of 6'), findsOneWidget);
    // Prospects (over), team members and LRPs reached; volume and customers
    // under, with no mark.
    expect(find.bySemanticsLabel('Reached'), findsNWidgets(3));
    final bars = tester
        .widgetList<LoomiaProgressBar>(find.byType(LoomiaProgressBar))
        .map((bar) => bar.value)
        .toList();
    expect(bars.where((value) => value == 1), hasLength(3));
    expect(find.text('You planned 6,000'), findsOneWidget);
    expect(find.text('You aimed for Elite'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Next closes with the two typed figures', (tester) async {
    await pump(tester);

    await tester.enterText(field('OV'), '5000');
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Executive').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(closes, [(teamVolume: 5000.0, level: 'Executive')]);
  });

  testWidgets('both typed figures are optional', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(closes, [(teamVolume: null, level: null)]);
  });

  testWidgets('a failed close keeps the step and what was typed', (
    tester,
  ) async {
    await pump(tester);
    failWith = PeopleFailure.network;

    await tester.enterText(field('OV'), '5000');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.byType(FormError), findsOneWidget);
    expect(tester.widget<TextFormField>(field('OV')).controller!.text, '5000');
    expect(closes, isEmpty);
  });

  testWidgets('no target: the count alone, no bar', (tester) async {
    // "Reached" is a semantics label.
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      closing: _closing(plan: MonthPlan(month: _september)),
    );

    expect(find.text('2,650 PV'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.byType(LoomiaProgressBar), findsNothing);
    expect(find.bySemanticsLabel('Reached'), findsNothing);
    semantics.dispose();
  });

  testWidgets('Other: neutral words, a typed level', (tester) async {
    await pump(tester, model: BusinessModel.other);

    expect(find.text('2,650 of 2,800'), findsOneWidget);
    expect(field('Team volume'), findsOneWidget);
    await tester.enterText(field('Level'), ' Gold ');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(closes.single.level, 'Gold');
    expect(find.textContaining('PV'), findsNothing);
  });
}
