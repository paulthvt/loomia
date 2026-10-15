import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/domain/tag.dart';
import 'package:loomia/features/contacts/presentation/stage_filter.dart';

Person _person(
  String id, {
  Stage stage = Stage.prospect,
  Set<String> tags = const {},
  DateTime? lrp,
}) => Person(
  id: id,
  name: id,
  stage: stage,
  stageSince: DateTime(2026, 10),
  tagIds: tags,
  loyaltySince: lrp,
);

void main() {
  const lyon = Tag(id: 'lyon', name: 'Lyon', color: TagColor.stone);
  const sleep = Tag(id: 'sleep', name: 'Sleep', color: TagColor.sand);
  const lea = Tag(id: 'lea', name: 'Lea', color: TagColor.olive);

  group('nextTagColor', () {
    test('none used: the first', () {
      expect(nextTagColor(const []), TagColor.stone);
    });

    test('the first unused', () {
      expect(nextTagColor(const [lyon, sleep]), TagColor.olive);
    });

    test('all used: the first again', () {
      expect(
        nextTagColor([
          for (final color in TagColor.values)
            Tag(id: color.name, name: color.name, color: color),
        ]),
        TagColor.stone,
      );
    });
  });

  group('tagNameTaken', () {
    test('ignores case, accents and spaces', () {
      expect(tagNameTaken('lyon', const [lyon]), isTrue);
      expect(tagNameTaken(' Lyon ', const [lyon]), isTrue);
      expect(tagNameTaken('Léa', const [lea]), isTrue);
      expect(tagNameTaken('Lyons', const [lyon]), isFalse);
    });

    test('a rename may keep its own name', () {
      expect(tagNameTaken('LYON', const [lyon], except: 'lyon'), isFalse);
    });
  });

  test('tagState: all, some, none', () {
    final a = _person('a', tags: {'lyon'});
    final b = _person('b', tags: {'lyon'});
    final c = _person('c');
    expect(tagState(lyon, [a, b]), isTrue);
    expect(tagState(lyon, [a, c]), isNull);
    expect(tagState(lyon, [c]), isFalse);
  });

  test('tagsOf keeps the tags order and drops unknown ids', () {
    expect(tagsOf({'sleep', 'gone', 'lyon'}, const [lyon, sleep]), [
      lyon,
      sleep,
    ]);
  });

  group('StageFilter.shows with tags', () {
    final both = _person(
      'both',
      stage: Stage.customer,
      tags: {'lyon', 'sleep'},
    );
    final one = _person('one', stage: Stage.customer, tags: {'lyon'});
    final prospect = _person('p', tags: {'lyon', 'sleep'});

    test('every tag picked must be there', () {
      bool shows(Person p) =>
          StageFilter.shows(Stage.customer, p, tags: {'lyon', 'sleep'});
      expect(shows(both), isTrue);
      expect(shows(one), isFalse);
      expect(shows(prospect), isFalse);
    });

    test('and the LRP when asked', () {
      final withLrp = _person(
        'lrp',
        stage: Stage.customer,
        tags: {'lyon'},
        lrp: DateTime(2026, 9),
      );
      expect(
        StageFilter.shows(null, withLrp, loyalty: true, tags: {'lyon'}),
        isTrue,
      );
      expect(
        StageFilter.shows(null, one, loyalty: true, tags: {'lyon'}),
        isFalse,
      );
    });

    test('no tag picked shows everyone', () {
      expect(StageFilter.shows(null, _person('x')), isTrue);
    });
  });
}
