import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/workflows/data/event_workflow_repository.dart';
import 'package:loomia/features/workflows/data/workflow_repository.dart';
import 'package:loomia/features/workflows/presentation/event_workflows_controller.dart';

import '../../contacts/fake_activity_repository.dart';
import '../../contacts/fake_people_repository.dart';
import '../fake_event_workflow_repository.dart';
import '../fake_workflow_repository.dart';

class _World {
  _World(this.container, this.workflows, this.eventWorkflows);

  final ProviderContainer container;
  final FakeWorkflowRepository workflows;
  final FakeEventWorkflowRepository eventWorkflows;
}

_World _world() {
  final workflows = FakeWorkflowRepository();
  final eventWorkflows = FakeEventWorkflowRepository(
    FakeEventWorkflowRepository.samples(),
  );
  final container = ProviderContainer(
    overrides: [
      accountProvider.overrideWith(
        (ref) => const Account(firstName: 'Pauline', email: 'p@example.com'),
      ),
      peopleRepositoryProvider.overrideWith((ref) => FakePeopleRepository()),
      activityRepositoryProvider.overrideWith(
        (ref) => FakeActivityRepository(),
      ),
      workflowRepositoryProvider.overrideWith((ref) => workflows),
      eventWorkflowRepositoryProvider.overrideWith((ref) => eventWorkflows),
    ],
  );
  return _World(container, workflows, eventWorkflows);
}

void main() {
  test('lists the event workflows once the seed has run', () async {
    final world = _world();
    final listed = await world.container.read(
      eventWorkflowsProvider('p@example.com').future,
    );

    expect(listed.single.name, 'Workshop');
    expect(world.workflows.calls.first, startsWith('seed('));
  });

  test('signed out: none, nothing asked', () async {
    final world = _world();
    expect(
      await world.container.read(eventWorkflowsProvider(null).future),
      isEmpty,
    );
    expect(world.eventWorkflows.calls, isEmpty);
  });

  test('a write reloads the list', () async {
    final world = _world();
    const owner = 'p@example.com';
    await world.container.read(eventWorkflowsProvider(owner).future);

    await world.container
        .read(eventWorkflowsProvider(owner).notifier)
        .edit((repository) => repository.create('Training'));
    final listed = await world.container.read(
      eventWorkflowsProvider(owner).future,
    );

    expect(
      listed.map((workflow) => workflow.name),
      containsAll(['Workshop', 'Training']),
    );
  });
}
