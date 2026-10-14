import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

WorkflowStep _step(num position, String label, int days, {String? note}) =>
    WorkflowStep(
      id: 's$position',
      position: position,
      label: label,
      days: days,
      note: note,
    );

Workflow _samples([List<WorkflowStep>? steps]) => Workflow(
  id: 'w1',
  stage: Stage.prospect,
  name: 'Samples',
  isDefault: true,
  steps:
      steps ??
      [
        _step(1, 'Send a first message', 0),
        _step(2, 'Send the samples', 1),
        _step(3, 'Samples arrived', 4),
      ],
);

/// A person as the server returns them: on [stepId], due on [due].
Person _at(String? stepId, {DateTime? due, DateTime? pausedAt}) => Person(
  id: 'p1',
  name: 'Sarah',
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026, 9, 1),
  place: (workflowId: 'w1', atPosition: 2, lastTick: DateTime(2026, 9, 28)),
  currentStepId: stepId,
  dueOn: due,
  pausedAt: pausedAt,
);

void main() {
  test("the server's step, its place in the list and its day", () {
    final progress =
        progressOf(_at('s2', due: DateTime(2026, 9, 29)), _samples()) as OnStep;

    expect(progress.step.label, 'Send the samples');
    expect(progress.index, 2);
    expect(progress.total, 3);
    expect(progress.due, DateTime(2026, 9, 29));
  });

  test('steps come sorted by position whatever the order given', () {
    final workflow = _samples([
      _step(3, 'Samples arrived', 4),
      _step(1, 'Send a first message', 0),
      _step(2, 'Send the samples', 1),
    ]);
    final progress =
        progressOf(_at('s2', due: DateTime(2026, 9, 29)), workflow) as OnStep;

    expect(progress.index, 2);
  });

  test('a rename shows at once', () {
    final workflow = _samples([
      _step(1, 'Send a first message', 0),
      _step(2, 'Post the samples', 1),
      _step(3, 'Samples arrived', 4),
    ]);
    final progress =
        progressOf(_at('s2', due: DateTime(2026, 9, 29)), workflow) as OnStep;

    expect(progress.step.label, 'Post the samples');
  });

  test('an event step: on it until its event is planned, then planned', () {
    final workflow = _samples([
      _step(1, 'Send a first message', 0),
      const WorkflowStep(
        id: 's2',
        position: 2,
        label: 'Book a wellness check',
        days: 0,
        eventWorkflowId: 'check',
      ),
    ]);

    final on = progressOf(_at('s2', due: DateTime(2026, 9, 28)), workflow);
    expect(on, isA<OnStep>().having((step) => step.isEvent, 'isEvent', true));

    final planned = Person(
      id: 'p1',
      name: 'Sarah',
      stage: Stage.prospect,
      stageSince: DateTime.utc(2026, 9),
      place: (workflowId: 'w1', atPosition: 2, lastTick: DateTime(2026, 9, 28)),
      currentStepId: 's2',
      plannedEventId: 'e1',
    );
    expect(
      progressOf(planned, workflow),
      isA<Planned>()
          .having((p) => p.eventId, 'eventId', 'e1')
          .having((p) => p.index, 'index', 2)
          .having((p) => p.total, 'total', 2),
    );
  });

  test('no current step is done', () {
    expect(progressOf(_at(null), _samples()), isA<Done>());
  });

  test('a step the list does not have yet is no progress, not a crash', () {
    // The workflows were loaded before an edit the book already reflects.
    expect(
      progressOf(_at('s9', due: DateTime(2026, 9, 29)), _samples()),
      isNull,
    );
  });

  test('paused wins over everything, even no workflow', () {
    final since = DateTime.utc(2026, 7, 12);

    expect(
      (progressOf(_at('s2', pausedAt: since), _samples())! as Paused).since,
      since,
    );
    expect(progressOf(_at('s2', pausedAt: since), null), isA<Paused>());
  });

  test('no workflow, or one that is not in the list, is no progress', () {
    final other = Workflow(
      id: 'w2',
      stage: Stage.prospect,
      name: 'Other',
      isDefault: false,
      steps: const [],
    );

    expect(progressOf(_at('s2', due: DateTime(2026, 9, 29)), null), isNull);
    expect(progressOf(_at('s2', due: DateTime(2026, 9, 29)), other), isNull);
  });

  test('start puts the first step on the chosen day', () {
    final workflow = _samples([_step(1, 'Welcome call', 3)]);

    final place = start(workflow, firstDue: DateTime(2026, 10, 2));

    expect(place.workflowId, 'w1');
    expect(place.atPosition, 1);
    expect(place.lastTick, DateTime(2026, 9, 29));
    expect(
      firstDueDefault(workflow, DateTime(2026, 9, 29)),
      DateTime(2026, 10, 2),
    );
  });

  test('days are calendar days, across a clock change', () {
    // Paris moves its clocks back on 25 October 2026.
    expect(daysBetween(DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
    expect(addDays(DateTime(2026, 10, 24), 2), DateTime(2026, 10, 26));
  });

  test('forStage: the default first, then by name', () {
    final workflows = [
      Workflow(
        id: 'b',
        stage: Stage.customer,
        name: 'B',
        isDefault: false,
        steps: const [],
      ),
      Workflow(
        id: 'z',
        stage: Stage.customer,
        name: 'Z',
        isDefault: true,
        steps: const [],
      ),
      _samples(),
    ];

    expect(
      [for (final w in forStage(workflows, Stage.customer)) w.id],
      ['z', 'b'],
    );
    expect(defaultFor(workflows, Stage.customer)?.id, 'z');
    expect(defaultFor(workflows, Stage.team), isNull);
  });
}
