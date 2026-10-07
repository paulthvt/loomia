import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_event_workflow_repository.dart';

const _failed = "Couldn't save. Check your connection and try again.";

EventWorkflow _workshop(FakeEventWorkflowRepository repository) =>
    repository.store.firstWhere((w) => w.id == 'workshop');

Iterable<String> _renames(FakeEventWorkflowRepository repository) =>
    repository.calls.where((call) => call.startsWith('rename'));

Future<ProviderContainer> _openWorkshop(
  WidgetTester tester,
  FakeEventWorkflowRepository eventWorkflows, {
  Size size = const Size(390, 2000),
}) async {
  final container = await pumpLoomia(
    tester,
    size: size,
    eventWorkflows: eventWorkflows,
  );
  container
      .read(routerProvider)
      .go(Routes.settingsEventWorkflowLocation('workshop'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('Workflows lists the event workflows; one opens', (tester) async {
    final container = await pumpLoomia(tester, size: const Size(390, 2000));
    container.read(routerProvider).go(Routes.settingsWorkflows);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('EVENTS'), 200);
    expect(find.text('Workshop'), findsOneWidget);

    await tester.tap(find.text('Workshop'));
    await tester.pumpAndSettle();

    expect(find.text("Remind everyone it's tomorrow"), findsOneWidget);
    expect(find.text('1 day before'), findsOneWidget);
    expect(find.text('1 day after'), findsOneWidget);
  });

  testWidgets('a step three days before', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 2000),
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
    final workshop = eventWorkflows.store.firstWhere((w) => w.id == 'workshop');
    expect(
      workshop.steps.first,
      isA<EventWorkflowStep>()
          .having((step) => step.label, 'label', 'Book the room')
          .having((step) => step.days, 'days', -3),
    );
  });

  testWidgets('prospects can keep their workflow', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    await _openWorkshop(tester, eventWorkflows);

    await tester.tap(find.text('Samples'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep their workflow').last);
    await tester.pumpAndSettle();

    expect(eventWorkflows.calls, contains('setFollowUps(workshop)'));
    expect(_workshop(eventWorkflows).followUps, {
      Stage.customer: 'new-customer',
    });
    expect(find.text('Samples'), findsNothing);
  });

  testWidgets('a failed follow-up save shows the saved one again', (
    tester,
  ) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    await _openWorkshop(tester, eventWorkflows);
    eventWorkflows.failWith = PeopleFailure.network;

    await tester.tap(find.text('Samples'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep their workflow').last);
    await tester.pumpAndSettle();

    expect(eventWorkflows.calls, contains('setFollowUps(workshop)'));
    expect(find.text(_failed), findsOneWidget);
    expect(find.text('Samples'), findsOneWidget);
    expect(_workshop(eventWorkflows).followUps[Stage.prospect], 'samples');
  });

  testWidgets('desktop: typed name saved when go() tears down the editor', (
    tester,
  ) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    final container = await _openWorkshop(
      tester,
      eventWorkflows,
      size: const Size(1440, 900),
    );

    await tester.enterText(find.byType(TextField).first, 'Open evening');
    // While focused, navigate away: the field is torn down with the typed name.
    container.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();

    expect(_renames(eventWorkflows), ['rename(workshop, Open evening)']);
  });

  testWidgets('mobile: typed name saved when go() tears down the editor', (
    tester,
  ) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    final container = await _openWorkshop(tester, eventWorkflows);

    await tester.enterText(find.byType(TextField).first, 'Open evening');
    container.read(routerProvider).go(Routes.today);
    await tester.pumpAndSettle();

    expect(_renames(eventWorkflows), ['rename(workshop, Open evening)']);
    expect(_workshop(eventWorkflows).name, 'Open evening');
  });

  testWidgets('a failed save on the way out is not an uncaught error', (
    tester,
  ) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    final container = await _openWorkshop(
      tester,
      eventWorkflows,
      size: const Size(1440, 900),
    );
    eventWorkflows.failWith = PeopleFailure.network;

    await tester.enterText(find.byType(TextField).first, 'Open evening');
    container.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();

    expect(_renames(eventWorkflows), ['rename(workshop, Open evening)']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new event workflow; delete goes back', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 2000),
      eventWorkflows: eventWorkflows,
    );

    // Create workflow directly and navigate to it
    final created = await eventWorkflows.create('Training');
    container
        .read(routerProvider)
        .go(Routes.settingsEventWorkflowLocation(created.id));
    await tester.pumpAndSettle();

    expect(find.text('No steps yet.'), findsOneWidget);

    // Scroll to and tap delete
    await tester.ensureVisible(find.text('Delete workflow').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete workflow').last);
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
