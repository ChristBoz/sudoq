import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoq/main.dart';
import 'package:sudoq/state/app_state.dart';

import 'fakes.dart';

/// Starts the whole app on fakes.
Future<TestApp> pumpApp(WidgetTester tester, {TestApp? app}) async {
  final t = app ?? TestApp();
  appState = t.state;
  await t.state.loadSaved();
  await tester.pumpWidget(const SudoqApp());
  await tester.pumpAndSettle();
  return t;
}

void main() {
  testWidgets('first launch shows onboarding with the permission request', (
    tester,
  ) async {
    final t = await pumpApp(tester, app: TestApp()..usage.access = false);

    expect(find.text('Grant usage access'), findsOneWidget);
    await tester.tap(find.text('Grant usage access'));
    expect(t.usage.settingsOpened, isTrue);
  });

  testWidgets(
    'FR01: continuing without access leads to a clear limited state',
    (tester) async {
      await pumpApp(tester, app: TestApp()..usage.access = false);

      await tester.tap(find.text('Continue without access'));
      await tester.pumpAndSettle();
      expect(find.text('Select apps'), findsOneWidget);

      // Chat is messaging: not offered by default (FR02).
      expect(find.text('Video'), findsOneWidget);
      expect(find.text('Chat'), findsNothing);

      await tester.tap(find.text('Video'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(find.text('Usage data unavailable'), findsOneWidget);
      expect(find.textContaining('— min today'), findsOneWidget);
    },
  );

  testWidgets('AC07: dashboard with no apps shows the empty state', (
    tester,
  ) async {
    final t = TestApp();
    await t.state.completeOnboarding();
    await pumpApp(tester, app: t);

    expect(find.text('No apps selected yet.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Select apps'), findsOneWidget);
  });

  testWidgets('AC05: an invalid goal is blocked with a message', (
    tester,
  ) async {
    final t = TestApp()..usage.minutes = {'app.video': 10};
    await t.trackVideo();
    await pumpApp(tester, app: t);

    await tester.tap(find.text('Set goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '0');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('The limit must be greater than 0'), findsOneWidget);
    expect(t.state.trackedApps.single.limitMinutes, isNull);

    await tester.enterText(find.byType(TextFormField), '45');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(t.state.trackedApps.single.limitMinutes, 45);
    expect(find.text('10 / 45 min today'), findsOneWidget);
  });

  testWidgets(
    'AC01 + AC03 + AC04: limit notice opens Sudoku, usage unchanged',
    (tester) async {
      final t = TestApp()..usage.minutes = {'app.video': 45};
      await t.trackVideo(limit: 45);
      await pumpApp(tester, app: t);

      // Opening the app found the goal reached.
      expect(find.text('You reached your goal'), findsOneWidget);
      expect(find.text('View usage'), findsOneWidget);
      expect(find.text('Dismiss'), findsOneWidget);

      await tester.tap(find.text('Play Sudoku'));
      await tester.pumpAndSettle();
      expect(find.text('Sudoku break'), findsOneWidget);

      await tester.tap(find.text('Exit'));
      await tester.pumpAndSettle();
      expect(find.text('45 / 45 min today'), findsOneWidget);
      expect(find.text('Daily goal reached'), findsOneWidget);
    },
  );
}
