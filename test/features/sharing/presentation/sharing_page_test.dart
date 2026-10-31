import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/app.dart';
import 'package:loomia/app/shell/app_shell.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/sharing/data/sharing_repository.dart';
import 'package:loomia/features/sharing/domain/share_item.dart';
import 'package:loomia/features/sharing/domain/shared_goals.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_sharing_repository.dart';

Future<FakeSharingRepository> _openSharing(
  WidgetTester tester, {
  MyShare? initialShare,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final auth = FakeAuthRepository()
    ..session = true
    ..account = Account(firstName: 'Pauline', email: 'p@example.com');
  addTearDown(auth.dispose);

  final sharing = FakeSharingRepository()..myShareValue = initialShare;

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

  await tester.tap(find.text('Sharing'));
  await tester.pumpAndSettle();

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
