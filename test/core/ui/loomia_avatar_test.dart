import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/preview_photo.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  // Image decoding is real async work, outside the fake clock.
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage(
        (element.widget as Image).image,
        element,
        onError: (_, _) {},
      );
    }
  });
  await tester.pumpAndSettle();
}

Finder _shownImage() => find.byWidgetPredicate(
  (widget) => widget is RawImage && widget.image != null,
);

void main() {
  testWidgets('without a photo: initials', (tester) async {
    await _pump(tester, const LoomiaAvatar(name: 'Marie Dupont'));

    expect(find.text('MD'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Marie Dupont')), findsOneWidget);
  });

  testWidgets('with a photo: the photo over the initials', (tester) async {
    await _pump(
      tester,
      LoomiaAvatar(name: 'Marie Dupont', photo: MemoryImage(previewPhoto)),
    );

    expect(_shownImage(), findsOneWidget);
    expect(find.text('MD'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Marie Dupont')), findsOneWidget);
  });

  testWidgets('a photo that fails to load: initials, no error', (tester) async {
    await _pump(
      tester,
      LoomiaAvatar(
        name: 'Marie Dupont',
        photo: MemoryImage(Uint8List.fromList([0, 1, 2, 3])),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(_shownImage(), findsNothing);
    expect(find.text('MD'), findsOneWidget);
  });

  testWidgets('PhotoAvatar without a path needs no ProviderScope', (
    tester,
  ) async {
    await _pump(tester, const PhotoAvatar(name: 'Marie Dupont'));

    expect(tester.takeException(), isNull);
    expect(find.text('MD'), findsOneWidget);
  });
}
