import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/app/theme/app_typography.dart';
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

import '../../../load_fonts.dart';
import '../../auth/fake_auth_repository.dart';
import '../../contacts/fake_activity_repository.dart';

/// Where the shell's expanded sidebar ends (232 + its margins).
const double _sidebar = 264;

void main() {
  setUpAll(loadAppFonts);
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
          // The expanded sidebar's room, as in the shell.
          home: Row(
            children: [
              const SizedBox(width: _sidebar),
              Expanded(
                child: GoalsView(
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
            ],
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

  const labels = ['NEW PROSPECTS', 'NEW CUSTOMERS', 'NEW TEAM MEMBERS', 'LRPS'];

  testWidgets(
    'desktop at 1440: the four tiles in one row, labels on one line',
    (tester) async {
      await pump(tester);

      final line =
          AppTypography.overline.fontSize! * AppTypography.overline.height!;
      final tops = {
        for (final label in labels) tester.getTopLeft(find.text(label)).dy,
      };
      expect(tops, hasLength(1));
      for (final label in labels) {
        expect(tester.getSize(find.text(label)).height, line, reason: label);
      }
    },
  );

  testWidgets('desktop at 1200: two pairs of tiles, the band still a row', (
    tester,
  ) async {
    await pump(tester, size: const Size(1200, 800));

    expect(tester.takeException(), isNull);
    double top(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(top('NEW CUSTOMERS'), top('NEW PROSPECTS'));
    expect(top('NEW TEAM MEMBERS'), greaterThan(top('NEW PROSPECTS')));
    expect(top('LRPS'), top('NEW TEAM MEMBERS'));
    // The panel beside the volume, not under it.
    expect(
      tester.getTopLeft(find.text('Change the plan')).dx,
      greaterThan(
        tester.getTopRight(find.textContaining('1,840', findRichText: true)).dx,
      ),
    );
  });

  testWidgets('desktop at 2000: the page stops at its max width', (
    tester,
  ) async {
    await pump(tester, size: const Size(2000, 900));

    expect(
      tester.getSize(find.byType(HeroPanel)).width,
      Breakpoints.maxContentWidth,
    );
    expect(
      tester.getTopRight(find.text('Orders in September')).dx,
      lessThanOrEqualTo(
        _sidebar + AppSpacing.xxl + Breakpoints.maxContentWidth,
      ),
    );
  });

  testWidgets('desktop: the volume, the bar and the tiles are apart', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester);

    String label(Finder finder) => tester.getSemantics(finder).label;
    final volume = label(find.textContaining('1,840', findRichText: true));
    expect(volume, contains('OWN VOLUME'));
    expect(volume, contains('1,840 of 2,800 PV'));
    final bar = label(find.text('66% of what you planned · On pace'));
    for (final node in [volume, bar]) {
      expect(node, isNot(contains('NEW PROSPECTS')));
      expect(node, isNot(contains('Orders in September')));
    }
    // The figure once: the caption says it, the bar keeps quiet.
    expect(tester.getSemantics(find.byType(LinearProgressIndicator)).value, '');
    expect(
      tester.getSemantics(find.widgetWithText(FilledButton, 'Change the plan')),
      isSemantics(label: 'Change the plan', isButton: true),
    );
    semantics.dispose();
  });
}
