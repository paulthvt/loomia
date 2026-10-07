import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_event_workflow_repository.dart';

void main() {
  testWidgets('Workflows lists the event workflows; one opens', (tester) async {
    final container = await pumpLoomia(tester, size: const Size(390, 1200));
    container.read(routerProvider).go(Routes.settingsWorkflows);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('EVENTS'), 200);
    expect(find.text('Workshop'), findsOneWidget);
    await tester.ensureVisible(find.text('Workshop'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Workshop'));
    await tester.pumpAndSettle();

    expect(find.text("Remind everyone it's tomorrow"), findsOneWidget);
    expect(find.text('1 day before'), findsOneWidget);
    expect(find.text('1 day after'), findsOneWidget);
    expect(find.text('Prospects who were there'), findsOneWidget);
  });

  testWidgets('a step three days before', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1200),
      eventWorkflows: eventWorkflows,
    );
    container
        .read(routerProvider)
        .go(Routes.settingsEventWorkflowLocation('workshop'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a step'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'What to do'),
        matching: find.byType(TextFormField),
      ),
      'Book the room',
    );
    await tester.tap(find.text('Before'));
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(LabeledField, 'Days'),
        matching: find.byType(TextFormField),
      ),
      '3',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(eventWorkflows.calls, contains('addStep(workshop)'));
    expect(
      eventWorkflows.store.single.steps.first,
      isA<EventWorkflowStep>()
          .having((step) => step.label, 'label', 'Book the room')
          .having((step) => step.days, 'days', -3),
    );
  });

  testWidgets('prospects can keep their workflow', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1200),
      eventWorkflows: eventWorkflows,
    );
    container
        .read(routerProvider)
        .go(Routes.settingsEventWorkflowLocation('workshop'));
    await tester.pumpAndSettle();

    expect(find.text('Prospects who were there'), findsOneWidget);
    expect(find.text('Samples'), findsOneWidget);

    // Verify initial state has prospect workflow
    expect(
      eventWorkflows.store.single.followUps[Stage.prospect],
      'samples',
    );
  });

  testWidgets('a new event workflow opens on itself; delete goes back', (
    tester,
  ) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 1200),
      eventWorkflows: eventWorkflows,
    );
    container.read(routerProvider).go(Routes.settingsWorkflows);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('New event workflow'), 200);
    await tester.ensureVisible(find.text('New event workflow'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New event workflow'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Training');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(find.text('No steps yet.'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Delete workflow'), 200);
    await tester.tap(find.text('Delete workflow'));
    await tester.pumpAndSettle();
    expect(
      find.text('Events of this kind keep their title, without the steps.'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(
      eventWorkflows.calls.where((call) => call.startsWith('delete(')),
      hasLength(1),
    );
    expect(find.text('EVENTS'), findsOneWidget);
  });
}
