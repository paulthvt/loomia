import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/workflows/data/event_workflow_repository.dart';
import 'package:loomia/features/workflows/data/workflow_repository.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../auth/fake_auth_repository.dart';
import '../contacts/fake_activity_repository.dart';
import '../contacts/fake_people_repository.dart';
import '../workflows/fake_event_workflow_repository.dart';
import '../workflows/fake_workflow_repository.dart';
import 'fake_event_repository.dart';

/// A screen with one "Open" button that runs [open], signed in as Pauline
/// with [events]. What [open] resolves to goes to [result].
Future<void> pumpCalendarHarness(
  WidgetTester tester, {
  required FakeEventRepository events,
  FakeEventWorkflowRepository? eventWorkflows,
  required Future<Object?> Function(BuildContext context) open,
  required void Function(Object? value) result,
}) async {
  final auth = FakeAuthRepository()
    ..session = true
    ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
  addTearDown(auth.dispose);
  final workflows = FakeWorkflowRepository(FakeWorkflowRepository.samples());
  final eventWorkflowsRepo =
      eventWorkflows ??
      FakeEventWorkflowRepository(FakeEventWorkflowRepository.samples());
  final people = FakePeopleRepository();
  final activities = FakeActivityRepository();
  tester.view
    ..physicalSize = const Size(390, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        eventRepositoryProvider.overrideWithValue(events),
        eventWorkflowRepositoryProvider.overrideWithValue(eventWorkflowsRepo),
        workflowRepositoryProvider.overrideWithValue(workflows),
        peopleRepositoryProvider.overrideWithValue(people),
        activityRepositoryProvider.overrideWithValue(activities),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async => result(await open(context)),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
