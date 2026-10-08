import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/presentation/people_picker.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

Person _person(String id, String name, Stage stage) =>
    Person(id: id, name: name, stage: stage, stageSince: DateTime.utc(2026, 9));

final _book = [
  _person('p1', 'Claire Moreau', Stage.prospect),
  _person('p2', 'Marie Dupont', Stage.customer),
  _person('p3', 'Sarah Lemaire', Stage.prospect),
];

Future<void> _open(
  WidgetTester tester, {
  Set<String> except = const {},
  required void Function(Set<String>? picked) result,
}) async {
  tester.view
    ..physicalSize = const Size(390, 1200)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () async => result(
                await pickPeople(context, people: _book, except: except),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picks several people, without those already invited', (
    tester,
  ) async {
    Set<String>? picked;
    await _open(tester, except: {'p3'}, result: (value) => picked = value);

    expect(find.text('Sarah Lemaire'), findsNothing);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Claire Moreau'));
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 2 people'));
    await tester.pumpAndSettle();

    expect(picked, {'p1', 'p2'});
  });

  testWidgets('search narrows the list and keeps who is picked', (
    tester,
  ) async {
    Set<String>? picked;
    await _open(tester, result: (value) => picked = value);

    await tester.tap(find.text('Claire Moreau'));
    await tester.enterText(find.byType(TextField), 'mari');
    await tester.pumpAndSettle();

    expect(find.text('Claire Moreau'), findsNothing);
    expect(find.text('Marie Dupont'), findsOneWidget);
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 2 people'));
    await tester.pumpAndSettle();

    expect(picked, {'p1', 'p2'});
  });

  testWidgets('the stage filter narrows the list and keeps who is picked', (
    tester,
  ) async {
    Set<String>? picked;
    await _open(tester, result: (value) => picked = value);

    await tester.tap(find.text('Claire Moreau'));
    await tester.tap(find.text('Customers'));
    await tester.pumpAndSettle();

    expect(find.text('Claire Moreau'), findsNothing);
    expect(find.text('Sarah Lemaire'), findsNothing);
    await tester.tap(find.text('Marie Dupont'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add 2 people'));
    await tester.pumpAndSettle();

    expect(picked, {'p1', 'p2'});
  });

  testWidgets('nobody left to add says so', (tester) async {
    await _open(tester, except: {'p1', 'p2', 'p3'}, result: (_) {});

    expect(find.text('Nobody else to add.'), findsOneWidget);
  });

  testWidgets('dismissing picks nobody', (tester) async {
    var called = false;
    Set<String>? picked = {'x'};
    await _open(
      tester,
      result: (value) {
        called = true;
        picked = value;
      },
    );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(called, isTrue);
    expect(picked, isNull);
  });
}
