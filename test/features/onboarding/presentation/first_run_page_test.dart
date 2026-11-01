import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/app.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/photos/photo_picker.dart';
import 'package:loomia/core/photos/photo_repository.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/auth/domain/auth_change.dart';
import 'package:loomia/features/auth/domain/auth_failure.dart';
import 'package:loomia/features/calendar/data/event_repository.dart';
import 'package:loomia/features/contacts/data/activity_repository.dart';
import 'package:loomia/features/contacts/data/people_repository.dart';
import 'package:loomia/features/contacts/data/phone_contacts_repository.dart';
import 'package:loomia/features/contacts/data/tag_repository.dart';
import 'package:loomia/features/contacts/presentation/contact_list.dart';
import 'package:loomia/features/contacts/presentation/import_contacts_page.dart';
import 'package:loomia/features/goals/data/goals_repository.dart';
import 'package:loomia/features/notifications/data/notifications_repository.dart';
import 'package:loomia/features/notifications/data/push.dart';
import 'package:loomia/features/notifications/presentation/notifications_controller.dart';
import 'package:loomia/features/onboarding/presentation/first_run_page.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';
import 'package:loomia/features/sharing/domain/shared_goals.dart';
import 'package:loomia/features/tasks/data/task_repository.dart';
import 'package:loomia/features/today/presentation/today_page.dart';
import 'package:loomia/features/workflows/data/event_workflow_repository.dart';
import 'package:loomia/features/workflows/data/workflow_repository.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../../../core/photos/fake_photo_picker.dart';
import '../../../core/photos/fake_photo_repository.dart';
import '../../auth/fake_auth_repository.dart';
import '../../calendar/fake_event_repository.dart';
import '../../contacts/fake_activity_repository.dart';
import '../../contacts/fake_people_repository.dart';
import '../../contacts/fake_phone_contacts_repository.dart';
import '../../contacts/fake_tag_repository.dart';
import '../../goals/fake_goals_repository.dart';
import '../../notifications/fake_notifications_repository.dart';
import '../../notifications/fake_push.dart';
import '../../sharing/fake_sharing_repository.dart';
import '../../tasks/fake_task_repository.dart';
import '../../workflows/fake_event_workflow_repository.dart';
import '../../workflows/fake_workflow_repository.dart';

const _phone = Size(390, 844);
const _question = 'Which company do you work with?';
const _people = 'Who do you already work with?';

FakeAuthRepository _newAccount() => FakeAuthRepository()
  ..session = true
  ..account = const Account(
    firstName: 'Pauline',
    email: 'p@example.com',
    onboarded: false,
  );

Future<void> _choose(WidgetTester tester, String company) async {
  await tester.tap(find.text(company));
  await tester.pumpAndSettle();
}

const _nameQuestion = 'What should we call you?';

/// An Apple sign-in: no name from anywhere.
FakeAuthRepository _nameless() => FakeAuthRepository()
  ..session = true
  ..account = const Account(
    firstName: '',
    email: 'x7k2@privaterelay.appleid.com',
    onboarded: false,
    needsName: true,
  );

