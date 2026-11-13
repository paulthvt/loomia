import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/content_columns.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/core/ui/tick_ring.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/domain/month_review.dart';
import 'package:loomia/features/goals/presentation/close_form.dart';
import 'package:loomia/features/goals/presentation/plan_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Step 2 of 3: the month just closed, looked back on before planning the
/// next (#475). Same layout whatever happened; reached objectives are praised
/// by name, the rest are "on its way", never "missed" (principle #5).
class MonthReview extends StatelessWidget {
  const MonthReview({
    required this.closed,
    required this.next,
    required this.model,
    required this.onNext,
    this.onClose,
    super.key,
  });

  /// The hero's close button; none without.
  final VoidCallback? onClose;

  /// With at least one target (`goalsOf` not empty).
  final MonthPlan closed;

  /// The month planned in step 3.
  final DateTime next;
  final BusinessModel model;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final goals = goalsOf(closed, model);
    final reached = [
      for (final goal in goals)
        if (goal.reached) goal,
    ];
    final open = [
      for (final goal in goals)
        if (!goal.reached) goal,
    ];
    final month = closed.month;

    String label(GoalKind kind) => switch (kind) {
      GoalKind.ownVolume => l10n.goalOwnVolume,
      GoalKind.prospects => l10n.goalNewProspects,
      GoalKind.customers => l10n.goalNewCustomers,
      GoalKind.teamMembers => l10n.goalNewTeamMembers,
      GoalKind.loyalty => l10n.goalLoyalty(model.name),
      GoalKind.teamVolume => l10n.planTeamVolume(model.name),
      GoalKind.level => l10n.planLevel(model.name),
    };

    Widget row(GoalResult goal) {
      final done = goal.done;
      final target = goal.target;
      final value = switch ((goal.kind, done, target)) {
        (_, null, _) => l10n.reviewNotFilledIn,
        (GoalKind.level, final String level, final String aim) =>
          goal.reached ? level : l10n.reviewLevel(level, aim),
        (GoalKind.ownVolume, final num done, final num target) =>
          l10n.closeVolumeOf(
            model.name,
            number.format(done),
            number.format(target),
          ),
        (_, final num done, final num target) => l10n.closeOf(
          number.format(done),
          number.format(target),
        ),
        _ => '$done',
      };
      return ResultRow(
        label: label(goal.kind),
        value: value,
        reached: goal.reached,
        progress: switch ((done, target)) {
          (final num done, final num target) when target > 0 =>
            (done / target).clamp(0, 1).toDouble(),
          _ => null,
        },
      );
    }

    List<Widget> group(String title, List<GoalResult> goals) => [
      SectionHeader(title: title),
      Card(
        // Each objective reads on its own, its "Reached" with it.
        semanticContainer: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            spacing: AppSpacing.md,
            children: [for (final goal in goals) row(goal)],
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
    ];

    final (title, body) = open.isEmpty
        ? (l10n.reviewTitleAll, l10n.reviewBodyAll(month))
        : reached.isEmpty
        ? (l10n.reviewTitleNone(month), l10n.reviewBodyNone(next))
        : (
            l10n.reviewTitleSome(month),
            l10n.reviewBodySome(reached.length, goals.length),
          );

    // One column at every width, centred and capped on wide screens.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ContentColumns.mainMax),
        child: HeroFormList(
          onClose: onClose,
          eyebrow: l10n.closeStep(2, 3),
          title: title,
          children: [
            const StepBar(step: 2, total: 3),
            const SizedBox(height: AppSpacing.lg),
            if (open.isEmpty) ...[
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: ReachedRing(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Text(
              body,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: LoomiaColors.of(context).textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (reached.isEmpty)
              ...group(l10n.reviewBuilt, open)
            else ...[
              ...group(l10n.reviewReached, reached),
              if (open.isNotEmpty) ...group(l10n.reviewOnItsWay, open),
            ],
            FilledButton(onPressed: onNext, child: Text(l10n.reviewPlan(next))),
          ],
        ),
      ),
    );
  }
}

/// Every objective reached: the ring draws closed with its check, once
/// (320ms, decelerate), and holds — the one celebration principle #5 allows
/// (design system §7.4). Reduce motion: it fades in, already closed.
class ReachedRing extends StatefulWidget {
  const ReachedRing({super.key});

  @override
  State<ReachedRing> createState() => _ReachedRingState();
}

class _ReachedRingState extends State<ReachedRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.status == AnimationStatus.dismissed) {
      _controller
        ..duration = context.motion(AppMotion.slow)
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _size = 88.0;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final reduce = context.reduceMotion;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final drawn = reduce
              ? 1.0
              : AppMotion.decelerate.transform(_controller.value);
          final ring = SizedBox.square(
            dimension: _size,
            child: CustomPaint(
              painter: _RingPainter(progress: drawn, color: color),
              child: Center(
                child: CustomPaint(
                  size: const Size.square(_size / 2),
                  painter: CheckPainter(progress: drawn, color: color),
                ),
              ),
            ),
          );
          return reduce
              ? Opacity(opacity: _controller.value, child: ring)
              : ring;
        },
      ),
    );
  }
}

/// The ring, drawn clockwise from the top to [progress] (1 closed).
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width / 14;
    canvas.drawArc(
      (Offset.zero & size).deflate(stroke / 2),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
