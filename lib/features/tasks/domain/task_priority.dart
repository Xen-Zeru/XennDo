enum TaskPriority {
  none('None', 0),
  low('Low', 1),
  medium('Medium', 2),
  high('High', 3);

  const TaskPriority(this.label, this.rank);

  final String label;
  final int rank;

  /// Priorities users can choose in the editor.
  static const List<TaskPriority> selectable = [high, medium, low];
}
