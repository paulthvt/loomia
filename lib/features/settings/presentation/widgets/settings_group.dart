import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/loomia_card.dart';
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
    return LoomiaCard(
      child: ListTileTheme(
        data: AppTheme.settingsRows(context, bold: bold),
        child: Column(
          children: ListTile.divideTiles(
            context: context,
            tiles: children,
          ).toList(),
        ),
      ),
    );
  }
}
