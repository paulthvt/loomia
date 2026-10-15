import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/tag.dart';
import 'package:loomia/features/contacts/presentation/tag_sheet.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_people_repository.dart';
import '../fake_tag_repository.dart';
import 'form_harness.dart';

Person _person(String id, [Set<String> tags = const {}]) => Person(
  id: id,
  name: 'Person $id',
  stage: Stage.customer,
  stageSince: DateTime.utc(2026, 5, 1),
  tagIds: tags,
);

const _lyon = Tag(id: 'lyon', name: 'Lyon', color: TagColor.stone);
const _sleep = Tag(id: 'sleep', name: 'Sleep', color: TagColor.sand);

Future<FakePeopleRepository> _open(
  WidgetTester tester,
  List<Person> people, {
  FakeTagRepository? tags,
}) async {
  final repository = FakePeopleRepository(people);
  await pumpFormHarness(
    tester,
    people: repository,
    tags: tags ?? FakeTagRepository(const [_lyon, _sleep]),
    open: (context) => showTagSheet(context, people),
    result: (_) {},
  );
  return repository;
}

CheckboxListTile _box(WidgetTester tester, String name) =>
    tester.widget(find.widgetWithText(CheckboxListTile, name));

int _setTags(FakePeopleRepository people) =>
    people.calls.where((c) => c.startsWith('setTags')).length;

void main() {
  testWidgets('one person: tick Sleep, Done writes once', (tester) async {
    final people = await _open(tester, [
      _person('1', {'lyon'}),
    ]);
    expect(find.text('Tags'), findsOneWidget);
    expect(_box(tester, 'Lyon').value, isTrue);
    expect(_box(tester, 'Sleep').value, isFalse);

    await tester.tap(find.text('Sleep'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(people.calls.last, 'setTags(1, +sleep, -)');
    expect(find.text('Done'), findsNothing);
  });

  testWidgets('closing without Done writes nothing', (tester) async {
    final people = await _open(tester, [_person('1')]);
    await tester.tap(find.text('Sleep'));
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(_setTags(people), 0);
  });

  testWidgets('a new name: Create makes the tag and ticks it', (tester) async {
    final tags = FakeTagRepository(const [_lyon, _sleep]);
    final people = await _open(tester, [_person('1')], tags: tags);

    await tester.enterText(find.byType(TextField), 'Workshop May');
    await tester.pump();
    expect(find.text('Sleep'), findsNothing);
    await tester.tap(find.text('Create “Workshop May”'));
    await tester.pumpAndSettle();

    expect(tags.calls, contains('add(Workshop May, olive)'));
    expect(_box(tester, 'Workshop May').value, isTrue);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(people.calls.last, 'setTags(1, +new-0, -)');
  });

  testWidgets('a name already used offers no Create', (tester) async {
    await _open(tester, [_person('1')]);
    await tester.enterText(find.byType(TextField), ' lyon ');
    await tester.pump();
    expect(find.textContaining('Create'), findsNothing);
    expect(find.text('Lyon'), findsOneWidget);
  });

  testWidgets('no tag yet: the empty line', (tester) async {
    await _open(tester, [_person('1')], tags: FakeTagRepository());
    expect(find.text('Type a name to create your first tag'), findsOneWidget);
  });

  group('four people', () {
    final four = [
      _person('1', {'lyon'}),
      _person('2', {'lyon'}),
      _person('3'),
      _person('4'),
    ];

    testWidgets('a mixed box left alone changes nothing', (tester) async {
      final people = await _open(tester, four);
      expect(find.text('Tag 4 people'), findsOneWidget);
      expect(_box(tester, 'Lyon').value, isNull);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(_setTags(people), 0);
    });

    testWidgets('ticking a mixed box adds it to all', (tester) async {
      final people = await _open(tester, four);
      await tester.tap(find.text('Lyon'));
      await tester.pump();
      expect(_box(tester, 'Lyon').value, isTrue);

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(people.calls.last, 'setTags(1, 2, 3, 4, +lyon, -)');
    });

    testWidgets('mixed, ticked, empty, then mixed again', (tester) async {
      await _open(tester, four);
      for (final expected in [true, false, null]) {
        await tester.tap(find.text('Lyon'));
        await tester.pump();
        expect(_box(tester, 'Lyon').value, expected);
      }
    });
  });
}
