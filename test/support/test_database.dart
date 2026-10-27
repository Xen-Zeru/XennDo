import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/core/time/local_date.dart';

Future<AppDatabase> openInMemoryDatabase() async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final database = AppDatabase(NativeDatabase.memory());
  await database.select(database.taskLists).get();
  return database;
}

/// The instant every fixture timestamp is written with.
final DateTime fixtureNow = DateTime.utc(2026, 10, 19, 12);

/// A small data set that touches every table a backup carries: two lists (the
/// seeded Inbox plus Work), open and completed tasks, reminder metadata with
/// notification ids, subtasks, Top 3 selections, and a stored preference.
Future<void> seedBackupFixture(AppDatabase database) async {
  final now = fixtureNow;

  await database
      .into(database.taskLists)
      .insert(
        TaskListsCompanion.insert(
          id: 'work',
          name: 'Work',
          color: 0xFF6750A4,
          icon: const Value('work'),
          sortOrder: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );

  await database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          id: 'task-open',
          title: 'Write the plan',
          description: const Value('Outline the phases'),
          listId: const Value('work'),
          priority: const Value(3),
          dueDate: Value(LocalDate(2026, 10, 20)),
          dueTimeMinutes: const Value(540),
          createdAt: now,
          updatedAt: now,
          reminderDate: Value(LocalDate(2026, 10, 20)),
          reminderTimeMinutes: const Value(600),
          notificationId: const Value(1001),
        ),
      );

  await database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          id: 'task-done',
          title: 'Ship the last phase',
          listId: const Value('work'),
          priority: const Value(2),
          isCompleted: const Value(true),
          completedAt: Value(now.subtract(const Duration(days: 2))),
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now.subtract(const Duration(days: 2)),
        ),
      );

  await database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          id: 'task-overdue-reminder',
          title: 'Call the dentist',
          priority: const Value(1),
          dueDate: Value(LocalDate(2026, 10, 1)),
          createdAt: now,
          updatedAt: now,
          reminderDate: Value(LocalDate(2026, 10, 1)),
          reminderTimeMinutes: const Value(540),
          notificationId: const Value(1002),
        ),
      );

  await database
      .into(database.subtasks)
      .insert(
        SubtasksCompanion.insert(
          id: 'subtask-1',
          parentTaskId: 'task-open',
          title: 'Outline the phases',
          isCompleted: const Value(true),
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );

  await database
      .into(database.subtasks)
      .insert(
        SubtasksCompanion.insert(
          id: 'subtask-2',
          parentTaskId: 'task-open',
          title: 'Review the plan',
          sortOrder: 1,
          createdAt: now,
          updatedAt: now,
        ),
      );

  await database
      .into(database.dailyFocusEntries)
      .insert(
        DailyFocusEntriesCompanion.insert(
          focusDate: LocalDate(2026, 10, 19),
          taskId: 'task-open',
          sortOrder: 0,
        ),
      );

  await database
      .into(database.settings)
      .insert(
        Setting(key: 'theme_mode', value: 'dark', updatedAt: now),
        mode: InsertMode.insertOrReplace,
      );
}
