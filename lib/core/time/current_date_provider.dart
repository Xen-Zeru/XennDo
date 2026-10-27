import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/core/time/local_date.dart';

final currentDateProvider = NotifierProvider<CurrentDateController, LocalDate>(
  CurrentDateController.new,
);

class CurrentDateController extends Notifier<LocalDate> {
  @override
  LocalDate build() => LocalDate.fromDateTime(ref.watch(nowProvider)());

  /// Re-reads the current local date. Called when the app resumes or when the
  /// local day changes while the app is open.
  void refresh() {
    final next = LocalDate.fromDateTime(ref.read(nowProvider)());
    if (next != state) {
      state = next;
    }
  }
}
