import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/time/current_date_provider.dart';
import 'package:xenndo/features/progress/domain/progress_summary.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';

/// Number of local days shown on the Progress screen.
const int progressWindowDays = 7;

/// Tasks completed during the current local day.
final completedTodayProvider = StreamProvider.autoDispose<List<TaskItem>>((
  ref,
) {
  final today = ref.watch(currentDateProvider);
  return ref.watch(taskRepositoryProvider).watchCompletedOn(day: today);
});

/// Tasks whose due date is the current local day, completed or still open.
final dueTodayTasksProvider = StreamProvider.autoDispose<List<TaskItem>>((ref) {
  final today = ref.watch(currentDateProvider);
  return ref.watch(taskRepositoryProvider).watchTasksDueOn(day: today);
});

/// Tasks completed in the window of [progressWindowDays] local days ending
/// today.
final lastSevenDayCompletionsProvider =
    StreamProvider.autoDispose<List<TaskItem>>((ref) {
      final today = ref.watch(currentDateProvider);
      return ref
          .watch(taskRepositoryProvider)
          .watchCompletedBetween(
            firstDay: today.addDays(-(progressWindowDays - 1)),
            lastDayExclusive: today.addDays(1),
          );
    });

/// Completion counts per local day for the last [progressWindowDays] days,
/// oldest day first. Derived from stored completion timestamps.
final completionCountsProvider = Provider.autoDispose<List<DayCompletionCount>>(
  (ref) {
    final today = ref.watch(currentDateProvider);
    final tasks =
        ref.watch(lastSevenDayCompletionsProvider).value ?? const <TaskItem>[];
    final completedAt = <DateTime>[
      for (final task in tasks)
        if (task.completedAt != null) task.completedAt!,
    ];
    return ProgressSummary.completionsByDay(
      completedAtUtc: completedAt,
      days: ProgressSummary.lastDays(today, progressWindowDays),
    );
  },
);

/// Today's due-task progress, or a zero-total result when nothing is due.
final dueTodayProgressProvider = Provider.autoDispose<DueDayProgress>((ref) {
  final tasks = ref.watch(dueTodayTasksProvider).value ?? const <TaskItem>[];
  final completed = tasks.where((task) => task.isCompleted).length;
  return ProgressSummary.dueProgress(total: tasks.length, completed: completed);
});
