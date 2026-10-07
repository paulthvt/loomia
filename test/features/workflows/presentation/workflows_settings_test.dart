import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/presentation/workflow_editor.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_workflow_repository.dart';
import 'workflows_harness.dart';

const _failed = "Couldn't save. Check your connection and try again.";

Finder _title(String text) =>
    find.descendant(of: find.byType(LoomiaTopBar), matching: find.text(text));

Future<void> _openNew(WidgetTester tester) async {
  await tester.ensureVisible(find.text('New workflow'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('New workflow'));
  await tester.pumpAndSettle();
}

Iterable<String> _creates(FakeWorkflowRepository workflows) =>
    workflows.calls.where((call) => call.startsWith('create'));

void main() {
  testWidgets('lists the workflows by stage, the default first', (
    tester,
  ) async {
    await openWorkflows(tester, Routes.settingsWorkflows);

    expect(find.text('PROSPECTS'), findsOneWidget);
    expect(find.text('CUSTOMERS'), findsOneWidget);
    expect(find.text('TEAM'), findsOneWidget);
    // Samples and Getting started have 5 steps; New customer 4.
    expect(find.text('Default · 5 steps'), findsNWidgets(2));
    expect(find.text('Default · 4 steps'), findsOneWidget);
    expect(find.text('4 steps'), findsOneWidget);
    // Workshop event workflow also has 2 steps
    expect(find.text('2 steps'), findsNWidgets(2));
    expect(
      tester.getTopLeft(find.text('Samples')).dy,
      lessThan(tester.getTopLeft(find.text('Health professionals')).dy),
    );

    // Event workflows section appears
    await tester.scrollUntilVisible(find.text('EVENTS'), 200);
    expect(find.text('Workshop'), findsOneWidget);
  });

  testWidgets('a stage with no workflows has no group', (tester) async {
    await openWorkflows(
      tester,
      Routes.settingsWorkflows,
      workflows: FakeWorkflowRepository(
        FakeWorkflowRepository.samples().where(
          (workflow) => workflow.stage != Stage.team,
        ),
      ),
    );

    expect(find.text('PROSPECTS'), findsOneWidget);
    expect(find.text('TEAM'), findsNothing);
  });

  testWidgets('a spinner while loading', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples())
      ..gate = Completer<void>();
    await openWorkflows(
      tester,
      Routes.settingsWorkflows,
      workflows: workflows,
      settle: false,
    );

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.text('Samples'), findsNothing);

    workflows.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Samples'), findsOneWidget);
  });

  testWidgets('a failed load says so, and Try again reloads', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples())
      ..failWith = PeopleFailure.network;
    await openWorkflows(tester, Routes.settingsWorkflows, workflows: workflows);

    expect(find.text("Couldn't load the workflows"), findsOneWidget);

    workflows.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Samples'), findsOneWidget);
  });

  testWidgets('the Settings row opens the list', (tester) async {
    await openWorkflows(tester, Routes.settings);

    await tester.tap(find.text('Workflows'));
    await tester.pumpAndSettle();

    expect(find.text('Samples'), findsOneWidget);
  });

  testWidgets('New workflow creates at the stage picked, then opens it', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(tester, Routes.settingsWorkflows, workflows: workflows);
    await _openNew(tester);

    await tester.enterText(find.byType(TextFormField), 'Weekend');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Customer'));
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(workflows.calls, contains('create(customer, Weekend)'));
    expect(find.byType(WorkflowEditor), findsOneWidget);
    expect(_title('Weekend'), findsOneWidget);
  });

  testWidgets('a blank name is refused, and a name is trimmed', (tester) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(tester, Routes.settingsWorkflows, workflows: workflows);
    await _openNew(tester);

    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name.'), findsOneWidget);
    expect(_creates(workflows), isEmpty);

    await tester.enterText(find.byType(TextFormField), '  Weekend  ');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    // Prospect is picked unless the user picks another stage.
    expect(_creates(workflows), ['create(prospect, Weekend)']);
  });

  testWidgets('a failed create keeps the dialog and what was typed', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(tester, Routes.settingsWorkflows, workflows: workflows);
    await _openNew(tester);
    workflows.failWith = PeopleFailure.network;

    await tester.enterText(find.byType(TextFormField), 'Weekend');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FormError, _failed), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Weekend'), findsOneWidget);
    expect(find.byType(WorkflowEditor), findsNothing);
  });

  testWidgets('a second tap on Create while creating writes nothing more', (
    tester,
  ) async {
    final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
    await openWorkflows(tester, Routes.settingsWorkflows, workflows: workflows);
    await _openNew(tester);
    await tester.enterText(find.byType(TextFormField), 'Weekend');
    workflows.gate = Completer<void>();

    // No frame between the taps: Create is not rebuilt as disabled yet.
    await tester.tap(find.text('Create'));
    await tester.tap(find.text('Create'));
    await tester.pump();
    expect(_creates(workflows), hasLength(1));

    workflows.gate!.complete();
    await tester.pumpAndSettle();
    expect(_creates(workflows), hasLength(1));
    expect(find.byType(WorkflowEditor), findsOneWidget);
  });

  testWidgets('desktop: the list, then the editor, in the pane', (
    tester,
  ) async {
    await openWorkflows(tester, Routes.settings, size: const Size(1440, 900));

    await tester.tap(find.text('Workflows'));
    await tester.pumpAndSettle();
    expect(find.text('Health professionals'), findsOneWidget);
    expect(find.text('PREFERENCES'), findsOneWidget);

    await tester.tap(find.text('Health professionals'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowEditor), findsOneWidget);
    expect(find.text('PREFERENCES'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowEditor), findsNothing);
    expect(find.text('Health professionals'), findsOneWidget);
  });
}
