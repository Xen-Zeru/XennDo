import 'package:flutter/material.dart';
import 'package:xenndo/core/database/app_database.dart';
import 'package:xenndo/features/settings/domain/app_settings.dart';

/// Storage keys for the `settings` table.
abstract final class SettingsKeys {
  static const themeMode = 'theme_mode';

  /// Keys that a backup file may carry.
  ///
  /// Transient platform state such as the notification permission is not
  /// listed: it is read from Android on demand and is never stored, so it is
  /// never exported or restored.
  static const Set<String> exportableKeys = {themeMode};
}

/// Reads and writes the persisted user preferences.
///
/// Values are plain strings so unknown or corrupted rows degrade to defaults
/// instead of failing.
class SettingsRepository {
  SettingsRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Future<AppSettings> load() async {
    return _toSettings(await _db.select(_db.settings).get());
  }

  Future<void> saveThemeMode(ThemeMode mode) {
    return _write(SettingsKeys.themeMode, mode.name);
  }

  Future<void> _write(String key, String value) async {
    await _db
        .into(_db.settings)
        .insertOnConflictUpdate(
          Setting(key: key, value: value, updatedAt: _clock().toUtc()),
        );
  }

  AppSettings _toSettings(List<Setting> rows) {
    final values = <String, String>{for (final row in rows) row.key: row.value};
    return AppSettings(
      themeMode: AppSettings.themeModeFromStorage(
        values[SettingsKeys.themeMode],
      ),
    );
  }
}
