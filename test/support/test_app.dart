import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xenndo/app/app.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/core/database/database_provider.dart';
import 'package:xenndo/core/database/inbox_defaults.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/features/lists/application/list_providers.dart';
import 'package:xenndo/features/lists/domain/task_list_model.dart';
import 'package:xenndo/features/progress/application/progress_providers.dart';
import 'package:xenndo/features/reminders/application/reminder_providers.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/today/application/focus_providers.dart';
import 'package:xenndo/features/today/domain/today_agenda.dart';

import 'test_database.dart';

DateTime testNow() => DateTime(2026, 10, 19, 12);

/// Stubs the platform package metadata so the About section has a known value.
void mockPackageInfo() {
  PackageInfo.setMockInitialValues(
    appName: 'XennDo',
    packageName: 'com.xennzeru.xenndo',
    version: '1.0.0',
    buildNumber: '1',
    buildSignature: 'test',
  );
}

final _inboxTimestamp = DateTime.utc(2026, 1, 1);

final _inboxList = TaskListModel(
  id: InboxDefaults.id,
  name: InboxDefaults.name,
  color: InboxDefaults.color,
  icon: InboxDefaults.icon,
  sortOrder: 0,
  isInbox: true,
  createdAt: _inboxTimestamp,
  updatedAt: _inboxTimestamp,
);

final _inboxSummary = TaskListSummary(
  id: InboxDefaults.id,
  name: InboxDefaults.name,
  color: InboxDefaults.color,
  icon: InboxDefaults.icon,
  sortOrder: 0,
  isInbox: true,
  openTaskCount: 0,
);

/// Pumps the app with an in-memory database.
///
/// Stream-backed providers are overridden with static values so widget tests
/// do not leave Drift stream timers pending. Repository behavior is covered by
/// `test/database/repository_test.dart`.
Future<AppDatabase> pumpXenndoApp(
  WidgetTester tester, {
  DateTime? now,
  ReminderScheduler? reminderScheduler,
}) async {
  final database = await openInMemoryDatabase();
  addTearDown(database.close);
  mockPackageInfo();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        nowProvider.overrideWithValue(() => now ?? testNow()),
        listsProvider.overrideWith((ref) => Stream.value([_inboxList])),
        listSummariesProvider.overrideWith(
          (ref) => Stream.value([_inboxSummary]),
        ),
        todayAgendaProvider.overrideWith(
          (ref) => Stream.value(
            const TodayAgenda(overdue: [], dueToday: [], completedToday: []),
          ),
        ),
        upcomingTasksProvider.overrideWith((ref) => Stream.value(const [])),
        topThreeProvider.overrideWith((ref) => Stream.value(const [])),
        completedTodayProvider.overrideWith((ref) => Stream.value(const [])),
        dueTodayTasksProvider.overrideWith((ref) => Stream.value(const [])),
        lastSevenDayCompletionsProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        if (reminderScheduler != null)
          reminderSchedulerProvider.overrideWithValue(reminderScheduler),
      ],
      child: const XenndoApp(),
    ),
  );
  await tester.pumpAndSettle();
  return database;
}

/// Pumps the app with real Riverpod/Drift stream providers.
///
/// Call [disposeXenndoApp] before the test ends so Drift stream timers are
/// flushed instead of failing the pending-timer check.
Future<AppDatabase> pumpXenndoAppLive(
  WidgetTester tester, {
  DateTime? now,
  AppDatabase? database,
  ReminderScheduler? reminderScheduler,
}) async {
  final ownsDatabase = database == null;
  database ??= await openInMemoryDatabase();
  if (ownsDatabase) {
    addTearDown(database.close);
  }
  mockPackageInfo();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        if (reminderScheduler != null)
          reminderSchedulerProvider.overrideWithValue(reminderScheduler),
        nowProvider.overrideWithValue(() => now ?? testNow()),
      ],
      child: const XenndoApp(),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
  return database;
}

Future<void> disposeXenndoApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
