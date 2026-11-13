import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:material_ui/material_ui.dart';

/// One group of Settings rows (`SettingsRow` in Figma): a Horizon card, a
/// hairline between rows, square row highlights so they meet its edges.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, this.bold = false, super.key});

  /// `ListTile`s.
  final List<Widget> children;

  /// Bold titles, for rows that each explain themselves (Notifications).
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final card = AppTheme.card(context);
    // The shadow on a box, the fill and the rows' ink on a Material above it.
    return DecoratedBox(
      decoration: card,
      child: Material(
        color: card.color,
        borderRadius: BorderRadius.circular(AppRadii.card),
        clipBehavior: Clip.antiAlias,
        child: ListTileTheme(
          data: AppTheme.settingsRows(context, bold: bold),
          child: Column(
            children: ListTile.divideTiles(
              context: context,
              tiles: children,
            ).toList(),
          ),
        ),
      ),
    );
  }
}
