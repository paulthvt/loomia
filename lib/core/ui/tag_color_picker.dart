import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/tag_chip.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The tag palette as a row of swatches, [selected] ringed and checked: the
/// tag form's (#332) and the event type editor's (#516). [onPick] null
/// disables it.
class TagColorPicker extends StatelessWidget {
  const TagColorPicker({
    required this.selected,
    required this.onPick,
    super.key,
  });

  final TagColor selected;
  final ValueChanged<TagColor>? onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final pick = onPick;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final key in TagColor.values)
          _Swatch(
            color: key,
            selected: key == selected,
            label: tagColorName(l10n, key),
            onTap: pick == null ? null : () => pick(key),
          ),
      ],
    );
  }
}

/// One palette colour, ringed when picked.
class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final TagColor color;
  final bool selected;
  final String label;
  final VoidCallback? onTap;

  static const double _size = 32;

  @override
  Widget build(BuildContext context) {
    final tag = color.of(context);
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: kMinInteractiveDimension / 2,
        child: SizedBox.square(
          dimension: kMinInteractiveDimension,
          child: Center(
            child: Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                color: tag.container,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.onSurface
                      : tag.ink,
                  width: selected ? 3 : 1,
                ),
              ),
              child: selected
                  ? Icon(Icons.check_rounded, size: 18, color: tag.ink)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
