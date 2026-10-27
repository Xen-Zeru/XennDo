import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';

/// Reconciles pending notifications with the database.
///
/// Reminders keep their local wall-clock time, so this re-derives the absolute
/// instant from stored local fields and reschedules. Pending notifications that
/// no longer match a task are cancelled.
class ReminderReconciler {
  ReminderReconciler({
    required this.tasks,
    required this.scheduler,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final TaskRepository tasks;
  final ReminderScheduler scheduler;
  final DateTime Function() _clock;

  Future<void> reconcile() => tasks.synchronizeReminders(_reconcile);

  Future<void> _reconcile() async {
    final reminders = await tasks.getSchedulableReminders();
    final knownIds = <int>{};
    final now = _clock();

    Object? firstFailure;
    final permission = await scheduler.checkPermission();
    for (final task in reminders) {
      final notificationId = task.notificationId;
      if (notificationId == null) {
        continue;
      }
      knownIds.add(notificationId);

      try {
        await scheduler.cancel(notificationId);
        if (task.isCompleted ||
            permission != ReminderPermissionStatus.granted) {
          continue;
        }
        final when = tasks.reminderInstantFor(task);
        if (when == null || !when.isAfter(now)) {
          continue;
        }
        await scheduler.schedule(
          notificationId: notificationId,
          taskId: task.id,
          title: task.title,
          body: task.description,
          when: when,
        );
      } catch (error) {
        firstFailure ??= error;
      }
    }

    final pending = await scheduler.pendingNotificationIds();
    for (final id in pending.difference(knownIds)) {
      try {
        await scheduler.cancel(id);
      } catch (error) {
        firstFailure ??= error;
      }
    }
    if (firstFailure != null) {
      throw StateError('One or more reminders could not be refreshed.');
    }
  }
}
