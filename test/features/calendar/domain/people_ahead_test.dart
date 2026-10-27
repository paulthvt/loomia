import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/calendar/domain/people_ahead.dart';
import 'package:loomia/features/contacts/domain/person.dart';

Person _person(String id, String name, List<Reminder> reminders) => Person(
  id: id,
  name: name,
  stage: Stage.prospect,
  stageSince: DateTime.utc(2026),
  reminders: reminders,
);

Reminder _reminder(String id, DateTime due) =>
    (id: id, text: 'Text $id', dueOn: due, createdAt: DateTime.utc(2026));

void main() {
  final today = DateTime(2026, 10, 6);
  final thursday = DateTime(2026, 10, 8);

  test('people per day: one per person, from today on', () {
    final ahead = PeopleAhead(
      people: [
        _person('a', 'Anna', [
          _reminder('r1', thursday),
          _reminder('r2', thursday),
        ]),
        _person('b', 'Bruno', [
          _reminder('r3', thursday),
          _reminder('r4', DateTime(2026, 10, 5)),
        ]),
      ],
      workflows: const [],
      today: today,
    );

    expect(ahead.count(thursday), 2);
    expect(ahead.on(thursday).first.length, 2);
    expect(ahead.count(DateTime(2026, 10, 5)), 0);
    expect(ahead.count(DateTime(2026, 10, 9)), 0);
  });

  test('none has nobody', () {
    expect(const PeopleAhead.none().count(thursday), 0);
  });
}
