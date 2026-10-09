import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/app.dart';
import 'package:loomia/core/photos/photo_picker.dart';
import 'package:loomia/core/photos/photo_repository.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/data/phone_contacts_repository.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/workflows/data/event_workflow_repository.dart';
import 'package:loomia/features/workflows/data/workflow_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../core/photos/fake_photo_picker.dart';
import '../core/photos/fake_photo_repository.dart';
import '../features/auth/fake_auth_repository.dart';
import '../features/calendar/fake_event_repository.dart';
import '../features/contacts/fake_activity_repository.dart';
import '../features/contacts/fake_people_repository.dart';
import '../features/contacts/fake_phone_contacts_repository.dart';
import '../features/goals/fake_goals_repository.dart';
import '../features/workflows/fake_event_workflow_repository.dart';
import '../features/workflows/fake_workflow_repository.dart';

/// The whole app, signed in as Pauline unless [auth] says otherwise, at [size]
/// logical pixels times [pixelRatio]. Returns the container so a
/// test can drive `routerProvider` the way a URL would. With [settle] false it
/// pumps one frame, for a load gated on purpose.
Future<ProviderContainer> pumpLoomia(
  WidgetTester tester, {
  required Size size,
  double pixelRatio = 1,
  FakePeopleRepository? people,
  FakeActivityRepository? activities,
  FakeWorkflowRepository? workflows,
  FakeEventWorkflowRepository? eventWorkflows,
  FakeGoalsRepository? goals,
  FakeEventRepository? events,
  FakePhoneContactsRepository? phoneContacts,
  FakeAuthRepository? auth,
  FakePhotoRepository? photos,
  FakePhotoPicker? picker,
  bool settle = true,
}) async {
  tester.view.physicalSize = size * pixelRatio;
  tester.view.devicePixelRatio = pixelRatio;
  addTearDown(tester.view.reset);
  auth ??= FakeAuthRepository()
    ..session = true
    ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        peopleRepositoryProvider.overrideWithValue(
          people ?? FakePeopleRepository(),
        ),
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
        goalsRepositoryProvider.overrideWithValue(
          goals ?? FakeGoalsRepository(),
        ),
        eventRepositoryProvider.overrideWithValue(
          events ?? FakeEventRepository(),
        ),
        phoneContactsRepositoryProvider.overrideWithValue(
          phoneContacts ?? FakePhoneContactsRepository(),
        ),
        photoRepositoryProvider.overrideWithValue(
          photos ?? FakePhotoRepository(),
        ),
        photoPickerProvider.overrideWithValue(picker ?? FakePhotoPicker()),
      ],
      child: const LoomiaApp(),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return ProviderScope.containerOf(tester.element(find.byType(LoomiaApp)));
}
