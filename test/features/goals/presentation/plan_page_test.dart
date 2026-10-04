import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/goals/presentation/plan_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_goals_repository.dart';

void main() {
  final now = today();
  final thisMonth = DateTime(now.year, now.month);
  late FakeGoalsRepository goals;
  late int saved;

  Progress done(double volume, int prospects) => Progress(
    ownVolume: volume,
    prospects: prospects,
    customers: 0,
    teamMembers: 0,
    loyalty: 0,
  );

  MonthPlan closed(int monthsAgo, double volume, int prospects) => MonthPlan(
    month: DateTime(now.year, now.month - monthsAgo),
    actual: done(volume, prospects),
    closedAt: DateTime(now.year, now.month - monthsAgo + 1),
  );

  /// [PlanPage] over the fake, as dōTERRA unless [model] says otherwise.
  Future<void> open(
    WidgetTester tester, {
    BusinessModel model = BusinessModel.doterra,
  }) async {
    saved = 0;
    final auth = FakeAuthRepository()
      ..session = true
      ..account = Account(
        firstName: 'Pauline',
        email: 'p@example.com',
        businessModel: model,
      );
    addTearDown(auth.dispose);
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          goalsRepositoryProvider.overrideWithValue(goals),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PlanPage(onSaved: () => saved++),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledField, label),
    matching: find.byType(TextFormField),
  );

  String text(WidgetTester tester, String label) =>
      tester.widget<TextFormField>(field(label)).controller!.text;

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
  }

  testWidgets('the first time: empty fields, the forecast prefilled', (
    tester,
  ) async {
    goals = FakeGoalsRepository(forecastValue: 3);
    await open(tester);

    expect(find.textContaining('What are you aiming for in'), findsOneWidget);
    expect(
      find.text('Pick what you want to aim for. Leave any of them empty.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('3 customers reach their LRP step'),
      findsOneWidget,
    );
    expect(text(tester, 'LRPs'), '3');
    expect(text(tester, 'Own volume (PV)'), '');

    await tester.enterText(field('Own volume (PV)'), '2800');
    await tester.enterText(field('New prospects'), '8');
    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elite').last);
    await tester.pumpAndSettle();
    await save(tester);

    final plan = goals.store.single;
    expect(plan.month, thisMonth);
    expect(plan.ownVolumeTarget, 2800);
    expect(plan.prospectsTarget, 8);
    expect(plan.customersTarget, isNull);
    expect(plan.loyaltyTarget, 3);
    expect(plan.loyaltyForecast, 3);
    expect(plan.levelTarget, 'Elite');
    expect(saved, 1);
  });

  testWidgets('each number starts from the last 3 closed months', (
    tester,
  ) async {
    goals = FakeGoalsRepository(
      plans: [
        closed(1, 3000, 7),
        closed(2, 2600, 8),
        closed(3, 2200, 6),
        closed(4, 9000, 30),
      ],
    );
    await open(tester);

    expect(
      find.text(
        'Each number starts from your last 3 months. Change any of them, or leave one empty.',
      ),
      findsOneWidget,
    );
    expect(text(tester, 'Own volume (PV)'), '2600');
    expect(text(tester, 'New prospects'), '7');
    expect(find.text('Your last 3 months: about 2,600'), findsOneWidget);
  });

  testWidgets('a saved plan opens as saved and saves over itself', (
    tester,
  ) async {
    goals = FakeGoalsRepository(
      plans: [
        closed(1, 3000, 7),
        MonthPlan(month: thisMonth, ownVolumeTarget: 1500, loyaltyForecast: 2),
      ],
      forecastValue: 5,
    );
    await open(tester);

    expect(text(tester, 'Own volume (PV)'), '1500');
    expect(text(tester, 'New prospects'), '');
    await tester.enterText(field('Own volume (PV)'), '1750.5');
    await save(tester);

    final plans = goals.store.where((plan) => plan.month == thisMonth);
    expect(plans.single.ownVolumeTarget, 1750.5);
    // What was suggested the first time stays the record.
    expect(plans.single.loyaltyForecast, 2);
    // The tab reloads with the new numbers.
    expect(goals.calls.where((call) => call == 'plans()'), hasLength(2));
  });

  testWidgets('a bad number is refused', (tester) async {
    goals = FakeGoalsRepository();
    await open(tester);

    await tester.enterText(field('Own volume (PV)'), 'lots');
    await save(tester);

    expect(find.text('Use a number, or leave it empty.'), findsOneWidget);
    expect(goals.store, isEmpty);
  });

  testWidgets('a failed save keeps what was typed', (tester) async {
    goals = FakeGoalsRepository();
    await open(tester);
    goals.failWith = PeopleFailure.network;

    await tester.enterText(field('Own volume (PV)'), '2800');
    await save(tester);

    expect(text(tester, 'Own volume (PV)'), '2800');
    expect(saved, 0);
    expect(goals.store, isEmpty);
  });

  testWidgets('Other: a typed level, neutral words', (tester) async {
    goals = FakeGoalsRepository(forecastValue: 1);
    await open(tester, model: BusinessModel.other);

    expect(field('Own volume'), findsOneWidget);
    expect(field('Team volume'), findsOneWidget);
    expect(
      find.textContaining('1 customer reaches their loyalty step'),
      findsOneWidget,
    );
    await tester.enterText(field('Level'), ' Gold ');
    await save(tester);

    expect(goals.store.single.levelTarget, 'Gold');
    expect(find.textContaining('PV'), findsNothing);
  });

  testWidgets('going back while saving still saves and reloads', (
    tester,
  ) async {
    goals = FakeGoalsRepository();
    final auth = FakeAuthRepository()
      ..session = true
      ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(auth.dispose);
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        goalsRepositoryProvider.overrideWithValue(goals),
      ],
    );
    addTearDown(container.dispose);
    // Goals stays listened to, as the tab under the pushed page does.
    container.listen(goalsProvider('p@example.com'), (_, _) {});
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          localizationsDelegates: localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => PlanPage(onSaved: () {}),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    goals.gate = Completer<void>();
    await tester.tap(find.text('Save'));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    goals.gate!.complete();
    goals.gate = null;
    await tester.pumpAndSettle();

    expect(goals.store, hasLength(1));
    expect(goals.calls.where((call) => call == 'plans()'), hasLength(2));
  });

  testWidgets('desktop: the form is one centred column', (tester) async {
    goals = FakeGoalsRepository();
    await open(tester);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();

    final box = tester.getRect(field('Own volume (PV)'));
    expect(box.width, lessThanOrEqualTo(624));
    expect(box.center.dx, moreOrLessEquals(720, epsilon: 2));
  });
}
