import 'package:xenndo/core/time/local_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/core/widgets/app_empty_state.dart';
import 'package:xenndo/core/widgets/app_error_state.dart';
import 'package:xenndo/core/widgets/app_loading_state.dart';
import 'package:xenndo/features/lists/application/list_providers.dart';
import 'package:xenndo/features/search/application/search_providers.dart';
import 'package:xenndo/features/tasks/domain/task_filter.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';
import 'package:xenndo/features/tasks/presentation/widgets/persisted_task_row.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(
      text: ref.read(taskFilterProvider).query,
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final now = ref.watch(nowProvider)();
    final filter = ref.watch(taskFilterProvider);
    final lists = ref.watch(listsProvider).value ?? const [];
    final results = ref.watch(filteredTasksProvider);

    return Scaffold(
      key: const ValueKey('search-screen'),
      appBar: AppBar(title: const Text('Search')),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.lg,
                AppSpacing.pageHorizontal,
                AppSpacing.xxxl,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    TextField(
                      key: const ValueKey('search-query-field'),
                      controller: _queryController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search titles and descriptions',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _queryController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _queryController.clear();
                                  ref
                                      .read(taskFilterProvider.notifier)
                                      .setQuery('');
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                      onChanged: (value) {
                        ref.read(taskFilterProvider.notifier).setQuery(value);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _FilterSection(
                      title: 'List',
                      children: [
                        ChoiceChip(
                          key: const ValueKey('filter-list-all'),
                          label: const Text('All lists'),
                          selected: filter.listId == null,
                          onSelected: (_) => ref
                              .read(taskFilterProvider.notifier)
                              .setList(null),
                        ),
                        for (final list in lists)
                          ChoiceChip(
                            key: ValueKey('filter-list-${list.id}'),
                            label: Text(list.name),
                            selected: filter.listId == list.id,
                            onSelected: (_) => ref
                                .read(taskFilterProvider.notifier)
                                .setList(list.id),
                          ),
                      ],
                    ),
                    _FilterSection(
                      title: 'Priority',
                      children: [
                        ChoiceChip(
                          key: const ValueKey('filter-priority-all'),
                          label: const Text('Any'),
                          selected: filter.priority == null,
                          onSelected: (_) => ref
                              .read(taskFilterProvider.notifier)
                              .setPriority(null),
                        ),
                        for (final priority in TaskPriority.selectable)
                          ChoiceChip(
                            key: ValueKey('filter-priority-${priority.name}'),
                            label: Text(priority.label),
                            selected: filter.priority == priority,
                            onSelected: (_) => ref
                                .read(taskFilterProvider.notifier)
                                .setPriority(priority),
                          ),
                      ],
                    ),
                    _FilterSection(
                      title: 'Status',
                      children: [
                        for (final completion in TaskCompletionFilter.values)
                          ChoiceChip(
                            key: ValueKey(
                              'filter-completion-${completion.name}',
                            ),
                            label: Text(completion.label),
                            selected: filter.completion == completion,
                            onSelected: (_) => ref
                                .read(taskFilterProvider.notifier)
                                .setCompletion(completion),
                          ),
                      ],
                    ),
                    _FilterSection(
                      title: 'Due date',
                      children: [
                        ActionChip(
                          key: const ValueKey('filter-date-range'),
                          avatar: const Icon(Icons.date_range_outlined),
                          label: Text(
                            filter.dueFrom == null
                                ? 'Any date'
                                : '${MaterialLocalizations.of(context).formatCompactDate(filter.dueFrom!.toLocalDateTime())} – ${MaterialLocalizations.of(context).formatCompactDate(filter.dueThrough!.toLocalDateTime())}',
                          ),
                          onPressed: () async {
                            FocusScope.of(context).unfocus();
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2200),
                              initialDateRange: filter.dueFrom == null
                                  ? null
                                  : DateTimeRange(
                                      start: filter.dueFrom!.toLocalDateTime(),
                                      end: filter.dueThrough!.toLocalDateTime(),
                                    ),
                            );
                            if (picked != null && mounted) {
                              ref
                                  .read(taskFilterProvider.notifier)
                                  .setDateRange(
                                    LocalDate.fromDateTime(picked.start),
                                    LocalDate.fromDateTime(picked.end),
                                  );
                            }
                          },
                        ),
                        if (filter.dueFrom != null)
                          ActionChip(
                            label: const Text('Clear dates'),
                            onPressed: () => ref
                                .read(taskFilterProvider.notifier)
                                .setDateRange(null, null),
                          ),
                      ],
                    ),
                    if (filter.isActive) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('search-clear-filters'),
                          onPressed: () {
                            _queryController.clear();
                            ref.read(taskFilterProvider.notifier).clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('Clear all filters'),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: results.when(
                loading: () => const SliverToBoxAdapter(
                  child: AppLoadingState(message: 'Searching...'),
                ),
                error: (error, stackTrace) => SliverToBoxAdapter(
                  child: AppErrorState(
                    title: 'Could not search tasks',
                    message: 'Tasks could not be read from the database.',
                    onRetry: () => ref.invalidate(filteredTasksProvider),
                  ),
                ),
                data: (tasks) {
                  if (tasks.isEmpty) {
                    if (!filter.isActive) {
                      return const SliverToBoxAdapter(
                        child: AppEmptyState(
                          icon: Icons.search_rounded,
                          title: 'No tasks yet',
                          message: 'Add a task and it will show up here.',
                        ),
                      );
                    }
                    return SliverToBoxAdapter(
                      child: AppEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No matching tasks',
                        message:
                            'Try a different search or clear your filters.',
                        actionLabel: 'Clear filters',
                        onAction: () {
                          _queryController.clear();
                          ref.read(taskFilterProvider.notifier).clear();
                          setState(() {});
                        },
                      ),
                    );
                  }

                  return SliverMainAxisGroup(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            tasks.length == 1
                                ? '1 matching task'
                                : '${tasks.length} matching tasks',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      SliverList.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: PersistedTaskRow(task: tasks[index], now: now),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: children,
          ),
        ],
      ),
    );
  }
}
