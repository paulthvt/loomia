import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/edit_person_form.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_people_repository.dart';
import 'form_harness.dart';

final _marie = Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: Stage.prospect,
  prospectStatus: ProspectStatus.thinking,
  phone: '06 12 34 56 78',
  stageSince: DateTime.utc(2026, 3, 4),
);

void main() {
  late FakePeopleRepository people;

  setUp(() => people = FakePeopleRepository([_marie]));

  Future<void> open(WidgetTester tester) => pumpFormHarness(
    tester,
    people: people,
    open: (context) => showEditPerson(context, _marie),
    result: (_) {},
  );

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(LabeledField, label),
    matching: find.byType(TextFormField),
  );

  testWidgets('starts from what is saved', (tester) async {
    await open(tester);

    expect(find.text('Marie Dupont'), findsOneWidget);
    expect(find.text('06 12 34 56 78'), findsOneWidget);
  });

  testWidgets('saves every field and keeps stage and status', (tester) async {
    await open(tester);

    await tester.enterText(field('Needs'), 'Sleep, stress');
    await tester.enterText(field('Phone'), '');
    await tester.ensureVisible(field('Notes'));
    await tester.enterText(field('Notes'), 'Met at the market');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = people.store['p1']!;
    expect(saved.needs, 'Sleep, stress');
    expect(saved.phone, isNull);
    expect(saved.notes, 'Met at the market');
    expect(saved.stage, Stage.prospect);
    expect(saved.prospectStatus, ProspectStatus.thinking);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets("a team member's own profile is edited with the rest", (
    tester,
  ) async {
    final member = Person(
      id: 'p2',
      name: 'Léa Martin',
      stage: Stage.team,
      stageSince: DateTime.utc(2026, 3, 4),
      why: 'More time with my kids',
    );
    people = FakePeopleRepository([member]);
    await pumpFormHarness(
      tester,
      people: people,
      open: (context) => showEditPerson(context, member),
      result: (_) {},
    );

    expect(find.text('More time with my kids'), findsOneWidget);
    await tester.ensureVisible(field('Their own goal'));
    await tester.enterText(field('Their own goal'), 'Pay for the holidays');
    await tester.ensureVisible(field('Where they are stuck'));
    await tester.enterText(field('Where they are stuck'), 'Talking about it');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = people.store['p2']!;
    expect(saved.why, 'More time with my kids');
    expect(saved.ownGoal, 'Pay for the holidays');
    expect(saved.stuckOn, 'Talking about it');
    expect(saved.stage, Stage.team);
  });

  testWidgets('not on the team: no profile fields, and a saved one is kept', (
    tester,
  ) async {
    final former = Person(
      id: 'p3',
      name: 'Paul Roux',
      stage: Stage.customer,
      stageSince: DateTime.utc(2026, 3, 4),
      ownGoal: 'Pay for the holidays',
    );
    people = FakePeopleRepository([former]);
    await pumpFormHarness(
      tester,
      people: people,
      open: (context) => showEditPerson(context, former),
      result: (_) {},
    );

    expect(find.text('Their own goal'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(people.store['p3']!.ownGoal, 'Pay for the holidays');
  });

  testWidgets('a section asks only for its own fields and keeps the rest', (
    tester,
  ) async {
    final member = Person(
      id: 'p2',
      name: 'Léa Martin',
      stage: Stage.team,
      stageSince: DateTime.utc(2026, 3, 4),
      needs: 'Sleep',
      why: 'More time with my kids',
    );
    people = FakePeopleRepository([member]);
    Future<void> edit(EditPart part) => pumpFormHarness(
      tester,
      people: people,
      open: (context) => showEditPerson(context, member, part),
      result: (_) {},
    );

    await edit(EditPart.aims);
    expect(find.text('What they are aiming for'), findsOneWidget);
    expect(field('Their own goal'), findsOneWidget);
    expect(field('Name'), findsNothing);
    expect(field('Needs'), findsNothing);
    await tester.enterText(field('Their own goal'), 'Pay for the holidays');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final saved = people.store['p2']!;
    expect(saved.ownGoal, 'Pay for the holidays');
    expect(saved.name, 'Léa Martin');
    expect(saved.needs, 'Sleep');

    await edit(EditPart.facts);
    expect(field('Needs'), findsOneWidget);
    expect(field('Name'), findsNothing);
    expect(field('Their why'), findsNothing);
  });

  group("a team member's rank and volume", () {
    const doterra = Account(
      firstName: 'Pauline',
      email: 'p@example.com',
      businessModel: BusinessModel.doterra,
    );
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);

    Person member({
      String? currentLevel,
      String? targetLevel,
      DateTime? by,
      double? volume,
    }) => Person(
      id: 'p2',
      name: 'Léa Martin',
      stage: Stage.team,
      stageSince: DateTime.utc(2026, 3, 4),
      why: 'More time with my kids',
      needs: 'Sleep',
      currentLevel: currentLevel,
      targetLevel: targetLevel,
      targetLevelBy: by,
      monthlyVolumeTarget: volume,
    );

    Future<void> edit(
      WidgetTester tester,
      Person person, {
      Account account = const Account(
        firstName: 'Pauline',
        email: 'p@example.com',
      ),
      EditPart part = EditPart.everything,
    }) {
      people = FakePeopleRepository([person]);
      return pumpFormHarness(
        tester,
        people: people,
        account: account,
        open: (context) => showEditPerson(context, person, part),
        result: (_) {},
      );
    }

    Finder labeled(String label) => find.widgetWithText(LabeledField, label);

    Future<void> pick(WidgetTester tester, String label, String level) async {
      await tester.ensureVisible(labeled(label));
      await tester.tap(
        find.descendant(
          of: labeled(label),
          matching: find.byType(DropdownButtonFormField<String?>),
        ),
      );
      await tester.pumpAndSettle();
      // The menu opens on the picked rank; "Not set" may be scrolled above.
      if (level == 'Not set') {
        await tester.drag(find.byType(Scrollable).last, const Offset(0, 400));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text(level).last);
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets('dōTERRA: ranks from the list, a month, PV each month', (
      tester,
    ) async {
      await edit(tester, member(), account: doterra);

      double top(String label) => tester.getTopLeft(labeled(label)).dy;
      expect(top('Their why'), lessThan(top('Rank now')));
      expect(top('Rank now'), lessThan(top('Aiming for')));
      expect(top('Aiming for'), lessThan(top('Each month (PV)')));
      expect(top('Each month (PV)'), lessThan(top('Their own goal')));
      // No month until there is something to aim for.
      expect(labeled('By'), findsNothing);

      await pick(tester, 'Rank now', 'Executive');
      await pick(tester, 'Aiming for', 'Elite');
      expect(labeled('By'), findsOneWidget);
      await tester.ensureVisible(labeled('By'));
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();
      // The picker opens on this month; OK keeps it.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(field('Each month (PV)'));
      await tester.enterText(field('Each month (PV)'), '100');
      await save(tester);

      final saved = people.store['p2']!;
      expect(saved.currentLevel, 'Executive');
      expect(saved.targetLevel, 'Elite');
      expect(saved.targetLevelBy, thisMonth);
      expect(saved.monthlyVolumeTarget, 100);
      expect(saved.why, 'More time with my kids');
    });

    testWidgets('a picked rank reads like the typed fields', (tester) async {
      await edit(tester, member(currentLevel: 'Executive'), account: doterra);

      final context = tester.element(labeled('Rank now'));
      final rank = tester.widget<DropdownButton<String?>>(
        find.byType(DropdownButton<String?>).first,
      );
      expect(rank.style, Theme.of(context).textTheme.bodyLarge);
    });

    testWidgets('Other: levels are typed, the volume has no unit', (
      tester,
    ) async {
      await edit(tester, member());

      expect(labeled('Rank now'), findsNothing);
      await tester.ensureVisible(field('Level now'));
      await tester.enterText(field('Level now'), 'Bronze');
      await tester.enterText(field('Aiming for'), 'Silver');
      await tester.pump();
      expect(labeled('By'), findsOneWidget);
      await tester.ensureVisible(field('Each month'));
      await tester.enterText(field('Each month'), '250');
      await save(tester);

      final saved = people.store['p2']!;
      expect(saved.currentLevel, 'Bronze');
      expect(saved.targetLevel, 'Silver');
      expect(saved.targetLevelBy, isNull);
      expect(saved.monthlyVolumeTarget, 250);
    });

    testWidgets('clearing Aiming for drops By; a saved volume is kept', (
      tester,
    ) async {
      await edit(
        tester,
        member(targetLevel: 'Elite', by: DateTime(2027, 3), volume: 99.5),
      );

      expect(find.text('March 2027'), findsOneWidget);
      expect(find.text('99.5'), findsOneWidget);
      await tester.ensureVisible(field('Aiming for'));
      await tester.enterText(field('Aiming for'), '');
      await tester.pump();
      expect(labeled('By'), findsNothing);
      await save(tester);

      final saved = people.store['p2']!;
      expect(saved.targetLevel, isNull);
      expect(saved.targetLevelBy, isNull);
      expect(saved.monthlyVolumeTarget, 99.5);
    });

    testWidgets('an unknown rank stays picked and is kept', (tester) async {
      await edit(
        tester,
        member(currentLevel: 'Wellness Advocate'),
        account: doterra,
      );

      expect(find.text('Wellness Advocate'), findsOneWidget);
      await save(tester);

      expect(people.store['p2']!.currentLevel, 'Wellness Advocate');
    });

    testWidgets('"Not set" clears a rank', (tester) async {
      await edit(tester, member(currentLevel: 'Executive'), account: doterra);

      await pick(tester, 'Rank now', 'Not set');
      await save(tester);

      expect(people.store['p2']!.currentLevel, isNull);
    });

    testWidgets('a past month opens the picker and is kept', (tester) async {
      await edit(tester, member(targetLevel: 'Elite', by: DateTime(2020)));

      await tester.ensureVisible(find.text('January 2020'));
      await tester.tap(find.text('January 2020'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await save(tester);

      expect(people.store['p2']!.targetLevelBy, DateTime(2020));
    });

    testWidgets('iOS: a month-and-year wheel that starts at a past month', (
      tester,
    ) async {
      await edit(tester, member(targetLevel: 'Elite', by: DateTime(2020)));

      await tester.ensureVisible(find.text('January 2020'));
      await tester.tap(find.text('January 2020'));
      await tester.pumpAndSettle();
      final wheel = tester.widget<CupertinoDatePicker>(
        find.byType(CupertinoDatePicker),
      );
      expect(wheel.mode, CupertinoDatePickerMode.monthYear);
      expect(wheel.minimumDate, DateTime(2020));
      expect(wheel.maximumDate, DateTime(thisMonth.year + 10, thisMonth.month));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.byType(CupertinoDatePicker), findsNothing);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a bad volume is refused', (tester) async {
      await edit(tester, member());

      await tester.ensureVisible(field('Each month'));
      await tester.enterText(field('Each month'), '0');
      await save(tester);

      expect(
        find.text('Use a number above 0, like 100 or 99.5.'),
        findsOneWidget,
      );
      expect(people.store['p2']!.monthlyVolumeTarget, isNull);
    });

    testWidgets('editing what you know keeps the rank and volume', (
      tester,
    ) async {
      await edit(
        tester,
        member(
          currentLevel: 'Executive',
          targetLevel: 'Elite',
          by: DateTime(2027, 3),
          volume: 100,
        ),
        account: doterra,
        part: EditPart.facts,
      );

      expect(labeled('Rank now'), findsNothing);
      await tester.enterText(field('Needs'), 'Sleep, stress');
      await save(tester);

      final saved = people.store['p2']!;
      expect(saved.needs, 'Sleep, stress');
      expect(saved.currentLevel, 'Executive');
      expect(saved.targetLevel, 'Elite');
      expect(saved.targetLevelBy, DateTime(2027, 3));
      expect(saved.monthlyVolumeTarget, 100);
    });
  });

  testWidgets('the whole form is grouped as the page is', (tester) async {
    final member = Person(
      id: 'p2',
      name: 'Léa Martin',
      stage: Stage.team,
      stageSince: DateTime.utc(2026, 3, 4),
    );
    people = FakePeopleRepository([member, _marie]);
    Future<void> edit(Person person, [EditPart? part]) => pumpFormHarness(
      tester,
      people: people,
      open: (context) => part == null
          ? showEditPerson(context, person)
          : showEditPerson(context, person, part),
      result: (_) {},
    );
    double top(Finder finder) => tester.getTopLeft(finder).dy;

    await edit(member);
    final aims = find.text('WHAT THEY ARE AIMING FOR');
    final known = find.text('WHAT YOU KNOW');
    expect(top(field('Name')), lessThan(top(aims)));
    expect(top(aims), lessThan(top(field('Their why'))));
    await tester.ensureVisible(field('Needs'));
    expect(top(field('Where they are stuck')), lessThan(top(known)));
    expect(top(known), lessThan(top(field('Needs'))));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await edit(_marie);
    expect(find.text('WHAT THEY ARE AIMING FOR'), findsNothing);
    expect(find.text('WHAT YOU KNOW'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await edit(member, EditPart.facts);
    expect(find.text('WHAT YOU KNOW'), findsNothing);
  });

  testWidgets('a name is still required', (tester) async {
    await open(tester);

    await tester.enterText(field('Name'), '  ');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a name.'), findsOneWidget);
    expect(people.calls, ['list()']);
  });

  testWidgets('a failure stays on the form with the input kept', (
    tester,
  ) async {
    await open(tester);
    people.failWith = PeopleFailure.unknown;

    await tester.enterText(field('Needs'), 'Sleep');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(FormError), findsOneWidget);
    expect(find.text('Something went wrong. Try again.'), findsOneWidget);
    expect(find.text('Sleep'), findsOneWidget);
  });
}
