import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/core/time/current_date_provider.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/core/widgets/app_empty_state.dart';
import 'package:xenndo/core/widgets/app_error_state.dart';
import 'package:xenndo/core/widgets/app_loading_state.dart';
import 'package:xenndo/core/widgets/page_heading.dart';
import 'package:xenndo/features/progress/application/progress_providers.dart';
import 'package:xenndo/features/progress/domain/progress_summary.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/tasks/presentation/widgets/persisted_task_row.dart';
import 'package:xenndo/features/tasks/presentation/widgets/task_group.dart';
import 'package:xenndo/features/today/application/focus_providers.dart';
import 'package:xenndo/features/today/domain/today_agenda.dart';
import 'package:xenndo/features/today/presentation/widgets/top_three_card.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = MaterialLocalizations.of(context);
    final now = ref.watch(nowProvider)();
    final date = ref.watch(currentDateProvider);
    final agenda = ref.watch(todayAgendaProvider);
    final topThree = ref.watch(topThreeProvider);
    final dueTasks = ref.watch(dueTodayTasksProvider);
    final progress = dueTasks.hasValue
        ? ref.watch(dueTodayProgressProvider)
        : null;
    final focusTasks = topThree.value ?? const <TaskItem>[];
    final focusIds = focusTasks.map((task) => task.id).toSet();
    final overdueIds =
        agenda.value?.overdue.map((task) => task.id).toSet() ??
        const <String>{};

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const ValueKey('today-screen'),
        slivers: [
          SliverToBoxAdapter(
            child: PageHeading(
              title: 'Today',
              eyebrow: localizations.formatMediumDate(now),
              actions: [
                IconButton(
                  key: const ValueKey('search-action'),
                  tooltip: 'Search tasks',
                  onPressed: () => context.pushNamed('search'),
                  icon: const Icon(Icons.search_rounded, size: 22),
                ),
                IconButton(
                  key: const ValueKey('progress-action'),
                  tooltip: 'Progress',
                  onPressed: () => context.pushNamed('progress'),
                  icon: const Icon(Icons.insights_outlined, size: 22),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              0,
              AppSpacing.pageHorizontal,
              AppSpacing.pageBottom,
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TodayProgress(
                        progress: progress,
                        isError: dueTasks.hasError,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      _buildTopThreeCard(
                        context,
                        ref,
                        topThree,
                        now,
                        date,
                        overdueIds,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
                agenda.when(
                  data: (value) => _TodayAgendaView(
                    agenda: value,
                    now: now,
                    focusIds: focusIds,
                    hasFocus: focusIds.isNotEmpty,
                  ),
                  loading: () =>
                      const SliverToBoxAdapter(child: AppLoadingState()),
                  error: (error, stackTrace) => SliverToBoxAdapter(
                    child: AppErrorState(
                      title: 'Could not load today',
                      message:
                          'Your tasks could not be read from the database.',
                      onRetry: () => ref.invalidate(todayAgendaProvider),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThreeCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<TaskItem>> topThree,
    DateTime now,
    LocalDate date,
    Set<String> overdueIds,
  ) {
    return topThree.when(
      data: (tasks) => TopThreeCard(
        tasks: tasks,
        now: now,
        overdueTaskIds: overdueIds,
        onAdd: () => context.pushNamed('topThreePicker'),
        onOpenTask: (task) =>
            context.pushNamed('editTask', pathParameters: {'taskId': task.id}),
        onRemove: (task) => _runAction(
          context,
          () => ref
              .read(focusRepositoryProvider)
              .removeFromFocus(date: date, taskId: task.id),
          'Could not update My Top 3.',
        ),
        onToggleCompleted: (task, value) => _runAction(
          context,
          () =>
              ref.read(taskRepositoryProvider).setTaskCompleted(task.id, value),
          'Could not update this task.',
        ),
        onReorder: (ordered) => _runAction(
          context,
          () => ref
              .read(focusRepositoryProvider)
              .reorderFocus(
                date: date,
                orderedTaskIds: ordered.map((task) => task.id).toList(),
              ),
          'Could not reorder My Top 3.',
        ),
      ),
      loading: () => _emptyTopThreeCard(context, now),
      error: (error, stackTrace) => _emptyTopThreeCard(context, now),
    );
  }

  Widget _emptyTopThreeCard(BuildContext context, DateTime now) {
    return TopThreeCard(
      tasks: const [],
      now: now,
      onAdd: () => context.pushNamed('topThreePicker'),
      onOpenTask: (_) {},
      onRemove: (_) {},
      onToggleCompleted: (_, _) {},
      onReorder: (_) {},
    );
  }
}

class _TodayProgress extends StatelessWidget {
  const _TodayProgress({required this.progress, required this.isError});

  final DueDayProgress? progress;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final value = progress;
    if (value == null) {
      return Text(
        isError ? 'Progress unavailable' : 'Loading progress…',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: colors.onSurfaceVariant),
      );
    }
    if (!value.hasTasks) {
      return Text(
        'No tasks due',
        key: const ValueKey('today-progress-empty'),
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    return Semantics(
      label: '${value.completed} of ${value.total} tasks due today completed',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${value.completed} of ${value.total} due today complete',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: LinearProgressIndicator(
              value: value.fraction,
              minHeight: 16,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _runAction(
  BuildContext context,
  Future<void> Function() action,
  String errorMessage,
) async {
  try {
    await action();
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errorMessage)));
  }
}

class _TodayAgendaView extends ConsumerWidget {
  const _TodayAgendaView({
    required this.agenda,
    required this.now,
    required this.focusIds,
    required this.hasFocus,
  });

  final TodayAgenda agenda;
  final DateTime now;
  final Set<String> focusIds;
  final bool hasFocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overdue = _withoutFocus(agenda.overdue);
    final dueToday = _withoutFocus(agenda.dueToday);
    final completed = _withoutFocus(agenda.completedToday);

    if (overdue.isEmpty && dueToday.isEmpty && completed.isEmpty) {
      if (hasFocus) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }
      return SliverToBoxAdapter(
        child: AppEmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'Your day is clear',
          message: 'Add a task with a due date to see it in your day plan.',
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        if (overdue.isNotEmpty) ...[
          SliverTaskGroup(
            header: TaskSectionTitle(
              title: 'Overdue',
              icon: Icons.event_busy_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            itemCount: overdue.length,
            itemBuilder: (context, index) => PersistedTaskRow(
              task: overdue[index],
              isOverdue: true,
              now: now,
              flat: true,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],
        if (dueToday.isNotEmpty) ...[
          SliverTaskGroup(
            header: const TaskSectionTitle(
              title: 'Remaining today',
              icon: Icons.check_box_outlined,
            ),
            itemCount: dueToday.length,
            itemBuilder: (context, index) => PersistedTaskRow(
              task: dueToday[index],
              now: now,
              showTimeOnly: true,
              flat: true,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
        ],
        if (completed.isNotEmpty)
          SliverTaskGroup(
            header: const TaskSectionTitle(
              title: 'Completed',
              icon: Icons.done_all_rounded,
            ),
            itemCount: completed.length,
            itemBuilder: (context, index) => PersistedTaskRow(
              task: completed[index],
              now: now,
              showTimeOnly:
                  completed[index].dueDate == LocalDate.fromDateTime(now),
              flat: true,
            ),
          ),
      ],
    );
  }

  List<TaskItem> _withoutFocus(List<TaskItem> tasks) {
    if (focusIds.isEmpty) {
      return tasks;
    }
    return tasks
        .where((task) => !focusIds.contains(task.id))
        .toList(growable: false);
  }
}
