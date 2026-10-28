import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/calendar/domain/people_ahead.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/calendar/presentation/calendar_page.dart';
import 'package:loomia/features/calendar/presentation/event_page.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/task_page.dart';
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
Widget calendarDesktopLight() => _app(AppTheme.light, _calendar(desktop: true));

@Preview(group: 'Calendar', name: 'Week — light', size: Size(390, 844))
Widget calendarWeekLight() =>
    _app(AppTheme.light, _calendar(mode: CalendarMode.week));

@Preview(group: 'Calendar', name: 'Week desktop — light', size: Size(1440, 900))
Widget calendarWeekDesktopLight() =>
    _app(AppTheme.light, _calendar(mode: CalendarMode.week, desktop: true));

@Preview(group: 'Calendar', name: 'Event — light', size: Size(390, 844))
Widget eventMobileLight() => _app(
  AppTheme.light,
  Scaffold(
    appBar: AppBar(leading: const BackButton()),
    body: EventView(
      event: _events[1],
      people: eventPeople(_events[1], _people),
      now: DateTime(2026, 10, 7, 9),
      onAddPeople: () {},
      onRemove: (_) {},
      onGoing: (_) {},
      onFollowedUp: (_) {},
      onOpenPerson: (_) {},
      onMarkDone: () {},
      onEdit: () {},
      onDelete: () {},
      onOpenPlace: (_) {},
      onJoin: (_) {},
      steps: _workshopSteps,
      onTick: (_, _) {},
    ),
  ),
);

@Preview(group: 'Calendar', name: 'Event done — light', size: Size(390, 844))
Widget eventDoneMobileLight() => _app(
  AppTheme.light,
  Scaffold(
    appBar: AppBar(leading: const BackButton()),
    body: EventView(
      event: _done,
      people: eventPeople(_done, _people),
      now: DateTime(2026, 10, 9, 9),
      onAddPeople: () {},
      onRemove: (_) {},
      onGoing: (_) {},
      onFollowedUp: (_) {},
      onOpenPerson: (_) {},
      onMarkDone: () {},
      onEdit: () {},
      onDelete: () {},
      onOpenPlace: (_) {},
      onJoin: (_) {},
      steps: _workshopSteps,
      onTick: (_, _) {},
    ),
  ),
);

/// A task's page (#390): timed, its bell on, repeating, with a note.
@Preview(group: 'Calendar', name: 'Task — light', size: Size(390, 844))
Widget taskMobileLight() => _app(
  AppTheme.light,
  Scaffold(
    appBar: AppBar(leading: const BackButton()),
    body: TaskView(
      task: Task(
        id: 't5',
        title: 'Call the supplier',
        note: 'Ask about the 10 ml bottles',
        dueOn: DateTime(2026, 10, 22),
        doneOn: null,
        createdAt: DateTime(2026, 10, 5),
        dueTime: (hour: 14, minute: 0),
        repeat: (
          every: 1,
          unit: RepeatUnit.week,
          from: DateTime(2026, 10, 22),
          until: null,
          scheduledOn: DateTime(2026, 10, 22),
        ),
      ),
      now: DateTime(2026, 10, 20, 9),
      busy: false,
      onTick: () {},
      onEdit: () {},
      onDelete: () {},
      onPostpone: (_) {},
    ),
  ),
);

