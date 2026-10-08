import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';

Map<String, dynamic> _row([Map<String, dynamic> changes = const {}]) => {
  'id': 'a1',
  'owner_id': 'u1',
  'person_id': 'p1',
  'kind': 'call',
  'happened_on': '2026-09-20',
  'text': 'Asked about the cream',
  'stage': null,
  'amount': null,
  'created_at': '2026-09-28T12:00:00+00:00',
  ...changes,
};

void main() {
  group('activityFromRow', () {
    test('maps columns to fields, the day as local midnight', () {
      final activity = activityFromRow(_row());

      expect(activity.id, 'a1');
      expect(activity.personId, 'p1');
      expect(activity.kind, ActivityKind.call);
      expect(activity.happenedOn, DateTime(2026, 9, 20));
      expect(activity.text, 'Asked about the cream');
      expect(activity.stage, isNull);
      expect(activity.createdAt, DateTime.utc(2026, 9, 28, 12));
    });

    test('reads a reminder entry, which the user never picks', () {
      final activity = activityFromRow(_row({'kind': 'reminder'}));
      expect(activity.kind, ActivityKind.reminder);
      expect(ActivityKind.reminder.byUser, isFalse);
    });

    test('reads a stage entry', () {
      final activity = activityFromRow(
        _row({'kind': 'stage', 'text': null, 'stage': 'team'}),
      );

      expect(activity.kind, ActivityKind.stage);
      expect(activity.stage, Stage.team);
    });

    test('reads an order amount, whole or not', () {
      expect(
        activityFromRow(_row({'kind': 'order', 'amount': 100})).amount,
        100,
      );
      expect(
        activityFromRow(_row({'kind': 'order', 'text': null, 'amount': 99.5}))
            .amount,
        99.5,
      );
    });

    test('an unknown kind is a failure, never a default', () {
      expect(
        () => activityFromRow(_row({'kind': 'visit'})),
        throwsA(PeopleFailure.unknown),
      );
    });

    test('an unknown stage is a failure, never a default', () {
      expect(
        () => activityFromRow(
          _row({'kind': 'stage', 'text': null, 'stage': 'partner'}),
        ),
        throwsA(PeopleFailure.unknown),
      );
    });
  });

  test('activityDraftToRow writes the day as yyyy-MM-dd and trims', () {
    expect(
      activityDraftToRow('p1', (
        kind: ActivityKind.order,
        happenedOn: DateTime(2026, 3, 4),
        text: '  Two creams ',
        amount: null,
      )),
      {
        'person_id': 'p1',
        'kind': 'order',
        'happened_on': '2026-03-04',
        'text': 'Two creams',
        'amount': null,
      },
    );
  });

  test('activityDraftToRow: an amount alone writes no text', () {
    expect(
      activityDraftToRow('p1', (
        kind: ActivityKind.order,
        happenedOn: DateTime(2026, 3, 4),
        text: '   ',
        amount: 100,
      )),
      {
        'person_id': 'p1',
        'kind': 'order',
        'happened_on': '2026-03-04',
        'text': null,
        'amount': 100,
      },
    );
  });

  test('an own order has no person', () {
    final order = activityFromRow(
      _row({'person_id': null, 'kind': 'order', 'text': null, 'amount': 80}),
    );

    expect(order.personId, isNull);
    expect(order.amount, 80);
  });

  test("a month's order carries its person's name, or none", () {
    final theirs = monthOrderFromRow(
      _row({
        'kind': 'order',
        'amount': 100,
        'person': {'name': 'Marie Dupont'},
      }),
    );
    final own = monthOrderFromRow(
      _row({
        'person_id': null,
        'kind': 'order',
        'text': null,
        'amount': 80,
        'person': null,
      }),
    );

    expect(theirs.personName, 'Marie Dupont');
    expect(theirs.order.amount, 100);
    expect(own.personName, isNull);
  });

  test('activityDraftToRow: an own order writes no person', () {
    final row = activityDraftToRow(null, (
      kind: ActivityKind.order,
      happenedOn: DateTime(2026, 9, 19),
      text: '',
      amount: 100,
    ));

    expect(row['person_id'], isNull);
    expect(row['amount'], 100);
  });

  test('activityEditToRow writes the day, the text and the amount only', () {
    expect(
      activityEditToRow((
        kind: ActivityKind.step,
        happenedOn: DateTime(2026, 10, 1),
        text: ' Sent the samples ',
        amount: null,
      )),
      {'happened_on': '2026-10-01', 'text': 'Sent the samples', 'amount': null},
    );
    expect(
      activityEditToRow((
        kind: ActivityKind.order,
        happenedOn: DateTime(2026, 10, 2),
        text: ' ',
        amount: 55,
      )),
      {'happened_on': '2026-10-02', 'text': null, 'amount': 55},
    );
  });
}
