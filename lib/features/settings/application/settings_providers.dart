import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xenndo/core/database/database_provider.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/features/reminders/application/reminder_providers.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';
import 'package:xenndo/features/settings/data/settings_repository.dart';
import 'package:xenndo/features/settings/domain/app_settings.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(nowProvider),
  );
});

/// Persisted preferences, read once from the `settings` table.
///
/// Writers invalidate this provider, so the app re-reads after a change and on
/// the next launch.
final appSettingsProvider = FutureProvider<AppSettings>((ref) {
  return ref.watch(settingsRepositoryProvider).load();
});

/// The appearance used by the app. Falls back to system until the stored
/// preference has been read.
final themeModeProvider = Provider<ThemeMode>((ref) {
  final settings = ref.watch(appSettingsProvider).value;
  return settings?.themeMode ?? ThemeMode.system;
});

class ThemeModeController {
  ThemeModeController(this._ref, this._repository);

  final Ref _ref;
  final SettingsRepository _repository;

  /// Persists the choice and refreshes the providers that read it.
  Future<void> setMode(ThemeMode mode) async {
    await _repository.saveThemeMode(mode);
    _ref.invalidate(appSettingsProvider);
  }
}

final themeModeControllerProvider = Provider<ThemeModeController>((ref) {
  return ThemeModeController(ref, ref.watch(settingsRepositoryProvider));
});

/// The platform notification permission state, re-read on every screen visit.
final notificationPermissionProvider =
    FutureProvider.autoDispose<ReminderPermissionStatus>((ref) {
      return ref.watch(reminderSchedulerProvider).checkPermission();
    });

/// Installed metadata shared by Settings, About and the license page.
final appPackageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

/// Compact version label; build information lives on the About page.
final appVersionProvider = FutureProvider.autoDispose<String>((ref) async {
  return (await ref.watch(appPackageInfoProvider.future)).version;
});

/// Uses the installed package label, including build-flavor labels if present.
final appNameProvider = FutureProvider.autoDispose<String>((ref) async {
  return (await ref.watch(appPackageInfoProvider.future)).appName;
});
