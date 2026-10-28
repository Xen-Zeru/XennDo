import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';
import 'package:xenndo/features/tasks/domain/task_draft.dart';

import 'reminders/fake_reminder_scheduler.dart';
import 'support/test_database.dart';

class _FullIosQueue extends FakeReminderScheduler {
  @override
  Future<void> schedule({
    required int notificationId,
    required String taskId,
    required String title,
    String? body,
    required DateTime when,
  }) async {
    throw const ReminderCapacityException();
  }
}

void main() {
  test('iOS capacity refusal preserves task content and reports unscheduled reminder', () async {
    final database = await openInMemoryDatabase();
    addTearDown(database.close);
    final messages = <String>[];
    final tasks = TaskRepository(
      database,
      clock: () => DateTime(2026, 10, 28, 10),
      reminderScheduler: _FullIosQueue(),
      onNotice: messages.add,
    );
    final id = await tasks.createTask(
      TaskDraft(
        title: 'Keep this task',
        description: 'Keep its notes',
        reminderEnabled: true,
        reminderDate: LocalDate(2026, 10, 29),
        reminderTimeMinutes: 600,
      ),
    );
    final stored = await tasks.getTask(id);
    expect(stored?.title, 'Keep this task');
    expect(stored?.description, 'Keep its notes');
    expect(stored?.notificationId, isNotNull);
    expect(messages, hasLength(1));
    expect(messages.single, contains('64 pending reminders'));
    expect(messages.single, contains('not scheduled'));
  });
}
