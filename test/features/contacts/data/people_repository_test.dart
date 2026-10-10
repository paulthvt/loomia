import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, dynamic> _row([Map<String, dynamic> changes = const {}]) => {
  'id': 'p1',
  'owner_id': 'u1',
  'name': 'Marie Dupont',
  'stage': 'prospect',
  'prospect_status': 'not_now',
  'phone': '06 12 34 56 78',
  'email': null,
  'instagram': '  ',
  'needs': 'Sleep, stress',
  'products': null,
  'profession': 'Nurse',
  'address': null,
  'notes': '',
  'created_at': '2026-03-04T10:00:00+00:00',
  'stage_since': '2026-04-01T08:00:00+00:00',
  'updated_at': '2026-03-05T10:00:00+00:00',
  ...changes,
};

void main() {
  group('personFromRow', () {
    test('reads the photo path, blank as none', () {
      expect(personFromRow(_row({'photo_path': 'u1/abc'})).photoPath, 'u1/abc');
      expect(personFromRow(_row({'photo_path': ' '})).photoPath, isNull);
      expect(personFromRow(_row()).photoPath, isNull);
    });

    test('an edit never writes the photo: only setPhoto does', () {
      final person = personFromRow(_row({'photo_path': 'u1/abc'}));

      expect(personToRow(person).containsKey('photo_path'), isFalse);
    });

    test('reads the LRP day as local midnight, absent as none', () {
      expect(
        personFromRow(_row({'loyalty_since': '2026-10-02'})).loyaltySince,
        DateTime(2026, 10, 2),
      );
      expect(personFromRow(_row()).loyaltySince, isNull);
    });

    test('an edit never writes the LRP: only setLoyalty does', () {
      final person = personFromRow(_row({'loyalty_since': '2026-10-02'}));

      expect(personToRow(person).containsKey('loyalty_since'), isFalse);
    });

    test('maps columns to fields', () {
      final person = personFromRow(_row());

      expect(person.id, 'p1');
      expect(person.name, 'Marie Dupont');
      expect(person.stage, Stage.prospect);
      expect(person.prospectStatus, ProspectStatus.notNow);
      expect(person.phone, '06 12 34 56 78');
      expect(person.needs, 'Sleep, stress');
      expect(person.profession, 'Nurse');
      expect(person.stageSince, DateTime.utc(2026, 4, 1, 8));
    });

    test("reads a team member's own profile", () {
      final person = personFromRow(
        _row({
          'stage': 'team',
          'prospect_status': null,
          'why': 'More time with my kids',
          'own_goal': 'Pay for the holidays',
          'time_available': '3 evenings a week',
          'would_love_to': 'Host a workshop',
          'strengths': 'Warm, organised',
          'stuck_on': '',
        }),
      );

      expect(person.why, 'More time with my kids');
      expect(person.ownGoal, 'Pay for the holidays');
      expect(person.timeAvailable, '3 evenings a week');
      expect(person.wouldLoveTo, 'Host a workshop');
      expect(person.strengths, 'Warm, organised');
      expect(person.stuckOn, isNull);
    });

    test("reads a team member's rank and volume", () {
      final person = personFromRow(
        _row({
          'stage': 'team',
          'prospect_status': null,
          'current_level': 'Executive',
          'target_level': 'Elite',
          'target_level_by': '2027-03-01',
          'monthly_volume_target': 100,
        }),
      );

      expect(person.currentLevel, 'Executive');
      expect(person.targetLevel, 'Elite');
      expect(person.targetLevelBy, DateTime(2027, 3));
      expect(person.monthlyVolumeTarget, 100.0);
    });

    test('reads no rank and no volume as null', () {
      final person = personFromRow(_row());
      expect(person.currentLevel, isNull);
      expect(person.targetLevel, isNull);
      expect(person.targetLevelBy, isNull);
      expect(person.monthlyVolumeTarget, isNull);
    });

    test('reads the reminders, soonest first, the day as local midnight', () {
      final person = personFromRow(
        _row({
          'reminder': [
            {
              'id': 'r2',
              'text': 'Price list',
              'due_on': '2026-10-12',
              'created_at': '2026-10-01T10:00:00+00:00',
            },
            {
              'id': 'r3',
              'text': 'Samples',
              'due_on': '2026-10-10',
              'created_at': '2026-10-02T10:00:00+00:00',
            },
            {
              'id': 'r1',
              'text': 'Call back',
              'due_on': '2026-10-10',
              'created_at': '2026-10-01T10:00:00+00:00',
            },
          ],
        }),
      );

      expect([for (final r in person.reminders) r.id], ['r1', 'r3', 'r2']);
      expect(person.reminders.first.text, 'Call back');
      expect(person.reminders.first.dueOn, DateTime(2026, 10, 10));
    });

    test('reads no reminders as none', () {
      expect(personFromRow(_row()).reminders, isEmpty);
    });

    test('reads blank text as null', () {
      final person = personFromRow(_row());
      expect(person.email, isNull);
      expect(person.instagram, isNull);
      expect(person.notes, isNull);
    });

    test('reads no_reply', () {
      expect(
        personFromRow(_row({'prospect_status': 'no_reply'})).prospectStatus,
        ProspectStatus.noReply,
      );
    });

    test('an unknown stage is a failure, never a default', () {
      expect(
        () => personFromRow(_row({'stage': 'partner'})),
        throwsA(PeopleFailure.unknown),
      );
    });

    test('an unknown status is a failure, never a default', () {
      expect(
        () => personFromRow(_row({'prospect_status': 'maybe'})),
        throwsA(PeopleFailure.unknown),
      );
    });
  });

  test('personToRow writes snake_case values and nulls for blanks, never the '
      'stage', () {
    final row = personToRow(
      Person(
        id: 'p1',
        name: ' Marie Dupont ',
        stage: Stage.prospect,
        stageSince: DateTime.utc(2026, 3, 4),
        prospectStatus: ProspectStatus.noReply,
        phone: '',
        notes: 'Met at the market',
        stuckOn: ' ',
        ownGoal: 'Pay for the holidays',
        currentLevel: ' ',
        targetLevel: 'Elite',
        targetLevelBy: DateTime(2027, 3),
        monthlyVolumeTarget: 99.5,
      ),
    );

    expect(row, {
      'name': 'Marie Dupont',
      'prospect_status': 'no_reply',
      'phone': null,
      'email': null,
      'instagram': null,
      'needs': null,
      'products': null,
      'profession': null,
      'address': null,
      'notes': 'Met at the market',
      'why': null,
      'own_goal': 'Pay for the holidays',
      'time_available': null,
      'would_love_to': null,
      'strengths': null,
      'stuck_on': null,
      'current_level': null,
      'target_level': 'Elite',
      'target_level_by': '2027-03-01',
      'monthly_volume_target': 99.5,
    });
  });

  test('personToRow writes no month when there is none', () {
    final row = personToRow(
      Person(
        id: 'p1',
        name: 'Claire',
        stage: Stage.team,
        stageSince: DateTime.utc(2026, 3, 4),
      ),
    );
    expect(row['target_level_by'], isNull);
    expect(row['monthly_volume_target'], isNull);
  });

  test('draftToRow writes the name, stage and channels', () {
    final row = draftToRow((
      name: ' Lucas ',
      stage: Stage.customer,
      phone: null,
      email: 'lucas@example.com',
      instagram: null,
    ));

    expect(row, {
      'name': 'Lucas',
      'stage': 'customer',
      'phone': null,
      'email': 'lucas@example.com',
      'instagram': null,
    });
  });

  group('peopleFailureFrom', () {
    test('passes a PeopleFailure through', () {
      expect(peopleFailureFrom(PeopleFailure.network), PeopleFailure.network);
    });

    test('a lost connection is network', () {
      expect(
        peopleFailureFrom(const SocketException('offline')),
        PeopleFailure.network,
      );
      expect(
        peopleFailureFrom(TimeoutException('slow')),
        PeopleFailure.network,
      );
      // storage_client wraps a socket error, its type as the status.
      expect(
        peopleFailureFrom(
          const StorageException('offline', statusCode: 'ClientException'),
        ),
        PeopleFailure.network,
      );
    });

    test('a server refusal is unknown', () {
      expect(
        peopleFailureFrom(const StorageException('Payload too large')),
        PeopleFailure.unknown,
      );
      expect(
        peopleFailureFrom(const StorageException('x', statusCode: '413')),
        PeopleFailure.unknown,
      );
      expect(
        peopleFailureFrom(const PostgrestException(message: 'denied')),
        PeopleFailure.unknown,
      );
    });

    test('a malformed row is unknown', () {
      expect(
        peopleFailureFrom(const FormatException('bad timestamp')),
        PeopleFailure.unknown,
      );
    });

    test('a bug is unknown', () {
      expect(peopleFailureFrom(StateError('bad')), PeopleFailure.unknown);
    });
  });

  group('a person\'s place', () {
    Map<String, dynamic> row([Map<String, dynamic> extra = const {}]) => {
      'id': 'p1',
      'name': 'Sarah',
      'stage': 'prospect',
      'stage_since': '2026-09-01T10:00:00Z',
      ...extra,
    };

    test('reads the workflow fields, last_tick as a local day', () {
      final person = personFromRow(
        row({
          'workflow_id': 'w1',
          'at_position': 2.5,
          'last_tick': '2026-09-28',
          'paused_at': '2026-09-29T08:00:00Z',
        }),
      );

      expect(person.place?.workflowId, 'w1');
      expect(person.place?.atPosition, 2.5);
      expect(person.place?.lastTick, DateTime(2026, 9, 28));
      expect(person.pausedAt, DateTime.utc(2026, 9, 29, 8));
    });

    test("reads the server's step and day, due_on as a local day", () {
      final person = personFromRow(
        row({
          'workflow_id': 'w1',
          'at_position': 2,
          'last_tick': '2026-09-28',
          'current_step_id': 's2',
          'due_on': '2026-09-29',
        }),
      );

      expect(person.currentStepId, 's2');
      expect(person.dueOn, DateTime(2026, 9, 29));
    });

    test('reads last_contact_on as a local day', () {
      expect(
        personFromRow(row({'last_contact_on': '2026-09-12'})).lastContactOn,
        DateTime(2026, 9, 12),
      );
      expect(personFromRow(row()).lastContactOn, isNull);
    });

    test('nothing due reads as null', () {
      final person = personFromRow(row());

      expect(person.currentStepId, isNull);
      expect(person.dueOn, isNull);
    });

    test('no workflow is no place, and a half-written one too', () {
      expect(personFromRow(row()).place, isNull);
      expect(
        personFromRow(row({'workflow_id': null, 'at_position': 1})).place,
        isNull,
      );
      expect(personFromRow(row()).pausedAt, isNull);
    });

    test('writes a place as three columns, and null as three nulls', () {
      expect(
        placeToRow((
          workflowId: 'w1',
          atPosition: 3,
          lastTick: DateTime(2026, 1, 5),
        )),
        {'workflow_id': 'w1', 'at_position': 3, 'last_tick': '2026-01-05'},
      );
      expect(placeToRow(null), {
        'workflow_id': null,
        'at_position': null,
        'last_tick': null,
      });
    });

    test('withStatus keeps the place and the pause', () {
      final person = personFromRow(
        row({
          'workflow_id': 'w1',
          'at_position': 1,
          'last_tick': '2026-09-28',
          'paused_at': '2026-09-29T08:00:00Z',
        }),
      ).withStatus(ProspectStatus.thinking);

      expect(person.place?.workflowId, 'w1');
      expect(person.pausedAt, isNotNull);
    });
  });
}
