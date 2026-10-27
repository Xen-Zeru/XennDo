import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/tasks/presentation/task_view_data.dart';
import 'package:xenndo/features/tasks/presentation/widgets/task_row.dart';
import 'package:xenndo/features/tasks/presentation/widgets/task_group.dart';

class TopThreeCard extends ConsumerStatefulWidget {
  const TopThreeCard({
    required this.tasks,
    required this.now,
    required this.onAdd,
    required this.onRemove,
    required this.onToggleCompleted,
    required this.onReorder,
    required this.onOpenTask,
    this.overdueTaskIds = const {},
    super.key,
  });

  final List<TaskItem> tasks;
  final DateTime now;
  final VoidCallback onAdd;
  final ValueChanged<TaskItem> onRemove;
  final void Function(TaskItem task, bool value) onToggleCompleted;
  final ValueChanged<List<TaskItem>> onReorder;
  final ValueChanged<TaskItem> onOpenTask;
  final Set<String> overdueTaskIds;

  @override
  ConsumerState<TopThreeCard> createState() => _TopThreeCardState();
}

class _TopThreeCardState extends ConsumerState<TopThreeCard> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tasks = widget.tasks;
    final progress = tasks.isEmpty
        ? null
        : ref.watch(subtaskProgressProvider).value;
    final activeCount = tasks.where((task) => !task.isCompleted).length;
    final slots = 3 - activeCount;

    return Semantics(
      label: '$activeCount of 3 active focus selections',
      child: TaskGroup(
        dividerIndent: 112,
        header: TaskSectionTitle(
          title: 'My Top 3',
          icon: Icons.track_changes_outlined,
          trailing: _editing
              ? TextButton(
                  key: const ValueKey('finish-focus-edit'),
                  onPressed: () => setState(() => _editing = false),
                  child: const Text('Done'),
                )
              : null,
        ),
        children: [
          if (tasks.isNotEmpty)
            ReorderableListView.builder(
              key: const ValueKey('top-three-reorderable'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) => Material(
                elevation: MediaQuery.disableAnimationsOf(context) ? 0 : 2,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: child,
              ),
              itemCount: tasks.length,
              onReorderItem: (oldIndex, newIndex) =>
                  _move(tasks, oldIndex, newIndex),
              itemBuilder: (context, index) {
                final task = tasks[index];
                final subtasks = progress?[task.id];
                return Column(
                  key: ValueKey('focus-task-${task.id}'),
                  children: [
                    TaskRow(
                      flat: true,
                      completionKey: ValueKey('focus-checkbox-$index'),
                      data: taskToRowData(
                        task,
                        context: context,
                        now: widget.now,
                        isOverdue: widget.overdueTaskIds.contains(task.id),
                        showTimeOnly:
                            !widget.overdueTaskIds.contains(task.id) &&
                            task.dueDate == LocalDate.fromDateTime(widget.now),
                        completedSubtasks: subtasks?.completed ?? 0,
                        totalSubtasks: subtasks?.total ?? 0,
                      ),
                      leading: _editing
                          ? ReorderableDragStartListener(
                              index: index,
                              child: Semantics(
                                label:
                                    'Drag to reorder ${task.title}; move actions also in task options',
                                child: const SizedBox(
                                  width: 48,
                                  height: 48,
                                  child: Icon(Icons.drag_handle_rounded),
                                ),
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.xs,
                              ),
                              child: SizedBox(
                                width: 32,
                                height: 48,
                                child: Center(
                                  child: CircleAvatar(
                                    radius: 16,
                                    backgroundColor: colors.primaryContainer,
                                    foregroundColor: colors.onPrimaryContainer,
                                    child: Text(
                                      '${index + 1}',
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            color: colors.onPrimaryContainer,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                      onCompletionChanged: (value) {
                        HapticFeedback.selectionClick();
                        widget.onToggleCompleted(task, value);
                      },
                      onTap: () => widget.onOpenTask(task),
                      trailing: PopupMenuButton<String>(
                        key: ValueKey('focus-menu-$index'),
                        tooltip: 'Focus task options',
                        iconSize: 18,
                        padding: EdgeInsets.zero,
                        onSelected: (action) {
                          switch (action) {
                            case 'reorder':
                              setState(() => _editing = true);
                            case 'edit':
                              widget.onOpenTask(task);
                            case 'up':
                              _move(tasks, index, index - 1);
                            case 'down':
                              _move(tasks, index, index + 1);
                            case 'remove':
                              widget.onRemove(task);
                          }
                        },
                        itemBuilder: (context) => [
                          if (!_editing)
                            const PopupMenuItem(
                              key: ValueKey('edit-focus'),
                              value: 'reorder',
                              child: Text('Reorder focus tasks'),
                            ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit task'),
                          ),
                          if (index > 0)
                            const PopupMenuItem(
                              key: ValueKey('focus-move-up'),
                              value: 'up',
                              child: Text('Move up'),
                            ),
                          if (index < tasks.length - 1)
                            const PopupMenuItem(
                              key: ValueKey('focus-move-down'),
                              value: 'down',
                              child: Text('Move down'),
                            ),
                          const PopupMenuItem(
                            key: ValueKey('focus-remove'),
                            value: 'remove',
                            child: Text('Remove from My Top 3'),
                          ),
                        ],
                      ),
                    ),
                    if (index < tasks.length - 1)
                      const Divider(height: 1, indent: 112, endIndent: 16),
                  ],
                );
              },
            ),
          if (slots > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('choose-focus-task'),
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Choose a focus task'),
              ),
            ),
        ],
      ),
    );
  }

  void _move(List<TaskItem> tasks, int from, int to) {
    if (to < 0 || to >= tasks.length || from == to) return;
    final reordered = [...tasks];
    reordered.insert(to, reordered.removeAt(from));
    HapticFeedback.selectionClick();
    widget.onReorder(reordered);
  }
}
