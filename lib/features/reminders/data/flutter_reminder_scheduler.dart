import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';

class FlutterReminderScheduler implements ReminderScheduler {
  FlutterReminderScheduler({
    FlutterLocalNotificationsPlugin? plugin,
    MethodChannel settingsChannel = const MethodChannel('xenndo/settings'),
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       // ignore: prefer_initializing_formals
       _settingsChannel = settingsChannel;

  static const _channelId = 'xenndo_reminders';
  static const _channelName = 'Task reminders';
  static const _channelDescription =
      'Local reminders for tasks with a chosen reminder time.';

  final FlutterLocalNotificationsPlugin _plugin;
  final MethodChannel _settingsChannel;

  bool _initialized = false;

  @override
  Future<void> initialize({
    required void Function(String taskId) onNotificationTap,
  }) async {
    // Re-running initialize is intentional: it refreshes the time-zone location
    // after a device zone change, while plugin setup below only happens once.
    tz_data.initializeTimeZones();
    await _setLocalTimeZone();

    if (_initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('ic_stat_task');
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) {
          onNotificationTap(payload);
        }
      },
    );

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.high,
      ),
    );

    _initialized = true;
  }

  Future<void> _setLocalTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Keep the timezone package default if the platform lookup fails.
    }
  }

  @override
  Future<String?> takeInitialTaskId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) {
      return null;
    }
    final payload = details?.notificationResponse?.payload;
    return payload == null || payload.isEmpty ? null : payload;
  }

  @override
  Future<ReminderPermissionStatus> checkPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return ReminderPermissionStatus.unsupported;
    }
    try {
      final enabled = await android.areNotificationsEnabled();
      if (enabled == null) {
        return ReminderPermissionStatus.unsupported;
      }
      if (enabled) return ReminderPermissionStatus.granted;
      // Android's runtime prompt is unavailable after permanent denial and on
      // pre-33 devices. The native boundary also remembers whether we asked.
      final canRequest = await _settingsChannel.invokeMethod<bool>(
        'canRequestNotificationPermission',
      );
      return canRequest == true
          ? ReminderPermissionStatus.requestable
          : ReminderPermissionStatus.denied;
    } on MissingPluginException {
      return ReminderPermissionStatus.denied;
    }
  }

  @override
  Future<ReminderPermissionStatus> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return ReminderPermissionStatus.unsupported;
    }
    final status = await checkPermission();
    if (status != ReminderPermissionStatus.requestable) return status;
    await _settingsChannel.invokeMethod<void>(
      'notificationPermissionRequested',
    );
    final granted = await android.requestNotificationsPermission();
    return granted == true
        ? ReminderPermissionStatus.granted
        : ReminderPermissionStatus.denied;
  }

  @override
  Future<bool> openNotificationSettings() async {
    try {
      final opened = await _settingsChannel.invokeMethod<bool>(
        'openNotificationSettings',
      );
      return opened ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> schedule({
    required int notificationId,
    required String taskId,
    required String title,
    String? body,
    required DateTime when,
  }) async {
    await _plugin.zonedSchedule(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(when.toUtc(), tz.UTC),
      payload: taskId,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      // Exact alarms are used only when the platform reports the permission as
      // granted; otherwise scheduling falls back to inexact delivery, which
      // needs no special alarm permission and may be delayed by Android.
      androidScheduleMode: await _scheduleMode(),
    );
  }

  Future<AndroidScheduleMode> _scheduleMode() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final canScheduleExact = await android?.canScheduleExactNotifications();
      if (canScheduleExact == true) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {
      // Fall through to inexact scheduling when the platform check fails.
    }
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  @override
  Future<void> cancel(int notificationId) {
    return _plugin.cancel(id: notificationId);
  }

  @override
  Future<Set<int>> pendingNotificationIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((request) => request.id).toSet();
  }
}
