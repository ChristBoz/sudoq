import 'package:flutter_test/flutter_test.dart';

import '../fakes.dart';

void main() {
  group('what the blocker is told', () {
    test('it is off until onboarding is finished', () async {
      final t = TestApp();
      await t.state.start();
      expect(t.blocker.enabled, isFalse);
    });

    test('it gets every monitored app that has a goal', () async {
      final t = TestApp();
      await t.trackVideo(limit: 45);
      await t.state.setTracked(t.usage.installed[1], true); // no goal yet

      expect(t.blocker.enabled, isTrue);
      expect(t.blocker.rules.keys, ['app.video']);
      expect(t.blocker.rules['app.video']!.limitMinutes, 45);
    });

    test('a changed goal reaches it straight away', () async {
      final t = TestApp();
      final app = await t.trackVideo(limit: 45);
      await t.state.setLimit(app, 20);

      expect(t.blocker.rules['app.video']!.limitMinutes, 20);
    });

    test('an unselected app is no longer blocked', () async {
      final t = TestApp();
      await t.trackVideo(limit: 45);
      await t.state.setTracked(t.usage.installed.first, false);

      expect(t.blocker.rules, isEmpty);
    });

    test('pausing or switching the setting off stops it', () async {
      final t = TestApp();
      await t.trackVideo(limit: 45);

      await t.state.setMonitoringPaused(true);
      expect(t.blocker.enabled, isFalse);
      await t.state.setMonitoringPaused(false);
      expect(t.blocker.enabled, isTrue);

      await t.state.setBlockingEnabled(false);
      expect(t.blocker.enabled, isFalse);
    });

    test('demo-mode minutes count for blocking too', () async {
      final t = TestApp()..usage.minutes = {'app.video': 30};
      final app = await t.trackVideo(limit: 45);
      t.state.setDemoMode(true);
      await t.state.simulateUsage(app, 15);

      expect(t.blocker.rules['app.video']!.extraMinutes, 15);
    });

    test('deleting history tells it to ignore earlier usage', () async {
      final t = TestApp(now: DateTime(2026, 11, 14, 15, 0));
      await t.trackVideo(limit: 45);
      await t.state.clearUsageHistory();

      expect(
        t.blocker.historyStartMs,
        DateTime(2026, 11, 14, 15, 0).millisecondsSinceEpoch,
      );
    });

    test('the setting survives a restart', () async {
      final t = TestApp();
      await t.trackVideo(limit: 45);
      await t.state.setBlockingEnabled(false);

      final restarted = t.newState();
      await restarted.loadSaved();
      expect(restarted.blockingEnabled, isFalse);
    });
  });

  group('the gate', () {
    test('a blocked app is reported once, with its name and goal', () async {
      final t = TestApp();
      await t.trackVideo(limit: 45);
      t.blocker.pendingGate = 'app.video';

      final app = await t.state.takePendingGate();
      expect(app!.name, 'Video');
      expect(app.limitMinutes, 45);
      expect(await t.state.takePendingGate(), isNull);
    });

    test('solving lets that app through; leaving goes home', () async {
      final t = TestApp();
      final app = await t.trackVideo(limit: 45);

      await t.state.passGate(app);
      expect(t.blocker.passed, ['app.video']);

      await t.state.leaveGate();
      expect(t.blocker.wentHome, 1);
    });

    test('the missing overlay permission is noticed on refresh', () async {
      final t = TestApp()..blocker.overlay = false;
      await t.trackVideo(limit: 45);
      await t.state.refresh();
      expect(t.state.overlayGranted, isFalse);

      t.blocker.overlay = true;
      await t.state.refresh();
      expect(t.state.overlayGranted, isTrue);
    });
  });
}
