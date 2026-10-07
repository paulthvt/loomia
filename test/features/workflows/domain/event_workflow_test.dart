import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';

void main() {
  test('steps are in date order, then by name', () {
    final workflow = EventWorkflow(
      id: 'w',
      name: 'Workshop',
      steps: const [
        EventWorkflowStep(id: 'b', label: 'Thank', days: 1),
        EventWorkflowStep(id: 'c', label: 'Book the room', days: -7),
        EventWorkflowStep(id: 'a', label: 'Ask', days: 1),
      ],
    );

    expect(workflow.steps.map((step) => step.id), ['c', 'a', 'b']);
  });
}
