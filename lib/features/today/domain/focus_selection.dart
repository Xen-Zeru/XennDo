import 'package:xenndo/core/time/local_date.dart';

class FocusSelection {
  const FocusSelection({
    required this.focusDate,
    required this.taskId,
    required this.sortOrder,
  });

  final LocalDate focusDate;
  final String taskId;
  final int sortOrder;
}
