import 'dart:math' as math;

import 'package:loomia/app/shell/create_action.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The four destinations' icons, outlined and filled: the bar, the rail and
/// the sidebar fill the active one.
const navIcons = [
  (Icons.wb_sunny_outlined, Icons.wb_sunny),
  (Icons.calendar_month_outlined, Icons.calendar_month),
  (Icons.people_outline, Icons.people),
  (Icons.flag_outlined, Icons.flag),
];

/// The phone's navigation: a dark pill floating 16px above the safe area,
/// the four tabs and, on the right, the white + of [create]. Icons only: the
/// active tab sits on an amber pill, every name goes to tooltips and screen
/// readers.
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

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final l10n = AppLocalizations.of(context);
    final create = this.create;
    final tabs = [
      l10n.navToday,
      l10n.navCalendar,
      l10n.navContacts,
      l10n.navGoals,
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
            shadows: AppElevation.overlay,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Tabs(
                  tabs: tabs,
                  selected: selected,
                  onSelect: onSelect,
                ),
              ),
              if (create != null)
                IconButton(
                  onPressed: onCreate,
                  tooltip: create.label,
                  style: AppTheme.createButton(context).copyWith(
                    fixedSize: const WidgetStatePropertyAll(
                      Size.square(_createSize),
                    ),
                  ),
                  icon: Icon(create.icon),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The four destinations, sharing the row evenly, and one amber pill behind
/// them. The pill sits at a fractional position `t` that eases toward
/// [selected]; every tab's colour follows its closeness to `t`.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  /// The pill, as in the mockup, centred in its tab.
  static const _pill = Size(60, 44);

  /// The labels, in [navIcons]' order, for tooltips and screen readers.
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return LayoutBuilder(
      builder: (context, constraints) {
        final slot = constraints.maxWidth / tabs.length;
        return TweenAnimationBuilder<double>(
          // No begin: the first frame is settled, and a change mid-flight
          // carries on from where the pill is.
          tween: Tween(end: selected.toDouble()),
          duration: context.motion(AppMotion.emphasized),
          curve: Curves.easeInOutCubicEmphasized,
          builder: (context, t, _) {
            double presence(int i) => (1 - (t - i).abs()).clamp(0, 1);
            return Stack(
              children: [
                // ponytail: LTR only, the pill is placed from the left while
                // the Row lays tabs out right-to-left in RTL. Mirror `t`
                // (length - 1 - t) when an RTL locale ships.
                Positioned.fromRect(
                  rect: Rect.fromCenter(
                    center: Offset(slot * (t + 0.5), constraints.maxHeight / 2),
                    width: math.min(_pill.width, slot),
                    height: _pill.height,
                  ),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: primary,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, label) in tabs.indexed)
                      Expanded(
                        child: _Tab(
                          icon: index == selected
                              ? navIcons[index].$2
                              : navIcons[index].$1,
                          label: label,
                          selected: index == selected,
                          presence: presence(index),
                          onTap: () => onSelect(index),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// A destination: its icon only, its name in a tooltip and announced, with
/// its selected state.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.presence,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;

  /// 1 under the settled pill, 0 one tab away or more.
  final double presence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      label: label,
      // excludeSemantics drops the InkWell's tap: give it back.
      onTap: onTap,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        // The whole slot takes the tap; the pill shows in the 44 inside.
        child: Material(
          type: MaterialType.transparency,
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Icon(
              icon,
              color: Color.lerp(
                colors.onChromeMuted,
                colors.onChrome,
                presence,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
