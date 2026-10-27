import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:xenndo/core/theme/app_spacing.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final scaledLabelHeight = MediaQuery.textScalerOf(context).scale(14);
    final hideLabels = scaledLabelHeight > 19;
    final route = GoRouterState.of(context).uri.pathSegments;
    final isListDetail = route.length > 1 && route.first == 'lists';
    final showAddTask = navigationShell.currentIndex < 2 && !isListDetail;

    return Scaffold(
      body: Padding(
        // With large text, controls often wrap onto another line. Keep the FAB
        // below the scrolling viewport so it cannot cover those controls.
        padding: EdgeInsets.only(
          bottom: showAddTask && hideLabels
              ? AppSpacing.floatingActionClearance
              : 0,
        ),
        child: navigationShell,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        labelBehavior: hideLabels
            ? NavigationDestinationLabelBehavior.alwaysHide
            : NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: const [
          NavigationDestination(
            key: ValueKey('nav-today'),
            icon: Icon(Icons.event_available_outlined),
            selectedIcon: Icon(Icons.event_available_rounded),
            label: 'Today',
            tooltip: 'Today',
          ),
          NavigationDestination(
            key: ValueKey('nav-upcoming'),
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded),
            label: 'Upcoming',
            tooltip: 'Upcoming',
          ),
          NavigationDestination(
            key: ValueKey('nav-lists'),
            icon: Icon(Icons.format_list_bulleted_rounded),
            selectedIcon: Icon(Icons.format_list_bulleted_rounded),
            label: 'Lists',
            tooltip: 'Lists',
          ),
          NavigationDestination(
            key: ValueKey('nav-settings'),
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
            tooltip: 'Settings',
          ),
        ],
      ),
      floatingActionButton: !showAddTask
          ? null
          : SizedBox(
              width: 64,
              height: 64,
              child: FloatingActionButton(
                key: const ValueKey('add-task-fab'),
                tooltip: 'Add task',
                onPressed: () => context.pushNamed('newTask'),
                child: const Icon(Icons.add_rounded, size: 32),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

class ShellPagePadding extends StatelessWidget {
  const ShellPagePadding({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.pageBottom),
      child: child,
    );
  }
}
