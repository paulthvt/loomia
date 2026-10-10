import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/loyalty_sheet.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import '../fake_people_repository.dart';
import 'form_harness.dart';

Person _claire({DateTime? loyaltySince}) => Person(
  id: 'p1',
  name: 'Claire Moreau',
  stage: Stage.customer,
  stageSince: DateTime.utc(2026, 3, 4),
  loyaltySince: loyaltySince,
);

void main() {
  late FakePeopleRepository people;

  Future<void> open(WidgetTester tester, Person person) async {
    people = FakePeopleRepository([person]);
    await pumpFormHarness(
      tester,
      people: people,
      account: const Account(
        firstName: 'Pauline',
        email: 'p@example.com',
        businessModel: BusinessModel.doterra,
      ),
      open: (context) => showLoyalty(context, person),
      result: (_) {},
    );
  }

  testWidgets('not set: today by default, Save starts it, no stop', (
    tester,
  ) async {
    await open(tester, _claire());
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text('When did it start?'), findsOneWidget);
    expect(find.text(l10n.logWhenToday(today())), findsOneWidget);
    expect(find.text('Stopped their LRP'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('setLoyalty(p1)'));
    expect(people.store['p1']!.loyaltySince, today());
    expect(find.text('When did it start?'), findsNothing);
  });

  testWidgets('set: the stored day, and Stopped their LRP stops it', (
    tester,
  ) async {
    final since = DateTime(2026, 10, 2);
    await open(tester, _claire(loyaltySince: since));
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    expect(find.text(dayLabel(l10n, since, today())), findsOneWidget);
    await tester.tap(find.text('Stopped their LRP'));
    await tester.pumpAndSettle();

    expect(people.calls, contains('setLoyalty(p1)'));
    expect(people.store['p1']!.loyaltySince, isNull);
    expect(find.text('When did it start?'), findsNothing);
  });

  testWidgets('a failure says so and keeps the sheet open', (tester) async {
    await open(tester, _claire());
    people.failWith = PeopleFailure.network;

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(
      find.text("Couldn't save. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.text('When did it start?'), findsOneWidget);
  });
}
