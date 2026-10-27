import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/core/database/inbox_defaults.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/core/time/task_timing.dart';
import 'package:xenndo/features/tasks/data/task_mapping.dart';
import 'package:xenndo/features/tasks/domain/subtask_draft.dart';
import 'package:xenndo/features/tasks/domain/subtask_item.dart';
import 'package:xenndo/features/tasks/domain/task_deletion_snapshot.dart';
import 'package:xenndo/features/tasks/domain/task_draft.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';
import 'package:xenndo/features/tasks/domain/task_filter.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/today/domain/focus_selection.dart';
import 'package:xenndo/features/today/domain/today_agenda.dart';

class TaskRepository {
  TaskRepository(
    this._db, {
    DateTime Function()? clock,
    ReminderScheduler? reminderScheduler,
    this.onNotice,
  }) : _clock = clock ?? DateTime.now,
       // ignore: prefer_initializing_formals
       _reminderScheduler = reminderScheduler;

  final void Function(String message)? onNotice;
  final AppDatabase _db;
  final DateTime Function() _clock;
  final ReminderScheduler? _reminderScheduler;
  final Uuid _uuid = const Uuid();

  /// One aggregate stream shared by every visible task row, avoiding a query
  /// and a subtask-list subscription for each task.
  Stream<Map<String, ({int completed, int total})>> watchSubtaskProgress() {
    return _db
        .customSelect(
          'SELECT parent_task_id, COUNT(*) AS total, '
          'SUM(is_completed) AS completed FROM subtasks GROUP BY parent_task_id',
          readsFrom: {_db.subtasks},
        )
        .watch()
        .map(
          (rows) => {
            for (final row in rows)
              row.read<String>('parent_task_id'): (
                completed: row.read<int>('completed'),
                total: row.read<int>('total'),
              ),
          },
        );
  }

  Stream<TodayAgenda> watchToday({required LocalDate today}) {
    final dayStartUtc = today.toLocalDateTime().toUtc();
    final nextDayStartUtc = today.addDays(1).toLocalDateTime().toUtc();
    final dueDateEpochDay = _db.tasks.dueDate.dartCast<int>();
    final completedAtMillis = _db.tasks.completedAt.dartCast<int>();

    final query = _db.select(_db.tasks).join([
      leftOuterJoin(
        _db.taskLists,
        _db.taskLists.id.equalsExp(_db.tasks.listId),
      ),
    ]);
    query.where(
      (_db.tasks.isCompleted.equals(false) &
              _db.tasks.dueDate.isNotNull() &
              dueDateEpochDay.isSmallerOrEqualValue(today.epochDay)) |
          (_db.tasks.isCompleted.equals(true) &
              _db.tasks.completedAt.isNotNull() &
              completedAtMillis.isBiggerOrEqualValue(
                dayStartUtc.millisecondsSinceEpoch,
              ) &
              completedAtMillis.isSmallerThanValue(
                nextDayStartUtc.millisecondsSinceEpoch,
              )),
    );

    return query.watch().map((rows) {
      final tasks = rows.map(_taskFromRow).toList(growable: false);
      final openTasks = tasks.where((task) => !task.isCompleted).toList()
        ..sort(_compareOpenTasks);
      final completedTasks = tasks.where((task) => task.isCompleted).toList()
        ..sort(_compareCompletedTasks);

      final overdue = <TaskItem>[];
      final dueToday = <TaskItem>[];
      for (final task in openTasks) {
        final taskDueDate = task.dueDate;
        if (taskDueDate == null) {
          continue;
        }
        if (TaskTiming.isOverdue(
          dueDate: taskDueDate,
          dueTimeMinutes: task.dueTimeMinutes,
          now: _clock(),
        )) {
          overdue.add(task);
        } else {
          dueToday.add(task);
        }
      }

      return TodayAgenda(
        overdue: overdue,
        dueToday: dueToday,
        completedToday: completedTasks,
      );
    });
  }

  Stream<List<TaskItem>> watchUpcoming({required LocalDate after}) {
    final dueDateEpochDay = _db.tasks.dueDate.dartCast<int>();
    final query = _db.select(_db.tasks).join([
      leftOuterJoin(
        _db.taskLists,
        _db.taskLists.id.equalsExp(_db.tasks.listId),
      ),
    ]);
    query.where(
      _db.tasks.isCompleted.equals(false) &
          _db.tasks.dueDate.isNotNull() &
          dueDateEpochDay.isBiggerThanValue(after.epochDay),
    );

    return query.watch().map((rows) {
      final tasks = rows.map(_taskFromRow).toList()..sort(_compareOpenTasks);
      return List<TaskItem>.unmodifiable(tasks);
    });
  }

