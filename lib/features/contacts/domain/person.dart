/// Where someone is in the relationship. One stage at a time; people move
/// forward and sometimes back.
enum Stage { prospect, customer, team }

/// How a prospect conversation stands. Only prospects have one.
enum ProspectStatus { interested, thinking, notNow, noReply }

/// Where someone is in a workflow (#57). The current step is the first whose
/// position is at least [atPosition], due its days after [lastTick]. All three
/// are set together or not at all.
typedef WorkflowPlace = ({
  String workflowId,
  num atPosition,
  DateTime lastTick,
});

/// Someone in the user's book.
///
/// Every text field is optional except [name]. A blank value is stored as null,
/// never as an empty string.
class Person {
  const Person({
    required this.id,
    required this.name,
    required this.stage,
    required this.stageSince,
    this.prospectStatus,
    this.phone,
    this.email,
    this.instagram,
    this.needs,
    this.products,
    this.profession,
    this.address,
    this.notes,
    this.why,
    this.currentLevel,
    this.targetLevel,
    this.targetLevelBy,
    this.monthlyVolumeTarget,
    this.ownGoal,
    this.timeAvailable,
    this.wouldLoveTo,
    this.strengths,
    this.stuckOn,
    this.place,
    this.pausedAt,
    this.currentStepId,
    this.dueOn,
    this.lastContactOn,
    this.reminders = const [],
  }) : assert(
         prospectStatus == null || stage == Stage.prospect,
         'Only prospects have a status',
       );

  final String id;
  final String name;
  final Stage stage;

  /// When their current stage began. The database sets it on every stage
  /// change.
  final DateTime stageSince;
  final ProspectStatus? prospectStatus;
  final String? phone;
  final String? email;
  final String? instagram;

  /// Free text: "Sleep, stress, dry skin".
  final String? needs;

  /// Free text: what they already use.
  final String? products;
  final String? profession;
  final String? address;
  final String? notes;

  /// Why they started. This and the five after it are a team member's own
  /// profile, in their words; shown while they are on the team.
  final String? why;

  /// Their rank or level now, as the user picked or typed it. This and the
  /// three after it are what the member said in conversation, never read
  /// from their book (#67), never summed or compared.
  final String? currentLevel;

  /// The rank they are aiming for.
  final String? targetLevel;

  /// The month they aim to reach [targetLevel] by: local midnight on the
  /// first of that month. Only with a [targetLevel].
  final DateTime? targetLevelBy;

  /// The volume they aim for each month, in the business model's unit.
  final double? monthlyVolumeTarget;

  /// Their own goal, not one set for them.
  final String? ownGoal;

  /// "3 evenings a week".
  final String? timeAvailable;
  final String? wouldLoveTo;
  final String? strengths;

  /// Where they are stuck.
  final String? stuckOn;

  /// Null when they follow no workflow.
  final WorkflowPlace? place;

  /// Set while paused: the NEXT STEP card rests, the place is kept.
  final DateTime? pausedAt;

  /// The server's answer (`current_step_id`): the step they are on. Null with
  /// no workflow or once done. Read-only: never written back.
  final String? currentStepId;

  /// The server's answer (`due_on`): the day that step is due, local midnight.
  /// Null while paused, with no workflow, or done. Read-only.
  final DateTime? dueOn;

  /// The server's answer (`last_contact_on`): the latest day anything was
  /// logged with them, stage changes aside. Local midnight. Read-only.
  final DateTime? lastContactOn;

  /// Their open reminders, soonest first (#217). Read with the book.
  final List<Reminder> reminders;

  Person withStatus(ProspectStatus? status) =>
      _copy(prospectStatus: status, reminders: reminders);

  Person withReminders(Iterable<Reminder> reminders) => _copy(
    prospectStatus: prospectStatus,
    reminders: sortedReminders(reminders),
  );

  Person _copy({
    required ProspectStatus? prospectStatus,
    required List<Reminder> reminders,
  }) => Person(
    id: id,
    name: name,
    stage: stage,
    stageSince: stageSince,
    prospectStatus: prospectStatus,
    phone: phone,
    email: email,
    instagram: instagram,
    needs: needs,
    products: products,
    profession: profession,
    address: address,
    notes: notes,
    why: why,
    currentLevel: currentLevel,
    targetLevel: targetLevel,
    targetLevelBy: targetLevelBy,
    monthlyVolumeTarget: monthlyVolumeTarget,
    ownGoal: ownGoal,
    timeAvailable: timeAvailable,
    wouldLoveTo: wouldLoveTo,
    strengths: strengths,
    stuckOn: stuckOn,
    place: place,
    pausedAt: pausedAt,
    currentStepId: currentStepId,
    dueOn: dueOn,
    lastContactOn: lastContactOn,
    reminders: reminders,
  );
}

/// Something the user promised to do with one person, due on a day, outside
/// any workflow (#217). Ticked once: the history keeps it, the row goes.
typedef Reminder = ({
  String id,
  String text,

  /// Local midnight.
  DateTime dueOn,

  /// Breaks a tie between reminders due the same day.
  DateTime createdAt,
});

/// Soonest first; the same day, the oldest first.
List<Reminder> sortedReminders(Iterable<Reminder> reminders) =>
    [...reminders]..sort((a, b) {
      final byDay = a.dueOn.compareTo(b.dueOn);
      return byDay != 0 ? byDay : a.createdAt.compareTo(b.createdAt);
    });

/// What Add someone collects.
typedef PersonDraft = ({
  String name,
  Stage stage,
  String? phone,
  String? email,
  String? instagram,
});
