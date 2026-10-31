import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/supabase/supabase_provider.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/sharing/domain/invite_code.dart';
import 'package:loomia/features/sharing/domain/invite_failure.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';
import 'package:loomia/features/sharing/domain/shared_goals.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SharingRepository {
  SharingRepository(this._client);

  final SupabaseClient _client;

  Future<Invite?> openInvite(String personId) => guardPeople(() async {
    final rows = await _client
        .from('share_invite')
        .select()
        .eq('person_id', personId)
        // An expired code no longer works: none open, so Invite shows again.
        .gt('expires_at', DateTime.now().toUtc().toIso8601String());
    if (rows.isEmpty) return null;
    return _inviteFromRow(rows.first);
  });

  Future<Invite> createInvite(String personId) => guardPeople(() async {
    final row = await _client
        .rpc<Object?>('create_share_invite', params: {'p_person_id': personId})
        .single();
    return _inviteFromRow(row);
  });

  Future<void> cancelInvite(String personId) => guardPeople(() async {
    await _client.from('share_invite').delete().eq('person_id', personId);
  });

  Future<String> previewInvite(String code) async {
    try {
      return await _client.rpc<String>(
        'share_invite_preview',
        params: {'p_code': code},
      );
    } on PostgrestException catch (e) {
      throw _inviteFailureFrom(e);
    }
  }

  Future<void> acceptInvite(String code, Set<ShareItem> items) async {
    try {
      await _client.rpc<void>(
        'accept_share_invite',
        params: {
          'p_code': code,
          'p_items': items.map((item) => item.stored).toList(),
        },
      );
    } on PostgrestException catch (e) {
      throw _inviteFailureFrom(e);
    }
  }

  Future<MyShare?> myShare() => guardPeople(() async {
    final rows = await _client.rpc<Object?>('my_share');
    if (rows is! List || rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    return MyShare(
      mentorFirstName: row['mentor_first_name'] as String,
      items: _parseItems(row['items'] as List),
    );
  });

  Future<void> setItems(Set<ShareItem> items) => guardPeople(() async {
    await _client
        .from('share_link')
        .update({'items': items.map((item) => item.stored).toList()})
        .eq('member_id', _client.auth.currentUser!.id);
  });

  Future<void> stopSharing() => guardPeople(() async {
    await _client
        .from('share_link')
        .delete()
        .eq('member_id', _client.auth.currentUser!.id);
  });

  Future<SharedGoals?> sharedGoals(String personId, DateTime month) =>
      guardPeople(() async {
        final rows = await _client.rpc<Object?>(
          'shared_goals',
          params: _monthParams(personId, month),
        );
        if (rows is! List || rows.isEmpty) return null;
        return sharedGoalsFromRow(rows.first as Map<String, dynamic>, month);
      });

  Future<void> stopSharingWith(String personId) => guardPeople(() async {
    await _client.from('share_link').delete().eq('person_id', personId);
  });

  Future<AboutMe> aboutMe() => guardPeople(() async {
    final rows = await _client.from('about_me').select();
    if (rows.isEmpty) return const AboutMe();
    final row = rows.first;
    return AboutMe(
      why: row['why'] as String?,
      ownGoal: row['own_goal'] as String?,
    );
  });

  Future<void> saveAboutMe(AboutMe aboutMe) => guardPeople(() async {
    await _client.from('about_me').upsert({
      'owner_id': _client.auth.currentUser!.id,
      'why': aboutMe.why?.isEmpty == true ? null : aboutMe.why,
      'own_goal': aboutMe.ownGoal?.isEmpty == true ? null : aboutMe.ownGoal,
    });
  });

  Map<String, Object?> _monthParams(String personId, DateTime month) {
    final (:starts, :ends) = monthBounds(month);
    return {
      'p_person_id': personId,
      'p_month': dayColumn(month),
      'p_starts': starts.toIso8601String(),
      'p_ends': ends.toIso8601String(),
    };
  }

  Invite _inviteFromRow(Map<String, dynamic> row) => Invite(
    code: row['code'] as String,
    expiresAt: DateTime.parse(row['expires_at'] as String),
  );

  InviteFailure _inviteFailureFrom(PostgrestException e) {
    if (e.code != 'P0001') return InviteFailure.unknown;
    return switch (e.message) {
      'invite_invalid' => InviteFailure.invalid,
      'invite_own' => InviteFailure.own,
      'already_sharing' => InviteFailure.alreadySharing,
      'not_team' => InviteFailure.notTeam,
      _ => InviteFailure.unknown,
    };
  }
}

final sharingRepositoryProvider = Provider<SharingRepository>(
  (ref) => SharingRepository(ref.watch(supabaseClientProvider)),
);

Set<ShareItem> _parseItems(List<dynamic> items) => items
    .map((item) => ShareItem.parse(item as String))
    .whereType<ShareItem>()
    .toSet();

SharedGoals sharedGoalsFromRow(Map<String, dynamic> row, DateTime month) {
  final planData = row['plan'];
  final progressData = row['progress'];
  return SharedGoals(
    memberFirstName: row['member_first_name'] as String,
    items: _parseItems(row['items'] as List),
    plan: planData == null
        ? null
        : monthPlanFromRow({
            ...planData as Map<String, dynamic>,
            'month': dayColumn(month),
          }),
    levelNow: row['level_now'] as String?,
    progress: progressData == null
        ? null
        : progressFromRow(progressData as Map<String, dynamic>),
    why: row['why'] as String?,
    ownGoal: row['own_goal'] as String?,
  );
}
