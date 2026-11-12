import 'dart:async';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_colors.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/core/repeat/repeat.dart';
import 'package:loomia/core/ui/labeled_field.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/core/ui/scope_dialog.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// What [repeat] means in words: "Every month on the 3rd", "Every 2 weeks
/// on Thursday", with ", until Jun 3, 2027" when it ends. Under the form's
/// repeat fields and as the row's repeat icon label.
String repeatRuleLine(AppLocalizations l10n, Repeat repeat) {
  final n = repeat.every;
  final from = repeat.from;
  final line = switch (repeat.unit) {
    RepeatUnit.day => l10n.taskRepeatLineDay(n),
    RepeatUnit.week => l10n.taskRepeatLineWeek(
      n,
      DateFormat.EEEE(l10n.localeName).format(from),
    ),
    RepeatUnit.month => l10n.taskRepeatLineMonth(
      n,
      l10n.taskRepeatDayOfMonth('${from.day}'),
    ),
    RepeatUnit.year => l10n.taskRepeatLineYear(
      n,
      DateFormat.MMMMd(l10n.localeName).format(from),
    ),
  };
  final until = repeat.until;
  return until == null
      ? line
      : l10n.taskRepeatUntil(
          line,
          DateFormat.yMMMd(l10n.localeName).format(until),
        );
}

/// The repeat block of a task or reminder form (#376, #486): the Repeat
/// switch and, on, Repeats every [n] [unit], the line saying what it means,
/// and Ends Never / On a day. The form keeps the values.
class RepeatFields extends StatelessWidget {
  const RepeatFields({
    required this.on,
    required this.onOn,
    required this.every,
    required this.unit,
    required this.onUnit,
    required this.until,
    required this.onUntil,
    required this.day,
    required this.lineFrom,
    this.onEvery,
    super.key,
  });

  final bool on;

  /// Null while saving.
  final ValueChanged<bool>? onOn;

  /// The number, 1–99, validated here.
  final TextEditingController every;
  final RepeatUnit unit;
  final ValueChanged<RepeatUnit> onUnit;

  /// When it ends; null: never.
  final DateTime? until;
  final ValueChanged<DateTime?> onUntil;

  /// The day of the task or reminder: Ends On can't be before it.
  final DateTime day;

  /// The day the line counts from: the schedule's start when editing, so a
  /// postponed one still reads "on the 3rd".
  final DateTime lineFrom;

  /// The number was typed: the line and the unit's plural follow it.
  final VoidCallback? onEvery;

  int get _count => int.tryParse(every.text) ?? 1;

  /// Ends On: picks a day not before [day]. Cancelled leaves it as is.
  Future<void> _pickUntil(BuildContext context) async {
    final picked = await pickDay(
      context,
      initial: until ?? DateTime(day.year, day.month, day.day + 30),
      first: day,
      last: DateTime(day.year, day.month, day.day + 365 * 10),
    );
    if (picked != null) onUntil(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final count = _count;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.ms,
      children: [
        // The app's one switch style, as in the log sheet.
        SwitchListTile(
          value: on,
          title: Text(l10n.taskRepeat),
          contentPadding: EdgeInsets.zero,
          onChanged: onOn,
        ),
        if (on) ...[
          LabeledField(
            label: l10n.taskRepeatsEvery,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpacing.sm,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: every,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => onEvery?.call(),
                    validator: (value) => switch (int.tryParse(value ?? '')) {
                      final n? when n >= 1 && n <= 99 => null,
                      _ => l10n.taskRepeatEveryInvalid,
                    },
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<RepeatUnit>(
                    initialValue: unit,
                    // The menu lists the units as words, the field reads
                    // them after the number: "3 months".
                    items: [
                      for (final unit in RepeatUnit.values)
                        DropdownMenuItem(
                          value: unit,
                          child: Text(_unitLabel(l10n, unit, 1)),
                        ),
                    ],
                    selectedItemBuilder: (context) => [
                      for (final unit in RepeatUnit.values)
                        Text(_unitLabel(l10n, unit, count)),
                    ],
                    onChanged: (picked) => onUnit(picked ?? unit),
                  ),
                ),
              ],
            ),
          ),
          Text(
            repeatRuleLine(l10n, (
              every: count,
              unit: unit,
              from: lineFrom,
              until: until,
              scheduledOn: lineFrom,
            )),
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: LoomiaColors.of(context).textMuted),
          ),
          LabeledField(
            label: l10n.taskRepeatEnds,
            child: RadioGroup<bool>(
              groupValue: until != null,
              onChanged: (ends) async {
                if (ends ?? false) {
                  await _pickUntil(context);
                } else {
                  onUntil(null);
                }
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<bool>(
                    value: false,
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.taskRepeatNever),
                  ),
                  RadioListTile<bool>(
                    value: true,
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      spacing: AppSpacing.sm,
                      children: [
                        Text(l10n.taskRepeatOn),
                        Flexible(
                          child: OutlinedButton(
                            onPressed: until == null
                                ? null
                                : () => unawaited(_pickUntil(context)),
                            child: Text(switch (until) {
                              final until? => DateFormat.yMMMd(
                                l10n.localeName,
                              ).format(until),
                              null => l10n.taskRepeatPickDay,
                            }, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _unitLabel(AppLocalizations l10n, RepeatUnit unit, int count) =>
      switch (unit) {
        RepeatUnit.day => l10n.taskRepeatUnitDay(count),
        RepeatUnit.week => l10n.taskRepeatUnitWeek(count),
        RepeatUnit.month => l10n.taskRepeatUnitMonth(count),
        RepeatUnit.year => l10n.taskRepeatUnitYear(count),
      };
}

/// What Save writes as the repeat, after the scope dialog when the day of
/// a repeating one moved: [on] is the switch, [old] the rule it had (null
/// when new or not repeating), [oldDay] its due day before the edit (null
/// when new), [ruleFrom] the rule as the fields read counted from a day.
/// The day moved, rule unchanged: This one keeps [old] (postponed), This
/// and following counts from [day]. The rule changed: from [day], and the
/// dialog, if any, only offers This and following. Null: cancelled.
Future<(Repeat?,)?> repeatToSave(
  BuildContext context, {
  required bool on,
  required Repeat? old,
  required DateTime? oldDay,
  required DateTime day,
  required Repeat Function(DateTime from) ruleFrom,
  required ScopeWording wording,
}) async {
  if (!on) return (null,);
  if (old == null || oldDay == null) return (ruleFrom(day),);
  final rule = ruleFrom(day);
  final ruleChanged =
      old.every != rule.every ||
      old.unit != rule.unit ||
      old.until != rule.until;
  if (day == oldDay) return (ruleChanged ? rule : old,);
  final scope = await pickScope(
    context,
    ruleChanged: ruleChanged,
    wording: wording,
  );
  if (scope == null) return null;
  // This one: postponed, the schedule stays.
  return (scope == EventScope.one ? old : rule,);
}
