import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

import 'fake_activity_repository.dart';
import 'fake_people_repository.dart';

void main() {
  final marie = Person(
    id: 'p1',
    name: 'Marie Dupont',
    stage: Stage.prospect,
    prospectStatus: ProspectStatus.interested,
    phone: '06 12 34 56 78',
    stageSince: DateTime.utc(2026, 3, 4),
  );

  test('setStage does what the trigger does', () async {
    final people = FakePeopleRepository([marie]);

    final [moved] = await people.setStage(['p1'], Stage.customer);

    expect(people.calls, ['setStage(p1, customer)']);
    expect(moved.stage, Stage.customer);
    expect(moved.prospectStatus, isNull);
    expect(moved.stageSince, DateTime.utc(2026, 9, 28));
    expect(moved.phone, '06 12 34 56 78');
    expect(people.store['p1']!.id, moved.id);
  });

  test('setStage writes the stage entry, as the trigger does', () async {
    final activities = FakeActivityRepository();
    final people = FakePeopleRepository([marie])..activities = activities;

    await people.setStage(['p1'], Stage.team);

    expect(activities.store.single.kind, ActivityKind.stage);
    expect(activities.store.single.stage, Stage.team);
    expect(activities.store.single.personId, 'p1');
  });

  test('update keeps the stored stage, as the real update does', () async {
    final people = FakePeopleRepository([marie]);
    await people.setStage(['p1'], Stage.customer);

    // A copy read before the move still says prospect.
    final saved = await people.update(
      Person(
        id: 'p1',
        name: 'Marie D.',
        stage: Stage.prospect,
        stageSince: marie.stageSince,
      ),
    );

    expect(saved.name, 'Marie D.');
    expect(saved.stage, Stage.customer);
    expect(saved.stageSince, DateTime.utc(2026, 9, 28));
    expect(people.store['p1']!.id, saved.id);
  });

  group('LRP, as set_loyalty and complete_step', () {
    final claire = Person(
      id: 'p2',
      name: 'Claire Moreau',
      stage: Stage.customer,
      stageSince: DateTime.utc(2026, 9, 1),
      place: (workflowId: 'w1', atPosition: 1, lastTick: DateTime(2026, 10)),
    );
    final twoSetups = Workflow(
      id: 'w1',
      stage: Stage.customer,
      name: 'Two setups',
      isDefault: true,
      steps: const [
        WorkflowStep(
          id: 's1',
          position: 1,
          label: 'Set up their LRP',
          days: 0,
          loyaltySetup: true,
        ),
        WorkflowStep(
          id: 's2',
          position: 2,
          label: 'Check the LRP',
          days: 7,
          loyaltySetup: true,
        ),
      ],
    );

    List<ActivityKind> loyaltyKinds(FakeActivityRepository activities) => [
      for (final entry in activities.store)
        if (entry.kind.isLoyalty) entry.kind,
    ];

    test('the first loyalty step starts it, a second leaves it', () async {
      final activities = FakeActivityRepository();
      final people = FakePeopleRepository([claire])
        ..activities = activities
        ..workflows = [twoSetups];

      final first = await people.completeStep(
        'p2',
        's1',
        DateTime(2026, 10, 2),
      );
      final second = await people.completeStep(
        'p2',
        's2',
        DateTime(2026, 10, 9),
      );

      expect(first.loyaltySince, DateTime(2026, 10, 2));
      expect(second.loyaltySince, DateTime(2026, 10, 2));
      expect(loyaltyKinds(activities), [ActivityKind.loyaltyStart]);
    });

    test('setLoyalty starts, moves and stops it with its entries', () async {
      final activities = FakeActivityRepository();
      final people = FakePeopleRepository([claire])..activities = activities;
      final today = DateTime(2026, 10, 10);

      final started = await people.setLoyalty(
        'p2',
        DateTime(2026, 10, 2),
        today,
      );
      final moved = await people.setLoyalty('p2', DateTime(2026, 9, 20), today);
      expect(activities.store.single.happenedOn, DateTime(2026, 9, 20));
      final stopped = await people.setLoyalty('p2', null, today);

      expect(people.calls, everyElement('setLoyalty(p2)'));
      expect(started.loyaltySince, DateTime(2026, 10, 2));
      expect(moved.loyaltySince, DateTime(2026, 9, 20));
      expect(stopped.loyaltySince, isNull);
      expect(loyaltyKinds(activities), [
        ActivityKind.loyaltyStart,
        ActivityKind.loyaltyStop,
      ]);
      expect(activities.store.last.happenedOn, today);
    });
  });

  test('completeReminder does what complete_reminder does', () async {
    final activities = FakeActivityRepository();
    final people = FakePeopleRepository([marie])..activities = activities;
    final added = await people.addReminder(
      'p1',
      ' Call back ',
      DateTime(2026, 10, 15),
    );

    await people.completeReminder(added.id, DateTime(2026, 10, 9));
    final [done] = await people.list();

    expect(done.reminders, isEmpty);
    expect(done.lastContactOn, DateTime(2026, 10, 9));
    expect(activities.store.single.kind, ActivityKind.reminder);
    expect(activities.store.single.text, 'Call back');
    await expectLater(
      people.completeReminder(added.id, DateTime(2026, 10, 9)),
      throwsA(isA<Object>()),
    );
  });
}
