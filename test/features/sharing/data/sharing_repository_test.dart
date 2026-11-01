import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/invite_failure.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A repository on a local server that answers every request with [answer].
Future<SharingRepository> _answering(Object? answer) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(server.close);
  server.listen((request) async {
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(answer));
    await request.response.close();
  });
  final client = SupabaseClient(
    'http://${server.address.host}:${server.port}',
    'publishable',
  );
  addTearDown(client.dispose);
  return SharingRepository(client);
}

void main() {
  group('no server', () {
    // Nothing listens on the port: a network error, not a Postgrest one.
    Future<SharingRepository> offline() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();
      final client = SupabaseClient('http://127.0.0.1:$port', 'publishable');
      addTearDown(client.dispose);
      return SharingRepository(client);
    }

    test('preview fails as unknown', () async {
      final repository = await offline();

      await expectLater(
        repository.previewInvite('ABCDEFGH'),
        throwsA(InviteFailure.unknown),
      );
    });

    test('accept fails as unknown', () async {
      final repository = await offline();

      await expectLater(
        repository.acceptInvite('ABCDEFGH', {}),
        throwsA(InviteFailure.unknown),
      );
    });
  });

  group('an account without a first name', () {
    test('previews as an empty name', () async {
      final repository = await _answering(null);

      expect(await repository.previewInvite('ABCDEFGH'), '');
    });

    test('shares as an empty name', () async {
      final repository = await _answering([
        {
          'mentor_first_name': null,
          'items': ['progress'],
        },
      ]);

      expect((await repository.myShare())!.mentorFirstName, '');
    });

    test('is shared with as an empty name', () {
      final shared = sharedGoalsFromRow({
        'member_first_name': null,
        'items': <String>[],
      }, DateTime(2026, 10));

      expect(shared.memberFirstName, '');
    });
  });

  test('openInvite asks only for invites not yet expired', () async {
    // A local server stands in for PostgREST: what matters is the query.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final queries = <Map<String, String>>[];
    server.listen((request) {
      queries.add(request.uri.queryParameters);
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(<Object>[]))
        ..close();
    });
    final client = SupabaseClient(
      'http://${server.address.host}:${server.port}',
      'publishable',
    );
    addTearDown(client.dispose);

    final invite = await SharingRepository(client).openInvite('p1');

    expect(invite, isNull);
    expect(queries.single['person_id'], 'eq.p1');
    final expires = queries.single['expires_at']!;
    expect(expires, startsWith('gt.'));
    final after = DateTime.parse(expires.substring(3));
    expect(after.difference(DateTime.now()).inSeconds.abs(), lessThan(60));
  });

  test('sharedGoals asks for the month of the day given', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    final bodies = <Map<String, dynamic>>[];
    server.listen((request) async {
      bodies.add(
        jsonDecode(await utf8.decodeStream(request)) as Map<String, dynamic>,
      );
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(<Object>[]));
      await request.response.close();
    });
    final client = SupabaseClient(
      'http://${server.address.host}:${server.port}',
      'publishable',
    );
    addTearDown(client.dispose);

    await SharingRepository(client).sharedGoals('p1', DateTime(2026, 10, 31));

    // shared_goals answers for a whole month only.
    expect(bodies.single['p_month'], '2026-10-01');
    expect(
      DateTime.parse(bodies.single['p_starts'] as String),
      DateTime(2026, 10).toUtc(),
    );
  });

  group('sharedGoalsFromRow', () {
    test('maps row with progress item and null plan', () {
      final month = DateTime(2026, 10);
      final row = {
        'member_first_name': 'Alice',
        'items': ['progress'],
        'plan': null,
        'level_now': 'Gold',
        'progress': {
          'own_volume': 1500.0,
          'prospects': 5,
          'customers': 3,
          'team_members': 2,
          'loyalty': 1,
        },
        'why': null,
        'own_goal': null,
      };

      final result = sharedGoalsFromRow(row, month);

      expect(result.memberFirstName, 'Alice');
      expect(result.items, {ShareItem.progress});
      expect(result.plan, null);
      expect(result.levelNow, 'Gold');
      expect(result.progress, isNotNull);
      expect(result.progress!.ownVolume, 1500.0);
      expect(result.progress!.prospects, 5);
      expect(result.why, null);
      expect(result.ownGoal, null);
    });

    test('progress without activity targets carries the volume only', () {
      final row = {
        'member_first_name': 'Alice',
        'items': ['progress'],
        'plan': null,
        'level_now': null,
        'progress': {'own_volume': 120},
        'why': null,
        'own_goal': null,
      };

      final progress = sharedGoalsFromRow(row, DateTime(2026, 10)).progress!;

      expect(progress.ownVolume, 120.0);
      expect(progress.prospects, 0);
      expect(progress.loyalty, 0);
    });

    test('ignores unknown item strings', () {
      final month = DateTime(2026, 10);
      final row = {
        'member_first_name': 'Bob',
        'items': ['progress', 'unknown_item', 'activity_targets'],
        'plan': null,
        'level_now': null,
        'progress': null,
        'why': null,
        'own_goal': null,
      };

      final result = sharedGoalsFromRow(row, month);

      expect(result.items, {ShareItem.progress, ShareItem.activityTargets});
    });

    test('maps row with plan and all items', () {
      final month = DateTime(2026, 10);
      final row = {
        'member_first_name': 'Charlie',
        'items': ['activity_targets', 'progress', 'about_me'],
        'plan': {
          'own_volume_target': 2000.0,
          'team_volume_target': 5000.0,
          'level_target': 'Platinum',
          'prospects_target': 10,
          'customers_target': 5,
          'team_members_target': 3,
          'loyalty_target': 2,
        },
        'level_now': 'Gold',
        'progress': {
          'own_volume': 1800.0,
          'prospects': 8,
          'customers': 4,
          'team_members': 2,
          'loyalty': 1,
        },
        'why': 'My personal reason',
        'own_goal': 'My goal',
      };

      final result = sharedGoalsFromRow(row, month);

      expect(result.memberFirstName, 'Charlie');
      expect(result.items, {
        ShareItem.activityTargets,
        ShareItem.progress,
        ShareItem.aboutMe,
      });
      expect(result.plan, isNotNull);
      expect(result.plan!.month, month);
      expect(result.plan!.ownVolumeTarget, 2000.0);
      expect(result.plan!.prospectsTarget, 10);
      expect(result.levelNow, 'Gold');
      expect(result.progress, isNotNull);
      expect(result.why, 'My personal reason');
      expect(result.ownGoal, 'My goal');
    });
  });
}
