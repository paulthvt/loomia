import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/today/domain/due.dart';
import 'package:loomia/features/today/domain/today_events.dart';
import 'package:loomia/features/today/presentation/today_page.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Today in both modes and both layouts, for `flutter widget-preview start`,
/// on a fixed morning so the goldens never follow the clock. Six people are
/// due: a phone shows five and "And one more waiting", a desktop all six.
/// Nothing in the app imports this file.
@Preview(group: 'Today', name: 'Mobile — light', size: Size(390, 844))
Widget todayMobileLight() => _app(AppTheme.light, _book, goals: _goals);

@Preview(group: 'Today', name: 'Mobile — dark', size: Size(390, 844))
Widget todayMobileDark() => _app(AppTheme.dark, _book, goals: _goals);

@Preview(group: 'Today', name: 'Desktop — light', size: Size(1440, 900))
Widget todayDesktopLight() => _app(AppTheme.light, _book, goals: _goals);

@Preview(group: 'Today', name: 'Desktop — dark', size: Size(1440, 900))
Widget todayDesktopDark() => _app(AppTheme.dark, _book, goals: _goals);

@Preview(group: 'Today', name: 'Empty — light', size: Size(390, 844))
Widget todayEmptyLight() => _app(AppTheme.light, const []);

@Preview(group: 'Today', name: 'Events — light', size: Size(390, 844))
Widget todayEventsMobileLight() => _app(
  AppTheme.light,
  [
    _due('Sarah Martin', 2, DateTime(2026, 9, 26)),
    _due('Claire Dubois', 1, DateTime(2026, 9, 28)),
    _due('Julie Bernard', 1, DateTime(2026, 9, 29)),
  ],
  events: _events,
  now: DateTime(2026, 9, 29, 18, 50),
);

final _now = DateTime(2026, 9, 29, 9);

/// September planned and not closed: on the 29th, the line reads "150 PV to
/// go · 1 day left" and the close-and-plan card shows, as in the Figma.
final GoalsMonth _goals = (
  month: DateTime(2026, 9),
  plan: _september,
  progress: const Progress(
    ownVolume: 2650,
    prospects: 5,
    customers: 4,
    teamMembers: 1,
    loyalty: 2,
  ),
  forecast: 1,
  plans: [_september],
);

final _september = MonthPlan(
  month: DateTime(2026, 9),
  ownVolumeTarget: 2800,
  prospectsTarget: 8,
);

final _samples = Workflow(
  id: 'samples',
  stage: Stage.prospect,
  name: 'Samples',
  isDefault: true,
  steps: const [
    WorkflowStep(id: 's1', position: 1, label: 'Send a first message', days: 0),
    WorkflowStep(id: 's2', position: 2, label: 'Send the samples', days: 1),
    WorkflowStep(
      id: 's3',
      position: 3,
      label: 'Ask how they liked them',
      days: 4,
    ),
  ],
);

Due _due(String name, int step, DateTime due) => (
  person: Person(
    id: name,
    name: name,
    stage: Stage.prospect,
    stageSince: DateTime.utc(2026, 9),
  ),
  step: OnStep(
    workflow: _samples,
    step: _samples.steps[step - 1],
    index: step,
    total: _samples.steps.length,
    due: due,
  ),
);

/// Oldest first, then by name, as `dueToday` sorts.
final _book = [
  _due('Sarah Martin', 2, DateTime(2026, 9, 26)),
  _due('Claire Dubois', 1, DateTime(2026, 9, 28)),
  _due('Julie Bernard', 1, DateTime(2026, 9, 29)),
  _due('Léa Petit', 2, DateTime(2026, 9, 29)),
  _due('Marie Lefèvre', 3, DateTime(2026, 9, 29)),
  _due('Nadia Roux', 1, DateTime(2026, 9, 29)),
];

final _eventWorkflow = EventWorkflow(
  id: 'product-evening',
  name: 'Product evening',
  steps: [
    const EventWorkflowStep(
      id: 'remind',
      label: 'Remind everyone it\'s tomorrow',
      days: -1,
    ),
  ],
);

final _events = (
  today: [
    CalendarEvent(
      id: 'oils',
      title: 'Essential oils for sleep',
      startsAt: DateTime(2026, 9, 29, 19, 0),
      endsAt: DateTime(2026, 9, 29, 20, 30),
      link: 'https://meet.example.com/oils',
      attendees: List.generate(6, (i) => (personId: 'person$i', came: false)),
    ),
  ],
  toMark: [
    CalendarEvent(
      id: 'training',
      title: 'New member training',
      startsAt: DateTime(2026, 9, 24, 14, 0),
      endsAt: DateTime(2026, 9, 24, 16, 0),
      attendees: List.generate(
        3,
        (i) => (personId: 'person${i + 10}', came: false),
      ),
    ),
  ],
  steps: [
    (
      event: CalendarEvent(
        id: 'product',
        title: 'Product evening',
        startsAt: DateTime(2026, 9, 30, 19, 0),
        eventWorkflowId: 'product-evening',
      ),
      step: _eventWorkflow.steps[0],
      due: DateTime(2026, 9, 29),
    ),
  ],
);

Widget _app(
  ThemeData theme,
  List<Due> due, {
  GoalsMonth? goals,
  TodayEvents events = noTodayEvents,
  DateTime? now,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // The preview is its own app: without the delegates, any component that
    // reads AppLocalizations throws here.
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: TodayView(
      due: AsyncData(due),
      now: now ?? _now,
      firstName: 'Pauline',
      onTick: (_) {},
      onOpen: (_) {},
      onRetry: () {},
      onRefresh: () async {},
      goals: goals,
      model: BusinessModel.doterra,
      events: events,
      onOpenEvent: (_) {},
      onMarkDone: (_) {},
      onTickStep: (_) {},
      onJoin: (_) {},
    ),
  );
}
