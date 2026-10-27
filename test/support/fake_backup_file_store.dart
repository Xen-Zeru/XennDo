import 'package:xenndo/features/backup/data/backup_file_store.dart';

/// Stands in for the system save and open dialogs.
class FakeBackupFileStore implements BackupFileStore {
  FakeBackupFileStore({
    this.savedUri,
    this.openBytes,
    this.saveError,
    this.openError,
  });

  /// Uri the save dialog reports, or null when the dialog was dismissed.
  String? savedUri;

  /// Bytes the open dialog reports, or null when the dialog was dismissed.
  List<int>? openBytes;

  Object? saveError;
  Object? openError;

  String? savedFileName;
  List<int>? savedBytes;
  int saveCalls = 0;
  int openCalls = 0;

  @override
  Future<String?> saveBackup({
    required String fileName,
    required List<int> bytes,
  }) async {
    saveCalls++;
    savedFileName = fileName;
    savedBytes = bytes;
    final error = saveError;
    if (error != null) {
      throw error;
    }
    return savedUri;
  }

  @override
  Future<List<int>?> openBackup() async {
    openCalls++;
    final error = openError;
    if (error != null) {
      throw error;
    }
    return openBytes;
  }
}