  /// Tasks completed during the local day [day], newest completion first.
  Stream<List<TaskItem>> watchCompletedOn({required LocalDate day}) {
    return watchCompletedBetween(
      firstDay: day,
      lastDayExclusive: day.addDays(1),
    );
  }

  /// Tasks completed in the local-day window `[firstDay, lastDayExclusive)`.
  ///
  /// The bounds are local midnights converted to UTC, so completions group by
  /// the device's local calendar day.
  Stream<List<TaskItem>> watchCompletedBetween({
    required LocalDate firstDay,
    required LocalDate lastDayExclusive,
  }) {
    final startUtc = firstDay.toLocalDateTime().toUtc();
    final endUtc = lastDayExclusive.toLocalDateTime().toUtc();
    final completedAt = _db.tasks.completedAt.dartCast<int>();

    final query = _db.select(_db.tasks).join([
      leftOuterJoin(
        _db.taskLists,
        _db.taskLists.id.equalsExp(_db.tasks.listId),
      ),
    ]);
    query.where(
      completedAt.isBiggerOrEqualValue(startUtc.millisecondsSinceEpoch) &
          completedAt.isSmallerThanValue(endUtc.millisecondsSinceEpoch),
    );

    return query.watch().map((rows) {
      final tasks = rows.map(_taskFromRow).toList()
        ..sort(_compareCompletedTasks);
      return List<TaskItem>.unmodifiable(tasks);
    });
  }

  /// Tasks whose due date is exactly [day], completed or still open.
  Stream<List<TaskItem>> watchTasksDueOn({required LocalDate day}) {
    final dueDateEpochDay = _db.tasks.dueDate.dartCast<int>();
    final query = _db.select(_db.tasks).join([
      leftOuterJoin(
        _db.taskLists,
        _db.taskLists.id.equalsExp(_db.tasks.listId),
      ),
    ]);
    query.where(dueDateEpochDay.equals(day.epochDay));

    return query.watch().map((rows) {
      final tasks = rows.map(_taskFromRow).toList()..sort(_compareOpenTasks);
      return List<TaskItem>.unmodifiable(tasks);
    });
  }

  Stream<List<TaskItem>> watchTasksForList(String listId) {
    final query = _db.select(_db.tasks).join([
      leftOuterJoin(
        _db.taskLists,
        _db.taskLists.id.equalsExp(_db.tasks.listId),
      ),
    ]);
    query.where(_db.tasks.listId.equals(listId));

    return query.watch().map((rows) {
      final tasks = rows.map(_taskFromRow).toList()..sort(_compareListTasks);
      return List<TaskItem>.unmodifiable(tasks);
    });
  }

