import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/contact_row.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/loomia_avatar.dart';
import 'package:loomia/core/ui/loomia_dialog.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contact_list.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

Person _person(String id, String name, Stage stage, {String? profession}) =>
    Person(
      id: id,
      name: name,
      stage: stage,
      profession: profession,
      stageSince: DateTime.utc(2026, 3, 4),
    );

const _phone = Size(390, 844);
const _tablet = Size(800, 900);

final _book = [
  _person('1', 'Anne Martin', Stage.prospect, profession: 'Nurse'),
  _person('2', 'Bruno Leroy', Stage.customer),
  _person('3', 'Hélène Petit', Stage.team),
];

Future<void> _pump(
  WidgetTester tester, {
  List<Person>? people,
  ValueChanged<Person>? onOpen,
  VoidCallback? onAdd,
  Future<void> Function()? onRefresh,
  VoidCallback? onImport,
  Future<bool> Function(List<Person> people, Stage stage)? onMove,
  Future<bool> Function(List<Person> people)? onChangeWorkflow,
  Future<bool> Function(List<Person> people)? onDelete,
  ValueChanged<bool>? onPickingChanged,
  Size size = _tablet,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: ContactList(
          people: people ?? _book,
          onOpen: onOpen ?? (_) {},
          onAdd: onAdd ?? () {},
          onRefresh: onRefresh ?? () async {},
          onMove: onMove ?? (_, _) async => true,
          onChangeWorkflow: onChangeWorkflow ?? (_) async => true,
          onDelete: onDelete ?? (_) async => true,
          onImport: onImport,
          onPickingChanged: onPickingChanged,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists everyone with their stage and a subtitle', (tester) async {
    await _pump(tester);

    expect(find.byType(ContactRow), findsNWidgets(3));
    expect(find.text('Nurse'), findsOneWidget);
    // The filter chip "Team" and Hélène's stage chip.
    expect(find.text('Team'), findsNWidgets(2));
  });

  testWidgets('a stage chip filters the list', (tester) async {
    await _pump(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Customers'));
    await tester.pumpAndSettle();

    expect(find.byType(ContactRow), findsOneWidget);
    expect(find.text('Bruno Leroy'), findsOneWidget);
  });

  testWidgets('search ignores accents and case', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'HELENE');
    await tester.pumpAndSettle();

    expect(find.byType(ContactRow), findsOneWidget);
    expect(find.text('Hélène Petit'), findsOneWidget);
  });

  testWidgets('nothing matching says so in one line', (tester) async {
    await _pump(tester);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.byType(ContactRow), findsNothing);
    expect(find.text('Nobody matches.'), findsOneWidget);
  });

  testWidgets('an empty book offers to add someone', (tester) async {
    var adds = 0;
    await _pump(tester, people: const [], onAdd: () => adds++);

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add someone'));
    expect(adds, 1);
  });

  testWidgets('tapping a row opens that person', (tester) async {
    Person? opened;
    await _pump(tester, onOpen: (person) => opened = person);

    await tester.tap(find.text('Bruno Leroy'));

    expect(opened?.id, '2');
  });

  testWidgets('pulling down refreshes', (tester) async {
    var refreshes = 0;
    await _pump(tester, onRefresh: () async => refreshes++);

    await tester.fling(find.text('Anne Martin'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(refreshes, 1);
  });

  testWidgets('a paused prospect reads Not now · paused in July', (
    tester,
  ) async {
    await _pump(
      tester,
      people: [
        Person(
          id: 'p1',
          name: 'Sarah Martin',
          stage: Stage.prospect,
          prospectStatus: ProspectStatus.notNow,
          stageSince: DateTime.utc(2026, 3, 4),
          pausedAt: DateTime(2026, 7, 12),
        ),
      ],
    );

    expect(find.text('Not now · paused in July'), findsOneWidget);
  });

  testWidgets('the import is in the toolbar and the empty state', (
    tester,
  ) async {
    var imports = 0;
    await _pump(tester, people: const [], onImport: () => imports++);

    await tester.tap(find.byTooltip('Import from your contacts'));
    await tester.tap(
      find.widgetWithText(TextButton, 'Import from your contacts'),
    );

    expect(imports, 2);
  });

  testWidgets('no import without an address book', (tester) async {
    await _pump(tester, people: const []);

    expect(find.text('Import from your contacts'), findsNothing);
    expect(find.byTooltip('Import from your contacts'), findsNothing);
  });

  group('picking several', () {
    testWidgets('a long press starts it; a tap then picks, not opens', (
      tester,
    ) async {
      Person? opened;
      final picking = <bool>[];
      await _pump(
        tester,
        onOpen: (person) => opened = person,
        onPickingChanged: picking.add,
      );

      await tester.longPress(find.text('Anne Martin'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);

      await tester.tap(find.text('Bruno Leroy'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      expect(opened, isNull);
      expect(picking, [true]);
    });

    testWidgets('a picked avatar turns into a check', (tester) async {
      await _pump(tester);

      await tester.longPress(find.text('Anne Martin'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byType(LoomiaAvatar), findsNWidgets(2));
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('unpicking the last one ends it', (tester) async {
      final picking = <bool>[];
      await _pump(tester, onPickingChanged: picking.add);

      await tester.longPress(find.text('Anne Martin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anne Martin'));
      await tester.pumpAndSettle();

      expect(find.text('Contacts'), findsOneWidget);
      expect(picking, [true, false]);
    });

    testWidgets('✕ ends it', (tester) async {
      await _pump(tester);

      await tester.longPress(find.text('Anne Martin'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Stop selecting'));
      await tester.pumpAndSettle();

      expect(find.text('Contacts'), findsOneWidget);
    });

    testWidgets('Select starts it where there is a mouse, not on a phone', (
      tester,
    ) async {
      await _pump(tester, size: _phone);
      expect(find.text('Select'), findsNothing);

      await _pump(tester);
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('0 selected'), findsOneWidget);
    });

    testWidgets('Select all picks who the filter shows', (tester) async {
      await _pump(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Customers'));
      await tester.pump();
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('on a phone the actions are a labelled bar at the bottom', (
      tester,
    ) async {
      await _pump(tester, size: _phone);

      await tester.longPress(find.text('Anne Martin'));
      await tester.pumpAndSettle();

      for (final label in ['Move to…', 'Change workflow', 'Delete']) {
        expect(find.text(label), findsOneWidget);
      }
      expect(
        tester.getTopLeft(find.text('Delete')).dy,
        greaterThan(tester.getTopLeft(find.text('Bruno Leroy')).dy),
      );
    });

    testWidgets('Move to… offers only stages someone is not in, and moves '
        'only them', (tester) async {
      (List<Person>, Stage)? moved;
      await _pump(
        tester,
        onMove: (people, stage) async {
          moved = (people, stage);
          return true;
        },
      );

      await tester.longPress(find.text('Anne Martin'));
      await tester.pump();
      await tester.tap(find.text('Bruno Leroy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to…'));
      await tester.pumpAndSettle();

      expect(find.text('Move 2 people to…'), findsOneWidget);
      expect(
        find.text('1 of 2 moves, the others are there already'),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: find.byType(LoomiaDialog),
          matching: find.text('Team'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(LoomiaDialog),
          matching: find.text('Customers'),
        ),
      );
      await tester.pumpAndSettle();

      expect([for (final person in moved!.$1) person.id], ['1']);
      expect(moved!.$2, Stage.customer);
      // Done: the picking ends.
      expect(find.text('Contacts'), findsOneWidget);
    });

    testWidgets('a move not done keeps the picking', (tester) async {
      await _pump(tester, onMove: (_, _) async => false);

      await tester.longPress(find.text('Anne Martin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Move to…'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(LoomiaDialog),
          matching: find.text('Prospects'),
        ),
        findsNothing,
      );
      await tester.tap(
        find.descendant(
          of: find.byType(LoomiaDialog),
          matching: find.text('Team'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('workflow only for people in one stage', (tester) async {
      List<Person>? changed;
      await _pump(
        tester,
        onChangeWorkflow: (people) async {
          changed = people;
          return true;
        },
      );
      ButtonStyleButton workflow() => tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Workflow'),
          matching: find.bySubtype<ButtonStyleButton>(),
        ),
      );

      await tester.longPress(find.text('Anne Martin'));
      await tester.pump();
      await tester.tap(find.text('Bruno Leroy'));
      await tester.pumpAndSettle();
      expect(workflow().onPressed, isNull);

      await tester.tap(find.text('Bruno Leroy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Workflow'));
      await tester.pumpAndSettle();

      expect([for (final person in changed!) person.id], ['1']);
    });

    testWidgets('delete asks first', (tester) async {
      List<Person>? deleted;
      await _pump(
        tester,
        size: _phone,
        onDelete: (people) async {
          deleted = people;
          return true;
        },
      );

      await tester.longPress(find.text('Anne Martin'));
      await tester.pump();
      await tester.tap(find.text('Bruno Leroy'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete 2 people?'), findsOneWidget);
      expect(deleted, isNull);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect([for (final person in deleted!) person.id], ['1', '2']);
    });
  });
}
