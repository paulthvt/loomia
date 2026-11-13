import 'package:loomia/app/shell/create_action.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
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

  final VoidCallback? onCreate;

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

/// The four destinations and one amber pill behind them. The pill sits at
/// a fractional position `t` that eases toward [selected]; every tab's width
/// and colour follow its closeness to `t`, so the room the pill covers moves
/// with it between the tabs. An inactive tab is its icon in the 48px
/// tap target; the active one takes the rest of the row.
class _Tabs extends StatelessWidget {
  const _Tabs({
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  final List<(IconData, String)> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final style = DefaultTextStyle.of(context).style
        .merge(Theme.of(context).textTheme.labelLarge);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final iconSize = IconTheme.of(context).size!;
    return LayoutBuilder(
      builder: (context, constraints) {
        const inactive = kMinInteractiveDimension;
        final extra = constraints.maxWidth - inactive * tabs.length;
        // A label shows only if all of it fits the settled pill: never "Cale…".
        final room = inactive + extra - 2 * _Tab.padding - iconSize - _Tab.gap;
        bool fits(String label) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textScaler: scaler,
            textDirection: direction,
            maxLines: 1,
          )..layout();
          final width = painter.width;
          painter.dispose();
          return width <= room;
        }

        return TweenAnimationBuilder<double>(
          // No begin: the first frame is settled, and a change mid-flight
          // carries on from where the pill is.
          tween: Tween(end: selected.toDouble()),
          duration: context.motion(AppMotion.emphasized),
          curve: Curves.easeInOutCubicEmphasized,
          builder: (context, t, _) {
            double presence(int i) => (1 - (t - i).abs()).clamp(0, 1);
            // The extra width slides as one piece, so does the pill over it.
            final pill = Rect.fromLTWH(
              inactive * t,
              0,
              inactive + extra,
              constraints.maxHeight,
            );
            return Stack(
              children: [
                Positioned.fromRect(
                  rect: pill,
                  child: Padding(
                    padding: _Tab.inset,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: primary,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, (icon, label)) in tabs.indexed)
                      SizedBox(
                        width: inactive + extra * presence(index),
                        child: _Tab(
                          icon: icon,
                          label: label,
                          showLabel: fits(label),
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

/// A destination: its icon, and its label as it nears the pill. Either way
/// the label and the selected state are announced.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.showLabel,
    required this.selected,
    required this.presence,
    required this.onTap,
  });

  /// 44 high in the 52 the + takes.
  static const inset = EdgeInsets.symmetric(vertical: AppSpacing.xs);

  /// Either side of the icon and label, and between them.
  static const padding = AppSpacing.ms;
  static const gap = AppSpacing.sm;

  /// Below this presence the label is hidden; above it, it fades in.
  static const _labelFrom = 0.45;

  final IconData icon;
  final String label;

  /// Whether [label] fits the settled pill; if not, the pill is its icon.
  final bool showLabel;
  final bool selected;

  /// 1 under the settled pill, 0 one tab away or more.
  final double presence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = LoomiaColors.of(context);
    final color = Color.lerp(colors.onChromeMuted, colors.onChrome, presence);
    // The whole 52 takes the tap; the pill shows in the 44 inside.
    final tab = Material(
      type: MaterialType.transparency,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: inset,
          child: ClipRect(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: padding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: gap,
                children: [
                  Icon(icon, color: color),
                  if (showLabel && presence > _labelFrom)
                    Flexible(
                      child: Opacity(
                        opacity: ((presence - _labelFrom) / (1 - _labelFrom))
                            .clamp(0, 1),
                        child: Text(
                          label,
                          // Settled, it fits; mid-slide the ClipRect cuts it.
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.visible,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: color),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      container: true,
      selected: selected,
      button: true,
      label: label,
      // excludeSemantics drops the InkWell's tap: give it back.
      onTap: onTap,
      excludeSemantics: true,
      child: selected && showLabel ? tab : Tooltip(message: label, child: tab),
    );
  }
}
