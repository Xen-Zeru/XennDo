import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';

import 'reminders/fake_reminder_scheduler.dart';
import 'support/test_app.dart';

void main() {
  testWidgets(
    'iOS denial uses Settings guidance and leaves task management usable',
    (tester) async {
      final scheduler = FakeReminderScheduler()
        ..permission = ReminderPermissionStatus.denied;
      await pumpXenndoApp(tester, reminderScheduler: scheduler);
      await tester.tap(find.byKey(const ValueKey('nav-settings')));
      await tester.pumpAndSettle();
      expect(find.textContaining('iOS Settings'), findsOneWidget);
      expect(find.textContaining('Android'), findsNothing);
      expect(find.byKey(const ValueKey('add-task-fab')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const ValueKey('open-system-notification-settings')),
      );
      await tester.tap(
        find.byKey(const ValueKey('open-system-notification-settings')),
      );
      await tester.pumpAndSettle();
      expect(scheduler.openSettingsCalled, isTrue);
      await tester.tap(find.byKey(const ValueKey('nav-today')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-task-fab')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('task-schedule-section')),
      );
      await tester.tap(find.byKey(const ValueKey('task-schedule-section')));
      await tester.pumpAndSettle();
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('reminder-switch')))
          .onChanged!(true);
      await tester.pumpAndSettle();
      expect(find.textContaining('iOS Settings'), findsOneWidget);
      expect(find.textContaining('Android'), findsNothing);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const ValueKey('reminder-switch')),
            )
            .value,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );

  testWidgets(
    'iOS safe areas, large text and keyboard keep validation and draft protection reachable',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 34);
      tester.view.padding = const FakeViewPadding(top: 44, bottom: 34);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(() {
        tester.view.resetDevicePixelRatio();
        tester.view.resetPhysicalSize();
        tester.view.resetPadding();
        tester.view.resetViewPadding();
        tester.view.resetViewInsets();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await pumpXenndoAppLive(
        tester,
        reminderScheduler: FakeReminderScheduler(),
      );
      for (final nav in [
        'nav-upcoming',
        'nav-lists',
        'nav-settings',
        'nav-today',
      ]) {
        await tester.tap(find.byKey(ValueKey(nav)));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: nav);
      }
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('today-screen'))).dy,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.byKey(const ValueKey('add-task-fab')));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      tester.view.padding = const FakeViewPadding(top: 44);
      await tester.pumpAndSettle();
      final save = find.byKey(const ValueKey('save-task-button'));
      expect(tester.getBottomLeft(save).dy, lessThanOrEqualTo(512));
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Enter a task title.'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('task-title-field')),
        'Keep my draft',
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Discard changes?'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await disposeXenndoApp(tester);
    },
    variant: const TargetPlatformVariant({TargetPlatform.iOS}),
  );
}
