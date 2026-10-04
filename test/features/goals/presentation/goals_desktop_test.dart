import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
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

  testWidgets('desktop: dashboard left, orders and past months right', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
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
            onLogOrder: () {},
            onOrders: () => fail('no sheet on desktop'),
            onRitual: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tiles = tester.getTopLeft(find.text('NEW PROSPECTS')).dx;
    expect(
      tester.getTopLeft(find.text('ORDERS IN SEPTEMBER')).dx,
      greaterThan(tiles + 600),
    );
    expect(find.text('Order · 100 PV'), findsOneWidget);
    await tester.tap(find.text('Own volume'));
    await tester.pumpAndSettle();
  });
}
