import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/features/lists/data/list_repository.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';
import 'package:xenndo/features/tasks/domain/task_draft.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';

import 'support/test_app.dart';

final _now = DateTime(2026, 10, 19, 12);

Future<void> _showResults(WidgetTester tester) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const ValueKey('search-screen')),
        matching: find.byType(Scrollable),
      )
      .first;
  final position = tester.state<ScrollableState>(scrollable).position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('search and combined filters narrow results and clear', (
    tester,
  ) async {
    final database = await pumpXenndoAppLive(tester, now: _now);
    final lists = ListRepository(database, clock: () => _now);
    final tasks = TaskRepository(database, clock: () => _now);

    final workId = await lists.createList(name: 'Work', color: 0xFF111111);
    await lists.createList(name: 'Personal', color: 0xFF222222);
    await tasks.createTask(
      TaskDraft(
        title: 'Alpha report',
        description: 'Quarterly numbers',
        listId: workId,
        priority: TaskPriority.high,
      ),
    );
    final betaId = await tasks.createTask(
      const TaskDraft(title: 'Beta errand', priority: TaskPriority.low),
    );
    await tasks.setTaskCompleted(betaId, true);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('search-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('search-screen')), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('search-query-field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('search-query-field')),
      'report',
    );
    await tester.pumpAndSettle();
    await _showResults(tester);
    expect(find.text('Alpha report'), findsOneWidget);
    expect(find.text('Beta errand'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('search-query-field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('search-query-field')),
      'quarterly',
    );
    await tester.pumpAndSettle();
    await _showResults(tester);
    expect(find.text('Alpha report'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('search-query-field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('search-query-field')),
      '',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(ValueKey('filter-list-$workId')));
    await tester.tap(find.byKey(ValueKey('filter-list-$workId')));
    await tester.pumpAndSettle();
    await _showResults(tester);
    expect(find.text('Alpha report'), findsOneWidget);
    expect(find.text('Beta errand'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('filter-completion-completed')),
    );
    await tester.tap(find.byKey(const ValueKey('filter-completion-completed')));
    await tester.pumpAndSettle();
    expect(find.text('No matching tasks'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const ValueKey('search-clear-filters')),
    );
    await tester.tap(find.byKey(const ValueKey('search-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.text('2 matching tasks'), findsOneWidget);
    await _showResults(tester);
    expect(find.text('Alpha report'), findsOneWidget);
    expect(find.text('Beta errand'), findsOneWidget);

    await disposeXenndoApp(tester);
  });
}
