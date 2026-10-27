import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:xenndo/features/reminders/data/flutter_reminder_scheduler.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const settings = MethodChannel('xenndo/settings');
  var notificationsEnabled = false;
  var canRequest = true;
  var requests = 0;
  var recordedRequest = false;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    notificationsEnabled = false;
    canRequest = true;
    requests = 0;
    recordedRequest = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notifications, (call) async {
      switch (call.method) {
        case 'areNotificationsEnabled':
          return notificationsEnabled;
        case 'requestNotificationsPermission':
          requests++;
          return false;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(settings, (call) async {
      switch (call.method) {
        case 'canRequestNotificationPermission':
          return canRequest;
        case 'notificationPermissionRequested':
          recordedRequest = true;
      }
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(notifications, null);
    messenger.setMockMethodCallHandler(settings, null);
  });

  test('granted notifications need no prompt', () async {
    notificationsEnabled = true;
    final scheduler = FlutterReminderScheduler();
    expect(await scheduler.checkPermission(), ReminderPermissionStatus.granted);
    expect(
      await scheduler.requestPermission(),
      ReminderPermissionStatus.granted,
    );
    expect(requests, 0);
  });

  test(
    'requestable notifications record the request and report denial accurately',
    () async {
      final scheduler = FlutterReminderScheduler();
      expect(
        await scheduler.checkPermission(),
        ReminderPermissionStatus.requestable,
      );
      expect(
        await scheduler.requestPermission(),
        ReminderPermissionStatus.denied,
      );
      expect(requests, 1);
      expect(recordedRequest, isTrue);
    },
  );

  test(
    'permanently denied notifications do not attempt an unavailable prompt',
    () async {
      canRequest = false;
      final scheduler = FlutterReminderScheduler();
      expect(
        await scheduler.checkPermission(),
        ReminderPermissionStatus.denied,
      );
      expect(
        await scheduler.requestPermission(),
        ReminderPermissionStatus.denied,
      );
      expect(requests, 0);
      expect(recordedRequest, isFalse);
    },
  );
}
