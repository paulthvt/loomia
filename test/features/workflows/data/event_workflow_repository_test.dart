import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/data/event_workflow_repository.dart';

void main() {
  test('reads a row with its steps and the stages it starts', () {
    final workflow = eventWorkflowFromRow({
      'id': 'w1',
      'name': 'Workshop',
      'prospect_workflow_id': 'samples',
      'customer_workflow_id': null,
      'team_workflow_id': null,
      'event_workflow_step': [
        {'id': 's2', 'label': 'Thank', 'days': 1, 'note': null},
        {'id': 's1', 'label': 'Remind', 'days': -1, 'note': 'By text'},
      ],
    });

    expect(workflow.name, 'Workshop');
    expect(workflow.followUps, {Stage.prospect: 'samples'});
    expect(workflow.steps.map((step) => step.id), ['s1', 's2']);
    expect(workflow.steps.first.note, 'By text');
  });
}
