import 'package:flutter/material.dart';
import 'package:xenndo/features/tasks/data/task_repository.dart';
import 'package:xenndo/features/tasks/domain/task_deletion_snapshot.dart';

/// Keep Undo usable after the task row or editor that deleted it is disposed.
void showTaskDeletionNotice(
  ScaffoldMessengerState messenger,
  TaskRepository repository,
  TaskDeletionSnapshot snapshot,
) {
  if (!messenger.mounted) return;
  messenger.showSnackBar(
    SnackBar(
      content: const Text('Task deleted.'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          try {
            await repository.restoreTask(snapshot);
          } catch (_) {
            if (messenger.mounted) {
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('Could not undo deletion. Please try again.'),
                ),
              );
            }
          }
        },
      ),
    ),
  );
}
