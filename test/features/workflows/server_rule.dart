import 'package:loomia/features/calendar/domain/calendar_event.dart';
import 'package:loomia/features/contacts/domain/person.dart';
import 'package:loomia/features/workflows/domain/progress.dart';
import 'package:loomia/features/workflows/domain/workflow.dart';

/// The one Dart copy of the server's rule (`current_step_id`, `due_on`,
/// `complete_step`), so fakes answer like the database. Test-only: the app
/// never computes a step. supabase/tests/due_test.sql pins the real one.
Person withServerFields(Person person, List<Workflow> workflows) {
  final place = person.place;
  final step = place == null
      ? null
      : findWorkflow(
          workflows,
          place.workflowId,
        )?.steps.where((step) => step.position >= place.atPosition).firstOrNull;
  return Person(
    id: person.id,
    name: person.name,
    stage: person.stage,
    stageSince: person.stageSince,
    prospectStatus: person.prospectStatus,
    phone: person.phone,
    email: person.email,
    instagram: person.instagram,
    needs: person.needs,
    products: person.products,
    profession: person.profession,
    address: person.address,
    notes: person.notes,
    why: person.why,
    ownGoal: person.ownGoal,
    timeAvailable: person.timeAvailable,
    wouldLoveTo: person.wouldLoveTo,
    strengths: person.strengths,
    stuckOn: person.stuckOn,
    currentLevel: person.currentLevel,
    targetLevel: person.targetLevel,
    targetLevelBy: person.targetLevelBy,
    monthlyVolumeTarget: person.monthlyVolumeTarget,
    place: place,
    pausedAt: person.pausedAt,
    currentStepId: step?.id,
    dueOn: step == null || place == null || person.pausedAt != null
        ? null
        : addDays(place.lastTick, step.days),
    lastContactOn: person.lastContactOn,
    reminders: person.reminders,
    photoPath: person.photoPath,
    loyaltySince: person.loyaltySince,
  );
}

/// [person] with the server's `last_contact_on`, as the fake reads it from
/// its history.
Person withLastContact(Person person, DateTime? day) => Person(
  id: person.id,
  name: person.name,
  stage: person.stage,
  stageSince: person.stageSince,
  prospectStatus: person.prospectStatus,
  phone: person.phone,
  email: person.email,
  instagram: person.instagram,
  needs: person.needs,
  products: person.products,
  profession: person.profession,
  address: person.address,
  notes: person.notes,
  why: person.why,
  ownGoal: person.ownGoal,
  timeAvailable: person.timeAvailable,
  wouldLoveTo: person.wouldLoveTo,
  strengths: person.strengths,
  stuckOn: person.stuckOn,
  currentLevel: person.currentLevel,
  targetLevel: person.targetLevel,
  targetLevelBy: person.targetLevelBy,
  monthlyVolumeTarget: person.monthlyVolumeTarget,
  place: person.place,
  pausedAt: person.pausedAt,
  currentStepId: person.currentStepId,
  dueOn: person.dueOn,
  lastContactOn: day,
  photoPath: person.photoPath,
  loyaltySince: person.loyaltySince,
  reminders: person.reminders,
);

/// Where ticking [stepId] leads: the next step's position; past the last,
/// the first step's when the workflow repeats, else 1e9 once done (far past
/// any step, so a step moved or added at the end stays unmet).
num positionAfter(Workflow workflow, String stepId) {
  final steps = workflow.steps;
  final index = steps.indexWhere((step) => step.id == stepId);
  if (index + 1 < steps.length) return steps[index + 1].position;
  return workflow.repeats ? steps.first.position : 1e9;
}

/// The Dart copy of `follow_up_on`: 3 days after the invite or the last
/// follow-up, for someone not yet going on an event not [done].
DateTime? followUpOn(Attendee attendee, {required bool done}) {
  final from = attendee.followedUpOn ?? attendee.invitedOn;
  if (attendee.going || done || from == null) return null;
  return addDays(from, 3);
}
