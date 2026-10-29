import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/onboarding/presentation/first_run_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Every first-run step, for `flutter widget-preview start`. Nothing is
/// tapped, so the repository is never read. Nothing in the app imports this
/// file.
@Preview(group: 'First run', name: 'Name — light', size: Size(390, 844))
Widget firstRunNameLight() =>
    _app(FirstRunNameStep(initial: '', onSaved: (_) {}));

@Preview(group: 'First run', name: 'Company — light', size: Size(390, 844))
Widget firstRunCompanyLight() => _app(FirstRunCompanyStep(onChosen: () {}));

@Preview(group: 'First run', name: 'People — light', size: Size(390, 844))
Widget firstRunPeopleLight() => _app(FirstRunPeopleStep(onBack: () {}));

Widget _app(Widget step) {
  return ProviderScope(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      // The preview is its own app: without the delegates, any component that
      // reads AppLocalizations throws here.
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: step,
    ),
  );
}
