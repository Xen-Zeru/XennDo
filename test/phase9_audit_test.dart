import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/app/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/backup/data/backup_repository.dart';
import 'package:xenndo/features/backup/presentation/backup_dialogs.dart';
import 'package:xenndo/features/backup/domain/backup_document.dart';
import 'package:xenndo/features/lists/data/list_repository.dart';
import 'package:xenndo/features/reminders/application/reminder_reconciler.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';
import 'package:xenndo/features/tasks/domain/task_draft.dart';
import 'package:xenndo/features/tasks/domain/task_filter.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';
import 'package:xenndo/features/tasks/presentation/widgets/persisted_task_row.dart';
import 'package:xenndo/features/tasks/presentation/task_editor_screen.dart';
import 'package:xenndo/features/today/data/focus_repository.dart';
import 'package:xenndo/features/today/domain/focus_exceptions.dart';

import 'reminders/fake_reminder_scheduler.dart';
import 'support/test_app.dart';
import 'support/test_database.dart';

final _now = DateTime(2026, 10, 25, 12);
final _today = LocalDate.fromDateTime(_now);

class _FailingScheduler extends FakeReminderScheduler {
  bool fail = true;
  @override
  Future<void> cancel(int id) async {
    if (fail) throw StateError('Android unavailable');
    await super.cancel(id);
  }
}

class _DelayedScheduler extends FakeReminderScheduler {
  bool delay = false;
  final gate = Completer<void>();
  @override
  Future<void> cancel(int id) async {
    if (delay) await gate.future;
    await super.cancel(id);
  }
}

TaskDraft _reminder(String title) => TaskDraft(
  title: title,
  reminderEnabled: true,
  reminderDate: _today.addDays(1),
  reminderTimeMinutes: 9 * 60,
);

