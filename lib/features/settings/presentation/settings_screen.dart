import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/theme/app_spacing.dart';
import 'package:xenndo/core/theme/app_colors.dart';
import 'package:xenndo/core/widgets/page_heading.dart';
import 'package:xenndo/features/backup/application/backup_providers.dart';
import 'package:xenndo/features/backup/application/backup_service.dart';
import 'package:xenndo/features/backup/presentation/backup_dialogs.dart';
import 'package:xenndo/features/reminders/application/reminder_providers.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';
import 'package:xenndo/features/reminders/presentation/reminder_platform_text.dart';
import 'package:xenndo/features/settings/application/settings_providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Returning from system settings must refresh the permission shown here.
      ref.invalidate(notificationPermissionProvider);
    }
  }

  Future<void> _openSystemNotificationSettings() async {
    try {
      final opened = await ref
          .read(reminderSchedulerProvider)
          .openNotificationSettings();
      if (mounted) {
        ref.invalidate(notificationPermissionProvider);
        if (!opened) {
          _showMessage('Could not open system notification settings.');
        }
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Could not open system notification settings.');
      }
    }
  }

  Future<void> _requestNotificationPermission() async {
    try {
      final status = await ref
          .read(reminderSchedulerProvider)
          .requestPermission();
      if (!mounted) {
        return;
      }
      ref.invalidate(notificationPermissionProvider);
      if (status == ReminderPermissionStatus.denied) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            scrollable: true,
            title: const Text('Notifications are still off'),
            content: Text(
              'Reminders cannot be delivered until notifications are allowed. '
              'You can change this in ${ReminderPlatformText.settingsName(Theme.of(context).platform)}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _openSystemNotificationSettings();
                },
                child: const Text('Open settings'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Could not check notification permission.');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Explains what the file contains, then hands off to the system save
  /// dialog.
  Future<void> _exportBackup() async {
    final service = ref.read(backupServiceProvider);
    final confirmed = await confirmBackupExport(context);
    if (!confirmed || !mounted) {
      return;
    }

    final result = await service.exportBackup();
    if (!mounted) {
      return;
    }
    switch (result.status) {
      case BackupExportStatus.saved:
        _showMessage('Backup saved as ${result.fileName}.');
      case BackupExportStatus.cancelled:
        _showMessage('Export cancelled. Nothing was saved.');
      case BackupExportStatus.failed:
        await showBackupError(
          context,
          title: 'Could not save the backup',
          message: result.message ?? 'The backup could not be saved.',
        );
    }
  }

  /// Validates a file first, shows what it contains, and only then replaces
  /// the local data.
  Future<void> _restoreBackup() async {
    final service = ref.read(backupServiceProvider);
    final opened = await service.openBackup();
    if (!mounted) {
      return;
    }
    if (opened.status == BackupOpenStatus.cancelled) {
      _showMessage('Restore cancelled. Nothing was changed.');
      return;
    }
    if (opened.status == BackupOpenStatus.failed) {
      await showBackupError(
        context,
        title: 'Could not open the backup',
        message: opened.message ?? 'The backup could not be read.',
      );
      return;
    }

    final document = opened.document!;
    final confirmed = await confirmBackupRestore(context, document.summary);
    if (!confirmed || !mounted) {
      return;
    }

    final result = await service.restore(document);
    if (!mounted) {
      return;
    }
    if (result.status == BackupRestoreStatus.failed) {
      await showBackupError(
        context,
        title: 'Restore failed',
        message: result.message ?? 'The restore could not be completed.',
      );
      return;
    }

    ref.invalidate(appSettingsProvider);
    await showRestoreResult(
      context,
      summary: result.summary!,
      warning: result.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);
    final permission = ref.watch(notificationPermissionProvider);
    final status = permission.value;
    final statusText = switch (status) {
      ReminderPermissionStatus.granted => 'Allowed',
      ReminderPermissionStatus.requestable => 'Permission needed',
      ReminderPermissionStatus.denied => 'Not allowed',
      ReminderPermissionStatus.unsupported => 'Not available on this device',
      null => permission.hasError ? 'Status unavailable' : 'Checking...',
    };
    final version = ref
        .watch(appVersionProvider)
        .when(
          data: (value) => 'Version $value',
          loading: () => 'Version ...',
          error: (_, _) => 'Version unavailable',
        );
    final appName = ref.watch(appNameProvider).value ?? 'XennDo';
    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        key: const ValueKey('settings-screen'),
        slivers: [
          const SliverToBoxAdapter(child: PageHeading(title: 'Settings')),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              0,
              AppSpacing.pageHorizontal,
              24,
            ),
            sliver: SliverList.list(
              children: [
                _appearanceCard(context, themeMode),
                const SizedBox(height: 16),
                _notificationsCard(context, status, statusText),
                const SizedBox(height: 16),
                _dataCard(context),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionHeading(context, 'About', Icons.info_outline),
                        ListTile(
                          key: const ValueKey('about-details'),
                          contentPadding: const EdgeInsets.only(left: 48),
                          minVerticalPadding: 8,
                          title: Text(
                            appName,
                            style: theme.textTheme.bodyMedium,
                          ),
                          subtitle: Text(
                            version,
                            key: const ValueKey('app-version'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                          ),
                          onTap: () => context.pushNamed('about'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeading(BuildContext context, String title, IconData icon) =>
      Row(
        children: [
          Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      );

  Widget _appearanceCard(BuildContext context, ThemeMode mode) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading(context, 'Appearance', Icons.palette_outlined),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in [
                  (ThemeMode.system, 'System', Icons.brightness_auto_outlined),
                  (ThemeMode.light, 'Light', Icons.light_mode_outlined),
                  (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
                ])
                  ChoiceChip(
                    key: ValueKey('theme-${entry.$1.name}'),
                    avatar: Icon(
                      entry.$3,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(entry.$2),
                    labelStyle: theme.textTheme.bodyMedium,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    showCheckmark: false,
                    selected: mode == entry.$1,
                    selectedColor: theme.colorScheme.primaryContainer,
                    backgroundColor: theme.colorScheme.surfaceContainerLow,
                    onSelected: (_) =>
                        ref.read(themeModeControllerProvider).setMode(entry.$1),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _notificationsCard(
    BuildContext context,
    ReminderPermissionStatus? status,
    String label,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final needsPermission =
        status == ReminderPermissionStatus.denied ||
        status == ReminderPermissionStatus.requestable;
    final canRequest = status == ReminderPermissionStatus.requestable;
    final canOpen =
        status == ReminderPermissionStatus.granted ||
        status == ReminderPermissionStatus.denied;
    final warning = context.appColors.warning;
    final notice = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          key: const ValueKey('notification-status'),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: needsPermission ? warning : colors.onSurface,
          ),
        ),
        if (needsPermission) ...[
          const SizedBox(height: 4),
          Text(
            canRequest
                ? 'Enable notifications to get reminders for your tasks.'
                : 'Allow notifications in ${ReminderPlatformText.settingsName(theme.platform)} to get reminders.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    final action = canRequest || canOpen
        ? FilledButton(
            key: ValueKey(
              canRequest
                  ? 'request-notification-permission'
                  : 'open-system-notification-settings',
            ),
            onPressed: canRequest
                ? _requestNotificationPermission
                : _openSystemNotificationSettings,
            style: FilledButton.styleFrom(
              minimumSize: const Size(72, 48),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(canRequest ? 'Enable' : 'Settings'),
          )
        : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading(context, 'Reminders', Icons.notifications_outlined),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: needsPermission
                    ? (theme.brightness == Brightness.light
                          ? const Color(0xFFFFF5D6)
                          : const Color(0xFF382E17))
                    : colors.primaryContainer.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 260 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        notice,
                        if (action != null) ...[
                          const SizedBox(height: 8),
                          action,
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        needsPermission
                            ? Icons.error_rounded
                            : Icons.check_circle_outline,
                        size: 24,
                        color: needsPermission ? warning : colors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: notice),
                      if (action != null) ...[
                        const SizedBox(width: 12),
                        action,
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dataCard(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeading(context, 'Data', Icons.save_alt_outlined),
            const SizedBox(height: 8),
            ListTile(
              key: const ValueKey('backup-export'),
              contentPadding: EdgeInsets.zero,
              minTileHeight: 48,
              leading: Icon(Icons.ios_share_outlined, color: colors.primary),
              title: Text(
                'Export backup',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: _exportBackup,
            ),
            const Divider(height: 1, indent: 48),
            ListTile(
              key: const ValueKey('backup-import'),
              contentPadding: EdgeInsets.zero,
              minTileHeight: 48,
              leading: Icon(
                Icons.file_download_outlined,
                color: colors.primary,
              ),
              title: Text(
                'Restore backup',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: _restoreBackup,
            ),
          ],
        ),
      ),
    );
  }
}
