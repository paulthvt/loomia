import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:loomia/features/notifications/presentation/push_bell.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_group.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The summary time as the device shows times: "7:00 PM", "19:00".
String formatSummaryTime(BuildContext context, NotificationSettings settings) =>
    MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay(hour: settings.hour, minute: settings.minute),
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );

/// Settings → Notifications, as it reads: the two switches, then the time,
/// days and time zone they share. Every change goes to [onChanged] at once; there is no Save.
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

  /// Turning a switch on, when it needs more than a save (the OS prompt):
  /// the settings to save.
  final ValueChanged<NotificationSettings>? onEnable;

  /// The warning's button: asks the OS again. Once the OS stops prompting,
  /// the warning stays as the hint to the phone's settings.
  final VoidCallback? onAllow;

  /// Push reaches this device. False on the web: the settings still apply
  /// to the phones.
  final bool phone;

  /// What the OS allows; false shows the warning while a push is on.
  final bool? allowed;

  final PeopleFailure? failure;

  /// A day's circle.
  static const double _day = 40;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final on = settings.any;
    void turn(NotificationSettings next, {required bool value}) =>
        value && onEnable != null ? onEnable!(next) : onChanged(next);
    final error = failure;
    final muted = AppTypography.bodySmall.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final locale = Localizations.localeOf(context).toLanguageTag();
    final days = weekdayOrder(
      MaterialLocalizations.of(context).firstDayOfWeekIndex,
    );
    final action = on
        ? LoomiaColors.of(context).primaryText
        : theme.disabledColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          FormError(peopleFailureCopy(l10n, error)),
          const SizedBox(height: AppSpacing.md),
        ],
        _Group(
          children: [
            SwitchListTile(
              title: Text(l10n.notificationsSummary),
              subtitle: Text(l10n.notificationsSummaryBody),
              secondary: _Bell(on: settings.enabled),
              value: settings.enabled,
              onChanged: (value) =>
                  turn(settings.copyWith(enabled: value), value: value),
            ),
            SwitchListTile(
              title: Text(l10n.notificationsRitual),
              subtitle: Text(l10n.notificationsRitualBody),
              secondary: _Bell(on: settings.ritual),
              value: settings.ritual,
              onChanged: (value) => turn(
                settings.copyWith(ritual: value, ritualChosen: true),
                value: value,
              ),
            ),
            SwitchListTile(
              title: Text(l10n.notificationsTasks),
              subtitle: Text(l10n.notificationsTasksBody),
              secondary: _Bell(on: settings.tasks),
              value: settings.tasks,
              onChanged: (value) =>
                  turn(settings.copyWith(tasks: value), value: value),
            ),
            SwitchListTile(
              title: Text(l10n.notificationsSharing),
              subtitle: Text(l10n.notificationsSharingBody),
              secondary: _Bell(on: settings.sharing),
              value: settings.sharing,
              onChanged: (value) =>
                  turn(settings.copyWith(sharing: value), value: value),
            ),
          ],
        ),
        if (settings.pushes && allowed == false) ...[
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
        const SizedBox(height: AppSpacing.md),
        _Group(
          children: [
            ListTile(
              enabled: on,
              title: Text(l10n.notificationsTime),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: AppSpacing.xs,
                children: [
                  Text(
                    formatSummaryTime(context, settings),
                    style: AppTypography.labelLarge.copyWith(color: action),
                  ),
                  Icon(Icons.chevron_right_rounded, color: action),
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.sm,
                children: [
                  Text(
                    l10n.notificationsDays,
                    style: AppTypography.labelLarge.copyWith(
                      color: on ? scheme.onSurface : theme.disabledColor,
                    ),
                  ),
                  Theme(
                    data: AppTheme.dayChips(context),
                    // Full width, so spaceBetween spreads the days.
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final day in days)
                          FilterChip(
                            key: ValueKey('day-$day'),
                            // 2024-01-01 is a Monday: day d is the d-th.
                            label: SizedBox.square(
                              dimension: _day,
                              child: Center(
                                child: Text(
                                  DateFormat.EEEEE(locale)
                                      .format(DateTime(2024, 1, day)),
                                  // "T" twice, "S" twice: say the day.
                                  semanticsLabel: DateFormat.EEEE(locale)
                                      .format(DateTime(2024, 1, day)),
                                ),
                              ),
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

/// A group of the form's rows, their titles bold (Figma).
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SettingsGroup(
    children: [
      for (final child in children)
        ListTileTheme.merge(
          titleTextStyle: AppTypography.labelLarge.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
          subtitleTextStyle: AppTypography.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          child: child,
        ),
    ],
  );
}

/// The push's bell in a circle: tinted when on, quiet when off.
class _Bell extends StatelessWidget {
  const _Bell({required this.on});

  final bool on;

  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        // surfaceContainer is the card's own colour in dark mode.
        color: on ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: _size,
        child: IconTheme.merge(
          data: IconThemeData(
            color: on
                ? LoomiaColors.of(context).primaryText
                : scheme.onSurfaceVariant,
            size: 20,
          ),
          child: pushBell(on: on),
        ),
      ),
    );
  }
}
