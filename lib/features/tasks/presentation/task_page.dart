import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loomia/app/router/back.dart';
import 'package:loomia/app/router/routes.dart';
import 'package:loomia/features/auth/data/auth_repository.dart';
import 'package:loomia/features/tasks/presentation/tasks_controller.dart';
import 'package:material_ui/material_ui.dart';

/// One task on mobile and tablet (#390): a screen of its own above the one
/// it was opened from, as an event's.
class TaskPage extends StatelessWidget {
  const TaskPage({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => backOr(context, Routes.calendar)),
      ),
      body: SafeArea(top: false, child: TaskPane(id: id)),
    );
  }
}

/// A task found in the loaded tasks (no second fetch). Shared by [TaskPage]
/// and the Calendar's desktop pane.
class TaskPane extends ConsumerWidget {
  const TaskPane({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider(ref.watch(accountProvider)?.email));
    final task = tasks.value?.where((task) => task.id == id).firstOrNull;
    return Text(task?.title ?? '');
  }
}
