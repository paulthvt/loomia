import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/fact_row.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/preview_photo.dart';
import 'package:material_ui/material_ui.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(body: ListView(children: [child])),
  ),
);

void main() {
  testWidgets('ContactRow shows avatar, name, subtitle and taps', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      ContactRow(
        name: 'Marie Dupont',
        subtitle: 'Nurse',
        trailing: const Text('Prospect'),
        onTap: () => taps++,
      ),
    );

    expect(find.byType(LoomiaAvatar), findsOneWidget);
    expect(find.text('Marie Dupont'), findsOneWidget);
    expect(find.text('Nurse'), findsOneWidget);
    expect(find.text('Prospect'), findsOneWidget);
    await tester.tap(find.text('Marie Dupont'));
    expect(taps, 1);
  });

  testWidgets('a photo of bytes shows without a ProviderScope', (tester) async {
    final photo = MemoryImage(previewPhoto);
    await _pump(tester, ContactRow(name: 'Marie Dupont', photo: photo));

    expect(tester.takeException(), isNull);
    expect(tester.widget<LoomiaAvatar>(find.byType(LoomiaAvatar)).photo, photo);
  });

  testWidgets('FactRow wraps a long value instead of clipping it', (
    tester,
  ) async {
    await _pump(
      tester,
      // A ListView stretches its children; Align lets the 200 px width hold.
      const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 200,
          child: FactRow(
            label: 'Needs',
            value: 'Sleep, stress, dry skin, sore joints after running',
          ),
        ),
      ),
    );

    final value = tester.getSize(
      find.text('Sleep, stress, dry skin, sore joints after running'),
    );
    final label = tester.getSize(find.text('Needs'));
    expect(value.height, greaterThan(label.height * 1.5));
    expect(tester.takeException(), isNull);
  });
}
