import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The summary time as the device shows times: "7:00 PM", "19:00".
String formatSummaryTime(BuildContext context, NotificationSettings settings) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: settings.hour, minute: settings.minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// Settings → Notifications, as it reads: the switch, time, days and time
/// zone. Every change goes to [onChanged] at once; there is no Save.
class NotificationSettingsForm extends StatelessWidget {
  const NotificationSettingsForm({
    required this.settings,
    required this.onChanged,
    this.onEnable,
    this.onAllow,
    this.phone = true,
    this.allowed,
    this.failure,
    super.key,
  });

  final NotificationSettings settings;
  final ValueChanged<NotificationSettings> onChanged;

  /// Turning the switch on, when it needs more than a save (the OS prompt).
  final VoidCallback? onEnable;

  /// The warning's button: asks the OS again. Once the OS stops prompting,
  /// the warning stays as the hint to the phone's settings.
  final VoidCallback? onAllow;

  /// Push reaches this device. False on the web: the settings still apply
  /// to the phones.
  final bool phone;

  /// What the OS allows; false shows the warning while the summary is on.
  final bool? allowed;

  final PeopleFailure? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = settings.enabled;
    final error = failure;
    final muted = AppTypography.bodySmall.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days = weekdayOrder(
      MaterialLocalizations.of(context).firstDayOfWeekIndex,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          FormError(peopleFailureCopy(l10n, error)),
          const SizedBox(height: AppSpacing.md),
        ],
        SettingsGroup(
          children: [
            SwitchListTile(
              title: Text(l10n.notificationsSummary),
              subtitle: Text(l10n.notificationsSummaryBody),
              value: on,
              onChanged: (value) => value && onEnable != null
                  ? onEnable!()
                  : onChanged(settings.copyWith(enabled: value)),
            ),
          ],
        ),
        if (on && allowed == false) ...[
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.ms),
            decoration: BoxDecoration(
              color: LoomiaColors.of(context).warningContainer,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.xs,
              children: [
                Text(
                  l10n.notificationsPermissionOff,
                  style: AppTypography.bodySmall.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                if (onAllow != null)
                  TextButton(
                    onPressed: onAllow,
                    child: Text(l10n.notificationsAllow),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        SettingsGroup(
          children: [
            ListTile(
              enabled: on,
              title: Text(l10n.notificationsTime),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.xs,
                children: [
                  Text(formatSummaryTime(context, settings)),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              onTap: () async {
                final picked = await pickTime(
                  context,
                  initial: TimeOfDay(
                    hour: settings.hour,
                    minute: settings.minute,
                  ),
                );
                if (picked == null) return;
                onChanged(
                  settings.copyWith(hour: picked.hour, minute: picked.minute),
                );
              },
            ),
            // The group's column centres what doesn't fill it.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.ms,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.sm,
                children: [
                  Text(
                    l10n.notificationsDays,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: on ? scheme.onSurface : theme.disabledColor,
                    ),
                  ),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final day in days)
                        FilterChip(
                          key: ValueKey('day-$day'),
                          // The theme hides it for filters elsewhere; here it
                          // is what tells a chosen day apart (Figma).
                          showCheckmark: true,
                          // 2024-01-01 is a Monday: day d is the d-th.
                          label: Text(
                            DateFormat.E(locale).format(DateTime(2024, 1, day)),
                          ),
                          selected: settings.days.contains(day),
                          onSelected: on
                              ? (_) => onChanged(
                                  settings.copyWith(
                                    days: toggleDay(settings.days, day),
                                  ),
                                )
                              : null,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.xs,
            children: [
              Text(
                l10n.notificationsTimeZone(settings.timeZone),
                style: AppTypography.bodySmall.copyWith(
                  color: scheme.onSurface,
                ),
              ),
              Text(l10n.notificationsLocalTime, style: muted),
              if (!phone) Text(l10n.notificationsPhoneOnly, style: muted),
            ],
          ),
        ),
      ],
    );
  }
}
