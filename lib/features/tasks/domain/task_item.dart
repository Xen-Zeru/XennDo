import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/tasks/domain/reminder_offset.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';

class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.priority,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
    this.description,
    this.listId,
    this.listName,
    this.listColor,
    this.dueDate,
    this.dueTimeMinutes,
    this.completedAt,
    this.reminderAt,
    this.reminderDate,
    this.reminderTimeMinutes,
    this.reminderOffset,
    this.notificationId,
  });

  final int sortOrder;
  final String id;
  final String title;
  final String? description;
  final String? listId;
  final String? listName;
  final int? listColor;
  final TaskPriority priority;
  final LocalDate? dueDate;
  final int? dueTimeMinutes;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? reminderAt;
  final LocalDate? reminderDate;
  final int? reminderTimeMinutes;
  final ReminderOffset? reminderOffset;
  final int? notificationId;
}
