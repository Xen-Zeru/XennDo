import 'dart:convert';

import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/app/app.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/core/database/database_provider.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/features/backup/application/backup_providers.dart';
import 'package:xenndo/features/backup/data/backup_file_store.dart';
import 'package:xenndo/features/backup/data/backup_repository.dart';
import 'package:xenndo/features/reminders/application/reminder_providers.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';
import 'package:xenndo/features/settings/data/settings_repository.dart';
import 'package:xenndo/features/settings/domain/app_settings.dart';

import 'reminders/fake_reminder_scheduler.dart';
import 'support/fake_backup_file_store.dart';
import 'support/test_app.dart';
import 'support/test_database.dart';

final _utc = DateTime.utc(2026, 10, 19, 12);

ProviderScope _appScope(
  AppDatabase database, {
  ReminderScheduler? scheduler,
  BackupFileStore? fileStore,
}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(database),
      nowProvider.overrideWithValue(() => DateTime(2026, 10, 19, 12)),
      if (scheduler != null)
        reminderSchedulerProvider.overrideWithValue(scheduler),
      if (fileStore != null)
        backupFileStoreProvider.overrideWithValue(fileStore),
    ],
    child: const XenndoApp(),
  );
}

/// Builds the app against [database], lands on the Settings tab, then runs
/// [checks].
///
/// The widget tree is always torn down before the test body ends so Drift
/// stream timers are flushed instead of failing the pending-timer check.
Future<void> _openSettings(
  WidgetTester tester,
  AppDatabase database,
  Future<void> Function() checks, {
  ReminderScheduler? scheduler,
  BackupFileStore? fileStore,
}) async {
  await tester.pumpWidget(
    _appScope(database, scheduler: scheduler, fileStore: fileStore),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('nav-settings')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('add-task-fab')), findsNothing);
  try {
    await checks();
  } finally {
    await disposeXenndoApp(tester);
  }
}

