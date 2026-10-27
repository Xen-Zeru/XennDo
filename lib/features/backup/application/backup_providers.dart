import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/database/database_provider.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/features/backup/application/backup_service.dart';
import 'package:xenndo/features/backup/data/backup_file_store.dart';
import 'package:xenndo/features/backup/data/backup_repository.dart';
import 'package:xenndo/features/reminders/application/reminder_providers.dart';

/// The dialogs backup files travel through.
///
/// Overridden in tests so no system dialog ever opens there.
final backupFileStoreProvider = Provider<BackupFileStore>((ref) {
  return const FilePickerBackupStore();
});

final backupRepositoryProvider = Provider<BackupRepository>((ref) {
  return BackupRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(nowProvider),
  );
});

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService(
    repository: ref.watch(backupRepositoryProvider),
    fileStore: ref.watch(backupFileStoreProvider),
    reconciler: ref.watch(reminderReconcilerProvider),
    clock: ref.watch(nowProvider),
  );
});
