import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/features/backup/application/backup_service.dart';
import 'package:xenndo/features/backup/data/backup_file_store.dart';
import 'package:xenndo/features/backup/data/backup_repository.dart';
import 'package:xenndo/features/backup/domain/backup_document.dart';
import 'package:xenndo/features/reminders/application/reminder_reconciler.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';

import 'reminders/fake_reminder_scheduler.dart';
import 'support/fake_backup_file_store.dart';
import 'support/test_database.dart';

const _instant = '2026-10-19T12:00:00.000Z';

Map<String, Object?> _inboxRecord() => <String, Object?>{
  'id': 'inbox',
  'name': 'Inbox',
  'color': 6746623,
  'icon': 'inbox',
  'sortOrder': 0,
  'isInbox': true,
  'createdAt': _instant,
  'updatedAt': _instant,
};

Map<String, Object?> _taskRecord({
  String id = 'task-1',
  String title = 'Test task',
  String? listId = 'inbox',
  int priority = 2,
  Object? dueDate,
  Object? dueTimeMinutes,
  bool isCompleted = false,
  Object? completedAt,
  Object? reminderDate,
  Object? reminderTimeMinutes,
}) => <String, Object?>{
  'id': id,
  'title': title,
  'description': null,
  'listId': listId,
  'priority': priority,
  'dueDate': dueDate,
  'dueTimeMinutes': dueTimeMinutes,
  'isCompleted': isCompleted,
  'completedAt': completedAt,
  'createdAt': _instant,
  'updatedAt': _instant,
  'reminderDate': reminderDate,
  'reminderTimeMinutes': reminderTimeMinutes,
  'reminderAt': null,
};

/// A minimal document that decodes cleanly, so each test can break one rule.
Map<String, Object?> _minimalBackup() => <String, Object?>{
  'format': BackupFormat.name,
  'version': BackupFormat.currentVersion,
  'schemaVersion': 3,
  'exportedAt': _instant,
  'data': <String, Object?>{
    'lists': [_inboxRecord()],
    'tasks': [_taskRecord()],
    'subtasks': <Object>[],
    'focus': <Object>[],
    'settings': <String, Object?>{'theme_mode': 'system'},
  },
};

String _encode(Map<String, Object?> json) => jsonEncode(json);

void _expectRejected(String source, String expectedFragment) {
  expect(
    () => BackupDocument.decode(source),
    throwsA(
      isA<BackupException>().having(
        (error) => error.message,
        'message',
        contains(expectedFragment),
      ),
    ),
  );
}

