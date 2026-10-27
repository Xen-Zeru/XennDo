import 'dart:convert';

import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/settings/data/settings_repository.dart';
import 'package:xenndo/features/settings/domain/app_settings.dart';

/// Raised when a backup file cannot be read, understood, or trusted.
///
/// The message is written for the person restoring the file, so it names the
/// section, record, and field that failed.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// Constants that describe the on-disk backup format.
abstract final class BackupFormat {
  /// Written in every export so a file can be recognized before anything else
  /// is read.
  static const String name = 'xenndo-backup';

  /// Version 2 adds task ordering and retains completed focus selections.
  /// Version 1 backups remain readable.
  static const int currentVersion = 2;
}

/// Counts shown in the restore preview before anything is written.
class BackupSummary {
  const BackupSummary({
    required this.lists,
    required this.tasks,
    required this.completedTasks,
    required this.subtasks,
    required this.focusEntries,
    required this.themeMode,
  });

  final int lists;
  final int tasks;
  final int completedTasks;
  final int subtasks;
  final int focusEntries;
  final String themeMode;
}

/// A custom list.
class BackupList {
  const BackupList({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.sortOrder,
    required this.isInbox,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BackupList.read(Map<String, dynamic> json, int position) {
    final where = 'List $position';
    return BackupList(
      id: _readId(json, 'id', where),
      name: _readText(json, 'name', where),
      color: _readInt(json, 'color', where),
      icon: _readStringOrNull(json, 'icon', where),
      sortOrder: _readInt(json, 'sortOrder', where),
      isInbox: _readBool(json, 'isInbox', where),
      createdAt: _readInstant(json, 'createdAt', where),
      updatedAt: _readInstant(json, 'updatedAt', where),
    );
  }

  final String id;
  final String name;
  final int color;
  final String? icon;
  final int sortOrder;
  final bool isInbox;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'color': color,
    'icon': icon,
    'sortOrder': sortOrder,
    'isInbox': isInbox,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// A task, with its reminder definition but without any notification id.
class BackupTask {
  const BackupTask({
    required this.id,
    required this.title,
    this.sortOrder = 0,
    required this.description,
    required this.listId,
    required this.priority,
    required this.dueDate,
    required this.dueTimeMinutes,
    required this.isCompleted,
    required this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.reminderDate,
    required this.reminderTimeMinutes,
    required this.reminderAt,
  });

  factory BackupTask.read(Map<String, dynamic> json, int position) {
    final where = 'Task $position';
    return BackupTask(
      id: _readId(json, 'id', where),
      title: _readText(json, 'title', where),
      sortOrder: json.containsKey('sortOrder')
          ? _readIntInRange(json, 'sortOrder', where, min: 0, max: 2147483647)
          : 0,
      description: _readStringOrNull(json, 'description', where),
      listId: _readStringOrNull(json, 'listId', where),
      priority: _readIntInRange(json, 'priority', where, min: 0, max: 3),
      dueDate: _readDateOrNull(json, 'dueDate', where),
      dueTimeMinutes: _readTimeOrNull(json, 'dueTimeMinutes', where),
      isCompleted: _readBool(json, 'isCompleted', where),
      completedAt: _readInstantOrNull(json, 'completedAt', where),
      createdAt: _readInstant(json, 'createdAt', where),
      updatedAt: _readInstant(json, 'updatedAt', where),
      reminderDate: _readDateOrNull(json, 'reminderDate', where),
      reminderTimeMinutes: _readTimeOrNull(json, 'reminderTimeMinutes', where),
      reminderAt: _readInstantOrNull(json, 'reminderAt', where),
    );
  }

  final String id;
  final String title;
  final int sortOrder;
  final String? description;
  final String? listId;
  final int priority;
  final LocalDate? dueDate;
  final int? dueTimeMinutes;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final LocalDate? reminderDate;
  final int? reminderTimeMinutes;
  final DateTime? reminderAt;

  /// True when the task carries reminder metadata and therefore needs a freshly
  /// assigned notification id after a restore.
  bool get hasReminder =>
      reminderDate != null || reminderAt != null || reminderTimeMinutes != null;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'sortOrder': sortOrder,
    'description': description,
    'listId': listId,
    'priority': priority,
    'dueDate': dueDate?.toIso8601String(),
    'dueTimeMinutes': dueTimeMinutes,
    'isCompleted': isCompleted,
    'completedAt': completedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'reminderDate': reminderDate?.toIso8601String(),
    'reminderTimeMinutes': reminderTimeMinutes,
    'reminderAt': reminderAt?.toIso8601String(),
  };
}

/// A subtask of one task.
class BackupSubtask {
  const BackupSubtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.isCompleted,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BackupSubtask.read(Map<String, dynamic> json, int position) {
    final where = 'Subtask $position';
    return BackupSubtask(
      id: _readId(json, 'id', where),
      taskId: _readId(json, 'taskId', where),
      title: _readText(json, 'title', where),
      isCompleted: _readBool(json, 'isCompleted', where),
      sortOrder: _readInt(json, 'sortOrder', where),
      createdAt: _readInstant(json, 'createdAt', where),
      updatedAt: _readInstant(json, 'updatedAt', where),
    );
  }

  final String id;
  final String taskId;
  final String title;
  final bool isCompleted;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'taskId': taskId,
    'title': title,
    'isCompleted': isCompleted,
    'sortOrder': sortOrder,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

/// One "My Top 3" selection for a local day.
class BackupFocusEntry {
  const BackupFocusEntry({
    required this.date,
    required this.taskId,
    required this.sortOrder,
  });

  factory BackupFocusEntry.read(Map<String, dynamic> json, int position) {
    final where = 'Top 3 selection $position';
    return BackupFocusEntry(
      date: _readDate(json, 'date', where),
      taskId: _readId(json, 'taskId', where),
      sortOrder: _readIntInRange(
        json,
        'sortOrder',
        where,
        min: 0,
        max: 2147483647,
      ),
    );
  }

  final LocalDate date;
  final String taskId;
  final int sortOrder;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'date': date.toIso8601String(),
    'taskId': taskId,
    'sortOrder': sortOrder,
  };
}

/// A complete, validated backup.
///
/// [decode] performs every structural and value check before an instance
/// exists, so a document that reaches the repository is safe to write.
class BackupDocument {
  const BackupDocument({
    required this.version,
    required this.schemaVersion,
    required this.exportedAt,
    required this.lists,
    required this.tasks,
    required this.subtasks,
    required this.focusEntries,
    required this.settings,
  });

  /// Parses [source] and rejects anything this build cannot restore.
  factory BackupDocument.decode(String source) {
    final Object? root;
    try {
      root = jsonDecode(source);
    } on FormatException catch (error) {
      throw BackupException('This file is not valid JSON (${error.message}).');
    }

    final envelope = _readMap(root, 'The backup file');
    final format = envelope['format'];
    if (format != BackupFormat.name) {
      throw BackupException(
        'This is not a XennDo backup: "format" should be '
        '"${BackupFormat.name}", found $format.',
      );
    }

    final version = envelope['version'];
    if (version is! int) {
      throw BackupException(
        'This backup has no usable version number, so it cannot be restored.',
      );
    }
    if (version < 1 || version > BackupFormat.currentVersion) {
      throw BackupException(
        'Backup version $version is not supported. This version of XennDo '
        'restores backup versions 1 through ${BackupFormat.currentVersion}.',
      );
    }

    final schemaVersion = envelope['schemaVersion'];
    if (schemaVersion is! int) {
      throw BackupException(
        'This backup has no usable database schema version, so it cannot be '
        'restored.',
      );
    }

    final data = _readMap(envelope['data'], 'The backup "data" section');
    final exportedAt = _readInstant(envelope, 'exportedAt', 'The backup file');

    final lists = <BackupList>[];
    for (final (index, raw) in _readSection(data, 'lists').indexed) {
      lists.add(BackupList.read(raw, index + 1));
    }

    final tasks = <BackupTask>[];
    for (final (index, raw) in _readSection(data, 'tasks').indexed) {
      tasks.add(BackupTask.read(raw, index + 1));
    }

    final subtasks = <BackupSubtask>[];
    for (final (index, raw) in _readSection(data, 'subtasks').indexed) {
      subtasks.add(BackupSubtask.read(raw, index + 1));
    }

    final focusEntries = <BackupFocusEntry>[];
    for (final (index, raw) in _readSection(data, 'focus').indexed) {
      focusEntries.add(BackupFocusEntry.read(raw, index + 1));
    }

    if (version == 1 && focusEntries.any((entry) => entry.sortOrder > 2)) {
      throw const BackupException(
        'Version 1 focus positions must be between 0 and 2.',
      );
    }
    final settings = _readSettings(data['settings']);

    _assertUniqueIds(lists, tasks, subtasks, focusEntries);
    _assertReferences(
      lists: lists,
      tasks: tasks,
      subtasks: subtasks,
      focus: focusEntries,
    );

    return BackupDocument(
      version: version,
      schemaVersion: schemaVersion,
      exportedAt: exportedAt,
      lists: lists,
      tasks: tasks,
      subtasks: subtasks,
      focusEntries: focusEntries,
      settings: settings,
    );
  }

  final int version;
  final int schemaVersion;
  final DateTime exportedAt;
  final List<BackupList> lists;
  final List<BackupTask> tasks;
  final List<BackupSubtask> subtasks;
  final List<BackupFocusEntry> focusEntries;
  final Map<String, String> settings;

  BackupSummary get summary => BackupSummary(
    lists: lists.length,
    tasks: tasks.length,
    completedTasks: tasks.where((task) => task.isCompleted).length,
    subtasks: subtasks.length,
    focusEntries: focusEntries.length,
    themeMode: settings[SettingsKeys.themeMode] ?? 'system',
  );

  /// The payload section, without the envelope. Comparing two exports compares
  /// this map so timestamps written by different runs are ignored.
  Map<String, Object?> dataJson() => <String, Object?>{
    'lists': [for (final list in lists) list.toJson()],
    'tasks': [for (final task in tasks) task.toJson()],
    'subtasks': [for (final subtask in subtasks) subtask.toJson()],
    'focus': [for (final entry in focusEntries) entry.toJson()],
    'settings': settings,
  };

  /// The exact structure an export writes.
  Map<String, Object?> toJson() => <String, Object?>{
    'format': BackupFormat.name,
    'version': version,
    'schemaVersion': schemaVersion,
    'exportedAt': exportedAt.toIso8601String(),
    'data': dataJson(),
  };

  String encode() {
    final encoded = const JsonEncoder.withIndent('  ').convert(toJson());
    return '$encoded\n';
  }
}

List<Map<String, dynamic>> _readSection(Map<String, dynamic> data, String key) {
  final Object? value = data[key];
  if (value is! List) {
    throw BackupException(
      'The backup "$key" section is missing or is not a list.',
    );
  }
  final section = <Map<String, dynamic>>[];
  for (final (index, raw) in value.indexed) {
    section.add(_readMap(raw, '$key entry ${index + 1}'));
  }
  return section;
}

Map<String, String> _readSettings(Object? value) {
  if (value is! Map) {
    throw BackupException(
      'The backup "settings" section is missing or is not a JSON object.',
    );
  }
  final settings = <String, String>{};
  for (final entry in value.entries) {
    final key = entry.key;
    final settingValue = entry.value;
    if (key is! String || settingValue is! String) {
      throw BackupException(
        'Every backup setting must be a text key with a text value.',
      );
    }
    if (!SettingsKeys.exportableKeys.contains(key)) {
      throw BackupException(
        'The backup contains the setting "$key", which this version of XennDo '
        'does not use.',
      );
    }
    if (key == SettingsKeys.themeMode &&
        !AppSettings.storageValues.contains(settingValue)) {
      throw BackupException(
        'The backup setting $key must be one of '
        '${AppSettings.storageValues.join(', ')}; found '
        '"$settingValue".',
      );
    }
    settings[key] = settingValue;
  }
  return settings;
}

void _assertUniqueIds(
  List<BackupList> lists,
  List<BackupTask> tasks,
  List<BackupSubtask> subtasks,
  List<BackupFocusEntry> focus,
) {
  _assertDistinct('list', [for (final list in lists) list.id]);
  _assertDistinct('task', [for (final task in tasks) task.id]);
  _assertDistinct('subtask', [for (final subtask in subtasks) subtask.id]);

  final byTask = <String>[];
  final byPosition = <String>[];
  for (final entry in focus) {
    byTask.add('${entry.date.toIso8601String()} ${entry.taskId}');
    byPosition.add('${entry.date.toIso8601String()} ${entry.sortOrder}');
  }
  _assertDistinct(
    'Top 3 selection',
    byTask,
    'a task is listed twice for a day',
  );
  _assertDistinct(
    'Top 3 position',
    byPosition,
    'a day uses one position twice',
  );
}

void _assertDistinct(String noun, List<String> values, [String? reason]) {
  final seen = <String>{};
  final duplicates = <String>{};
  for (final value in values) {
    if (!seen.add(value)) {
      duplicates.add(value);
    }
  }
  if (duplicates.isNotEmpty) {
    final label = duplicates.length == 1 ? '$noun id' : '$noun ids';
    final listed = duplicates.map((value) => '"$value"').join(', ');
    final suffix = reason == null ? '' : ' ($reason)';
    throw BackupException(
      'The backup repeats the same $label: $listed$suffix. Each record must be '
      'unique.',
    );
  }
}

void _assertReferences({
  required List<BackupList> lists,
  required List<BackupTask> tasks,
  required List<BackupSubtask> subtasks,
  required List<BackupFocusEntry> focus,
}) {
  final inboxes = lists.where((list) => list.isInbox).toList();
  if (inboxes.length > 1 ||
      lists.any((list) => list.id == 'inbox' && !list.isInbox)) {
    throw const BackupException(
      'The backup must contain at most one protected Inbox.',
    );
  }
  final listIds = {for (final list in lists) list.id};
  final taskIds = <String>{};

  for (final (index, task) in tasks.indexed) {
    taskIds.add(task.id);
    final listId = task.listId;
    if (listId != null && !listIds.contains(listId)) {
      throw BackupException(
        'Task ${index + 1} ("${task.title}") points at list "$listId", which is '
        'not in the backup.',
      );
    }
  }

  for (final (index, subtask) in subtasks.indexed) {
    if (!taskIds.contains(subtask.taskId)) {
      throw BackupException(
        'Subtask ${index + 1} ("${subtask.title}") points at task '
        '"${subtask.taskId}", which is not in the backup.',
      );
    }
  }

  final completed = {for (final task in tasks) task.id: task.isCompleted};
  final activePerDay = <LocalDate, int>{};
  for (final (index, entry) in focus.indexed) {
    if (completed[entry.taskId] == false) {
      activePerDay.update(entry.date, (n) => n + 1, ifAbsent: () => 1);
      if (activePerDay[entry.date]! > 3) {
        throw const BackupException(
          'My Top 3 cannot contain more than three incomplete tasks per day.',
        );
      }
    }
    if (!taskIds.contains(entry.taskId)) {
      throw BackupException(
        'Top 3 selection ${index + 1} points at task "${entry.taskId}", which is '
        'not in the backup.',
      );
    }
  }
}

Map<String, dynamic> _readMap(Object? value, String where) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  throw BackupException('$where is not a JSON object.');
}

String _readId(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw BackupException('$where: "$key" must be a non-empty text id.');
  }
  return value;
}

