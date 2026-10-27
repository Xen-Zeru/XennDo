import 'package:xenndo/features/settings/application/settings_providers.dart';
import 'package:xenndo/features/reminders/application/reminder_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xenndo/app/router.dart';
import 'package:xenndo/features/reminders/application/reminder_providers.dart';

/// Initializes notifications, routes notification taps, and reconciles pending
/// reminders on app resume.
class ReminderLifecycleListener extends ConsumerStatefulWidget {
  const ReminderLifecycleListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReminderLifecycleListener> createState() =>
      _ReminderLifecycleListenerState();
}

class _ReminderLifecycleListenerState
    extends ConsumerState<ReminderLifecycleListener>
    with WidgetsBindingObserver {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshOnResume();
    }
  }

  Future<void> _initialize() async {
    _router = ref.read(routerProvider);
    final scheduler = ref.read(reminderSchedulerProvider);

    try {
      await scheduler.initialize(onNotificationTap: _openTask);

      final initialTaskId = await scheduler.takeInitialTaskId();
      if (initialTaskId != null && mounted) {
        _openTask(initialTaskId);
      }

      await _reconcile();
    } catch (_) {
      _reportFailure();
    }
  }

  Future<void> _refreshOnResume() async {
    // Re-initializing refreshes the time-zone location, then reconciliation
    // re-derives reminder instants so they keep their local wall-clock time
    // after a device time-zone change.
    final scheduler = ref.read(reminderSchedulerProvider);
    try {
      await scheduler.initialize(onNotificationTap: _openTask);
      if (!mounted) return;
      ref.invalidate(notificationPermissionProvider);
      await _reconcile();
    } catch (_) {
      _reportFailure();
    }
  }

  Future<void> _reconcile() async {
    try {
      await ref.read(reminderReconcilerProvider).reconcile();
    } catch (_) {
      _reportFailure();
    }
  }

  void _reportFailure() {
    if (mounted) {
      ref
          .read(reminderNoticeProvider.notifier)
          .show(
            'Android reminders could not be refreshed. Your tasks are safe; reopen the app to retry.',
          );
    }
  }

  void _openTask(String taskId) {
    final router = _router;
    if (router == null) {
      return;
    }
    // Preserve the shell and any unsaved editor already underneath this task.
    router.pushNamed('editTask', pathParameters: {'taskId': taskId});
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
