import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contact_details.dart';
import 'package:loomia/features/contacts/presentation/edit_person_form.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

Person _person({
  Stage stage = Stage.prospect,
  ProspectStatus? status,
  String? phone,
  String? email,
  String? instagram,
  String? needs,
  String? ownGoal,
  String? stuckOn,
  DateTime? pausedAt,
}) => Person(
  id: 'p1',
  name: 'Marie Dupont',
  stage: stage,
  stageSince: DateTime.utc(2026, 3, 4),
  prospectStatus: status,
  phone: phone,
  email: email,
  instagram: instagram,
  needs: needs,
  ownGoal: ownGoal,
  stuckOn: stuckOn,
  pausedAt: pausedAt,
);

class _Calls {
  final statuses = <ProspectStatus?>[];
  final launched = <Uri>[];
  final edits = <EditPart>[];
  var deletes = 0;
  var logs = 0;
  final moves = <Stage>[];
  var workflowChanges = 0;
  var pauses = 0;
  var resumes = 0;
}

Future<_Calls> _pump(
  WidgetTester tester,
  Person person, {
  Size size = const Size(800, 600),
  String? workflowName,
  BusinessModel model = BusinessModel.other,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final calls = _Calls();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      home: Scaffold(
        body: ContactDetails(
          person: person,
          model: model,
          onStatus: calls.statuses.add,
          onEdit: calls.edits.add,
          onDelete: () => calls.deletes++,
          onLog: () => calls.logs++,
          onMove: calls.moves.add,
          onLaunch: calls.launched.add,
          onRefresh: () async {},
          onChangeWorkflow: () => calls.workflowChanges++,
          onPause: () => calls.pauses++,
          onResume: () => calls.resumes++,
          workflowName: workflowName,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('the header says the stage and since when', (tester) async {
    await _pump(tester, _person());

    expect(find.text('Marie Dupont'), findsOneWidget);
    expect(find.text('Prospect since March 2026'), findsOneWidget);
  });

  testWidgets('a status chip saves it; tapping it again clears it', (
    tester,
  ) async {
    final calls = await _pump(
      tester,
      _person(status: ProspectStatus.interested),
    );

    await tester.tap(find.widgetWithText(ChoiceChip, 'Thinking about it'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Interested'));

    expect(calls.statuses, [ProspectStatus.thinking, null]);
  });

  testWidgets('customers have no status chips', (tester) async {
    await _pump(tester, _person(stage: Stage.customer));

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('WHERE IT STANDS'), findsNothing);
  });

  testWidgets('no channel, no Message or Call', (tester) async {
    await _pump(tester, _person());

    expect(find.text('Message'), findsNothing);
    expect(find.text('Call'), findsNothing);
  });

  testWidgets('a phone gives Call and Message by text', (tester) async {
    final calls = await _pump(tester, _person(phone: '06 12 34 56 78'));

    await tester.tap(find.text('Call'));
    await tester.tap(find.text('Message'));

    expect(calls.launched, [
      Uri(scheme: 'tel', path: '0612345678'),
      Uri(scheme: 'sms', path: '0612345678'),
    ]);
  });

  testWidgets('Instagram only gives Message on Instagram', (tester) async {
    final calls = await _pump(tester, _person(instagram: 'marie.d'));

    expect(find.text('Call'), findsNothing);
    await tester.tap(find.text('Message'));

    expect(calls.launched, [Uri.https('instagram.com', '/marie.d')]);
  });

  testWidgets('a typed @ is stripped from the Instagram link', (tester) async {
    final calls = await _pump(tester, _person(instagram: '@marie.d'));

    await tester.tap(find.text('Message'));

    expect(calls.launched, [Uri.https('instagram.com', '/marie.d')]);
  });

  testWidgets('an email opens the mail app', (tester) async {
    final calls = await _pump(tester, _person(email: 'marie@example.com'));

    await tester.tap(find.text('marie@example.com'));

    expect(calls.launched, [Uri(scheme: 'mailto', path: 'marie@example.com')]);
  });

  testWidgets('filled facts only, or "Nothing yet"', (tester) async {
    await _pump(tester, _person());
    expect(find.text('Nothing yet.'), findsOneWidget);

    await _pump(tester, _person(needs: 'Sleep, stress'));
    expect(find.text('Nothing yet.'), findsNothing);
    expect(find.text('Needs'), findsOneWidget);
    expect(find.text('Sleep, stress'), findsOneWidget);
    expect(find.text('Phone'), findsNothing);
  });

  testWidgets('a team member: what they are aiming for, filled facts only', (
    tester,
  ) async {
    await _pump(
      tester,
      _person(
        stage: Stage.team,
        ownGoal: 'Pay for the holidays',
        stuckOn: 'Talking about it',
      ),
    );

    expect(find.text('WHAT THEY ARE AIMING FOR'), findsOneWidget);
    expect(find.text('Their own goal'), findsOneWidget);
    expect(find.text('Pay for the holidays'), findsOneWidget);
    expect(find.text('Where they are stuck'), findsOneWidget);
    expect(find.text('Their why'), findsNothing);
    // Above what you know.
    expect(
      tester.getTopLeft(find.text('WHAT THEY ARE AIMING FOR')).dy,
      lessThan(tester.getTopLeft(find.text('WHAT YOU KNOW')).dy),
    );
  });

  testWidgets('a team member with no profile yet still gets the section', (
    tester,
  ) async {
    final calls = await _pump(tester, _person(stage: Stage.team));

    expect(find.text('WHAT THEY ARE AIMING FOR'), findsOneWidget);
    expect(find.text('Nothing yet.'), findsNWidgets(2));
    await tester.tap(find.text('Edit').first);
    await tester.tap(find.text('Edit').last);
    // Each section edits its own facts.
    expect(calls.edits, [EditPart.aims, EditPart.facts]);
  });

  Person member({
    Stage stage = Stage.team,
    String? currentLevel = 'Executive',
    DateTime? by,
    double? volume = 100,
  }) => Person(
    id: 'p1',
    name: 'Claire Martin',
    stage: stage,
    stageSince: DateTime.utc(2026, 3, 4),
    why: 'More time with my kids',
    ownGoal: 'Pay for the holidays',
    currentLevel: currentLevel,
    targetLevel: 'Elite',
    targetLevelBy: by,
    monthlyVolumeTarget: volume,
  );

  testWidgets('dōTERRA: rank now, aiming for by a month, PV each month', (
    tester,
  ) async {
    await _pump(
      tester,
      member(by: DateTime(2027, 3)),
      model: BusinessModel.doterra,
    );

    expect(find.text('Rank now'), findsOneWidget);
    expect(find.text('Executive'), findsOneWidget);
    expect(find.text('Aiming for'), findsOneWidget);
    expect(find.text('Elite by March 2027'), findsOneWidget);
    expect(find.text('Each month'), findsOneWidget);
    expect(find.text('Aims for 100 PV'), findsOneWidget);
    // After their why, before their own goal.
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Their why'), lessThan(top('Rank now')));
    expect(top('Rank now'), lessThan(top('Aiming for')));
    expect(top('Aiming for'), lessThan(top('Each month')));
    expect(top('Each month'), lessThan(top('Their own goal')));
  });

  testWidgets('Other: level now, a target with no month, a bare number', (
    tester,
  ) async {
    await _pump(tester, member(volume: 99.5));

    expect(find.text('Level now'), findsOneWidget);
    expect(find.text('Rank now'), findsNothing);
    expect(find.text('Elite'), findsOneWidget);
    expect(find.text('Aims for 99.5'), findsOneWidget);
  });

  testWidgets('an unknown rank reads as stored', (tester) async {
    await _pump(
      tester,
      member(currentLevel: 'Wellness Advocate'),
      model: BusinessModel.doterra,
    );

    expect(find.text('Wellness Advocate'), findsOneWidget);
  });

  testWidgets('no rank and no volume: those rows are left out', (tester) async {
    await _pump(
      tester,
      member(currentLevel: null, volume: null),
      model: BusinessModel.doterra,
    );

    expect(find.text('Rank now'), findsNothing);
    expect(find.text('Each month'), findsNothing);
    expect(find.text('Aiming for'), findsOneWidget);
  });

  testWidgets('a customer shows no rank, even if saved', (tester) async {
    await _pump(
      tester,
      member(stage: Stage.customer, by: DateTime(2027, 3)),
      model: BusinessModel.doterra,
    );

    expect(find.text('Executive'), findsNothing);
    expect(find.text('Elite by March 2027'), findsNothing);
    expect(find.text('Aims for 100 PV'), findsNothing);
  });

  testWidgets('not on the team: no aims, even if saved', (tester) async {
    await _pump(
      tester,
      _person(stage: Stage.customer, ownGoal: 'Pay for the holidays'),
    );

    expect(find.text('WHAT THEY ARE AIMING FOR'), findsNothing);
    expect(find.text('Pay for the holidays'), findsNothing);
  });

  testWidgets('Edit in the section header and in ⋯ both edit', (tester) async {
    final calls = await _pump(tester, _person());

    await tester.tap(find.text('Edit'));
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();

    expect(calls.edits, [EditPart.facts, EditPart.everything]);
  });

  testWidgets('Delete asks first; Cancel keeps the person', (tester) async {
    final calls = await _pump(tester, _person());

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Marie'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Marie Dupont?'), findsOneWidget);
    expect(find.text('Their details are removed for good.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls.deletes, 0);

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Marie'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(calls.deletes, 1);
  });

  testWidgets('⋯ menu: Log, a Move row per other stage, Edit, Delete', (
    tester,
  ) async {
    final calls = await _pump(tester, _person());

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();

    expect(find.text('Log something'), findsOneWidget);
    expect(find.text('Move to prospects'), findsNothing);
    expect(find.text('Move to customers'), findsOneWidget);
    expect(find.text('Move to team'), findsOneWidget);
    expect(find.text('Edit details'), findsOneWidget);
    expect(find.text('Delete Marie'), findsOneWidget);
    await tester.tap(find.text('Move to team'));
    await tester.pumpAndSettle();

    expect(calls.moves, [Stage.team]);
  });

  testWidgets('mobile: ⋯ is a sheet titled with the name', (tester) async {
    final calls = await _pump(
      tester,
      _person(stage: Stage.customer),
      size: const Size(390, 844),
    );

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Marie Dupont'), findsNWidgets(2));
    expect(find.text('Move to prospects'), findsOneWidget);
    expect(find.text('Move to customers'), findsNothing);
    expect(find.text('Move to team'), findsOneWidget);
    await tester.tap(find.text('Log something'));
    await tester.pumpAndSettle();

    expect(calls.logs, 1);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('mobile: Delete in the sheet still asks first', (tester) async {
    final calls = await _pump(tester, _person(), size: const Size(390, 844));

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Marie'));
    await tester.pumpAndSettle();

    expect(find.text('Delete Marie Dupont?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(calls.deletes, 1);
  });

  testWidgets('mobile: Cancel closes the sheet and does nothing', (
    tester,
  ) async {
    final calls = await _pump(tester, _person(), size: const Size(390, 844));

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsNothing);
    expect(
      calls.logs + calls.edits.length + calls.deletes + calls.moves.length,
      0,
    );
  });

  testWidgets('⋯: Change workflow names the current one, then Pause', (
    tester,
  ) async {
    final calls = await _pump(tester, _person(), workflowName: 'Samples');

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Samples'), findsOneWidget);
    expect(find.text('Resume'), findsNothing);
    await tester.tap(find.text('Pause — not now'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change workflow'));
    await tester.pumpAndSettle();

    expect(calls.pauses, 1);
    expect(calls.workflowChanges, 1);
  });

  testWidgets('mobile ⋯, paused: Resume instead of Pause', (tester) async {
    final calls = await _pump(
      tester,
      _person(pausedAt: DateTime.utc(2026, 7, 12)),
      size: const Size(390, 844),
    );

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    expect(find.text('Pause — not now'), findsNothing);
    await tester.tap(find.text('Resume'));
    await tester.pumpAndSettle();

    expect(calls.resumes, 1);
  });

  testWidgets('large text: Message and Call stack, one line each', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _pump(
      tester,
      _person(phone: '06 12 34 56 78'),
      size: const Size(390, 844),
    );

    final message = tester.getRect(find.text('Message'));
    final call = tester.getRect(find.text('Call'));
    expect(message.height, call.height, reason: 'no label wraps');
    expect(call.top, greaterThan(message.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop: the facts column is 340 wide, beside the next step', (
    tester,
  ) async {
    await _pump(tester, _person(), size: const Size(1440, 900));

    final facts = find.ancestor(
      of: find.text('WHAT YOU KNOW'),
      matching: find.byType(SectionHeader),
    );
    expect(tester.getSize(facts).width, 340);
    expect(
      tester.getTopLeft(find.text('WHERE IT STANDS')).dx,
      lessThan(tester.getTopLeft(facts).dx),
    );
  });
}