String _readText(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw BackupException(
      '$where: "$key" must be non-empty text; found $value.',
    );
  }
  return value;
}

String? _readStringOrNull(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw BackupException('$where: "$key" must be text or null.');
  }
  return value;
}

int _readInt(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is! int) {
    throw BackupException(
      '$where: "$key" must be a whole number; found $value.',
    );
  }
  return value;
}

int _readIntInRange(
  Map<String, dynamic> json,
  String key,
  String where, {
  required int min,
  required int max,
}) {
  final value = _readInt(json, key, where);
  if (value < min || value > max) {
    throw BackupException('$where: "$key" must be between $min and $max.');
  }
  return value;
}

bool _readBool(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is! bool) {
    throw BackupException(
      '$where: "$key" must be true or false; found $value.',
    );
  }
  return value;
}

DateTime _readInstant(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is! String) {
    throw BackupException('$where: "$key" must be an ISO-8601 timestamp.');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) {
    throw BackupException(
      '$where: "$key" is not an ISO-8601 timestamp; found "$value".',
    );
  }
  return parsed.toUtc();
}

DateTime? _readInstantOrNull(
  Map<String, dynamic> json,
  String key,
  String where,
) {
  if (json[key] == null) {
    return null;
  }
  return _readInstant(json, key, where);
}

LocalDate _readDate(Map<String, dynamic> json, String key, String where) {
  final value = json[key];
  if (value is! String) {
    throw BackupException(
      '$where: "$key" must be a date written as YYYY-MM-DD.',
    );
  }
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) {
    throw BackupException(
      '$where: "$key" must be a date written as YYYY-MM-DD; found "$value".',
    );
  }
  try {
    return LocalDate(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  } on ArgumentError {
    throw BackupException('$where: "$key" is not a real calendar date.');
  }
}

LocalDate? _readDateOrNull(
  Map<String, dynamic> json,
  String key,
  String where,
) {
  if (json[key] == null) {
    return null;
  }
  return _readDate(json, key, where);
}

int? _readTimeOrNull(Map<String, dynamic> json, String key, String where) {
  if (json[key] == null) {
    return null;
  }
  return _readIntInRange(json, key, where, min: 0, max: 1439);
}
