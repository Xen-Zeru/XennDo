import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/core/database/inbox_defaults.dart';
import 'package:xenndo/features/lists/domain/task_list_model.dart';

class ListRepository {
  ListRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;
  final Uuid _uuid = const Uuid();

  Stream<List<TaskListSummary>> watchListsWithOpenCounts() {
    final openTaskCount = _db.tasks.id.count(
      filter: _db.tasks.isCompleted.equals(false),
    );
    final completedTaskCount = _db.tasks.id.count(
      filter: _db.tasks.isCompleted.equals(true),
    );
    final query = _db.select(_db.taskLists).join([
      leftOuterJoin(_db.tasks, _db.tasks.listId.equalsExp(_db.taskLists.id)),
    ]);
    query.addColumns([openTaskCount, completedTaskCount]);
    query.groupBy([_db.taskLists.id]);
    query.orderBy([
      OrderingTerm.desc(_db.taskLists.isInbox),
      OrderingTerm.asc(_db.taskLists.sortOrder),
      OrderingTerm.asc(_db.taskLists.id),
    ]);

    return query.watch().map((rows) {
      return rows
          .map((row) {
            final list = row.readTable(_db.taskLists);
            return TaskListSummary(
              id: list.id,
              name: list.name,
              color: list.color,
              icon: list.icon,
              sortOrder: list.sortOrder,
              isInbox: list.isInbox,
              openTaskCount: row.read(openTaskCount) ?? 0,
              completedTaskCount: row.read(completedTaskCount) ?? 0,
            );
          })
          .toList(growable: false);
    });
  }

  Stream<List<TaskListModel>> watchLists() {
    final query = _db.select(_db.taskLists)
      ..orderBy([
        (table) => OrderingTerm.desc(table.isInbox),
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.id),
      ]);
    return query.watch().map(
      (rows) => rows.map(_mapList).toList(growable: false),
    );
  }

  Future<List<TaskListModel>> getLists() async {
    final query = _db.select(_db.taskLists)
      ..orderBy([
        (table) => OrderingTerm.desc(table.isInbox),
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.asc(table.id),
      ]);
    final rows = await query.get();
    return rows.map(_mapList).toList(growable: false);
  }

  Future<TaskListModel?> getInbox() async {
    final row = await (_db.select(
      _db.taskLists,
    )..where((list) => list.isInbox.equals(true))).getSingleOrNull();
    return row == null ? null : _mapList(row);
  }

  Future<String> createList({
    required String name,
    required int color,
    String? icon,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'List name cannot be blank.');
    }

    return _db.transaction(() async {
      final maxOrder = _db.taskLists.sortOrder.max();
      final maxQuery = _db.selectOnly(_db.taskLists)..addColumns([maxOrder]);
      final maxRow = await maxQuery.getSingle();
      final nextOrder = (maxRow.read(maxOrder) ?? -1) + 1;
      final id = _uuid.v4();
      final now = _clock().toUtc();

      await _db
          .into(_db.taskLists)
          .insert(
            TaskListsCompanion.insert(
              id: id,
              name: trimmedName,
              color: color,
              icon: Value(icon),
              sortOrder: nextOrder,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    });
  }

  Future<void> renameList(String id, String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'List name cannot be blank.');
    }

    await (_db.update(
      _db.taskLists,
    )..where((list) => list.id.equals(id))).write(
      TaskListsCompanion(
        name: Value(trimmedName),
        updatedAt: Value(_clock().toUtc()),
      ),
    );
  }

  Future<void> recolorList(String id, int color) async {
    await (_db.update(
      _db.taskLists,
    )..where((list) => list.id.equals(id))).write(
      TaskListsCompanion(
        color: Value(color),
        updatedAt: Value(_clock().toUtc()),
      ),
    );
  }

  Future<void> reorderLists(List<String> orderedIds) async {
    if (orderedIds.toSet().length != orderedIds.length) {
      throw ArgumentError.value(
        orderedIds,
        'orderedIds',
        'List IDs must be unique.',
      );
    }

    await _db.transaction(() async {
      final existing = await getLists();
      if (existing.length != orderedIds.length ||
          existing.any((list) => !orderedIds.contains(list.id)) ||
          (existing.any((list) => list.isInbox) &&
              orderedIds.first !=
                  existing.firstWhere((list) => list.isInbox).id)) {
        throw ArgumentError(
          'Order must contain every list once, with Inbox first.',
        );
      }
      final now = _clock().toUtc();
      for (var index = 0; index < orderedIds.length; index++) {
        await (_db.update(
          _db.taskLists,
        )..where((list) => list.id.equals(orderedIds[index]))).write(
          TaskListsCompanion(sortOrder: Value(index), updatedAt: Value(now)),
        );
      }
    });
  }

  Future<void> deleteList(String id) async {
    if (id == InboxDefaults.id) {
      throw StateError('Inbox cannot be deleted.');
    }

    await _db.transaction(() async {
      final list = await (_db.select(
        _db.taskLists,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      if (list == null) {
        return;
      }
      if (list.isInbox) {
        throw StateError('Inbox cannot be deleted.');
      }

      final inbox = await getInbox();
      if (inbox == null) {
        throw StateError('Inbox is missing.');
      }

      final now = _clock().toUtc();
      await (_db.update(
        _db.tasks,
      )..where((task) => task.listId.equals(id))).write(
        TasksCompanion(listId: Value(inbox.id), updatedAt: Value(now)),
      );
      await (_db.delete(_db.taskLists)..where((row) => row.id.equals(id))).go();
    });
  }

  TaskListModel _mapList(TaskList list) {
    return TaskListModel(
      id: list.id,
      name: list.name,
      color: list.color,
      icon: list.icon,
      sortOrder: list.sortOrder,
      isInbox: list.isInbox,
      createdAt: list.createdAt,
      updatedAt: list.updatedAt,
    );
  }
}
