import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_app.dart';

void main() {
  testWidgets('app starts on Today with the shell available', (tester) async {
    await pumpXenndoApp(tester);

    expect(find.byKey(const ValueKey('today-screen')), findsOneWidget);
    expect(find.byKey(const ValueKey('add-task-fab')), findsOneWidget);
    expect(find.byTooltip('Progress'), findsOneWidget);
    expect(find.byKey(const ValueKey('today-progress-empty')), findsOneWidget);
  });
}
