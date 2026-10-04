import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/empty_state.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/goals/domain/goal_rules.dart';
import 'package:loomia/features/goals/domain/month_plan.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// This month's plan, full screen: step 2 of the close-and-plan flow, alone
/// until #143 adds step 1.
class PlanPage extends ConsumerWidget {
  const PlanPage({this.onSaved, super.key});

  /// After a save. Defaults to going back to Goals.
  final VoidCallback? onSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final account = ref.watch(accountProvider);
    final provider = goalsProvider(account?.email);
    final month = ref.watch(provider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => backOr(context, Routes.goals)),
      ),
      body: SafeArea(
        child: switch (month) {
          // `.value` survives the reload a save triggers.
          AsyncValue(value: final value?) => PlanForm(
            month: value,
            model: account?.businessModel ?? BusinessModel.other,
            onSave: (plan) => savePlan(
              ProviderScope.containerOf(context, listen: false),
              plan,
            ),
            onSaved: onSaved ?? () => backOr(context, Routes.goals),
          ),
          AsyncError() => EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l10n.goalsLoadFailed,
            body: l10n.contactsLoadErrorBody,
            actionLabel: l10n.contactsRetry,
            onAction: () => ref.invalidate(provider),
          ),
          _ => const Center(child: CircularProgressIndicator()),
        },
      ),
    );
  }
}

/// The month's targets, each optional. Starts from the saved plan, else from
/// the last 3 closed months, with loyalty from the forecast.
class PlanForm extends StatefulWidget {
  const PlanForm({
    required this.month,
    required this.model,
    required this.onSave,
    required this.onSaved,
    this.step,
    super.key,
  });

  final GoalsMonth month;

  /// In the close-and-plan flow: which step this is.
  final int? step;
  final BusinessModel model;

  /// Throws `PeopleFailure`; the form stays, with what was typed.
  final Future<void> Function(MonthPlan plan) onSave;
  final VoidCallback onSaved;

  @override
  State<PlanForm> createState() => _PlanFormState();
}

/// Digits and a dot, as typed and as `parseAmount` reads them.
String _plain(num? value) => switch (value) {
  null => '',
  final number when number == number.roundToDouble() => '${number.round()}',
  final number => '$number',
};

class _PlanFormState extends State<PlanForm> {
  final _form = GlobalKey<FormState>();
  late final MonthPlan? _saved = widget.month.plan;