  Stream<List<TaskItem>> watchFilteredTasks(TaskFilter filter) {
    final query = _db.select(_db.tasks).join([
      leftOuterJoin(
        _db.taskLists,
        _db.taskLists.id.equalsExp(_db.tasks.listId),
      ),
    ]);

    var predicate = _db.tasks.id.isNotNull();
    final queryText = filter.query.trim();
    if (queryText.isNotEmpty) {
      final pattern = '%${_escapeLike(queryText.toLowerCase())}%';
      predicate =
          predicate &
          (_db.tasks.title.lower().like(pattern, escapeChar: r'\') |
              _db.tasks.description.dartCast<String>().lower().like(
                pattern,
                escapeChar: r'\',
              ));
    }
    final listId = filter.listId;
    if (listId != null) {
      predicate = predicate & _db.tasks.listId.equals(listId);
    }
    final priority = filter.priority;
    if (priority != null) {
      predicate = predicate & _db.tasks.priority.equals(priority.rank);
    }
    switch (filter.completion) {
      case TaskCompletionFilter.incomplete:
        predicate = predicate & _db.tasks.isCompleted.equals(false);
      case TaskCompletionFilter.completed:
        predicate = predicate & _db.tasks.isCompleted.equals(true);
      case TaskCompletionFilter.all:
        break;
    }
    if (filter.dueFrom != null) {
      predicate =
          predicate &
          _db.tasks.dueDate.dartCast<int>().isBiggerOrEqualValue(
            filter.dueFrom!.epochDay,
          );
    }
    if (filter.dueThrough != null) {
      predicate =
          predicate &
          _db.tasks.dueDate.dartCast<int>().isSmallerOrEqualValue(
            filter.dueThrough!.epochDay,
          );
    }
    query.where(predicate);

    return query.watch().map((rows) {
      final tasks = rows.map(_taskFromRow).toList()
        ..sort(_compareFilteredTasks);
      return List<TaskItem>.unmodifiable(tasks);
    });
  }

  Stream<List<TaskItem>> watchAllIncomplete() {
    return watchFilteredTasks(
      const TaskFilter(completion: TaskCompletionFilter.incomplete),
    );
  }

  Stream<TaskItem?> watchTask(String taskId) {
    final query = _db.select(_db.tasks).join([
      leftOuterJoin(
        _db.taskLists,
        _db.taskLists.id.equalsExp(_db.tasks.listId),
      ),
    ]);
    query.where(_db.tasks.id.equals(taskId));

    return query.watchSingleOrNull().map((row) {
      return row == null ? null : _taskFromRow(row);
    });
  }

  Future<TaskItem?> getTask(String taskId) async {
    final query = _db.select(_db.tasks).join([
      leftOuterJoin(
        _db.taskLists,
        _db.taskLists.id.equalsExp(_db.tasks.listId),
      ),
    ]);
    query.where(_db.tasks.id.equals(taskId));
    final row = await query.getSingleOrNull();
    return row == null ? null : _taskFromRow(row);
  }

  Future<List<TaskItem>> getTasksForList(String listId) async {
    final query = _db.select(_db.tasks).join([
      leftOuterJoin(
        _db.taskLists,
        _db.taskLists.id.equalsExp(_db.tasks.listId),
      ),
    ]);
    query.where(_db.tasks.listId.equals(listId));
    final rows = await query.get();
    final tasks = rows.map(_taskFromRow).toList()..sort(_compareListTasks);
    return tasks;
  }

  Future<String> createTask(TaskDraft draft) async {
    _validateDraft(draft);

    final id = await _db.transaction(() async {
      final listId = await _resolveListId(draft.listId);
      final order = await _nextTaskOrder(listId);
      final taskId = _uuid.v4();
      final now = _clock().toUtc();
      final reminder = await _prepareReminder(
        draft: draft,
        existingNotificationId: null,
      );

      await _db
          .into(_db.tasks)
          .insert(
            TasksCompanion.insert(
              id: taskId,
              sortOrder: Value(order),
              title: draft.title.trim(),
              description: Value(_nullableTrimmed(draft.description)),
              listId: Value(listId),
              priority: Value(draft.priority.rank),
              dueDate: Value(draft.dueDate),
              dueTimeMinutes: Value(draft.dueTimeMinutes),
              createdAt: now,
              updatedAt: now,
              reminderAt: Value(reminder.instant),
              reminderDate: Value(reminder.date),
              reminderTimeMinutes: Value(reminder.timeMinutes),
              reminderOffsetMinutes: const Value(null),
              notificationId: Value(reminder.notificationId),
            ),
          );

      final subtasks = _normalizedSubtasks(draft.subtasks);
      for (var index = 0; index < subtasks.length; index++) {
        final subtask = subtasks[index];
        await _db
            .into(_db.subtasks)
            .insert(
              SubtasksCompanion.insert(
                id: subtask.id ?? _uuid.v4(),
                parentTaskId: taskId,
                title: subtask.title,
                isCompleted: Value(subtask.isCompleted),
                sortOrder: index,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      return taskId;
    });

    await _attemptReminderUpdate(() => _syncReminder(id));
    return id;
  }

  Future<void> updateTask(String taskId, TaskDraft draft) async {
    _validateDraft(draft);

    int? previousNotificationId;
    await _db.transaction(() async {
      final existing = await (_db.select(
        _db.tasks,
      )..where((task) => task.id.equals(taskId))).getSingleOrNull();
      if (existing == null) {
        throw StateError('Task $taskId does not exist.');
      }

      previousNotificationId = existing.notificationId;
      final listId = await _resolveListId(draft.listId);
      final reminder = await _prepareReminder(
        draft: draft,
        existingNotificationId: existing.notificationId,
      );
      final now = _clock().toUtc();

      await (_db.update(
        _db.tasks,
      )..where((task) => task.id.equals(taskId))).write(
        TasksCompanion(
          sortOrder: Value(
            existing.listId == listId
                ? existing.sortOrder
                : await _nextTaskOrder(listId),
          ),
          title: Value(draft.title.trim()),
          description: Value(_nullableTrimmed(draft.description)),
          listId: Value(listId),
          priority: Value(draft.priority.rank),
          dueDate: Value(draft.dueDate),
          dueTimeMinutes: Value(draft.dueTimeMinutes),
          updatedAt: Value(now),
          reminderAt: Value(reminder.instant),
          reminderDate: Value(reminder.date),
          reminderTimeMinutes: Value(reminder.timeMinutes),
          reminderOffsetMinutes: const Value(null),
          notificationId: Value(reminder.notificationId),
        ),
      );

      await _reconcileSubtasks(taskId, draft.subtasks, now);
    });

    await _attemptReminderUpdate(
      () =>
          _syncReminder(taskId, previousNotificationId: previousNotificationId),
    );
  }

  Future<void> _reconcileSubtasks(
    String taskId,
    List<SubtaskDraft> drafts,
    DateTime now,
  ) async {
    final existing = await getSubtasks(taskId);
    final existingIds = existing.map((subtask) => subtask.id).toSet();
    final retainedIds = <String>{};
    final normalized = _normalizedSubtasks(drafts);

    for (var index = 0; index < normalized.length; index++) {
      final draft = normalized[index];
      final existingId = draft.id;
      if (existingId != null && existingIds.contains(existingId)) {
        retainedIds.add(existingId);
        await (_db.update(
          _db.subtasks,
        )..where((subtask) => subtask.id.equals(existingId))).write(
          SubtasksCompanion(
            title: Value(draft.title),
            isCompleted: Value(draft.isCompleted),
            sortOrder: Value(index),
            updatedAt: Value(now),
          ),
        );
      } else {
        final newId = _uuid.v4();
        retainedIds.add(newId);
        await _db
            .into(_db.subtasks)
            .insert(
              SubtasksCompanion.insert(
                id: newId,
                parentTaskId: taskId,
                title: draft.title,
                isCompleted: Value(draft.isCompleted),
                sortOrder: index,
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
    }

    for (final subtask in existing) {
      if (!retainedIds.contains(subtask.id)) {
        await (_db.delete(
          _db.subtasks,
        )..where((row) => row.id.equals(subtask.id))).go();
      }
    }
  }

  Future<void> setTaskCompleted(
    String taskId,
    bool isCompleted, {
    DateTime? completedAt,
  }) async {
    var focusRemoved = false;
    await _db.transaction(() async {
      final existing = await getTask(taskId);
      if (existing == null) throw StateError('Task $taskId does not exist.');
      if (existing.isCompleted == isCompleted) return;
      if (!isCompleted) {
        final dates = await (_db.select(
          _db.dailyFocusEntries,
        )..where((row) => row.taskId.equals(taskId))).get();
        for (final entry in dates) {
          final active = await _activeFocusCount(entry.focusDate);
          if (active >= 3) {
            focusRemoved = true;
            await (_db.delete(_db.dailyFocusEntries)..where(
                  (row) =>
                      row.taskId.equals(taskId) &
                      row.focusDate.equalsValue(entry.focusDate),
                ))
                .go();
          }
        }
      }
      final now = (completedAt ?? _clock()).toUtc();
      await (_db.update(
        _db.tasks,
      )..where((task) => task.id.equals(taskId))).write(
        TasksCompanion(
          isCompleted: Value(isCompleted),
          completedAt: Value(isCompleted ? now : null),
          updatedAt: Value(now),
        ),
      );
    });
    if (focusRemoved) {
      onNotice?.call(
        'Task reopened in its list. My Top 3 already has three active tasks, so this task left the focus selection.',
      );
    }
    await _attemptReminderUpdate(() => _syncReminder(taskId));
  }

  Future<void> deleteTask(String taskId) async {
    await deleteTaskWithSnapshot(taskId);
  }

  /// Deletes a task and returns everything needed to undo the deletion.
  Future<TaskDeletionSnapshot> deleteTaskWithSnapshot(String taskId) async {
    final snapshot = await _db.transaction(() async {
      final row = await _taskRowQuery(taskId).getSingleOrNull();
      if (row == null) {
        throw StateError('Task $taskId does not exist.');
      }

      final task = _taskFromRow(row);
      final subtasks = await getSubtasks(taskId);
      final focusRows = await (_db.select(
        _db.dailyFocusEntries,
      )..where((focus) => focus.taskId.equals(taskId))).get();
      final focusSelections = focusRows
          .map(
            (focus) => FocusSelection(
              focusDate: focus.focusDate,
              taskId: focus.taskId,
              sortOrder: focus.sortOrder,
            ),
          )
          .toList(growable: false);

      await (_db.delete(
        _db.dailyFocusEntries,
      )..where((focus) => focus.taskId.equals(taskId))).go();
      await (_db.delete(
        _db.subtasks,
      )..where((subtask) => subtask.parentTaskId.equals(taskId))).go();
      await (_db.delete(
        _db.tasks,
      )..where((task) => task.id.equals(taskId))).go();

      return TaskDeletionSnapshot(
        task: task,
        subtasks: subtasks,
        focusSelections: focusSelections,
      );
    });

    final notificationId = snapshot.task.notificationId;
    if (notificationId != null) {
      await _attemptReminderUpdate(() async {
        await _reminderScheduler?.cancel(notificationId);
      });
    }
    return snapshot;
  }

  /// Restores a task deleted through [deleteTaskWithSnapshot].
  Future<void> restoreTask(TaskDeletionSnapshot snapshot) async {
    await _db.transaction(() async {
      final task = snapshot.task;
      final alreadyExists = await (_db.select(
        _db.tasks,
      )..where((row) => row.id.equals(task.id))).getSingleOrNull();
      if (alreadyExists != null) {
        return;
      }

      final listId = await _resolveListIdForRestore(task.listId);
      await _db
          .into(_db.tasks)
          .insert(
            TasksCompanion.insert(
              id: task.id,
              sortOrder: Value(task.sortOrder),
              title: task.title,
              description: Value(task.description),
              listId: Value(listId),
              priority: Value(task.priority.rank),
              dueDate: Value(task.dueDate),
              dueTimeMinutes: Value(task.dueTimeMinutes),
              isCompleted: Value(task.isCompleted),
              completedAt: Value(task.completedAt),
              createdAt: task.createdAt,
              updatedAt: _clock().toUtc(),
              reminderAt: Value(task.reminderAt),
              reminderDate: Value(task.reminderDate),
              reminderTimeMinutes: Value(task.reminderTimeMinutes),
              reminderOffsetMinutes: const Value(null),
              notificationId: Value(task.notificationId),
            ),
          );

      for (final subtask in snapshot.subtasks) {
        await _db
            .into(_db.subtasks)
            .insert(
              SubtasksCompanion.insert(
                id: subtask.id,
                parentTaskId: task.id,
                title: subtask.title,
                isCompleted: Value(subtask.isCompleted),
                sortOrder: subtask.sortOrder,
                createdAt: subtask.createdAt,
                updatedAt: subtask.updatedAt,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }

      for (final focus in snapshot.focusSelections) {
        if (!task.isCompleted &&
            await _activeFocusCount(focus.focusDate) >= 3) {
          continue;
        }
        final entries = await (_db.select(
          _db.dailyFocusEntries,
        )..where((row) => row.focusDate.equalsValue(focus.focusDate))).get();
        var order = focus.sortOrder;
        final used = entries.map((row) => row.sortOrder).toSet();
        while (used.contains(order)) {
          order++;
        }
        await _db
            .into(_db.dailyFocusEntries)
            .insert(
              DailyFocusEntriesCompanion.insert(
                focusDate: focus.focusDate,
                taskId: task.id,
                sortOrder: order,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    });

    await _attemptReminderUpdate(() => _syncReminder(snapshot.task.id));
  }

  Future<List<SubtaskItem>> getSubtasks(String taskId) async {
    final query = _db.select(_db.subtasks)
      ..where((subtask) => subtask.parentTaskId.equals(taskId))
      ..orderBy([(subtask) => OrderingTerm.asc(subtask.sortOrder)]);
    final rows = await query.get();
    return rows.map(_mapSubtask).toList(growable: false);
  }

  Stream<List<SubtaskItem>> watchSubtasks(String taskId) {
    final query = _db.select(_db.subtasks)
      ..where((subtask) => subtask.parentTaskId.equals(taskId))
      ..orderBy([(subtask) => OrderingTerm.asc(subtask.sortOrder)]);
    return query.watch().map(
      (rows) => rows.map(_mapSubtask).toList(growable: false),
    );
  }

  Future<String> addSubtask(String taskId, String title) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'Subtask title cannot be blank.',
      );
    }

    return _db.transaction(() async {
      final parent = await (_db.select(
        _db.tasks,
      )..where((task) => task.id.equals(taskId))).getSingleOrNull();
      if (parent == null) {
        throw StateError('Task $taskId does not exist.');
      }

      final maxOrder = _db.subtasks.sortOrder.max();
      final maxQuery = _db.selectOnly(_db.subtasks)
        ..addColumns([maxOrder])
        ..where(_db.subtasks.parentTaskId.equals(taskId));
      final maxRow = await maxQuery.getSingle();
      final now = _clock().toUtc();
      final id = _uuid.v4();

      await _db
          .into(_db.subtasks)
          .insert(
            SubtasksCompanion.insert(
              id: id,
              parentTaskId: taskId,
              title: trimmedTitle,
              sortOrder: (maxRow.read(maxOrder) ?? -1) + 1,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    });
  }

  Future<void> setSubtaskCompleted(String subtaskId, bool isCompleted) async {
    final changed =
        await (_db.update(
          _db.subtasks,
        )..where((subtask) => subtask.id.equals(subtaskId))).write(
          SubtasksCompanion(
            isCompleted: Value(isCompleted),
            updatedAt: Value(_clock().toUtc()),
          ),
        );
    if (changed == 0) {
      throw StateError('Subtask $subtaskId does not exist.');
    }
  }

  Future<void> deleteSubtask(String subtaskId) async {
    await (_db.delete(
      _db.subtasks,
    )..where((subtask) => subtask.id.equals(subtaskId))).go();
  }

  void _validateDraft(TaskDraft draft) {
    if (draft.title.trim().isEmpty) {
      throw ArgumentError.value(
        draft.title,
        'title',
        'Task title cannot be blank.',
      );
    }
    if (draft.dueDate == null && draft.dueTimeMinutes != null) {
      throw ArgumentError('A due time requires a due date.');
    }
    if (draft.reminderEnabled &&
        (draft.reminderDate == null || draft.reminderTimeMinutes == null)) {
      throw ArgumentError(
        'A reminder requires both a reminder date and reminder time.',
      );
    }
    final dueTime = draft.dueTimeMinutes;
    if (dueTime != null && (dueTime < 0 || dueTime >= Duration.minutesPerDay)) {
      throw ArgumentError.value(
        dueTime,
        'dueTimeMinutes',
        'Must be between 0 and 1439.',
      );
    }
    final reminderTime = draft.reminderTimeMinutes;
    if (reminderTime != null &&
        (reminderTime < 0 || reminderTime >= Duration.minutesPerDay)) {
      throw ArgumentError.value(
        reminderTime,
        'reminderTimeMinutes',
        'Must be between 0 and 1439.',
      );
    }
  }

  Future<String> _resolveListId(String? requestedListId) async {
    final listId = requestedListId == null || requestedListId.trim().isEmpty
        ? InboxDefaults.id
        : requestedListId;
    final list = await (_db.select(
      _db.taskLists,
    )..where((row) => row.id.equals(listId))).getSingleOrNull();
    if (list == null) {
      throw ArgumentError.value(
        requestedListId,
        'listId',
        'List does not exist.',
      );
    }
    return listId;
  }

  Future<String> _resolveListIdForRestore(String? requestedListId) async {
    if (requestedListId == null || requestedListId.trim().isEmpty) {
      return InboxDefaults.id;
    }
    final list = await (_db.select(
      _db.taskLists,
    )..where((row) => row.id.equals(requestedListId))).getSingleOrNull();
    return list == null ? InboxDefaults.id : requestedListId;
  }

  List<SubtaskDraft> _normalizedSubtasks(List<SubtaskDraft> subtasks) {
    return subtasks
        .map(
          (subtask) => SubtaskDraft(
            id: subtask.id,
            title: subtask.title.trim(),
            isCompleted: subtask.isCompleted,
          ),
        )
        .where((subtask) => subtask.title.isNotEmpty)
        .toList(growable: false);
  }

  JoinedSelectStatement<HasResultSet, dynamic> _taskRowQuery(String taskId) {
    final query = _db.select(_db.tasks).join([
      leftOuterJoin(
        _db.taskLists,
        _db.taskLists.id.equalsExp(_db.tasks.listId),
      ),
    ]);
    query.where(_db.tasks.id.equals(taskId));
    return query;
  }

  Future<_PreparedReminder> _prepareReminder({
    required TaskDraft draft,
    required int? existingNotificationId,
  }) async {
    if (!draft.reminderEnabled) {
      return const _PreparedReminder();
    }
    final reminderDate = draft.reminderDate;
    final reminderTime = draft.reminderTimeMinutes;
    if (reminderDate == null || reminderTime == null) {
      throw ArgumentError(
        'A reminder requires both a reminder date and reminder time.',
      );
    }

    var notificationId = existingNotificationId;
    while (notificationId == null) {
      final candidate = _notificationIdFor(_uuid.v4());
      final match =
          await (_db.select(_db.tasks)
                ..where((row) => row.notificationId.equals(candidate)))
              .getSingleOrNull();
      if (match == null) notificationId = candidate;
    }
    return _PreparedReminder(
      instant: TaskTiming.resolveLocalReminderInstant(
        reminderDate: reminderDate,
        reminderTimeMinutes: reminderTime,
      ),
      date: reminderDate,
      timeMinutes: reminderTime,
      notificationId: notificationId,
    );
  }

  /// Returns incomplete tasks that have reminder metadata.
  Future<List<TaskItem>> getSchedulableReminders() async {
    final query = _db.select(_db.tasks).join([
      leftOuterJoin(
        _db.taskLists,
        _db.taskLists.id.equalsExp(_db.tasks.listId),
      ),
    ]);
    query.where(
      _db.tasks.isCompleted.equals(false) &
          (_db.tasks.reminderDate.isNotNull() |
              _db.tasks.reminderAt.isNotNull()),
    );
    final rows = await query.get();
    return rows.map(_taskFromRow).toList(growable: false);
  }

  DateTime? reminderInstantFor(TaskItem task) {
    final date = task.reminderDate;
    final time = task.reminderTimeMinutes;
    if (date != null && time != null) {
      return TaskTiming.resolveLocalReminderInstant(
        reminderDate: date,
        reminderTimeMinutes: time,
      );
    }
    return task.reminderAt;
  }

  Future<void> _reminderQueue = Future<void>.value();

  /// Serialize platform operations and read the latest committed task state.
  Future<void> synchronizeReminders(Future<void> Function() action) {
    final result = _reminderQueue.then((_) => action());
    _reminderQueue = result.catchError((Object _) {});
    return result;
  }

  Future<void> _attemptReminderUpdate(Future<void> Function() action) async {
    try {
      await synchronizeReminders(action);
    } catch (_) {
      // The database commit succeeded. Retrying the save would duplicate data.
      onNotice?.call(
        'Task changes saved. Android reminders could not be updated. Check notification settings and reopen the app to retry.',
      );
    }
  }

  Future<void> _syncReminder(
    String taskId, {
    int? previousNotificationId,
  }) async {
    final scheduler = _reminderScheduler;
    if (scheduler == null) {
      return;
    }

    final task = await getTask(taskId);
    final notificationId = task?.notificationId;
    if (previousNotificationId != null &&
        previousNotificationId != notificationId) {
      await scheduler.cancel(previousNotificationId);
    }
    if (task == null || notificationId == null) {
      return;
    }

    await scheduler.cancel(notificationId);
    if (task.isCompleted) {
      return;
    }

    final when = reminderInstantFor(task);
    if (when == null || !when.isAfter(_clock())) {
      return;
    }

    if (await scheduler.checkPermission() != ReminderPermissionStatus.granted) {
      onNotice?.call(
        'Task saved. Its reminder is not scheduled because notifications are off. Enable them in Settings.',
      );
      return;
    }
    await scheduler.schedule(
      notificationId: notificationId,
      taskId: task.id,
      title: task.title,
      body: task.description,
      when: when,
    );
  }

  int _notificationIdFor(String uuid) {
    final hex = uuid.replaceAll('-', '');
    return int.parse(hex.substring(0, 8), radix: 16) & 0x7FFFFFFF;
  }

  String? _nullableTrimmed(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  TaskItem _taskFromRow(TypedResult row) {
    final task = row.readTable(_db.tasks);
    final list = row.readTableOrNull(_db.taskLists);
    return mapTaskRow(task, list: list);
  }

  SubtaskItem _mapSubtask(Subtask subtask) {
    return SubtaskItem(
      id: subtask.id,
      parentTaskId: subtask.parentTaskId,
      title: subtask.title,
      isCompleted: subtask.isCompleted,
      sortOrder: subtask.sortOrder,
      createdAt: subtask.createdAt,
      updatedAt: subtask.updatedAt,
    );
  }

  String _escapeLike(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
  }

  int _compareFilteredTasks(TaskItem left, TaskItem right) {
    if (left.isCompleted != right.isCompleted) {
      return left.isCompleted ? 1 : -1;
    }

    final leftDate = left.dueDate;
    final rightDate = right.dueDate;
    if (leftDate == null && rightDate != null) {
      return 1;
    }
    if (leftDate != null && rightDate == null) {
      return -1;
    }
    if (leftDate != null && rightDate != null) {
      final dateComparison = leftDate.compareTo(rightDate);
      if (dateComparison != 0) {
        return dateComparison;
      }
    }

    final leftTime = left.dueTimeMinutes ?? Duration.minutesPerDay;
    final rightTime = right.dueTimeMinutes ?? Duration.minutesPerDay;
    if (leftTime != rightTime) {
      return leftTime.compareTo(rightTime);
    }

    final priorityComparison = right.priority.rank.compareTo(
      left.priority.rank,
    );
    if (priorityComparison != 0) {
      return priorityComparison;
    }

    final titleComparison = left.title.toLowerCase().compareTo(
      right.title.toLowerCase(),
    );
    if (titleComparison != 0) {
      return titleComparison;
    }
    return left.id.compareTo(right.id);
  }

  Future<int> _activeFocusCount(LocalDate date) async {
    final rows = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM daily_focus_entries f JOIN tasks t ON t.id = f.task_id WHERE f.focus_date = ? AND t.is_completed = 0',
          variables: [Variable<int>(date.epochDay)],
          readsFrom: {_db.tasks, _db.dailyFocusEntries},
        )
        .getSingle();
    return rows.read<int>('n');
  }

  Future<int> _nextTaskOrder(String listId) async {
    final max = _db.tasks.sortOrder.max();
    final query = _db.selectOnly(_db.tasks)
      ..addColumns([max])
      ..where(_db.tasks.listId.equals(listId));
    final value = (await query.getSingle()).read(max) ?? 0;
    return value == 0 ? 0 : value + 1;
  }

  Future<void> reorderTasks(String listId, List<String> orderedIds) =>
      _db.transaction(() async {
        final tasks = (await getTasksForList(listId))
            .where((task) => !task.isCompleted)
            .toList();
        if (orderedIds.toSet().length != orderedIds.length ||
            orderedIds.length != tasks.length ||
            tasks.any((task) => !orderedIds.contains(task.id))) {
          throw ArgumentError(
            'Order must contain every open task in this list exactly once.',
          );
        }
        for (var index = 0; index < orderedIds.length; index++) {
          await (_db.update(
            _db.tasks,
          )..where((task) => task.id.equals(orderedIds[index]))).write(
            TasksCompanion(
              sortOrder: Value(index + 1),
              updatedAt: Value(_clock().toUtc()),
            ),
          );
        }
      });

  int _compareListTasks(TaskItem left, TaskItem right) {
    if (left.isCompleted != right.isCompleted) return left.isCompleted ? 1 : -1;
    if (left.isCompleted) return _compareCompletedTasks(left, right);
    if (left.sortOrder != right.sortOrder) {
      return left.sortOrder.compareTo(right.sortOrder);
    }
    final priority = right.priority.rank.compareTo(left.priority.rank);
    if (priority != 0) return priority;
    final fallback = _compareOpenTasks(left, right);
    return fallback != 0 ? fallback : left.id.compareTo(right.id);
  }

  int _compareOpenTasks(TaskItem left, TaskItem right) {
    final leftDate = left.dueDate;
    final rightDate = right.dueDate;
    if (leftDate != null && rightDate != null) {
      final dateComparison = leftDate.compareTo(rightDate);
      if (dateComparison != 0) {
        return dateComparison;
      }
    } else if (leftDate != null) {
      return -1;
    } else if (rightDate != null) {
      return 1;
    }

    final leftTime = left.dueTimeMinutes ?? Duration.minutesPerDay;
    final rightTime = right.dueTimeMinutes ?? Duration.minutesPerDay;
    if (leftTime != rightTime) {
      return leftTime.compareTo(rightTime);
    }

    final priorityComparison = right.priority.rank.compareTo(
      left.priority.rank,
    );
    if (priorityComparison != 0) {
      return priorityComparison;
    }
    return left.createdAt.compareTo(right.createdAt);
  }

  int _compareCompletedTasks(TaskItem left, TaskItem right) {
    final leftCompleted = left.completedAt ?? left.updatedAt;
    final rightCompleted = right.completedAt ?? right.updatedAt;
    return rightCompleted.compareTo(leftCompleted);
  }
}

class _PreparedReminder {
  const _PreparedReminder({
    this.instant,
    this.date,
    this.timeMinutes,
    this.notificationId,
  });

  final DateTime? instant;
  final LocalDate? date;
  final int? timeMinutes;
  final int? notificationId;
}
