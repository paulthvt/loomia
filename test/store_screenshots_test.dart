import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:loomia/app/router/app_router.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/domain/account.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app_harness.dart';
import 'features/auth/fake_auth_repository.dart';
import 'features/calendar/fake_event_repository.dart';
import 'features/contacts/fake_activity_repository.dart';
import 'features/contacts/fake_people_repository.dart';
import 'load_fonts.dart';

/// Store listing screenshots: the whole app — navigation, account button — on
/// a sample book, every screen on every device in every app language. Written
/// to `build/store/<device>/<language>/`, numbered in listing order, never
/// compared. Skipped unless asked for:
///
///   flutter test test/store_screenshots_test.dart --dart-define=STORE_SCREENSHOTS=true
///
/// The dates follow the clock, so the header shows the day it ran.
void main() {
  // Logical size and pixel ratio. Play takes phone and both tablets (sides
  // within 2:1); desktop is for the web. No App Store sizes until there is an
  // iOS listing, it wants exact device ones.
  const devices = {
    'phone': (Size(360, 640), 3.0), // 1080×1920, bottom bar
    'tablet-7': (Size(600, 960), 2.0), // 1200×1920, icon rail
    'tablet-10': (Size(1280, 800), 2.0), // 2560×1600, sidebar
    'desktop': (Size(1440, 900), 2.0), // 2880×1800, sidebar
  };
  final screens = {
    'today': Routes.today,
    'contacts': Routes.contacts,
    'contact': Routes.contactLocation('marie'),
    'calendar': Routes.calendar,
  };

  setUpAll(loadAppFonts);

  for (final locale in AppLocalizations.supportedLocales) {
    final language = locale.languageCode;
    for (final MapEntry(key: device, value: (size, ratio)) in devices.entries) {
      for (final (index, MapEntry(key: screen, value: path))
          in screens.entries.indexed) {
        testWidgets('$device $language $screen', skip: !_store, (tester) async {
          final activities = FakeActivityRepository(_history());
          final container = await pumpLoomia(
            tester,
            size: size,
            pixelRatio: ratio,
            people: FakePeopleRepository(_book())..activities = activities,
            activities: activities,
            events: FakeEventRepository(_events()),
            auth: FakeAuthRepository()
              ..session = true
              ..account = Account(
                firstName: 'Pauline',
                email: 'pauline@example.com',
                locale: language,
                appearance: Appearance.light,
              ),
          );
          container.read(routerProvider).go(path);
          await tester.pumpAndSettle();

          final png = await tester.runAsync(() async {
            final image = await captureImage(
              find.byType(MaterialApp).evaluate().single,
            );
            return image.toByteData(format: ui.ImageByteFormat.png);
          });
          File('build/store/$device/$language/${index + 1}_$screen.png')
            ..createSync(recursive: true)
            ..writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
    }
  }
}

const _store = bool.fromEnvironment('STORE_SCREENSHOTS');

/// [ago] days since the last tick, at [at] of [workflow]. Steps are due their
/// days after the last tick (FakeWorkflowRepository.samples).
WorkflowPlace _place(String workflow, num at, int ago) =>
    (workflowId: workflow, atPosition: at, lastTick: addDays(today(), -ago));

List<Person> _book() => [
  Person(
    id: 'marie',
    name: 'Marie Dupont',
    stage: Stage.prospect,
    prospectStatus: ProspectStatus.thinking,
    phone: '06 12 34 56 78',
    email: 'marie@example.com',
    needs: 'Sleep, stress',
    profession: 'Nurse',
    notes: 'Met at the Saturday market. Asked about lavender.',
    stageSince: addDays(today(), -40),
    place: _place('samples', 4, 3),
  ),
  Person(
    id: 'sarah',
    name: 'Sarah Martin',
    stage: Stage.prospect,
    prospectStatus: ProspectStatus.interested,
    stageSince: addDays(today(), -9),
    place: _place('samples', 2, 4),
  ),
  Person(
    id: 'claire',
    name: 'Claire Dubois',
    stage: Stage.prospect,
    stageSince: addDays(today(), -2),
    place: _place('samples', 1, 1),
  ),
  Person(
    id: 'thomas',
    name: 'Thomas Petit',
    stage: Stage.prospect,
    profession: 'Physiotherapist',
    stageSince: addDays(today(), -12),
    place: _place('health', 2, 2),
  ),
  Person(
    id: 'lucas',
    name: 'Lucas Martin',
    stage: Stage.customer,
    products: 'Lavender, Peppermint',
    needs: 'Headaches',
    stageSince: addDays(today(), -60),
    place: _place('new-customer', 3, 14),
  ),
  Person(
    id: 'camille',
    name: 'Camille Roux',
    stage: Stage.customer,
    stageSince: addDays(today(), -120),
  ),
  Person(
    id: 'antoine',
    name: 'Antoine Girard',
    stage: Stage.prospect,
    prospectStatus: ProspectStatus.notNow,
    stageSince: addDays(today(), -30),
  ),
  Person(
    id: 'helene',
    name: 'Hélène Bernard',
    stage: Stage.team,
    profession: 'Yoga teacher',
    stageSince: addDays(today(), -6),
    place: _place('getting-started', 2, 5),
  ),
  Person(
    id: 'bruno',
    name: 'Bruno Keller',
    stage: Stage.team,
    stageSince: addDays(today(), -120),
  ),
  Person(
    id: 'lea',
    name: 'Léa Fontaine',
    stage: Stage.team,
    stageSince: addDays(today(), -42),
  ),
  Person(
    id: 'sophie',
    name: 'Sophie Laurent',
    stage: Stage.team,
    stageSince: addDays(today(), -200),
  ),
];

/// Talks with the team, for when you last talked, and Marie's history.
List<Activity> _history() => [
  for (final (person, ago, kind, text) in [
    ('marie', 3, ActivityKind.message, 'Sent the samples'),
    ('marie', 10, ActivityKind.note, 'Asked about lavender for sleep'),
    ('bruno', 19, ActivityKind.call, 'Planned the autumn workshop'),
    ('lea', 6, ActivityKind.call, 'Weekly catch-up'),
    ('sophie', 2, ActivityKind.message, 'Shared her first order'),
  ])
    Activity(
      id: '$person-$ago',
      personId: person,
      kind: kind,
      happenedOn: addDays(today(), -ago),
      createdAt: addDays(today(), -ago),
      text: text,
    ),
];

/// Today's workshop and training, and two more later in the month.
List<CalendarEvent> _events() {
  final day = today();
  DateTime at(int days, int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day + days, hour, minute);
  return [
    CalendarEvent(
      id: 'e1',
      title: 'Essential oils for sleep',
      startsAt: at(0, 19),
      endsAt: at(0, 21),
      place: 'Studio Lumière, Lyon',
    ),
    CalendarEvent(
      id: 'e2',
      title: 'New member training',
      startsAt: at(0, 14),
      endsAt: at(0, 15),
      link: 'https://meet.google.com/abc-defg-hij',
    ),
    CalendarEvent(
      id: 'e3',
      title: 'Product evening',
      startsAt: at(6, 19, 30),
      place: 'Chez Claire',
    ),
    CalendarEvent(id: 'e4', title: 'Workshop', startsAt: at(13, 19)),
  ];
}
