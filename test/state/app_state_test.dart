import 'package:flutter_test/flutter_test.dart';
import 'package:sudoq/models/app_event.dart';
import 'package:sudoq/models/usage_result.dart';
import 'package:sudoq/state/app_state.dart';

import '../fakes.dart';

void main() {
  group('usage readings', () {
    test(
      'AC06: without permission there is no reading, not 0 minutes',
      () async {
        final t = TestApp()..usage.access = false;
        final app = await t.trackVideo(limit: 45);
        await t.state.refresh();

        expect(t.state.usageAccessGranted, isFalse);
        expect(t.state.usage, isA<UsageUnavailable>());
        expect(t.state.minutesToday(app.packageName), isNull);
      },
    );

    test(
      'AC06: Android returning nothing is "no data", not 0 minutes',
      () async {
        final t = TestApp()..usage.minutes = null;
        final app = await t.trackVideo(limit: 45);
        await t.state.refresh();

        final usage = t.state.usage as UsageUnavailable;
        expect(usage.reason, UsageProblem.noData);
        expect(t.state.minutesToday(app.packageName), isNull);
      },
    );

    test('an app that was not opened today reads 0 minutes', () async {
      final t = TestApp()..usage.minutes = {'app.social': 12};
      final app = await t.trackVideo();
      await t.state.refresh();

      expect(t.state.minutesToday(app.packageName), 0);
    });

    test('granting access later is picked up on refresh', () async {
      final t = TestApp()..usage.access = false;
      await t.trackVideo();
      await t.state.refresh();
      expect(t.state.usageAccessGranted, isFalse);

      t.usage.access = true;
      t.usage.minutes = {'app.video': 7};
      await t.state.refresh();
      expect(t.state.usageAccessGranted, isTrue);
      expect(t.state.minutesToday('app.video'), 7);
    });

    test('today is read from local midnight', () async {
      final t = TestApp(now: DateTime(2026, 11, 14, 15, 30));
      await t.trackVideo();
      await t.state.refresh();

      expect(t.usage.queries.last.start, DateTime(2026, 11, 14));
      expect(t.usage.queries.last.end, DateTime(2026, 11, 14, 15, 30));
    });
  });

  group('warnings and limit notices', () {
    test('AC02: warning at 36 of 45 min, shown once', () async {
      final t = TestApp();
      await t.trackVideo(limit: 45);

      t.usage.minutes = {'app.video': 36};
      final first = await t.state.refresh();
      expect(first.single.event, AppEvent.warning80);

      t.usage.minutes = {'app.video': 40};
      expect(await t.state.refresh(), isEmpty);
    });

    test('AC01: limit reached at 45 of 45 min, shown once', () async {
      final t = TestApp();
      await t.trackVideo(limit: 45);

      t.usage.minutes = {'app.video': 45};
      final first = await t.state.refresh();
      expect(first.single.event, AppEvent.limitReached);
      expect(first.single.usedMinutes, 45);

      t.usage.minutes = {'app.video': 80};
      expect(await t.state.refresh(), isEmpty);
    });

    test('AC04: reaching the limit changes neither usage nor goal', () async {
      final t = TestApp()..usage.minutes = {'app.video': 45};
      final app = await t.trackVideo(limit: 45);
      await t.state.refresh();

      expect(t.state.minutesToday(app.packageName), 45);
      expect(app.limitMinutes, 45);
    });

    test('warnings come back the next day', () async {
      final t = TestApp(now: DateTime(2026, 11, 14, 22, 0));
      await t.trackVideo(limit: 45);
      t.usage.minutes = {'app.video': 45};
      expect(await t.state.refresh(), hasLength(1));

      t.setNow(DateTime(2026, 11, 15, 8, 0));
      expect(await t.state.refresh(), hasLength(1));
    });

    test('paused monitoring shows nothing', () async {
      final t = TestApp()..usage.minutes = {'app.video': 60};
      await t.trackVideo(limit: 45);
      await t.state.setMonitoringPaused(true);

      expect(await t.state.refresh(), isEmpty);
      expect(t.state.minutesToday('app.video'), 60);
    });

    test('notifications switched off shows nothing', () async {
      final t = TestApp()..usage.minutes = {'app.video': 60};
      await t.trackVideo(limit: 45);
      await t.state.setNotificationsEnabled(false);

      expect(await t.state.refresh(), isEmpty);
    });

    test('changing the goal lets its warnings fire again', () async {
      final t = TestApp()..usage.minutes = {'app.video': 45};
      final app = await t.trackVideo(limit: 45);
      expect(await t.state.refresh(), hasLength(1));

      await t.state.setLimit(app, 40);
      final again = await t.state.refresh();
      expect(again.single.event, AppEvent.limitReached);
    });
  });

  group('demo mode', () {
    test('simulated minutes are added and reported separately', () async {
      final t = TestApp()..usage.minutes = {'app.video': 30};
      final app = await t.trackVideo(limit: 45);
      t.state.setDemoMode(true);

      final events = await t.state.simulateUsage(app, 10);
      expect(events.single.event, AppEvent.warning80);
      expect(t.state.minutesToday(app.packageName), 40);
      expect(t.state.simulatedMinutes(app.packageName), 10);
    });

    test('turning demo mode off removes the simulated minutes', () async {
      final t = TestApp()..usage.minutes = {'app.video': 30};
      final app = await t.trackVideo(limit: 45);
      t.state.setDemoMode(true);
      await t.state.simulateUsage(app, 10);

      t.state.setDemoMode(false);
      expect(t.state.minutesToday(app.packageName), 30);
    });
  });

  group('saving', () {
    test('apps, goals and switches survive a restart', () async {
      final t = TestApp();
      await t.trackVideo(limit: 45);
      await t.state.setNotificationsEnabled(false);

      // A new AppState reading the same storage = the app restarted.
      final restarted = AppState(
        usage: t.usage,
        storage: t.storage,
        notifications: t.notifications,
        background: t.background,
      );
      await restarted.loadSaved();

      expect(restarted.onboarded, isTrue);
      expect(restarted.notificationsEnabled, isFalse);
      expect(restarted.trackedApps.single.name, 'Video');
      expect(restarted.trackedApps.single.limitMinutes, 45);
    });

    test('a warning already shown is not repeated after a restart', () async {
      final t = TestApp()..usage.minutes = {'app.video': 45};
      await t.trackVideo(limit: 45);
      expect(await t.state.refresh(), hasLength(1));

      final restarted = AppState(
        usage: t.usage,
        storage: t.storage,
        notifications: t.notifications,
        background: t.background,
        clock: () => t.now,
      );
      await restarted.loadSaved();
      expect(await restarted.refresh(), isEmpty);
    });

    test('unselecting an app stops monitoring it', () async {
      final t = TestApp();
      await t.trackVideo(limit: 45);
      await t.state.setTracked(t.usage.installed.first, false);

      expect(t.state.trackedApps, isEmpty);
      expect(t.storage.settings.tracked, isEmpty);
    });
  });

  group('background check switch', () {
    test('runs after onboarding, stops while paused', () async {
      final t = TestApp();
      expect(t.background.running, isFalse);

      await t.trackVideo();
      expect(t.background.running, isTrue);
      expect(t.notifications.permissionRequested, isTrue);

      await t.state.setMonitoringPaused(true);
      expect(t.background.running, isFalse);

      await t.state.setMonitoringPaused(false);
      expect(t.background.running, isTrue);
    });
  });

  group('history', () {
    test('past days are loaded for the monitored apps, oldest first', () async {
      final t = TestApp(now: DateTime(2026, 11, 14, 15, 0));
      t.usage.pastDays[DateTime(2026, 11, 13)] = {
        'app.video': 50,
        'app.other': 99,
      };
      t.usage.pastDays[DateTime(2026, 11, 12)] = {};
      await t.trackVideo(limit: 45);
      await t.state.loadPastDays();

      final days = t.state.pastDays!;
      expect(days, hasLength(6));
      expect(days.first.day, DateTime(2026, 11, 8));
      expect(days.first.hasData, isFalse); // nothing from Android: a dash
      expect(days[4].minutes, {'app.video': 0}); // used, but not this app
      expect(days[5].minutes, {'app.video': 50}); // other apps not kept
    });

    test('a past day is read from Android only once', () async {
      final t = TestApp(now: DateTime(2026, 11, 14, 15, 0));
      t.usage.pastDays[DateTime(2026, 11, 13)] = {'app.video': 50};
      await t.trackVideo();
      await t.state.loadPastDays();

      t.usage.queries.clear();
      await t.state.loadPastDays();
      final reread = t.usage.queries.where(
        (q) => q.start == DateTime(2026, 11, 13),
      );
      expect(reread, isEmpty);
    });

    test('FR05: a goal is suggested once three days are observed', () async {
      final t = TestApp(now: DateTime(2026, 11, 14, 15, 0));
      await t.trackVideo();
      t.usage.pastDays[DateTime(2026, 11, 13)] = {'app.video': 60};
      t.usage.pastDays[DateTime(2026, 11, 12)] = {'app.video': 60};
      await t.state.loadPastDays();
      expect(t.state.suggestedGoal('app.video'), isNull);

      t.usage.pastDays[DateTime(2026, 11, 11)] = {'app.video': 60};
      await t.state.loadPastDays();
      expect(t.state.suggestedGoal('app.video'), 55);
      expect(t.state.recentAverage('app.video'), 60);
      expect(t.state.observedDays('app.video'), 3);
    });

    test('FR09: deleting history hides everything before now', () async {
      final t = TestApp(now: DateTime(2026, 11, 14, 15, 0));
      t.usage.pastDays[DateTime(2026, 11, 13)] = {'app.video': 50};
      t.usage.minutes = {'app.video': 45};
      final app = await t.trackVideo(limit: 45);
      await t.state.refresh();
      await t.state.loadPastDays();

      // After deleting, Android has nothing newer than "now" yet.
      t.usage.minutes = null;
      await t.state.clearUsageHistory();
      await t.state.loadPastDays();

      expect(t.storage.summaries, isEmpty);
      expect(t.state.pastDays!.every((day) => !day.hasData), isTrue);
      expect(t.state.minutesToday(app.packageName), 0);
      expect(t.usage.queries.last.start, DateTime(2026, 11, 14, 15, 0));
      expect(app.limitMinutes, 45); // goals are kept
    });
  });
}
