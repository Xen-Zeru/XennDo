import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/core/time/current_date_provider.dart';
import 'package:xenndo/core/widgets/app_empty_state.dart';
import 'package:xenndo/core/widgets/app_error_state.dart';
import 'package:xenndo/core/widgets/app_loading_state.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/tasks/presentation/task_view_data.dart';
import 'package:xenndo/features/tasks/presentation/widgets/priority_badge.dart';
import 'package:xenndo/features/today/application/focus_providers.dart';
import 'package:xenndo/features/today/domain/focus_exceptions.dart';

class TopThreePickerScreen extends ConsumerWidget {
  const TopThreePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider)();
    final date = ref.watch(currentDateProvider);
    final tasks = ref.watch(incompleteTasksProvider);
    final selected = ref.watch(topThreeProvider).value ?? const <TaskItem>[];
    final selectedIds = selected.map((task) => task.id).toSet();

    return Scaffold(
      key: const ValueKey('top-three-picker-screen'),
      appBar: AppBar(
        title: const Text('My Top 3'),
        actions: [
          TextButton(
            key: const ValueKey('top-three-done'),
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Done'),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: tasks.when(
          loading: () => const AppLoadingState(message: 'Loading tasks...'),
          error: (error, stackTrace) => AppErrorState(
            title: 'Could not load tasks',
            message: 'Your tasks could not be read from the database.',
            onRetry: () => ref.invalidate(incompleteTasksProvider),
          ),
          data: (value) {
            if (value.isEmpty) {
              return const AppEmptyState(
                icon: Icons.filter_3_rounded,
                title: 'No tasks to choose',
                message: 'Add an incomplete task first, then pick your focus.',
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.lg,
                AppSpacing.pageHorizontal,
                AppSpacing.xxxl,
              ),
              children: [
                Text(
                  'Choose up to three tasks for today.',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${selected.where((task) => !task.isCompleted).length} of 3 active selections. Selections are saved for ${date.toIso8601String()}.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                for (final task in value) ...[
                  _FocusChoiceTile(
                    task: task,
                    now: now,
                    selected: selectedIds.contains(task.id),
                    onToggle: () => _toggle(
                      context,
                      ref,
                      task: task,
                      selected: selectedIds.contains(task.id),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref, {
    required TaskItem task,
    required bool selected,
  }) async {
    final date = ref.read(currentDateProvider);
    final repository = ref.read(focusRepositoryProvider);

    try {
      if (selected) {
        await repository.removeFromFocus(date: date, taskId: task.id);
      } else {
        await repository.addToFocus(date: date, taskId: task.id);
      }
    } on FocusLimitException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('My Top 3 already has three tasks for today.'),
          ),
        );
      }
    } on FocusDuplicateException {
      // Already selected; nothing to do.
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update My Top 3.')),
        );
      }
    }
  }
}

class _FocusChoiceTile extends StatelessWidget {
  const _FocusChoiceTile({
    required this.task,
    required this.now,
    required this.selected,
    required this.onToggle,
  });

  final TaskItem task;
  final DateTime now;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final rowData = taskToRowData(
      task,
      context: context,
      now: now,
      isOverdue: false,
    );
    final borderRadius = BorderRadius.circular(AppRadii.lg);

    return Material(
      color: selected
          ? colorScheme.secondaryContainer
          : colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('focus-choice-${task.id}'),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: selected, onChanged: (_) => onToggle()),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (rowData.listName != null)
                            Text(
                              rowData.listName!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (rowData.dueLabel != null)
                            Text(
                              rowData.dueLabel!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          PriorityBadge(priority: task.priority),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
