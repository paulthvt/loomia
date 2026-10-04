import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/close_form.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/goals/presentation/goals_page.dart';
import 'package:loomia/features/goals/presentation/plan_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Goals on September 19, as in the Figma frames, so the goldens never follow
/// the clock. Nothing in the app imports this file.
@Preview(group: 'Goals', name: 'Mobile — light', size: Size(390, 844))
Widget goalsMobileLight() => _goals(AppTheme.light, _month);

@Preview(group: 'Goals', name: 'Mobile — dark', size: Size(390, 844))
Widget goalsMobileDark() => _goals(AppTheme.dark, _month);

@Preview(group: 'Goals', name: 'Desktop — light', size: Size(1440, 900))
Widget goalsDesktopLight() => _goals(AppTheme.light, _month);

@Preview(group: 'Goals', name: 'Empty — light', size: Size(390, 844))
Widget goalsEmptyLight() => _goals(AppTheme.light, (
  month: _september,
  plan: null,
  progress: _progress,
  forecast: 0,
  plans: const [],
));

@Preview(group: 'Goals', name: 'Plan — light', size: Size(390, 844))
Widget goalsPlanLight() => _app(
  AppTheme.light,
  Scaffold(
    body: SafeArea(
      child: PlanForm(
        month: (
          month: DateTime(2026, 10),
          plan: null,
          progress: _progress,
          forecast: 3,
          plans: _past,
        ),
        model: BusinessModel.doterra,
        onSave: (_) async {},
        onSaved: () {},
      ),
    ),
  ),
);

@Preview(group: 'Goals', name: 'Plan — desktop', size: Size(1440, 900))
Widget goalsPlanDesktopLight() => goalsPlanLight();

@Preview(group: 'Goals', name: 'Close — light', size: Size(390, 844))
Widget goalsCloseLight() => _app(
  AppTheme.light,
  Scaffold(
    body: SafeArea(
      child: CloseForm(
        closing: (
          ritual: (close: _september, plan: DateTime(2026, 10), closes: true),
          closing: _month.plan,
          done: const Progress(
            ownVolume: 2650,
            prospects: 7,
            customers: 5,
            teamMembers: 2,
            loyalty: 3,
          ),
          forecast: 3,
          plans: _past,
        ),
        model: BusinessModel.doterra,
        onClose: ({teamVolume, level}) async {},
      ),
    ),
  ),
);

final _today = DateTime(2026, 9, 19);
final _september = DateTime(2026, 9);

const _progress = Progress(
  ownVolume: 1840,
  prospects: 5,
  customers: 4,
  teamMembers: 1,
  loyalty: 2,
);

final _past = [
  MonthPlan(
    month: DateTime(2026, 8),
    ownVolumeTarget: 2500,
    levelTarget: 'Elite',
    actual: const Progress(
      ownVolume: 2410,
      prospects: 6,
      customers: 5,
      teamMembers: 1,
      loyalty: 2,
    ),
    teamVolumeActual: 5600,
    levelActual: 'Elite',
    closedAt: DateTime(2026, 9),
  ),
  MonthPlan(
    month: DateTime(2026, 7),
    ownVolumeTarget: 2400,
    levelTarget: 'Elite',
    actual: const Progress(
      ownVolume: 2180,
      prospects: 8,
      customers: 4,
      teamMembers: 1,
      loyalty: 3,
    ),
    teamVolumeActual: 5200,
    levelActual: 'Executive',
    closedAt: DateTime(2026, 8),
  ),
];

final GoalsMonth _month = (
  month: _september,
  plan: MonthPlan(
    month: _september,
    ownVolumeTarget: 2800,
    teamVolumeTarget: 6000,
    levelTarget: 'Elite',
    prospectsTarget: 8,
    customersTarget: 6,
    teamMembersTarget: 2,
    loyaltyTarget: 3,
  ),
  progress: _progress,
  forecast: 1,
  plans: _past,
);

/// Desktop lists the month's orders, read through providers: the preview
/// gives them sample ones.
Widget _goals(ThemeData theme, GoalsMonth month) => ProviderScope(
  overrides: [
    accountProvider.overrideWithValue(
      const Account(
        firstName: 'Pauline',
        email: 'p@example.com',
        businessModel: BusinessModel.doterra,
      ),
    ),
    ordersProvider.overrideWith((ref, _) async => _orders),
  ],
  child: _app(
    theme,
    GoalsView(
      month: AsyncData(month),
      today: _today,
      model: BusinessModel.doterra,
      onPlan: () {},
      onRetry: () {},
      onRefresh: () async {},
      onLogOrder: () {},
      onOrders: () {},
      onRitual: () {},
    ),
  ),
);

final _orders = <MonthOrder>[
  (
    order: Activity(
      id: 'o1',
      personId: 'p1',
      kind: ActivityKind.order,
      happenedOn: DateTime(2026, 9, 18),
      amount: 100,
      createdAt: DateTime.utc(2026, 9, 18, 12),
    ),
    personName: 'Marie Dupont',
  ),
  (
    order: Activity(
      id: 'o2',
      personId: null,
      kind: ActivityKind.order,
      happenedOn: DateTime(2026, 9, 12),
      amount: 80,
      createdAt: DateTime.utc(2026, 9, 12, 12),
    ),
    personName: null,
  ),
];

Widget _app(ThemeData theme, Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  // The preview is its own app: without the delegates, any component that
  // reads AppLocalizations throws here.
  localizationsDelegates: localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: theme,
  home: home,
);
