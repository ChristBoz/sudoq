import 'package:flutter_test/flutter_test.dart';
import 'package:sudoq/services/background_service.dart';

import '../fakes.dart';

void main() {
  Future<void> runCheck(TestApp t) => runBackgroundCheck(
    usage: t.usage,
    storage: t.storage,
    notifications: t.notifications,
    now: t.now,
  );

  test('AC01: reaching the goal sends the limit notification once', () async {
    final t = TestApp()..usage.minutes = {'app.video': 45};
    await t.trackVideo(limit: 45);

    await runCheck(t);
    expect(t.notifications.shown, ['limit:app.video:45']);

    await runCheck(t);
    expect(t.notifications.shown, hasLength(1));
  });

  test('AC02: 80% sends the warning, then the limit later', () async {
    final t = TestApp()..usage.minutes = {'app.video': 36};
    await t.trackVideo(limit: 45);

    await runCheck(t);
    t.usage.minutes = {'app.video': 47};
    await runCheck(t);

    expect(t.notifications.shown, [
      'warning:app.video:36',
      'limit:app.video:47',
    ]);
  });

  test('a notice sent in the background is not repeated in the app', () async {
    final t = TestApp()..usage.minutes = {'app.video': 45};
    await t.trackVideo(limit: 45);

    await runCheck(t);
    expect(await t.state.refresh(), isEmpty);
  });

  test('nothing is sent without usage access', () async {
    final t = TestApp()
      ..usage.access = false
      ..usage.minutes = {'app.video': 99};
    await t.trackVideo(limit: 45);

    await runCheck(t);
    expect(t.notifications.shown, isEmpty);
  });

  test('nothing is sent while paused or with notifications off', () async {
    final t = TestApp()..usage.minutes = {'app.video': 99};
    await t.trackVideo(limit: 45);

    await t.state.setMonitoringPaused(true);
    await runCheck(t);
    expect(t.notifications.shown, isEmpty);

    await t.state.setMonitoringPaused(false);
    await t.state.setNotificationsEnabled(false);
    await runCheck(t);
    expect(t.notifications.shown, isEmpty);
  });

  test('nothing is sent before onboarding is finished', () async {
    final t = TestApp()..usage.minutes = {'app.video': 99};
    await runCheck(t);
    expect(t.notifications.shown, isEmpty);
  });
}
