import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:xenndo/features/reminders/data/flutter_reminder_scheduler.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const notifications = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );
  const settings = MethodChannel('xenndo/settings');
  const timezone = MethodChannel('flutter_timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;
  late bool enabled;
  late bool provisional;
  late bool canRequest;
  late bool grantRequest;
  late String localZone;
  late List<Map<String, Object?>> pending;
  late FlutterReminderScheduler scheduler;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    calls = [];
    enabled = false;
    provisional = false;
    canRequest = true;
    grantRequest = false;
    localZone = 'Asia/Singapore';
    pending = [];
    scheduler = FlutterReminderScheduler();
    messenger.setMockMethodCallHandler(notifications, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'initialize':
          return true;
        case 'checkPermissions':
          return {'isEnabled': enabled, 'isProvisionalEnabled': provisional};
        case 'requestPermissions':
          enabled = grantRequest;
          canRequest = false;
          return grantRequest;
        case 'pendingNotificationRequests':
          return pending;
        case 'openAppNotificationSettings':
          return true;
        case 'getNotificationAppLaunchDetails':
          return {
            'notificationLaunchedApp': true,
            'notificationResponse': {
              'notificationId': 7,
              'notificationResponseType': 0,
              'payload': 'cold-task',
            },
          };
      }
      return null;
    });
    messenger.setMockMethodCallHandler(settings, (call) async {
      expect(call.method, 'canRequestNotificationPermission');
      return canRequest;
    });
    messenger.setMockMethodCallHandler(timezone, (_) async => localZone);
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(notifications, null);
    messenger.setMockMethodCallHandler(settings, null);
    messenger.setMockMethodCallHandler(timezone, null);
    tz.setLocalLocation(tz.UTC);
  });

  test(
    'initialization never prompts and resume refreshes the local zone',
    () async {
      await scheduler.initialize(onNotificationTap: (_) {});
      final args =
          calls.singleWhere((c) => c.method == 'initialize').arguments as Map;
      expect(args['requestAlertPermission'], isFalse);
      expect(args['requestSoundPermission'], isFalse);
      expect(args['requestBadgePermission'], isFalse);
      expect(tz.local.name, 'Asia/Singapore');
      localZone = 'America/New_York';
      await scheduler.initialize(onNotificationTap: (_) {});
      expect(tz.local.name, 'America/New_York');
      expect(calls.where((c) => c.method == 'initialize'), hasLength(1));
      expect(calls.where((c) => c.method == 'requestPermissions'), isEmpty);
    },
  );

  test('not determined prompts once; denial then requires Settings', () async {
    expect(
      await scheduler.checkPermission(),
      ReminderPermissionStatus.requestable,
    );
    expect(
      await scheduler.requestPermission(),
      ReminderPermissionStatus.denied,
    );
    expect(
      await scheduler.requestPermission(),
      ReminderPermissionStatus.denied,
    );
    final requests = calls
        .where((c) => c.method == 'requestPermissions')
        .toList();
    expect(requests, hasLength(1));
    expect((requests.single.arguments as Map)['alert'], isTrue);
    expect((requests.single.arguments as Map)['sound'], isTrue);
    expect((requests.single.arguments as Map)['badge'], isFalse);
    expect(await scheduler.openNotificationSettings(), isTrue);
    expect(calls.last.method, 'openAppNotificationSettings');
  });

  test('granted and provisional permissions do not prompt again', () async {
    grantRequest = true;
    expect(
      await scheduler.requestPermission(),
      ReminderPermissionStatus.granted,
    );
    calls.clear();
    expect(
      await scheduler.requestPermission(),
      ReminderPermissionStatus.granted,
    );
    expect(calls.where((c) => c.method == 'requestPermissions'), isEmpty);
    enabled = false;
    provisional = true;
    expect(await scheduler.checkPermission(), ReminderPermissionStatus.granted);
  });

  test('scheduling retains UTC instant, content and task payload; cancel uses same id', () async {
    await scheduler.initialize(onNotificationTap: (_) {});
    final when = DateTime.now().toUtc().add(const Duration(days: 2));
    await scheduler.schedule(
      notificationId: 7,
      taskId: 'task-7',
      title: 'Task',
      body: 'Notes',
      when: when,
    );
    final args =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments as Map;
    expect(args['timeZoneName'], tz.UTC.name);
    expect(
      DateTime.parse(args['scheduledDateTimeISO8601'] as String).toUtc(),
      when,
    );
    expect(args['payload'], 'task-7');
    expect(args['body'], 'Notes');
    expect((args['platformSpecifics'] as Map)['presentBanner'], isTrue);
    await scheduler.cancel(7);
    expect(calls.last.method, 'cancel');
    expect(calls.last.arguments, 7);
  });

  test('a full queue refuses a new reminder instead of evicting one', () async {
    await scheduler.initialize(onNotificationTap: (_) {});
    pending = List.generate(
      64,
      (id) => {'id': id, 'title': 'Task', 'body': null, 'payload': 'task-$id'},
    );
    final when = DateTime.now().add(const Duration(days: 1));
    await expectLater(
      scheduler.schedule(
        notificationId: 65,
        taskId: 'new',
        title: 'New',
        when: when,
      ),
      throwsA(isA<ReminderCapacityException>()),
    );
    expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
    await scheduler.schedule(
      notificationId: 3,
      taskId: 'task-3',
      title: 'Updated',
      when: when,
    );
    expect(calls.where((c) => c.method == 'zonedSchedule'), hasLength(1));
  });

  test('warm and cold notification taps preserve task identifiers', () async {
    String? opened;
    await scheduler.initialize(onNotificationTap: (id) => opened = id);
    await messenger.handlePlatformMessage(
      notifications.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('didReceiveNotificationResponse', {
          'notificationId': 7,
          'notificationResponseType': 0,
          'payload': 'warm-task',
        }),
      ),
      (_) {},
    );
    expect(opened, 'warm-task');
    expect(await scheduler.takeInitialTaskId(), 'cold-task');
  });
}
