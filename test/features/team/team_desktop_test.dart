import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/team/presentation/team_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  final today = DateTime(2026, 9, 29);
  Person member(String name, {DateTime? talked}) => Person(
    id: name,
    name: name,
    stage: Stage.team,
    stageSince: DateTime(2026, 5),
    lastContactOn: talked,
  );

  Future<void> pumpAt(WidgetTester tester, Size size) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: TeamView(
          people: AsyncData([
            member('Janine', talked: DateTime(2026, 9, 1)),
            member('Jeanne', talked: DateTime(2026, 9, 28)),
          ]),
          today: today,
          onOpen: (_) {},
          onRetry: () {},
          onCheckIn: (_) {},
          onRefresh: () async {},
        ),
      ),
    );
  }

  testWidgets('desktop: roster left, summary and check-ins right', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1440, 900));

    final everyone = tester.getTopLeft(find.text('EVERYONE')).dx;
    expect(
      tester.getTopLeft(find.text('WORTH A CHECK-IN')).dx,
      greaterThan(everyone + 600),
    );
    expect(
      tester.getTopLeft(find.textContaining('people on your team')).dx,
      greaterThan(everyone + 600),
    );
  });

  testWidgets('a wide window: the title lines up with the roster', (
    tester,
  ) async {
    await pumpAt(tester, const Size(1920, 900));

    expect(
      tester.getTopLeft(find.text('Team').first).dx,
      moreOrLessEquals(tester.getTopLeft(find.text('EVERYONE')).dx, epsilon: 1),
    );
  });
}
