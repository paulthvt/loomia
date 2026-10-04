import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/close_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_goals_repository.dart';

void main() {
  final september = DateTime(2026, 9);
  final october = DateTime(2026, 10);
  late FakeGoalsRepository goals;
  late int done;

  Future<void> open(WidgetTester tester, DateTime day) async {
    done = 0;
    final auth = FakeAuthRepository()
      ..session = true
      ..account = const Account(
        firstName: 'Pauline',
        email: 'p@example.com',
        businessModel: BusinessModel.doterra,
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
          home: ClosePage(day: day, onDone: () => done++),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledField, label),
    matching: find.byType(TextFormField),
  );

  testWidgets('close September, then plan October', (tester) async {
    goals = FakeGoalsRepository(
      plans: [MonthPlan(month: september, ownVolumeTarget: 2800)],
      progressValue: const Progress(
        ownVolume: 2650,
        prospects: 7,
        customers: 5,
        teamMembers: 1,
        loyalty: 2,
      ),
      forecastValue: 3,
    );
    await open(tester, DateTime(2026, 9, 29));

    expect(find.text('How did September go?'), findsOneWidget);
    await tester.enterText(field('OV'), '5000');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final closed = goals.store.singleWhere((plan) => plan.month == september);
    expect(closed.closed, isTrue);
    expect(closed.teamVolumeActual, 5000);
    expect(find.text('STEP 2 OF 2'), findsOneWidget);
    expect(find.text('What are you aiming for in October?'), findsOneWidget);
    // Starts from the month just closed.
    expect(
      tester.widget<TextFormField>(field('Own volume (PV)')).controller!.text,
      '2650',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(goals.store.where((plan) => plan.month == october), hasLength(1));
    expect(done, 1);
    // Leaving: the page doesn't reload into "Nothing to close" on its way out.
    await tester.pumpAndSettle();
    expect(find.text('Nothing to close or plan right now.'), findsNothing);
  });

  testWidgets('closed, next not planned: straight to the plan', (tester) async {
    goals = FakeGoalsRepository(
      plans: [MonthPlan(month: september, closedAt: DateTime(2026, 9, 30))],
    );
    await open(tester, DateTime(2026, 9, 30));

    expect(find.text('What are you aiming for in October?'), findsOneWidget);
    expect(find.textContaining('STEP'), findsNothing);
    expect(goals.calls, isNot(contains('progress(2026-09)')));
  });

  testWidgets('nothing left: says so and goes back', (tester) async {
    goals = FakeGoalsRepository();
    await open(tester, DateTime(2026, 9, 15));

    expect(find.text('Nothing to close or plan right now.'), findsOneWidget);
    await tester.tap(find.text('Back to Goals'));
    expect(done, 1);
  });

  testWidgets('a failed close stays on step 1', (tester) async {
    goals = FakeGoalsRepository(
      plans: [MonthPlan(month: september, ownVolumeTarget: 2800)],
    );
    await open(tester, DateTime(2026, 9, 29));
    goals.failWith = PeopleFailure.network;

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('How did September go?'), findsOneWidget);
    expect(find.byType(FormError), findsOneWidget);
    expect(goals.store.single.closed, isFalse);
  });
}
