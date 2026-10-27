import 'package:xenndo/core/time/local_date.dart';

/// Completion totals for one local calendar day.
class DayCompletionCount {
  const DayCompletionCount({required this.day, required this.count});

  final LocalDate day;
  final int count;
}

/// Completion state of the tasks due on a single local calendar day.
///
/// A day with no due tasks is a real state, not a zero percent score: read
/// [hasTasks] before showing a percentage.
class DueDayProgress {
  const DueDayProgress({required this.total, required this.completed});

  final int total;
  final int completed;

  bool get hasTasks => total > 0;

  int get open => total - completed;

  /// Fraction of due tasks completed, or 0 when nothing is due.
  double get fraction => total == 0 ? 0 : completed / total;

  /// Rounded percentage for display, or 0 when nothing is due.
  int get percent => total == 0 ? 0 : ((completed / total) * 100).round();
}

/// Pure calculations behind the Progress screen.
///
/// Counts are derived from stored completion timestamps, never from a mutable
/// counter, so they always match the task rows.
abstract final class ProgressSummary {
  /// The [count] local days ending with [today], oldest day first.
  static List<LocalDate> lastDays(LocalDate today, int count) {
    if (count <= 0) {
      return const [];
    }
    return [
      for (var offset = count - 1; offset >= 0; offset--)
        today.addDays(-offset),
    ];
  }

  /// Groups completion timestamps into the given local days.
  ///
  /// Timestamps outside [days] are ignored, so callers can pass a fixed window
  /// such as the last seven days.
  static List<DayCompletionCount> completionsByDay({
    required List<DateTime> completedAtUtc,
    required List<LocalDate> days,
  }) {
    final counts = <LocalDate, int>{for (final day in days) day: 0};
    for (final completedAt in completedAtUtc) {
      final day = LocalDate.fromDateTime(completedAt.toLocal());
      final current = counts[day];
      if (current != null) {
        counts[day] = current + 1;
      }
    }
    return [
      for (final day in days)
        DayCompletionCount(day: day, count: counts[day] ?? 0),
    ];
  }

  static DueDayProgress dueProgress({
    required int total,
    required int completed,
  }) {
    final safeCompleted = completed.clamp(0, total);
    return DueDayProgress(total: total, completed: safeCompleted);
  }
}
