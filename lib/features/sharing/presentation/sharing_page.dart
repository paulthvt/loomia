import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';
import 'package:loomia/features/sharing/domain/shared_goals.dart';
import 'package:loomia/features/sharing/presentation/accept_invite.dart';
import 'package:loomia/features/sharing/presentation/sharing_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class SharingPage extends ConsumerStatefulWidget {
  const SharingPage({super.key});

  @override
  ConsumerState<SharingPage> createState() => _SharingPageState();
}

class _SharingPageState extends ConsumerState<SharingPage> {
  late final TextEditingController _whyController;
  late final TextEditingController _ownGoalController;
  bool _aboutMeBusy = false;
  bool _aboutMeInitialized = false;

  @override
  void initState() {
    super.initState();
    _whyController = TextEditingController();
    _ownGoalController = TextEditingController();

    // Initialize controllers when aboutMe data loads
    ref.listenManual(aboutMeProvider, (previous, next) {
      if (!_aboutMeInitialized) {
        next.whenData((data) {
          if (data.why != null) _whyController.text = data.why!;
          if (data.ownGoal != null) _ownGoalController.text = data.ownGoal!;
          _aboutMeInitialized = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _whyController.dispose();
    _ownGoalController.dispose();
    super.dispose();
  }

  Future<void> _saveAboutMe() async {
    if (_aboutMeBusy) return;
    setState(() => _aboutMeBusy = true);

    final aboutMe = AboutMe(
      why: _whyController.text.trim().isEmpty
          ? null
          : _whyController.text.trim(),
      ownGoal: _ownGoalController.text.trim().isEmpty
          ? null
          : _ownGoalController.text.trim(),
    );

    try {
      await ref.read(sharingRepositoryProvider).saveAboutMe(aboutMe);
      if (mounted) {
        ref.invalidate(aboutMeProvider);
        setState(() => _aboutMeBusy = false);
      }
    } catch (e) {
      if (mounted) setState(() => _aboutMeBusy = false);
    }
  }

  Future<void> _stopSharing() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await confirmDestructive(
      context,
      title: l10n.sharingStopTitle,
      action: l10n.sharingStopAction,
      body: l10n.sharingStopBody,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(sharingRepositoryProvider).stopSharing();
      if (mounted) ref.invalidate(myShareProvider);
    } catch (e) {
      // Silent: stop shows on error, user tries again.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myShare = ref.watch(myShareProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          myShare.when(
            data: (share) => share == null
                ? AcceptInvite(
                    onAccepted: () {
                      ref.invalidate(myShareProvider);
                    },
                  )
                : _LinkedState(share: share, onStopSharing: _stopSharing),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => const SizedBox.shrink(),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l10n.sharingAboutMeTitle),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.sharingAboutMeCaption,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          SettingsGroup(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LabeledField(
                      label: l10n.sharingWhyLabel,
                      child: TextField(
                        controller: _whyController,
                        maxLines: 3,
                        decoration: const InputDecoration(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    LabeledField(
                      label: l10n.sharingOwnGoalLabel,
                      child: TextField(
                        controller: _ownGoalController,
                        maxLines: 3,
                        decoration: const InputDecoration(),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: _aboutMeBusy ? null : _saveAboutMe,
                      child: _aboutMeBusy
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              MaterialLocalizations.of(context).saveButtonLabel,
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinkedState extends ConsumerStatefulWidget {
  const _LinkedState({required this.share, required this.onStopSharing});

  final MyShare share;
  final VoidCallback onStopSharing;

  @override
  ConsumerState<_LinkedState> createState() => _LinkedStateState();
}

class _LinkedStateState extends ConsumerState<_LinkedState> {
  late Set<ShareItem> _items;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _items = Set.of(widget.share.items);
  }

  Future<void> _toggle(ShareItem item, bool value) async {
    if (_busy) return;

    final newItems = Set.of(_items);
    if (value) {
      newItems.add(item);
    } else {
      newItems.remove(item);
    }

    setState(() {
      _items = newItems;
      _busy = true;
    });

    try {
      await ref.read(sharingRepositoryProvider).setItems(newItems);
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _items = Set.of(widget.share.items);
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.sharingLinkedWith(widget.share.mentorFirstName),
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        SettingsGroup(
          children: [
            ListTile(
              title: Text(l10n.inviteAlwaysShared),
              trailing: Text(l10n.inviteAlwaysSharedBadge),
            ),
            SwitchListTile(
              title: Text(l10n.shareItemActivityTargets),
              value: _items.contains(ShareItem.activityTargets),
              onChanged: _busy
                  ? null
                  : (value) => _toggle(ShareItem.activityTargets, value),
            ),
            SwitchListTile(
              title: Text(l10n.shareItemProgress),
              value: _items.contains(ShareItem.progress),
              onChanged: _busy
                  ? null
                  : (value) => _toggle(ShareItem.progress, value),
            ),
            SwitchListTile(
              title: Text(l10n.shareItemAboutMe),
              value: _items.contains(ShareItem.aboutMe),
              onChanged: _busy
                  ? null
                  : (value) => _toggle(ShareItem.aboutMe, value),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.tonal(
          style: AppTheme.tonal(context),
          onPressed: widget.onStopSharing,
          child: Text(l10n.sharingStopButton),
        ),
      ],
    );
  }
}
