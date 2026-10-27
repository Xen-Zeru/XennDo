import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/features/reminders/application/reminder_reconciler.dart';
import 'package:xenndo/features/reminders/data/flutter_reminder_scheduler.dart';
import 'package:xenndo/features/reminders/domain/reminder_scheduler.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';

final reminderSchedulerProvider = Provider<ReminderScheduler>((ref) {
  return FlutterReminderScheduler();
});

final reminderReconcilerProvider = Provider<ReminderReconciler>((ref) {
  return ReminderReconciler(
    tasks: ref.watch(taskRepositoryProvider),
    scheduler: ref.watch(reminderSchedulerProvider),
    clock: ref.watch(nowProvider),
  );
});
