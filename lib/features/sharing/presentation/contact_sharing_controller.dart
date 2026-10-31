import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/invite_code.dart';
import 'package:loomia/features/sharing/domain/shared_goals.dart';

typedef ContactSharing = ({SharedGoals? shared, Invite? invite});

final contactSharingProvider = FutureProvider.autoDispose
    .family<ContactSharing, String>((ref, personId) async {
      final repo = ref.watch(sharingRepositoryProvider);
      final now = DateTime.now();

      final shared = await repo.sharedGoals(personId, now);
      if (shared != null) {
        return (shared: shared, invite: null);
      }

      final invite = await repo.openInvite(personId);
      return (shared: null, invite: invite);
    });
