import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/step_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../../contacts/fake_people_repository.dart';
import '../../contacts/presentation/form_harness.dart';
import '../fake_workflow_repository.dart';

const _failed = "Couldn't save. Check your connection and try again.";

void main() {
  late FakeWorkflowRepository workflows;

  setUp(() {
    workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
  });

  /// The sheet on [workflow] (Samples by default): [index] null adds a step.
  Future<void> open(
    WidgetTester tester, {
    int? index,
    String workflow = 'samples',
    Account account = const Account(
      firstName: 'Pauline',
      email: 'p@example.com',
    ),
  }) => pumpFormHarness(
    tester,
    people: FakePeopleRepository(),
    workflows: workflows,
    account: account,
    open: (context) => showStepSheet(
      context,
      workflows.store.firstWhere((w) => w.id == workflow),
      index: index,
    ),
    result: (_) {},
  );

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledField, label),
    matching: find.byType(TextFormField),
  );

  Iterable<String> writes(String name) =>
      workflows.calls.where((call) => call.startsWith(name));

  testWidgets('a new step goes at the end, counted from the one before', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('New step'), findsOneWidget);
    expect(find.text('Remove this step'), findsNothing);
    // Samples has 5 steps; a new one is due a day after the fifth.
    expect(find.text('Comes due 1 day after you tick step 5.'), findsOneWidget);

    await tester.enterText(field('What to do'), 'Say thanks');
    await tester.enterText(field('Days after the previous step'), '2');
    await tester.pump();
    expect(
      find.text('Comes due 2 days after you tick step 5.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(writes('addStep'), ['addStep(samples, Say thanks, 2, 6)']);
    expect(find.text('New step'), findsNothing);
  });

  testWidgets('step 1 counts from the start', (tester) async {
    await open(tester, index: 0);

    expect(find.text('Step 1'), findsOneWidget);
    expect(find.text('Send a first message'), findsOneWidget);
    expect(field('Days after starting'), findsOneWidget);
    expect(find.text('Comes due the same day you start.'), findsOneWidget);
  });

  testWidgets('an edited step is saved trimmed', (tester) async {
    await open(tester, index: 1);
    expect(find.text('Step 2'), findsOneWidget);

    await tester.enterText(field('What to do'), '  Send the kit  ');
    await tester.enterText(field('Days after the previous step'), '3');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(writes('updateStep'), ['updateStep(samples-2, Send the kit, 3)']);
    expect(find.text('Step 2'), findsNothing);
  });

  group('loyalty setup', () {
    const doterra = Account(
      firstName: 'Pauline',
      email: 'p@example.com',
      businessModel: BusinessModel.doterra,
    );

    Future<void> toggle(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Counts as a loyalty setup'));
      await tester.tap(find.text('Counts as a loyalty setup'));
      await tester.pump();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    Workflow customers() =>
        workflows.store.firstWhere((w) => w.id == 'new-customer');
    WorkflowStep step(int index) => customers().steps[index];

    testWidgets('a prospect is no customer yet: no switch', (tester) async {
      await open(tester, index: 1, account: doterra);

      expect(find.text('Counts as a loyalty setup'), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(workflows.store.first.steps[1].loyaltySetup, isFalse);
    });

    testWidgets('a new step can count as one', (tester) async {
      await open(tester, workflow: 'new-customer', account: doterra);

      expect(
        find.text(
          'When you tick this step, it counts as one LRP for the month.',
        ),
        findsOneWidget,
      );
      await tester.enterText(field('What to do'), 'Set up their LRP');
      await toggle(tester);
      await save(tester);

      expect(customers().steps.last.loyaltySetup, isTrue);
    });

    testWidgets('a step is not one unless switched on', (tester) async {
      await open(tester, workflow: 'new-customer');

      await tester.enterText(field('What to do'), 'Say thanks');
      await save(tester);

      expect(customers().steps.last.loyaltySetup, isFalse);
    });

    testWidgets('switching it off is saved', (tester) async {
      await open(tester, workflow: 'new-customer', index: 1);
      await toggle(tester);
      await save(tester);
      expect(step(1).loyaltySetup, isTrue);

      await open(tester, workflow: 'new-customer', index: 1);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await toggle(tester);
      await save(tester);
      expect(step(1).loyaltySetup, isFalse);
    });

    testWidgets('editing the label keeps it on', (tester) async {
      await open(tester, workflow: 'new-customer', index: 1);
      await toggle(tester);
      await save(tester);

      await open(tester, workflow: 'new-customer', index: 1);
      await tester.enterText(field('What to do'), 'Send the kit');
      await save(tester);

      expect(step(1).label, 'Send the kit');
      expect(step(1).loyaltySetup, isTrue);
    });

    testWidgets('Other: neutral words', (tester) async {
      await open(tester, workflow: 'new-customer');

      expect(
        find.text(
          'When you tick this step, it counts as one loyalty order for the month.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('LRP'), findsNothing);
    });
  });

  testWidgets('what to do is required', (tester) async {
    await open(tester);

    await tester.enterText(field('What to do'), '   ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter what to do.'), findsOneWidget);
    expect(writes('addStep'), isEmpty);
  });

  testWidgets('days must be 0 to 365', (tester) async {
    await open(tester, index: 1);
    final days = field('Days after the previous step');

    await tester.enterText(days, '400');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number from 0 to 365.'), findsOneWidget);

    await tester.enterText(days, '');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number from 0 to 365.'), findsOneWidget);

    // Only digits can be typed.
    await tester.enterText(days, '-3a');
    expect(tester.widget<TextFormField>(days).controller!.text, '3');
    expect(writes('updateStep'), isEmpty);
  });

  testWidgets('Remove this step removes it without asking', (tester) async {
    await open(tester, index: 1);

    await tester.tap(find.text('Remove this step'));
    await tester.pumpAndSettle();

    expect(writes('removeStep'), ['removeStep(samples-2)']);
    expect(find.text('Step 2'), findsNothing);
  });

  testWidgets('a second tap on Save while saving writes nothing more', (
    tester,
  ) async {
    await open(tester, index: 1);
    workflows.gate = Completer<void>();

    // No frame between the taps: Save is not rebuilt as disabled yet.
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(writes('updateStep'), hasLength(1));

    workflows.gate!.complete();
    await tester.pumpAndSettle();
    expect(writes('updateStep'), hasLength(1));
  });

  testWidgets('a failed save keeps the sheet and what was typed', (
    tester,
  ) async {
    await open(tester, index: 1);
    workflows.failWith = PeopleFailure.network;

    await tester.enterText(field('What to do'), 'Send the kit');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FormError, _failed), findsOneWidget);
    expect(find.text('Step 2'), findsOneWidget);
    expect(find.text('Send the kit'), findsOneWidget);
  });
}
