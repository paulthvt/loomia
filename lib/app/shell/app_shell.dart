import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/create_action.dart';
import 'package:loomia/app/shell/floating_nav_bar.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/loomia_wordmark.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/presentation/account_photo.dart';
import 'package:loomia/features/contacts/presentation/contacts_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Chrome around every signed-in screen (`docs/design/components.md` #23).
///
/// Desktop: the floating [AppSidebar]. Tablet: the same panel collapsed to a
/// 72px icon rail. Mobile: the [FloatingNavBar] on the four tabs only, its +
/// creating what the tab is about; not on a screen opened from one (back
/// arrow instead) nor on Contacts while picking several people, whose
/// actions take the bar's place.
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

  /// The phone's tabs, in the bar's order. The bar shows on these paths
  /// only: a contact, an event or Settings has its back arrow instead.
  static const _tabs = [
    Routes.today,
    Routes.calendar,
    Routes.contacts,
    Routes.goals,
  ];

  /// Under the last row of a tab, above the safe area: clear of the bar.
  static const double _barRoom = AppSpacing.xxl * 2.5;

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
      if (location.startsWith(Routes.settings)) return child;
      final picking =
          location.startsWith(Routes.contacts) &&
          ref.watch(contactsPickingProvider);
      final selected = _tabs.indexOf(location);
      final bar = selected >= 0 && !picking;
      final create = createActionFor(location, AppLocalizations.of(context));
      final media = MediaQuery.of(context);
      return Scaffold(
        // The tab's list runs under the bar, the room it needs left as bottom
        // padding. Always this MediaQuery, only its data changes: the
        // Contacts list keeps its state.
        extendBody: true,
        body: MediaQuery(
          data: media.copyWith(
            padding: media.padding.copyWith(
              bottom: media.padding.bottom + (bar ? _barRoom : 0),
            ),
          ),
          child: child,
        ),
        bottomNavigationBar: bar
            ? FloatingNavBar(
                selected: selected,
                onSelect: (index) => context.go(_tabs[index]),
                create: create,
                onCreate: create == null
                    ? null
                    : (button) => unawaited(create.run(button, ref)),
              )
            : null,
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
          child: AppSidebar(location: location, expanded: size.isDesktop),
        ),
        // A route's modal barrier blocks the semantics of everything painted
        // before it; without this boundary screen readers never see the sidebar.
        Expanded(child: Semantics(container: true, child: child)),
      ],
    );
  }
}

/// The wide-screen navigation: a dark panel floating [AppSpacing.md] in from
/// the window edges, on the canvas. First the white + creating for the
/// section (labelled on desktop, a tooltip on the tablet's rail), then the
/// four destinations, the account block at the bottom.
class AppSidebar extends ConsumerWidget {
  const AppSidebar({required this.location, required this.expanded, super.key});

  static const double _expandedWidth = 232;
  static const double _railWidth = 72;
  static const double _railCreateSize = 44;

  final String location;
  final bool expanded;

  /// The section [location] belongs to; Today for anything outside the four
  /// (Settings), so the + never leaves the panel.
  String get _section =>
      [
        Routes.calendar,
        Routes.contacts,
        Routes.goals,
      ].where(location.startsWith).firstOrNull ??
      Routes.today;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LoomiaColors.of(context);
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(accountProvider);
    final create = createActionFor(_section, l10n)!;

    final createButton = Builder(
      builder: (button) {
        void run() => unawaited(create.run(button, ref));
        final style = AppTheme.createButton(button);
        return expanded
            ? FilledButton.icon(
                onPressed: run,
                style: style,
                icon: Icon(create.icon),
                label: Text(create.label),
              )
            : Center(
                child: IconButton(
                  onPressed: run,
                  tooltip: create.label,
                  style: style.copyWith(
                    fixedSize: const WidgetStatePropertyAll(
                      Size.square(_railCreateSize),
                    ),
                  ),
                  icon: Icon(create.icon),
                ),
              );
      },
    );

    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Container(
            width: expanded ? _expandedWidth : _railWidth,
            decoration: BoxDecoration(
              color: colors.chrome,
              borderRadius: BorderRadius.circular(AppRadii.heroCard),
              border: Border.all(color: colors.chromeBorder),
              boxShadow: colors.heroCardShadow,
            ),
            child: Material(
              type: MaterialType.transparency,
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
                          AppSpacing.md,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: LoomiaWordmark(
                            style: Theme.of(context).textTheme.headlineSmall!
                                .copyWith(color: colors.onChrome),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: AppSpacing.xs),
                    createButton,
                    const SizedBox(height: AppSpacing.md),
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
                        icon: LoomiaAvatar(
                          name: account.displayName,
                          photo: ref.watch(accountPhotoProvider),
                          size: AvatarSize.dense,
                        ),
                        label: account.displayName,
                        subtitle: l10n.settingsTitle,
                        semanticLabel: l10n.settingsTitle,
                        selected: location.startsWith(Routes.settings),
                        block: true,
                        expanded: expanded,
                        onTap: () => context.go(Routes.settings),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 44px (a pointer is precise), a pill: active = `primary` with its label
/// bold in `onChrome`, the others `onChromeMuted`. Collapsed, the label
/// becomes the semantic label — an icon never carries meaning alone. The
/// account [block] sits on `heroFillSubtle`.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.onTap,
    this.subtitle,
    this.semanticLabel,
    this.block = false,
  });

  final Widget icon;
  final String label;

  /// Under the label, expanded only (the account block's "Settings").
  final String? subtitle;

  /// When what the item does differs from what it shows (the account block
  /// shows a name and opens Settings).
  final String? semanticLabel;
  final bool selected;
  final bool expanded;
  final bool block;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    final text = Theme.of(context).textTheme;
    final subtitle = this.subtitle;
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
      shape: block
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
            )
          : const StadiumBorder(),
      tileColor: block ? colors.heroFillSubtle : null,
      selected: selected,
      selectedTileColor: block ? colors.heroFillSubtle : scheme.primary,
      selectedColor: colors.onChrome,
      iconColor: colors.onChromeMuted,
      textColor: colors.onChromeMuted,
      hoverColor: colors.heroFillSubtle,
      leading: expanded ? ExcludeSemantics(child: icon) : null,
      title: content,
      subtitle: expanded && subtitle != null
          ? ExcludeSemantics(child: Text(subtitle))
          : null,
      titleTextStyle: text.labelLarge?.copyWith(
        color: selected || block ? colors.onChrome : colors.onChromeMuted,
        fontWeight: selected || block ? FontWeight.w700 : null,
      ),
      subtitleTextStyle: text.labelSmall?.copyWith(color: colors.onChromeMuted),
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
        child: LoomiaAvatar(
          name: account.displayName,
          photo: ref.watch(accountPhotoProvider),
          size: AvatarSize.dense,
        ),
      ),
    );
  }
}
