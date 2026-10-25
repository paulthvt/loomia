import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/tasks/data/task_repository.dart';
import 'package:loomia/features/tasks/presentation/task_sheet.dart';
import 'package:loomia/features/tasks/presentation/tasks_controller.dart';
import 'package:loomia/features/workflows/domain/progress.dart' show addDays;
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

import '../../auth/fake_auth_repository.dart';
import '../fake_task_repository.dart';

const _account = Account(firstName: 'Pauline', email: 'p@example.com');

String _written(DateTime day) =>
    (day.year == today().year
            ? DateFormat.MMMMEEEEd('en')
            : DateFormat.yMMMMEEEEd('en'))
        .format(day);

Future<void> _pumpHarness(
  WidgetTester tester, {
  required FakeTaskRepository tasks,
  required Future<void> Function(BuildContext context) open,
}) async {
  final auth = FakeAuthRepository()
    ..session = true
    ..account = _account;
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        taskRepositoryProvider.overrideWithValue(tasks),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light,
        home: Consumer(
          builder: (context, ref, _) {
            // Load the provider like the real screen would.
            ref.watch(tasksProvider(ref.watch(accountProvider)?.email));
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async => open(context),
                  child: const Text('Open'),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  late FakeTaskRepository tasks;

  final whatField = find.descendant(
    of: find.widgetWithText(LabeledField, 'What'),
    matching: find.byType(TextFormField),
  );

  final noteField = find.descendant(
    of: find.widgetWithText(LabeledField, 'Note (optional)'),
    matching: find.byType(TextFormField),
  );

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
  }

  setUp(() => tasks = FakeTaskRepository());

  testWidgets('new task: "  " shows taskTitleRequired and saves nothing', (
    tester,
  ) async {
    final day = DateTime(2026, 10, 30);
    await _pumpHarness(
      tester,
      tasks: tasks,
      open: (context) => showTask(context, day: day),
    );

    expect(find.text('New task'), findsOneWidget);
    await tester.enterText(whatField, '  ');
    await save(tester);

    expect(find.text('Say what to do'), findsOneWidget);
    expect(tasks.calls.where((c) => c.startsWith('add')), isEmpty);
  });

  testWidgets('new task: "  Order flyers " saves trimmed with given day', (
    tester,
  ) async {
    final day = DateTime(2026, 10, 30);
    await _pumpHarness(
      tester,
      tasks: tasks,
      open: (context) => showTask(context, day: day),
    );

    await tester.enterText(whatField, '  Order flyers ');
    await save(tester);

    expect(tasks.calls, contains('add(Order flyers, 2026-10-30)'));
    expect(tasks.store.values.first.title, 'Order flyers');
    expect(tasks.store.values.first.note, isNull);
    expect(tasks.store.values.first.dueOn, day);
    expect(find.text('New task'), findsNothing);
  });

  testWidgets('new task: note "  " saves as null', (tester) async {
    final day = DateTime(2026, 11, 1);
    await _pumpHarness(
      tester,
      tasks: tasks,
      open: (context) => showTask(context, day: day),
    );

    await tester.enterText(whatField, 'Buy stamps');
    await tester.enterText(noteField, '  ');
    await save(tester);

    expect(tasks.store.values.first.title, 'Buy stamps');
    expect(tasks.store.values.first.note, isNull);
  });

  testWidgets('new task: note with text saves trimmed', (tester) async {
    final day = DateTime(2026, 11, 1);
    await _pumpHarness(
      tester,
      tasks: tasks,
      open: (context) => showTask(context, day: day),
    );

    await tester.enterText(whatField, 'Buy stamps');
    await tester.enterText(noteField, '  At the post office  ');
    await save(tester);

    expect(tasks.store.values.first.note, 'At the post office');
  });

  testWidgets('editing: shows title, note and day', (tester) async {
    final task = await tasks.add((
      title: 'Review contract',
      note: 'Check clause 3',
      dueOn: DateTime(2026, 11, 5),
    ));
    await _pumpHarness(
      tester,
      tasks: tasks,
      open: (context) =>
          showTask(context, day: DateTime(2026, 11, 1), editing: task),
    );

    expect(find.text('Edit task'), findsOneWidget);
    expect(find.text('Review contract'), findsOneWidget);
    expect(find.text('Check clause 3'), findsOneWidget);
    expect(find.text(_written(DateTime(2026, 11, 5))), findsOneWidget);
  });

  testWidgets('editing: Save writes the change', (tester) async {
    final task = await tasks.add((
      title: 'Old title',
      note: 'Old note',
      dueOn: DateTime(2026, 11, 5),
    ));
    await _pumpHarness(
      tester,
      tasks: tasks,
      open: (context) =>
          showTask(context, day: DateTime(2026, 11, 1), editing: task),
    );

    await tester.enterText(whatField, 'New title');
    await tester.enterText(noteField, 'New note');
    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    await save(tester);

    expect(
      tasks.calls.last,
      'update(${task.id}, New title, ${_day(addDays(today(), 1))})',
    );
    expect(tasks.store[task.id]!.title, 'New title');
    expect(tasks.store[task.id]!.note, 'New note');
    expect(find.text('Edit task'), findsNothing);
  });

  testWidgets('editing: Delete asks then removes', (tester) async {
    final task = await tasks.add((
      title: 'Old task',
      note: null,
      dueOn: DateTime(2026, 11, 5),
    ));
    await _pumpHarness(
      tester,
      tasks: tasks,
      open: (context) =>
          showTask(context, day: DateTime(2026, 11, 1), editing: task),
    );

    await tester.tap(find.text('Delete').first);
    await tester.pumpAndSettle();

    expect(find.text('Delete this task?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(tasks.calls.last, 'delete(${task.id})');
    expect(tasks.store, isEmpty);
    expect(find.text('Edit task'), findsNothing);
  });

  testWidgets('failed save shows failure copy and keeps sheet open', (
    tester,
  ) async {
    tasks.failWith = PeopleFailure.network;
    await _pumpHarness(
      tester,
      tasks: tasks,
      open: (context) => showTask(context, day: DateTime(2026, 11, 1)),
    );

    await tester.enterText(whatField, 'Test task');
    await save(tester);

    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('New task'), findsOneWidget);
  });
}

String _day(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
