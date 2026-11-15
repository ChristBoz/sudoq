import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoq/logic/sudoku_game.dart';
import 'package:sudoq/main.dart';
import 'package:sudoq/state/app_state.dart';
import 'package:sudoq/widgets/sudoku_board.dart';

import 'fakes.dart';

/// Finds the solution of a puzzle by trying digits cell by cell.
List<List<int>> solve(SudokuGame puzzle) {
  final work = SudokuGame([
    for (final row in puzzle.cells) [...row],
  ]);
  bool fill(int index) {
    if (index == 16) return true;
    final r = index ~/ 4, c = index % 4;
    if (work.isClue(r, c)) return fill(index + 1);
    for (var value = 1; value <= 4; value++) {
      work.setCell(r, c, value);
      if (!work.hasConflict(r, c) && fill(index + 1)) return true;
    }
    work.setCell(r, c, 0);
    return false;
  }

  fill(0);
  return work.cells;
}

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

      await tester.tap(find.text('Continue without these permissions'));
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

  group('the gate shown when a blocked app is opened', () {
    Future<TestApp> openBlockedApp(WidgetTester tester) async {
      final t = TestApp()..usage.minutes = {'app.video': 50};
      await t.trackVideo(limit: 45);
      await t.state.refresh(); // the limit notice was already shown earlier
      t.blocker.pendingGate = 'app.video';
      await pumpApp(tester, app: t);
      return t;
    }

    testWidgets('the app cannot be continued until the puzzle is solved', (
      tester,
    ) async {
      final t = await openBlockedApp(tester);

      expect(find.text('Daily goal reached'), findsOneWidget);
      expect(find.text('Video is past its 45 min daily goal.'), findsOneWidget);

      final button = find.widgetWithText(FilledButton, 'Continue to Video');
      expect(tester.widget<FilledButton>(button).onPressed, isNull);
      expect(t.blocker.passed, isEmpty);
    });

    testWidgets('solving the puzzle lets the app through', (tester) async {
      final t = await openBlockedApp(tester);

      // Work out the answer, then enter it through the buttons.
      final game = tester.widget<SudokuBoard>(find.byType(SudokuBoard)).game;
      final answer = solve(game);
      for (var r = 0; r < 4; r++) {
        for (var c = 0; c < 4; c++) {
          if (game.isClue(r, c)) continue;
          final cell = find.byKey(ValueKey('cell-$r-$c'));
          await tester.ensureVisible(cell);
          await tester.tap(cell);
          await tester.pump();
          final digit = find.byKey(ValueKey('digit-${answer[r][c]}'));
          await tester.ensureVisible(digit);
          await tester.tap(digit);
          await tester.pump();
        }
      }

      final button = find.widgetWithText(FilledButton, 'Continue to Video');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(t.blocker.passed, ['app.video']);
      // The gate is closed; suDOq is back on the dashboard underneath.
      expect(find.text('Continue to Video'), findsNothing);
      expect(find.text('50 / 45 min today'), findsOneWidget);
    });

    testWidgets('"Leave" goes to the home screen without unblocking', (
      tester,
    ) async {
      final t = await openBlockedApp(tester);

      final leave = find.text('Leave Video');
      await tester.ensureVisible(leave);
      await tester.tap(leave);
      await tester.pumpAndSettle();

      expect(t.blocker.wentHome, 1);
      expect(t.blocker.passed, isEmpty);
    });

    testWidgets('the back button cannot skip the puzzle', (tester) async {
      final t = await openBlockedApp(tester);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(t.blocker.wentHome, 1);
      expect(t.blocker.passed, isEmpty);
    });
  });

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
