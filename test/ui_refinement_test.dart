import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';
import 'package:xenndo/features/tasks/domain/task_draft.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';
import 'package:xenndo/features/lists/data/list_repository.dart';
import 'package:xenndo/features/tasks/domain/subtask_draft.dart';
import 'package:xenndo/features/tasks/presentation/widgets/task_row.dart';
import 'package:xenndo/features/today/presentation/widgets/top_three_card.dart';
import 'package:xenndo/features/today/data/focus_repository.dart';

import 'support/test_app.dart';

final _now = DateTime(2026, 10, 19, 12);
final _today = LocalDate(2026, 10, 19);

void main() {
  testWidgets('Today does not duplicate focus tasks in its agenda sections', (
    tester,
  ) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    final tasks = TaskRepository(database, clock: () => _now);
    final overdueId = await tasks.createTask(
      TaskDraft(title: 'Focus overdue', dueDate: _today.addDays(-1)),
    );
    await tasks.createTask(TaskDraft(title: 'Due today task', dueDate: _today));
    await FocusRepository(database).addToFocus(date: _today, taskId: overdueId);
    await tester.pumpAndSettle();

    expect(find.text('Focus overdue'), findsOneWidget);
    expect(find.text('Due today task'), findsOneWidget);
    expect(find.textContaining('Overdue · Yesterday'), findsOneWidget);
    await disposeXenndoApp(tester);
  });

  testWidgets('Upcoming date-strip selection scrolls without filtering tasks', (
    tester,
  ) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    final tasks = TaskRepository(database, clock: () => _now);
    await tasks.createTask(
      TaskDraft(title: 'First upcoming task', dueDate: _today.addDays(1)),
    );
    await tasks.createTask(
      TaskDraft(title: 'Second upcoming task', dueDate: _today.addDays(2)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-upcoming')));
    await tester.pumpAndSettle();

    final scrollable = find
        .descendant(
          of: find.byKey(const ValueKey('upcoming-screen')),
          matching: find.byType(Scrollable),
        )
        .first;
    final before = tester.state<ScrollableState>(scrollable).position.pixels;
    await tester.tap(find.byKey(const ValueKey('upcoming-date-2026-10-21')));
    await tester.pumpAndSettle();
    final after = tester.state<ScrollableState>(scrollable).position.pixels;

    expect(after, greaterThan(before));
    expect(find.text('First upcoming task'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Second upcoming task'),
      140,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('upcoming-screen')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Second upcoming task'), findsOneWidget);
    await disposeXenndoApp(tester);
  });

  testWidgets('Upcoming shows a seven-day strip and keeps tasks visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final database = await pumpXenndoAppLive(tester, now: _now);
    final tasks = TaskRepository(database, clock: () => _now);
    await tasks.createTask(
      TaskDraft(title: 'First upcoming task', dueDate: _today.addDays(1)),
    );
    await tasks.createTask(
      TaskDraft(title: 'Second upcoming task', dueDate: _today.addDays(2)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-upcoming')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('upcoming-date-strip')), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('upcoming-date-2026-10-22')),
    );
    await tester.tap(find.byKey(const ValueKey('upcoming-date-2026-10-22')));
    await tester.pumpAndSettle();

    expect(find.text('First upcoming task'), findsOneWidget);
    expect(find.textContaining('No upcoming tasks on'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Second upcoming task'),
      140,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('upcoming-screen')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Second upcoming task'), findsOneWidget);
    await disposeXenndoApp(tester);
  });

  testWidgets('Today handles long titles and three focus rows at large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    final database = await pumpXenndoAppLive(tester, now: _now);
    final tasks = TaskRepository(database, clock: () => _now);
    final focusIds = [
      await tasks.createTask(
        TaskDraft(
          title: 'A very long task title that still needs to remain readable on a small phone',
          dueDate: _today.addDays(-1),
        ),
      ),
      await tasks.createTask(
        TaskDraft(title: 'Second focus task', dueDate: _today),
      ),
      await tasks.createTask(TaskDraft(title: 'Third focus task')),
    ];
    final focus = FocusRepository(database);
    for (final id in focusIds) {
      await focus.addToFocus(date: _today, taskId: id);
    }
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('focus-checkbox-2')), findsOneWidget);
    expect(find.textContaining('A very long task title'), findsOneWidget);
    expect(find.textContaining('Overdue · Yesterday'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeXenndoApp(tester);
  });

  testWidgets('unsaved task edits require an explicit discard confirmation', (
    tester,
  ) async {
    await pumpXenndoApp(tester, now: _now);
    await tester.tap(find.byKey(const ValueKey('add-task-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Keep this draft',
    );
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Keep this draft'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-editor-screen')), findsNothing);
  });
  testWidgets('completion changes only completion; tapping the title edits', (
    tester,
  ) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    final repository = TaskRepository(database, clock: () => _now);
    final taskId = await repository.createTask(
      TaskDraft(
        title: 'Task with steps',
        dueDate: _today,
        subtasks: const [
          SubtaskDraft(title: 'First', isCompleted: true),
          SubtaskDraft(title: 'Second'),
        ],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 of 2 subtasks'), findsOneWidget);
    final row = find.ancestor(
      of: find.text('Task with steps'),
      matching: find.byType(TaskRow),
    );
    await tester.tap(find.descendant(of: row, matching: find.byType(Checkbox)));
    await tester.pumpAndSettle();
    expect((await repository.getTask(taskId))!.isCompleted, isTrue);
    expect(find.byKey(const ValueKey('task-editor-screen')), findsNothing);
    expect(find.text('Task with steps'), findsOneWidget);
    await tester.tap(find.text('Task with steps'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-editor-screen')), findsOneWidget);
    expect(find.text('Task with steps'), findsOneWidget);
    await disposeXenndoApp(tester);
  });

  testWidgets(
    'focus edit mode exposes drag handles; completed tasks stay unique',
    (tester) async {
      final database = await pumpXenndoAppLive(tester, now: _now);
      final repository = TaskRepository(database, clock: () => _now);
      final focus = FocusRepository(database);
      final ids = <String>[];
      for (final title in ['First focus', 'Second focus', 'Third focus']) {
        final id = await repository.createTask(
          TaskDraft(title: title, dueDate: _today),
        );
        ids.add(id);
        await focus.addToFocus(date: _today, taskId: id);
      }
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableDragStartListener), findsNothing);
      await tester.tap(find.byKey(const ValueKey('focus-menu-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('edit-focus')));
      await tester.pumpAndSettle();
      expect(find.byType(ReorderableDragStartListener), findsNWidgets(3));
      await tester.tap(find.byKey(const ValueKey('focus-checkbox-0')));
      await tester.pumpAndSettle();
      expect((await repository.getTask(ids.first))!.isCompleted, isTrue);
      expect(find.text('First focus'), findsOneWidget);
      final focusCard = find.byType(TopThreeCard);
      expect(
        find.descendant(of: focusCard, matching: find.text('First focus')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('focus-checkbox-0')));
      await tester.pumpAndSettle();
      expect((await repository.getTask(ids.first))!.isCompleted, isFalse);
      expect(find.text('First focus'), findsOneWidget);
      await disposeXenndoApp(tester);
    },
  );

  testWidgets(
    'subtask counts update when steps change without completing parent',
    (tester) async {
      final database = await pumpXenndoAppLive(tester, now: _now);
      final repository = TaskRepository(database, clock: () => _now);
      final id = await repository.createTask(
        TaskDraft(
          title: 'Parent',
          dueDate: _today,
          subtasks: const [SubtaskDraft(title: 'Step')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 of 1 subtasks'), findsOneWidget);
      final subtasks = await repository.getSubtasks(id);
      await repository.setSubtaskCompleted(subtasks.single.id, true);
      await tester.pumpAndSettle();
      expect(find.text('1 of 1 subtasks'), findsOneWidget);
      expect((await repository.getTask(id))!.isCompleted, isFalse);
      await disposeXenndoApp(tester);
    },
  );

  testWidgets('date strip retains earlier dates after a selection', (
    tester,
  ) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    final repository = TaskRepository(database, clock: () => _now);
    await repository.createTask(
      TaskDraft(title: 'Tomorrow task', dueDate: _today.addDays(1)),
    );
    await repository.createTask(
      TaskDraft(title: 'Later task', dueDate: _today.addDays(2)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-upcoming')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('upcoming-date-2026-10-21')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('upcoming-date-2026-10-20')),
      findsOneWidget,
    );
    expect(find.text('Tomorrow task'), findsOneWidget);
    expect(find.text('Later task'), findsOneWidget);
    await disposeXenndoApp(tester);
  });

  testWidgets(
    'Save and validation stay usable with a keyboard on a small screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final database = await pumpXenndoAppLive(tester, now: _now);
      await tester.tap(find.byKey(const ValueKey('add-task-fab')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('save-task-button'));
      expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(440));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Enter a task title.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Keyboard task',
      );
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('task-editor-screen')), findsNothing);
      expect(
        (await database.select(database.tasks).get()).single.title,
        'Keyboard task',
      );
      await disposeXenndoApp(tester);
    },
  );
  testWidgets('failed saves retain the draft and its unsaved-edit guard', (
    tester,
  ) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    await database.customStatement(
      "CREATE TRIGGER fail_task_save BEFORE INSERT ON tasks BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await tester.tap(find.byKey(const ValueKey('add-task-fab')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('task-title-field')),
      'Preserve this task',
    );
    await tester.tap(find.byKey(const ValueKey('save-task-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save this task. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Preserve this task'), findsOneWidget);
    expect(await database.select(database.tasks).get(), isEmpty);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Preserve this task'), findsOneWidget);
    await disposeXenndoApp(tester);
  });
  testWidgets(
    'date picker scrolls to a distant group and preserves all tasks',
    (tester) async {
      final database = await pumpXenndoAppLive(tester, now: _now);
      final repository = TaskRepository(database, clock: () => _now);
      await repository.createTask(
        TaskDraft(title: 'Near task', dueDate: _today.addDays(1)),
      );
      await repository.createTask(
        TaskDraft(title: 'Distant task', dueDate: LocalDate(2026, 12, 1)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-upcoming')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('upcoming-date-picker')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '12/01/2026');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Near task'), findsOneWidget);
      expect(find.text('Distant task'), findsOneWidget);
      final screen = tester.getRect(
        find.byKey(const ValueKey('upcoming-screen')),
      );
      expect(
        screen.overlaps(tester.getRect(find.text('Distant task'))),
        isTrue,
      );
      await disposeXenndoApp(tester);
    },
  );

  testWidgets(
    'populated dark screens fit long titles and list names at 200 percent',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      final database = await pumpXenndoAppLive(tester, now: _now);
      final listId = await ListRepository(database).createList(
        name: 'A long list name that wraps across several lines',
        color: 0xFF6A4FB6,
      );
      final repository = TaskRepository(database, clock: () => _now);
      await repository.createTask(
        TaskDraft(
          title: 'A long task title that should wrap clearly across lines',
          listId: listId,
          dueDate: _today,
          priority: TaskPriority.high,
        ),
      );
      await repository.createTask(
        TaskDraft(
          title: 'A future task with a long title for a very small screen',
          listId: listId,
          dueDate: _today.addDays(1),
          priority: TaskPriority.high,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('theme-dark')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(find.byKey(const ValueKey('add-task-fab')), findsNothing);
      for (final destination in [
        'nav-today',
        'nav-upcoming',
        'nav-lists',
        'nav-settings',
      ]) {
        await tester.tap(find.byKey(ValueKey(destination)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: destination);
      }
      await disposeXenndoApp(tester);
    },
  );
  testWidgets('dragging a focus handle persists the reordered selections', (
    tester,
  ) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    final repository = TaskRepository(database, clock: () => _now);
    final focus = FocusRepository(database);
    final first = await repository.createTask(TaskDraft(title: 'Drag first'));
    final second = await repository.createTask(TaskDraft(title: 'Drag second'));
    await focus.addToFocus(date: _today, taskId: first);
    await focus.addToFocus(date: _today, taskId: second);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-menu-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('edit-focus')));
    await tester.pumpAndSettle();
    final secondRect = tester.getRect(
      find.byKey(ValueKey('focus-task-$second')),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(ReorderableDragStartListener).first),
    );
    await tester.pump();
    // Real touch drags cross the insertion threshold across several frames.
    for (var step = 0; step < 10; step++) {
      await gesture.moveBy(Offset(0, secondRect.height / 10));
      await tester.pump(const Duration(milliseconds: 32));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      (await focus.getFocusSelections(_today))
          .map((selection) => selection.taskId),
      [second, first],
    );
    await disposeXenndoApp(tester);
  });
  testWidgets(
    'list progress is labeled and task creation stays in list details',
    (tester) async {
      final database = await pumpXenndoAppLive(tester, now: _now);
      final repository = TaskRepository(database, clock: () => _now);
      final taskId = await repository.createTask(
        const TaskDraft(title: 'Complete one'),
      );
      await repository.createTask(const TaskDraft(title: 'Leave one open'));
      await repository.setTaskCompleted(taskId, true);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('nav-lists')));
      await tester.pumpAndSettle();
      expect(find.byTooltip('1 of 2 tasks complete'), findsOneWidget);
      expect(find.text('1 open task'), findsOneWidget);
      expect(find.byKey(const ValueKey('add-task-fab')), findsNothing);
      await tester.tap(find.text('Inbox'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('list-add-task-action')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('task-editor-screen')), findsOneWidget);
      await disposeXenndoApp(tester);
    },
  );
}
