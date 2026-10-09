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
  reminders: person.reminders,
);

/// Where ticking [stepId] leads: the next step's position, or 1e9 once done
/// (far past any step, so a step moved or added at the end stays unmet).
num positionAfter(Workflow workflow, String stepId) {
  final steps = workflow.steps;
  final index = steps.indexWhere((step) => step.id == stepId);
  return index + 1 < steps.length ? steps[index + 1].position : 1e9;
}
