import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/tag.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/app_harness.dart';
import '../fake_people_repository.dart';
import '../fake_tag_repository.dart';

const _lyon = Tag(id: 'lyon', name: 'Lyon', color: TagColor.sage);
const _sleep = Tag(id: 'sleep', name: 'Sleep', color: TagColor.sky);

Person _person(String id, Set<String> tags) => Person(
  id: id,
  name: 'Person $id',
  stage: Stage.customer,
  stageSince: DateTime.utc(2026, 5, 1),
  tagIds: tags,
);

Future<FakeTagRepository> _open(WidgetTester tester) async {
  final tags = FakeTagRepository(const [_lyon, _sleep]);
  final container = await pumpLoomia(
    tester,
    size: const Size(390, 844),
    tags: tags,
    people: FakePeopleRepository([
      for (var i = 0; i < 12; i++) _person('$i', {'lyon'}),
      _person('x', {'sleep'}),
    ]),
  );
  // The book loads with Contacts; Settings only reads it.
  container.read(routerProvider).go(Routes.contacts);
  await tester.pumpAndSettle();
  container.read(routerProvider).go(Routes.settingsTags);
  await tester.pumpAndSettle();
  return tags;
}

void main() {
  testWidgets('Settings has a Tags row with the count', (tester) async {
    final container = await pumpLoomia(
      tester,
      size: const Size(390, 844),
      tags: FakeTagRepository(const [_lyon, _sleep]),
    );
    container.read(routerProvider).go(Routes.settings);
    await tester.pumpAndSettle();
    expect(find.text('2 tags'), findsOneWidget);
    await tester.tap(find.text('Tags'));
    await tester.pumpAndSettle();
    expect(find.text('Lyon'), findsOneWidget);
  });

  testWidgets('lists every tag with how many people have it', (tester) async {
    await _open(tester);
    expect(find.text('Lyon'), findsOneWidget);
    expect(find.text('12 people'), findsOneWidget);
    expect(find.text('1 person'), findsOneWidget);
  });

  testWidgets('rename and recolour save in one write', (tester) async {
    final tags = await _open(tester);
    await tester.tap(find.text('Lyon'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Lyon centre');
    await tester.tap(find.bySemanticsLabel('Violet'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tags.calls, contains('update(lyon, Lyon centre, violet)'));
    expect(find.text('Lyon centre'), findsOneWidget);
  });

  testWidgets('a name in use says so and cannot save', (tester) async {
    final tags = await _open(tester);
    await tester.tap(find.text('Lyon'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sleep');
    await tester.pump();

    expect(find.text('You already have a tag called sleep'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save'),
    );
    expect(save.onPressed, isNull);
    expect(tags.calls.where((c) => c.startsWith('update')), isEmpty);
  });

  testWidgets('delete asks with the count, then deletes', (tester) async {
    final tags = await _open(tester);
    await tester.tap(find.text('Lyon'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete tag'));
    await tester.pumpAndSettle();

    expect(find.text('Remove Lyon from 12 people?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete tag'));
    await tester.pumpAndSettle();

    expect(tags.calls, contains('delete(lyon)'));
    expect(find.text('Lyon'), findsNothing);
  });

  testWidgets('New tag starts on the first unused colour', (tester) async {
    final tags = await _open(tester);
    await tester.tap(find.text('New tag'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Family');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(tags.calls, contains('add(Family, stone)'));
  });
}
