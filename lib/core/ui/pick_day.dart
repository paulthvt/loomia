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

bool get _wheel => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

class _Wheel extends StatefulWidget {
  const _Wheel({
    this.mode = CupertinoDatePickerMode.date,
    required this.initial,
    this.first,
    required this.last,
  });

  final CupertinoDatePickerMode mode;

  final DateTime initial;
  final DateTime? first;
  final DateTime last;

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
                onDateTimeChanged: (day) => _day = day,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
