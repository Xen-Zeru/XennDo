import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/tasks/domain/subtask_draft.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';

class TaskDraft {
  const TaskDraft({
    required this.title,
    this.description,
    this.listId,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.dueTimeMinutes,
    this.reminderEnabled = false,
    this.reminderDate,
    this.reminderTimeMinutes,
    this.subtasks = const [],
  });

  final String title;
  final String? description;
  final String? listId;
  final TaskPriority priority;
  final LocalDate? dueDate;
  final int? dueTimeMinutes;
  final bool reminderEnabled;
  final LocalDate? reminderDate;
  final int? reminderTimeMinutes;
  final List<SubtaskDraft> subtasks;
}
