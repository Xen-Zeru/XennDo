class FocusLimitException implements Exception {
  const FocusLimitException();

  @override
  String toString() => 'My Top 3 already has three tasks for this day.';
}

class FocusDuplicateException implements Exception {
  const FocusDuplicateException(this.taskId);

  final String taskId;

  @override
  String toString() => 'Task $taskId is already selected for this day.';
}
