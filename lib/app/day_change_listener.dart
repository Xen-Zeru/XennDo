import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/core/time/clock_provider.dart';
import 'package:xenndo/core/time/current_date_provider.dart';
import 'package:xenndo/features/tasks/application/task_providers.dart';
import 'package:xenndo/features/today/application/focus_providers.dart';

/// Refreshes date-based views when the app resumes or the local day changes.
class DayChangeListener extends ConsumerStatefulWidget {
  const DayChangeListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DayChangeListener> createState() => _DayChangeListenerState();
}

class _DayChangeListenerState extends ConsumerState<DayChangeListener>
    with WidgetsBindingObserver {
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRefresh();
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDateBasedViews();
      _scheduleMidnightRefresh();
    }
  }

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = ref.read(nowProvider)();
    // Minute boundaries refresh time-based overdue labels as well as midnight.
    final nextMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    final delay = nextMinute.difference(now) + const Duration(milliseconds: 50);
    _midnightTimer = Timer(delay, () {
      _refreshDateBasedViews(refreshAll: false);
      _scheduleMidnightRefresh();
    });
  }

  void _refreshDateBasedViews({bool refreshAll = true}) {
    ref.read(currentDateProvider.notifier).refresh();
    ref.invalidate(todayAgendaProvider);
    if (refreshAll) {
      ref.invalidate(upcomingTasksProvider);
      ref.invalidate(topThreeProvider);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
