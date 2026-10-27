import 'package:drift/drift.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/tasks/data/task_mapping.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/today/domain/focus_exceptions.dart';
import 'package:xenndo/features/today/domain/focus_selection.dart';

class FocusRepository {
  FocusRepository(this._db);

  final AppDatabase _db;

  Stream<List<TaskItem>> watchTopThree(LocalDate date) {
    final query = _db.select(_db.dailyFocusEntries).join([
      innerJoin(
        _db.tasks,
        _db.tasks.id.equalsExp(_db.dailyFocusEntries.taskId),
      ),
      leftOuterJoin(
        _db.taskLists,
        _db.taskLists.id.equalsExp(_db.tasks.listId),
      ),
    ]);
    query.where(_db.dailyFocusEntries.focusDate.equalsValue(date));
    query.orderBy([OrderingTerm.asc(_db.dailyFocusEntries.sortOrder)]);

    return query.watch().map((rows) {
      return rows
          .map((row) {
            return mapTaskRow(
              row.readTable(_db.tasks),
              list: row.readTableOrNull(_db.taskLists),
            );
          })
          .toList(growable: false);
    });
  }

  Future<List<FocusSelection>> getFocusSelections(LocalDate date) async {
    final query = _db.select(_db.dailyFocusEntries)
      ..where((focus) => focus.focusDate.equalsValue(date))
      ..orderBy([(focus) => OrderingTerm.asc(focus.sortOrder)]);
    final rows = await query.get();
    return rows
        .map(
          (row) => FocusSelection(
            focusDate: row.focusDate,
            taskId: row.taskId,
            sortOrder: row.sortOrder,
          ),
        )
        .toList(growable: false);
  }

  Future<void> addToFocus({required LocalDate date, required String taskId}) {
    return _db.transaction(() async {
      final task = await (_db.select(
        _db.tasks,
      )..where((row) => row.id.equals(taskId))).getSingleOrNull();
      if (task == null) {
        throw StateError('Task $taskId does not exist.');
      }
      if (task.isCompleted) {
        throw StateError('Completed tasks cannot be added to My Top 3.');
      }

      final existing =
          await (_db.select(_db.dailyFocusEntries)..where(
                (focus) =>
                    focus.focusDate.equalsValue(date) &
                    focus.taskId.equals(taskId),
              ))
              .getSingleOrNull();
      if (existing != null) {
        throw FocusDuplicateException(taskId);
      }

      final activeCount = await _db
          .customSelect(
            'SELECT COUNT(*) AS n FROM daily_focus_entries f JOIN tasks t ON t.id = f.task_id WHERE f.focus_date = ? AND t.is_completed = 0',
            variables: [Variable<int>(date.epochDay)],
            readsFrom: {_db.tasks, _db.dailyFocusEntries},
          )
          .getSingle();
      if (activeCount.read<int>('n') >= 3) throw const FocusLimitException();
      final rows = await (_db.select(
        _db.dailyFocusEntries,
      )..where((focus) => focus.focusDate.equalsValue(date))).get();
      final nextOrder =
          rows.fold(
            -1,
            (value, row) => row.sortOrder > value ? row.sortOrder : value,
          ) +
          1;

      await _db
          .into(_db.dailyFocusEntries)
          .insert(
            DailyFocusEntriesCompanion.insert(
              focusDate: date,
              taskId: taskId,
              sortOrder: nextOrder,
            ),
          );
    });
  }

  Future<void> removeFromFocus({
    required LocalDate date,
    required String taskId,
  }) async {
    await (_db.delete(_db.dailyFocusEntries)..where(
          (focus) =>
              focus.focusDate.equalsValue(date) & focus.taskId.equals(taskId),
        ))
        .go();
  }

  Future<void> reorderFocus({
    required LocalDate date,
    required List<String> orderedTaskIds,
  }) {
    if (orderedTaskIds.toSet().length != orderedTaskIds.length) {
      throw ArgumentError.value(
        orderedTaskIds,
        'orderedTaskIds',
        'Task IDs must be unique.',
      );
    }

    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.dailyFocusEntries,
      )..where((focus) => focus.focusDate.equalsValue(date))).get();
      final existingIds = existing.map((row) => row.taskId).toSet();
      if (orderedTaskIds.any((taskId) => !existingIds.contains(taskId)) ||
          orderedTaskIds.length != existingIds.length) {
        throw ArgumentError.value(
          orderedTaskIds,
          'orderedTaskIds',
          'Must contain exactly the tasks currently selected for this day.',
        );
      }

      await (_db.delete(
        _db.dailyFocusEntries,
      )..where((focus) => focus.focusDate.equalsValue(date))).go();
      for (var index = 0; index < orderedTaskIds.length; index++) {
        await _db
            .into(_db.dailyFocusEntries)
            .insert(
              DailyFocusEntriesCompanion.insert(
                focusDate: date,
                taskId: orderedTaskIds[index],
                sortOrder: index,
              ),
            );
      }
    });
  }
}
