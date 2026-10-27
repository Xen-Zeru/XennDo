import 'package:xenndo/features/tasks/domain/subtask_item.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/today/domain/focus_selection.dart';

/// Everything needed to restore a deleted task reliably.
///
/// Captured in the same transaction that deletes the task so an undo can
/// recreate the task, its subtasks, and its daily focus selections.
class TaskDeletionSnapshot {
  const TaskDeletionSnapshot({
    required this.task,
    required this.subtasks,
    required this.focusSelections,
  });

  final TaskItem task;
  final List<SubtaskItem> subtasks;
  final List<FocusSelection> focusSelections;
}
