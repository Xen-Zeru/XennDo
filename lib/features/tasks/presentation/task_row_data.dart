import 'package:flutter/foundation.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';

@immutable
class TaskRowData {
  const TaskRowData({
    required this.id,
    required this.title,
    this.description,
    this.listName,
    this.listColor,
    this.timeLabel,
    this.dueLabel,
    this.priority = TaskPriority.none,
    this.isCompleted = false,
    this.isOverdue = false,
    this.completedSubtasks = 0,
    this.totalSubtasks = 0,
  });

  final String id;
  final String title;
  final String? description;
  final String? listName;
  final int? listColor;
  final String? timeLabel;
  final String? dueLabel;
  final TaskPriority priority;
  final bool isCompleted;
  final bool isOverdue;
  final int completedSubtasks;
  final int totalSubtasks;
}
