import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reports platform failures separately from successful database writes.
final reminderNoticeProvider = NotifierProvider<ReminderNotice, String?>(
  ReminderNotice.new,
);

class ReminderNotice extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) {
    state = null;
    state = message;
  }
}
