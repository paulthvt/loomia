import 'package:flutter/widget_previews.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/create_action.dart';
import 'package:loomia/app/shell/floating_nav_bar.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// The phone's floating bar on Today, for `flutter widget-preview start`.
/// Nothing in the app imports this file.
@Preview(group: 'Shell', name: 'Floating bar — light', size: Size(390, 120))
Widget navBarLight() => _bar(AppTheme.light);

@Preview(group: 'Shell', name: 'Floating bar — dark', size: Size(390, 120))
Widget navBarDark() => _bar(AppTheme.dark);

Widget _bar(ThemeData theme) => MaterialApp(
  debugShowCheckedModeBanner: false,
  localizationsDelegates: localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme,
  home: Scaffold(
    extendBody: true,
    body: const SizedBox.expand(),
    bottomNavigationBar: Builder(
      builder: (context) => FloatingNavBar(
        selected: 0,
        onSelect: (_) {},
        create: createActionFor(Routes.today, AppLocalizations.of(context)),
        onCreate: (_) {},
      ),
    ),
  ),
);
