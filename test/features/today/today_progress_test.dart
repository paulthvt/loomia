import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/hero_panel.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/team/domain/check_in.dart';
import 'package:loomia/features/today/domain/due.dart';
import 'package:loomia/features/today/presentation/all_done_card.dart';
import 'package:loomia/features/today/presentation/today_hero.dart';
import 'package:loomia/features/today/presentation/today_page.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

final _now = DateTime(2026, 10, 12, 9);

final _samples = Workflow(
  id: 'samples',
  stage: Stage.prospect,
  name: 'Samples',
  isDefault: true,
  steps: const [
    WorkflowStep(id: 's1', position: 1, label: 'Send a first message', days: 0),
  ],
);

Due _due(String name) => DueStep(
  Person(
    id: name,
    name: name,
    stage: Stage.prospect,
    stageSince: DateTime.utc(2026, 9),
  ),
  OnStep(
    workflow: _samples,
    step: _samples.steps.first,
    index: 1,
    total: 1,
    due: DateTime(2026, 10, 12),
  ),
);

const _body =
    "Congrats, Pauline — that's everyone and every task. When someone is "
    "worth a message, they'll show up here.";

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required List<Due> due,
    required int? done,
    Size size = const Size(390, 844),
    List<CheckIn> checkIns = const [],
    Locale? locale,
  }) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        locale: locale,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TodayView(
          due: AsyncData(due),
          tasks: const AsyncData([]),
          done: done,
          now: _now,
          firstName: 'Pauline',
          checkIns: checkIns,
          onTick: (_) {},
          onOpen: (_) {},
          onRetry: () {},
          onRefresh: () async {},
        ),
      ),
    );
  }

  testWidgets('the bar counts rows done out of the whole day; the headline '
      'still counts people', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, due: [_due('Anna'), _due('Bruno')], done: 1);

    expect(find.text('1 of 3 done'), findsOneWidget);
    expect(find.text('2 people are worth a message today'), findsOneWidget);
    // Heard once, as the caption; never as a percentage.
    expect(find.bySemanticsLabel('1 of 3 done'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('%')), findsNothing);
    handle.dispose();
  });

  testWidgets('an unknown count: the sentence alone', (tester) async {
    await pump(tester, due: [_due('Anna')], done: null);

    expect(find.text('One person is worth a message today'), findsOneWidget);
    expect(find.byType(LoomiaProgressBar), findsNothing);
  });

  testWidgets('everything done: the hero stays, full', (tester) async {
    await pump(tester, due: const [], done: 3);

    expect(find.text("You're all done for today"), findsOneWidget);
    expect(find.text('3 of 3 done'), findsOneWidget);
    expect(find.text(_body), findsOneWidget);
    expect(find.text('You are up to date'), findsNothing);
  });

  for (final done in [0, null]) {
    testWidgets('nothing due and nothing done ($done): up to date', (
      tester,
    ) async {
      await pump(tester, due: const [], done: done);

      expect(find.text('You are up to date'), findsOneWidget);
      expect(find.byType(TodayHero), findsNothing);
      expect(find.byType(LoomiaProgressBar), findsNothing);
    });
  }

  testWidgets('everything done on desktop: the band carries it, no white '
      'card', (tester) async {
    await pump(tester, due: const [], done: 2, size: _desktop);

    expect(find.byType(AllDoneBand), findsOneWidget);
    expect(find.byType(AllDoneCard), findsNothing);
    expect(find.byType(HeroCard), findsNothing);
    expect(
      find.ancestor(of: find.text(_body), matching: find.byType(HeroPanel)),
      findsOneWidget,
    );
  });

  testWidgets('done on desktop: no empty Tasks header', (tester) async {
    await pump(tester, due: const [], done: 2, size: _desktop);

    expect(find.text('Tasks'), findsNothing);
  });

  testWidgets('done on desktop: Catch up leads the main column, not the side', (
    tester,
  ) async {
    await pump(
      tester,
      due: const [],
      done: 2,
      size: _desktop,
      checkIns: [_lea],
    );

    expect(find.text('Catch up'), findsOneWidget);
    expect(find.text('Léa Moreau'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Catch up')).dx, lessThan(1440 / 2));
    expect(find.text('Hide'), findsNothing);
  });

  testWidgets('done on desktop, undone: back to the card', (tester) async {
    await pump(tester, due: const [], done: 2, size: _desktop);
    await pump(tester, due: [_due('Anna')], done: 1, size: _desktop);
    await tester.pumpAndSettle();

    expect(find.byType(HeroCard), findsOneWidget);
    expect(find.byType(AllDoneBand), findsNothing);
  });

  testWidgets('done band survives French at 1.3x on a 1200 window', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(
      tester,
      due: const [],
      done: 2,
      size: const Size(1200, 900),
      checkIns: [_lea],
      locale: const Locale('fr'),
    );

    expect(find.byType(AllDoneBand), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone done is unchanged', (tester) async {
    await pump(tester, due: const [], done: 2);

    expect(find.byType(AllDoneCard), findsOneWidget);
    expect(find.byType(AllDoneBand), findsNothing);
    expect(find.text('Tasks'), findsOneWidget);
  });
}

const _desktop = Size(1440, 900);

final CheckIn _lea = (
  person: Person(
    id: 'lea',
    name: 'Léa Moreau',
    stage: Stage.team,
    stageSince: DateTime.utc(2025, 2),
  ),
  reason: CheckInReason.quiet,
  since: DateTime(2026, 7, 12),
  days: 92,
);
