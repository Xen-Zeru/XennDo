import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/core/widgets/app_empty_state.dart';
import 'package:xenndo/core/widgets/app_error_state.dart';
import 'package:xenndo/core/widgets/app_loading_state.dart';
import 'package:xenndo/core/widgets/section_header.dart';
import 'package:xenndo/features/lists/application/list_providers.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/tasks/presentation/widgets/persisted_task_row.dart';

class ListDetailScreen extends ConsumerWidget {
  const ListDetailScreen({required this.listId, super.key});

  final String listId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(nowProvider)();
    final lists = ref.watch(listsProvider).value ?? const [];
    final matchingLists = lists.where((item) => item.id == listId);
    final list = matchingLists.isEmpty ? null : matchingLists.first;
    final tasks = ref.watch(tasksForListProvider(listId));

    return Scaffold(
      key: const ValueKey('list-detail-screen'),
      appBar: AppBar(
        title: Text(list?.name ?? 'List'),
        actions: [
          IconButton(
            key: const ValueKey('list-add-task-action'),
            tooltip: 'Add task to this list',
            onPressed: () => context.pushNamed(
              'newTask',
              queryParameters: {'listId': listId},
            ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: tasks.when(
        loading: () => const AppLoadingState(message: 'Loading tasks...'),
        error: (error, stackTrace) => AppErrorState(
          title: 'Could not load tasks',
          message: 'Tasks for this list could not be read from the database.',
          onRetry: () => ref.invalidate(tasksForListProvider(listId)),
        ),
        data: (value) => _ListTasks(tasks: value, listId: listId, now: now),
      ),
    );
  }
}

class _ListTasks extends ConsumerWidget {
  const _ListTasks({
    required this.tasks,
    required this.listId,
    required this.now,
  });

  final List<TaskItem> tasks;
  final String listId;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tasks.isEmpty) {
      return AppEmptyState(
        icon: Icons.playlist_add_check_circle_outlined,
        title: 'No tasks here yet',
        message: 'Add a task to this list to start planning.',
        actionLabel: 'Add task',
        onAction: () =>
            context.pushNamed('newTask', queryParameters: {'listId': listId}),
      );
    }

    final openTasks = tasks.where((task) => !task.isCompleted).toList();
    final completedTasks = tasks.where((task) => task.isCompleted).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        AppSpacing.lg,
        AppSpacing.pageHorizontal,
        AppSpacing.pageBottom,
      ),
      children: [
        if (openTasks.isNotEmpty) ...[
          SectionHeader(
            title: 'Open',
            supportingText: openTasks.length == 1
                ? '1 task'
                : '${openTasks.length} tasks',
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final (index, task) in openTasks.indexed) ...[
            PersistedTaskRow(
              task: task,
              now: now,
              onMoveUp: index == 0
                  ? null
                  : () => _move(context, ref, openTasks, index, index - 1),
              onMoveDown: index == openTasks.length - 1
                  ? null
                  : () => _move(context, ref, openTasks, index, index + 1),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
        if (completedTasks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          SectionHeader(
            title: 'Completed',
            supportingText: 'Tap the checkbox to reopen',
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final task in completedTasks) ...[
            _EditableTaskRow(task: task, now: now),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
    );
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    List<TaskItem> tasks,
    int from,
    int to,
  ) async {
    final ids = tasks.map((task) => task.id).toList();
    ids.insert(to, ids.removeAt(from));
    try {
      await ref.read(taskRepositoryProvider).reorderTasks(listId, ids);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not reorder tasks.')),
        );
      }
    }
  }
}

class _EditableTaskRow extends StatelessWidget {
  const _EditableTaskRow({required this.task, required this.now});

  final TaskItem task;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return PersistedTaskRow(
      task: task,
      now: now,
      onTap: () =>
          context.pushNamed('editTask', pathParameters: {'taskId': task.id}),
    );
  }
}
