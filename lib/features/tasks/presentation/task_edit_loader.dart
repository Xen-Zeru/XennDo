import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xenndo/core/widgets/app_error_state.dart';
import 'package:xenndo/core/widgets/app_loading_state.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/tasks/domain/subtask_draft.dart';
import 'package:xenndo/features/tasks/domain/subtask_item.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';
import 'package:xenndo/features/tasks/presentation/task_editor_screen.dart';

/// An editor owns a local working copy. Database changes during Save/Delete
/// must not dispose it while it waits for the platform reminder operation.
final _editorDataProvider = FutureProvider.autoDispose
    .family<({TaskItem? task, List<SubtaskItem> subtasks}), String>((
      ref,
      id,
    ) async {
      final repository = ref.watch(taskRepositoryProvider);
      final task = await repository.getTask(id);
      return (
        task: task,
        subtasks: task == null
            ? <SubtaskItem>[]
            : await repository.getSubtasks(id),
      );
    });

class TaskEditLoader extends ConsumerWidget {
  const TaskEditLoader({required this.taskId, super.key});
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(_editorDataProvider(taskId))
        .when(
          loading: () =>
              const Scaffold(body: AppLoadingState(message: 'Loading task...')),
          error: (_, _) => _message(
            context,
            AppErrorState(
              title: 'Could not load task',
              message: 'The task and its subtasks could not be read.',
              onRetry: () => ref.invalidate(_editorDataProvider(taskId)),
            ),
          ),
          data: (data) {
            final task = data.task;
            if (task == null) {
              return _message(
                context,
                const AppErrorState(
                  title: 'Task not found',
                  message: 'This task may have been deleted.',
                ),
              );
            }
            return TaskEditorScreen(
              key: ValueKey('editor-$taskId'),
              taskId: taskId,
              initialValues: TaskEditorInitialValues(
                taskId: taskId,
                title: task.title,
                description: task.description ?? '',
                listId: task.listId,
                priority: task.priority == TaskPriority.none
                    ? TaskPriority.medium
                    : task.priority,
                dueDate: task.dueDate,
                dueTimeMinutes: task.dueTimeMinutes,
                reminderEnabled:
                    task.reminderAt != null || task.reminderDate != null,
                reminderDate: task.reminderDate,
                reminderTimeMinutes: task.reminderTimeMinutes,
                subtasks: [
                  for (final subtask in data.subtasks)
                    SubtaskDraft(
                      id: subtask.id,
                      title: subtask.title,
                      isCompleted: subtask.isCompleted,
                    ),
                ],
              ),
            );
          },
        );
  }

  Widget _message(BuildContext context, Widget body) => Scaffold(
    appBar: AppBar(
      title: const Text('Task'),
      leading: IconButton(
        tooltip: 'Close',
        icon: const Icon(Icons.close_rounded),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.goNamed('today');
          }
        },
      ),
    ),
    body: body,
  );
}
