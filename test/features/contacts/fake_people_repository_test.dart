import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/person.dart';

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
}
