import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/tasks/domain/reminder_offset.dart';

abstract final class TaskTiming {
  /// Returns whether an incomplete task is overdue at [now].
  ///
  /// Date-only deadlines become overdue when the local calendar day advances.
  /// Timed deadlines become overdue after their local wall-clock time on the
  /// selected date.
  static bool isOverdue({
    required LocalDate dueDate,
    required int? dueTimeMinutes,
    required DateTime now,
  }) {
    final today = LocalDate.fromDateTime(now);
    if (dueDate.isBefore(today)) {
      return true;
    }
    if (dueDate.isAfter(today) || dueTimeMinutes == null) {
      return false;
    }

    final due = resolveLocalDateTime(
      dueDate: dueDate,
      dueTimeMinutes: dueTimeMinutes,
    );
    return now.isAfter(due);
  }

  /// Resolves a timed deadline to a local [DateTime] in the device's current
  /// time zone. Date-only deadlines should use [LocalDate] directly.
  static DateTime resolveLocalDateTime({
    required LocalDate dueDate,
    required int dueTimeMinutes,
  }) {
    if (dueTimeMinutes < 0 || dueTimeMinutes >= Duration.minutesPerDay) {
      throw ArgumentError.value(
        dueTimeMinutes,
        'dueTimeMinutes',
        'Must be between 0 and 1439',
      );
    }

    return dueDate.toLocalDateTime(
      hour: dueTimeMinutes ~/ Duration.minutesPerHour,
      minute: dueTimeMinutes % Duration.minutesPerHour,
    );
  }

  /// Computes the absolute UTC instant for an explicit local reminder
  /// date and time chosen by the user.
  ///
  /// The reminder keeps its local wall-clock time. On a time-zone change the
  /// stored local fields are rescheduled so the reminder fires at the same
  /// local time in the new zone.
  static DateTime resolveLocalReminderInstant({
    required LocalDate reminderDate,
    required int reminderTimeMinutes,
  }) {
    return resolveLocalDateTime(
      dueDate: reminderDate,
      dueTimeMinutes: reminderTimeMinutes,
    ).toUtc();
  }

  /// Computes the absolute UTC instant for a local reminder.
  ///
  /// The returned instant is stable afterward. If the device time zone changes,
  /// the stored reminder keeps its original absolute time; Phase 6 should
  /// reconcile or reschedule pending notifications when that behavior matters.
  static DateTime resolveReminderInstant({
    required LocalDate dueDate,
    required int dueTimeMinutes,
    required ReminderOffset offset,
  }) {
    return resolveLocalDateTime(
      dueDate: dueDate,
      dueTimeMinutes: dueTimeMinutes,
    ).subtract(offset.duration).toUtc();
  }
}
