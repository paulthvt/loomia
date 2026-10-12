import 'package:flutter/widget_previews.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/notifications/domain/notification_settings.dart';
import 'package:loomia/features/notifications/presentation/notification_settings_form.dart';
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
