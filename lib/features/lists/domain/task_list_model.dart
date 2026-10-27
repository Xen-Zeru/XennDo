class TaskListModel {
  const TaskListModel({
    required this.id,
    required this.name,
    required this.color,
    required this.sortOrder,
    required this.isInbox,
    required this.createdAt,
    required this.updatedAt,
    this.icon,
  });

  final String id;
  final String name;
  final int color;
  final String? icon;
  final int sortOrder;
  final bool isInbox;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class TaskListSummary {
  const TaskListSummary({
    required this.id,
    required this.name,
    required this.color,
    required this.sortOrder,
    required this.isInbox,
    required this.openTaskCount,
    this.completedTaskCount = 0,
    this.icon,
  });

  final String id;
  final String name;
  final int color;
  final String? icon;
  final int sortOrder;
  final bool isInbox;
  final int openTaskCount;
  final int completedTaskCount;
  int get totalTaskCount => openTaskCount + completedTaskCount;
  double get completionFraction =>
      totalTaskCount == 0 ? 0 : completedTaskCount / totalTaskCount;
}
