import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/next_step_section.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../workflows/fake_workflow_repository.dart';

final _today = DateTime(2026, 9, 29);
final _samples = FakeWorkflowRepository.samples().first;
final _newCustomer = FakeWorkflowRepository.samples()[2];

Person _sarah({Stage stage = Stage.prospect}) => Person(
  id: 'p1',
  name: 'Sarah Martin',
  stage: stage,
  stageSince: DateTime.utc(2026, 3, 4),
);

class _Calls {
  final ticks = <OnStep>[];
  var resumes = 0;
  var notNows = 0;
  var followWiths = 0;
  var becameCustomers = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  WorkflowProgress? progress, {
  Person? person,
  bool busy = false,
}) async {
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: NextStepCard(
          person: person ?? _sarah(),
          progress: progress,
          today: _today,
          busy: busy,
          onTick: calls.ticks.add,
          onResume: () => calls.resumes++,
          onNotNow: () => calls.notNows++,
          onFollowWith: () => calls.followWiths++,
          onBecameCustomer: () => calls.becameCustomers++,
        ),
      ),
    ),
  );
  return calls;
}

void main() {
  OnStep onStep(int index, DateTime due) => OnStep(
    workflow: _samples,
    step: _samples.steps[index - 1],
    index: index,
    total: 5,
    due: due,
  );

  testWidgets('on a step: its name, where it is, when it is due', (
    tester,
  ) async {
    final calls = await _pump(tester, onStep(4, _today));

    expect(find.text('NEXT STEP'), findsOneWidget);
    expect(find.text('Samples · 4 of 5'), findsOneWidget);
    expect(find.text('Ask how the samples went'), findsOneWidget);
    expect(find.text('Due today'), findsOneWidget);
    await tester.tap(find.byTooltip('Mark "Ask how the samples went" done'));

    expect(calls.ticks.single.step.id, 'samples-4');
  });

  testWidgets('late, with the step\'s note', (tester) async {
    final step = OnStep(
      workflow: _samples,
      step: const WorkflowStep(
        id: 'samples-1',
        position: 1,
        label: 'Send a first message',
        days: 0,
        note: 'Keep it short',
      ),
      index: 1,
      total: 5,
      due: _today.subtract(const Duration(days: 3)),
    );
    await _pump(tester, step);

    expect(find.text('3 days late — Keep it short'), findsOneWidget);
  });

  testWidgets('busy: the ring stays filled and takes no second tap', (
    tester,
  ) async {
    await _pump(tester, onStep(2, _today), busy: true);

    final ring = tester.widget<IconButton>(find.byType(IconButton));
    expect((ring.isSelected, ring.onPressed), (true, null));
  });

  testWidgets('a prospect done: how did it end, two ways on', (tester) async {
    final calls = await _pump(tester, Done(_samples));

    expect(find.text('SAMPLES — DONE'), findsOneWidget);
    expect(find.text('How did it end with Sarah?'), findsOneWidget);
    expect(
      find.text(
        'All 5 steps are done. Their notes and history stay whatever you pick.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Became a customer'));
    await tester.tap(find.text('Not now'));

    expect(calls.becameCustomers, 1);
    expect(calls.notNows, 1);
  });

  testWidgets('a customer done: follow with something else', (tester) async {
    final calls = await _pump(
      tester,
      Done(_newCustomer),
      person: _sarah(stage: Stage.customer),
    );

    expect(find.text('NEW CUSTOMER — DONE'), findsOneWidget);
    expect(find.text('All 4 steps are done with Sarah.'), findsOneWidget);
    await tester.tap(find.text('Follow with…'));

    expect(calls.followWiths, 1);
  });

  testWidgets('paused: since when, and Resume', (tester) async {
    final calls = await _pump(tester, Paused(DateTime(2026, 7, 12, 10)));

    expect(find.text('Paused since July 12'), findsOneWidget);
    await tester.tap(find.text('Resume'));

    expect(calls.resumes, 1);
  });

  testWidgets('no workflow: nothing planned, follow with', (tester) async {
    final calls = await _pump(tester, null);

    expect(find.text('Nothing planned'), findsOneWidget);
    await tester.tap(find.text('Follow with…'));

    expect(calls.followWiths, 1);
  });
}
