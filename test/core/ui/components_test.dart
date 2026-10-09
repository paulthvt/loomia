import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/action_item.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

Future<void> pump(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  test('initials come from the first and last word', () {
    expect(LoomiaAvatar.initialsOf('Marie Dupont'), 'MD');
    expect(LoomiaAvatar.initialsOf('Jean-Luc De La Fontaine'), 'JF');
    expect(LoomiaAvatar.initialsOf('  amina  '), 'A');
    expect(LoomiaAvatar.initialsOf(''), '?');
  });

  testWidgets('avatars are circular at every size', (tester) async {
    for (final size in AvatarSize.values) {
      await pump(tester, LoomiaAvatar(name: 'Marie Dupont', size: size));
      final box = tester.getSize(find.byType(LoomiaAvatar));
      expect(box.width, size.diameter);
      expect(box.height, size.diameter);
      final decoration =
          tester.widget<Container>(find.byType(Container).first).decoration
              as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
    }
  });

  testWidgets('an action item opens the person and resolves in one tap', (
    tester,
  ) async {
    var opened = 0;
    var resolved = 0;
    await pump(
      tester,
      ActionItem(
        name: 'Marie Dupont',
        reason: 'Back from her holiday today',
        onOpen: () => opened++,
        onResolve: () => resolved++,
      ),
    );

    await tester.tap(find.byIcon(Icons.check_rounded));
    expect((opened, resolved), (0, 1));

    await tester.tap(find.text('Marie Dupont'));
    expect((opened, resolved), (1, 1));
  });

  testWidgets('a tag sits right after the name, not at the line\'s end', (
    tester,
  ) async {
    await pump(
      tester,
      const ActionItem(
        name: 'Bob',
        reason: 'Send a first message',
        tag: Text('Prospect'),
      ),
    );

    final name = tester.renderObject<RenderParagraph>(find.text('Bob'));
    final nameEnd =
        tester.getTopLeft(find.text('Bob')).dx +
        name.getMaxIntrinsicWidth(double.infinity);
    final tagStart = tester.getTopLeft(find.text('Prospect')).dx;
    expect(tagStart - nameEnd, lessThan(20));
  });

  testWidgets('the resolve button keeps a 44px touch target', (tester) async {
    await pump(
      tester,
      ActionItem(
        name: 'Marie Dupont',
        reason: 'Back from her holiday today',
        onResolve: () {},
      ),
    );

    final button = tester.getSize(find.byType(IconButton));
    expect(button.width, greaterThanOrEqualTo(44));
    expect(button.height, greaterThanOrEqualTo(44));
  });

  testWidgets('a field is named by the label above it', (tester) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, const LabeledField(label: 'Name', child: TextField()));

    // Above the box, not inside it.
    expect(
      tester.getBottomLeft(find.text('Name')).dy,
      lessThanOrEqualTo(tester.getTopLeft(find.byType(InputDecorator)).dy),
    );
    expect(
      tester.getSemantics(find.byType(TextField)),
      isSemantics(label: 'Name', isTextField: true),
    );
    semantics.dispose();
  });
}
