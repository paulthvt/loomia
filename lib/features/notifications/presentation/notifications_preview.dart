import 'package:flutter/widget_previews.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:loomia/features/notifications/presentation/notification_settings_form.dart';
import 'package:loomia/features/notifications/presentation/ritual_reminder.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_scroll.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Settings → Notifications, as in the Figma (#270). Nothing in the app
/// imports this file.
@Preview(group: 'Notifications', name: 'Mobile — light', size: Size(390, 844))
Widget notificationsMobileLight() => _app(
  AppTheme.light,
  const NotificationSettings(enabled: true, timeZone: 'Europe/Paris'),
  allowed: true,
);

@Preview(group: 'Notifications', name: 'Off — dark', size: Size(390, 844))
Widget notificationsOffDark() => _app(
  AppTheme.dark,
  const NotificationSettings(timeZone: 'Europe/Paris'),
  allowed: true,
);

@Preview(
  group: 'Notifications',
  name: 'Permission off — light',
  size: Size(390, 844),
)
Widget notificationsPermissionOffLight() => _app(
  AppTheme.light,
  const NotificationSettings(enabled: true, timeZone: 'Europe/Paris'),
  allowed: false,
);

/// The month-end push alone (#148).
@Preview(
  group: 'Notifications',
  name: 'Month-end review — light',
  size: Size(390, 844),
)
Widget notificationsRitualLight() => _app(
  AppTheme.light,
  const NotificationSettings(ritual: true, timeZone: 'Europe/Paris'),
  allowed: true,
);

/// Its offer on the plan step, above Save.
@Preview(
  group: 'Notifications',
  name: 'Plan reminder — light',
  size: Size(390, 200),
)
Widget notificationsPlanReminderLight() => MaterialApp(
  debugShowCheckedModeBanner: false,
  localizationsDelegates: localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.light,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      // Its own height, as in the plan step's list.
      child: Align(
        alignment: Alignment.topCenter,
        child: RitualReminderSwitch(
          month: DateTime(2026, 10),
          time: '7:00 PM',
          value: false,
          onChanged: (_) {},
        ),
      ),
    ),
  ),
);

Widget _app(
  ThemeData theme,
  NotificationSettings settings, {
  required bool allowed,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  localizationsDelegates: localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme,
  home: Builder(
    builder: (context) => Scaffold(
      appBar: AppBar(),
      body: SettingsScroll(
        title: AppLocalizations.of(context).settingsSectionNotifications,
        child: NotificationSettingsForm(
          settings: settings,
          allowed: allowed,
          onChanged: (_) {},
          onAllow: () {},
        ),
      ),
    ),
  ),
);
