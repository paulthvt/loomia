import 'dart:async';

import 'package:flutter/semantics.dart'
    show CustomSemanticsAction, SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/workflow_editor.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';
import 'package:material_ui/material_ui.dart';

import '../../contacts/fake_people_repository.dart';
import '../fake_workflow_repository.dart';
import 'workflows_harness.dart';

const _failed = "Couldn't save. Check your connection and try again.";

Finder _title(String text) =>
    find.descendant(of: find.byType(LoomiaTopBar), matching: find.text(text));

String _name(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField).first).controller!.text;

Iterable<String> _renames(FakeWorkflowRepository workflows) =>
    workflows.calls.where((call) => call.startsWith('rename'));

Future<void> _typeName(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextField).first, name);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
}

Person _on(String id, String workflowId) => Person(
  id: id,
  name: 'Person $id',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 3, 4),
  place: (workflowId: workflowId, atPosition: 1, lastTick: today()),
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The row of the step labelled [label], as semantics sees it: the node
/// that carries ReorderableListView's Move up / Move down actions.
FinderBase<SemanticsNode> _stepNode(String label) => find.semantics
    .ancestor(
      of: find.semantics.byLabel(RegExp(label)),
      matching: find.semantics.byPredicate(
        (node) =>
            node.getSemanticsData().customSemanticsActionIds?.isNotEmpty ??
            false,
      ),
      matchRoot: true,
    )
    .first;

const _moveDown = CustomSemanticsAction(label: 'Move down');

/// Health professionals is a prospect workflow.
final _defaultSwitch = find.widgetWithText(
  SwitchListTile,
  'Default for new prospects',
);
final _repeatSwitch = find.widgetWithText(
  SwitchListTile,
  'Start over after the last step',
);

Workflow _weekly({bool repeats = true, int days = 7}) => Workflow(
  id: 'weekly',
  stage: Stage.team,
  name: 'Weekly check-in',
  isDefault: false,
  repeats: repeats,
  steps: [WorkflowStep(id: 'w1', position: 1, label: 'Check in', days: days)],
);

