import 'package:xenndo/features/reminders/application/reminder_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xenndo/app/day_change_listener.dart';
import 'package:xenndo/app/reminder_lifecycle_listener.dart';
import 'package:xenndo/app/router.dart';
import 'package:xenndo/core/theme/app_theme.dart';
import 'package:xenndo/features/settings/application/settings_providers.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class XenndoApp extends ConsumerWidget {
  const XenndoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(reminderNoticeProvider, (previous, message) {
      if (message == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messengerKey.currentState?.showSnackBar(
          SnackBar(content: Text(message)),
        );
      });
    });
    return DayChangeListener(
      child: ReminderLifecycleListener(
        child: MaterialApp.router(
          title: 'XennDo',
          scaffoldMessengerKey: _messengerKey,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ref.watch(themeModeProvider),
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    );
  }
}
