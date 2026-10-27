import 'package:xenndo/features/tasks/domain/task_item.dart';

class TodayAgenda {
  const TodayAgenda({
    required this.overdue,
    required this.dueToday,
    required this.completedToday,
  });

  final List<TaskItem> overdue;
  final List<TaskItem> dueToday;
  final List<TaskItem> completedToday;

  bool get isEmpty =>
      overdue.isEmpty && dueToday.isEmpty && completedToday.isEmpty;
}
