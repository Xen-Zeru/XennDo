import 'package:flutter/material.dart';
import 'package:xenndo/core/theme/app_colors.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({required this.priority, super.key});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    if (priority == TaskPriority.none) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final color = switch (priority) {
      TaskPriority.none => theme.colorScheme.outline,
      TaskPriority.low => context.appColors.priorityLow,
      TaskPriority.medium => context.appColors.priorityMedium,
      TaskPriority.high => context.appColors.priorityHigh,
    };

    return Semantics(
      label: '${priority.label} priority',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                priority.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
