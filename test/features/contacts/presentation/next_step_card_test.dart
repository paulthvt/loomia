import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/action_item.dart';
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

Person _sarah({
  Stage stage = Stage.prospect,
  List<Reminder> reminders = const [],
}) => Person(
  id: 'p1',
  name: 'Sarah Martin',
  stage: stage,
  stageSince: DateTime.utc(2026, 3, 4),
  reminders: reminders,
);

final _late = (
  id: 'r1',
  text: 'Call back about the diffuser',
  dueOn: DateTime(2026, 9, 27),
  createdAt: DateTime.utc(2026, 9),
);
final _later = (
  id: 'r2',
  text: 'Send her the price list',
  dueOn: DateTime(2026, 10, 4),
  createdAt: DateTime.utc(2026, 9),
);

class _Calls {
  final ticks = <OnStep>[];
  var resumes = 0;
  var notNows = 0;
  var followWiths = 0;
  var becameCustomers = 0;
  final tickedReminders = <Reminder>[];
  final editedReminders = <Reminder>[];
  var addReminders = 0;
  var retries = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  WorkflowProgress? progress, {
  Person? person,
  bool busy = false,
  bool waiting = false,
  bool failed = false,
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
          waiting: waiting,
          onRetry: failed ? () => calls.retries++ : null,
          onTickReminder: calls.tickedReminders.add,
          onEditReminder: calls.editedReminders.add,
          onAddReminder: () => calls.addReminders++,
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
    expect(find.text('Ask how the samples went'), findsOneWidget);
    // Where it is goes on the step's row, under when: the header also sits
    // above the reminders.
    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Samples · 4 of 5'), findsOneWidget);
    expect(find.byIcon(Icons.route_rounded), findsOneWidget);
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
    expect(find.text('Samples · 1 of 5'), findsOneWidget);
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

  group('reminders', () {
    final reminders = _sarah(reminders: [_late, _later]);

    testWidgets('sorted with the step by day, no date chip', (tester) async {
      await _pump(tester, onStep(4, _today), person: reminders);

      final late = tester.getTopLeft(find.text(_late.text)).dy;
      final later = tester.getTopLeft(find.text(_later.text)).dy;
      final step = tester.getTopLeft(find.text('Ask how the samples went')).dy;
      expect(late, lessThan(step));
      expect(step, lessThan(later));
      expect(find.text('2 days late'), findsOneWidget);
      expect(find.text('Due in 5 days'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsNWidgets(2));
      expect(find.byType(DateChip), findsNothing);
      expect(find.text('NEXT STEP'), findsOneWidget);
      expect(find.text('Add a reminder'), findsOneWidget);
    });

    testWidgets('on the same day, the step first', (tester) async {
      await _pump(tester, onStep(4, _later.dueOn), person: reminders);

      final later = tester.getTopLeft(find.text(_later.text)).dy;
      final step = tester.getTopLeft(find.text('Ask how the samples went')).dy;
      expect(step, lessThan(later));
    });

    testWidgets('tick, edit and add', (tester) async {
      final calls = await _pump(tester, onStep(4, _today), person: reminders);

      await tester.tap(find.byTooltip('Mark "${_late.text}" done'));
      await tester.tap(find.text(_later.text));
      await tester.tap(find.text('Add a reminder'));

      expect(calls.tickedReminders, [_late]);
      expect(calls.editedReminders, [_later]);
      expect(calls.addReminders, 1);
      expect(calls.ticks, isEmpty);
    });

    testWidgets('kept while paused, when done, and with no workflow, which '
        'then reads No workflow', (tester) async {
      for (final progress in <WorkflowProgress?>[
        Paused(DateTime.utc(2026, 9)),
        Done(_samples),
        null,
      ]) {
        await _pump(tester, progress, person: reminders);
        expect(find.text(_late.text), findsOneWidget);
        expect(find.text('Add a reminder'), findsOneWidget);
      }
      expect(find.text('No workflow'), findsOneWidget);
      expect(find.text('Nothing planned'), findsNothing);
    });

    testWidgets('with none and no workflow: Nothing planned', (tester) async {
      await _pump(tester, null);
      expect(find.text('Nothing planned'), findsOneWidget);
      expect(find.text('Add a reminder'), findsOneWidget);
    });

    testWidgets('there while the workflows load, and when they failed', (
      tester,
    ) async {
      await _pump(tester, null, person: reminders, waiting: true);
      expect(find.text(_late.text), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final calls = await _pump(
        tester,
        null,
        person: reminders,
        waiting: true,
        failed: true,
      );
      // The card resizes from the spinner to the message.
      await tester.pumpAndSettle();
      expect(find.text(_late.text), findsOneWidget);
      expect(find.text("Couldn't load the workflows"), findsOneWidget);
      expect(find.text('Nothing planned'), findsNothing);
      await tester.tap(find.text('Try again'));
      expect(calls.retries, 1);
    });
  });
}
