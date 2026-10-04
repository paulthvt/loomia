import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/data/workflow_repository.dart';

void main() {
  Map<String, dynamic> row({String stage = 'prospect'}) => {
    'id': 'w1',
    'stage': stage,
    'name': 'Samples',
    'is_default': true,
    'workflow_step': [
      {
        'id': 's2',
        'position': 2.5,
        'label': 'Send the samples',
        'days': 1,
        'note': null,
        'loyalty_setup': true,
      },
      {
        'id': 's1',
        'position': 1,
        'label': 'Send a first message',
        'days': 0,
        'note': 'Keep it short',
        'loyalty_setup': false,
      },
    ],
  };

  test('reads a workflow with its steps, sorted, positions as numbers', () {
    final workflow = workflowFromRow(row());

    expect(workflow.stage, Stage.prospect);
    expect(workflow.isDefault, isTrue);
    expect([for (final s in workflow.steps) s.id], ['s1', 's2']);
    expect(workflow.steps.last.position, 2.5);
    expect(workflow.steps.first.note, 'Keep it short');
  });

  test('reads which step is a loyalty setup', () {
    final workflow = workflowFromRow(row());

    expect([for (final s in workflow.steps) s.loyaltySetup], [false, true]);
  });

  test('an unknown stage is an unknown failure', () {
    expect(
      () => workflowFromRow(row(stage: 'vip')),
      throwsA(PeopleFailure.unknown),
    );
  });
}
