class SubtaskDraft {
  const SubtaskDraft({required this.title, this.id, this.isCompleted = false});

  final String? id;
  final String title;
  final bool isCompleted;
}
