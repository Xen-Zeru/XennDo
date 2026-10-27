import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';

enum TaskCompletionFilter {
  all('All'),
  incomplete('Incomplete'),
  completed('Completed');

  const TaskCompletionFilter(this.label);

  final String label;
}

const _unset = Object();

class TaskFilter {
  const TaskFilter({
    this.query = '',
    this.dueFrom,
    this.dueThrough,
    this.listId,
    this.priority,
    this.completion = TaskCompletionFilter.all,
  });

  final LocalDate? dueFrom;
  final LocalDate? dueThrough;
  final String query;
  final String? listId;
  final TaskPriority? priority;
  final TaskCompletionFilter completion;

  bool get isActive =>
      dueFrom != null ||
      dueThrough != null ||
      query.trim().isNotEmpty ||
      listId != null ||
      priority != null ||
      completion != TaskCompletionFilter.all;

  TaskFilter copyWith({
    String? query,
    Object? dueFrom = _unset,
    Object? dueThrough = _unset,
    Object? listId = _unset,
    Object? priority = _unset,
    TaskCompletionFilter? completion,
  }) {
    return TaskFilter(
      query: query ?? this.query,
      dueFrom: identical(dueFrom, _unset)
          ? this.dueFrom
          : dueFrom as LocalDate?,
      dueThrough: identical(dueThrough, _unset)
          ? this.dueThrough
          : dueThrough as LocalDate?,
      listId: identical(listId, _unset) ? this.listId : listId as String?,
      priority: identical(priority, _unset)
          ? this.priority
          : priority as TaskPriority?,
      completion: completion ?? this.completion,
    );
  }

  TaskFilter cleared() => const TaskFilter();
}
