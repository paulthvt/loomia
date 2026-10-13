import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/notifications/data/push.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:loomia/features/notifications/presentation/notification_settings_form.dart';
import 'package:loomia/features/notifications/presentation/notifications_controller.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The month-end push offered on the plan step, right after the user has
/// planned [month] (#148). Only on a phone with push, once the settings have
/// loaded. Saves at once, apart from the plan. On asks the OS first; refused,
/// nothing is saved, as there is no warning here to explain an "on" that does
/// nothing. With no settings row yet, one is made with the summary off.
class RitualReminder extends ConsumerWidget {
  const RitualReminder({required this.month, super.key});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(accountProvider)?.email;
    if (owner == null || ref.watch(pushAvailableProvider).value != true) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(notificationSettingsProvider(owner));
    if (!state.hasValue) return const SizedBox.shrink();
    // ponytail: UTC when the zone can't be read, as Today's card does.
    final settings =
        state.value ??
        NotificationSettings(
          timeZone: ref.watch(deviceTimeZoneProvider).value ?? 'UTC',
        );
    return RitualReminderSwitch(
      month: month,
      time: formatSummaryTime(context, settings),
      value: settings.ritual,
      onChanged: (on) => unawaited(_turn(context, ref, owner, settings, on)),
    );
  }

  Future<void> _turn(
    BuildContext context,
    WidgetRef ref,
    String owner,
    NotificationSettings settings,
    bool on,
  ) async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(notificationSettingsProvider(owner).notifier);
    if (on && !await ref.read(pushProvider).ask()) return;
    try {
      await controller.save(settings.copyWith(ritual: on));
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }
}

/// "Remind me when October ends", as it reads; no providers, for previews.
class RitualReminderSwitch extends StatelessWidget {
  const RitualReminderSwitch({
    required this.month,
    required this.time,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final DateTime month;

  /// The summary time, formatted for the device.
  final String time;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SettingsGroup(
      children: [
        SwitchListTile(
          title: Text(l10n.planReminder(month)),
          subtitle: Text(l10n.planReminderBody(time)),
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
