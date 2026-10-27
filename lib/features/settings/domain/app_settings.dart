import 'package:flutter/material.dart';

/// User preferences that are persisted locally.
class AppSettings {
  const AppSettings({this.themeMode = ThemeMode.system});

  static const AppSettings defaults = AppSettings();

  final ThemeMode themeMode;

  AppSettings copyWith({ThemeMode? themeMode}) {
    return AppSettings(themeMode: themeMode ?? this.themeMode);
  }

  /// Storage strings accepted for [themeMode].
  ///
  /// Readers fall back to the default for an unknown value, while backups are
  /// validated against this list so a file cannot smuggle in a bad value.
  static Set<String> get storageValues {
    return {for (final mode in ThemeMode.values) mode.name};
  }

  /// Parses a stored value, falling back to the default when absent or unknown.
  static ThemeMode themeModeFromStorage(String? raw) {
    for (final mode in ThemeMode.values) {
      if (mode.name == raw) {
        return mode;
      }
    }
    return defaults.themeMode;
  }

  @override
  bool operator ==(Object other) {
    return other is AppSettings && other.themeMode == themeMode;
  }

  @override
  int get hashCode => themeMode.hashCode;

  @override
  String toString() => 'AppSettings(themeMode: ${themeMode.name})';
}
