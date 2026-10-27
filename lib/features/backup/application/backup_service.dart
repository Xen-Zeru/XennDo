import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';

import 'dart:convert';

import 'package:xenndo/core/time/local_date.dart';
import 'package:xenndo/features/backup/data/backup_file_store.dart';
import 'package:xenndo/features/backup/data/backup_repository.dart';
import 'package:xenndo/features/backup/domain/backup_document.dart';
import 'package:xenndo/features/reminders/application/reminder_reconciler.dart';

enum BackupExportStatus { saved, cancelled, failed }

/// Outcome of one export attempt.
class BackupExportResult {
  const BackupExportResult.saved(this.fileName)
    : status = BackupExportStatus.saved,
      message = null;

  const BackupExportResult.cancelled()
    : status = BackupExportStatus.cancelled,
      fileName = null,
      message = null;

  const BackupExportResult.failed(this.message)
    : status = BackupExportStatus.failed,
      fileName = null;

  final BackupExportStatus status;
  final String? fileName;
  final String? message;
}

enum BackupOpenStatus { selected, cancelled, failed }

/// Outcome of one open attempt: a validated document, a dismissal, or an error.
class BackupOpenResult {
  const BackupOpenResult.selected(this.document)
    : status = BackupOpenStatus.selected,
      message = null;

  const BackupOpenResult.cancelled()
    : status = BackupOpenStatus.cancelled,
      document = null,
      message = null;

  const BackupOpenResult.failed(this.message)
    : status = BackupOpenStatus.failed,
      document = null;

  final BackupOpenStatus status;
  final BackupDocument? document;
  final String? message;
}

/// Outcome of a restore attempt.
class BackupRestoreResult {
  const BackupRestoreResult.restored(this.summary, {this.warning})
    : status = BackupRestoreStatus.restored,
      message = null;

  const BackupRestoreResult.failed(this.message)
    : status = BackupRestoreStatus.failed,
      summary = null,
      warning = null;

  final BackupRestoreStatus status;
  final BackupSummary? summary;

  /// Set when the data was restored but a follow-up step, such as
  /// rescheduling reminders, could not finish.
  final String? warning;
  final String? message;
}

enum BackupRestoreStatus { restored, failed }

/// Drives the export, open, and restore flows.
///
/// Reading and validation happen before any database write, so a bad file can
/// never reach the storage layer.
class BackupService {
  BackupService({
    required this.repository,
    required this.fileStore,
    required this.reconciler,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BackupRepository repository;
  final BackupFileStore fileStore;
  final ReminderReconciler reconciler;
  final DateTime Function() _clock;

  /// Suggested file name, for example `xenndo-backup-2026-10-25.json`.
  String backupFileName() {
    final day = LocalDate.today(_clock()).toIso8601String();
    return 'xenndo-backup-$day.json';
  }

  /// Writes the current data as a JSON file through the system save dialog.
  Future<BackupExportResult> exportBackup() async {
    try {
      final document = await repository.exportAll();
      final fileName = backupFileName();
      final destination = await fileStore.saveBackup(
        fileName: fileName,
        bytes: utf8.encode(document.encode()),
      );
      if (destination == null) {
        return const BackupExportResult.cancelled();
      }
      return BackupExportResult.saved(fileName);
    } on Object catch (error) {
      return BackupExportResult.failed(
        "The backup could not be saved. The chosen destination may contain an incomplete file. ($error)",
      );
    }
  }

  /// Opens and validates a file without touching the database.
  Future<BackupOpenResult> openBackup() async {
    final List<int>? bytes;
    try {
      bytes = await fileStore.openBackup();
    } on Object catch (error) {
      return BackupOpenResult.failed(
        "The backup file could not be read. Nothing was changed. ($error)",
      );
    }
    if (bytes == null) {
      return const BackupOpenResult.cancelled();
    }

    try {
      final source = utf8.decode(bytes);
      return BackupOpenResult.selected(BackupDocument.decode(source));
    } on FormatException catch (error) {
      return BackupOpenResult.failed(
        'This file is not UTF-8 text, so it cannot be a XennDo backup '
        '(${error.message}).',
      );
    } on BackupException catch (error) {
      return BackupOpenResult.failed('${error.message} Nothing was changed.');
    }
  }

  /// Replaces all local data with [document], then reconciles reminders.
  Future<BackupRestoreResult> restore(BackupDocument document) async {
    try {
      await repository.restore(document);
    } on Object catch (error) {
      return BackupRestoreResult.failed(
        'The restore stopped, so your previous data was left untouched. '
        '($error)',
      );
    }

    try {
      await reconciler.reconcile();
      if (await reconciler.scheduler.checkPermission() !=
              ReminderPermissionStatus.granted &&
          document.tasks.any((task) => !task.isCompleted && task.hasReminder)) {
        return BackupRestoreResult.restored(
          document.summary,
          warning: 'Your data was restored. Reminders are not scheduled while notifications are off; enable them in Settings.',
        );
      }
    } on Object {
      return BackupRestoreResult.restored(
        document.summary,
        warning:
            'Your data was restored, but reminders could not be rescheduled '
            'yet. They are set again the next time the app opens.',
      );
    }
    return BackupRestoreResult.restored(document.summary);
  }
}
