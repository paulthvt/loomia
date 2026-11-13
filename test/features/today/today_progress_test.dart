import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/features/contacts/domain/person.dart';
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
  }) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TodayView(
          due: AsyncData(due),
          tasks: const AsyncData([]),
          done: done,
          now: _now,
          firstName: 'Pauline',
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

  testWidgets('everything done on desktop: the line on the hero card, '
      'beside the greeting', (tester) async {
    await pump(tester, due: const [], done: 2, size: const Size(1440, 900));

    expect(
      find.ancestor(of: find.text(_body), matching: find.byType(AllDoneCard)),
      findsOneWidget,
    );
    expect(
      tester.getTopLeft(find.text(_body)).dx,
      greaterThan(tester.getTopRight(find.text('Good morning, Pauline')).dx),
    );
  });
}