Future<void> _continueWithName(WidgetTester tester, String name) async {
  await tester.enterText(find.byType(TextFormField), name);
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

void main() {
  group('the name step', () {
    testWidgets('an account without a name is asked for it first', (
      tester,
    ) async {
      await pumpLoomia(tester, size: _phone, auth: _nameless());

      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text(_nameQuestion), findsOneWidget);
      expect(
        find.text('Your first name, for your greeting on Today.'),
        findsOneWidget,
      );
      expect(find.text('First name'), findsOneWidget);
      expect(find.text(_question), findsNothing);
    });

    testWidgets('an account with a name starts at the company', (tester) async {
      await pumpLoomia(tester, size: _phone, auth: _newAccount());

      expect(find.text(_nameQuestion), findsNothing);
      expect(find.text('Welcome'), findsOneWidget);
    });

    testWidgets('an empty name is refused', (tester) async {
      final auth = _nameless();
      await pumpLoomia(tester, size: _phone, auth: auth);

      await _continueWithName(tester, '  ');

      expect(find.text('Enter your first name.'), findsOneWidget);
      expect(auth.calls, isEmpty);
      expect(find.text(_nameQuestion), findsOneWidget);
    });

    testWidgets('Continue saves the name and moves to the company', (
      tester,
    ) async {
      final auth = _nameless();
      await pumpLoomia(tester, size: _phone, auth: auth);

      await _continueWithName(tester, 'Pauline');

      expect(auth.calls, ['updateFirstName(Pauline)']);
      expect(auth.account!.firstName, 'Pauline');
      expect(find.text(_question), findsOneWidget);
      // Said once, on the name step.
      expect(find.text('Welcome'), findsNothing);
    });

    testWidgets('a failed save stays on the name', (tester) async {
      final auth = _nameless()..failWith = AuthFailure.network;
      await pumpLoomia(tester, size: _phone, auth: auth);

      await _continueWithName(tester, 'Pauline');

      expect(find.text(_nameQuestion), findsOneWidget);
      expect(
        find.text('We could not reach Loomia. Check your connection.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextFormField, 'Pauline'), findsOneWidget);
    });

    testWidgets('back from the company returns to the name, filled', (
      tester,
    ) async {
      final auth = _nameless();
      await pumpLoomia(tester, size: _phone, auth: auth);
      await _continueWithName(tester, 'Pauline');

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text(_nameQuestion), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Pauline'), findsOneWidget);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      // The system back gesture too.
      expect(await tester.binding.handlePopRoute(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text(_nameQuestion), findsOneWidget);
    });

    testWidgets('decided once, when the first run opens', (tester) async {
      final auth = _nameless();
      await pumpLoomia(tester, size: _phone, auth: auth);

      // Say a backfill landed meanwhile: the step stays, nothing jumps.
      auth
        ..account = const Account(
          firstName: 'Pauline',
          email: 'p@example.com',
          onboarded: false,
        )
        ..emit(AuthChange.userUpdated);
      await tester.pumpAndSettle();

      expect(find.text(_nameQuestion), findsOneWidget);
    });
  });

  testWidgets('a new account is asked its company first', (tester) async {
    await pumpLoomia(tester, size: _phone, auth: _newAccount());

    expect(find.byType(FirstRunPage), findsOneWidget);
    expect(find.text(_question), findsOneWidget);
    expect(find.text('dōTERRA'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
    // The tap is the answer: nothing chosen yet, nothing to confirm.
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('a tap saves the company and moves on', (tester) async {
    final auth = _newAccount();
    await pumpLoomia(tester, size: _phone, auth: auth);

    await _choose(tester, 'dōTERRA');

    expect(auth.calls, ['updateBusinessModel(doterra)']);
    expect(auth.account!.businessModel, BusinessModel.doterra);
    expect(auth.account!.onboarded, isFalse);
    expect(find.text('Invite code'), findsOneWidget);
    expect(find.text(_question), findsNothing);
  });

  testWidgets('back returns to the question, and a new answer is saved', (
    tester,
  ) async {
    final auth = _newAccount();
    await pumpLoomia(tester, size: _phone, auth: auth);
    await _choose(tester, 'dōTERRA');

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text(_question), findsOneWidget);

    await _choose(tester, 'Other');
    // The system back gesture too: the question, not out of the app.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text(_question), findsOneWidget);

    expect(auth.calls, [
      'updateBusinessModel(doterra)',
      'updateBusinessModel(other)',
    ]);
    expect(auth.account!.businessModel, BusinessModel.other);
  });

  testWidgets('a failed save stays on the question', (tester) async {
    final auth = _newAccount()..failWith = AuthFailure.network;
    await pumpLoomia(tester, size: _phone, auth: auth);

    await _choose(tester, 'dōTERRA');

    expect(find.text(_question), findsOneWidget);
    expect(
      find.text('We could not reach Loomia. Check your connection.'),
      findsOneWidget,
    );

    auth.failWith = null;
    await _choose(tester, 'dōTERRA');
    expect(find.text('Invite code'), findsOneWidget);
  });

  testWidgets('a second tap while saving is ignored', (tester) async {
    final auth = _newAccount()..gate = Completer<void>();
    await pumpLoomia(tester, size: _phone, auth: auth);

    await tester.tap(find.text('dōTERRA'));
    await tester.pump();
    await tester.tap(find.text('Other'));
    await tester.pump();
    auth.gate!.complete();
    await tester.pumpAndSettle();

    expect(auth.calls, ['updateBusinessModel(doterra)']);
    expect(find.text('Invite code'), findsOneWidget);
  });

  testWidgets('Skip goes to Today, for good', (tester) async {
    final auth = _newAccount();
    await pumpLoomia(tester, size: _phone, auth: auth);
    await _choose(tester, 'Other');

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip for now'));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('markOnboarded()'));
    expect(auth.account!.onboarded, isTrue);
    expect(find.byType(TodayPage), findsOneWidget);
  });

  testWidgets('Import goes to the phone contacts', (tester) async {
    await pumpLoomia(tester, size: _phone, auth: _newAccount());
    await _choose(tester, 'Other');

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Import from your contacts'));
    await tester.pumpAndSettle();

    expect(find.byType(ImportContactsPage), findsOneWidget);

    // The system back gesture: Contacts, not out of the app.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(ContactList), findsOneWidget);
  });

  testWidgets('an onboarded account never sees it', (tester) async {
    await pumpLoomia(tester, size: _phone);

    expect(find.byType(FirstRunPage), findsNothing);
  });

  group('invite step', () {
    testWidgets('the flow goes company → invite → people', (tester) async {
      await pumpLoomia(tester, size: _phone, auth: _newAccount());

      await _choose(tester, 'dōTERRA');
      expect(find.text('Invite code'), findsOneWidget);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text(_people), findsOneWidget);
    });

    testWidgets('back from people lands on invite', (tester) async {
      final auth = _newAccount();
      await pumpLoomia(tester, size: _phone, auth: auth);
      await _choose(tester, 'dōTERRA');
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('Invite code'), findsOneWidget);
    });

    testWidgets('skip on invite shows people', (tester) async {
      final auth = _newAccount();
      await pumpLoomia(tester, size: _phone, auth: auth);
      await _choose(tester, 'dōTERRA');

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text(_people), findsOneWidget);
      expect(auth.calls, contains('updateBusinessModel(doterra)'));
      expect(auth.calls, isNot(contains('markOnboarded()')));
    });

    testWidgets('already sharing shows linked state with Continue', (
      tester,
    ) async {
      tester.view.physicalSize = _phone;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final auth = _newAccount();
      addTearDown(auth.dispose);

      final sharing = FakeSharingRepository()
        ..myShareValue = const MyShare(
          mentorFirstName: 'Alice',
          items: {ShareItem.activityTargets},
        );

      // Use a custom ProviderScope to inject the sharing repository
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            sharingRepositoryProvider.overrideWithValue(sharing),
            peopleRepositoryProvider.overrideWithValue(FakePeopleRepository()),
            tagRepositoryProvider.overrideWithValue(FakeTagRepository()),
            activityRepositoryProvider.overrideWithValue(
              FakeActivityRepository(),
            ),
            workflowRepositoryProvider.overrideWithValue(
              FakeWorkflowRepository(FakeWorkflowRepository.samples()),
            ),
            eventWorkflowRepositoryProvider.overrideWithValue(
              FakeEventWorkflowRepository(
                FakeEventWorkflowRepository.samples(),
              ),
            ),
            goalsRepositoryProvider.overrideWithValue(FakeGoalsRepository()),
            eventRepositoryProvider.overrideWithValue(FakeEventRepository()),
            taskRepositoryProvider.overrideWithValue(FakeTaskRepository()),
            phoneContactsRepositoryProvider.overrideWithValue(
              FakePhoneContactsRepository(),
            ),
            photoRepositoryProvider.overrideWithValue(FakePhotoRepository()),
            photoPickerProvider.overrideWithValue(FakePhotoPicker()),
            pushProvider.overrideWithValue(FakePush(isAvailable: false)),
            notificationsRepositoryProvider.overrideWithValue(
              FakeNotificationsRepository(),
            ),
            deviceTimeZoneProvider.overrideWith((ref) => 'Europe/Paris'),
          ],
          child: const LoomiaApp(),
        ),
      );
      await tester.pumpAndSettle();

      await _choose(tester, 'dōTERRA');

      expect(find.text('You share your goals with Alice'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
      expect(find.text('Invite code'), findsNothing);

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text(_people), findsOneWidget);
    });
  });
}
