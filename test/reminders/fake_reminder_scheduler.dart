import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';

class ScheduledReminder {
  const ScheduledReminder({
    required this.notificationId,
    required this.taskId,
    required this.title,
    required this.when,
    this.body,
  });

  final int notificationId;
  final String taskId;
  final String title;
  final String? body;
  final DateTime when;
}

class FakeReminderScheduler implements ReminderScheduler {
  ReminderPermissionStatus permission = ReminderPermissionStatus.granted;
  bool openSettingsCalled = false;
  int permissionRequests = 0;
  String? initialTaskId;
  final Set<int> pending = <int>{};
  final List<ScheduledReminder> scheduled = <ScheduledReminder>[];
  final List<int> cancelled = <int>[];

  void Function(String taskId)? _onTap;

  void simulateTap(String taskId) => _onTap?.call(taskId);

  @override
  Future<void> initialize({
    required void Function(String taskId) onNotificationTap,
  }) async {
    _onTap = onNotificationTap;
  }

  @override
  Future<String?> takeInitialTaskId() async => initialTaskId;

  @override
  Future<ReminderPermissionStatus> checkPermission() async => permission;

  @override
  Future<ReminderPermissionStatus> requestPermission() async {
    permissionRequests++;
    return permission == ReminderPermissionStatus.requestable
        ? ReminderPermissionStatus.denied
        : permission;
  }

  @override
  Future<bool> openNotificationSettings() async {
    openSettingsCalled = true;
    return true;
  }

  @override
  Future<void> schedule({
    required int notificationId,
    required String taskId,
    required String title,
    String? body,
    required DateTime when,
  }) async {
    scheduled.add(
      ScheduledReminder(
        notificationId: notificationId,
        taskId: taskId,
        title: title,
        body: body,
        when: when,
      ),
    );
    pending.add(notificationId);
  }

  @override
  Future<void> cancel(int notificationId) async {
    cancelled.add(notificationId);
    pending.remove(notificationId);
  }

  @override
  Future<Set<int>> pendingNotificationIds() async => Set.of(pending);
}
