import 'package:flutter/material.dart';
import 'package:xenndo/core/theme/app_spacing.dart';

/// Shared first-screen geometry, matching the reference's large, left heading.
class PageHeading extends StatelessWidget {
  const PageHeading({
    required this.title,
    this.eyebrow,
    this.actions = const [],
    this.bottomPadding = 18,
    super.key,
  });

  final String title;
  final String? eyebrow;
  final List<Widget> actions;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageHorizontal,
        44,
        AppSpacing.pageHorizontal,
        bottomPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            Text(
              eyebrow!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
          ],
          LayoutBuilder(
            builder: (context, constraints) {
              final heading = Semantics(
                header: true,
                child: Text(title, style: theme.textTheme.headlineMedium),
              );
              if (actions.isNotEmpty &&
                  MediaQuery.textScalerOf(context).scale(32) > 42) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    Wrap(spacing: 4, children: actions),
                  ],
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Expanded(child: heading),
                    ...actions,
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
