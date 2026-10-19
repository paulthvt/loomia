import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode, showCupertinoModalPopup;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:loomia/app/theme/app_spacing.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// The device's today, as local midnight: "today" is decided on the device,
/// never by the server (#48).
DateTime today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

/// A calendar day between [first] and [last], as local midnight; null when
/// dismissed. The platform's own picker (docs/architecture.md → Design
/// packages): a wheel on iOS, the Material calendar elsewhere.
Future<DateTime?> pickDay(
  BuildContext context, {
  required DateTime initial,
  DateTime? first,
  required DateTime last,
}) async {
  final picked = _wheel
      ? await showCupertinoModalPopup<DateTime>(
          context: context,
          builder: (_) => _Wheel(initial: initial, first: first, last: last),
        )
      : await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first ?? DateTime(1900),
          lastDate: last,
        );
  return picked == null
      ? null
      : DateTime(picked.year, picked.month, picked.day);
}

/// The first of a month between [first] and [last], as local midnight; null
/// when dismissed. A month-and-year wheel on iOS; elsewhere a dialog of the
/// year's twelve months, the year changed with its arrows.
Future<DateTime?> pickMonth(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
}) async {
  final picked = _wheel
      ? await showCupertinoModalPopup<DateTime>(
          context: context,
          builder: (_) => _Wheel(
            mode: CupertinoDatePickerMode.monthYear,
            initial: initial,
            first: first,
            last: last,
          ),
        )
      : await showDialog<DateTime>(
          context: context,
          builder: (_) =>
              _MonthDialog(initial: initial, first: first, last: last),
        );
  return picked == null ? null : DateTime(picked.year, picked.month);
}

/// A year, ‹ ›, and its months in a 3 × 4 grid; the initial month
/// outlined, months outside [first]…[last] disabled. A month closes it.
class _MonthDialog extends StatefulWidget {
  const _MonthDialog({
    required this.initial,
    required this.first,
    required this.last,
  });

  final DateTime initial;
  final DateTime first;
  final DateTime last;

  @override
  State<_MonthDialog> createState() => _MonthDialogState();
}

class _MonthDialogState extends State<_MonthDialog> {
  static const int _columns = 3;

  late int _year = widget.initial.year;

  bool _within(DateTime month) =>
      !month.isBefore(DateTime(widget.first.year, widget.first.month)) &&
      !month.isAfter(DateTime(widget.last.year, widget.last.month));

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final name = DateFormat.MMM(locale);
    final full = DateFormat.yMMMM(locale);
    final theme = Theme.of(context);
    final months = [
      for (var m = 1; m <= DateTime.monthsPerYear; m++) DateTime(_year, m),
    ];
    return AlertDialog(
      contentPadding: const EdgeInsets.all(AppSpacing.md),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: AppSpacing.sm,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _year > widget.first.year
                      ? () => setState(() => _year--)
                      : null,
                  tooltip: AppLocalizations.of(context).monthPickerPreviousYear,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    localizations.formatYear(DateTime(_year)),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: _year < widget.last.year
                      ? () => setState(() => _year++)
                      : null,
                  tooltip: AppLocalizations.of(context).monthPickerNextYear,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            for (var row = 0; row < months.length; row += _columns)
              Row(
                spacing: AppSpacing.sm,
                children: [
                  for (final month in months.sublist(row, row + _columns))
                    Expanded(
                      child: Semantics(
                        label: full.format(month),
                        selected:
                            month ==
                            DateTime(widget.initial.year, widget.initial.month),
                        excludeSemantics: true,
                        child: _monthButton(
                          month,
                          name.format(month),
                          onPressed: _within(month)
                              ? () => Navigator.pop(context, month)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localizations.cancelButtonLabel),
        ),
      ],
    );
  }

  Widget _monthButton(
    DateTime month,
    String label, {
    required VoidCallback? onPressed,
  }) {
    final current =
        month == DateTime(widget.initial.year, widget.initial.month);
    final text = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    return current
        ? OutlinedButton(onPressed: onPressed, child: text)
        : TextButton(onPressed: onPressed, child: text);
  }
}

/// A time of day; null when dismissed. A wheel on iOS, the Material dial
/// elsewhere, both in the device's 12- or 24-hour format.
Future<TimeOfDay?> pickTime(
  BuildContext context, {
  required TimeOfDay initial,
}) async {
  if (!_wheel) return showTimePicker(context: context, initialTime: initial);
  final now = DateTime.now();
  final picked = await showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (context) => _Wheel(
      mode: CupertinoDatePickerMode.time,
      initial: DateTime(
        now.year,
        now.month,
        now.day,
        initial.hour,
        initial.minute,
      ),
      use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    ),
  );
  return picked == null ? null : TimeOfDay.fromDateTime(picked);
}

bool get _wheel => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

class _Wheel extends StatefulWidget {
  const _Wheel({
    this.mode = CupertinoDatePickerMode.date,
    required this.initial,
    this.first,
    this.last,
    this.use24hFormat = false,
  });

  final CupertinoDatePickerMode mode;

  final DateTime initial;
  final DateTime? first;
  final DateTime? last;

  /// Time mode only: hours as the device shows them.
  final bool use24hFormat;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  late DateTime _day = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context, _day),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
            SizedBox(
              // UIKit's standard picker height.
              height: 216,
              child: CupertinoDatePicker(
                mode: widget.mode,
                initialDateTime: widget.initial,
                minimumDate: widget.first,
                maximumDate: widget.last,
                use24hFormat: widget.use24hFormat,
                onDateTimeChanged: (day) => _day = day,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
