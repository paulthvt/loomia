import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// The Horizon card (`AppTheme.card`): the soft shadow on a box behind a
/// Material that paints the fill, so rows' ink and selected fills show on
/// the card, clipped to its corners.
class LoomiaCard extends StatelessWidget {
  const LoomiaCard({
    required this.child,
    this.onTap,
    this.outlined = false,
    this.semanticContainer = true,
    super.key,
  });

  final Widget child;

  /// The whole card as one tap target.
  final VoidCallback? onTap;

  /// A hairline with no fill or shadow, for what is over (#451).
  final bool outlined;

  /// As `Card.semanticContainer`: one node for the card, or false so each
  /// child reads on its own.
  final bool semanticContainer;

  @override
  Widget build(BuildContext context) {
    final card = AppTheme.card(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.card),
      side: outlined
          ? BorderSide(color: LoomiaColors.of(context).borderSubtle)
          : BorderSide.none,
    );
    final tap = onTap;
    final material = Material(
      color: outlined ? Colors.transparent : card.color,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Semantics(
        explicitChildNodes: !semanticContainer,
        child: tap == null
            ? child
            : InkWell(onTap: tap, customBorder: shape, child: child),
      ),
    );
    return Semantics(
      container: semanticContainer,
      child: outlined
          ? material
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: card.borderRadius,
                boxShadow: card.boxShadow,
              ),
              child: material,
            ),
    );
  }
}