void main() {
  group('Phase 9 repository regressions', () {
    late AppDatabase db;
    late TaskRepository tasks;
    setUp(() async {
      db = await openInMemoryDatabase();
      tasks = TaskRepository(db, clock: () => _now);
    });
    tearDown(() => db.close());

    test(
      'notification failure preserves committed saves and delete Undo',
      () async {
        final notices = <String>[];
        final scheduler = _FailingScheduler();
        final repo = TaskRepository(
          db,
          clock: () => _now,
          reminderScheduler: scheduler,
          onNotice: notices.add,
        );
        final id = await repo.createTask(_reminder('Persist once'));
        expect(await db.select(db.tasks).get(), hasLength(1));
        expect(notices, hasLength(1));
        await repo.updateTask(id, _reminder('Edited once'));
        expect((await repo.getTask(id))!.title, 'Edited once');
        await repo.setTaskCompleted(id, true);
        final snapshot = await repo.deleteTaskWithSnapshot(id);
        expect(await repo.getTask(id), isNull);
        await repo.restoreTask(snapshot);
        expect((await repo.getTask(id))!.isCompleted, isTrue);
        scheduler.fail = false;
        await repo.setTaskCompleted(id, false);
        expect(scheduler.scheduled.single.taskId, id);
      },
    );

    test(
      'turning a reminder off cancels its previous native id immediately',
      () async {
        final scheduler = FakeReminderScheduler();
        final repo = TaskRepository(
          db,
          clock: () => _now,
          reminderScheduler: scheduler,
        );
        final id = await repo.createTask(_reminder('Switch off'));
        final notificationId = (await repo.getTask(id))!.notificationId!;
        expect(scheduler.pending, contains(notificationId));
        await repo.updateTask(id, const TaskDraft(title: 'Switch off'));
        expect(scheduler.pending, isEmpty);
        expect((await repo.getTask(id))!.notificationId, isNull);
      },
    );

    test(
      'revoked permission retains definitions without claiming delivery',
      () async {
        final notices = <String>[];
        final scheduler = FakeReminderScheduler()
          ..permission = ReminderPermissionStatus.denied;
        final repo = TaskRepository(
          db,
          clock: () => _now,
          reminderScheduler: scheduler,
          onNotice: notices.add,
        );
        final id = await repo.createTask(_reminder('Permission off'));
        expect((await repo.getTask(id))!.reminderDate, _today.addDays(1));
        expect(scheduler.scheduled, isEmpty);
        expect(notices.single, contains('not scheduled'));
        await ReminderReconciler(
          tasks: repo,
          scheduler: scheduler,
          clock: () => _now,
        ).reconcile();
        expect(scheduler.scheduled, isEmpty);
        scheduler.permission = ReminderPermissionStatus.granted;
        await ReminderReconciler(
          tasks: repo,
          scheduler: scheduler,
          clock: () => _now,
        ).reconcile();
        expect(scheduler.scheduled.single.taskId, id);
      },
    );

    test('repeat completion preserves its original timestamp', () async {
      final id = await tasks.createTask(const TaskDraft(title: 'Once'));
      await tasks.setTaskCompleted(id, true);
      await tasks.setTaskCompleted(
        id,
        true,
        completedAt: _now.add(const Duration(hours: 1)),
      );
      expect((await tasks.getTask(id))!.completedAt, _now.toUtc());
    });

    test(
      'completed focus frees a slot and survives ordering and backup',
      () async {
        final focus = FocusRepository(db);
        final ids = <String>[];
        for (var i = 0; i < 5; i++) {
          ids.add(await tasks.createTask(TaskDraft(title: 'Focus $i')));
        }
        for (final id in ids.take(3)) {
          await focus.addToFocus(date: _today, taskId: id);
        }
        await tasks.setTaskCompleted(ids.first, true);
        await focus.addToFocus(date: _today, taskId: ids[3]);
        expect(await focus.getFocusSelections(_today), hasLength(4));
        await expectLater(
          focus.addToFocus(date: _today, taskId: ids[4]),
          throwsA(isA<FocusLimitException>()),
        );
        await focus.reorderFocus(
          date: _today,
          orderedTaskIds: ids.take(4).toList().reversed.toList(),
        );
        final backup = BackupDocument.decode(
          (await BackupRepository(db).exportAll()).encode(),
        );
        expect(backup.version, 2);
        expect(backup.focusEntries, hasLength(4));
        await BackupRepository(db).restore(backup);
        expect((await focus.getFocusSelections(_today)).first.taskId, ids[3]);
        await tasks.setTaskCompleted(ids.first, false);
        expect((await tasks.getTask(ids.first))!.isCompleted, isFalse);
        expect(await focus.getFocusSelections(_today), hasLength(3));
      },
    );

    test('Undo never creates a fourth active focus selection', () async {
      final focus = FocusRepository(db);
      final first = await tasks.createTask(const TaskDraft(title: 'Delete me'));
      await focus.addToFocus(date: _today, taskId: first);
      final snapshot = await tasks.deleteTaskWithSnapshot(first);
      for (var i = 0; i < 3; i++) {
        final id = await tasks.createTask(TaskDraft(title: 'Replacement $i'));
        await focus.addToFocus(date: _today, taskId: id);
      }
      await tasks.restoreTask(snapshot);
      expect(await tasks.getTask(first), isNotNull);
      expect(await focus.getFocusSelections(_today), hasLength(3));
    });

    test(
      'inclusive local-date range combines with search and excludes undated',
      () async {
        for (var day = -1; day <= 2; day++) {
          await tasks.createTask(
            TaskDraft(title: 'Report $day', dueDate: _today.addDays(day)),
          );
        }
        await tasks.createTask(const TaskDraft(title: 'Report undated'));
        final result = await tasks
            .watchFilteredTasks(
              TaskFilter(
                query: 'report',
                dueFrom: _today,
                dueThrough: _today.addDays(1),
                completion: TaskCompletionFilter.incomplete,
              ),
            )
            .first;
        expect(result.map((task) => task.title), ['Report 0', 'Report 1']);
        expect(TaskFilter(dueFrom: _today).cleared().isActive, isFalse);
      },
    );

    test(
      'list/task manual ordering survives backup and rejects incomplete orders',
      () async {
        final lists = ListRepository(db);
        final a = await lists.createList(name: 'A', color: 1);
        final b = await lists.createList(name: 'B', color: 2);
        await lists.reorderLists(['inbox', b, a]);
        expect((await lists.getLists()).map((list) => list.name), [
          'Inbox',
          'B',
          'A',
        ]);
        await expectLater(lists.reorderLists([b, a]), throwsArgumentError);
        final one = await tasks.createTask(TaskDraft(title: 'One', listId: a));
        final two = await tasks.createTask(TaskDraft(title: 'Two', listId: a));
        await tasks.reorderTasks(a, [two, one]);
        final three = await tasks.createTask(
          TaskDraft(title: 'Three', listId: a),
        );
        await expectLater(tasks.reorderTasks(a, [one]), throwsArgumentError);
        final backup = BackupDocument.decode(
          (await BackupRepository(db).exportAll()).encode(),
        );
        await BackupRepository(db).restore(backup);
        expect((await tasks.getTasksForList(a)).map((task) => task.id), [
          two,
          one,
          three,
        ]);
      },
    );

    test('default list order prioritizes open high priority tasks', () async {
      final low = await tasks.createTask(
        TaskDraft(
          title: 'Low early',
          priority: TaskPriority.low,
          dueDate: _today,
        ),
      );
      final high = await tasks.createTask(
        TaskDraft(
          title: 'High later',
          priority: TaskPriority.high,
          dueDate: _today.addDays(2),
        ),
      );
      final done = await tasks.createTask(
        const TaskDraft(title: 'High done', priority: TaskPriority.high),
      );
      await tasks.setTaskCompleted(done, true);
      expect((await tasks.getTasksForList('inbox')).map((task) => task.id), [
        high,
        low,
        done,
      ]);
    });

    test('version 1 backup loads with default order and maps missing list to Inbox', () async {
      await tasks.createTask(const TaskDraft(title: 'Legacy'));
      final json = (await BackupRepository(db).exportAll()).toJson();
      json['version'] = 1;
      json['schemaVersion'] = 3;
      final data = json['data'] as Map<String, Object?>;
      final rows = data['tasks'] as List;
      (rows.first as Map).remove('sortOrder');
      (rows.first as Map)['listId'] = null;
      await BackupRepository(db)
          .restore(BackupDocument.decode(jsonEncode(json)));
      final restored = (await tasks.getTasksForList('inbox')).single;
      expect(restored.sortOrder, 0);
    });
  });

  for (final oldVersion in [2, 3]) {
    test(
      'schema $oldVersion migration preserves tasks, subtasks, focus and settings',
      () async {
        final dir = await Directory.systemTemp.createTemp('xenndo-migration-');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/legacy.sqlite');
        var db = AppDatabase(NativeDatabase(file));
        final tasks = TaskRepository(db, clock: () => _now);
        final id = await tasks.createTask(const TaskDraft(title: 'Preserved'));
        await tasks.addSubtask(id, 'Preserved step');
        await FocusRepository(db).addToFocus(date: _today, taskId: id);
        await db.customStatement(
          "INSERT INTO settings VALUES ('theme_mode', 'dark', 0)",
        );
        // Recreate the pre-v4 constraint and remove the new task column.
        await db.customStatement('ALTER TABLE tasks DROP COLUMN sort_order');
        await db.customStatement(
          'ALTER TABLE daily_focus_entries RENAME TO focus_new',
        );
        await db.customStatement(
          'CREATE TABLE daily_focus_entries (focus_date INTEGER NOT NULL, task_id TEXT NOT NULL REFERENCES tasks(id) ON DELETE CASCADE, sort_order INTEGER NOT NULL CHECK(sort_order BETWEEN 0 AND 2), PRIMARY KEY(focus_date, task_id), UNIQUE(focus_date,sort_order))',
        );
        await db.customStatement(
          'INSERT INTO daily_focus_entries SELECT * FROM focus_new',
        );
        await db.customStatement('DROP TABLE focus_new');
        if (oldVersion == 2) await db.customStatement('DROP TABLE settings');
        await db.customStatement('PRAGMA user_version = $oldVersion');
        await db.close();
        db = AppDatabase(NativeDatabase(file));
        final repo = TaskRepository(db, clock: () => _now);
        expect((await repo.getTask(id))!.title, 'Preserved');
        expect((await repo.getTask(id))!.sortOrder, 0);
        expect(await repo.getSubtasks(id), hasLength(1));
        expect(
          await FocusRepository(db).getFocusSelections(_today),
          hasLength(1),
        );
        expect(
          (await db.customSelect('PRAGMA foreign_key_check').get()),
          isEmpty,
        );
        expect(
          (await db.select(db.settings).get()).length,
          oldVersion == 3 ? 1 : 0,
        );
        await db.close();
      },
    );
  }

  testWidgets(
    'new past reminders are rejected even when scheduling controls are collapsed',
    (tester) async {
      final db = await pumpXenndoAppLive(
        tester,
        now: _now,
        reminderScheduler: FakeReminderScheduler(),
      );
      final context = tester.element(
        find.byKey(const ValueKey('today-screen')),
      );
      unawaited(
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => TaskEditorScreen(
              initialValues: TaskEditorInitialValues(
                title: 'Keep my draft',
                reminderEnabled: true,
                reminderDate: LocalDate(2020, 1, 2),
                reminderTimeMinutes: 540,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-task-button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Choose a future reminder date and time.'),
        findsOneWidget,
      );
      expect(find.text('Keep my draft'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('task-schedule-section')),
      );
      await tester.tap(find.byKey(const ValueKey('task-schedule-section')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-task-button')));
      await tester.pumpAndSettle();
      expect(
        find.text('Choose a future reminder date and time.'),
        findsOneWidget,
      );
      expect(await db.select(db.tasks).get(), isEmpty);
      await disposeXenndoApp(tester);
    },
  );

  testWidgets('imported old dates open both calendar controls safely', (
    tester,
  ) async {
    final db = await openInMemoryDatabase();
    addTearDown(db.close);
    final tasks = TaskRepository(db, clock: () => _now);
    final id = await tasks.createTask(
      TaskDraft(
        title: 'Old imported date',
        dueDate: LocalDate(2020, 1, 2),
        reminderEnabled: true,
        reminderDate: LocalDate(2020, 1, 2),
        reminderTimeMinutes: 540,
      ),
    );
    final scheduler = FakeReminderScheduler()..initialTaskId = id;
    await pumpXenndoAppLive(
      tester,
      now: _now,
      database: db,
      reminderScheduler: scheduler,
    );
    for (final key in ['due-date-tile', 'reminder-date-tile']) {
      await tester.ensureVisible(find.byKey(ValueKey(key)));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    }
    await disposeXenndoApp(tester);
  });

  testWidgets(
    'editing other fields keeps an unchanged elapsed reminder definition',
    (tester) async {
      final db = await openInMemoryDatabase();
      addTearDown(db.close);
      final tasks = TaskRepository(db, clock: () => _now);
      final date = LocalDate(2020, 1, 2);
      final id = await tasks.createTask(
        TaskDraft(
          title: 'Elapsed reminder',
          reminderEnabled: true,
          reminderDate: date,
          reminderTimeMinutes: 540,
        ),
      );
      final scheduler = FakeReminderScheduler()..initialTaskId = id;
      await pumpXenndoAppLive(
        tester,
        now: _now,
        database: db,
        reminderScheduler: scheduler,
      );
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Edited title, same old reminder',
      );
      await tester.tap(find.byKey(const ValueKey('save-task-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
      final saved = (await tasks.getTask(id))!;
      expect(saved.title, 'Edited title, same old reminder');
      expect(saved.reminderDate, date);
      expect(scheduler.scheduled, isEmpty);
      await disposeXenndoApp(tester);
    },
  );

  testWidgets(
    'startup notification editor closes and saves back to the shell',
    (tester) async {
      final db = await openInMemoryDatabase();
      addTearDown(db.close);
      final tasks = TaskRepository(db, clock: () => _now);
      final id = await tasks.createTask(
        const TaskDraft(title: 'Notification task'),
      );
      final scheduler = FakeReminderScheduler()..initialTaskId = id;
      await pumpXenndoAppLive(
        tester,
        now: _now,
        database: db,
        reminderScheduler: scheduler,
      );
      expect(find.byKey(const ValueKey('task-editor-screen')), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
      scheduler.simulateTap(id);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Notification edited',
      );
      await tester.tap(find.byKey(const ValueKey('save-task-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
      expect((await tasks.getTask(id))!.title, 'Notification edited');
      expect(tester.takeException(), isNull);
      await disposeXenndoApp(tester);
    },
  );

  testWidgets('direct editor route never pops its last page after save', (
    tester,
  ) async {
    final db = await pumpXenndoAppLive(tester, now: _now);
    final id = await TaskRepository(
      db,
      clock: () => _now,
    ).createTask(const TaskDraft(title: 'Direct task'));
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('today-screen'))),
    );
    container.read(routerProvider).go('/tasks/$id/edit');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-task-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeXenndoApp(tester);
  });

  testWidgets('notification navigation preserves an existing unsaved editor', (
    tester,
  ) async {
    final db = await openInMemoryDatabase();
    addTearDown(db.close);
    final tasks = TaskRepository(db, clock: () => _now);
    final first = await tasks.createTask(const TaskDraft(title: 'First draft'));
    final second = await tasks.createTask(
      const TaskDraft(title: 'Second task'),
    );
    final scheduler = FakeReminderScheduler()..initialTaskId = first;
    await pumpXenndoAppLive(
      tester,
      now: _now,
      database: db,
      reminderScheduler: scheduler,
    );
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Keep unsaved text',
    );
    scheduler.simulateTap(second);
    await tester.pumpAndSettle();
    expect(find.text('Second task'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Keep unsaved text'), findsOneWidget);
    expect((await tasks.getTask(first))!.title, 'First draft');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
    await disposeXenndoApp(tester);
  });

  testWidgets(
    'deleting a reminder task waits safely for platform cancellation and keeps Undo',
    (tester) async {
      final db = await openInMemoryDatabase();
      addTearDown(db.close);
      final scheduler = _DelayedScheduler();
      final tasks = TaskRepository(
        db,
        clock: () => _now,
        reminderScheduler: scheduler,
      );
      final id = await tasks.createTask(_reminder('Delayed delete'));
      scheduler.initialTaskId = id;
      await pumpXenndoAppLive(
        tester,
        now: _now,
        database: db,
        reminderScheduler: scheduler,
      );
      scheduler.delay = true;
      await tester.tap(find.byKey(const ValueKey('delete-task-action')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(await tasks.getTask(id), isNull);
      expect(find.byKey(const ValueKey('task-editor-screen')), findsOneWidget);
      scheduler.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(await tasks.getTask(id), isNotNull);
      expect(tester.takeException(), isNull);
      await disposeXenndoApp(tester);
    },
  );

  testWidgets('a deleted notification target has an accessible way back', (
    tester,
  ) async {
    final scheduler = FakeReminderScheduler()..initialTaskId = 'missing-task';
    await pumpXenndoAppLive(tester, now: _now, reminderScheduler: scheduler);
    expect(find.text('Task not found'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
    await disposeXenndoApp(tester);
  });

  testWidgets('row-menu deletion keeps Undo alive after the row disappears', (
    tester,
  ) async {
    final db = await pumpXenndoAppLive(tester, now: _now);
    final tasks = TaskRepository(db, clock: () => _now);
    final id = await tasks.createTask(
      TaskDraft(title: 'Row Undo', dueDate: _today),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Task options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete task'));
    await tester.pumpAndSettle();
    expect(await tasks.getTask(id), isNull);
    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await tasks.getTask(id))!.title, 'Row Undo');
    expect(tester.takeException(), isNull);
    await disposeXenndoApp(tester);
  });

  testWidgets('history groups local days and allows reopening', (tester) async {
    final db = await pumpXenndoAppLive(tester, now: _now);
    final tasks = TaskRepository(db, clock: () => _now);
    final id = await tasks.createTask(
      const TaskDraft(title: 'Yesterday finished'),
    );
    await tasks.setTaskCompleted(
      id,
      true,
      completedAt: _now.subtract(const Duration(days: 1)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('progress-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('completion-history-action')));
    await tester.pumpAndSettle();
    expect(find.text('Yesterday finished'), findsOneWidget);
    final row = find.byKey(ValueKey('history-$id'));
    await tester.tap(find.descendant(of: row, matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
    expect((await tasks.getTask(id))!.completedAt, isNull);
    expect(find.text('No completed tasks'), findsOneWidget);
    await disposeXenndoApp(tester);
  });

  testWidgets('replace-all preview and failure result scroll at 200 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    const summary = BackupSummary(
      lists: 12,
      tasks: 5000,
      completedTasks: 200,
      subtasks: 900,
      focusEntries: 10,
      themeMode: 'system',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => confirmBackupRestore(context, summary),
                  child: const Text('Preview'),
                ),
                TextButton(
                  onPressed: () => showRestoreResult(
                    context,
                    summary: summary,
                    warning: 'Reminders could not be scheduled.',
                  ),
                  child: const Text('Result'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Result'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Future reminders were rescheduled'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Today and Upcoming build a bounded number of rows with 5000 tasks',
    (tester) async {
      final db = await openInMemoryDatabase();
      addTearDown(db.close);
      await db.batch(
        (batch) => batch.insertAll(db.tasks, [
          for (var i = 0; i < 5000; i++)
            TasksCompanion.insert(
              id: 'stress-$i',
              title: 'Stress task $i',
              listId: const drift.Value('inbox'),
              dueDate: drift.Value(
                i < 2000
                    ? _today
                    : i < 4500
                    ? _today.addDays(1)
                    : _today.addDays(2),
              ),
              createdAt: _now.toUtc(),
              updatedAt: _now.toUtc(),
            ),
        ]),
      );
      await pumpXenndoAppLive(tester, now: _now, database: db);
      expect(find.byType(PersistedTaskRow).evaluate().length, lessThan(50));
      await tester.tap(find.byKey(const ValueKey('nav-upcoming')));
      await tester.pumpAndSettle();
      expect(find.byType(PersistedTaskRow).evaluate().length, lessThan(50));
      expect(tester.takeException(), isNull);
      await disposeXenndoApp(tester);
    },
  );
}
