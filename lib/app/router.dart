import 'package:xenndo/features/settings/presentation/about_screen.dart';
import 'package:xenndo/features/progress/presentation/completion_history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xenndo/app/app_shell.dart';
import 'package:xenndo/features/lists/presentation/list_detail_screen.dart';
import 'package:xenndo/features/lists/presentation/lists_screen.dart';
import 'package:xenndo/features/progress/presentation/progress_screen.dart';
import 'package:xenndo/features/search/presentation/search_screen.dart';
import 'package:xenndo/features/settings/presentation/settings_screen.dart';
import 'package:xenndo/features/tasks/presentation/task_edit_loader.dart';
import 'package:xenndo/features/tasks/presentation/task_editor_screen.dart';
import 'package:xenndo/features/today/presentation/today_screen.dart';
import 'package:xenndo/features/today/presentation/top_three_picker_screen.dart';
import 'package:xenndo/features/upcoming/presentation/upcoming_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/today',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/today',
                name: 'today',
                builder: (context, state) => const TodayScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/upcoming',
                name: 'upcoming',
                builder: (context, state) => const UpcomingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/lists',
                name: 'lists',
                builder: (context, state) => const ListsScreen(),
                routes: [
                  GoRoute(
                    path: ':listId',
                    name: 'listDetail',
                    builder: (context, state) => ListDetailScreen(
                      listId: state.pathParameters['listId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/tasks/new',
        name: 'newTask',
        builder: (context, state) => TaskEditorScreen(
          initialListId: state.uri.queryParameters['listId'],
        ),
      ),
      GoRoute(
        path: '/tasks/:taskId/edit',
        name: 'editTask',
        builder: (context, state) =>
            TaskEditLoader(taskId: state.pathParameters['taskId']!),
      ),
      GoRoute(
        path: '/search',
        name: 'search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/top-three',
        name: 'topThreePicker',
        builder: (context, state) => const TopThreePickerScreen(),
      ),
      GoRoute(
        path: '/history',
        name: 'completionHistory',
        builder: (context, state) => const CompletionHistoryScreen(),
      ),
      GoRoute(
        path: '/about',
        name: 'about',
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: '/progress',
        name: 'progress',
        builder: (context, state) => const ProgressScreen(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
