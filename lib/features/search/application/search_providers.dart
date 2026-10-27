import 'package:xenndo/core/time/local_date.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/tasks/domain/task_filter.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';

final taskFilterProvider =
    NotifierProvider.autoDispose<TaskFilterController, TaskFilter>(
      TaskFilterController.new,
    );

class TaskFilterController extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => const TaskFilter();

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setList(String? listId) {
    state = state.copyWith(listId: listId);
  }

  void setPriority(TaskPriority? priority) {
    state = state.copyWith(priority: priority);
  }

  void setCompletion(TaskCompletionFilter completion) {
    state = state.copyWith(completion: completion);
  }

  void setDateRange(LocalDate? from, LocalDate? through) {
    state = state.copyWith(dueFrom: from, dueThrough: through);
  }

  void clear() {
    state = state.cleared();
  }
}

final filteredTasksProvider = StreamProvider.autoDispose<List<TaskItem>>((ref) {
  final filter = ref.watch(taskFilterProvider);
  return ref.watch(taskRepositoryProvider).watchFilteredTasks(filter);
});
