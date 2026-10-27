import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/core/database/database_provider.dart';
import 'package:xenndo/core/database/inbox_defaults.dart';
import 'package:xenndo/core/theme/app_theme.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/lists/application/list_providers.dart';
import 'package:xenndo/features/lists/domain/task_list_model.dart';
import 'package:xenndo/features/tasks/domain/subtask_draft.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';
import 'package:xenndo/features/tasks/presentation/task_editor_screen.dart';

import 'support/test_app.dart';
import 'support/test_database.dart';

void main() {
  testWidgets('add task layout validates and saves a persisted task', (
    tester,
  ) async {
    final database = await pumpXenndoApp(
      tester,
      now: DateTime(2026, 10, 19, 12),
    );

    await tester.tap(find.byKey(const ValueKey('add-task-fab')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('task-title-field')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('task-description-section')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('task-description-section')),
    );
    await tester.tap(find.byKey(const ValueKey('task-description-section')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('task-description-field')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('task-list-field')), findsOneWidget);
    for (final priority in TaskPriority.selectable) {
      expect(find.byKey(ValueKey('priority-${priority.name}')), findsOneWidget);
    }
    final defaultPriority = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('priority-medium')),
    );
    expect(defaultPriority.selected, isTrue);
    await tester.ensureVisible(
      find.byKey(const ValueKey('task-schedule-section')),
    );
    await tester.tap(find.byKey(const ValueKey('task-schedule-section')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('due-date-tile')), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder-switch')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('task-subtasks-section')),
    );
    await tester.tap(find.byKey(const ValueKey('task-subtasks-section')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('add-subtask-button')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('save-task-button')));
    await tester.tap(find.byKey(const ValueKey('save-task-button')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a task title.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Plan the week',
    );
    await tester.tap(find.byKey(const ValueKey('priority-high')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('task-subtasks-section')),
    );
    await tester.tap(find.byKey(const ValueKey('task-subtasks-section')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('add-subtask-button')),
    );
    await tester.tap(find.byKey(const ValueKey('add-subtask-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('subtask-field-0')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('subtask-field-0')));
    await tester.enterText(
      find.byKey(const ValueKey('subtask-field-0')),
      'List three priorities',
    );

    final highChip = tester.widget<ChoiceChip>(
      find.byKey(const ValueKey('priority-high')),
    );
    expect(highChip.selected, isTrue);

    await tester.ensureVisible(find.byKey(const ValueKey('save-task-button')));
    await tester.tap(find.byKey(const ValueKey('save-task-button')));
    await tester.pumpAndSettle();

    final tasks = await database.select(database.tasks).get();
    expect(tasks, hasLength(1));
    expect(tasks.single.title, 'Plan the week');
    expect(tasks.single.priority, TaskPriority.high.rank);

    final subtasks = await database.select(database.subtasks).get();
    expect(subtasks.map((subtask) => subtask.title), ['List three priorities']);
  });

  testWidgets('edit layout shows due time and reminder from initial values', (
    tester,
  ) async {
    final database = await openInMemoryDatabase();
    addTearDown(database.close);

    final inbox = TaskListModel(
      id: InboxDefaults.id,
      name: InboxDefaults.name,
      color: InboxDefaults.color,
      icon: InboxDefaults.icon,
      sortOrder: 0,
      isInbox: true,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          listsProvider.overrideWith((ref) => Stream.value([inbox])),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          home: TaskEditorScreen(
            initialValues: TaskEditorInitialValues(
              taskId: 'existing-task',
              title: 'Existing task',
              description: 'A task with details.',
              priority: TaskPriority.medium,
              dueDate: LocalDate(2026, 10, 20),
              dueTimeMinutes: 10 * 60 + 30,
              reminderEnabled: true,
              reminderDate: LocalDate(2026, 10, 20),
              reminderTimeMinutes: 10 * 60 + 30,
              subtasks: const [SubtaskDraft(title: 'First step')],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Edit task'), findsOneWidget);
    expect(find.text('Existing task'), findsOneWidget);
    expect(find.byKey(const ValueKey('due-time-tile')), findsOneWidget);
    expect(find.byKey(const ValueKey('subtask-field-0')), findsOneWidget);
    expect(find.text('First step'), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder-date-tile')), findsOneWidget);
    expect(find.byKey(const ValueKey('reminder-time-tile')), findsOneWidget);

    final reminderSwitch = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('reminder-switch')),
    );
    expect(reminderSwitch.onChanged, isNotNull);
    expect(reminderSwitch.value, isTrue);
  });
}
