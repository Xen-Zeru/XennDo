import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/core/database/inbox_defaults.dart';
import 'package:xenndo/features/backup/domain/backup_document.dart';
import 'package:xenndo/features/settings/data/settings_repository.dart';

/// Reads and writes the backup payload.
///
/// Every read captures the whole user data set, and every write happens inside
/// a single transaction so a failed restore leaves the previous data intact.
class BackupRepository {
  BackupRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid = const Uuid();

  /// Reads every row a backup owns. Notification ids are left out on purpose:
  /// they are assigned by the platform and mean nothing on another device.
  Future<BackupDocument> exportAll() => _db.transaction(() async {
    final lists = await _db.select(_db.taskLists).get();
    final tasks = await _db.select(_db.tasks).get();
    final subtasks = await _db.select(_db.subtasks).get();
    final focus = await _db.select(_db.dailyFocusEntries).get();
    final settings = await _db.select(_db.settings).get();

    return BackupDocument(
      version: BackupFormat.currentVersion,
      schemaVersion: AppDatabase.currentSchemaVersion,
      exportedAt: _clock().toUtc(),
      lists: [
        for (final list in lists)
          BackupList(
            id: list.id,
            name: list.name,
            color: list.color,
            icon: list.icon,
            sortOrder: list.sortOrder,
            isInbox: list.isInbox,
            createdAt: list.createdAt,
            updatedAt: list.updatedAt,
          ),
      ],
      tasks: [
        for (final task in tasks)
          BackupTask(
            id: task.id,
            title: task.title,
            sortOrder: task.sortOrder,
            description: task.description,
            listId: task.listId ?? lists.firstWhere((list) => list.isInbox).id,
            priority: task.priority,
            dueDate: task.dueDate,
            dueTimeMinutes: task.dueTimeMinutes,
            isCompleted: task.isCompleted,
            completedAt: task.completedAt,
            createdAt: task.createdAt,
            updatedAt: task.updatedAt,
            reminderDate: task.reminderDate,
            reminderTimeMinutes: task.reminderTimeMinutes,
            reminderAt: task.reminderAt,
          ),
      ],
      subtasks: [
        for (final subtask in subtasks)
          BackupSubtask(
            id: subtask.id,
            taskId: subtask.parentTaskId,
            title: subtask.title,
            isCompleted: subtask.isCompleted,
            sortOrder: subtask.sortOrder,
            createdAt: subtask.createdAt,
            updatedAt: subtask.updatedAt,
          ),
      ],
      focusEntries: [
        for (final entry in focus)
          BackupFocusEntry(
            date: entry.focusDate,
            taskId: entry.taskId,
            sortOrder: entry.sortOrder,
          ),
      ],
      settings: {
        for (final row in settings)
          if (SettingsKeys.exportableKeys.contains(row.key)) row.key: row.value,
      },
    );
  });

  /// Replaces the entire data set with [document].
  ///
  /// Deletion and insertion share one transaction: if any write fails, Drift
  /// rolls the whole thing back and the previous data stays exactly as it was.
  /// Callers must have validated [document] with [BackupDocument.decode] first.
  Future<void> restore(BackupDocument document) async {
    await _db.transaction(() async {
      await _db.delete(_db.dailyFocusEntries).go();
      await _db.delete(_db.subtasks).go();
      await _db.delete(_db.tasks).go();
      await _db.delete(_db.taskLists).go();
      await _db.delete(_db.settings).go();

      for (final list in document.lists) {
        await _db.into(_db.taskLists).insert(list.toCompanion());
      }
      await _ensureInbox(document);

      final inbox = await (_db.select(
        _db.taskLists,
      )..where((list) => list.isInbox.equals(true))).getSingle();
      final usedNotificationIds = <int>{};
      for (final task in document.tasks) {
        await _db
            .into(_db.tasks)
            .insert(
              task.toCompanion(
                fallbackListId: inbox.id,
                notificationId: task.hasReminder
                    ? _freshNotificationId(usedNotificationIds)
                    : null,
              ),
            );
      }
      for (final subtask in document.subtasks) {
        await _db.into(_db.subtasks).insert(subtask.toCompanion());
      }
      for (final entry in document.focusEntries) {
        await _db.into(_db.dailyFocusEntries).insert(entry.toCompanion());
      }

      final now = _clock().toUtc();
      for (final entry in document.settings.entries) {
        await _db
            .into(_db.settings)
            .insertOnConflictUpdate(
              Setting(key: entry.key, value: entry.value, updatedAt: now),
            );
      }
    });
  }

  /// Keeps Inbox present even for a hand-written backup that has no inbox row.
  Future<void> _ensureInbox(BackupDocument document) async {
    final hasInbox = document.lists.any(
      (list) => list.isInbox || list.id == InboxDefaults.id,
    );
    if (hasInbox) {
      return;
    }
    final now = _clock().toUtc();
    await _db
        .into(_db.taskLists)
        .insert(
          TaskListsCompanion.insert(
            id: InboxDefaults.id,
            name: InboxDefaults.name,
            color: InboxDefaults.color,
            icon: const Value(InboxDefaults.icon),
            sortOrder: 0,
            isInbox: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  int _freshNotificationId(Set<int> used) {
    while (true) {
      final hex = _uuid.v4().replaceAll('-', '');
      final id = int.parse(hex.substring(0, 8), radix: 16) & 0x7FFFFFFF;
      if (used.add(id)) {
        return id;
      }
    }
  }
}

extension on BackupList {
  TaskListsCompanion toCompanion() => TaskListsCompanion.insert(
    id: id,
    name: name,
    color: color,
    icon: Value(icon),
    sortOrder: sortOrder,
    isInbox: Value(isInbox),
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension on BackupTask {
  TasksCompanion toCompanion({
    required int? notificationId,
    required String fallbackListId,
  }) {
    return TasksCompanion.insert(
      id: id,
      title: title,
      description: Value(description),
      listId: Value(listId ?? fallbackListId),
      sortOrder: Value(sortOrder),
      priority: Value(priority),
      dueDate: Value(dueDate),
      dueTimeMinutes: Value(dueTimeMinutes),
      isCompleted: Value(isCompleted),
      completedAt: Value(completedAt),
      createdAt: createdAt,
      updatedAt: updatedAt,
      reminderDate: Value(reminderDate),
      reminderTimeMinutes: Value(reminderTimeMinutes),
      reminderAt: Value(reminderAt),
      notificationId: Value(notificationId),
    );
  }
}

extension on BackupSubtask {
  SubtasksCompanion toCompanion() => SubtasksCompanion.insert(
    id: id,
    parentTaskId: taskId,
    title: title,
    isCompleted: Value(isCompleted),
    sortOrder: sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

extension on BackupFocusEntry {
  DailyFocusEntriesCompanion toCompanion() => DailyFocusEntriesCompanion.insert(
    focusDate: date,
    taskId: taskId,
    sortOrder: sortOrder,
  );
}
