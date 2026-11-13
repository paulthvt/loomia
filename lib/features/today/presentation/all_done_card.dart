import 'dart:math' as math;

import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The Today hero card once everything on today's list was ticked: a check
/// badge in a little confetti, a warm line, the full bar and its count. A
/// moment, not a reward: nothing here counts days or compares.
class AllDoneCard extends StatelessWidget {
  const AllDoneCard({required this.done, required this.firstName, super.key});

  /// Rows ticked today: the whole list.
  final int done;

  /// Empty when the account has none.
  final String firstName;

  /// The confetti layer, for tests.
  static const confettiKey = ValueKey('all-done-confetti');

  static const double _badge = 76;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Decoration only: the title says it.
        ExcludeSemantics(
          child: SizedBox(
            height: _badge + AppSpacing.lg,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  key: confettiKey,
                  child: _Confetti(
                    colors: [
                      scheme.primary,
                      colors.heroGradient.colors.first,
                      colors.heroGradient.colors.last,
                      colors.accent,
                      colors.success,
                      scheme.secondary,
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [scheme.primary, colors.heroGradient.colors.last],
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: _badge,
                    child: Icon(
                      Icons.check_rounded,
                      size: _badge / 2,
                      color: scheme.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.todayAllDone,
          textAlign: TextAlign.center,
          style: AppTypography.titleLarge.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.todayAllDoneBody(firstName),
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        const ExcludeSemantics(
          child: LoomiaProgressBar(value: 1, tone: ProgressTone.primary),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.todayDone(done, done),
          textAlign: TextAlign.center,
          style: AppTypography.caption.copyWith(color: colors.primaryText),
        ),
      ],
    );
  }
}

/// A few still pieces around the badge, always in the same places.
class _Confetti extends StatelessWidget {
  const _Confetti({required this.colors});

  final List<Color> colors;

  /// Where (as an [Alignment]), which colour, and whether a strip (turned by
  /// the angle) or a dot.
  static const _pieces = [
    (x: -0.78, y: -0.70, color: 3, strip: false, turn: 0.0),
    (x: -0.55, y: -0.45, color: 0, strip: true, turn: -0.5),
    (x: -0.70, y: 0.15, color: 0, strip: true, turn: 0.6),
    (x: -0.45, y: 0.45, color: 1, strip: false, turn: 0.0),
    (x: -0.20, y: -0.85, color: 1, strip: false, turn: 0.0),
    (x: 0.45, y: -0.65, color: 1, strip: true, turn: 0.3),
    (x: 0.75, y: -0.55, color: 4, strip: false, turn: 0.0),
    (x: 0.50, y: 0.15, color: 2, strip: false, turn: 0.0),
    (x: 0.38, y: 0.55, color: 0, strip: true, turn: 0.8),
    (x: 0.82, y: 0.45, color: 5, strip: true, turn: -0.3),
  ];

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      for (final piece in _pieces)
        Align(
          alignment: Alignment(piece.x, piece.y),
          child: Transform.rotate(
            angle: piece.turn * math.pi / 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors[piece.color],
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: piece.strip
                  ? const SizedBox(width: 6, height: 12)
                  : const SizedBox.square(dimension: 7),
            ),
          ),
        ),
    ],
  );
}
