import 'package:flutter/material.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/tasks/presentation/task_row_data.dart';

TaskRowData taskToRowData(
  TaskItem task, {
  required BuildContext context,
  required DateTime now,
  required bool isOverdue,
  bool showTimeOnly = false,
  bool timeColumn = false,
  bool showDateOnlyLabel = false,
  int completedSubtasks = 0,
  int totalSubtasks = 0,
}) {
  return TaskRowData(
    id: task.id,
    title: task.title,
    description: task.description,
    listName: task.listName,
    listColor: task.listColor,
    timeLabel: timeColumn
        ? _formatTimeOnly(task.dueTimeMinutes, context) ?? 'Date only'
        : null,
    dueLabel: timeColumn
        ? null
        : showTimeOnly
        ? (task.dueTimeMinutes == null &&
                  task.dueDate != null &&
                  showDateOnlyLabel
              ? 'Date only'
              : _formatTimeOnly(task.dueTimeMinutes, context))
        : formatDueLabel(
            dueDate: task.dueDate,
            dueTimeMinutes: task.dueTimeMinutes,
            now: now,
            context: context,
          ),
    completedSubtasks: completedSubtasks,
    totalSubtasks: totalSubtasks,
    priority: task.priority,
    isCompleted: task.isCompleted,
    isOverdue: isOverdue && !task.isCompleted,
  );
}

String? _formatTimeOnly(int? dueTimeMinutes, BuildContext context) {
  if (dueTimeMinutes == null) {
    return null;
  }
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(
      hour: dueTimeMinutes ~/ Duration.minutesPerHour,
      minute: dueTimeMinutes % Duration.minutesPerHour,
    ),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

String? formatDueLabel({
  required LocalDate? dueDate,
  required int? dueTimeMinutes,
  required DateTime now,
  required BuildContext context,
}) {
  if (dueDate == null) {
    return null;
  }

  final today = LocalDate.fromDateTime(now);
  final dateLabel = switch (dueDate) {
    _ when dueDate == today => 'Today',
    _ when dueDate == today.addDays(-1) => 'Yesterday',
    _ when dueDate == today.addDays(1) => 'Tomorrow',
    _ => MaterialLocalizations.of(
      context,
    ).formatMediumDate(dueDate.toLocalDateTime()),
  };

  if (dueTimeMinutes == null) {
    return dateLabel;
  }

  final timeLabel = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay(
      hour: dueTimeMinutes ~/ Duration.minutesPerHour,
      minute: dueTimeMinutes % Duration.minutesPerHour,
    ),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
  return '$dateLabel · $timeLabel';
}
