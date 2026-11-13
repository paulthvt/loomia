import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/app/shell/create_action.dart';
import 'package:loomia/app/shell/floating_nav_bar.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// The phone's floating bar and the wide-screen sidebar on Today, for `flutter widget-preview start`.
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

@Preview(group: 'Shell', name: 'Sidebar — desktop', size: Size(264, 900))
Widget sidebarDesktopLight() => _sidebar(expanded: true);

@Preview(group: 'Shell', name: 'Sidebar — rail', size: Size(104, 900))
Widget sidebarRailLight() => _sidebar(expanded: false);

Widget _sidebar({required bool expanded}) => ProviderScope(
  overrides: [
    accountProvider.overrideWithValue(
      const Account(firstName: 'Pauline', email: 'p@example.com'),
    ),
  ],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    home: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [AppSidebar(location: Routes.today, expanded: expanded)],
    ),
  ),
);
