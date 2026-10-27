import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/core/time/current_date_provider.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/core/widgets/app_empty_state.dart';
import 'package:xenndo/core/widgets/app_error_state.dart';
import 'package:xenndo/core/widgets/app_loading_state.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/tasks/presentation/widgets/persisted_task_row.dart';

final _historyProvider = StreamProvider.autoDispose
    .family<List<TaskItem>, LocalDate>((ref, end) {
      return ref
          .watch(taskRepositoryProvider)
          .watchCompletedBetween(
            firstDay: end.addDays(-6),
            lastDayExclusive: end.addDays(1),
          );
    });

/// Recent completions, with a calendar alternative for earlier local days.
class CompletionHistoryScreen extends ConsumerStatefulWidget {
  const CompletionHistoryScreen({super.key});
  @override
  ConsumerState<CompletionHistoryScreen> createState() =>
      _CompletionHistoryState();
}

class _CompletionHistoryState extends ConsumerState<CompletionHistoryScreen> {
  LocalDate? _end;
  @override
  Widget build(BuildContext context) {
    final today = ref.watch(currentDateProvider);
    final end = _end ?? today;
    final history = ref.watch(_historyProvider(end));
    final labels = MaterialLocalizations.of(context);
    final now = ref.watch(nowProvider)();
    return Scaffold(
      key: const ValueKey('completion-history-screen'),
      appBar: AppBar(
        title: const Text('Completion history'),
        actions: [
          IconButton(
            tooltip: 'Choose history end date',
            icon: const Icon(Icons.date_range_outlined),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: end.toLocalDateTime(),
                firstDate: DateTime(1900),
                lastDate: today.toLocalDateTime(),
              );
              if (picked != null && mounted) {
                setState(() => _end = LocalDate.fromDateTime(picked));
              }
            },
          ),
        ],
      ),
      body: history.when(
        loading: () => const AppLoadingState(),
        error: (_, _) => AppErrorState(
          title: 'Could not load history',
          message: 'Try reading your completed tasks again.',
          onRetry: () => ref.invalidate(_historyProvider(end)),
        ),
        data: (tasks) {
          final rows = <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                '${labels.formatMediumDate(end.addDays(-6).toLocalDateTime())} – ${labels.formatMediumDate(end.toLocalDateTime())}',
              ),
            ),
          ];
          LocalDate? previous;
          for (final task in tasks) {
            final day = LocalDate.fromDateTime(task.completedAt!.toLocal());
            if (day != previous) {
              rows.add(
                Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  child: Semantics(
                    header: true,
                    child: Text(
                      labels.formatFullDate(day.toLocalDateTime()),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
              );
              previous = day;
            }
            rows.add(
              PersistedTaskRow(
                key: ValueKey('history-${task.id}'),
                task: task,
                now: now,
              ),
            );
          }
          if (tasks.isEmpty) {
            rows.add(
              const AppEmptyState(
                icon: Icons.history_outlined,
                title: 'No completed tasks',
                message: 'Choose another date or complete a task.',
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            itemCount: rows.length,
            itemBuilder: (_, index) => rows[index],
          );
        },
      ),
    );
  }
}
