import 'package:xenndo/features/tasks/presentation/task_deletion_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/tasks/presentation/task_view_data.dart';
import 'package:xenndo/features/tasks/presentation/widgets/task_row.dart';

class PersistedTaskRow extends ConsumerWidget {
  const PersistedTaskRow({
    required this.task,
    required this.now,
    super.key,
    this.isOverdue = false,
    this.showTimeOnly = false,
    this.timeColumn = false,
    this.onTap,
    this.onMoveUp,
    this.onMoveDown,
    this.flat = false,
    this.showDateOnlyLabel = false,
  });

  final TaskItem task;
  final DateTime now;
  final bool isOverdue;
  final bool showTimeOnly;
  final bool timeColumn;
  final VoidCallback? onTap;
  final bool flat;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final bool showDateOnlyLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void openTask() {
      context.pushNamed('editTask', pathParameters: {'taskId': task.id});
    }

    final subtasks = ref.watch(subtaskProgressProvider).value?[task.id];
    return TaskRow(
      flat: flat,
      onMoveUp: onMoveUp,
      onMoveDown: onMoveDown,
      data: taskToRowData(
        task,
        context: context,
        now: now,
        isOverdue: isOverdue,
        showTimeOnly: showTimeOnly,
        timeColumn: timeColumn,
        showDateOnlyLabel: showDateOnlyLabel,
        completedSubtasks: subtasks?.completed ?? 0,
        totalSubtasks: subtasks?.total ?? 0,
      ),
      onTap: onTap ?? openTask,
      onEdit: openTask,
      onDelete: () => _deleteTask(context, ref),
      onCompletionChanged: (value) async {
        try {
          await ref
              .read(taskRepositoryProvider)
              .setTaskCompleted(task.id, value);
        } catch (error) {
          if (!context.mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not update this task. Please try again.'),
            ),
          );
          return;
        }
        await HapticFeedback.selectionClick();
      },
    );
  }

  Future<void> _deleteTask(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(taskRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final snapshot = await repository.deleteTaskWithSnapshot(task.id);
      showTaskDeletionNotice(messenger, repository, snapshot);
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not delete this task. Please try again.'),
          ),
        );
      }
    }
  }
}
