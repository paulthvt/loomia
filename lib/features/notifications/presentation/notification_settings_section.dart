import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/ui/load_failed.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/notifications/data/push.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:loomia/features/notifications/presentation/notification_settings_form.dart';
import 'package:loomia/features/notifications/presentation/notifications_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Settings → Notifications: loads and saves the daily summary, asks the OS
/// when it is turned on, and says when the OS refuses. Back from the phone's
/// settings, it looks again.
class NotificationSettingsSection extends ConsumerStatefulWidget {
  const NotificationSettingsSection({super.key});

  @override
  ConsumerState<NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends ConsumerState<NotificationSettingsSection> {
  bool? _allowed;
  PeopleFailure? _failure;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _check);
    _check();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final allowed = await ref.read(pushProvider).allowed();
    if (mounted) setState(() => _allowed = allowed);
  }

  Future<void> _save(NotificationSettings next) async {
    final controller = ref.read(
      notificationSettingsProvider(ref.read(accountProvider)?.email).notifier,
    );
    setState(() => _failure = null);
    try {
      await controller.save(next);
    } on PeopleFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    }
  }

  /// On even when the OS says no: the warning says where to fix it.
  Future<void> _enable(NotificationSettings settings) async {
    final push = ref.read(pushProvider);
    final save = _save(settings.copyWith(enabled: true));
    final allowed = await push.ask();
    if (mounted) setState(() => _allowed = allowed);
    await save;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final owner = ref.watch(accountProvider)?.email;
    final provider = notificationSettingsProvider(owner);
    final phone = ref.watch(pushAvailableProvider).value ?? false;
    // ponytail: UTC when the device's zone can't be read; add a zone picker
    // if that is ever seen.
    final zone = ref.watch(deviceTimeZoneProvider).value ?? 'UTC';

    return switch (ref.watch(provider)) {
      AsyncData(:final value) => NotificationSettingsForm(
        settings: value ?? NotificationSettings(timeZone: zone),
        phone: phone,
        allowed: _allowed,
        failure: _failure,
        onChanged: _save,
        onEnable: phone
            ? () => _enable(value ?? NotificationSettings(timeZone: zone))
            : null,
      ),
      AsyncError(:final error) => LoadFailed(
        offline: error == PeopleFailure.network,
        title: l10n.notificationsLoadFailed,
        onRetry: () => ref.invalidate(provider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}
