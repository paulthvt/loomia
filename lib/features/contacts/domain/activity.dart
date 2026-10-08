import 'package:intl/intl.dart';
import 'package:loomia/features/contacts/domain/person.dart';

/// What an entry records. [stage] entries are written by the database when a
/// person changes stage, [step] entries when a workflow step is ticked, [event]
/// entries when the person was at an event, [reminder] entries when a reminder
/// is ticked; the user writes the others.
enum ActivityKind {
  note,
  call,
  message,
  order,
  meeting,
  stage,
  step,
  event,
  reminder;

  /// Offered in Log something.
  bool get byUser =>
      this != stage && this != step && this != event && this != reminder;
}

/// One thing in a person's history. Its text, day and amount can be edited;
/// a stage entry's day is the person's [Person.stageSince].
class Activity {
  Activity({
    required this.id,
    required this.personId,
    required this.kind,
    required this.happenedOn,
    required this.createdAt,
    this.text,
    this.stage,
    this.amount,
  }) : assert(
         kind == ActivityKind.stage
             ? stage != null && text == null && amount == null
             : stage == null &&
                   (text == null
                       ? kind == ActivityKind.order && amount != null
                       : text.trim().isNotEmpty) &&
                   (amount == null ||
                       (kind == ActivityKind.order && amount > 0)) &&
                   (personId != null ||
                       (kind == ActivityKind.order && amount != null)),
         'A stage entry has a stage only; any other has no stage and non-blank '
         'text, except an order, which needs text or an amount; only an order '
         'has an amount; only an own order has no person',
       );

  final String id;

  /// Null on the user's own order, which has an amount (Goals).
  final String? personId;
  final ActivityKind kind;

  /// The calendar day it happened, as local midnight.
  final DateTime happenedOn;

  /// What happened; null on stage entries and on an order given by its
  /// amount alone.
  final String? text;

  /// What an order was worth, in the business model's unit (PV for dōTERRA).
  /// Orders only.
  final double? amount;

  /// The stage moved to; stage entries only.
  final Stage? stage;
  final DateTime createdAt;

  /// The day it shows under. A stage entry's [happenedOn] is the server's UTC
  /// day, and "today" is decided on the device, so it uses the local day of
  /// [createdAt].
  DateTime get day {
    if (kind != ActivityKind.stage) return happenedOn;
    final local = createdAt.toLocal();
    return DateTime(local.year, local.month, local.day);
  }
}

/// What Log something collects. Never a stage entry. [text] may be blank only
/// on an order with an [amount]; [amount] is set only on an order.
typedef ActivityDraft = ({
  ActivityKind kind,
  DateTime happenedOn,
  String text,
  double? amount,
});

/// An order in a month's list: the entry and whose it is (null: the user's
/// own).
typedef MonthOrder = ({Activity order, String? personName});

/// An order's amount as typed, read the way [locale] writes numbers: at most
/// two decimals (the column is numeric(12,2)), spaces ignored. Null for
/// anything else, zero included; an ambiguous value is refused, never
/// guessed.
///
/// Where the decimal point is `.` (English), `,` only groups thousands:
/// "6,000" is 6000, "6,00" is refused. Elsewhere (French) `,` is the decimal
/// point and so is `.`, which some number pads offer alone; "6.000" has three
/// decimals and is refused.
// ponytail: the app language stands for the region (English reads US-style);
// use the device locale if someone writes English with decimal commas.
double? parseAmount(String input, String locale) {
  var typed = input.replaceAll(RegExp(r'\s'), '');
  if (NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP == '.') {
    if (typed.contains(',') &&
        !RegExp(r'^\d{1,3}(,\d{3})+(\.\d*)?$').hasMatch(typed)) {
      return null;
    }
    typed = typed.replaceAll(',', '');
  } else {
    typed = typed.replaceAll(',', '.');
  }
  final match = RegExp(r'^(\d{1,10})(?:\.(\d{1,2}))?$').firstMatch(typed);
  if (match == null) return null;
  final value = double.parse('${match[1]}.${match[2] ?? '0'}');
  return value > 0 ? value : null;
}