/// Scrolls the settings list until [finder] is built, then reveals it.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// The notification button sits below the fold above the bottom bar.
Future<void> _revealAndTap(WidgetTester tester, Finder finder) async {
  await _scrollTo(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// One task that only exists on the device, so a restore can be seen to
/// replace it.
Future<void> _seedLocalTask(AppDatabase database) async {
  await database
      .into(database.tasks)
      .insert(
        TasksCompanion.insert(
          id: 'local-task',
          title: 'Local task',
          createdAt: fixtureNow,
          updatedAt: fixtureNow,
        ),
      );
}

void main() {
  group('settings repository', () {
    late AppDatabase database;
    late SettingsRepository repository;

    setUp(() async {
      database = await openInMemoryDatabase();
      repository = SettingsRepository(
        database,
        clock: () => DateTime.utc(2026, 10, 19, 12),
      );
    });

    tearDown(() => database.close());

    test('falls back to system when nothing is stored', () async {
      expect(await repository.load(), const AppSettings());
      expect((await repository.load()).themeMode, ThemeMode.system);
    });

    test('persists the theme mode for later reads', () async {
      await repository.saveThemeMode(ThemeMode.dark);

      // A fresh repository instance models a later app launch.
      final reopened = SettingsRepository(database);
      expect((await reopened.load()).themeMode, ThemeMode.dark);
    });

    test('later writes replace earlier values', () async {
      await repository.saveThemeMode(ThemeMode.dark);
      await repository.saveThemeMode(ThemeMode.light);

      expect((await repository.load()).themeMode, ThemeMode.light);
      expect(await database.select(database.settings).get(), hasLength(1));
    });

    test('unknown stored values fall back to system', () async {
      // Simulate a corrupted or future value written directly to storage.
      await database
          .into(database.settings)
          .insert(
            Setting(key: 'theme_mode', value: 'sepia', updatedAt: _utc),
            mode: InsertMode.insertOrReplace,
          );

      expect((await repository.load()).themeMode, ThemeMode.system);
    });
  });

  group('settings survive an app restart', () {
    testWidgets('the chosen appearance is restored when the app rebuilds', (
      tester,
    ) async {
      final database = await openInMemoryDatabase();
      addTearDown(database.close);
      mockPackageInfo();

      await tester.pumpWidget(_appScope(database));
      await tester.pumpAndSettle();

      try {
        await tester.tap(find.byKey(const ValueKey('nav-settings')));
        await tester.pumpAndSettle();

        final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
        expect(app.themeMode, ThemeMode.system);

        await tester.tap(find.byKey(const ValueKey('theme-dark')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.dark,
        );

        // Rebuild the whole tree against the same storage: a restart.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pumpWidget(_appScope(database));
        await tester.pumpAndSettle();

        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.dark,
        );
        await tester.tap(find.byKey(const ValueKey('nav-settings')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<ChoiceChip>(find.byKey(const ValueKey('theme-dark')))
              .selected,
          isTrue,
        );
      } finally {
        await disposeXenndoApp(tester);
      }
    });
  });

  group('settings screen', () {
    testWidgets('shows the notification permission state', (tester) async {
      final database = await openInMemoryDatabase();
      addTearDown(database.close);
      mockPackageInfo();
      final scheduler = FakeReminderScheduler()
        ..permission = ReminderPermissionStatus.granted;

      await _openSettings(tester, database, () async {
        expect(find.text('Allowed'), findsOneWidget);

        final button = tester.widget<FilledButton>(
          find.byKey(const ValueKey('open-system-notification-settings')),
        );
        expect(button.onPressed, isNotNull);

        await _revealAndTap(
          tester,
          find.byKey(const ValueKey('open-system-notification-settings')),
        );
        expect(scheduler.openSettingsCalled, isTrue);
      }, scheduler: scheduler);
    });

    testWidgets(
      'blocked notifications are explained and still allow settings',
      (tester) async {
        final database = await openInMemoryDatabase();
        addTearDown(database.close);
        mockPackageInfo();
        final scheduler = FakeReminderScheduler()
          ..permission = ReminderPermissionStatus.denied;

        await _openSettings(tester, database, () async {
          expect(find.text('Not allowed'), findsOneWidget);
          expect(
            find.byKey(const ValueKey('request-notification-permission')),
            findsNothing,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(
                    const ValueKey('open-system-notification-settings'),
                  ),
                )
                .onPressed,
            isNotNull,
          );

          await _revealAndTap(
            tester,
            find.byKey(const ValueKey('open-system-notification-settings')),
          );
          expect(scheduler.openSettingsCalled, isTrue);
        }, scheduler: scheduler);
      },
    );

    testWidgets(
      'Settings requests notification permission when Android can prompt',
      (tester) async {
        final database = await openInMemoryDatabase();
        addTearDown(database.close);
        mockPackageInfo();
        final scheduler = FakeReminderScheduler()
          ..permission = ReminderPermissionStatus.requestable;

        await _openSettings(tester, database, () async {
          await _revealAndTap(
            tester,
            find.byKey(const ValueKey('request-notification-permission')),
          );
          expect(scheduler.permissionRequests, 1);
          expect(find.text('Notifications are still off'), findsOneWidget);
        }, scheduler: scheduler);
      },
    );

    testWidgets('compact About row opens the dedicated About page', (
      tester,
    ) async {
      final database = await openInMemoryDatabase();
      addTearDown(database.close);
      mockPackageInfo();

      await _openSettings(tester, database, () async {
        await _scrollTo(tester, find.text('XennDo'));
        expect(find.text('XennDo'), findsOneWidget);
        expect(find.text('Plan your day. Get it done.'), findsNothing);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('app-version'))).data,
          'Version 1.0.0',
        );
        await _revealAndTap(
          tester,
          find.byKey(const ValueKey('about-details')),
        );
        expect(find.byKey(const ValueKey('about-screen')), findsOneWidget);
        expect(find.text('Plan your day. Get it done.'), findsOneWidget);
        expect(
          find.textContaining('XennDo is a personal to-do app'),
          findsOneWidget,
        );
      });
    });

    testWidgets('export explains that the file is readable, then saves it', (
      tester,
    ) async {
      final database = await openInMemoryDatabase();
      addTearDown(database.close);
      mockPackageInfo();
      final store = FakeBackupFileStore(savedUri: 'content://backup/x.json');

      await _openSettings(tester, database, () async {
        await _revealAndTap(
          tester,
          find.byKey(const ValueKey('backup-export')),
        );
        expect(find.text('Save a backup file'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('not encrypted'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.textContaining('read your list names'),
          ),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const ValueKey('backup-export-continue')));
        await tester.pumpAndSettle();

        expect(store.saveCalls, 1);
        expect(store.savedFileName, 'xenndo-backup-2026-10-19.json');
        final written = utf8.decode(store.savedBytes!);
        expect(written, contains('"format": "xenndo-backup"'));
        expect(
          find.textContaining('Backup saved as xenndo-backup-2026-10-19.json.'),
          findsOneWidget,
        );
      }, fileStore: store);
    });

    testWidgets('a dismissed save dialog is reported as a cancellation', (
      tester,
    ) async {
      final database = await openInMemoryDatabase();
      addTearDown(database.close);
      mockPackageInfo();
      final store = FakeBackupFileStore(savedUri: null);

      await _openSettings(tester, database, () async {
        await _revealAndTap(
          tester,
          find.byKey(const ValueKey('backup-export')),
        );
        await tester.tap(find.byKey(const ValueKey('backup-export-continue')));
        await tester.pumpAndSettle();

        expect(store.saveCalls, 1);
        expect(
          find.text('Export cancelled. Nothing was saved.'),
          findsOneWidget,
        );
      }, fileStore: store);
    });

    testWidgets(
      'restore previews the counts and replaces data only after confirmation',
      (tester) async {
        final source = await openInMemoryDatabase();
        addTearDown(source.close);
        await seedBackupFixture(source);
        final document = await BackupRepository(
          source,
          clock: () => DateTime(2026, 10, 19, 12),
        ).exportAll();

        final database = await openInMemoryDatabase();
        addTearDown(database.close);
        mockPackageInfo();
        await _seedLocalTask(database);
        final before = await BackupRepository(database).exportAll();

        final store = FakeBackupFileStore(
          openBytes: utf8.encode(document.encode()),
        );
        final scheduler = FakeReminderScheduler();

        await _openSettings(
          tester,
          database,
          () async {
            await _revealAndTap(
              tester,
              find.byKey(const ValueKey('backup-import')),
            );
            expect(find.text('Restore this backup?'), findsOneWidget);
            expect(find.textContaining('The file contains'), findsOneWidget);
            expect(find.textContaining('2 lists'), findsOneWidget);
            expect(find.textContaining('3 tasks'), findsOneWidget);
            expect(find.textContaining('2 subtasks'), findsOneWidget);
            expect(find.textContaining('1 Top 3 selection'), findsOneWidget);
            expect(find.textContaining('Appearance: dark'), findsOneWidget);
            expect(find.textContaining('cannot be undone'), findsOneWidget);

            await tester.tap(find.text('Cancel'));
            await tester.pumpAndSettle();
            expect(find.text('Restore this backup?'), findsNothing);
            expect(
              (await BackupRepository(database).exportAll()).dataJson(),
              before.dataJson(),
            );

            await _revealAndTap(
              tester,
              find.byKey(const ValueKey('backup-import')),
            );
            await tester.tap(
              find.byKey(const ValueKey('backup-restore-confirm')),
            );
            await tester.pumpAndSettle();

            expect(find.text('Restore complete'), findsOneWidget);
            expect(
              find.textContaining('Restored 2 lists, 3 tasks, 2 subtasks'),
              findsOneWidget,
            );
            await tester.tap(find.text('Done'));
            await tester.pumpAndSettle();

            final after = await BackupRepository(database).exportAll();
            expect(after.dataJson(), document.dataJson());
          },
          fileStore: store,
          scheduler: scheduler,
        );
      },
    );

    testWidgets('a malformed backup is rejected without touching data', (
      tester,
    ) async {
      final database = await openInMemoryDatabase();
      addTearDown(database.close);
      mockPackageInfo();
      await _seedLocalTask(database);
      final before = await BackupRepository(database).exportAll();

      final store = FakeBackupFileStore(
        openBytes: utf8.encode(
          '{"format":"xenndo-backup","version":99,"schemaVersion":3,'
          '"exportedAt":"2026-10-19T12:00:00.000Z","data":{}}',
        ),
      );

      await _openSettings(tester, database, () async {
        await _revealAndTap(
          tester,
          find.byKey(const ValueKey('backup-import')),
        );

        expect(find.text('Could not open the backup'), findsOneWidget);
        expect(
          find.textContaining('Backup version 99 is not supported'),
          findsOneWidget,
        );
        expect(find.textContaining('Nothing was changed.'), findsOneWidget);

        await tester.tap(find.text('Close'));
        await tester.pumpAndSettle();
        expect(
          (await BackupRepository(database).exportAll()).dataJson(),
          before.dataJson(),
        );
      }, fileStore: store);
    });
  });
}
