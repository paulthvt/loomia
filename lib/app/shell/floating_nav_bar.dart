import 'package:loomia/app/shell/create_action.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The phone's navigation: a dark pill floating 16px above the safe area,
/// the four tabs and, on the right, the white + of [create]. The active tab
/// is an amber pill with its label; the others show their icon only, the
/// label left to screen readers.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    required this.selected,
    required this.onSelect,
    required this.create,
    required this.onCreate,
    super.key,
  });

  static const double _height = 68;
  static const double _createSize = 52;

  /// The active tab: 0 Today, 1 Calendar, 2 Contacts, 3 Goals.
  final int selected;
  final ValueChanged<int> onSelect;

  /// No + without one.
  final CreateAction? create;

  /// Gets the + button's context, so a menu opens over it.
  final ValueChanged<BuildContext>? onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final l10n = AppLocalizations.of(context);
    final create = this.create;
    final tabs = [
      (Icons.wb_sunny_outlined, l10n.navToday),
      (Icons.calendar_month_outlined, l10n.navCalendar),
      (Icons.people_outline, l10n.navContacts),
      (Icons.flag_outlined, l10n.navGoals),
    ];
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Container(
          height: _height,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: ShapeDecoration(
            color: colors.chrome.withValues(alpha: 0.95),
            shape: StadiumBorder(side: BorderSide(color: colors.chromeBorder)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final (index, (icon, label)) in tabs.indexed)
                      if (index == selected)
                        Flexible(
                          child: _Tab(
                            icon: icon,
                            label: label,
                            selected: true,
                            onTap: () => onSelect(index),
                          ),
                        )
                      else
                        _Tab(
                          icon: icon,
                          label: label,
                          selected: false,
                          onTap: () => onSelect(index),
                        ),
                  ],
                ),
              ),
              if (create != null)
                Builder(
                  builder: (button) => IconButton(
                    onPressed: switch (onCreate) {
                      final run? => () => run(button),
                      null => null,
                    },
                    tooltip: create.label,
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(_createSize),
                      backgroundColor: colors.onChrome,
                      foregroundColor: colors.chrome,
                    ),
                    icon: Icon(create.icon),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A destination: selected, an amber pill holding icon and label; else the
/// icon alone. Either way the label and the selected state are announced.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    final color = selected ? colors.onChrome : colors.onChromeMuted;
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: Padding(
        // 44 high in the 52 the + takes.
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Material(
          type: selected ? MaterialType.canvas : MaterialType.transparency,
          color: selected ? scheme.primary : null,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: selected ? AppSpacing.md : AppSpacing.ms,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.sm,
                children: [
                  Icon(icon, color: color),
                  if (selected)
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: color),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
