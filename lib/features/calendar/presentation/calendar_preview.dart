import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/event_page.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// The Calendar and an event, for `flutter widget-preview start`, on a fixed
/// day so the goldens never follow the clock: the Figma's October 2026,
/// today the 7th, the 8th selected. Nothing in the app imports this file.
@Preview(group: 'Calendar', name: 'Mobile — light', size: Size(390, 844))
Widget calendarMobileLight() => _app(AppTheme.light, _calendar());

@Preview(group: 'Calendar', name: 'Mobile — dark', size: Size(390, 844))
Widget calendarMobileDark() => _app(AppTheme.dark, _calendar());

@Preview(group: 'Calendar', name: 'Desktop — light', size: Size(1440, 900))
Widget calendarDesktopLight() => _app(
  AppTheme.light,
  _calendar(
    pane: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        DaySection(
          events: AsyncData(_events),
          day: _selected,
          onOpen: (_) {},
          onAdd: (_) {},
          onRetry: () {},
        ),
      ],
    ),
  ),
);

@Preview(group: 'Calendar', name: 'Event — light', size: Size(390, 844))
Widget eventMobileLight() => _app(
  AppTheme.light,
  Scaffold(
    appBar: AppBar(leading: const BackButton()),
    body: EventView(
      event: _events[1],
      people: _people.map((p) => (person: p, came: false)).toList(),
      now: DateTime(2026, 10, 7, 9),
      onAddPeople: () {},
      onRemove: (_) {},
      onOpenPerson: (_) {},
      onMarkDone: () {},
      onEdit: () {},
      onDelete: () {},
      onOpenPlace: (_) {},
      onJoin: (_) {},
      steps: _workshopSteps,
      onTick: (_, _) {},
      followUpNames: const {
        Stage.prospect: 'Samples',
        Stage.customer: 'New customer',
      },
    ),
  ),
);

@Preview(group: 'Calendar', name: 'Event done — light', size: Size(390, 844))
Widget eventDoneMobileLight() => _app(
  AppTheme.light,
  Scaffold(
    appBar: AppBar(leading: const BackButton()),
    body: EventView(
      event: CalendarEvent(
        id: _events[1].id,
        title: _events[1].title,
        startsAt: _events[1].startsAt,
        endsAt: _events[1].endsAt,
        place: _events[1].place,
        link: _events[1].link,
        notes: _events[1].notes,
        attendees: [
          (personId: 'p1', came: true), // Claire
          (personId: 'p2', came: false), // Amélie
          (personId: 'p3', came: true), // Sarah
          (personId: 'p4', came: true), // Marie
          (personId: 'p5', came: true), // Bruno
        ],
        doneAt: DateTime(2026, 10, 9, 9),
        stepsDone: {..._events[1].stepsDone, 'thank': DateTime(2026, 10, 9)},
      ),
      people: [
        (person: _people[0], came: false), // Amélie
        (person: _people[1], came: true), // Bruno
        (person: _people[2], came: true), // Claire
        (person: _people[3], came: true), // Marie
        (person: _people[4], came: true), // Sarah
      ],
      now: DateTime(2026, 10, 9, 9),
      onAddPeople: () {},
      onRemove: (_) {},
      onOpenPerson: (_) {},
      onMarkDone: () {},
      onEdit: () {},
      onDelete: () {},
      onOpenPlace: (_) {},
      onJoin: (_) {},
      steps: _workshopSteps,
      onTick: (_, _) {},
      followUpNames: const {
        Stage.prospect: 'Samples',
        Stage.customer: 'New customer',
      },
    ),
  ),
);

final _today = DateTime(2026, 10, 7);
final _selected = DateTime(2026, 10, 8);

/// Five people as in the Figma: sorted by name.
final _people = [
  Person(
    id: 'p2',
    name: 'Amélie Rousseau',
    stage: Stage.prospect,
    stageSince: DateTime(2026, 9),
  ),
  Person(
    id: 'p5',
    name: 'Bruno Keller',
    stage: Stage.team,
    stageSince: DateTime(2026, 9),
  ),
  Person(
    id: 'p1',
    name: 'Claire Moreau',
    stage: Stage.prospect,
    stageSince: DateTime(2026, 9),
  ),
  Person(
    id: 'p4',
    name: 'Marie Dupont',
    stage: Stage.customer,
    stageSince: DateTime(2026, 9),
  ),
  Person(
    id: 'p3',
    name: 'Sarah Lemaire',
    stage: Stage.prospect,
    stageSince: DateTime(2026, 9),
  ),
];

/// As in the Figma: a done event on the 3rd, two on the 8th, one on the
/// 14th, two on the 21st, one on the 27th.
final _events = [
  CalendarEvent(
    id: 'e0',
    title: 'Workshop',
    startsAt: DateTime(2026, 10, 3, 10),
  ),
  CalendarEvent(
    id: 'e1',
    title: 'Essential oils for sleep',
    startsAt: DateTime(2026, 10, 8, 19),
    endsAt: DateTime(2026, 10, 8, 21),
    place: 'Studio Lumière, 4 rue Mercière, Lyon',
    link: 'https://meet.google.com/abc-defg-hij',
    notes: 'Bring the diffuser and ten sample vials. Doors open at 18:45.',
    attendees: [
      (personId: 'p1', came: false),
      (personId: 'p2', came: false),
      (personId: 'p3', came: false),
      (personId: 'p4', came: false),
      (personId: 'p5', came: false),
    ],
    eventWorkflowId: 'workshop',
    followUps: const {
      Stage.prospect: 'samples',
      Stage.customer: 'new-customer',
    },
    stepsDone: {'remind': DateTime(2026, 10, 7)},
  ),
  CalendarEvent(
    id: 'e2',
    title: 'New member training',
    startsAt: DateTime(2026, 10, 8, 14),
    endsAt: DateTime(2026, 10, 8, 15),
    link: 'https://meet.google.com/abc-defg-hij',
    attendees: [
      (personId: 'p1', came: false),
      (personId: 'p3', came: false),
      (personId: 'p5', came: false),
    ],
  ),
  CalendarEvent(
    id: 'e3',
    title: 'Product evening',
    startsAt: DateTime(2026, 10, 14, 19, 30),
  ),
  CalendarEvent(
    id: 'e4',
    title: 'Workshop',
    startsAt: DateTime(2026, 10, 21, 10),
  ),
  CalendarEvent(
    id: 'e5',
    title: 'Training',
    startsAt: DateTime(2026, 10, 21, 18),
  ),
  CalendarEvent(
    id: 'e6',
    title: 'Workshop',
    startsAt: DateTime(2026, 10, 27, 19),
  ),
];

final _workshopSteps = [
  const EventWorkflowStep(
    id: 'remind',
    label: "Remind everyone it's tomorrow",
    days: -1,
  ),
  const EventWorkflowStep(
    id: 'thank',
    label: 'Send a thank-you and the notes',
    days: 1,
  ),
];

Widget _calendar({Widget? pane}) => CalendarView(
  events: AsyncData(_events),
  selection: (month: DateTime(2026, 10), day: _selected),
  today: _today,
  onSelect: (_) {},
  onShift: (_) {},
  onToday: () {},
  onOpen: (_) {},
  onAdd: (_) {},
  onRetry: () {},
  pane: pane,
);

Widget _app(ThemeData theme, Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // The preview is its own app: without the delegates, any component that
    // reads AppLocalizations throws here.
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: home,
  );
}
