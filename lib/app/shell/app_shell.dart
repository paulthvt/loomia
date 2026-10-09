import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/loomia_wordmark.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Chrome around every signed-in screen (`docs/design/components.md` #23).
///
/// Desktop: the 248px sidebar. Tablet: the same sidebar collapsed to a 72px
/// icon rail. Mobile: a bottom bar with the destinations, except on Settings,
/// which is reached from [AccountButton] and has its own back button, and on
/// Contacts while picking several people, whose actions take the bar's place.
/// Team returns with the team plan; until then the Contacts `Team` filter
/// lists the team, and Today its check-ins.
///
/// ponytail: the design moves these edges to 840px (rail/bottom bar) and
/// 1100px (rail/sidebar); size classes are used until the difference is
/// visible.
class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});

  /// The current path, to mark the active destination.
  final String location;
  final Widget child;

  /// Back on another tab returns to Today, the home; only Today exits the
  /// app. Pages pushed inside a tab pop first: their navigator is asked
  /// before this route's.
  @override
  Widget build(BuildContext context, WidgetRef ref) => PopScope(
    canPop: location == Routes.today,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) context.go(Routes.today);
    },
    child: _chrome(context, ref),
  );

  Widget _chrome(BuildContext context, WidgetRef ref) {
    final size = context.screenSize;
    if (!size.usesSideNavigation) {
      final picking =
          location.startsWith(Routes.contacts) &&
          ref.watch(contactsPickingProvider);
      if (location.startsWith(Routes.settings)) return child;
      final l10n = AppLocalizations.of(context);
      const tabs = [
        Routes.today,
        Routes.calendar,
        Routes.contacts,
        Routes.goals,
      ];
      final selected = tabs.lastIndexWhere(
        (path) => path == Routes.today
            ? location == Routes.today
            : location.startsWith(path),
      );
      return Scaffold(
        body: child,
        // Null rather than another tree: the Contacts list keeps its state.
        bottomNavigationBar: picking
            ? null
            : NavigationBar(
                // A pushed page outside the tabs keeps Today marked, as before.
                selectedIndex: selected < 0 ? 0 : selected,
                onDestinationSelected: (index) => context.go(tabs[index]),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.wb_sunny_outlined),
                    label: l10n.navToday,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.calendar_month_outlined),
                    label: l10n.navCalendar,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.people_outline),
                    label: l10n.navContacts,
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.flag_outlined),
                    label: l10n.navGoals,
                  ),
                ],
              ),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The right inset (a landscape phone's nav buttons) belongs to the
        // content; left in, every ListTile in the rail pads by it again.
        MediaQuery.removePadding(
          context: context,
          removeRight: true,
          child: _Sidebar(location: location, expanded: size.isDesktop),
        ),
        // A route's modal barrier blocks the semantics of everything painted
        // before it; without this boundary screen readers never see the sidebar.
        Expanded(child: Semantics(container: true, child: child)),
      ],
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.location, required this.expanded});

  static const double _expandedWidth = 248;
  static const double _railWidth = 72;

  final String location;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LoomiaColors.of(context);
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(accountProvider);

    return Material(
      color: colors.surfaceSunken,
      child: Container(
        // Grows by the inset the SafeArea below takes (a landscape phone's
        // cutout), so the items keep their full width.
        width:
            (expanded ? _expandedWidth : _railWidth) +
            MediaQuery.paddingOf(context).left,
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: colors.borderSubtle)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.ms),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.xs,
              children: [
                if (expanded)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.ms,
                      AppSpacing.sm,
                      AppSpacing.ms,
                      AppSpacing.lg,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: LoomiaWordmark(
                        style: Theme.of(context).textTheme.headlineSmall!,
                      ),
                    ),
                  ),
                _SidebarItem(
                  icon: const Icon(Icons.wb_sunny_outlined),
                  label: l10n.navToday,
                  selected: location == Routes.today,
                  expanded: expanded,
                  onTap: () => context.go(Routes.today),
                ),
                _SidebarItem(
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: l10n.navCalendar,
                  selected: location.startsWith(Routes.calendar),
                  expanded: expanded,
                  onTap: () => context.go(Routes.calendar),
                ),
                _SidebarItem(
                  icon: const Icon(Icons.people_outline),
                  label: l10n.navContacts,
                  selected: location.startsWith(Routes.contacts),
                  expanded: expanded,
                  onTap: () => context.go(Routes.contacts),
                ),
                _SidebarItem(
                  icon: const Icon(Icons.flag_outlined),
                  label: l10n.navGoals,
                  selected: location.startsWith(Routes.goals),
                  expanded: expanded,
                  onTap: () => context.go(Routes.goals),
                ),
                const Spacer(),
                if (account != null)
                  _SidebarItem(
                    icon: PhotoAvatar(
                      name: account.displayName,
                      photoPath: account.avatarPath,
                      size: AvatarSize.dense,
                    ),
                    label: account.displayName,
                    semanticLabel: l10n.settingsTitle,
                    selected: location.startsWith(Routes.settings),
                    expanded: expanded,
                    onTap: () => context.go(Routes.settings),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 44px (a pointer is precise), radius 12, active = `primary/container`, hover
/// = `primary/muted` (#22). Collapsed, the label becomes the semantic label —
/// an icon never carries meaning alone.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
    this.semanticLabel,
  });

  final Widget icon;
  final String label;

  /// When what the item does differs from what it shows (the account block
  /// shows a name and opens Settings).
  final String? semanticLabel;
  final bool selected;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    // Labels the content, not the tile: the tile keeps its own tap action and
    // selected state for screen readers.
    final content = Semantics(
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: expanded
          ? Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)
          : Center(child: icon),
    );
    return ListTile(
      minTileHeight: 44,
      contentPadding: expanded
          ? const EdgeInsets.symmetric(horizontal: AppSpacing.ms)
          : EdgeInsets.zero,
      horizontalTitleGap: AppSpacing.ms,
      selected: selected,
      selectedTileColor: scheme.primaryContainer,
      selectedColor: scheme.onPrimaryContainer,
      hoverColor: colors.primaryMuted,
      leading: expanded ? ExcludeSemantics(child: icon) : null,
      title: content,
      titleTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
      ),
      onTap: onTap,
    );
  }
}

/// Opens Settings from a screen's top bar, where there is no sidebar (mobile).
/// Pushed, not gone to, so back returns to the screen it was opened from.
class AccountButton extends ConsumerWidget {
  const AccountButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(accountProvider);
    if (account == null) return const SizedBox.shrink();
    return IconButton(
      onPressed: () => context.push(Routes.settings),
      icon: Semantics(
        label: AppLocalizations.of(context).settingsTitle,
        excludeSemantics: true,
        child: PhotoAvatar(
          name: account.displayName,
          photoPath: account.avatarPath,
          size: AvatarSize.dense,
        ),
      ),
    );
  }
}
