import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';
import 'package:xenndo/features/tasks/domain/task_draft.dart';
import 'package:xenndo/features/today/data/focus_repository.dart';

import 'support/test_app.dart';

final _now = DateTime(2026, 10, 19, 12);
final _today = LocalDate(2026, 10, 19);

void main() {
  testWidgets('My Top 3 selection enforces limits and updates Today', (
    tester,
  ) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    final repository = TaskRepository(database, clock: () => _now);
    final focusRepository = FocusRepository(database);

    final taskIds = <String>[];
    for (final title in ['Focus A', 'Focus B', 'Focus C', 'Focus D']) {
      taskIds.add(await repository.createTask(TaskDraft(title: title)));
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('choose-focus-task')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('top-three-picker-screen')),
      findsOneWidget,
    );

    for (final taskId in taskIds.take(3)) {
      final choice = find.byKey(ValueKey('focus-choice-$taskId'));
      await tester.ensureVisible(choice);
      await tester.tap(choice);
      await tester.pumpAndSettle();
    }

    final fourth = find.byKey(ValueKey('focus-choice-${taskIds[3]}'));
    await tester.ensureVisible(fourth);
    await tester.tap(fourth);
    await tester.pumpAndSettle();
    expect(
      find.text('My Top 3 already has three tasks for today.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('top-three-done')));
    await tester.pumpAndSettle();
    // Let the previously asserted limit notice leave before opening row menus.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('focus-checkbox-2')), findsOneWidget);
    expect(find.text('Focus A'), findsOneWidget);

    final beforeReorder = await focusRepository.getFocusSelections(_today);
    await tester.tap(find.byKey(const ValueKey('focus-menu-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-move-down')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    final afterReorder = await focusRepository.getFocusSelections(_today);
    expect(afterReorder.first.taskId, isNot(beforeReorder.first.taskId));

    await tester.tap(find.byKey(const ValueKey('focus-menu-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-remove')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    expect(await focusRepository.getFocusSelections(_today), hasLength(2));

    final remaining = await focusRepository.getFocusSelections(_today);
    tester
        .widget<Checkbox>(find.byKey(const ValueKey('focus-checkbox-0')))
        .onChanged!(true);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    final completedTask = await repository.getTask(remaining.first.taskId);
    expect(completedTask!.isCompleted, isTrue);
    expect(find.text(completedTask.title), findsOneWidget);

    await disposeXenndoApp(tester);
  });
}
