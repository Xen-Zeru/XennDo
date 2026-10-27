import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/app/app.dart';
import 'package:xenndo/core/database/database_provider.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';
import 'package:xenndo/features/tasks/domain/task_draft.dart';

import 'support/test_app.dart';
import 'support/test_database.dart';

void main() {
  testWidgets('resuming on a new local day refreshes date-based views', (
    tester,
  ) async {
    final database = await openInMemoryDatabase();
    addTearDown(database.close);

    var currentNow = DateTime(2026, 10, 19, 12);
    final repository = TaskRepository(database, clock: () => currentNow);
    await repository.createTask(
      TaskDraft(title: 'Rollover task', dueDate: LocalDate(2026, 10, 19)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          nowProvider.overrideWithValue(() => currentNow),
        ],
        child: const XenndoApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Remaining today'), findsOneWidget);
    expect(find.text('Rollover task'), findsOneWidget);

    currentNow = DateTime(2026, 10, 20, 8);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Rollover task'), findsOneWidget);
    final expectedDate = MaterialLocalizations.of(
      tester.element(find.byKey(const ValueKey('today-screen'))),
    ).formatMediumDate(DateTime(2026, 10, 20, 8));
    expect(find.text(expectedDate), findsOneWidget);

    await disposeXenndoApp(tester);
  });
  testWidgets('timed tasks move into overdue while Today stays open', (
    tester,
  ) async {
    final database = await openInMemoryDatabase();
    addTearDown(database.close);
    var now = DateTime(2026, 10, 19, 12);
    await TaskRepository(database, clock: () => now).createTask(
      TaskDraft(
        title: 'Minute boundary',
        dueDate: LocalDate(2026, 10, 19),
        dueTimeMinutes: 12 * 60 + 1,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          nowProvider.overrideWithValue(() => now),
        ],
        child: const XenndoApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Remaining today'), findsOneWidget);
    now = DateTime(2026, 10, 19, 12, 1, 1);
    await tester.pump(const Duration(seconds: 61));
    await tester.pumpAndSettle();
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('Remaining today'), findsNothing);
    await disposeXenndoApp(tester);
  });
}
