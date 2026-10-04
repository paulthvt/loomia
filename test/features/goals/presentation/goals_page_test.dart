import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/goals/presentation/goals_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_goals_repository.dart';

final _today = DateTime(2026, 9, 19);
final _september = DateTime(2026, 9);

GoalsMonth month({
  MonthPlan? plan,
  Progress progress = noProgress,
  int forecast = 0,
  List<MonthPlan> past = const [],
}) => (
  month: _september,
  plan: plan,
  progress: progress,
  forecast: forecast,
  plans: [?plan, ...past],
);

var plans = 0;
var retries = 0;

/// [GoalsView] alone, on a fixed day, counting Plan and Try again taps.
Future<void> pumpGoals(
  WidgetTester tester,
  AsyncValue<GoalsMonth> value, {
  BusinessModel model = BusinessModel.doterra,
  DateTime? day,
}) {
  plans = 0;
  retries = 0;
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: GoalsView(
        month: value,
        today: day ?? _today,
        model: model,
        onPlan: () => plans++,
        onRetry: () => retries++,
        onRefresh: () async {},
      ),
    ),
  );
}

void main() {
  testWidgets('no plan: the question and Plan September', (tester) async {
    await pumpGoals(tester, AsyncData(month()));

    expect(find.text('11 DAYS LEFT IN SEPTEMBER'), findsOneWidget);
    expect(find.text('Goals'), findsOneWidget);
    expect(find.text('What are you aiming for this month?'), findsOneWidget);
    await tester.tap(find.text('Plan September'));
    expect(plans, 1);
  });

  testWidgets('loading: a spinner', (tester) async {
    await pumpGoals(tester, const AsyncLoading());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a failed load offers Try again', (tester) async {
    await pumpGoals(
      tester,
      const AsyncError(PeopleFailure.network, StackTrace.empty),
    );

    expect(find.text("Couldn't load your goals."), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
  });
}
