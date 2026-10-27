import 'package:xenndo/features/reminders/application/reminder_notice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/database/database_provider.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/core/time/current_date_provider.dart';
import 'package:xenndo/features/reminders/application/reminder_providers.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';
import 'package:xenndo/features/tasks/domain/subtask_item.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/today/domain/today_agenda.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(nowProvider),
    reminderScheduler: ref.watch(reminderSchedulerProvider),
    onNotice: (message) =>
        ref.read(reminderNoticeProvider.notifier).show(message),
  );
});

final todayAgendaProvider = StreamProvider.autoDispose<TodayAgenda>((ref) {
  final today = ref.watch(currentDateProvider);
  return ref.watch(taskRepositoryProvider).watchToday(today: today);
});

final upcomingTasksProvider = StreamProvider.autoDispose<List<TaskItem>>((ref) {
  final today = ref.watch(currentDateProvider);
  return ref.watch(taskRepositoryProvider).watchUpcoming(after: today);
});

final incompleteTasksProvider = StreamProvider.autoDispose<List<TaskItem>>((
  ref,
) {
  return ref.watch(taskRepositoryProvider).watchAllIncomplete();
});

final tasksForListProvider = StreamProvider.autoDispose
    .family<List<TaskItem>, String>((ref, listId) {
      return ref.watch(taskRepositoryProvider).watchTasksForList(listId);
    });

final taskProvider = StreamProvider.autoDispose.family<TaskItem?, String>((
  ref,
  taskId,
) {
  return ref.watch(taskRepositoryProvider).watchTask(taskId);
});

final subtasksProvider = StreamProvider.autoDispose
    .family<List<SubtaskItem>, String>((ref, taskId) {
      return ref.watch(taskRepositoryProvider).watchSubtasks(taskId);
    });

final subtaskProgressProvider =
    StreamProvider.autoDispose<Map<String, ({int completed, int total})>>(
      (ref) => ref.watch(taskRepositoryProvider).watchSubtaskProgress(),
    );
