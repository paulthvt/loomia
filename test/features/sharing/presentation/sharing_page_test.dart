import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/app.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';
import 'package:loomia/features/sharing/domain/shared_goals.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_sharing_repository.dart';

Future<FakeSharingRepository> _openSharing(
  WidgetTester tester, {
  MyShare? initialShare,
  bool open = true,
  Object? failWith,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository()
    ..session = true
    ..account = const Account(firstName: 'Pauline', email: 'p@example.com');
  addTearDown(auth.dispose);

  final sharing = FakeSharingRepository()
    ..myShareValue = initialShare
    ..failWith = failWith;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        sharingRepositoryProvider.overrideWithValue(sharing),
      ],
      child: const LoomiaApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byType(AccountButton));
  await tester.pumpAndSettle();

  if (open) {
    await tester.tap(find.text('Sharing'));
    await tester.pumpAndSettle();
  }

  return sharing;
}

void main() {
  testWidgets('linked state shows the mentor name', (tester) async {
    await _openSharing(
      tester,
      initialShare: const MyShare(
        mentorFirstName: 'Alice',
        items: {ShareItem.activityTargets},
      ),
    );

    expect(find.text('You share your goals with Alice'), findsOneWidget);
  });

  testWidgets('a mentor without a first name: the line goes without', (
    tester,
  ) async {
    await _openSharing(
      tester,
      initialShare: const MyShare(mentorFirstName: '', items: {}),
    );

    expect(find.text('You share your goals'), findsOneWidget);
  });

  testWidgets('Settings, a mentor without a first name: sharing your goals', (
    tester,
  ) async {
    await _openSharing(
      tester,
      initialShare: const MyShare(mentorFirstName: '', items: {}),
      open: false,
    );

    expect(find.text('Sharing your goals'), findsOneWidget);
  });

  testWidgets('a failed load offers Try again, then shows the link', (
    tester,
  ) async {
    final sharing = await _openSharing(
      tester,
      initialShare: const MyShare(mentorFirstName: 'Alice', items: {}),
      failWith: PeopleFailure.network,
    );

    sharing.failWith = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('You share your goals with Alice'), findsOneWidget);
    expect(find.text('Stop sharing'), findsOneWidget);
  });

  testWidgets('toggling progress calls setItems', (tester) async {
    final sharing = await _openSharing(
      tester,
      initialShare: const MyShare(
        mentorFirstName: 'Alice',
        items: {ShareItem.activityTargets},
      ),
    );

    await tester.tap(find.byType(SwitchListTile).last);
    await tester.pumpAndSettle();

    expect(sharing.calls.last, 'setItems(2 items)');
  });

  testWidgets('stop sharing after confirm calls stopSharing', (tester) async {
    final sharing = await _openSharing(
      tester,
      initialShare: const MyShare(
        mentorFirstName: 'Alice',
        items: {ShareItem.activityTargets},
      ),
    );

    final stopButton = find.widgetWithText(FilledButton, 'Stop sharing');
    await tester.ensureVisible(stopButton);
    await tester.pumpAndSettle();
    await tester.tap(stopButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await tester.pumpAndSettle();

    expect(sharing.calls, contains('stopSharing()'));
  });
}
