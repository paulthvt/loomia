import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/auth/presentation/widgets/submit_button.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/invite_code.dart';
import 'package:loomia/features/sharing/domain/invite_failure.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class AcceptInvite extends ConsumerStatefulWidget {
  const AcceptInvite({this.initialCode, required this.onAccepted, super.key});

  final String? initialCode;
  final VoidCallback onAccepted;

  @override
  ConsumerState<AcceptInvite> createState() => _AcceptInviteState();
}

class _AcceptInviteState extends ConsumerState<AcceptInvite> {
  final _codeController = TextEditingController();
  String? _normalised;
  String? _mentorName;
  final _items = {ShareItem.activityTargets};
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeController.text = widget.initialCode!;
      _normalised = normaliseCode(widget.initialCode!);
      if (_normalised != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _preview());
      }
    }
    _codeController.addListener(_onCodeChanged);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeChanged() {
    final normalised = normaliseCode(_codeController.text);
    if (normalised != _normalised) {
      setState(() {
        _normalised = normalised;
        _error = null;
      });
    }
  }

  Future<void> _preview() async {
    if (_normalised == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final name = await ref
          .read(sharingRepositoryProvider)
          .previewInvite(_normalised!);
      if (!mounted) return;
      setState(() {
        _mentorName = name;
        _busy = false;
      });
    } on InviteFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(failure);
        _busy = false;
      });
    }
  }

  Future<void> _accept() async {
    if (_normalised == null || _mentorName == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref
          .read(sharingRepositoryProvider)
          .acceptInvite(_normalised!, _items);
      if (!mounted) return;
      widget.onAccepted();
    } on InviteFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(failure);
        _busy = false;
      });
    }
  }

  String _errorMessage(InviteFailure failure) {
    final l10n = AppLocalizations.of(context);
    return switch (failure) {
      InviteFailure.invalid => l10n.inviteErrorInvalid,
      InviteFailure.own => l10n.inviteErrorOwn,
      InviteFailure.alreadySharing => l10n.inviteErrorAlreadySharing,
      InviteFailure.notTeam || InviteFailure.unknown => l10n.authFailureUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    if (_mentorName != null) {
      return _buildPreview(l10n, theme);
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LabeledField(
            label: l10n.inviteCodeLabel,
            child: TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
              decoration: const InputDecoration(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _normalised == null || _busy ? null : _preview,
            child: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.inviteContinue),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview(AppLocalizations l10n, ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.inviteShareWith(_mentorName!),
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
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _items.add(ShareItem.activityTargets);
                    } else {
                      _items.remove(ShareItem.activityTargets);
                    }
                  });
                },
              ),
              SwitchListTile(
                title: Text(l10n.shareItemProgress),
                value: _items.contains(ShareItem.progress),
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _items.add(ShareItem.progress);
                    } else {
                      _items.remove(ShareItem.progress);
                    }
                  });
                },
              ),
              SwitchListTile(
                title: Text(l10n.shareItemAboutMe),
                value: _items.contains(ShareItem.aboutMe),
                onChanged: (value) {
                  setState(() {
                    if (value) {
                      _items.add(ShareItem.aboutMe);
                    } else {
                      _items.remove(ShareItem.aboutMe);
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SubmitButton(
            label: l10n.inviteAccept,
            onPressed: _accept,
            busy: _busy,
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
