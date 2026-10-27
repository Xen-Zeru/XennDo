import 'package:flutter/material.dart';
import 'package:xenndo/core/theme/app_spacing.dart';

/// One quiet card, an optional in-card heading, and inset row dividers.
class TaskGroup extends StatelessWidget {
  const TaskGroup({
    required this.children,
    this.header,
    this.dividerIndent = 64,
    super.key,
  });
  final List<Widget> children;
  final Widget? header;
  final double dividerIndent;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ?header,
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0)
            Divider(height: 1, indent: dividerIndent, endIndent: 16),
          children[index],
        ],
        if (header != null) const SizedBox(height: 8),
      ],
    ),
  );
}

class TaskSectionTitle extends StatelessWidget {
  const TaskSectionTitle({
    required this.title,
    required this.icon,
    this.trailing,
    this.color,
    super.key,
  });
  final String title;
  final IconData icon;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 8, 8, 0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Icon(icon, color: color ?? theme.colorScheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.titleMedium),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// The same grouped surface with lazily built rows for long task collections.
class SliverTaskGroup extends StatelessWidget {
  const SliverTaskGroup({
    required this.itemCount,
    required this.itemBuilder,
    this.header,
    super.key,
  });
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? header;

  @override
  Widget build(BuildContext context) => DecoratedSliver(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.md),
      border: Border.all(
        color: Theme.of(context).colorScheme.outlineVariant,
        width: .5,
      ),
    ),
    sliver: SliverMainAxisGroup(
      slivers: [
        if (header != null) SliverToBoxAdapter(child: header),
        SliverList.builder(
          itemCount: itemCount,
          itemBuilder: (context, index) => Column(
            children: [
              if (index > 0)
                const Divider(height: 1, indent: 64, endIndent: 16),
              itemBuilder(context, index),
            ],
          ),
        ),
        if (header != null)
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    ),
  );
}
