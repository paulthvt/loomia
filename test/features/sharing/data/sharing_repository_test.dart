import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';

void main() {
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
