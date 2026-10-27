import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:xenndo/core/database/converters/local_date_converter.dart';
import 'package:xenndo/core/database/converters/utc_date_time_converter.dart';
import 'package:xenndo/core/database/inbox_defaults.dart';
import 'package:xenndo/core/database/tables.dart';
import 'package:xenndo/core/time/local_date.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [TaskLists, Tasks, Subtasks, DailyFocusEntries, Settings],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'xenndo'));

  static const int currentSchemaVersion = 4;

  @override
  int get schemaVersion => currentSchemaVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (migrator) async {
        await migrator.createAll();
        await _seedInbox();
      },
      onUpgrade: (migrator, from, to) async {
        if (from < 1 || from >= to || to != currentSchemaVersion) {
          throw UnsupportedError(
            'No migration registered from schema version $from to $to.',
          );
        }
        await transaction(() async {
          if (from < 2) {
            await migrator.addColumn(tasks, tasks.reminderDate);
            await migrator.addColumn(tasks, tasks.reminderTimeMinutes);
          }
          if (from < 3) {
            await migrator.create(settings);
          }
          if (from < 4) {
            await migrator.addColumn(tasks, tasks.sortOrder);
            await migrator.alterTable(TableMigration(dailyFocusEntries));
          }
        });
      },
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _seedInbox() async {
    final now = DateTime.now().toUtc();
    await into(taskLists).insert(
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
}