  /// A saved plan opens as saved: its empty fields stay empty.
  late final Suggestion _suggested = _saved == null
      ? suggest(widget.month.plans)
      : (
          ownVolume: null,
          teamVolume: null,
          prospects: null,
          customers: null,
          teamMembers: null,
        );
  late final _ownVolume = TextEditingController(
    text: _plain(_saved?.ownVolumeTarget ?? _suggested.ownVolume),
  );
  late final _prospects = TextEditingController(
    text: _plain(_saved?.prospectsTarget ?? _suggested.prospects),
  );
  late final _customers = TextEditingController(
    text: _plain(_saved?.customersTarget ?? _suggested.customers),
  );
  late final _teamMembers = TextEditingController(
    text: _plain(_saved?.teamMembersTarget ?? _suggested.teamMembers),
  );
  late final _loyalty = TextEditingController(
    text: _plain(_saved?.loyaltyTarget ?? widget.month.forecast),
  );
  late final _teamVolume = TextEditingController(
    text: _plain(_saved?.teamVolumeTarget ?? _suggested.teamVolume),
  );
  late String? _level = _saved?.levelTarget;
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    for (final controller in [
      _ownVolume,
      _prospects,
      _customers,
      _teamMembers,
      _loyalty,
      _teamVolume,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String get _locale => AppLocalizations.of(context).localeName;

  double? _volume(TextEditingController controller) =>
      parseAmount(controller.text, _locale);

  static int? _count(TextEditingController controller) =>
      int.tryParse(controller.text);

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    final level = _level?.trim();
    try {
      await widget.onSave(
        MonthPlan(
          month: widget.month.month,
          ownVolumeTarget: _volume(_ownVolume),
          teamVolumeTarget: _volume(_teamVolume),
          levelTarget: level == null || level.isEmpty ? null : level,
          prospectsTarget: _count(_prospects),
          customersTarget: _count(_customers),
          teamMembersTarget: _count(_teamMembers),
          loyaltyTarget: _count(_loyalty),
          // What was suggested the first time stays the record.
          loyaltyForecast: _saved?.loyaltyForecast ?? widget.month.forecast,
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      widget.onSaved();
    } on PeopleFailure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failure = failure;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final material = MaterialLocalizations.of(context);
    final colors = LoomiaColors.of(context);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final model = widget.model;
    final failure = _failure;
    final firstTime = widget.month.plans.every((plan) => !plan.closed);

    Widget amount(String label, TextEditingController controller, num? hint) =>
        LabeledField(
          label: label,
          child: TextFormField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              helperText: hint == null
                  ? null
                  : l10n.planSuggestion(number.format(hint)),
            ),
            validator: (value) {
              final typed = (value ?? '').trim();
              return typed.isEmpty ||
                      parseAmount(typed, l10n.localeName) != null
                  ? null
                  : l10n.planNumberInvalid;
            },
          ),
        );
    Widget count(String label, TextEditingController controller, int? hint) =>
        LabeledField(
          label: label,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              helperText: hint == null
                  ? null
                  : l10n.planSuggestion(number.format(hint)),
            ),
          ),
        );

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          LoomiaTopBar(
            eyebrow: switch (widget.step) {
              final step? => l10n.closeStep(step, 2),
              null => null,
            },
            title: l10n.planTitle(widget.month.month),
            gap: AppSpacing.sm,
          ),
          if (widget.step case final step?) ...[
            StepBar(step: step),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            firstTime ? l10n.planIntroFirst : l10n.planIntro,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (failure != null) ...[
            FormError(peopleFailureCopy(l10n, failure)),
            const SizedBox(height: AppSpacing.ms),
          ],
          SectionHeader(title: l10n.planFromBook),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.ms,
            children: [
              amount(
                l10n.planOwnVolume(model.name),
                _ownVolume,
                _suggested.ownVolume,
              ),
              count(l10n.goalNewProspects, _prospects, _suggested.prospects),
              count(l10n.goalNewCustomers, _customers, _suggested.customers),
              count(
                l10n.goalNewTeamMembers,
                _teamMembers,
                _suggested.teamMembers,
              ),
              Text(
                l10n.planLoyaltyForecast(
                  model.name,
                  widget.month.forecast,
                  widget.month.month,
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              count(l10n.goalLoyalty(model.name), _loyalty, null),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l10n.planFromCompany),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.ms,
            children: [
              amount(
                l10n.planTeamVolume(model.name),
                _teamVolume,
                _suggested.teamVolume,
              ),
              LevelField(
                label: l10n.planLevel(model.name),
                model: model,
                value: _level,
                onChanged: (value) => _level = value,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(material.saveButtonLabel),
          ),
        ],
      ),
    );
  }
}

/// The rank picker for dōTERRA, typed words for Other. A stored label the
/// list lacks (a renamed rank) stays a choice.
class LevelField extends StatelessWidget {
  const LevelField({
    required this.label,
    required this.model,
    required this.value,
    required this.onChanged,
    this.helper,
    super.key,
  });

  final String label;
  final BusinessModel model;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decoration = InputDecoration(helperText: helper);
    return LabeledField(
      label: label,
      child: model.levels.isEmpty
          ? TextFormField(
              initialValue: value,
              textCapitalization: TextCapitalization.words,
              decoration: decoration,
              onChanged: onChanged,
            )
          : DropdownButtonFormField<String?>(
              initialValue: value,
              isExpanded: true,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: decoration,
              items: [
                DropdownMenuItem(child: Text(l10n.editLevelNone)),
                for (final name in [
                  ...model.levels,
                  if (value case final saved?
                      when !model.levels.contains(saved))
                    saved,
                ])
                  DropdownMenuItem(value: name, child: Text(name)),
              ],
              onChanged: onChanged,
            ),
    );
  }
}

/// Where the close-and-plan flow is: one segment per step, done ones filled.
class StepBar extends StatelessWidget {
  const StepBar({required this.step, this.total = 2, super.key});

  /// From 1.
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = LoomiaColors.of(context);
    return Row(
      spacing: AppSpacing.xs,
      children: [
        for (var index = 1; index <= total; index++)
          Expanded(
            child: Container(
              height: AppSpacing.xs,
              decoration: BoxDecoration(
                color: index <= step ? scheme.primary : colors.secondaryTrack,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
            ),
          ),
      ],
    );
  }
}
