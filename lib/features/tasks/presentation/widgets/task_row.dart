import 'package:flutter/material.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';
import 'package:xenndo/features/tasks/presentation/task_row_data.dart';
import 'package:xenndo/features/tasks/presentation/widgets/priority_badge.dart';

class TaskRow extends StatelessWidget {
  const TaskRow({
    required this.data,
    super.key,
    this.onTap,
    this.onCompletionChanged,
    this.onEdit,
    this.onDelete,
    this.leading,
    this.trailing,
    this.completionKey,
    this.onMoveUp,
    this.onMoveDown,
    this.flat = false,
  });
  final TaskRowData data;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onCompletionChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Widget? leading;
  final Widget? trailing;
  final Key? completionKey;
  final bool flat;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final storedColor = data.listColor == null
        ? colors.primary
        : Color(data.listColor!);
    final listColor = theme.brightness == Brightness.dark
        ? Color.lerp(storedColor, Colors.white, .35)!
        : storedColor;
    final completion = Semantics(
      label: data.isCompleted
          ? 'Mark ${data.title} as not complete'
          : 'Mark ${data.title} as complete',
      child: SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: Transform.scale(
            scale: 1.2,
            child: Checkbox(
              key: completionKey,
              value: data.isCompleted,
              onChanged: onCompletionChanged == null
                  ? null
                  : (value) => onCompletionChanged!(value ?? false),
            ),
          ),
        ),
      ),
    );
    final actions = trailing ?? _taskMenu();
    Widget content({bool inlineTime = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data.title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w400,
            color: data.isCompleted
                ? colors.onSurfaceVariant
                : colors.onSurface,
            decoration: data.isCompleted ? TextDecoration.lineThrough : null,
            decorationColor: colors.onSurfaceVariant,
          ),
        ),
        if (_hasMetadata || (inlineTime && data.timeLabel != null)) ...[
          const SizedBox(height: 3),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (inlineTime && data.timeLabel != null)
                _TaskMeta(label: data.timeLabel!),
              if (data.dueLabel != null)
                _TaskMeta(
                  label: data.isOverdue
                      ? 'Overdue · ${data.dueLabel}'
                      : data.dueLabel!,
                  color: data.isOverdue ? colors.error : null,
                ),
              if (data.listName != null)
                _TaskMeta(label: data.listName!, dotColor: listColor),
              if (data.totalSubtasks > 0)
                _TaskMeta(
                  label:
                      '${data.completedSubtasks} of ${data.totalSubtasks} subtasks',
                  icon: Icons.checklist_rounded,
                ),
              if (data.priority != TaskPriority.medium)
                PriorityBadge(priority: data.priority),
            ],
          ),
        ],
      ],
    );

    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: flat ? BorderSide.none : BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(leading == null ? 8 : 12, 4, 4, 4),
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 340 &&
                  MediaQuery.textScalerOf(context).scale(16) > 22) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        ?leading,
                        completion,
                        const Spacer(),
                        ?actions,
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 4, 8, 12),
                      child: content(inlineTime: true),
                    ),
                  ],
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(
                  children: [
                    ?leading,
                    if (leading != null) const SizedBox(width: 4),
                    completion,
                    SizedBox(width: data.timeLabel == null ? 12 : 4),
                    if (data.timeLabel != null) ...[
                      SizedBox(
                        width: 72,
                        child: Text(
                          data.timeLabel!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: content(),
                      ),
                    ),
                    ?actions,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget? _taskMenu() {
    if (onEdit == null && onDelete == null) return null;
    return PopupMenuButton<String>(
      tooltip: 'Task options',
      iconSize: 18,
      padding: EdgeInsets.zero,
      onSelected: (action) {
        if (action == 'up') {
          onMoveUp?.call();
        } else if (action == 'down') {
          onMoveDown?.call();
        } else if (action == 'edit') {
          onEdit?.call();
        } else if (action == 'delete') {
          onDelete?.call();
        }
      },
      itemBuilder: (context) => [
        if (onMoveUp != null)
          const PopupMenuItem(value: 'up', child: Text('Move up')),
        if (onMoveDown != null)
          const PopupMenuItem(value: 'down', child: Text('Move down')),
        if (onEdit != null)
          const PopupMenuItem(value: 'edit', child: Text('Edit task')),
        if (onDelete != null)
          const PopupMenuItem(value: 'delete', child: Text('Delete task')),
      ],
    );
  }

  bool get _hasMetadata =>
      data.dueLabel != null ||
      data.listName != null ||
      data.totalSubtasks > 0 ||
      (data.priority != TaskPriority.none &&
          data.priority != TaskPriority.medium);
}

class _TaskMeta extends StatelessWidget {
  const _TaskMeta({required this.label, this.color, this.dotColor, this.icon});
  final String label;
  final Color? color;
  final Color? dotColor;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveColor = color ?? theme.colorScheme.onSurfaceVariant;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dotColor != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
        ] else if (icon != null) ...[
          Icon(icon, size: 14, color: effectiveColor),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(color: effectiveColor),
          ),
        ),
      ],
    );
  }
}
