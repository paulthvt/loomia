import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/notifications/data/push.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:loomia/features/notifications/presentation/notifications_controller.dart';
import 'package:loomia/features/notifications/presentation/push_bell.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/invite_code.dart';
import 'package:loomia/features/sharing/presentation/contact_sharing_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showInviteSheet(
  BuildContext context, {
  required String personId,
  required String name,
}) async {
  await LoomiaDialog.show<void>(
    context,
    (_) => _InviteSheet(personId: personId, name: name),
  );
  if (context.mounted) {
    ProviderScope.containerOf(context)
        .invalidate(contactSharingProvider(personId));
  }
}

// The web app routes from the fragment (hash URL strategy), so the code
// rides after the #.
String _inviteLink(String code) =>
    'app.getloomia.app/#${Routes.inviteLocation(code)}';

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.personId, required this.name});

  final String personId;
  final String name;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  /// "Tell me when they accept" (#423, #439): on until switched off.
  bool _tellMe = true;
  bool _tellMeRefused = false;
  PeopleFailure? _tellMeFailure;

  Invite? _invite;
  bool _loading = true;
  bool _canceling = false;
  PeopleFailure? _failure;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final repo = ref.read(sharingRepositoryProvider);
      final existing = await repo.openInvite(widget.personId);
      if (existing != null) {
        if (mounted) {
          setState(() {
            _invite = existing;
            _loading = false;
          });
        }
        return;
      }

      final created = await repo.createInvite(widget.personId);
      if (mounted) {
        setState(() {
          _invite = created;
          _loading = false;
        });
      }
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failure = failure;
        });
      }
    }
  }

  /// On a phone, while the Sharing push is off.
  bool get _offerTellMe {
    final phone = ref.read(pushAvailableProvider).value ?? false;
    final settings = ref.read(notificationSettingsProvider(_owner));
    return phone && settings.hasValue && settings.value?.sharing != true;
  }

  String? get _owner => ref.read(accountProvider)?.email;

  /// Saved only once the phone allows it; refused, the switch goes off.
  Future<void> _turnOnSharingPush() async {
    setState(() {
      _tellMeRefused = false;
      _tellMeFailure = null;
    });
    final allowed = await ref.read(pushProvider).ask();
    if (!mounted) return;
    if (!allowed) {
      setState(() {
        _tellMe = false;
        _tellMeRefused = true;
      });
      return;
    }
    final zone = await ref.read(deviceTimeZoneProvider.future) ?? 'UTC';
    final provider = notificationSettingsProvider(_owner);
    final current = ref.read(provider).value;
    try {
      await ref
          .read(provider.notifier)
          .save(
            (current ?? NotificationSettings(timeZone: zone)).copyWith(
              sharing: true,
            ),
          );
    } on PeopleFailure catch (failure) {
      if (mounted) setState(() => _tellMeFailure = failure);
    }
  }

  Future<void> _copyLink() async {
    final invite = _invite;
    if (invite == null) return;

    await Clipboard.setData(
      ClipboardData(text: 'https://${_inviteLink(invite.code)}'),
    );
    if (_tellMe && _offerTellMe) unawaited(_turnOnSharingPush());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).inviteSheetLinkCopied),
        ),
      );
    }
  }

  Future<void> _cancel() async {
    setState(() {
      _canceling = true;
      _failure = null;
    });
    try {
      await ref.read(sharingRepositoryProvider).cancelInvite(widget.personId);
      if (mounted) {
        Navigator.pop(context);
      }
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _canceling = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final invite = _invite;
    final failure = _failure;

    if (_loading) {
      return LoomiaDialog(
        title: l10n.inviteSheetTitle(widget.name),
        actions: const [],
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (invite == null) {
      return LoomiaDialog(
        title: l10n.inviteSheetTitle(widget.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(onPressed: _loadInvite, child: Text(l10n.contactsRetry)),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.ms,
          children: [
            if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
          ],
        ),
      );
    }

    final code = formatCode(invite.code);
    final phone = ref.watch(pushAvailableProvider).value ?? false;
    final settings = ref.watch(
      notificationSettingsProvider(ref.watch(accountProvider)?.email),
    );
    final offerTellMe =
        phone && settings.hasValue && settings.value?.sharing != true;

    return LoomiaDialog(
      title: l10n.inviteSheetTitle(widget.name),
      actions: [
        TextButton(
          onPressed: _canceling ? null : _cancel,
          child: Text(l10n.inviteSheetCancelInvite),
        ),
        FilledButton(
          onPressed: _canceling ? null : _copyLink,
          child: Text(l10n.inviteSheetCopyLink),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.md,
        children: [
          if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
          Text(code, style: Theme.of(context).textTheme.displaySmall),
          Text(_inviteLink(invite.code)),
          Text(l10n.inviteSheetBody(widget.name)),
          if (offerTellMe)
            _TellMe(
              name: widget.name,
              wanted: _tellMe,
              onChanged: (value) => setState(() {
                _tellMe = value;
                _tellMeRefused = false;
              }),
              refused: _tellMeRefused,
              failure: _tellMeFailure,
            ),
        ],
      ),
    );
  }
}

/// The Sharing push, offered when it matters (#423): on a phone, while it is
/// off. On until they say otherwise (#439); Copy link is what turns it on,
/// through the phone's prompt. The setting itself lives in Settings →
/// Notifications.
class _TellMe extends StatelessWidget {
  const _TellMe({
    required this.name,
    required this.wanted,
    required this.onChanged,
    required this.refused,
    this.failure,
  });

  final String name;
  final bool wanted;
  final ValueChanged<bool> onChanged;
  final bool refused;
  final PeopleFailure? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = this.failure;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: pushBell(on: wanted),
          title: Text(l10n.inviteNotifyMe(name)),
          value: wanted,
          onChanged: onChanged,
        ),
        if (refused) Text(l10n.notificationsPermissionOff),
        if (failure != null) FormError(peopleFailureCopy(l10n, failure)),
      ],
    );
  }
}
