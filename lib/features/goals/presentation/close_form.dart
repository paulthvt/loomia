import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/app/theme/app_theme.dart';
import 'package:loomia/core/business_model/business_model.dart';
import 'package:loomia/core/layout/content_columns.dart';
import 'package:loomia/core/ui/form_error.dart';
import 'package:loomia/core/ui/hero_panel.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/loomia_card.dart';
import 'package:loomia/core/ui/loomia_progress_bar.dart';
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
    this.steps = 2,
    this.onLeave,
    super.key,
  });

  /// The hero's close button; none without.
  final VoidCallback? onLeave;

  /// 3 when the month review follows (the month had targets).
  final int steps;

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

    Widget row(String label, String value, num doneValue, num? target) =>
        ResultRow(
          label: label,
          value: value,
          reached: target != null && doneValue >= target,
          progress: target != null && target > 0
              ? (doneValue / target).clamp(0, 1).toDouble()
              : null,
        );

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

    // One column at every width, centred and capped on wide screens.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ContentColumns.mainMax),
        child: Form(
          key: _form,
          child: HeroFormList(
            onClose: widget.onLeave,
            eyebrow: l10n.closeStep(1, widget.steps),
            title: l10n.closeTitle(widget.closing.ritual.close),
            children: [
              StepBar(step: 1, total: widget.steps),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.closeIntroFinal,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (failure != null) ...[
                FormError(peopleFailureCopy(l10n, failure)),
                const SizedBox(height: AppSpacing.ms),
              ],
              SectionHeader(title: l10n.planFromBook),
              // Each objective reads on its own, its "Reached" with it.
              LoomiaCard(
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
              // What the company counts, and where to find it (#428).
              SectionHeader(
                title: l10n.closeFinalNumbers(widget.closing.ritual.close),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: AppSpacing.ms,
                children: [
                  Text(
                    l10n.closeFinalNumbersHint(model.name),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                  LabeledField(
                    label: l10n.planTeamVolume(model.name),
                    child: TextFormField(
                      controller: _teamVolume,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: AppTheme.filledField(
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
        ),
      ),
    );
  }
}

/// One objective against its plan: label, figures, a check when reached, and
/// a neutral bar when there's a target. Shared by closing and the review.
class ResultRow extends StatelessWidget {
  const ResultRow({
    required this.label,
    required this.value,
    required this.reached,
    this.progress,
    super.key,
  });

  final String label;
  final String value;
  final bool reached;

  /// 0 to 1; no bar when null.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = this.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.xs,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => Row(
            spacing: AppSpacing.xs,
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              // Its own width, up to half the row: a long value ("Executive,
              // aiming for Elite") wraps instead of overflowing.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth / 2),
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: LoomiaColors.of(context).textMuted,
                  ),
                ),
              ),
              if (reached)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colorScheme.primary,
                  semanticLabel: AppLocalizations.of(context).closeReached,
                ),
            ],
          ),
        ),
        if (progress != null) LoomiaProgressBar(value: progress),
      ],
    );
  }
}
