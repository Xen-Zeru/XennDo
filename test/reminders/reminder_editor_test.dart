import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';

import '../support/test_app.dart';
import 'fake_reminder_scheduler.dart';

void main() {
  Future<void> openEditor(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('add-task-fab')));
    await tester.pumpAndSettle();
  }

  testWidgets('denied permission explains and keeps the reminder off', (
    tester,
  ) async {
    final scheduler = FakeReminderScheduler()
      ..permission = ReminderPermissionStatus.denied;
    await pumpXenndoApp(
      tester,
      now: DateTime(2026, 10, 19, 12),
      reminderScheduler: scheduler,
    );
    await openEditor(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('task-schedule-section')),
    );
    await tester.tap(find.byKey(const ValueKey('task-schedule-section')));
    await tester.pumpAndSettle();

    tester
        .widget<SwitchListTile>(find.byKey(const ValueKey('reminder-switch')))
        .onChanged!(true);
    await tester.pumpAndSettle();

    expect(find.text('Notifications are off'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('open-notification-settings')),
      findsOneWidget,
    );

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('reminder-switch')),
    );
    expect(switchTile.value, isFalse);
  });

  testWidgets('denied permission can open system notification settings', (
    tester,
  ) async {
    final scheduler = FakeReminderScheduler()
      ..permission = ReminderPermissionStatus.denied;
    await pumpXenndoApp(
      tester,
      now: DateTime(2026, 10, 19, 12),
      reminderScheduler: scheduler,
    );
    await openEditor(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('task-schedule-section')),
    );
    await tester.tap(find.byKey(const ValueKey('task-schedule-section')));
    await tester.pumpAndSettle();

    tester
        .widget<SwitchListTile>(find.byKey(const ValueKey('reminder-switch')))
        .onChanged!(true);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-notification-settings')));
    await tester.pumpAndSettle();

    expect(scheduler.openSettingsCalled, isTrue);
  });

  testWidgets('granted permission saves an explicit reminder date and time', (
    tester,
  ) async {
    final scheduler = FakeReminderScheduler()
      ..permission = ReminderPermissionStatus.granted;
    final database = await pumpXenndoApp(
      tester,
      now: DateTime(2026, 10, 19, 12),
      reminderScheduler: scheduler,
    );
    await openEditor(tester);
    await tester.ensureVisible(
      find.byKey(const ValueKey('task-schedule-section')),
    );
    await tester.tap(find.byKey(const ValueKey('task-schedule-section')));
    await tester.pumpAndSettle();

    tester
        .widget<SwitchListTile>(find.byKey(const ValueKey('reminder-switch')))
        .onChanged!(true);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reminder-date-tile')), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder-time-tile')), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Remind me',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-task-button')));
    await tester.tap(find.byKey(const ValueKey('save-task-button')));
    await tester.pumpAndSettle();

    final tasks = await database.select(database.tasks).get();
    expect(tasks, hasLength(1));
    expect(tasks.single.reminderDate, isNotNull);
    expect(tasks.single.reminderTimeMinutes, isNotNull);
    expect(tasks.single.notificationId, isNotNull);
    expect(scheduler.scheduled, hasLength(1));
  });
}
