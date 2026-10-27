import 'package:flutter/material.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/features/backup/domain/backup_document.dart';

/// Asks for permission to write a backup file after explaining what the file
/// contains.
///
/// Returns true when the person wants to continue to the system save dialog.
Future<bool> confirmBackupExport(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: const Text('Save a backup file'),
      content: const Text(
        'A backup is a plain text JSON file and it is not encrypted. Anyone '
        'who opens it can read your list names, task titles, notes, due dates, '
        'and reminder times, so keep it somewhere private.\n\n'
        'XennDo sends no data to a server. Your chosen storage provider controls the saved file.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('backup-export-continue'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Choose where to save'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Shows what a backup contains and states plainly that restoring replaces
/// everything currently on the device.
///
/// Returns true only when the person confirms the replacement.
Future<bool> confirmBackupRestore(
  BuildContext context,
  BackupSummary summary,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: const Text('Restore this backup?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'The file contains',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _countLine(Icons.list_alt_outlined, _plural(summary.lists, 'list')),
          _countLine(
            Icons.task_outlined,
            '${_plural(summary.tasks, 'task')}'
            '${summary.completedTasks == 0 ? '' : ' (${_plural(summary.completedTasks, 'completed task')} included)'}',
          ),
          _countLine(
            Icons.checklist_outlined,
            _plural(summary.subtasks, 'subtask'),
          ),
          _countLine(
            Icons.filter_3_outlined,
            _plural(summary.focusEntries, 'Top 3 selection'),
          ),
          _countLine(
            Icons.palette_outlined,
            'Appearance: ${summary.themeMode}',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Restoring replaces everything on this device. Your current lists, '
            'tasks, subtasks, Top 3 selections, and settings are deleted '
            'first, then the backup is written in one step. This cannot be '
            'undone.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('backup-restore-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Replace and restore'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Reports a finished restore, including any follow-up that could not run.
Future<void> showRestoreResult(
  BuildContext context, {
  required BackupSummary summary,
  String? warning,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: const Text('Restore complete'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restored ${_plural(summary.lists, 'list')}, '
            '${_plural(summary.tasks, 'task')}, '
            '${_plural(summary.subtasks, 'subtask')}, and '
            '${_plural(summary.focusEntries, 'Top 3 selection')}.',
          ),
          if (warning != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(warning),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

/// Reports a backup problem with a title that says which flow failed.
Future<void> showBackupError(
  BuildContext context, {
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Widget _countLine(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

String _plural(int count, String noun) {
  if (count == 1) {
    return '1 $noun';
  }
  if (noun == 'Top 3 selection') {
    return '$count Top 3 selections';
  }
  return '$count ${noun}s';
}