void main() {
  group('round trip', () {
    late AppDatabase source;
    late AppDatabase target;
    late BackupRepository sourceRepository;
    late BackupRepository targetRepository;

    setUp(() async {
      source = await openInMemoryDatabase();
      target = await openInMemoryDatabase();
      await seedBackupFixture(source);
      sourceRepository = BackupRepository(
        source,
        clock: () => DateTime(2026, 10, 19, 12),
      );
      targetRepository = BackupRepository(
        target,
        clock: () => DateTime(2026, 10, 19, 12),
      );
    });

    tearDown(() async {
      await source.close();
      await target.close();
    });

    test(
      'restoring onto a clean database reproduces the exported data',
      () async {
        final exported = await sourceRepository.exportAll();
        await targetRepository.restore(
          BackupDocument.decode(exported.encode()),
        );

        final restored = await targetRepository.exportAll();
        expect(restored.dataJson(), equals(exported.dataJson()));
        expect(restored.version, BackupFormat.currentVersion);
      },
    );

    test(
      'completion history, reminders, and Top 3 selections survive',
      () async {
        final exported = await sourceRepository.exportAll();
        expect(exported.tasks, hasLength(3));
        expect(
          exported.tasks
              .singleWhere((task) => task.id == 'task-done')
              .isCompleted,
          isTrue,
        );
        expect(
          exported.tasks
              .singleWhere((task) => task.id == 'task-done')
              .completedAt,
          isNotNull,
        );
        expect(
          exported.tasks
              .singleWhere((task) => task.id == 'task-open')
              .reminderDate
              ?.toIso8601String(),
          '2026-10-20',
        );
        expect(exported.focusEntries, hasLength(1));
        expect(exported.focusEntries.single.taskId, 'task-open');
        expect(exported.subtasks, hasLength(2));
        expect(exported.settings['theme_mode'], 'dark');

        await targetRepository.restore(
          BackupDocument.decode(exported.encode()),
        );

        final focus = await target.select(target.dailyFocusEntries).get();
        expect(focus, hasLength(1));
        expect(focus.single.taskId, 'task-open');

        final settings = await target.select(target.settings).get();
        expect(settings.single.value, 'dark');
      },
    );

    test(
      'notification ids are never exported and are reissued on restore',
      () async {
        final exported = await sourceRepository.exportAll();
        final encoded = exported.encode();
        expect(encoded, isNot(contains('notificationId')));

        await targetRepository.restore(BackupDocument.decode(encoded));

        final rows = await target.select(target.tasks).get();
        final issued = <int>[
          for (final row in rows)
            if (row.reminderDate != null) row.notificationId!,
        ];
        expect(issued, hasLength(2));
        expect(issued.toSet(), hasLength(issued.length));
        expect(issued, isNot(contains(1001)));
        expect(issued, isNot(contains(1002)));
      },
    );
  });

  group('validation rejects', () {
    test('text that is not JSON at all', () {
      _expectRejected('not a json document', 'not valid JSON');
    });

    test('a JSON document that is not an object', () {
      _expectRejected('[1, 2, 3]', 'not a JSON object');
    });

    test('a file from another app', () {
      final json = _minimalBackup()..['format'] = 'someone-elses-backup';
      _expectRejected(_encode(json), 'not a XennDo backup');
    });

    test('a newer backup version', () {
      final json = _minimalBackup()..['version'] = 99;
      _expectRejected(_encode(json), 'Backup version 99 is not supported');
    });

    test('a backup without a version', () {
      final json = _minimalBackup()..remove('version');
      _expectRejected(_encode(json), 'no usable version number');
    });

    test('a backup without a schema version', () {
      final json = _minimalBackup()..remove('schemaVersion');
      _expectRejected(_encode(json), 'no usable database schema version');
    });

    test('a missing section', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>).remove('tasks');
      _expectRejected(_encode(json), '"tasks" section is missing');
    });

    test('a missing settings section', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>).remove('settings');
      _expectRejected(_encode(json), '"settings" section is missing');
    });

    test('duplicate task ids', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['tasks'] = [
        _taskRecord(),
        _taskRecord(id: 'task-1', title: 'Second task'),
      ];
      _expectRejected(_encode(json), 'repeats the same task id');
    });

    test('a task pointing at a list that is not in the backup', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['tasks'] = [
        _taskRecord(listId: 'ghost'),
      ];
      _expectRejected(_encode(json), 'points at list "ghost"');
    });

    test('a subtask whose task is missing', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['subtasks'] = [
        <String, Object?>{
          'id': 'sub-1',
          'taskId': 'ghost',
          'title': 'Orphan',
          'isCompleted': false,
          'sortOrder': 0,
          'createdAt': _instant,
          'updatedAt': _instant,
        },
      ];
      _expectRejected(_encode(json), 'points at task "ghost"');
    });

    test('a Top 3 selection for a missing task', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['focus'] = [
        <String, Object?>{
          'date': '2026-10-19',
          'taskId': 'ghost',
          'sortOrder': 0,
        },
      ];
      _expectRejected(_encode(json), 'points at task "ghost"');
    });

    test('two Top 3 selections sharing a position', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['tasks'] = [
        _taskRecord(),
        _taskRecord(id: 'task-2', title: 'Other task'),
      ];
      (json['data']! as Map<String, Object?>)['focus'] = [
        <String, Object?>{
          'date': '2026-10-19',
          'taskId': 'task-1',
          'sortOrder': 0,
        },
        <String, Object?>{
          'date': '2026-10-19',
          'taskId': 'task-2',
          'sortOrder': 0,
        },
      ];
      _expectRejected(_encode(json), 'a day uses one position twice');
    });

    test('an empty title', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['tasks'] = [
        _taskRecord(title: '   '),
      ];
      _expectRejected(_encode(json), 'must be non-empty text');
    });

    test('a priority outside the supported range', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['tasks'] = [
        _taskRecord(priority: 9),
      ];
      _expectRejected(_encode(json), '"priority" must be between 0 and 3');
    });

    test('a due time outside the day', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['tasks'] = [
        _taskRecord(dueTimeMinutes: 2000),
      ];
      _expectRejected(
        _encode(json),
        '"dueTimeMinutes" must be between 0 and 1439',
      );
    });

    test('a due date that is not written as YYYY-MM-DD', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['tasks'] = [
        _taskRecord(dueDate: '20th Oct 2026'),
      ];
      _expectRejected(_encode(json), 'must be a date written as YYYY-MM-DD');
    });

    test('a date that does not exist', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['tasks'] = [
        _taskRecord(dueDate: '2026-02-30'),
      ];
      _expectRejected(_encode(json), 'not a real calendar date');
    });

    test('a timestamp that is not ISO-8601', () {
      final json = _minimalBackup()..['exportedAt'] = 'yesterday';
      _expectRejected(_encode(json), 'not an ISO-8601 timestamp');
    });

    test('a setting this version does not use', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['settings'] = {
        'theme_mode': 'system',
        'notification_permission': 'granted',
      };
      _expectRejected(_encode(json), 'does not use');
    });

    test('an unreadable theme mode', () {
      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['settings'] = {
        'theme_mode': 'sepia',
      };
      _expectRejected(_encode(json), 'theme_mode must be one of');
    });
  });

  group('service flow', () {
    late AppDatabase database;
    late BackupRepository repository;

    setUp(() async {
      database = await openInMemoryDatabase();
      await seedBackupFixture(database);
      repository = BackupRepository(
        database,
        clock: () => DateTime(2026, 10, 19, 12),
      );
    });

    tearDown(() => database.close());

    test('exporting writes a versioned file named after the day', () async {
      final store = FakeBackupFileStore(savedUri: 'content://backup/x.json');
      final service = _service(database, repository, store);

      final result = await service.exportBackup();

      expect(result.status, BackupExportStatus.saved);
      expect(result.fileName, 'xenndo-backup-2026-10-19.json');
      expect(store.savedFileName, 'xenndo-backup-2026-10-19.json');
      final written = utf8.decode(store.savedBytes!);
      expect(written, contains('"format": "xenndo-backup"'));
      expect(BackupDocument.decode(written).tasks, hasLength(3));
    });

    test('a dismissed save dialog reports cancellation', () async {
      final store = FakeBackupFileStore(savedUri: null);
      final result = await _service(database, repository, store).exportBackup();

      expect(result.status, BackupExportStatus.cancelled);
      expect(result.message, isNull);
    });

    test('a save failure is reported without throwing', () async {
      final store = FakeBackupFileStore(
        savedUri: 'content://backup/x.json',
        saveError: Exception('disk full'),
      );
      final result = await _service(database, repository, store).exportBackup();

      expect(result.status, BackupExportStatus.failed);
      expect(result.message, contains('could not be saved'));
    });

    test('a dismissed open dialog reports cancellation', () async {
      final store = FakeBackupFileStore(openBytes: null);
      final result = await _service(database, repository, store).openBackup();

      expect(result.status, BackupOpenStatus.cancelled);
    });

    test('an unreadable file is reported as a failure', () async {
      final store = FakeBackupFileStore(
        openError: Exception('permission denied'),
      );
      final result = await _service(database, repository, store).openBackup();

      expect(result.status, BackupOpenStatus.failed);
      expect(result.message, contains('could not be read'));
    });

    test('a rejected file never reaches the database', () async {
      final before = await repository.exportAll();
      final store = FakeBackupFileStore(
        openBytes: utf8.encode(_encode(_minimalBackup()..['version'] = 99)),
      );

      final result = await _service(database, repository, store).openBackup();

      expect(result.status, BackupOpenStatus.failed);
      expect(result.message, contains('not supported'));
      expect((await repository.exportAll()).dataJson(), before.dataJson());
    });

    test('a successful restore cancels stale reminders and schedules the '
        'future ones', () async {
      final scheduler = FakeReminderScheduler()..pending.add(5555);
      final source = await openInMemoryDatabase();
      addTearDown(source.close);
      await seedBackupFixture(source);
      final document = await BackupRepository(
        source,
        clock: () => DateTime(2026, 10, 19, 12),
      ).exportAll();

      final target = await openInMemoryDatabase();
      addTearDown(target.close);
      final service = BackupService(
        repository: BackupRepository(
          target,
          clock: () => DateTime(2026, 10, 19, 12),
        ),
        fileStore: FakeBackupFileStore(),
        reconciler: ReminderReconciler(
          tasks: TaskRepository(
            target,
            clock: () => DateTime(2026, 10, 19, 12),
            reminderScheduler: scheduler,
          ),
          scheduler: scheduler,
          clock: () => DateTime(2026, 10, 19, 12),
        ),
        clock: () => DateTime(2026, 10, 19, 12),
      );

      final result = await service.restore(document);

      expect(result.status, BackupRestoreStatus.restored);
      expect(result.warning, isNull);
      expect(result.summary!.tasks, 3);
      // Only the 2026-10-20 reminder is still in the future.
      expect(
        [for (final reminder in scheduler.scheduled) reminder.taskId],
        ['task-open'],
      );
      expect(scheduler.pending, isNot(contains(5555)));
      expect(scheduler.cancelled, contains(5555));
    });
  });

  group('failed restore', () {
    test('a write failure leaves the previous data untouched', () async {
      final database = await openInMemoryDatabase();
      addTearDown(database.close);
      await seedBackupFixture(database);
      final repository = BackupRepository(
        database,
        clock: () => DateTime(2026, 10, 19, 12),
      );
      final before = await repository.exportAll();

      // A trigger makes one insert fail partway through the replacement, after
      // the existing rows have already been deleted inside the transaction.
      await database.customStatement(
        "CREATE TRIGGER reject_poison BEFORE INSERT ON tasks "
        "WHEN NEW.title = 'Poison' "
        "BEGIN SELECT RAISE(ABORT, 'write refused'); END;",
      );

      final json = _minimalBackup();
      (json['data']! as Map<String, Object?>)['lists'] = [
        _inboxRecord(),
        <String, Object?>{
          'id': 'work',
          'name': 'Restored work list',
          'color': 1,
          'icon': null,
          'sortOrder': 1,
          'isInbox': false,
          'createdAt': _instant,
          'updatedAt': _instant,
        },
      ];
      (json['data']! as Map<String, Object?>)['tasks'] = [
        _taskRecord(title: 'Poison'),
      ];
      final failing = BackupDocument.decode(_encode(json));

      await expectLater(repository.restore(failing), throwsA(anything));

      final after = await repository.exportAll();
      expect(after.dataJson(), equals(before.dataJson()));
      expect(after.lists, hasLength(2));
      expect(
        after.lists.map((list) => list.name),
        containsAll(['Inbox', 'Work']),
      );
      expect(after.tasks.map((task) => task.title), contains('Write the plan'));
    });
  });
}

BackupService _service(
  AppDatabase database,
  BackupRepository repository,
  BackupFileStore store,
) {
  return BackupService(
    repository: repository,
    fileStore: store,
    reconciler: ReminderReconciler(
      tasks: TaskRepository(database),
      scheduler: const NoopReminderScheduler(),
    ),
    clock: () => DateTime(2026, 10, 19, 12),
  );
}
