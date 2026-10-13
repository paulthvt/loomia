import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/launch_splash.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Application root: wires router + theme. Keep this widget free of any
/// feature logic.
class LoomiaApp extends ConsumerWidget {
  const LoomiaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(accountProvider.select((a) => a?.locale));
    final appearance = ref.watch(
      accountProvider.select((a) => a?.appearance ?? Appearance.system),
    );
    return MaterialApp.router(
      // A product name is not translated, so there is no appTitle key.
      title: 'Loomia',
      debugShowCheckedModeBanner: false,
      // Generated from the ARB files present, so a new locale needs no edit here.
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The user's choice from Settings; null follows the system.
      locale: locale == null ? null : Locale(locale),
      routerConfig: ref.watch(routerProvider),
      // Built once for the app's lifetime, so it plays on cold start only.
      // The region is the status bar default for screens without an AppBar
      // (Today); without it the splash's light icons outlive the splash.
      builder: (context, child) => AnnotatedRegion(
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: LaunchSplash(child: child!),
      ),
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (appearance) {
        Appearance.system => ThemeMode.system,
        Appearance.light => ThemeMode.light,
        Appearance.dark => ThemeMode.dark,
      },
    );
  }
}
