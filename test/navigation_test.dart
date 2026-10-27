import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

Future<void> _pumpApp(WidgetTester tester) async {
  await pumpXenndoApp(tester, now: DateTime(2026, 10, 19, 12));
}

Future<void> _tapNavigationDestination(WidgetTester tester, String key) async {
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('primary navigation reaches every shell destination', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);

    await _tapNavigationDestination(tester, 'nav-upcoming');
    expect(find.byKey(const ValueKey('upcoming-screen')), findsOneWidget);
    expect(find.text('Upcoming'), findsWidgets);

    await _tapNavigationDestination(tester, 'nav-lists');
    expect(find.byKey(const ValueKey('lists-screen')), findsOneWidget);
    expect(find.text('My lists'), findsOneWidget);

    await _tapNavigationDestination(tester, 'nav-settings');
    expect(find.byKey(const ValueKey('settings-screen')), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-task-fab')), findsNothing);

    await _tapNavigationDestination(tester, 'nav-today');
    expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
  });

  testWidgets('add task action opens the editor and progress opens', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('progress-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('progress-screen')), findsOneWidget);
    expect(find.text('No progress yet'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-task-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-editor-screen')), findsOneWidget);
    expect(find.text('Add task'), findsOneWidget);
    expect(find.byKey(const ValueKey('task-title-field')), findsOneWidget);
    expect(find.byKey(const ValueKey('task-list-field')), findsOneWidget);
  });

  testWidgets('theme mode can switch between system, light, and dark', (
    tester,
  ) async {
    await _pumpApp(tester);
    await _tapNavigationDestination(tester, 'nav-settings');

    MaterialApp app() {
      return tester.widget<MaterialApp>(find.byType(MaterialApp));
    }

    expect(app().themeMode, ThemeMode.system);

    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    expect(app().themeMode, ThemeMode.dark);
    expect(
      Theme.of(tester.element(find.byKey(const ValueKey('settings-screen'))))
          .brightness,
      Brightness.dark,
    );

    await tester.tap(find.byKey(const ValueKey('theme-light')));
    await tester.pumpAndSettle();
    expect(app().themeMode, ThemeMode.light);
    expect(
      Theme.of(tester.element(find.byKey(const ValueKey('settings-screen'))))
          .brightness,
      Brightness.light,
    );

    await tester.tap(find.byKey(const ValueKey('theme-system')));
    await tester.pumpAndSettle();
    expect(app().themeMode, ThemeMode.system);
  });

  testWidgets('shell and editor fit a 320 dp screen at 200% text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await _pumpApp(tester);
    expect(tester.takeException(), isNull);

    final destinations = <String, String>{
      'nav-upcoming': 'upcoming-screen',
      'nav-lists': 'lists-screen',
      'nav-settings': 'settings-screen',
      'nav-today': 'today-screen',
    };

    for (final entry in destinations.entries) {
      await _tapNavigationDestination(tester, entry.key);
      expect(find.byKey(ValueKey(entry.value)), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Unexpected overflow on ${entry.key}',
      );
    }

    await tester.tap(find.byKey(const ValueKey('add-task-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('task-editor-screen')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('save-task-button')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.takeException(), isNull);
  });
}
