import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/core/theme/app_theme.dart';
import 'package:xenndo/core/widgets/app_empty_state.dart';
import 'package:xenndo/core/widgets/app_error_state.dart';
import 'package:xenndo/core/widgets/app_loading_state.dart';
import 'package:xenndo/features/tasks/domain/task_priority.dart';
import 'package:xenndo/features/tasks/presentation/task_row_data.dart';
import 'package:xenndo/features/tasks/presentation/widgets/priority_badge.dart';
import 'package:xenndo/features/tasks/presentation/widgets/task_row.dart';

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('empty state renders its action and calls it', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      _testApp(
        AppEmptyState(
          icon: Icons.inbox_outlined,
          title: 'Nothing here yet',
          message: 'Add your first task to get started.',
          actionLabel: 'Add task',
          onAction: () => tapped = true,
        ),
      ),
    );

    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Add your first task to get started.'), findsOneWidget);

    await tester.tap(find.text('Add task'));
    expect(tapped, isTrue);
  });

  testWidgets('error state renders and retries', (tester) async {
    var retried = false;

    await tester.pumpWidget(
      _testApp(
        AppErrorState(
          title: 'Could not load tasks',
          message: 'Try again in a moment.',
          onRetry: () => retried = true,
        ),
      ),
    );

    expect(find.text('Could not load tasks'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('loading state exposes a progress indicator and message', (
    tester,
  ) async {
    await tester.pumpWidget(_testApp(const AppLoadingState()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading your day...'), findsOneWidget);
  });

  testWidgets('task row shows priority, due state, and completion control', (
    tester,
  ) async {
    var toggledTo = false;

    await tester.pumpWidget(
      _testApp(
        TaskRow(
          data: const TaskRowData(
            id: 'task-1',
            title: 'Send proposal follow-up',
            description: 'Add the revised timeline.',
            listName: 'Work',
            dueLabel: 'Yesterday',
            priority: TaskPriority.high,
            isOverdue: true,
            completedSubtasks: 1,
            totalSubtasks: 2,
          ),
          onCompletionChanged: (value) => toggledTo = value,
        ),
      ),
    );

    expect(find.text('Send proposal follow-up'), findsOneWidget);
    expect(find.text('Overdue · Yesterday'), findsOneWidget);
    expect(find.text('1 of 2 subtasks'), findsOneWidget);
    expect(find.byType(PriorityBadge), findsOneWidget);
    expect(find.text('High'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    expect(toggledTo, isTrue);
  });
}
