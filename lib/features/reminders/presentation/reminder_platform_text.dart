import 'package:flutter/foundation.dart';

/// User-facing platform guidance, shared by Settings and the task editor.
abstract final class ReminderPlatformText {
  static String settingsName(TargetPlatform platform) => switch (platform) {
    TargetPlatform.iOS => 'iOS Settings',
    TargetPlatform.android => 'Android settings',
    _ => 'system settings',
  };

  static String settingsInstructions(TargetPlatform platform) =>
      switch (platform) {
        TargetPlatform.iOS => 'Open iOS Settings → Notifications → XennDo.',
        TargetPlatform.android =>
          'Open Android Settings, then Apps → XennDo → Notifications.',
        _ => 'Open system notification settings for XennDo.',
      };

  static String deliveryExplanation(TargetPlatform platform) =>
      platform == TargetPlatform.iOS
      ? 'iOS Focus, Scheduled Summary, and notification settings may delay or silence reminders. '
            'Up to 64 reminders can be pending; additional reminders require a retry after a slot is free. '
            'Reopen XennDo after changing time zones to refresh local reminder times.'
      : 'Android may delay reminder delivery because of battery restrictions or unavailable exact alarms. '
            'Reminders keep their chosen local time if the device time zone changes.';
}
