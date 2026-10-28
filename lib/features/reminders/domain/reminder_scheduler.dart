enum ReminderPermissionStatus {
  granted,

  /// The platform can still display a notification permission prompt.
  requestable,

  /// A system settings change is required.
  denied,
  unsupported,
}

class ReminderCapacityException implements Exception {
  const ReminderCapacityException();

  @override
  String toString() =>
      'Task saved. iOS can keep up to 64 pending reminders. This reminder was '
      'not scheduled. Remove another reminder or retry after one is delivered.';
}

/// Platform-independent reminder scheduling boundary.
///
/// Implementations may use local notifications, while tests use a fake.
abstract interface class ReminderScheduler {
  /// Prepares the scheduler and routes notification taps to [onNotificationTap].
  ///
  /// Safe to call more than once. Repeat calls must be idempotent with respect
  /// to plugin setup while still refreshing platform state such as the device
  /// time zone.
  Future<void> initialize({
    required void Function(String taskId) onNotificationTap,
  });

  /// Returns the task id from a notification that launched the app, if any.
  Future<String?> takeInitialTaskId();

  /// Reads the current permission state without prompting the user.
  Future<ReminderPermissionStatus> checkPermission();

  Future<ReminderPermissionStatus> requestPermission();

  Future<bool> openNotificationSettings();

  Future<void> schedule({
    required int notificationId,
    required String taskId,
    required String title,
    String? body,
    required DateTime when,
  });

  Future<void> cancel(int notificationId);

  Future<Set<int>> pendingNotificationIds();
}

/// A no-op scheduler used when notifications are not available.
class NoopReminderScheduler implements ReminderScheduler {
  const NoopReminderScheduler();

  @override
  Future<void> initialize({
    required void Function(String taskId) onNotificationTap,
  }) async {}

  @override
  Future<String?> takeInitialTaskId() async => null;

  @override
  Future<ReminderPermissionStatus> checkPermission() async =>
      ReminderPermissionStatus.unsupported;

  @override
  Future<ReminderPermissionStatus> requestPermission() async =>
      ReminderPermissionStatus.unsupported;

  @override
  Future<bool> openNotificationSettings() async => false;

  @override
  Future<void> schedule({
    required int notificationId,
    required String taskId,
    required String title,
    String? body,
    required DateTime when,
  }) async {}

  @override
  Future<void> cancel(int notificationId) async {}

  @override
  Future<Set<int>> pendingNotificationIds() async => const {};
}
