import 'package:go_router/go_router.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/features/tasks/presentation/widgets/persisted_task_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/core/widgets/app_empty_state.dart';
import 'package:xenndo/core/widgets/app_error_state.dart';
import 'package:xenndo/core/widgets/app_loading_state.dart';
import 'package:xenndo/core/widgets/section_header.dart';
import 'package:xenndo/features/progress/application/progress_providers.dart';
import 'package:xenndo/features/progress/domain/progress_summary.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';

/// Completion insight for today and the last seven local days.
///
/// Every number on this screen is derived from task rows, so reopening a task
/// updates it immediately.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = MaterialLocalizations.of(context);
    final completedToday = ref.watch(completedTodayProvider);
    final dueProgress = ref.watch(dueTodayProgressProvider);
    final dueTasks = ref.watch(dueTodayTasksProvider);
    final history = ref.watch(lastSevenDayCompletionsProvider);
    final counts = ref.watch(completionCountsProvider);
    final totalCompleted = counts.fold(0, (sum, day) => sum + day.count);

    return Scaffold(
      key: const ValueKey('progress-screen'),
      appBar: AppBar(title: const Text('Progress')),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                0,
                AppSpacing.pageHorizontal,
                AppSpacing.pageBottom,
              ),
              sliver: SliverList.list(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: const ValueKey('completion-history-action'),
                      onPressed: () => context.pushNamed('completionHistory'),
                      icon: const Icon(Icons.history_outlined),
                      label: const Text('Completion history'),
                    ),
                  ),
                  if (dueTasks.hasError || history.hasError)
                    AppErrorState(
                      title: 'Could not load progress',
                      message: 'Try reading your task history again.',
                      onRetry: () {
                        ref.invalidate(dueTodayTasksProvider);
                        ref.invalidate(lastSevenDayCompletionsProvider);
                      },
                    )
                  else if (!dueTasks.hasValue || !history.hasValue)
                    const AppLoadingState()
                  else
                    completedToday.when(
                      data: (tasks) {
                        final isEverythingEmpty =
                            tasks.isEmpty &&
                            !dueProgress.hasTasks &&
                            totalCompleted == 0;
                        if (isEverythingEmpty) {
                          return const Card(
                            child: AppEmptyState(
                              icon: Icons.insights_outlined,
                              title: 'No progress yet',
                              message: 'Complete a task and your daily progress will start taking shape.',
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DueTodayCard(progress: dueProgress),
                            const SizedBox(height: AppSpacing.lg),
                            _CompletedTodayCard(tasks: tasks),
                            const SizedBox(height: AppSpacing.lg),
                            _SevenDayCard(
                              counts: counts,
                              localizations: localizations,
                              totalCompleted: totalCompleted,
                            ),
                          ],
                        );
                      },
                      loading: () => const AppLoadingState(
                        message: 'Loading your progress...',
                      ),
                      error: (error, stackTrace) => AppErrorState(
                        title: 'Could not load progress',
                        message: 'Your completion history could not be read.',
                        onRetry: () => ref.invalidate(completedTodayProvider),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueTodayCard extends StatelessWidget {
  const _DueTodayCard({required this.progress});

  final DueDayProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const ValueKey('due-today-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(
              title: 'Due today',
              supportingText: 'Tasks whose due date is today, whether completed or still open.',
            ),
            const SizedBox(height: AppSpacing.md),
            if (!progress.hasTasks) ...[
              Text('No tasks due', style: theme.textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Nothing carries a due date of today, so there is no percentage to show.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ] else ...[
              Text(
                '${progress.completed} of ${progress.total} done',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                label:
                    '${progress.completed} of ${progress.total} tasks due today are completed',
                child: ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: LinearProgressIndicator(
                      value: progress.fraction,
                      minHeight: 10,
                      backgroundColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${progress.percent}% complete · ${progress.open} still open',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Tasks with an earlier due date are not counted here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CompletedTodayCard extends ConsumerWidget {
  const _CompletedTodayCard({required this.tasks});

  final List<TaskItem> tasks;

  static const int _visibleLimit = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider)();
    final visible = tasks.take(_visibleLimit).toList(growable: false);
    final hidden = tasks.length - visible.length;

    return Card(
      key: const ValueKey('completed-today-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Completed today',
              supportingText: tasks.isEmpty
                  ? 'Nothing finished yet since midnight.'
                  : '${tasks.length} ${tasks.length == 1 ? 'task' : 'tasks'} finished since midnight.',
            ),
            if (tasks.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              for (final task in visible)
                PersistedTaskRow(task: task, now: now, flat: true),
              if (hidden > 0) ...[
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => context.pushNamed('completionHistory'),
                  child: Text('View $hidden more in history'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SevenDayCard extends StatelessWidget {
  const _SevenDayCard({
    required this.counts,
    required this.localizations,
    required this.totalCompleted,
  });

  final List<DayCompletionCount> counts;
  final MaterialLocalizations localizations;
  final int totalCompleted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final peak = counts.fold(
      1,
      (max, day) => day.count > max ? day.count : max,
    );

    return Card(
      key: const ValueKey('seven-day-card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Last 7 days',
              supportingText:
                  '$totalCompleted completed across ${counts.length} local days',
            ),
            const SizedBox(height: AppSpacing.md),
            for (final day in counts)
              _CompletionBar(
                day: day.day,
                count: day.count,
                fraction: day.count / peak,
                localizations: localizations,
              ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Counts come from each task completion time. Reopening a task clears its completion record, so it leaves these counts; individual completion events are not stored in this version.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionBar extends StatelessWidget {
  const _CompletionBar({
    required this.day,
    required this.count,
    required this.fraction,
    required this.localizations,
  });

  final LocalDate day;
  final int count;
  final double fraction;
  final MaterialLocalizations localizations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final date = day.toLocalDateTime();
    final weekday = localizations.narrowWeekdays[date.weekday % 7];
    final label =
        '${localizations.formatFullDate(date)}: $count ${count == 1 ? 'task' : 'tasks'} completed';

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Text(
                  '$weekday ${day.day}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: LinearProgressIndicator(
                    value: fraction.clamp(0.0, 1.0),
                    minHeight: 12,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  ),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '$count',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
