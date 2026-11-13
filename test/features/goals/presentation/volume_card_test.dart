import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/hero_panel.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/volume_card.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../../load_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('French, text at 130%: the pace wraps under the chip, whole', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final september = DateTime(2026, 9);
    final plan = MonthPlan(month: september, ownVolumeTarget: 500);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(
          body: Padding(
            // The hero's own inset around its card.
            padding: const EdgeInsets.all(20),
            child: HeroCard(
              child: OwnVolumeHero(
                month: (
                  month: september,
                  plan: plan,
                  progress: const Progress(
                    ownVolume: 150,
                    prospects: 0,
                    customers: 0,
                    teamMembers: 0,
                    loyalty: 0,
                  ),
                  forecast: 0,
                  plans: [plan],
                ),
                today: DateTime(2026, 9, 13),
                model: BusinessModel.doterra,
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final pace = find.text('Un peu en dessous du rythme');
    expect(pace, findsOneWidget);
    final card = tester.getRect(find.byType(HeroCard));
    final shown = tester.getRect(pace);
    expect(shown.right, lessThanOrEqualTo(card.right));
    // Under the chip, not beside it.
    expect(
      shown.top,
      greaterThanOrEqualTo(tester.getRect(find.byType(HeroEyebrow)).bottom),
    );
  });
}