final _done = CalendarEvent(
  id: _events[1].id,
  title: _events[1].title,
  startsAt: _events[1].startsAt,
  endsAt: _events[1].endsAt,
  place: _events[1].place,
  link: _events[1].link,
  notes: _events[1].notes,
  attendees: [
    const Attendee(personId: 'p1', came: true), // Claire
    const Attendee(personId: 'p2', came: false), // Amélie
    const Attendee(personId: 'p3', came: true), // Sarah
    const Attendee(personId: 'p4', came: true), // Marie
    const Attendee(personId: 'p5', came: true), // Bruno
  ],
  doneAt: DateTime(2026, 10, 9, 9),
  stepsDone: {..._events[1].stepsDone, 'thank': DateTime(2026, 10, 9)},
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
    // As in Figma "Event — invited / going": two going, three invited.
    attendees: [
      const Attendee(personId: 'p1'), // Claire
      Attendee(
        personId: 'p2', // Amélie
        going: false,
        invitedOn: DateTime(2026, 10, 6),
        followUpOn: DateTime(2026, 10, 9),
      ),
      Attendee(
        personId: 'p3', // Sarah
        going: false,
        invitedOn: DateTime(2026, 10, 1),
        followedUpOn: DateTime(2026, 10, 5),
        followUpOn: DateTime(2026, 10, 8),
      ),
      const Attendee(personId: 'p4'), // Marie
      Attendee(
        personId: 'p5', // Bruno
        going: false,
        invitedOn: DateTime(2026, 10, 1),
        followUpOn: DateTime(2026, 10, 4),
      ),
    ],
    eventWorkflowId: 'workshop',
    stepsDone: {'remind': DateTime(2026, 10, 7)},
  ),
  CalendarEvent(
    id: 'e2',
    title: 'New member training',
    startsAt: DateTime(2026, 10, 8, 14),
    endsAt: DateTime(2026, 10, 8, 15),
    link: 'https://meet.google.com/abc-defg-hij',
    attendees: [
      const Attendee(personId: 'p1', came: false),
      const Attendee(personId: 'p3', came: false),
      const Attendee(personId: 'p5', came: false),
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

/// An open (repeating, #376) and a done task on the 8th, above its events,
/// and one at 14:00 (#377); one alone on the 10th (a hollow dot); one on the
/// 21st, after its two events' dots.
final _tasks = [
  Task(
    id: 't1',
    title: 'Order flyers',
    note: 'For the workshop',
    dueOn: _selected,
    doneOn: null,
    createdAt: DateTime(2026, 10, 1),
    repeat: (
      every: 1,
      unit: RepeatUnit.month,
      from: _selected,
      until: null,
      scheduledOn: _selected,
    ),
  ),
  Task(
    id: 't2',
    title: 'Print the price list',
    note: null,
    dueOn: _selected,
    doneOn: _today,
    createdAt: DateTime(2026, 10, 2),
  ),
  Task(
    id: 't3',
    title: 'Restock samples',
    note: null,
    dueOn: DateTime(2026, 10, 10),
    doneOn: null,
    createdAt: DateTime(2026, 10, 3),
  ),
  Task(
    id: 't4',
    title: 'Call the venue',
    note: null,
    dueOn: DateTime(2026, 10, 21),
    doneOn: null,
    createdAt: DateTime(2026, 10, 4),
  ),
  // A time (#377): its chip in the lists, its block on the desktop week.
  Task(
    id: 't5',
    title: 'Call the supplier',
    note: 'Ask about the 10 ml bottles',
    dueOn: _selected,
    doneOn: null,
    createdAt: DateTime(2026, 10, 5),
    dueTime: (hour: 14, minute: 0),
  ),
];

/// People due (#378): with Sarah's follow-up, five on the 8th (Léa twice),
/// Amélie's follow-up on the 9th, two on the 15th.
final _due = [
  _remind('d1', 'Camille Roux', [('Call back about the diffuser', _selected)]),
  _remind('d2', 'Hugo Martin', [('Follow up about the workshop', _selected)]),
  _remind('d3', 'Léa Fontaine', [
    ('Book the unboxing call', _selected),
    ('Send the samples', _selected),
  ]),
  _remind('d4', 'Nina Garnier', [('Send a first message', _selected)]),
  _remind('d5', 'Julie Martin', [
    ('Ask how the oils went', DateTime(2026, 10, 15)),
  ]),
  _remind('d6', 'Paul Girard', [
    ('Send the catalogue', DateTime(2026, 10, 15)),
  ]),
];

Person _remind(String id, String name, List<(String, DateTime)> reminders) =>
    Person(
      id: id,
      name: name,
      stage: Stage.prospect,
      stageSince: DateTime(2026, 9),
      reminders: [
        for (final (index, (text, on)) in reminders.indexed)
          (
            id: '$id-$index',
            text: text,
            dueOn: on,
            createdAt: DateTime(2026, 10, 1, index),
          ),
      ],
    );

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

Widget _calendar({
  bool desktop = false,
  CalendarMode mode = CalendarMode.month,
}) => CalendarView(
  events: AsyncData(_events),
  tasks: _tasks,
  people: PeopleAhead(
    people: [..._people, ..._due],
    workflows: const [],
    events: _events,
    today: _today,
  ),
  selection: (mode: mode, month: DateTime(2026, 10), day: _selected),
  today: _today,
  // The desktop week's now line, mid-morning.
  now: DateTime(2026, 10, 7, 11, 15),
  onSelect: (_) {},
  onShift: (_) {},
  onToday: () {},
  onOpen: (_) {},
  onAdd: (_) {},
  onAddTask: (_) {},
  onToggleTask: (_) {},
  onOpenTask: (_) {},
  onRetry: () {},
  desktop: desktop,
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
