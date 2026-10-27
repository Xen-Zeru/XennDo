import 'package:drift/drift.dart';
import 'package:xenndo/core/database/converters/local_date_converter.dart';
import 'package:xenndo/core/database/converters/utc_date_time_converter.dart';

class TaskLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get color => integer()();
  TextColumn get icon => text().nullable()();
  IntColumn get sortOrder => integer()();
  BoolColumn get isInbox => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer().map(const UtcDateTimeConverter())();
  IntColumn get updatedAt => integer().map(const UtcDateTimeConverter())();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(name)) > 0)',
  ];
}

@TableIndex(name: 'idx_tasks_due_date', columns: {#dueDate})
@TableIndex(name: 'idx_tasks_completion', columns: {#isCompleted})
@TableIndex(name: 'idx_tasks_list', columns: {#listId})
@TableIndex(name: 'idx_tasks_completed_at', columns: {#completedAt})
class Tasks extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get description => text().nullable()();
  TextColumn get listId => text().nullable().references(
    TaskLists,
    #id,
    onDelete: KeyAction.setNull,
  )();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  IntColumn get dueDate =>
      integer().map(const LocalDateConverter()).nullable()();
  IntColumn get dueTimeMinutes => integer().nullable()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get completedAt =>
      integer().map(const UtcDateTimeConverter()).nullable()();
  IntColumn get createdAt => integer().map(const UtcDateTimeConverter())();
  IntColumn get updatedAt => integer().map(const UtcDateTimeConverter())();
  IntColumn get reminderAt =>
      integer().map(const UtcDateTimeConverter()).nullable()();
  IntColumn get reminderDate =>
      integer().map(const LocalDateConverter()).nullable()();
  IntColumn get reminderTimeMinutes => integer().nullable()();
  IntColumn get reminderOffsetMinutes => integer().nullable()();
  IntColumn get notificationId => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(title)) > 0)',
    'CHECK (priority BETWEEN 0 AND 3)',
    'CHECK (due_time_minutes IS NULL OR '
        '(due_time_minutes BETWEEN 0 AND 1439))',
    'CHECK (reminder_time_minutes IS NULL OR '
        '(reminder_time_minutes BETWEEN 0 AND 1439))',
  ];
}

@TableIndex(name: 'idx_subtasks_parent', columns: {#parentTaskId})
class Subtasks extends Table {
  TextColumn get id => text()();
  TextColumn get parentTaskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get title => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer()();
  IntColumn get createdAt => integer().map(const UtcDateTimeConverter())();
  IntColumn get updatedAt => integer().map(const UtcDateTimeConverter())();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<String> get customConstraints => const [
    'CHECK (length(trim(title)) > 0)',
  ];
}

@TableIndex(name: 'idx_focus_task', columns: {#taskId})
class DailyFocusEntries extends Table {
  IntColumn get focusDate => integer().map(const LocalDateConverter())();
  TextColumn get taskId =>
      text().references(Tasks, #id, onDelete: KeyAction.cascade)();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {focusDate, taskId};

  @override
  List<String> get customConstraints => const [
    'UNIQUE (focus_date, sort_order)',
    'CHECK (sort_order >= 0)',
  ];
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  IntColumn get updatedAt => integer().map(const UtcDateTimeConverter())();

  @override
  Set<Column> get primaryKey => {key};
}
