import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Where backup bytes are written to and read from.
///
/// A [null] return value means the person dismissed the dialog, which is a
/// normal outcome rather than an error.
abstract interface class BackupFileStore {
  /// Opens the system save dialog and writes [bytes].
  ///
  /// Returns the location the file was written to, or null when cancelled.
  Future<String?> saveBackup({
    required String fileName,
    required List<int> bytes,
  });

  /// Opens the system open dialog and reads the chosen file.
  ///
  /// Returns null when cancelled.
  Future<List<int>?> openBackup();
}

/// Uses Android's Storage Access Framework or the iOS document picker.
///
/// The system dialogs grant a scoped read or write for the one file the person
/// chooses, so no storage permission is requested and nothing is read from or
/// written behind the user's back.
class FilePickerBackupStore implements BackupFileStore {
  const FilePickerBackupStore();

  @override
  Future<String?> saveBackup({
    required String fileName,
    required List<int> bytes,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      mimeType: 'application/json',
      dialogTitle: 'Save XennDo backup',
    );
    return uri?.toString();
  }

  @override
  Future<List<int>?> openBackup() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a XennDo backup',
      type: FileType.any,
    );
    if (file == null) {
      return null;
    }
    return file.readAsBytes();
  }
}
