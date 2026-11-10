import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../calendar/fake_event_repository.dart';
import '../fake_event_workflow_repository.dart';

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

  testWidgets('Several people: on for a workshop, off saves, disabled while '
      'saving', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    await _openWorkshop(tester, eventWorkflows);
    final toggle = find.widgetWithText(SwitchListTile, 'Several people');
    expect(tester.widget<SwitchListTile>(toggle).value, isTrue);

    final gate = eventWorkflows.gate = Completer<void>();
    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);

    gate.complete();
    await tester.pumpAndSettle();
    expect(eventWorkflows.calls, contains('setGroup(workshop, false)'));
    expect(_workshop(eventWorkflows).isGroup, isFalse);
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
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

    // Navigate to Workflows list and create through UI
    container.read(routerProvider).go(Routes.settingsWorkflows);
    await tester.pumpAndSettle();

    await tester.tap(find.text('New event workflow'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Training');
    await tester.tap(find.text('Create'));
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

  testWidgets('a new event workflow with events on Today; delete goes back', (
    tester,
  ) async {
    final eventWorkflows = FakeEventWorkflowRepository(
      FakeEventWorkflowRepository.samples(),
    );
    final events = FakeEventRepository([
      CalendarEvent(
        id: 'e1',
        title: 'Workshop',
        startsAt: DateTime.now().add(const Duration(days: 1)),
        eventWorkflowId: 'workshop',
      ),
    ]);
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 2000),
      eventWorkflows: eventWorkflows,
      events: events,
    );

    // Navigate to Workflows list and create through UI
    container.read(routerProvider).go(Routes.settingsWorkflows);
    await tester.pumpAndSettle();

    await tester.tap(find.text('New event workflow'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Training');
    await tester.tap(find.text('Create'));
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

  testWidgets('Report section: hidden for group, shown for one-person', (
    tester,
  ) async {
    final eventWorkflows = FakeEventWorkflowRepository([
      EventWorkflow(
        id: 'workshop',
        name: 'Workshop',
        steps: const [],
        isGroup: true,
      ),
    ]);
    await _openWorkshop(tester, eventWorkflows);

    expect(find.text('Add field'), findsNothing);

    await tester.tap(find.widgetWithText(SwitchListTile, 'Several people'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Add field'));
    expect(find.text('Add field'), findsOneWidget);
  });

  testWidgets('Report section: add a field', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository([
      EventWorkflow(
        id: 'workshop',
        name: 'Workshop',
        steps: const [],
        isGroup: false,
        reportFields: const ['Topic'],
      ),
    ]);
    await _openWorkshop(tester, eventWorkflows);

    await tester.ensureVisible(find.text('Add field'));
    await tester.tap(find.text('Add field'));
    await tester.pumpAndSettle();

    expect(
      eventWorkflows.calls,
      contains('setReportFields(workshop, [Topic, New])'),
    );
  });

  testWidgets('Report section: rename a field', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository([
      EventWorkflow(
        id: 'workshop',
        name: 'Workshop',
        steps: const [],
        isGroup: false,
        reportFields: const ['Topic'],
      ),
    ]);
    await _openWorkshop(tester, eventWorkflows);

    await tester.ensureVisible(find.text('Topic'));
    await tester.tap(find.text('Topic'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Subject');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      eventWorkflows.calls,
      contains('setReportFields(workshop, [Subject])'),
    );
  });

  testWidgets('Report section: delete a field', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository([
      EventWorkflow(
        id: 'workshop',
        name: 'Workshop',
        steps: const [],
        isGroup: false,
        reportFields: const ['Topic', 'Attendance'],
      ),
    ]);
    await _openWorkshop(tester, eventWorkflows);

    await tester.ensureVisible(find.text('Topic'));
    final topicTile = find.ancestor(
      of: find.text('Topic'),
      matching: find.byType(ListTile),
    );
    final deleteIcon = find.descendant(
      of: topicTile,
      matching: find.byIcon(Icons.delete_outline_rounded),
    );

    await tester.tap(deleteIcon);
    await tester.pumpAndSettle();

    expect(
      eventWorkflows.calls,
      contains('setReportFields(workshop, [Attendance])'),
    );
  });

  testWidgets('Report section: reorder fields', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository([
      EventWorkflow(
        id: 'workshop',
        name: 'Workshop',
        steps: const [],
        isGroup: false,
        reportFields: const ['Topic', 'Attendance', 'Notes'],
      ),
    ]);
    await _openWorkshop(tester, eventWorkflows);

    await tester.ensureVisible(find.text('Topic'));
    expect(find.text('Topic'), findsOneWidget);
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);

    final topicTile = find.ancestor(
      of: find.text('Topic'),
      matching: find.byType(ListTile),
    );
    final dragHandle = find.descendant(
      of: topicTile,
      matching: find.byIcon(Icons.drag_handle_rounded),
    );
    expect(dragHandle, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(dragHandle));
    await tester.pump(kLongPressTimeout);
    await gesture.moveBy(const Offset(0, 150));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      eventWorkflows.calls.any((c) => c.startsWith('setReportFields')),
      isTrue,
    );
  });

  testWidgets('Report section: blank label refused', (tester) async {
    final eventWorkflows = FakeEventWorkflowRepository([
      EventWorkflow(
        id: 'workshop',
        name: 'Workshop',
        steps: const [],
        isGroup: false,
        reportFields: const ['Topic'],
      ),
    ]);
    await _openWorkshop(tester, eventWorkflows);

    await tester.ensureVisible(find.text('Topic'));
    await tester.tap(find.text('Topic'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '   ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(
      eventWorkflows.calls,
      isNot(contains(startsWith('setReportFields'))),
    );
    expect(find.text('Topic'), findsOneWidget);
  });
}
