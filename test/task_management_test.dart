import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/core/database/inbox_defaults.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';
import 'package:xenndo/features/tasks/domain/subtask_draft.dart';
import 'package:xenndo/features/tasks/domain/task_draft.dart';
import 'package:xenndo/features/tasks/presentation/widgets/task_row.dart';

import 'support/test_app.dart';

final _now = DateTime(2026, 10, 19, 12);

Future<void> _openLists(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-lists')));
  await tester.pumpAndSettle();
}

Future<void> _openList(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

Future<void> _selectMenu(
  WidgetTester tester,
  String listId,
  String value,
) async {
  final menu = tester.widget<PopupMenuButton<String>>(
    find.byKey(ValueKey('list-menu-$listId')),
  );
  menu.onSelected!(value);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create, rename, recolor, and delete a list', (tester) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    final repository = TaskRepository(database, clock: () => _now);

    await _openLists(tester);

    await tester.tap(find.byKey(const ValueKey('create-list-action')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('list-name-field')),
      'Projects',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-list-form')));
    await tester.pumpAndSettle();

    final projects = (await database.select(database.taskLists).get())
        .firstWhere((list) => list.name == 'Projects');
    expect(find.text('Projects'), findsOneWidget);

    await _selectMenu(tester, projects.id, 'rename');
    await tester.enterText(
      find.byKey(const ValueKey('list-name-field')),
      'Projects 2026',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-list-form')));
    await tester.pumpAndSettle();
    expect(find.text('Projects 2026'), findsOneWidget);

    await _selectMenu(tester, projects.id, 'recolor');
    await tester.tap(find.byKey(const ValueKey('list-color-4281298925')));
    await tester.tap(find.byKey(const ValueKey('confirm-list-form')));
    await tester.pumpAndSettle();

    final recolored = (await database.select(database.taskLists).get())
        .firstWhere((list) => list.id == projects.id);
    expect(recolored.color, 0xFF2F6FED);

    final taskId = await repository.createTask(
      TaskDraft(title: 'Move me', listId: projects.id),
    );
    await tester.pumpAndSettle();

    await _selectMenu(tester, projects.id, 'delete');
    expect(find.textContaining('move to Inbox'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-delete-list')));
    await tester.pumpAndSettle();

    final moved = await repository.getTask(taskId);
    expect(moved!.listId, InboxDefaults.id);
    final remaining = await database.select(database.taskLists).get();
    expect(remaining.map((list) => list.id), isNot(contains(projects.id)));

    await disposeXenndoApp(tester);
  });

  testWidgets('completing all subtasks does not complete the parent task', (
    tester,
  ) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    final repository = TaskRepository(database, clock: () => _now);
    final taskId = await repository.createTask(
      const TaskDraft(
        title: 'Parent',
        subtasks: [
          SubtaskDraft(title: 'One'),
          SubtaskDraft(title: 'Two'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await _openLists(tester);
    await _openList(tester, 'Inbox');
    await tester.tap(find.text('Parent'));
    await tester.pumpAndSettle();

    final checkboxes = find.byKey(const ValueKey('subtask-checkbox-0'));
    await tester.ensureVisible(checkboxes);
    await tester.tap(checkboxes);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('subtask-checkbox-1')));
    await tester.pumpAndSettle();

    final parent = await repository.getTask(taskId);
    expect(parent!.isCompleted, isFalse);

    await disposeXenndoApp(tester);
  });

  testWidgets('list detail shows completed tasks and can reopen them', (
    tester,
  ) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    final repository = TaskRepository(database, clock: () => _now);
    await repository.createTask(const TaskDraft(title: 'Open task'));
    final doneId = await repository.createTask(
      const TaskDraft(title: 'Done task'),
    );
    await repository.setTaskCompleted(
      doneId,
      true,
      completedAt: DateTime(2026, 10, 19, 8).toUtc(),
    );
    await tester.pumpAndSettle();

    await _openLists(tester);
    await _openList(tester, 'Inbox');

    expect(find.byKey(const ValueKey('list-detail-screen')), findsOneWidget);
    expect(find.text('Open task'), findsOneWidget);
    expect(find.text('Done task'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);

    final doneRow = find.ancestor(
      of: find.text('Done task'),
      matching: find.byType(TaskRow),
    );
    await tester.tap(
      find.descendant(of: doneRow, matching: find.byType(Checkbox)),
    );
    await tester.pumpAndSettle();

    final reopened = await repository.getTask(doneId);
    expect(reopened!.isCompleted, isFalse);

    await disposeXenndoApp(tester);
  });

  testWidgets('editing a task persists changes', (tester) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    final repository = TaskRepository(database, clock: () => _now);
    final taskId = await repository.createTask(
      const TaskDraft(title: 'Original title'),
    );
    await tester.pumpAndSettle();

    await _openLists(tester);
    await _openList(tester, 'Inbox');
    await tester.tap(find.text('Original title'));
    await tester.pumpAndSettle();

    expect(find.text('Edit task'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Updated title',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('save-task-button')));
    await tester.tap(find.byKey(const ValueKey('save-task-button')));
    await tester.pumpAndSettle();

    final updated = await repository.getTask(taskId);
    expect(updated!.title, 'Updated title');
    expect(find.byKey(const ValueKey('list-detail-screen')), findsOneWidget);

    await disposeXenndoApp(tester);
  });

  testWidgets('deleting a task offers undo and restores it', (tester) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    final repository = TaskRepository(database, clock: () => _now);
    final taskId = await repository.createTask(
      const TaskDraft(
        title: 'Delete me',
        subtasks: [SubtaskDraft(title: 'Child')],
      ),
    );
    await tester.pumpAndSettle();

    await _openLists(tester);
    await _openList(tester, 'Inbox');
    await tester.tap(find.text('Delete me'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('delete-task-action')));
    await tester.pumpAndSettle();
    expect(await repository.getTask(taskId), isNull);

    expect(find.text('Undo'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    final restored = await repository.getTask(taskId);
    expect(restored, isNotNull);
    expect(restored!.title, 'Delete me');
    expect(await repository.getSubtasks(taskId), hasLength(1));

    await disposeXenndoApp(tester);
  });

  testWidgets('validates blank list names and blank subtasks', (tester) async {
    await pumpXenndoApp(tester, now: _now);

    await _openLists(tester);
    await tester.tap(find.byKey(const ValueKey('create-list-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-list-form')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a list name.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav-today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-task-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Valid title',
    );
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
    await tester.ensureVisible(find.byKey(const ValueKey('save-task-button')));
    await tester.tap(find.byKey(const ValueKey('save-task-button')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a subtask title.'), findsOneWidget);
  });
}
