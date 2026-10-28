import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/app.dart';
import 'package:loomia/core/layout/breakpoints.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/today/presentation/today_page.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app_harness.dart';

import 'features/auth/fake_auth_repository.dart';

void main() {
  testWidgets('a signed-out launch lands on the welcome screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
        child: const LoomiaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue with email'), findsOneWidget);
  });

  testWidgets('a restored session lands on Today', (tester) async {
    await pumpLoomia(tester, size: const Size(390, 844));

    expect(find.byType(TodayPage), findsOneWidget);
    // "Good morning, Pauline", or afternoon, or evening: the clock decides.
    expect(find.textContaining('Pauline'), findsOneWidget);
  });

  test('breakpoints map widths to layout classes', () {
    expect(Breakpoints.of(375), ScreenSize.mobile);
    expect(Breakpoints.of(Breakpoints.tablet), ScreenSize.tablet);
    expect(Breakpoints.of(Breakpoints.desktop), ScreenSize.desktop);
    // An iPad Pro 13" in portrait: too narrow for sidebar + list + pane (#403).
    expect(Breakpoints.of(1032), ScreenSize.tablet);
    expect(ScreenSize.mobile.usesSideNavigation, isFalse);
    expect(ScreenSize.desktop.usesSideNavigation, isTrue);
  });
}
