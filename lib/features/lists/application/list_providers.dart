import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/database/database_provider.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/features/lists/data/list_repository.dart';
import 'package:xenndo/features/lists/domain/task_list_model.dart';

final listRepositoryProvider = Provider<ListRepository>((ref) {
  return ListRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(nowProvider),
  );
});

final listsProvider = StreamProvider.autoDispose<List<TaskListModel>>((ref) {
  return ref.watch(listRepositoryProvider).watchLists();
});

final listSummariesProvider = StreamProvider.autoDispose<List<TaskListSummary>>(
  (ref) {
    return ref.watch(listRepositoryProvider).watchListsWithOpenCounts();
  },
);
