import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/core/ui/hero_panel.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/fake_auth_repository.dart';
import '../../contacts/fake_activity_repository.dart';

void main() {
  final september = DateTime(2026, 9);
  final plan = MonthPlan(
    month: september,
    ownVolumeTarget: 2800,
    prospectsTarget: 8,
  );

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = FakeAuthRepository()
      ..session = true
      ..account = const Account(
        firstName: 'Pauline',
        email: 'p@example.com',
        businessModel: BusinessModel.doterra,
      );
    addTearDown(auth.dispose);
    final activities = FakeActivityRepository([
      Activity(
        id: 'o1',
        personId: null,
        kind: ActivityKind.order,
        happenedOn: DateTime(2026, 9, 12),
        amount: 100,
        createdAt: DateTime.utc(2026, 9, 12, 12),
      ),
    ]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          activityRepositoryProvider.overrideWithValue(activities),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: GoalsView(
            month: AsyncData((
              month: september,
              plan: plan,
              progress: const Progress(
                ownVolume: 1840,
                prospects: 5,
                customers: 4,
                teamMembers: 1,
                loyalty: 2,
              ),
              forecast: 0,
              plans: [plan],
            )),
            today: DateTime(2026, 9, 19),
            model: BusinessModel.doterra,
            onPlan: () {},
            onRetry: () {},
            onRefresh: () async {},
            onOrders: () => fail('no sheet on desktop'),
            onRitual: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop: dashboard left, orders and past months right', (
    tester,
  ) async {
    await pump(tester);

    final tiles = tester.getTopLeft(find.text('NEW PROSPECTS')).dx;
    expect(
      tester.getTopLeft(find.text('Orders in September')).dx,
      greaterThan(tiles + 600),
    );
    expect(find.text('Order · 100 PV'), findsOneWidget);
    await tester.tap(find.text('OWN VOLUME'));
    await tester.pumpAndSettle();
  });

  testWidgets('desktop: the band carries the volume, no white card', (
    tester,
  ) async {
    await pump(tester);

    Finder inBand(Finder finder) =>
        find.descendant(of: find.byType(HeroPanel), matching: finder);
    expect(find.byType(HeroCard), findsNothing);
    expect(
      inBand(find.textContaining('1,840', findRichText: true)),
      findsOneWidget,
    );
    expect(
      inBand(find.text('66% of what you planned · On pace')),
      findsOneWidget,
    );
    expect(
      inBand(find.text('At this pace you finish the month at about 2,905 PV.')),
      findsOneWidget,
    );
    expect(
      inBand(find.widgetWithText(FilledButton, 'Change the plan')),
      findsOneWidget,
    );
    expect(
      tester.widget<LoomiaProgressBar>(find.byType(LoomiaProgressBar)).tone,
      ProgressTone.onHero,
    );
  });

  testWidgets('desktop: the four tiles share one row', (tester) async {
    await pump(tester);

    final tops = {
      for (final label in [
        'NEW PROSPECTS',
        'NEW CUSTOMERS',
        'NEW TEAM MEMBERS',
        'LRPS',
      ])
        tester.getTopLeft(find.text(label)).dy,
    };
    expect(tops, hasLength(1));
  });

  testWidgets('desktop: a very wide window does not stretch the page', (
    tester,
  ) async {
    await pump(tester, size: const Size(2000, 900));

    expect(
      tester.getSize(find.byType(HeroPanel)).width,
      lessThanOrEqualTo(Breakpoints.maxContentWidth),
    );
    expect(
      tester.getTopRight(find.text('Orders in September')).dx,
      lessThanOrEqualTo(Breakpoints.maxContentWidth + 2 * AppSpacing.xxl),
    );
  });

  testWidgets('desktop at 1200: the band wraps without overflow', (
    tester,
  ) async {
    await pump(tester, size: const Size(1200, 800));

    expect(tester.takeException(), isNull);
    expect(find.text('Change the plan'), findsOneWidget);
  });
}
