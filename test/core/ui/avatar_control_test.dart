import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/avatar_control.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, AvatarControl control) =>
    tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Center(child: control)),
      ),
    );

void main() {
  testWidgets('no photo: the menu offers Choose photo only', (tester) async {
    await _pump(
      tester,
      AvatarControl(name: 'Marie Dupont', onChoose: () async {}),
    );

    await tester.tap(find.byType(AvatarControl));
    await tester.pumpAndSettle();

    expect(find.text('Choose photo'), findsOneWidget);
    expect(find.text('Remove photo'), findsNothing);
  });

  testWidgets('with a photo: Remove photo too, and it calls back', (
    tester,
  ) async {
    var removed = 0;
    await _pump(
      tester,
      AvatarControl(
        name: 'Marie Dupont',
        onChoose: () async {},
        onRemove: () async => removed++,
      ),
    );

    await tester.tap(find.byType(AvatarControl));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();

    expect(removed, 1);
  });

  testWidgets('while choosing: the ring, no badge, no second tap', (
    tester,
  ) async {
    final choosing = Completer<void>();
    var chosen = 0;
    await _pump(
      tester,
      AvatarControl(
        name: 'Marie Dupont',
        onChoose: () {
          chosen++;
          return choosing.future;
        },
      ),
    );
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);

    await tester.tap(find.byType(AvatarControl));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose photo'));
    // The ring spins forever: pump past the menu's close, never settle.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.photo_camera_outlined), findsNothing);
    await tester.tap(find.byType(AvatarControl), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Choose photo'), findsNothing);

    choosing.complete();
    await tester.pumpAndSettle();

    expect(chosen, 1);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.photo_camera_outlined), findsOneWidget);
  });

  testWidgets('reads as a button: Change photo', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(
      tester,
      AvatarControl(name: 'Marie Dupont', onChoose: () async {}),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel(RegExp('Change photo'))),
      isSemantics(label: 'Change photo', isButton: true, hasTapAction: true),
    );
    semantics.dispose();
  });
}
