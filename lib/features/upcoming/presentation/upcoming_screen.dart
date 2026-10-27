import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/core/widgets/app_empty_state.dart';
import 'package:xenndo/core/widgets/app_error_state.dart';
import 'package:xenndo/core/widgets/app_loading_state.dart';
import 'package:xenndo/core/widgets/page_heading.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/tasks/presentation/widgets/persisted_task_row.dart';
import 'package:xenndo/features/tasks/presentation/widgets/task_group.dart';

class UpcomingScreen extends ConsumerStatefulWidget {
  const UpcomingScreen({super.key});

  @override
  ConsumerState<UpcomingScreen> createState() => _UpcomingScreenState();
}

class _UpcomingScreenState extends ConsumerState<UpcomingScreen> {
  final _scrollController = ScrollController();
  final _groupKeys = <LocalDate, GlobalKey>{};
  LocalDate? _selectedDate;
  bool _dateWasSelected = false;
  LocalDate? _stripStart;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(nowProvider)();
    final upcoming = ref.watch(upcomingTasksProvider);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const ValueKey('upcoming-screen'),
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: PageHeading(
              title: 'Upcoming',
              bottomPadding: 6,
              actions: [
                IconButton(
                  key: const ValueKey('search-action'),
                  tooltip: 'Search tasks',
                  onPressed: () => context.pushNamed('search'),
                  icon: const Icon(Icons.search_rounded, size: 22),
                ),
                IconButton(
                  key: const ValueKey('upcoming-date-picker'),
                  tooltip: 'Choose a date',
                  onPressed: () => _pickDate(
                    context,
                    _groupTasks(upcoming.value ?? const []),
                    now,
                  ),
                  icon: const Icon(Icons.calendar_month_outlined, size: 22),
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
            sliver: upcoming.when(
              data: (tasks) => _buildUpcoming(context, tasks, now),
              loading: () => const SliverToBoxAdapter(child: AppLoadingState()),
              error: (error, stackTrace) => SliverToBoxAdapter(
                child: AppErrorState(
                  title: 'Could not load upcoming tasks',
                  message: 'Your tasks could not be read from the database.',
                  onRetry: () => ref.invalidate(upcomingTasksProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcoming(
    BuildContext context,
    List<TaskItem> tasks,
    DateTime now,
  ) {
    final groups = _groupTasks(tasks);
    _groupKeys.removeWhere((date, _) => !groups.containsKey(date));
    for (final date in groups.keys) {
      _groupKeys.putIfAbsent(date, GlobalKey.new);
    }
    final tomorrow = LocalDate.fromDateTime(now).addDays(1);
    _stripStart ??= tomorrow.addDays(1 - tomorrow.toLocalDateTime().weekday);
    _selectedDate ??= LocalDate.fromDateTime(now).isBefore(_stripStart!)
        ? tomorrow
        : LocalDate.fromDateTime(now);

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            children: [
              _buildDateStrip(context, groups),
              if (_dateWasSelected && !groups.containsKey(_selectedDate))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'No upcoming tasks on ${MaterialLocalizations.of(context).formatMediumDate(_selectedDate!.toLocalDateTime())}.',
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
        if (tasks.isEmpty)
          const SliverToBoxAdapter(
            child: AppEmptyState(
              icon: Icons.event_available_outlined,
              title: 'No upcoming tasks',
              message: 'Tasks with a future due date will appear here so you can plan ahead.',
            ),
          ),
        for (final entry in groups.entries) ...[
          SliverToBoxAdapter(
            child: Padding(
              key: _groupKeys[entry.key],
              padding: const EdgeInsets.only(bottom: 8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final label = Text(
                    _groupLabel(context, entry.key, now),
                    style: Theme.of(context).textTheme.titleMedium,
                  );
                  final date = Text(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(entry.key.toLocalDateTime()),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  );
                  return MediaQuery.textScalerOf(context).scale(14) > 20
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [label, date],
                        )
                      : Row(
                          children: [
                            Expanded(child: label),
                            date,
                          ],
                        );
                },
              ),
            ),
          ),
          SliverTaskGroup(
            itemCount: entry.value.length,
            itemBuilder: (context, index) => PersistedTaskRow(
              task: entry.value[index],
              now: now,
              showTimeOnly: true,
              timeColumn: true,
              showDateOnlyLabel: true,
              flat: true,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ],
    );
  }

  Map<LocalDate, List<TaskItem>> _groupTasks(List<TaskItem> tasks) {
    final groups = <LocalDate, List<TaskItem>>{};
    for (final task in tasks) {
      if (task.dueDate != null) {
        groups.putIfAbsent(task.dueDate!, () => []).add(task);
      }
    }
    return groups;
  }

  Widget _buildDateStrip(
    BuildContext context,
    Map<LocalDate, List<TaskItem>> groups,
  ) {
    final startDate = _stripStart!;
    final colors = Theme.of(context).colorScheme;
    final localizations = MaterialLocalizations.of(context);
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 2.0);
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SizedBox(
      height: 92 * scale,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dayWidth = (constraints.maxWidth / 7).clamp(
            48 * scale,
            double.infinity,
          );
          return SingleChildScrollView(
            key: const ValueKey('upcoming-date-strip'),
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(7, (index) {
                final date = startDate.addDays(index);
                final selected = date == _selectedDate;
                final count = groups[date]?.length ?? 0;
                return Semantics(
                  button: true,
                  selected: selected,
                  label:
                      '${localizations.formatFullDate(date.toLocalDateTime())}, $count upcoming tasks',
                  child: SizedBox(
                    width: dayWidth,
                    child: InkWell(
                      key: ValueKey('upcoming-date-${date.toIso8601String()}'),
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _selectDate(date, groups),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            weekdays[date.toLocalDateTime().weekday - 1],
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: selected
                                      ? colors.primary
                                      : colors.onSurfaceVariant,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 44 * scale,
                            height: 44 * scale,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? colors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${date.day}',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: selected
                                        ? colors.onPrimary
                                        : colors.onSurface,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: count > 0
                                  ? colors.primary
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  void _selectDate(LocalDate date, Map<LocalDate, List<TaskItem>> groups) {
    setState(() {
      _selectedDate = date;
      _dateWasSelected = true;
    });
    if (!groups.containsKey(date)) {
      return;
    }
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      for (var attempt = 0; attempt < 3; attempt++) {
        if (!mounted) return;
        final target = _groupKeys[date]?.currentContext;
        if (target == null || !target.mounted) return;
        await Scrollable.ensureVisible(
          target,
          duration: disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: .05,
        );
        await WidgetsBinding.instance.endOfFrame;
      }
    });
  }

  Future<void> _pickDate(
    BuildContext context,
    Map<LocalDate, List<TaskItem>> groups,
    DateTime now,
  ) async {
    final today = LocalDate.fromDateTime(now);
    final firstDate = today.addDays(1).toLocalDateTime();
    final selectedDate = _selectedDate;
    final lastDate =
        groups.keys.isNotEmpty &&
            groups.keys.last.toLocalDateTime().isAfter(DateTime(now.year + 10))
        ? groups.keys.last.toLocalDateTime()
        : DateTime(now.year + 10);
    final candidate = selectedDate != null && selectedDate.isAfter(today)
        ? selectedDate.toLocalDateTime()
        : groups.keys.firstOrNull?.toLocalDateTime() ?? firstDate;
    final initialDate = candidate.isBefore(firstDate)
        ? firstDate
        : candidate.isAfter(lastDate)
        ? lastDate
        : candidate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Choose an upcoming date',
    );
    if (picked == null || !context.mounted) {
      return;
    }
    final date = LocalDate.fromDateTime(picked);
    setState(() => _stripStart = date);
    _selectDate(date, groups);
  }

  String _groupLabel(BuildContext context, LocalDate date, DateTime now) {
    final today = LocalDate.fromDateTime(now);
    if (date == today.addDays(1)) {
      return 'Tomorrow';
    }
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return weekdays[date.toLocalDateTime().weekday - 1];
  }
}
