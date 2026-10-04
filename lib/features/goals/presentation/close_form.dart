import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
import 'package:loomia/core/ui/loomia_top_bar.dart';
import 'package:loomia/core/ui/section_header.dart';
import 'package:loomia/features/contacts/domain/activity.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/goals/presentation/goals_controller.dart';
import 'package:loomia/features/goals/presentation/plan_page.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// Step 1: what the book counted against the plan, and the two figures only
/// the company knows. Under the plan stays neutral: no red, no "missed".
class CloseForm extends StatefulWidget {
  const CloseForm({
    required this.closing,
    required this.model,
    required this.onClose,
    super.key,
  });

  /// With `closing` and `done` set: there's a planned month to close.
  final Closing closing;
  final BusinessModel model;

  /// Throws `PeopleFailure`; the form stays, with what was typed.
  final Future<void> Function({double? teamVolume, String? level}) onClose;

  @override
  State<CloseForm> createState() => _CloseFormState();
}

class _CloseFormState extends State<CloseForm> {
  final _form = GlobalKey<FormState>();
  final _teamVolume = TextEditingController();
  String? _level;
  bool _saving = false;
  PeopleFailure? _failure;

  @override
  void dispose() {
    _teamVolume.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failure = null;
    });
    final level = _level?.trim();
    try {
      await widget.onClose(
        teamVolume: parseAmount(
          _teamVolume.text,
          AppLocalizations.of(context).localeName,
        ),
        level: level == null || level.isEmpty ? null : level,
      );
      if (mounted) setState(() => _saving = false);
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
    final theme = Theme.of(context);
    final colors = LoomiaColors.of(context);
    final number = NumberFormat.decimalPattern(l10n.localeName);
    final model = widget.model;
    final plan = widget.closing.closing!;
    final done = widget.closing.done!;
    final failure = _failure;

    Widget row(String label, String value, num doneValue, num? target) {
      final reached = target != null && doneValue >= target;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppSpacing.xs,
        children: [
          Row(
            spacing: AppSpacing.xs,
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              Text(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              if (reached)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                  semanticLabel: l10n.closeReached,
                ),
            ],
          ),
          if (target != null && target > 0)
            LoomiaProgressBar(value: (doneValue / target).clamp(0, 1)),
        ],
      );
    }

    Widget count(String label, int doneValue, int? target) => row(
      label,
      target == null
          ? '$doneValue'
          : l10n.closeOf(number.format(doneValue), number.format(target)),
      doneValue,
      target,
    );

    final volumeTarget = plan.ownVolumeTarget;
    final teamTarget = plan.teamVolumeTarget;
    final levelTarget = plan.levelTarget;

    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          LoomiaTopBar(
            eyebrow: l10n.closeStep(1, 2),
            title: l10n.closeTitle(widget.closing.ritual.close),
            gap: AppSpacing.sm,
          ),
          const StepBar(step: 1),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.closeIntro,
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (failure != null) ...[
            FormError(peopleFailureCopy(l10n, failure)),
            const SizedBox(height: AppSpacing.ms),
          ],
          SectionHeader(title: l10n.planFromBook),
          Card(
            // Each objective reads on its own, its "Reached" with it.
            semanticContainer: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                spacing: AppSpacing.md,
                children: [
                  row(
                    l10n.goalOwnVolume,
                    volumeTarget == null
                        ? l10n.closeVolumeAlone(
                            model.name,
                            number.format(done.ownVolume),
                          )
                        : l10n.closeVolumeOf(
                            model.name,
                            number.format(done.ownVolume),
                            number.format(volumeTarget),
                          ),
                    done.ownVolume,
                    volumeTarget,
                  ),
                  count(
                    l10n.goalNewProspects,
                    done.prospects,
                    plan.prospectsTarget,
                  ),
                  count(
                    l10n.goalNewCustomers,
                    done.customers,
                    plan.customersTarget,
                  ),
                  count(
                    l10n.goalNewTeamMembers,
                    done.teamMembers,
                    plan.teamMembersTarget,
                  ),
                  count(
                    l10n.goalLoyalty(model.name),
                    done.loyalty,
                    plan.loyaltyTarget,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SectionHeader(title: l10n.planFromCompany),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppSpacing.ms,
            children: [
              LabeledField(
                label: l10n.planTeamVolume(model.name),
                child: TextFormField(
                  controller: _teamVolume,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    helperText: teamTarget == null
                        ? null
                        : l10n.closePlanned(number.format(teamTarget)),
                  ),
                  validator: (value) {
                    final typed = (value ?? '').trim();
                    return typed.isEmpty ||
                            parseAmount(typed, l10n.localeName) != null
                        ? null
                        : l10n.planNumberInvalid;
                  },
                ),
              ),
              LevelField(
                label: l10n.planLevel(model.name),
                model: model,
                value: _level,
                helper: levelTarget == null
                    ? null
                    : l10n.closeAimedFor(levelTarget),
                onChanged: (value) => _level = value,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _close,
            child: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.closeNext),
          ),
        ],
      ),
    );
  }
}
