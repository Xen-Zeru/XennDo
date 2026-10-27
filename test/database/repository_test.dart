import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/core/database/inbox_defaults.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/core/time/task_timing.dart';
import 'package:xenndo/features/lists/data/list_repository.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';
import 'package:xenndo/features/tasks/domain/subtask_draft.dart';
import 'package:xenndo/features/tasks/domain/task_draft.dart';
import 'package:xenndo/features/tasks/domain/task_filter.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';
import 'package:xenndo/features/today/data/focus_repository.dart';
import 'package:xenndo/features/today/domain/focus_exceptions.dart';

import '../support/test_database.dart';

void main() {
  late AppDatabase database;
  late TaskRepository tasks;
  late ListRepository lists;
  late FocusRepository focus;

  final fixedNow = DateTime(2026, 10, 19, 12);
  final today = LocalDate(2026, 10, 19);

  setUp(() async {
    database = await openInMemoryDatabase();
    tasks = TaskRepository(database, clock: () => fixedNow);
    lists = ListRepository(database, clock: () => fixedNow);
    focus = FocusRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test(
    'list completion progress derives from persisted completed and open tasks',
    () async {
      var inbox = (await lists.watchListsWithOpenCounts().first).single;
      expect(inbox.totalTaskCount, 0);
      expect(inbox.completionFraction, 0);
      final first = await tasks.createTask(const TaskDraft(title: 'First'));
      await tasks.createTask(const TaskDraft(title: 'Second'));
      await tasks.setTaskCompleted(first, true);
      inbox = (await lists.watchListsWithOpenCounts().first).single;
      expect(inbox.openTaskCount, 1);
      expect(inbox.completedTaskCount, 1);
      expect(inbox.totalTaskCount, 2);
      expect(inbox.completionFraction, .5);
      await tasks.setTaskCompleted(first, false);
      inbox = (await lists.watchListsWithOpenCounts().first).single;
      expect(inbox.openTaskCount, 2);
      expect(inbox.completedTaskCount, 0);
      expect(inbox.completionFraction, 0);
    },
  );

  group('schema and validation', () {
    test('uses the current schema version and enables foreign keys', () async {
      expect(database.schemaVersion, 4);
      final result = await database.customSelect('PRAGMA foreign_keys').get();
      expect(result.single.data.values.single, 1);
    });

    test('seeds a protected Inbox', () async {
      final inbox = await lists.getInbox();

      expect(inbox, isNotNull);
      expect(inbox!.id, InboxDefaults.id);
      expect(inbox.name, InboxDefaults.name);
      expect(inbox.isInbox, isTrue);

      await expectLater(lists.deleteList(inbox.id), throwsA(isA<StateError>()));
    });

    test('rejects blank task titles and list names', () async {
      await expectLater(
        Future.sync(() => tasks.createTask(const TaskDraft(title: '   '))),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        lists.createList(name: '  ', color: 0xFF112233),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        lists.renameList(InboxDefaults.id, ' '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects invalid reminder metadata', () async {
      await expectLater(
        Future.sync(
          () => tasks.createTask(
            const TaskDraft(
              title: 'Reminder without a time',
              reminderEnabled: true,
            ),
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('task, list, and subtask persistence', () {
    test('stores a complete task, reminders, and ordered subtasks', () async {
      final workListId = await lists.createList(
        name: 'Work',
        color: 0xFF123456,
        icon: 'work',
      );
      final dueDate = LocalDate(2026, 10, 20);
      const dueTime = 10 * 60 + 30;

      final taskId = await tasks.createTask(
        TaskDraft(
          title: '  Prepare launch notes  ',
          description: '  Share with the team.  ',
          listId: workListId,
          priority: TaskPriority.high,
          dueDate: dueDate,
          dueTimeMinutes: dueTime,
          reminderEnabled: true,
          reminderDate: dueDate,
          reminderTimeMinutes: dueTime,
          subtasks: const [
            SubtaskDraft(title: '  Outline  '),
            SubtaskDraft(title: 'Review'),
            SubtaskDraft(title: '   '),
          ],
        ),
      );

      final task = await tasks.getTask(taskId);
      expect(task, isNotNull);
      expect(task!.title, 'Prepare launch notes');
      expect(task.description, 'Share with the team.');
      expect(task.listId, workListId);
      expect(task.listName, 'Work');
      expect(task.priority, TaskPriority.high);
      expect(task.dueDate, dueDate);
      expect(task.dueTimeMinutes, dueTime);
      expect(task.isCompleted, isFalse);
      expect(task.createdAt.isUtc, isTrue);
      expect(task.updatedAt.isUtc, isTrue);
      expect(task.reminderAt, isNotNull);
      expect(task.reminderAt!.isUtc, isTrue);
      expect(task.reminderDate, dueDate);
      expect(task.reminderTimeMinutes, dueTime);
      expect(task.notificationId, isNotNull);
      expect(
        task.reminderAt,
        TaskTiming.resolveLocalReminderInstant(
          reminderDate: dueDate,
          reminderTimeMinutes: dueTime,
        ),
      );

      final subtasks = await tasks.getSubtasks(taskId);
      expect(subtasks.map((subtask) => subtask.title), ['Outline', 'Review']);
      expect(subtasks.map((subtask) => subtask.sortOrder), [0, 1]);
    });

    test('supports task and subtask CRUD', () async {
      final taskId = await tasks.createTask(
        const TaskDraft(title: 'Original title'),
      );
      final inbox = await lists.getInbox();

      await tasks.updateTask(
        taskId,
        TaskDraft(
          title: 'Updated title',
          description: 'Updated details',
          listId: inbox!.id,
          priority: TaskPriority.low,
          dueDate: LocalDate(2026, 10, 21),
        ),
      );
      var task = await tasks.getTask(taskId);
      expect(task!.title, 'Updated title');
      expect(task.description, 'Updated details');
      expect(task.priority, TaskPriority.low);
      expect(task.dueDate, LocalDate(2026, 10, 21));

      final subtaskId = await tasks.addSubtask(taskId, 'First step');
      await tasks.setSubtaskCompleted(subtaskId, true);
      var subtasks = await tasks.getSubtasks(taskId);
      expect(subtasks.single.isCompleted, isTrue);

      await tasks.deleteSubtask(subtaskId);
      subtasks = await tasks.getSubtasks(taskId);
      expect(subtasks, isEmpty);

      await tasks.deleteTask(taskId);
      task = await tasks.getTask(taskId);
      expect(task, isNull);
    });

    test('completing and reopening updates the completion timestamp', () async {
      final taskId = await tasks.createTask(
        const TaskDraft(title: 'Complete me'),
      );
      final completedAt = DateTime(2026, 10, 19, 18, 30).toUtc();

      await tasks.setTaskCompleted(taskId, true, completedAt: completedAt);
      var task = await tasks.getTask(taskId);
      expect(task!.isCompleted, isTrue);
      expect(task.completedAt, completedAt);
      expect(task.completedAt!.isUtc, isTrue);

      await tasks.setTaskCompleted(taskId, false);
      task = await tasks.getTask(taskId);
      expect(task!.isCompleted, isFalse);
      expect(task.completedAt, isNull);
    });

    test('deleting a list moves its tasks to Inbox', () async {
      final listId = await lists.createList(
        name: 'Temporary',
        color: 0xFF334455,
      );
      final taskId = await tasks.createTask(
        TaskDraft(title: 'Move me', listId: listId),
      );

      await lists.deleteList(listId);

      final movedTask = await tasks.getTask(taskId);
      expect(movedTask!.listId, InboxDefaults.id);
      expect(movedTask.listName, InboxDefaults.name);
      final remainingLists = await lists.getLists();
      expect(remainingLists.map((list) => list.id), isNot(contains(listId)));
    });

    test('deleting a task removes subtasks and focus selections', () async {
      final taskId = await tasks.createTask(
        const TaskDraft(
          title: 'Delete me',
          subtasks: [SubtaskDraft(title: 'Child task')],
        ),
      );
      await focus.addToFocus(date: today, taskId: taskId);

      await tasks.deleteTask(taskId);

      expect(await tasks.getSubtasks(taskId), isEmpty);
      expect(await focus.getFocusSelections(today), isEmpty);
      expect(await tasks.getTask(taskId), isNull);
    });

    test('reports open task counts in each list', () async {
      final listId = await lists.createList(name: 'Counted', color: 0xFF223344);
      final firstId = await tasks.createTask(
        TaskDraft(title: 'First', listId: listId),
      );
      await tasks.createTask(TaskDraft(title: 'Second', listId: listId));
      await tasks.setTaskCompleted(firstId, true);

      final summaries = await lists.watchListsWithOpenCounts().first;
      final counted = summaries.firstWhere((list) => list.id == listId);
      final inbox = summaries.firstWhere((list) => list.id == InboxDefaults.id);

      expect(counted.openTaskCount, 1);
      expect(inbox.openTaskCount, 0);
    });
  });

  group('My Top 3', () {
    test(
      'allows three distinct tasks per date and rejects duplicates',
      () async {
        final taskIds = <String>[];
        for (var index = 0; index < 4; index++) {
          taskIds.add(
            await tasks.createTask(TaskDraft(title: 'Focus ${index + 1}')),
          );
        }

        await focus.addToFocus(date: today, taskId: taskIds[0]);
        await focus.addToFocus(date: today, taskId: taskIds[1]);
        await focus.addToFocus(date: today, taskId: taskIds[2]);

        await expectLater(
          focus.addToFocus(date: today, taskId: taskIds[3]),
          throwsA(isA<FocusLimitException>()),
        );
        await expectLater(
          focus.addToFocus(date: today, taskId: taskIds[0]),
          throwsA(isA<FocusDuplicateException>()),
        );

        final selections = await focus.getFocusSelections(today);
        expect(
          selections.map((selection) => selection.taskId),
          taskIds.take(3),
        );
        expect(selections.map((selection) => selection.sortOrder), [0, 1, 2]);

        await focus.addToFocus(date: today.addDays(1), taskId: taskIds[0]);
        final nextDay = await focus.getFocusSelections(today.addDays(1));
        expect(nextDay.single.taskId, taskIds[0]);
      },
    );

    test('supports removal and reordering', () async {
      final firstId = await tasks.createTask(
        const TaskDraft(title: 'First focus'),
      );
      final secondId = await tasks.createTask(
        const TaskDraft(title: 'Second focus'),
      );
      await focus.addToFocus(date: today, taskId: firstId);
      await focus.addToFocus(date: today, taskId: secondId);

      await focus.reorderFocus(
        date: today,
        orderedTaskIds: [secondId, firstId],
      );
      var selections = await focus.getFocusSelections(today);
      expect(selections.map((selection) => selection.taskId), [
        secondId,
        firstId,
      ]);

      await focus.removeFromFocus(date: today, taskId: secondId);
      selections = await focus.getFocusSelections(today);
      expect(selections.single.taskId, firstId);
    });
  });

  group('date handling', () {
    test('date-only values round-trip independently of local wall time', () {
      final date = LocalDate(2026, 3, 8);
      expect(date.epochDay, 20520);
      expect(LocalDate.fromEpochDay(date.epochDay), date);
      expect(date.toIso8601String(), '2026-03-08');
    });

    test('timed deadline overdue logic is testable with an explicit now', () {
      final now = DateTime(2026, 10, 19, 12);

      expect(
        TaskTiming.isOverdue(
          dueDate: LocalDate(2026, 10, 18),
          dueTimeMinutes: null,
          now: now,
        ),
        isTrue,
      );
      expect(
        TaskTiming.isOverdue(
          dueDate: LocalDate(2026, 10, 19),
          dueTimeMinutes: null,
          now: now,
        ),
        isFalse,
      );
      expect(
        TaskTiming.isOverdue(
          dueDate: LocalDate(2026, 10, 19),
          dueTimeMinutes: 9 * 60,
          now: now,
        ),
        isTrue,
      );
      expect(
        TaskTiming.isOverdue(
          dueDate: LocalDate(2026, 10, 19),
          dueTimeMinutes: 15 * 60,
          now: now,
        ),
        isFalse,
      );
    });

    test(
      'Today and Upcoming split due and completion dates by local day',
      () async {
        final yesterday = today.addDays(-1);
        final tomorrow = today.addDays(1);

        final yesterdayDateOnly = await tasks.createTask(
          TaskDraft(title: 'Yesterday', dueDate: yesterday),
        );
        final todayDateOnly = await tasks.createTask(
          TaskDraft(title: 'Today date only', dueDate: today),
        );
        final tomorrowDateOnly = await tasks.createTask(
          TaskDraft(title: 'Tomorrow', dueDate: tomorrow),
        );
        final todayTimedPast = await tasks.createTask(
          TaskDraft(
            title: 'Today earlier',
            dueDate: today,
            dueTimeMinutes: 9 * 60,
          ),
        );
        final todayTimedFuture = await tasks.createTask(
          TaskDraft(
            title: 'Today later',
            dueDate: today,
            dueTimeMinutes: 15 * 60,
          ),
        );
        final completedToday = await tasks.createTask(
          const TaskDraft(title: 'Completed today'),
        );
        final completedYesterday = await tasks.createTask(
          const TaskDraft(title: 'Completed yesterday'),
        );

        await tasks.setTaskCompleted(
          completedToday,
          true,
          completedAt: DateTime(2026, 10, 19, 8).toUtc(),
        );
        await tasks.setTaskCompleted(
          completedYesterday,
          true,
          completedAt: DateTime(2026, 10, 18, 23, 59).toUtc(),
        );

        final agenda = await tasks.watchToday(today: today).first;
        expect(
          agenda.overdue.map((task) => task.id),
          containsAll([yesterdayDateOnly, todayTimedPast]),
        );
        expect(
          agenda.dueToday.map((task) => task.id),
          containsAll([todayDateOnly, todayTimedFuture]),
        );
        expect(agenda.completedToday.map((task) => task.id), [completedToday]);
        expect(
          agenda.completedToday.map((task) => task.id),
          isNot(contains(completedYesterday)),
        );

        final upcoming = await tasks.watchUpcoming(after: today).first;
        expect(upcoming.map((task) => task.id), [tomorrowDateOnly]);

        final storedTomorrow = await tasks.getTask(tomorrowDateOnly);
        expect(storedTomorrow!.dueDate, tomorrow);
      },
    );
  });

  group('task and list management', () {
    test(
      'editing a task reconciles subtasks without completing the parent',
      () async {
        final taskId = await tasks.createTask(
          const TaskDraft(
            title: 'Parent task',
            subtasks: [
              SubtaskDraft(title: 'Alpha'),
              SubtaskDraft(title: 'Beta'),
              SubtaskDraft(title: 'Gamma'),
            ],
          ),
        );

        var subtasks = await tasks.getSubtasks(taskId);
        final alphaId = subtasks[0].id;
        final betaId = subtasks[1].id;
        final gammaId = subtasks[2].id;
        await tasks.setSubtaskCompleted(alphaId, true);

        await tasks.updateTask(
          taskId,
          TaskDraft(
            title: 'Parent task updated',
            subtasks: [
              SubtaskDraft(id: gammaId, title: 'Gamma updated'),
              SubtaskDraft(id: alphaId, title: 'Alpha', isCompleted: true),
              const SubtaskDraft(title: 'Delta'),
            ],
          ),
        );

        subtasks = await tasks.getSubtasks(taskId);
        expect(subtasks.map((subtask) => subtask.title), [
          'Gamma updated',
          'Alpha',
          'Delta',
        ]);
        expect(subtasks.map((subtask) => subtask.isCompleted), [
          false,
          true,
          false,
        ]);
        expect(subtasks.map((subtask) => subtask.id), isNot(contains(betaId)));

        final parent = await tasks.getTask(taskId);
        expect(parent!.isCompleted, isFalse);
      },
    );

    test('completing every subtask does not complete the parent', () async {
      final taskId = await tasks.createTask(
        const TaskDraft(
          title: 'Parent stays open',
          subtasks: [
            SubtaskDraft(title: 'One'),
            SubtaskDraft(title: 'Two'),
          ],
        ),
      );
      final subtasks = await tasks.getSubtasks(taskId);
      for (final subtask in subtasks) {
        await tasks.setSubtaskCompleted(subtask.id, true);
      }

      final parent = await tasks.getTask(taskId);
      expect(parent!.isCompleted, isFalse);
      final updatedSubtasks = await tasks.getSubtasks(taskId);
      expect(updatedSubtasks.every((subtask) => subtask.isCompleted), isTrue);
    });

    test(
      'delete snapshot restores the task, subtasks, and focus selections',
      () async {
        final taskId = await tasks.createTask(
          TaskDraft(
            title: 'Restore me',
            description: 'With details',
            priority: TaskPriority.high,
            dueDate: today,
            dueTimeMinutes: 15 * 60,
            subtasks: const [
              SubtaskDraft(title: 'Step one'),
              SubtaskDraft(title: 'Step two', isCompleted: true),
            ],
          ),
        );
        await focus.addToFocus(date: today, taskId: taskId);
        final originalSubtasks = await tasks.getSubtasks(taskId);

        final snapshot = await tasks.deleteTaskWithSnapshot(taskId);
        expect(snapshot.task.id, taskId);
        expect(await tasks.getTask(taskId), isNull);
        expect(await tasks.getSubtasks(taskId), isEmpty);
        expect(await focus.getFocusSelections(today), isEmpty);

        await tasks.restoreTask(snapshot);

        final restored = await tasks.getTask(taskId);
        expect(restored, isNotNull);
        expect(restored!.title, 'Restore me');
        expect(restored.description, 'With details');
        expect(restored.priority, TaskPriority.high);
        expect(restored.dueDate, today);
        expect(restored.dueTimeMinutes, 15 * 60);

        final restoredSubtasks = await tasks.getSubtasks(taskId);
        expect(
          restoredSubtasks.map((subtask) => subtask.id),
          originalSubtasks.map((subtask) => subtask.id),
        );
        expect(restoredSubtasks.map((subtask) => subtask.isCompleted), [
          false,
          true,
        ]);
        expect(await focus.getFocusSelections(today), hasLength(1));
      },
    );

    test('lists can be renamed and recolored', () async {
      final listId = await lists.createList(
        name: 'Old name',
        color: 0xFF111111,
      );

      await lists.renameList(listId, '  New name  ');
      await lists.recolorList(listId, 0xFF22AA55);

      final updated = (await lists.getLists()).firstWhere(
        (list) => list.id == listId,
      );
      expect(updated.name, 'New name');
      expect(updated.color, 0xFF22AA55);
    });

    test('new tasks default to medium priority', () async {
      final taskId = await tasks.createTask(const TaskDraft(title: 'Default'));
      final task = await tasks.getTask(taskId);
      expect(task!.priority, TaskPriority.medium);
    });
  });

  group('planning views', () {
    test(
      'due-today tasks become overdue after the local day changes',
      () async {
        final taskId = await tasks.createTask(
          TaskDraft(title: 'Boundary task', dueDate: today),
        );
        final tomorrow = today.addDays(1);

        final firstDay = await tasks.watchToday(today: today).first;
        expect(firstDay.dueToday.map((task) => task.id), contains(taskId));
        expect(firstDay.overdue, isEmpty);

        final tomorrowTasks = TaskRepository(
          database,
          clock: () => DateTime(2026, 10, 20, 8),
        );
        final secondDay = await tomorrowTasks.watchToday(today: tomorrow).first;
        expect(secondDay.overdue.map((task) => task.id), contains(taskId));
        expect(secondDay.dueToday, isEmpty);
      },
    );

    test('future tasks stay out of Today and appear in Upcoming', () async {
      final tomorrow = today.addDays(1);
      final futureId = await tasks.createTask(
        TaskDraft(title: 'Future task', dueDate: tomorrow),
      );

      final agenda = await tasks.watchToday(today: today).first;
      expect(agenda.overdue.map((task) => task.id), isNot(contains(futureId)));
      expect(agenda.dueToday.map((task) => task.id), isNot(contains(futureId)));

      final upcoming = await tasks.watchUpcoming(after: today).first;
      expect(upcoming.map((task) => task.id), contains(futureId));
    });

    test('My Top 3 selections are isolated per local date', () async {
      final taskId = await tasks.createTask(
        const TaskDraft(title: 'Focus once'),
      );
      await focus.addToFocus(date: today, taskId: taskId);

      expect(await focus.watchTopThree(today).first, hasLength(1));
      expect(await focus.watchTopThree(today.addDays(1)).first, isEmpty);
    });

    test('search matches titles and descriptions', () async {
      await tasks.createTask(
        const TaskDraft(
          title: 'Alpha report',
          description: 'Quarterly numbers',
        ),
      );
      await tasks.createTask(const TaskDraft(title: 'Beta errand'));

      final titleMatch = await tasks
          .watchFilteredTasks(const TaskFilter(query: 'alpha'))
          .first;
      expect(titleMatch.map((task) => task.title), ['Alpha report']);

      final descriptionMatch = await tasks
          .watchFilteredTasks(const TaskFilter(query: 'quarterly'))
          .first;
      expect(descriptionMatch.map((task) => task.title), ['Alpha report']);

      final noMatch = await tasks
          .watchFilteredTasks(const TaskFilter(query: 'missing'))
          .first;
      expect(noMatch, isEmpty);
    });

    test(
      'combined filters intersect and clearing restores all tasks',
      () async {
        final workId = await lists.createList(name: 'Work', color: 0xFF111111);
        final personalId = await lists.createList(
          name: 'Personal',
          color: 0xFF222222,
        );
        final alphaReport = await tasks.createTask(
          TaskDraft(
            title: 'Alpha report',
            description: 'Quarterly numbers',
            listId: workId,
            priority: TaskPriority.high,
          ),
        );
        await tasks.createTask(
          TaskDraft(
            title: 'Beta report',
            listId: personalId,
            priority: TaskPriority.low,
          ),
        );
        final gamma = await tasks.createTask(
          TaskDraft(title: 'Gamma', listId: workId),
        );
        final betaId = (await tasks.getTasksForList(personalId)).single.id;
        await tasks.setTaskCompleted(betaId, true);

        final combined = await tasks
            .watchFilteredTasks(
              TaskFilter(
                query: 'report',
                listId: workId,
                priority: TaskPriority.high,
                completion: TaskCompletionFilter.incomplete,
              ),
            )
            .first;
        expect(combined.map((task) => task.id), [alphaReport]);

        final incompleteWork = await tasks
            .watchFilteredTasks(
              TaskFilter(
                listId: workId,
                completion: TaskCompletionFilter.incomplete,
              ),
            )
            .first;
        expect(
          incompleteWork.map((task) => task.id),
          containsAll([alphaReport, gamma]),
        );

        final allTasks = await tasks
            .watchFilteredTasks(const TaskFilter())
            .first;
        expect(allTasks, hasLength(3));
      },
    );

    test('filtered ordering is deterministic', () async {
      final workId = await lists.createList(name: 'Work', color: 0xFF333333);
      await tasks.createTask(
        TaskDraft(title: 'Zeta', listId: workId, priority: TaskPriority.high),
      );
      await tasks.createTask(
        TaskDraft(title: 'Alpha', listId: workId, priority: TaskPriority.high),
      );
      await tasks.createTask(TaskDraft(title: 'Beta', listId: workId));

      final results = await tasks
          .watchFilteredTasks(
            TaskFilter(
              listId: workId,
              completion: TaskCompletionFilter.incomplete,
            ),
          )
          .first;
      expect(results.map((task) => task.title), ['Alpha', 'Zeta', 'Beta']);
    });
  });

  test('search query stays usable with a 5,000-task fixture', () async {
    final now = DateTime.utc(2026);
    final companions = [
      for (var index = 0; index < 5000; index++)
        TasksCompanion.insert(
          id: 'bulk-$index',
          title: 'Bulk task $index',
          listId: const Value(InboxDefaults.id),
          createdAt: now,
          updatedAt: now,
        ),
    ];
    await database.batch(
      (batch) => batch.insertAll(database.tasks, companions),
    );

    final results = await tasks
        .watchFilteredTasks(
          const TaskFilter(completion: TaskCompletionFilter.incomplete),
        )
        .first;
    expect(results, hasLength(5000));

    final filtered = await tasks
        .watchFilteredTasks(const TaskFilter(query: 'Bulk task 4999'))
        .first;
    expect(filtered.map((task) => task.id), ['bulk-4999']);
  });

  group('migrations', () {
    test('schema version 1 upgrades to the current version', () async {
      final createdAt = DateTime.utc(2026, 10, 19, 9).millisecondsSinceEpoch;
      final reminderAt = DateTime(
        2026,
        10,
        19,
        10,
      ).toUtc().millisecondsSinceEpoch;

      final legacyDatabase = AppDatabase(
        NativeDatabase.memory(
          setup: (raw) {
            raw.execute(
              'CREATE TABLE task_lists ('
              'id TEXT NOT NULL PRIMARY KEY, '
              'name TEXT NOT NULL, '
              'color INTEGER NOT NULL, '
              'icon TEXT NULL, '
              'sort_order INTEGER NOT NULL, '
              'is_inbox INTEGER NOT NULL DEFAULT 0, '
              'created_at INTEGER NOT NULL, '
              'updated_at INTEGER NOT NULL)',
            );
            raw.execute(
              'CREATE TABLE tasks ('
              'id TEXT NOT NULL PRIMARY KEY, '
              'title TEXT NOT NULL, '
              'description TEXT NULL, '
              'list_id TEXT NULL, '
              'priority INTEGER NOT NULL DEFAULT 0, '
              'due_date INTEGER NULL, '
              'due_time_minutes INTEGER NULL, '
              'is_completed INTEGER NOT NULL DEFAULT 0, '
              'completed_at INTEGER NULL, '
              'created_at INTEGER NOT NULL, '
              'updated_at INTEGER NOT NULL, '
              'reminder_at INTEGER NULL, '
              'reminder_offset_minutes INTEGER NULL, '
              'notification_id INTEGER NULL)',
            );
            raw.execute(
              'INSERT INTO tasks (id, title, priority, is_completed, '
              'created_at, updated_at, reminder_at, notification_id) '
              'VALUES (?, ?, 2, 0, ?, ?, ?, ?)',
              [
                'legacy-task',
                'Legacy task',
                createdAt,
                createdAt,
                reminderAt,
                123456,
              ],
            );
            raw.execute(
              'CREATE TABLE daily_focus_entries (focus_date INTEGER NOT NULL, task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE, sort_order INTEGER NOT NULL CHECK(sort_order BETWEEN 0 AND 2), PRIMARY KEY(focus_date, task_id), UNIQUE(focus_date, sort_order))',
            );
            raw.userVersion = 1;
          },
        ),
      );
      addTearDown(legacyDatabase.close);

      expect(legacyDatabase.schemaVersion, 4);
      // The v3 migration step creates the settings table for preferences.
      expect(
        await legacyDatabase.select(legacyDatabase.settings).get(),
        isEmpty,
      );
      final task = await TaskRepository(legacyDatabase).getTask('legacy-task');
      expect(task, isNotNull);
      expect(task!.title, 'Legacy task');
      expect(task.notificationId, 123456);
      // Local reminder fields are derived from the legacy instant.
      expect(task.reminderDate, isNotNull);
      expect(task.reminderTimeMinutes, isNotNull);
    });
  });

  group('file persistence', () {
    test('data survives closing and reopening the database', () async {
      final directory = await Directory.systemTemp.createTemp(
        'xenndo-db-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/xenndo_test.sqlite');

      var fileDatabase = AppDatabase(NativeDatabase(file));
      final fileTasks = TaskRepository(fileDatabase, clock: () => fixedNow);
      final fileLists = ListRepository(fileDatabase, clock: () => fixedNow);
      final fileFocus = FocusRepository(fileDatabase);

      final listId = await fileLists.createList(
        name: 'Persistent',
        color: 0xFF445566,
      );
      final taskId = await fileTasks.createTask(
        TaskDraft(
          title: 'Survive restart',
          listId: listId,
          dueDate: today,
          subtasks: const [SubtaskDraft(title: 'Persisted subtask')],
        ),
      );
      await fileFocus.addToFocus(date: today, taskId: taskId);
      await fileDatabase.close();

      fileDatabase = AppDatabase(NativeDatabase(file));
      final reopenedTasks = TaskRepository(fileDatabase, clock: () => fixedNow);
      final reopenedLists = ListRepository(fileDatabase);
      final reopenedFocus = FocusRepository(fileDatabase);

      final task = await reopenedTasks.getTask(taskId);
      expect(task, isNotNull);
      expect(task!.title, 'Survive restart');
      expect(task.listName, 'Persistent');
      expect(await reopenedTasks.getSubtasks(taskId), hasLength(1));
      expect(await reopenedFocus.getFocusSelections(today), hasLength(1));
      expect(
        (await reopenedLists.getLists()).map((list) => list.name),
        containsAll(['Inbox', 'Persistent']),
      );
      expect(fileDatabase.schemaVersion, 4);

      await fileDatabase.close();
    });
  });
}
