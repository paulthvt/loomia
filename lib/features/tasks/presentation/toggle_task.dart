import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/core/ui/pick_day.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/contacts/domain/people_failure.dart';
import 'package:loomia/features/contacts/presentation/people_copy.dart';
import 'package:loomia/features/contacts/presentation/undo_tick.dart';
import 'package:loomia/features/tasks/domain/task.dart';
import 'package:loomia/features/tasks/presentation/tasks_controller.dart';
import 'package:loomia/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// A task's ring: an open task is done today, with Undo; a done one opens
/// again, with no snackbar. A failure says so in a SnackBar. The caller
/// keeps the ring busy meanwhile.
Future<void> toggleTask(BuildContext context, WidgetRef ref, Task task) async {
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final owner = ref.read(accountProvider)?.email;
  try {
    await ref
        .read(tasksProvider(owner).notifier)
        .setDone(task, task.done ? null : today());
    if (!context.mounted || task.done) return;
    offerUndo(
      context,
      l10n.tickDone(task.title),
      (container) =>
          container.read(tasksProvider(owner).notifier).setDone(task, null),
    );
  } on PeopleFailure catch (failure) {
    messenger.showSnackBar(
      SnackBar(content: Text(peopleFailureCopy(l10n, failure))),
    );
  }
}
