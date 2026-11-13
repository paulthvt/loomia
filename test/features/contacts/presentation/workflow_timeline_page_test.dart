import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contact_details.dart';
import 'package:loomia/features/contacts/presentation/workflow_timeline_page.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_people_repository.dart';

const _phone = Size(390, 844);
const _desktop = Size(1440, 900);

Person _marie({
  num? position,
  DateTime? pausedAt,
  String workflowId = 'samples',
}) => Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 3, 4),
  place: position == null
      ? null
      : (workflowId: workflowId, atPosition: position, lastTick: today()),
  pausedAt: pausedAt,
);

bool _dimmed(WidgetTester tester, String label) => tester
    .widget<TimelineStep>(
      find.ancestor(of: find.text(label), matching: find.byType(TimelineStep)),
    )
    .dimmed;

void main() {
  late FakePeopleRepository people;

  Future<void> open(
    WidgetTester tester,
    Person marie, {
    Size size = _phone,
  }) async {
    people = FakePeopleRepository([marie]);
    final container = await pumpLoomia(tester, size: size, people: people);
    container.read(routerProvider).go(Routes.contactWorkflowLocation('p1'));
    await tester.pumpAndSettle();
  }

  testWidgets('on a step: before it greyed, it due, after it how far', (
    tester,
  ) async {
    await open(tester, _marie(position: 3));

    expect(find.text('MARIE DUPONT · STEP 3 OF 5'), findsOneWidget);
    expect(find.text('Samples'), findsOneWidget);
    expect(_dimmed(tester, 'Send a first message'), isTrue);
    expect(_dimmed(tester, 'Send the samples'), isTrue);
    expect(_dimmed(tester, 'Samples arrived'), isFalse);
    expect(find.text('Due in 4 days'), findsOneWidget);
    expect(_dimmed(tester, 'Ask how the samples went'), isFalse);
    expect(find.text('3 days later'), findsOneWidget);
    expect(find.text('7 days later'), findsOneWidget);
    expect(find.byTooltip('Mark "Samples arrived" done'), findsOneWidget);
  });

  testWidgets('the tick moves the highlight to the next step', (tester) async {
    await open(tester, _marie(position: 3));

    await tester.tap(find.byTooltip('Mark "Samples arrived" done'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('completeStep(p1, samples-3)'));
    expect(find.text('MARIE DUPONT · STEP 4 OF 5'), findsOneWidget);
    expect(_dimmed(tester, 'Samples arrived'), isTrue);
    expect(find.byTooltip('Mark "Ask how the samples went" done'), findsOne);
  });

  testWidgets(
    'paused: the step says since when, and Resume replaces the tick',
    (tester) async {
      await open(tester, _marie(position: 2, pausedAt: DateTime(2026, 9, 1)));

      expect(find.textContaining('Paused since'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      expect(people.calls, contains('resume(p1)'));
      expect(find.byTooltip('Mark "Send the samples" done'), findsOneWidget);
    },
  );

  testWidgets('finished: every step greyed, nothing to tick', (tester) async {
    await open(tester, _marie(position: 1e9));

    expect(find.text('MARIE DUPONT · FINISHED'), findsOneWidget);
    expect(_dimmed(tester, 'Follow up'), isTrue);
    expect(find.byIcon(Icons.check_rounded), findsNothing);
  });

  testWidgets('taken off the workflow elsewhere: says so, back to them', (
    tester,
  ) async {
    await open(tester, _marie());

    expect(find.text("Marie doesn't follow a workflow anymore."), findsOne);
    await tester.tap(find.text('Back to Marie'));
    await tester.pumpAndSettle();
    expect(find.byType(ContactDetails), findsOneWidget);
  });

  testWidgets('the card opens it, and back returns to the person', (
    tester,
  ) async {
    people = FakePeopleRepository([_marie(position: 1)]);
    final container = await pumpLoomia(tester, size: _phone, people: people);
    container.read(routerProvider).go(Routes.contacts);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send a first message'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowTimelinePage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowTimelinePage), findsNothing);
    expect(find.byType(ContactDetails), findsOneWidget);
  });

  testWidgets('from the import screen too, without stacking the shell twice', (
    tester,
  ) async {
    people = FakePeopleRepository([_marie(position: 1)]);
    final container = await pumpLoomia(tester, size: _phone, people: people);
    final router = container.read(routerProvider)..go(Routes.contacts);
    await tester.pumpAndSettle();
    unawaited(router.push(Routes.importContacts));
    await tester.pumpAndSettle();
    unawaited(router.push(Routes.importedContactLocation('p1')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send a first message'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(WorkflowTimelinePage), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ContactDetails), findsOneWidget);
  });

  testWidgets('no workflow: the card opens nothing', (tester) async {
    people = FakePeopleRepository([_marie()]);
    final container = await pumpLoomia(tester, size: _phone, people: people);
    container.read(routerProvider).go(Routes.contactLocation('p1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nothing planned'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkflowTimelinePage), findsNothing);
  });

  testWidgets('desktop: it opens in the pane, the list stays', (tester) async {
    await open(tester, _marie(position: 1), size: _desktop);

    expect(find.byType(WorkflowTimelinePage), findsOneWidget);
    expect(find.text('Marie Dupont'), findsWidgets);
    expect(find.text('MARIE DUPONT · STEP 1 OF 5'), findsOneWidget);
  });
}
