import 'package:cupertino_ui/cupertino_ui.dart'
    show CupertinoDatePicker, CupertinoDatePickerMode, showCupertinoModalPopup;
import 'package:flutter/foundation.dart';
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
/// when dismissed. A month-and-year wheel on iOS; elsewhere the Material
/// calendar opened on its years, of which only the month is kept.
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
      : await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          initialDatePickerMode: DatePickerMode.year,
        );
  return picked == null ? null : DateTime(picked.year, picked.month);
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
