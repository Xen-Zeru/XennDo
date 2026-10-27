import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/tasks/domain/reminder_offset.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';

TaskItem mapTaskRow(Task task, {TaskList? list}) {
  final reminderLocal = _resolveReminderLocal(task);
  return TaskItem(
    id: task.id,
    title: task.title,
    sortOrder: task.sortOrder,
    description: task.description,
    listId: task.listId,
    listName: list?.name,
    listColor: list?.color,
    priority:
        TaskPriority.values.elementAtOrNull(task.priority) ?? TaskPriority.none,
    dueDate: task.dueDate,
    dueTimeMinutes: task.dueTimeMinutes,
    isCompleted: task.isCompleted,
    completedAt: task.completedAt,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
    reminderAt: task.reminderAt,
    reminderDate: reminderLocal.$1,
    reminderTimeMinutes: reminderLocal.$2,
    reminderOffset: ReminderOffset.fromMinutes(task.reminderOffsetMinutes),
    notificationId: task.notificationId,
  );
}

/// Returns the stored local reminder date/time, falling back to the local
/// representation of [Task.reminderAt] for rows created before schema version 2.
(LocalDate?, int?) _resolveReminderLocal(Task task) {
  if (task.reminderDate != null && task.reminderTimeMinutes != null) {
    return (task.reminderDate, task.reminderTimeMinutes);
  }
  final instant = task.reminderAt;
  if (instant == null) {
    return (null, null);
  }
  final local = instant.toLocal();
  return (
    LocalDate.fromDateTime(local),
    local.hour * Duration.minutesPerHour + local.minute,
  );
}
