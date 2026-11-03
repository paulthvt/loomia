import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/notifications/data/push.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:loomia/features/notifications/presentation/notification_settings_form.dart';
import 'package:loomia/features/notifications/presentation/notifications_controller.dart';
import 'package:loomia/features/notifications/presentation/push_bell.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The month-end push offered on the plan step, right after the user has
/// planned [month] (#148). Only on a phone with push, once the settings have
/// loaded. On until they have chosen (#412), then as they chose, here or in
/// Settings: the switch only says what is wanted, and the form's Save is
/// what applies it, through [RitualReminderState.apply].
class RitualReminder extends ConsumerStatefulWidget {
  const RitualReminder({required this.month, super.key});

  final DateTime month;

  @override
  ConsumerState<RitualReminder> createState() => RitualReminderState();
}

class RitualReminderState extends ConsumerState<RitualReminder> {
  /// What the switch says once touched.
  bool? _wanted;

  /// Untouched: what they chose, or on while they never have.
  bool _on(NotificationSettings settings) =>
      _wanted ?? (settings.ritualChosen ? settings.ritual : true);

  /// What the switch was last drawn from; null while it isn't offered.
  NotificationSettings? _shown;

  /// Once the plan is saved: the push as the switch says. On asks the OS
  /// first; refused, nothing is saved, as there is no warning here to
  /// explain an "on" that does nothing. Never throws: the plan is saved, so
  /// a failure only says so.
  Future<void> apply() async {
    final settings = _shown;
    if (settings == null) return;
    final on = _on(settings);
    // Saving the plan with the switch as shown is a choice too, off
    // included: next month it opens as they left it.
    if (settings.ritual == on && settings.ritualChosen) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final controller = ref.read(
      notificationSettingsProvider(ref.read(accountProvider)?.email).notifier,
    );
    if (on && !await ref.read(pushProvider).ask()) return;
    try {
      await controller.save(settings.copyWith(ritual: on, ritualChosen: true));
    } on PeopleFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _shown = null;
    final owner = ref.watch(accountProvider)?.email;
    if (owner == null || ref.watch(pushAvailableProvider).value != true) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(notificationSettingsProvider(owner));
    if (!state.hasValue) return const SizedBox.shrink();
    // With no settings row yet, one is made with the summary off.
    // ponytail: UTC when the zone can't be read, as Today's card does.
    final settings = _shown =
        state.value ??
        NotificationSettings(
          timeZone: ref.watch(deviceTimeZoneProvider).value ?? 'UTC',
        );
    return RitualReminderSwitch(
      month: widget.month,
      time: formatSummaryTime(context, settings),
      value: _on(settings),
      onChanged: (on) => setState(() => _wanted = on),
    );
  }
}

/// "Remind me to review October", as it reads; no providers, for previews.
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
          secondary: pushBell(on: value),
          title: Text(l10n.planReviewReminder(month)),
          subtitle: Text(
            l10n.planReviewReminderBody(
              month,
              time,
              DateTime(month.year, month.month + 1),
            ),
          ),
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
