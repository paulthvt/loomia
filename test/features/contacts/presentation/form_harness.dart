import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/data/tag_repository.dart';
import 'package:loomia/features/contacts/presentation/people_controller.dart';
import 'package:loomia/features/workflows/data/event_workflow_repository.dart';
import 'package:loomia/features/workflows/data/workflow_repository.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/fake_auth_repository.dart';
import '../../workflows/fake_event_workflow_repository.dart';
import '../../workflows/fake_workflow_repository.dart';
import '../fake_activity_repository.dart';
import '../fake_people_repository.dart';
import '../fake_tag_repository.dart';

/// Pumps a screen with one "Open" button that runs [open], with the book
/// already loaded from [people]. Returns what [open] resolved to via [result].
Future<void> pumpFormHarness(
  WidgetTester tester, {
  required FakePeopleRepository people,
  FakeTagRepository? tags,
  FakeActivityRepository? activities,
  FakeWorkflowRepository? workflows,
  FakeEventWorkflowRepository? eventWorkflows,
  Account account = const Account(firstName: 'Pauline', email: 'p@example.com'),
  required Future<Object?> Function(BuildContext context) open,
  required void Function(Object? value) result,
}) async {
  final auth = FakeAuthRepository()
    ..session = true
    ..account = account;
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        peopleRepositoryProvider.overrideWithValue(people),
        tagRepositoryProvider.overrideWithValue(tags ?? FakeTagRepository()),
        activityRepositoryProvider.overrideWithValue(
          activities ?? FakeActivityRepository(),
        ),
        workflowRepositoryProvider.overrideWithValue(
          workflows ?? FakeWorkflowRepository(FakeWorkflowRepository.samples()),
        ),
        eventWorkflowRepositoryProvider.overrideWithValue(
          eventWorkflows ??
              FakeEventWorkflowRepository(
                FakeEventWorkflowRepository.samples(),
              ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Consumer(
          builder: (context, ref, _) {
            // Loaded, as it is when the list opens the form.
            ref.watch(peopleProvider(ref.watch(accountProvider)?.email));
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async => result(await open(context)),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
