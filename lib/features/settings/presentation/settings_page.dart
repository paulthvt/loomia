import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/auth/presentation/auth_failure_copy.dart';
import 'package:loomia/features/settings/presentation/account_settings.dart';
import 'package:loomia/features/settings/presentation/appearance_settings.dart';
import 'package:loomia/features/settings/presentation/language_settings.dart';
import 'package:loomia/features/settings/presentation/settings_action.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_scroll.dart';
import 'package:loomia/features/workflows/presentation/workflow_editor.dart';
import 'package:loomia/features/workflows/presentation/workflows_settings.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

enum SettingsSection { account, language, appearance, workflows }

/// The installed app version, major.minor.patch ("0.1.3"): the build number
/// only matters to the stores. Loaded once: it never changes while the app runs.
final _appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// The Settings list, and one of its sections.
///
/// Desktop shows both: the list on the left, the open section — Account when
/// none is — on the right. Mobile and tablet show one at a time, each section
/// its own screen; a tablet's rail leaves too little room for two panes.
class SettingsPage extends StatelessWidget {
  const SettingsPage({this.section, this.workflowId, super.key});

  static const double _listWidth = 400;

  final SettingsSection? section;

  /// The workflow open in [SettingsSection.workflows]; null shows the list.
  final String? workflowId;

  /// Beside the list on desktop; elsewhere pushed, so back returns to it.
  static void open(BuildContext context, SettingsSection section) {
    final location = switch (section) {
      SettingsSection.account => Routes.settingsAccount,
      SettingsSection.language => Routes.settingsLanguage,
      SettingsSection.appearance => Routes.settingsAppearance,
      SettingsSection.workflows => Routes.settingsWorkflows,
    };
    if (context.screenSize.isDesktop) {
      context.go(location);
    } else {
      context.push(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final size = context.screenSize;
    final current = section;

    if (size.isDesktop) {
      final shown = current ?? SettingsSection.account;
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: _listWidth,
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: LoomiaColors.of(context).borderSubtle,
                    ),
                  ),
                ),
                child: SettingsScroll(
                  title: l10n.settingsTitle,
                  child: _SettingsList(selected: shown),
                ),
              ),
              Expanded(
                child: _Section(section: shown, workflowId: workflowId),
              ),
            ],
          ),
        ),
      );
    }

    // Mobile reaches the list by push from a top bar; on a tablet it is a rail
    // destination with nothing to go back to. A section always goes back.
    final canGoBack = size.isMobile || current != null;
    return Scaffold(
      appBar: canGoBack
          ? AppBar(
              leading: BackButton(
                onPressed: () => backOr(
                  context,
                  current == null
                      ? Routes.today
                      : workflowId == null
                      ? Routes.settings
                      : Routes.settingsWorkflows,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: current == null
            ? SettingsScroll(
                title: l10n.settingsTitle,
                child: const _SettingsList(),
              )
            : _Section(section: current, workflowId: workflowId),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section, this.workflowId});

  final SettingsSection section;
  final String? workflowId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (section) {
      SettingsSection.account => SettingsScroll(
        title: l10n.settingsSectionAccount,
        child: const AccountSettings(),
      ),
      SettingsSection.language => SettingsScroll(
        title: l10n.settingsSectionLanguage,
        child: const LanguageSettings(),
      ),
      SettingsSection.appearance => SettingsScroll(
        title: l10n.settingsSectionAppearance,
        child: const AppearanceSettings(),
      ),
      SettingsSection.workflows => switch (workflowId) {
        null => SettingsScroll(
          title: l10n.settingsSectionWorkflows,
          child: const WorkflowsSettings(),
        ),
        // A new id is a new editor: nothing typed carries over.
        final id => _WorkflowPane(
          child: WorkflowEditor(key: ValueKey(id), id: id),
        ),
      },
    };
  }
}

/// On desktop the editor replaces the list in the pane, where the page has
/// no app bar: this one's back returns to the list. Elsewhere the page's
/// own app bar does.
class _WorkflowPane extends StatelessWidget {
  const _WorkflowPane({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!context.screenSize.isDesktop) return child;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => backOr(context, Routes.settingsWorkflows),
        ),
      ),
      body: child,
    );
  }
}

/// Profile, grouped rows, sign out. New settings are new rows in a group.
///
/// Signing out needs no navigation here: the session ends, and the router's
/// redirect takes the user to /welcome.
class _SettingsList extends ConsumerStatefulWidget {
  const _SettingsList({this.selected});

  /// The section open beside the list, on desktop.
  final SettingsSection? selected;

  @override
  ConsumerState<_SettingsList> createState() => _SettingsListState();
}

class _SettingsListState extends ConsumerState<_SettingsList>
    with SettingsAction {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(accountProvider);
    final selected = widget.selected;
    final error = failure;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (account != null) ...[
          SettingsGroup(
            children: [
              ListTile(
                selected: selected == SettingsSection.account,
                leading: LoomiaAvatar(
                  name: account.displayName,
                  size: AvatarSize.row,
                ),
                // One line each: this row only says whose account it is; the
                // full email is on the Account screen.
                title: Text(
                  account.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: account.firstName.isEmpty
                    ? null
                    : Text(
                        account.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () =>
                    SettingsPage.open(context, SettingsSection.account),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        SettingsGroup(
          children: [
            ListTile(
              selected: selected == SettingsSection.workflows,
              leading: const Icon(Icons.route_rounded),
              title: Text(l10n.settingsSectionWorkflows),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () =>
                  SettingsPage.open(context, SettingsSection.workflows),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SectionHeader(title: l10n.settingsSectionPreferences),
        SettingsGroup(
          children: [
            ListTile(
              selected: selected == SettingsSection.language,
              leading: const Icon(Icons.translate_rounded),
              title: Text(l10n.settingsSectionLanguage),
              subtitle: Text(
                account?.locale == null
                    ? l10n.settingsLanguageSystem
                    : l10n.languageName,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => SettingsPage.open(context, SettingsSection.language),
            ),
            ListTile(
              selected: selected == SettingsSection.appearance,
              leading: const Icon(Icons.contrast_rounded),
              title: Text(l10n.settingsSectionAppearance),
              subtitle: Text(
                appearanceLabel(l10n, account?.appearance ?? Appearance.system),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () =>
                  SettingsPage.open(context, SettingsSection.appearance),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (error != null) ...[
          FormError(authFailureCopy(l10n, error)),
          const SizedBox(height: AppSpacing.md),
        ],
        SettingsGroup(
          children: [
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: Text(l10n.settingsSignOut),
              onTap: busy ? null : () => run((auth) => auth.signOut()),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            // Silent until it resolves; a version footer is non-critical.
            ref
                .watch(_appVersionProvider)
                .maybeWhen(
                  data: (version) => l10n.settingsVersion(version),
                  orElse: () => '',
                ),
            style: AppTypography.caption.copyWith(
              color: LoomiaColors.of(context).textMuted,
            ),
          ),
        ),
      ],
    );
  }
}
