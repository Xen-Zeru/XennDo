import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/database/database_provider.dart';
import 'package:xenndo/core/time/current_date_provider.dart';
import 'package:xenndo/features/tasks/domain/task_item.dart';
import 'package:xenndo/features/today/data/focus_repository.dart';

final focusRepositoryProvider = Provider<FocusRepository>((ref) {
  return FocusRepository(ref.watch(databaseProvider));
});

final topThreeProvider = StreamProvider.autoDispose<List<TaskItem>>((ref) {
  final today = ref.watch(currentDateProvider);
  return ref.watch(focusRepositoryProvider).watchTopThree(today);
});