void main() {
  _repeatTests();
  testWidgets('shows the stage and the name', (tester) async {
    await openWorkflows(tester, Routes.settingsWorkflowLocation('samples'));

    expect(_title('Samples'), findsOneWidget);
    expect(find.text('PROSPECT'), findsOneWidget);
    expect(_name(tester), 'Samples');
  });

  testWidgets('What\'s next: the stage\'s other workflows, ticked to offer', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      size: const Size(390, 2400),
      workflows: workflows,
    );

    expect(find.text("WHAT'S NEXT"), findsOneWidget);
    final health = find.widgetWithText(
      CheckboxListTile,
      'Health professionals',
    );
    expect(health, findsOneWidget);
    expect(find.widgetWithText(CheckboxListTile, 'Samples'), findsNothing);
    expect(find.widgetWithText(CheckboxListTile, 'New customer'), findsNothing);

    await tester.tap(health);
    await tester.pumpAndSettle();
    expect(workflows.calls, contains('addNext(samples, health)'));
    expect(tester.widget<CheckboxListTile>(health).value, isTrue);

    await tester.tap(health);
    await tester.pumpAndSettle();
    expect(workflows.calls, contains('removeNext(samples, health)'));
  });

  testWidgets('a new name is trimmed, saved and shown', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    await _typeName(tester, '  Tasters  ');

    expect(_renames(workflows), ['rename(samples, Tasters)']);
    expect(_title('Tasters'), findsOneWidget);
    expect(_name(tester), 'Tasters');
  });

  testWidgets('an empty name puts the saved one back without writing', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    await _typeName(tester, '   ');
    expect(_name(tester), 'Samples');

    await _typeName(tester, 'Samples');
    expect(_renames(workflows), isEmpty);
  });

  testWidgets('a failed rename says so and puts the saved name back', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );
    workflows.failWith = PeopleFailure.network;

    await _typeName(tester, 'Tasters');

    expect(find.text(_failed), findsOneWidget);
    expect(_name(tester), 'Samples');
    expect(_title('Samples'), findsOneWidget);
  });

  testWidgets('a bad link says the workflow is not here', (tester) async {
    await openWorkflows(tester, Routes.settingsWorkflowLocation('gone'));

    expect(find.text("This workflow isn't here anymore"), findsOneWidget);

    await tester.tap(find.text('Back to workflows'));
    await tester.pumpAndSettle();
    expect(find.text('Health professionals'), findsOneWidget);
  });

  testWidgets('a workflow deleted elsewhere says so', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final container = await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    // Another device deleted it; this one reloads.
    workflows.store.removeWhere((workflow) => workflow.id == 'samples');
    container.invalidate(workflowsProvider('p@example.com'));
    await tester.pumpAndSettle();

    expect(find.text("This workflow isn't here anymore"), findsOneWidget);
    await tester.tap(find.text('Back to workflows'));
    await tester.pumpAndSettle();
    expect(find.text('Health professionals'), findsOneWidget);
    expect(find.text('Samples'), findsNothing);
  });

  testWidgets('desktop: typed name saved when go() tears down the editor', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final container = await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
      size: const Size(1440, 900),
    );

    await tester.enterText(find.byType(TextField).first, 'Tasters');
    // While focused, navigate away: the field is torn down with the typed name.
    container.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();

    expect(_renames(workflows), ['rename(samples, Tasters)']);
  });

  testWidgets('mobile: typed name saved when go() tears down the editor', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final container = await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    await tester.enterText(find.byType(TextField).first, 'Tasters');
    container.read(routerProvider).go(Routes.today);
    await tester.pumpAndSettle();

    expect(_renames(workflows), ['rename(samples, Tasters)']);
  });

  testWidgets('a failed save on the way out is not an uncaught error', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final container = await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );
    workflows.failWith = PeopleFailure.network;

    await tester.enterText(find.byType(TextField).first, 'Tasters');
    container.read(routerProvider).go(Routes.today);
    await tester.pumpAndSettle();

    expect(_renames(workflows), ['rename(samples, Tasters)']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop: list shows the new name after deactivate save', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final container = await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
      size: const Size(1440, 900),
    );

    await tester.enterText(find.byType(TextField).first, 'Tasters');
    container.read(routerProvider).go(Routes.settingsWorkflows);
    await tester.pumpAndSettle();

    expect(find.text('Tasters'), findsOneWidget);
    expect(find.text('Samples'), findsNothing);
    expect(_renames(workflows), ['rename(samples, Tasters)']);
  });

  testWidgets('mobile: list shows the new name after deactivate save', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final container = await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    await tester.enterText(find.byType(TextField).first, 'Tasters');
    container.read(routerProvider).go(Routes.settingsWorkflows);
    await tester.pumpAndSettle();

    expect(find.text('Tasters'), findsOneWidget);
    expect(find.text('Samples'), findsNothing);
    expect(_renames(workflows), ['rename(samples, Tasters)']);
  });

  testWidgets('each step says when it comes due', (tester) async {
    await openWorkflows(tester, Routes.settingsWorkflowLocation('samples'));

    // Samples: 0, 1, 4, 3, 7.
    expect(find.text('When you start'), findsOneWidget);
    expect(find.text('1 day after'), findsOneWidget);
    expect(find.text('4 days after'), findsOneWidget);
    expect(find.text('3 days after'), findsOneWidget);
    expect(find.text('7 days after'), findsOneWidget);
    expect(find.text('Default for new prospects'), findsOneWidget);
  });

  testWidgets('no steps says so', (tester) async {
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('empty'),
      workflows: FakeWorkflowRepository([
        Workflow(
          id: 'empty',
          stage: Stage.customer,
          name: 'Empty',
          isDefault: false,
          steps: const [],
        ),
      ]),
    );

    expect(find.text('No steps yet.'), findsOneWidget);
    expect(find.text('Default for new customers'), findsOneWidget);
  });

  testWidgets('add a step: it is written, then everyone is reloaded', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    final people = FakePeopleRepository();
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
      people: people,
    );
    people.calls.clear();

    await _tapVisible(tester, find.text('Add a step'));
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'What to do'),
        matching: find.byType(TextFormField),
      ),
      'Say thanks',
    );
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Days after the previous step'),
        matching: find.byType(TextFormField),
      ),
      '2',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(workflows.calls, contains('addStep(samples, Say thanks, 2, 6)'));
    expect(find.text('Say thanks'), findsOneWidget);
    // People's current step and due day may have changed on the server.
    expect(people.calls, ['list()']);
  });

  testWidgets('edit a step, then remove it', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    await _tapVisible(tester, find.text('Send the samples'));
    expect(find.text('Step 2'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'What to do'),
        matching: find.byType(TextFormField),
      ),
      'Send the kit',
    );
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Days after the previous step'),
        matching: find.byType(TextFormField),
      ),
      '3',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(workflows.calls, contains('updateStep(samples-2, Send the kit, 3)'));
    expect(find.text('Send the kit'), findsOneWidget);

    await _tapVisible(tester, find.text('Send the kit'));
    await tester.tap(find.text('Remove this step'));
    await tester.pumpAndSettle();
    expect(workflows.calls, contains('removeStep(samples-2)'));
    expect(find.text('Send the kit'), findsNothing);
  });

  testWidgets('Move down puts a step between its two next ones', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );

    tester.semantics.customAction(_stepNode('Send a first message'), _moveDown);
    await tester.pumpAndSettle();

    // Between Send the samples (2) and Samples arrived (3).
    expect(workflows.calls, contains('moveStep(samples-1, 2.5)'));
    semantics.dispose();
  });

  testWidgets('a step dropped where it was writes nothing', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );
    // Flutter's own list filters this out today; the editor does not rely on
    // it, so the callback is called directly.
    tester
        .widget<ReorderableListView>(find.byType(ReorderableListView))
        .onReorderItem!(1, 1);
    await tester.pumpAndSettle();

    expect(
      workflows.calls.where((call) => call.startsWith('moveStep')),
      isEmpty,
    );
  });

  testWidgets('a failed move says so and shows the saved order', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );
    workflows.failWith = PeopleFailure.network;

    tester.semantics.customAction(_stepNode('Send a first message'), _moveDown);
    await tester.pumpAndSettle();

    expect(workflows.calls, contains('moveStep(samples-1, 2.5)'));
    expect(find.text(_failed), findsOneWidget);
    expect(find.byType(WorkflowEditor), findsOneWidget);
    final labels = tester
        .widgetList<ListTile>(
          find.descendant(
            of: find.byType(ReorderableListView),
            matching: find.byType(ListTile),
          ),
        )
        .map((tile) => (tile.title! as Text).data)
        .take(2);
    expect(labels, ['Send a first message', 'Send the samples']);
    semantics.dispose();
  });

  testWidgets('dragging a step by its handle moves it', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );
    final handle = find.byIcon(Icons.drag_handle_rounded).first;
    await tester.ensureVisible(handle);
    await tester.pumpAndSettle();
    // One row plus the hairline under it.
    double top(String label) =>
        tester.getTopLeft(find.widgetWithText(ListTile, label)).dy;
    final row = top('Send the samples') - top('Send a first message');

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump();
    await gesture.moveBy(Offset(0, row / 2));
    await tester.pump();
    await gesture.moveBy(Offset(0, row / 2));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(workflows.calls, contains('moveStep(samples-1, 2.5)'));
  });

  testWidgets('a move while one is saving is ignored', (tester) async {
    final semantics = tester.ensureSemantics();
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );
    workflows.gate = Completer<void>();

    tester.semantics.customAction(_stepNode('Send a first message'), _moveDown);
    await tester.pump();
    // Positions are still the saved ones: this must not be sent.
    tester.semantics.customAction(_stepNode('Samples arrived'), _moveDown);
    await tester.pump();

    final moves = workflows.calls.where((call) => call.startsWith('moveStep'));
    expect(moves, ['moveStep(samples-1, 2.5)']);

    workflows.gate!.complete();
    await tester.pumpAndSettle();
    expect(
      workflows.calls.where((call) => call.startsWith('moveStep')),
      hasLength(1),
    );
    semantics.dispose();
  });

  testWidgets('the switch makes it the default', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('health'),
      workflows: workflows,
    );

    await _tapVisible(tester, _defaultSwitch);

    expect(workflows.calls, contains('setDefault(health, true)'));
    expect(tester.widget<SwitchListTile>(_defaultSwitch).value, isTrue);
  });

  testWidgets('a failed switch says so and shows the saved value', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('health'),
      workflows: workflows,
    );
    workflows.failWith = PeopleFailure.network;

    await _tapVisible(tester, _defaultSwitch);

    expect(find.text(_failed), findsOneWidget);
    expect(tester.widget<SwitchListTile>(_defaultSwitch).value, isFalse);
  });

  testWidgets('delete says who follows it, then returns to the list', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
      people: FakePeopleRepository([
        _on('p1', 'samples'),
        _on('p2', 'samples'),
        _on('p3', 'health'),
      ]),
    );

    await _tapVisible(tester, find.text('Delete workflow'));
    expect(find.text('Delete Samples?'), findsOneWidget);
    expect(
      find.text(
        "2 people follow it. They'll have nothing planned; their history "
        'stays.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(workflows.calls, contains('delete(samples)'));
    expect(find.byType(WorkflowEditor), findsNothing);
    expect(find.text('Health professionals'), findsOneWidget);
    expect(find.text('Samples'), findsNothing);
  });

  testWidgets('delete with no one on it; Cancel deletes nothing', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('health'),
      workflows: workflows,
      people: FakePeopleRepository([_on('p1', 'samples')]),
    );

    await _tapVisible(tester, find.text('Delete workflow'));
    expect(find.text('No one follows it.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(workflows.calls.where((call) => call.startsWith('delete')), isEmpty);
    expect(find.byType(WorkflowEditor), findsOneWidget);
  });
  testWidgets('a failed delete says so and stays on the workflow', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      workflows: workflows,
    );
    workflows.failWith = PeopleFailure.network;

    await _tapVisible(tester, find.text('Delete workflow'));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(workflows.calls, contains('delete(samples)'));
    expect(find.text(_failed), findsOneWidget);
    expect(find.byType(WorkflowEditor), findsOneWidget);
    expect(_name(tester), 'Samples');
    expect(find.text('Delete workflow'), findsOneWidget);
  });

  testWidgets('delete with people not loaded does not say no one follows it', (
    tester,
  ) async {
    final people = FakePeopleRepository([_on('p1', 'samples')])
      ..failWith = PeopleFailure.network;
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('samples'),
      people: people,
    );

    await _tapVisible(tester, find.text('Delete workflow'));

    expect(find.text('Delete Samples?'), findsOneWidget);
    expect(find.text('No one follows it.'), findsNothing);
    expect(
      find.text("They'll have nothing planned; their history stays."),
      findsOneWidget,
    );
  });
}

void _repeatTests() {
  testWidgets('Start over is saved, and step 1 says it comes back', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository([_weekly(repeats: false)]);
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('weekly'),
      workflows: workflows,
    );
    expect(find.text('7 days after'), findsOneWidget);

    await _tapVisible(tester, _repeatSwitch);

    expect(workflows.calls, contains('setRepeats(weekly, true)'));
    expect(tester.widget<SwitchListTile>(_repeatSwitch).value, isTrue);
    expect(
      find.text('Step 1 comes back 7 days after the last step'),
      findsOneWidget,
    );
    expect(find.text('7 days after the start or the last step'), findsOne);
  });

  testWidgets('Start over needs a day across the steps', (tester) async {
    final workflows = FakeWorkflowRepository([
      _weekly(repeats: false, days: 0),
    ]);
    await openWorkflows(
      tester,
      Routes.settingsWorkflowLocation('weekly'),
      workflows: workflows,
    );

    expect(tester.widget<SwitchListTile>(_repeatSwitch).onChanged, isNull);
    expect(find.text('Needs at least 1 day across the steps'), findsOneWidget);
  });
}
