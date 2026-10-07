import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/calendar/presentation/calendar_controller.dart';
import 'package:loomia/features/workflows/data/event_workflow_repository.dart';
import 'package:loomia/features/workflows/domain/event_workflow.dart';
import 'package:loomia/features/workflows/presentation/workflows_controller.dart';

/// One account's event workflows, `eventWorkflowsProvider(account?.email)`.
/// Waits for the person workflows first: their load is what seeds Workshop,
/// and a deleted workflow changes the stages these start. No automatic
/// retry.
final eventWorkflowsProvider =
    AsyncNotifierProvider.family<
      EventWorkflowsController,
      List<EventWorkflow>,
      String?
    >(EventWorkflowsController.new, retry: (error, _) => null);

class EventWorkflowsController extends AsyncNotifier<List<EventWorkflow>> {
  EventWorkflowsController(this.owner);

  /// The email of the account; null when signed out.
  final String? owner;

  @override
  Future<List<EventWorkflow>> build() async {
    final repository = ref.watch(eventWorkflowRepositoryProvider);
    if (owner == null) return const [];
    await ref.watch(workflowsProvider(owner).future);
    return repository.list();
  }

  /// Runs [write], then reloads, and the events: a deleted event workflow
  /// leaves theirs without one. Rethrows its `PeopleFailure`.
  Future<T> edit<T>(
    Future<T> Function(EventWorkflowRepository repository) write,
  ) async {
    final result = await write(ref.read(eventWorkflowRepositoryProvider));
    if (ref.mounted) {
      ref
        ..invalidateSelf()
        ..invalidate(eventsProvider(owner));
    }
    return result;
  }
}

/// [EventWorkflowsController.edit] on the signed-in account, read at call
/// time.
Future<T> editEventWorkflows<T>(
  WidgetRef ref,
  Future<T> Function(EventWorkflowRepository repository) write,
) => ref
    .read(eventWorkflowsProvider(ref.read(accountProvider)?.email).notifier)
    .edit(write);
