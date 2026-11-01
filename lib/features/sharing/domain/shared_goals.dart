import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';

class MyShare {
  const MyShare({required this.mentorFirstName, required this.items});

  final String mentorFirstName;
  final Set<ShareItem> items;
}

class SharedGoals {
  const SharedGoals({
    required this.memberFirstName,
    required this.items,
    this.plan,
    this.levelNow,
    this.progress,
    this.why,
    this.ownGoal,
  });

  final String memberFirstName;
  final Set<ShareItem> items;
  final MonthPlan? plan;
  final String? levelNow;
  final Progress? progress;
  final String? why;
  final String? ownGoal;
}

class AboutMe {
  const AboutMe({this.why, this.ownGoal});

  final String? why;
  final String? ownGoal;
}
