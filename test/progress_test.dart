import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/progress/domain/progress_summary.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';
import 'package:xenndo/features/tasks/domain/task_draft.dart';

import 'support/test_app.dart';
import 'support/test_database.dart';

void main() {
  group('progress calculations', () {
    test('lastDays returns the window ending today, oldest day first', () {
      final days = ProgressSummary.lastDays(LocalDate(2026, 10, 19), 7);

      expect(days, hasLength(7));
      expect(days.first, LocalDate(2026, 10, 13));
      expect(days.last, LocalDate(2026, 10, 19));
      expect(days.toSet(), hasLength(7));
    });

    test('lastDays with a non-positive count returns nothing', () {
      expect(ProgressSummary.lastDays(LocalDate(2026, 10, 19), 0), isEmpty);
    });

    test('completionsByDay groups timestamps by local calendar day', () {
      final days = [
        LocalDate(2026, 10, 18),
        LocalDate(2026, 10, 19),
        LocalDate(2026, 10, 20),
      ];
      final completions = [
        // 23:59 local on the 18th belongs to the 18th.
        LocalDate(2026, 10, 18).toLocalDateTime(hour: 23, minute: 59).toUtc(),
        // Local midnight starts the 19th.
        LocalDate(2026, 10, 19).toLocalDateTime().toUtc(),
        LocalDate(2026, 10, 19).toLocalDateTime(hour: 9).toUtc(),
        LocalDate(2026, 10, 20).toLocalDateTime(hour: 6, minute: 30).toUtc(),
      ];

      final counts = ProgressSummary.completionsByDay(
        completedAtUtc: completions,
        days: days,
      );

      expect(counts.map((day) => day.day), days);
      expect(counts.map((day) => day.count), [1, 2, 1]);
    });

    test('completionsByDay keeps zero days and ignores other days', () {
      final days = [LocalDate(2026, 10, 13), LocalDate(2026, 10, 19)];
      final counts = ProgressSummary.completionsByDay(
        completedAtUtc: [
          LocalDate(2026, 10, 5).toLocalDateTime(hour: 10).toUtc(),
          LocalDate(2026, 10, 19).toLocalDateTime(hour: 10).toUtc(),
        ],
        days: days,
      );

      expect(counts.map((day) => day.count), [0, 1]);
    });

    test('a day without due tasks is not a percentage', () {
      final progress = ProgressSummary.dueProgress(total: 0, completed: 0);

      expect(progress.hasTasks, isFalse);
      expect(progress.percent, 0);
      expect(progress.fraction, 0);
      expect(progress.open, 0);
    });

    test('due progress rounds the completion percentage', () {
      final twoOfThree = ProgressSummary.dueProgress(total: 3, completed: 2);
      expect(twoOfThree.percent, 67);
      expect(twoOfThree.fraction, closeTo(0.6667, 0.001));
      expect(twoOfThree.open, 1);

      final all = ProgressSummary.dueProgress(total: 4, completed: 4);
      expect(all.percent, 100);
      expect(all.hasTasks, isTrue);
    });

    test('due progress never reports more completions than due tasks', () {
      final progress = ProgressSummary.dueProgress(total: 2, completed: 5);

      expect(progress.completed, 2);
      expect(progress.percent, 100);
    });
  });

  group('progress queries', () {
    late AppDatabase database;
    late TaskRepository tasks;
    final now = DateTime(2026, 10, 19, 12);
    final today = LocalDate(2026, 10, 19);

    setUp(() async {
      database = await openInMemoryDatabase();
      tasks = TaskRepository(database, clock: () => now);
    });

    tearDown(() => database.close());

    test('completed tasks group into their local calendar day', () async {
      final yesterdayId = await tasks.createTask(
        const TaskDraft(title: 'Finished yesterday'),
      );
      await tasks.setTaskCompleted(
        yesterdayId,
        true,
        completedAt: LocalDate(2026, 10, 18).toLocalDateTime(hour: 15).toUtc(),
      );

      final todayId = await tasks.createTask(
        const TaskDraft(title: 'Finished today'),
      );
      await tasks.setTaskCompleted(
        todayId,
        true,
        completedAt: today.toLocalDateTime(hour: 9).toUtc(),
      );

      final completedToday = await tasks.watchCompletedOn(day: today).first;
      expect(completedToday.map((task) => task.title), ['Finished today']);

      final completedYesterday = await tasks
          .watchCompletedOn(day: today.addDays(-1))
          .first;
      expect(completedYesterday.map((task) => task.title), [
        'Finished yesterday',
      ]);
    });

    test('a completion at local midnight starts the next day', () async {
      final beforeMidnight = today
          .addDays(1)
          .toLocalDateTime()
          .subtract(const Duration(milliseconds: 1))
          .toUtc();
      final atMidnight = today.addDays(1).toLocalDateTime().toUtc();

      final endingId = await tasks.createTask(
        const TaskDraft(title: 'Ends the day'),
      );
      await tasks.setTaskCompleted(endingId, true, completedAt: beforeMidnight);
      final startingId = await tasks.createTask(
        const TaskDraft(title: 'Starts the day'),
      );
      await tasks.setTaskCompleted(startingId, true, completedAt: atMidnight);

      final endOfDay = await tasks.watchCompletedOn(day: today).first;
      expect(endOfDay.map((task) => task.title), ['Ends the day']);

      final startOfDay = await tasks
          .watchCompletedOn(day: today.addDays(1))
          .first;
      expect(startOfDay.map((task) => task.title), ['Starts the day']);
    });

    test('reopening a task removes its completion from the day', () async {
      final taskId = await tasks.createTask(const TaskDraft(title: 'Reopened'));
      await tasks.setTaskCompleted(
        taskId,
        true,
        completedAt: today.toLocalDateTime(hour: 10).toUtc(),
      );
      expect((await tasks.watchCompletedOn(day: today).first), hasLength(1));

      await tasks.setTaskCompleted(taskId, false);
      expect(await tasks.watchCompletedOn(day: today).first, isEmpty);
    });

    test('due tasks cover open and completed rows for that day only', () async {
      final dueToday = await tasks.createTask(
        TaskDraft(title: 'Due today', dueDate: today),
      );
      await tasks.setTaskCompleted(
        dueToday,
        true,
        completedAt: today.toLocalDateTime(hour: 8).toUtc(),
      );
      await tasks.createTask(TaskDraft(title: 'Still open', dueDate: today));
      await tasks.createTask(
        TaskDraft(title: 'Due tomorrow', dueDate: today.addDays(1)),
      );
      await tasks.createTask(const TaskDraft(title: 'No due date'));

      final dueTasks = await tasks.watchTasksDueOn(day: today).first;
      expect(
        dueTasks.map((task) => task.title),
        containsAll(['Due today', 'Still open']),
      );
      expect(dueTasks, hasLength(2));
      expect(dueTasks.where((task) => task.isCompleted), hasLength(1));
    });
  });

  group('progress screen', () {
    testWidgets('shows due progress, completed today, and seven day counts', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final database = await openInMemoryDatabase();
      addTearDown(database.close);

      final now = DateTime(2026, 10, 19, 12);
      final today = LocalDate(2026, 10, 19);
      final repository = TaskRepository(database, clock: () => now);

      final finished = await repository.createTask(
        TaskDraft(title: 'Morning report', dueDate: today),
      );
      await repository.setTaskCompleted(
        finished,
        true,
        completedAt: today.toLocalDateTime(hour: 9).toUtc(),
      );
      await repository.createTask(
        TaskDraft(title: 'Write the brief', dueDate: today),
      );
      await repository.createTask(
        TaskDraft(title: 'Call the studio', dueDate: today),
      );

      final lastWeek = await repository.createTask(
        const TaskDraft(title: 'Filed last week'),
      );
      await repository.setTaskCompleted(
        lastWeek,
        true,
        completedAt: today.addDays(-4).toLocalDateTime(hour: 16).toUtc(),
      );

      await pumpXenndoAppLive(tester, now: now, database: database);
      await tester.tap(find.byKey(const ValueKey('progress-action')));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('progress-screen')), findsOneWidget);
      expect(find.text('1 of 3 done'), findsOneWidget);
      expect(find.text('33% complete · 2 still open'), findsOneWidget);
      expect(find.text('No tasks due'), findsNothing);
      expect(find.text('Morning report'), findsOneWidget);
      expect(find.text('Last 7 days'), findsOneWidget);
      expect(
        find.textContaining('Reopening a task clears its completion'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Tasks with an earlier due date'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('1 of 3 tasks due today are completed')),
        findsOneWidget,
      );

      handle.dispose();
      await disposeXenndoApp(tester);
    });

    testWidgets(
      'a day without due tasks shows No tasks due, not a percentage',
      (tester) async {
        final database = await openInMemoryDatabase();
        addTearDown(database.close);

        final now = DateTime(2026, 10, 19, 12);
        final repository = TaskRepository(database, clock: () => now);
        final undated = await repository.createTask(
          const TaskDraft(title: 'No date at all'),
        );
        await repository.setTaskCompleted(
          undated,
          true,
          completedAt: now.toUtc(),
        );

        await pumpXenndoAppLive(tester, now: now, database: database);
        await tester.tap(find.byKey(const ValueKey('progress-action')));
        await tester.pumpAndSettle();

        expect(find.text('No tasks due'), findsOneWidget);
        expect(find.textContaining('% complete'), findsNothing);
        expect(find.text('No date at all'), findsOneWidget);
        expect(find.text('No progress yet'), findsNothing);

        await disposeXenndoApp(tester);
      },
    );
  });
}
