import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/core/time/task_timing.dart';
import 'package:xenndo/features/reminders/application/reminder_reconciler.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';
import 'package:xenndo/features/tasks/domain/task_draft.dart';

import '../support/test_database.dart';
import 'fake_reminder_scheduler.dart';

final _today = LocalDate(2026, 10, 19);
final _fixedNow = DateTime(2026, 10, 19, 12);

void main() {
  late AppDatabase database;
  late FakeReminderScheduler scheduler;
  late TaskRepository tasks;

  setUp(() async {
    database = await openInMemoryDatabase();
    scheduler = FakeReminderScheduler();
    tasks = TaskRepository(
      database,
      clock: () => _fixedNow,
      reminderScheduler: scheduler,
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<String> createFutureReminder({int hour = 15}) {
    return tasks.createTask(
      TaskDraft(
        title: 'Future reminder',
        reminderEnabled: true,
        reminderDate: _today,
        reminderTimeMinutes: hour * Duration.minutesPerHour,
      ),
    );
  }

  group('task reminder scheduling', () {
    test('schedules future reminders with a stable notification id', () async {
      final taskId = await createFutureReminder();
      final task = await tasks.getTask(taskId);

      expect(scheduler.scheduled, hasLength(1));
      final scheduled = scheduler.scheduled.single;
      expect(scheduled.taskId, taskId);
      expect(scheduled.notificationId, task!.notificationId);
      expect(
        scheduled.when,
        TaskTiming.resolveLocalReminderInstant(
          reminderDate: _today,
          reminderTimeMinutes: 15 * Duration.minutesPerHour,
        ),
      );
    });

    test('does not schedule a reminder whose time has passed', () async {
      await tasks.createTask(
        TaskDraft(
          title: 'Past reminder',
          reminderEnabled: true,
          reminderDate: _today,
          reminderTimeMinutes: 9 * Duration.minutesPerHour,
        ),
      );

      expect(scheduler.scheduled, isEmpty);
    });

    test('editing a reminder replaces the previous schedule', () async {
      final taskId = await createFutureReminder();
      final task = await tasks.getTask(taskId);
      scheduler.scheduled.clear();
      scheduler.cancelled.clear();

      await tasks.updateTask(
        taskId,
        TaskDraft(
          title: 'Future reminder',
          reminderEnabled: true,
          reminderDate: _today,
          reminderTimeMinutes: 16 * Duration.minutesPerHour,
        ),
      );

      expect(scheduler.cancelled, contains(task!.notificationId));
      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled.single.notificationId, task.notificationId);
    });

    test('completing a task cancels its reminder', () async {
      final taskId = await createFutureReminder();
      final task = await tasks.getTask(taskId);
      scheduler.scheduled.clear();
      scheduler.cancelled.clear();

      await tasks.setTaskCompleted(taskId, true);

      expect(scheduler.cancelled, contains(task!.notificationId));
      expect(scheduler.scheduled, isEmpty);
    });

    test('reopening a task schedules a future reminder again', () async {
      final taskId = await createFutureReminder();
      await tasks.setTaskCompleted(taskId, true);
      scheduler.scheduled.clear();

      await tasks.setTaskCompleted(taskId, false);

      expect(scheduler.scheduled, hasLength(1));
    });

    test('reopening does not schedule a reminder in the past', () async {
      final taskId = await createFutureReminder();
      await tasks.setTaskCompleted(taskId, true);
      scheduler.scheduled.clear();

      final laterTasks = TaskRepository(
        database,
        clock: () => DateTime(2026, 10, 20, 8),
        reminderScheduler: scheduler,
      );
      await laterTasks.setTaskCompleted(taskId, false);

      expect(scheduler.scheduled, isEmpty);
    });

    test('deleting a task cancels its reminder', () async {
      final taskId = await createFutureReminder();
      final task = await tasks.getTask(taskId);
      scheduler.scheduled.clear();
      scheduler.cancelled.clear();

      await tasks.deleteTask(taskId);

      expect(scheduler.cancelled, contains(task!.notificationId));
    });
  });

  group('reminder reconciliation', () {
    ReminderReconciler reconciler() => ReminderReconciler(
      tasks: tasks,
      scheduler: scheduler,
      clock: () => _fixedNow,
    );

    test(
      'cancels pending notifications that are not in the database',
      () async {
        scheduler.pending.add(999);

        await reconciler().reconcile();

        expect(scheduler.cancelled, contains(999));
      },
    );

    test('schedules database reminders that are still in the future', () async {
      await createFutureReminder();
      scheduler.scheduled.clear();
      scheduler.cancelled.clear();

      await reconciler().reconcile();

      expect(scheduler.scheduled, hasLength(1));
    });

    test('cancels database reminders whose time has passed', () async {
      final taskId = await tasks.createTask(
        TaskDraft(
          title: 'Past reminder',
          reminderEnabled: true,
          reminderDate: _today,
          reminderTimeMinutes: 9 * Duration.minutesPerHour,
        ),
      );
      final task = await tasks.getTask(taskId);
      scheduler.cancelled.clear();

      await reconciler().reconcile();

      expect(scheduler.cancelled, contains(task!.notificationId));
      expect(scheduler.scheduled, isEmpty);
    });

    test('local reminder instants are stored as UTC', () {
      final instant = TaskTiming.resolveLocalReminderInstant(
        reminderDate: _today,
        reminderTimeMinutes: 15 * Duration.minutesPerHour,
      );

      expect(instant.isUtc, isTrue);
      expect(instant.toLocal().hour, 15);
      expect(instant.toLocal().minute, 0);
    });
  });
}
