import 'package:flutter/widget_previews.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/preview_photo.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/contact_details.dart';
import 'package:loomia/features/contacts/presentation/contact_list.dart';
import 'package:loomia/features/contacts/presentation/next_step_section.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Contacts and a person in both modes, for `flutter widget-preview start`.
///
/// The sample book lives here and only here. Nothing in the app imports this
/// file.
@Preview(group: 'Contacts', name: 'List — light', size: Size(390, 844))
Widget contactsMobileLight() => _app(AppTheme.light, _list());

@Preview(group: 'Contacts', name: 'List — dark', size: Size(390, 844))
Widget contactsMobileDark() => _app(AppTheme.dark, _list());

@Preview(group: 'Contacts', name: 'Person — light', size: Size(390, 844))
Widget contactMobileLight() => _app(AppTheme.light, _details());

@Preview(group: 'Contacts', name: 'Person — dark', size: Size(390, 844))
Widget contactMobileDark() => _app(AppTheme.dark, _details());

@Preview(
  group: 'Contacts',
  name: 'Person — photo — light',
  size: Size(390, 844),
)
Widget contactPhotoMobileLight() =>
    _app(AppTheme.light, _details(photo: MemoryImage(previewPhoto)));

@Preview(group: 'Contacts', name: 'Team member — light', size: Size(390, 844))
Widget teamMemberMobileLight() =>
    _app(AppTheme.light, _details(person: _sample[2]));

@Preview(group: 'Contacts', name: 'Desktop — light', size: Size(1440, 900))
Widget contactsDesktopLight() => _app(
  AppTheme.light,
  Builder(
    builder: (context) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 440,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: LoomiaColors.of(context).borderSubtle),
            ),
          ),
          child: _list(selectedId: _sample.first.id, showRefresh: true),
        ),
        Expanded(child: _details()),
      ],
    ),
  ),
);

final _samples = Workflow(
  id: 'w1',
  stage: Stage.prospect,
  name: 'Samples',
  isDefault: true,
  steps: [
    for (final (index, (label, days)) in [
      ('Send a first message', 0),
      ('Send the samples', 1),
      ('Samples arrived', 4),
      ('Ask how the samples went', 3),
      ('Follow up', 7),
    ].indexed)
      WorkflowStep(
        id: 's${index + 1}',
        position: index + 1,
        label: label,
        days: days,
      ),
  ],
);

// A fixed day, so the golden never changes with the calendar.
final _previewToday = DateTime(2026, 9, 29);

final _sample = [
  Person(
    id: 'p1',
    name: 'Marie Dupont',
    stage: Stage.prospect,
    prospectStatus: ProspectStatus.thinking,
    phone: '06 12 34 56 78',
    email: 'marie@example.com',
    needs: 'Sleep, stress',
    profession: 'Nurse',
    notes: 'Met at the Saturday market. Asked about lavender.',
    stageSince: DateTime.utc(2026, 3, 4),
  ),
  Person(
    id: 'p2',
    name: 'Lucas Martin',
    stage: Stage.customer,
    products: 'Lavender, Peppermint',
    needs: 'Headaches',
    stageSince: DateTime.utc(2026, 5, 1),
  ),
  Person(
    id: 'p3',
    name: 'Hélène Bernard',
    stage: Stage.team,
    instagram: 'helene.b',
    profession: 'Yoga teacher',
    why: 'More time with my kids, on my own hours',
    ownGoal: 'Cover the family holidays by next summer',
    timeAvailable: 'Two evenings a week',
    wouldLoveTo: 'Run a workshop at the studio',
    strengths: 'Warm, great with beginners',
    stuckOn: 'Talking about it without feeling pushy',
    stageSince: DateTime.utc(2025, 11, 12),
  ),
  Person(
    id: 'p4',
    name: 'Sarah Cohen',
    stage: Stage.prospect,
    stageSince: DateTime.utc(2026, 9, 20),
  ),
];

Widget _list({String? selectedId, bool showRefresh = false}) => ContactList(
  people: _sample,
  onOpen: (_) {},
  onAdd: () {},
  onRefresh: () async {},
  onMove: (_, _) async => false,
  onChangeWorkflow: (_) async => false,
  onDelete: (_) async => false,
  model: BusinessModel.doterra,
  selectedId: selectedId,
  showRefresh: showRefresh,
);

/// The person, with no next step unless it is Marie's.
Widget _details({Person? person, ImageProvider? photo}) => ContactDetails(
  person: person ?? _sample.first,
  photo: photo,
  onChoosePhoto: () async {},
  onRemovePhoto: () async {},
  onLoyalty: () {},
  model: BusinessModel.other,
  onStatus: (_) {},
  onEdit: (_) {},
  onDelete: () {},
  onLog: () {},
  onMove: (_) {},
  onChangeWorkflow: () {},
  onPause: () {},
  onResume: () {},
  onLaunch: (_) {},
  onRefresh: () async {},
  workflowName: _samples.name,
  nextStep: person != null
      ? null
      : NextStepCard(
          // As in Figma "Reminders — #217": one late, one later.
          person: _sample.first.withReminders([
            (
              id: 'r1',
              text: 'Call back about the diffuser',
              dueOn: DateTime(2026, 9, 27),
              createdAt: DateTime.utc(2026, 9),
            ),
            (
              id: 'r2',
              text: 'Send her the price list',
              dueOn: DateTime(2026, 10, 4),
              createdAt: DateTime.utc(2026, 9),
            ),
          ]),
          progress: OnStep(
            workflow: _samples,
            step: _samples.steps[3],
            index: 4,
            total: 5,
            due: _previewToday,
          ),
          today: _previewToday,
          onTick: (_) {},
          onResume: () {},
          onNotNow: () {},
          onFollowWith: () {},
          onBecameCustomer: () {},
          onTickReminder: (_) {},
          onEditReminder: (_) {},
          onAddReminder: () {},
        ),
);

Widget _app(ThemeData theme, Widget body) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // The preview is its own app: without the delegates, any component that
    // reads AppLocalizations throws here.
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: Scaffold(body: SafeArea(child: body)),
  );
}
