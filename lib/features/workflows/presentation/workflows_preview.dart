import 'package:flutter/widget_previews.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/settings/presentation/widgets/settings_scroll.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';
import 'package:loomia/features/workflows/presentation/step_sheet.dart';
import 'package:loomia/features/workflows/presentation/workflow_editor.dart';
import 'package:loomia/features/workflows/presentation/workflows_settings.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:loomia/l10n/localizations_delegates.dart';
import 'package:material_ui/material_ui.dart';

/// Settings → Workflows, for `flutter widget-preview start`.
///
/// The sample workflows live here and only here. Nothing in the app imports
/// this file.
@Preview(group: 'Workflows', name: 'List — light', size: Size(390, 844))
Widget workflowsListLight() => _app(
  Builder(
    builder: (context) => SettingsScroll(
      title: AppLocalizations.of(context).settingsSectionWorkflows,
      child: WorkflowsView(workflows: _workflows, onOpen: (_) {}, onNew: () {}),
    ),
  ),
);

@Preview(group: 'Workflows', name: 'Editor — light', size: Size(390, 844))
Widget workflowEditorLight() => _app(
  Builder(
    builder: (context) => SettingsScroll(
      eyebrow: stageLabel(AppLocalizations.of(context), _samples.stage),
      title: _samples.name,
      child: WorkflowEditorView(
        workflow: _samples,
        onRename: (_) async {},
        onAddStep: () {},
        onOpenStep: (_) {},
        onMove: (_, _) async {},
        onDefault: (_) async {},
        onDelete: () async {},
      ),
    ),
  ),
);

@Preview(group: 'Workflows', name: 'Step — light', size: Size(390, 844))
Widget workflowStepLight() => _app(
  Align(
    alignment: Alignment.bottomCenter,
    child: StepForm(
      model: BusinessModel.other,
      offersLoyalty: _samples.stage != Stage.prospect,
      number: 2,
      step: _samples.steps[1],
      onSave: (_) async {},
      onRemove: () async {},
    ),
  ),
);

Workflow _workflow(
  String id,
  Stage stage,
  String name,
  List<(String, int)> steps, {
  bool isDefault = false,
}) => Workflow(
  id: id,
  stage: stage,
  name: name,
  isDefault: isDefault,
  steps: [
    for (final (index, (label, days)) in steps.indexed)
      WorkflowStep(
        id: '$id-$index',
        position: index + 1,
        label: label,
        days: days,
      ),
  ],
);

final _samples = _workflow('samples', Stage.prospect, 'Samples', [
  ('Send a first message', 0),
  ('Send the samples', 1),
  ('Samples arrived', 4),
  ('Ask how the samples went', 3),
  ('Follow up', 7),
], isDefault: true);

final _workflows = [
  _samples,
  _workflow('health', Stage.prospect, 'Health professionals', [
    ('Introduce yourself', 0),
    ('Share a product sheet', 2),
    ('Offer a sample kit', 5),
    ('Follow up', 7),
  ]),
  _workflow('new-customer', Stage.customer, 'New customer', [
    ('Thank them for the order', 0),
    ('Order arrived', 5),
    ('Check in on the products', 14),
    ('Suggest a refill routine', 21),
  ], isDefault: true),
  _workflow('getting-started', Stage.team, 'Getting started', [
    ('Welcome call', 0),
    ('Unboxing call', 5),
    ('First training', 3),
    ('First goal together', 7),
    ('Two-week check-in', 14),
  ], isDefault: true),
];

Widget _app(Widget body) => ProviderScope(
  overrides: [accountProvider.overrideWith((_) => null)],
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    // The preview is its own app: without the delegates, any component that
    // reads AppLocalizations throws here.
    localizationsDelegates: localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: AppTheme.light,
    home: Scaffold(body: SafeArea(child: body)),
  ),
);
