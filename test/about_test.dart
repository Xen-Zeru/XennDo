import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:xenndo/features/settings/application/settings_providers.dart';

import 'support/test_app.dart';

Future<void> _openAbout(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav-settings')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('about-details')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const ValueKey('about-details')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'About reads actual version/build, opens Flutter licenses and returns to Settings',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpXenndoApp(tester);
      PackageInfo.setMockInitialValues(
        appName: 'XennDo',
        packageName: 'com.xennzeru.xenndo',
        version: '2.3.4',
        buildNumber: '27',
        buildSignature: 'test',
      );
      await _openAbout(tester);
      expect(find.text('About XennDo'), findsOneWidget);
      expect(find.text('Plan your day. Get it done.'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('about-licenses')),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('2.3.4 · Build 27'), findsOneWidget);
      expect(find.text('Xenn Jan'), findsOneWidget);
      expect(find.bySemanticsLabel('Open-source licenses'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('about-licenses')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('about-licenses')));
      await tester.pumpAndSettle();
      expect(find.byType(LicensePage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('about-screen')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('settings-screen')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('app-version'))).data,
        'Version 2.3.4',
      );
      expect(find.textContaining('(27)'), findsNothing);
      semantics.dispose();
      await disposeXenndoApp(tester);
    },
  );

  testWidgets('About scrolls on a small screen at large text in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 560);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await pumpXenndoApp(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('today-screen'))),
    );
    await container.read(themeModeControllerProvider).setMode(ThemeMode.dark);
    await tester.pumpAndSettle();
    await _openAbout(tester);
    expect(
      Theme.of(tester.element(find.byKey(const ValueKey('about-screen'))))
          .brightness,
      Brightness.dark,
    );
    for (final heading in [
      'Plan with purpose',
      'Focus on what matters',
      'Available offline',
      'Your data, your control',
    ]) {
      await tester.scrollUntilVisible(
        find.text(heading),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('about-licenses')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1.0.0 · Build 1'), findsOneWidget);
    expect(find.text('Xenn Jan'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('about-licenses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('about-licenses')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeXenndoApp(tester);
  });
}
