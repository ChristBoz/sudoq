import 'package:flutter_test/flutter_test.dart';
import 'package:sudoq/logic/usage_check.dart';
import 'package:sudoq/models/app_event.dart';
import 'package:sudoq/models/day_flags.dart';
import 'package:sudoq/models/tracked_app.dart';

void main() {
  final video = TrackedApp(packageName: 'app.video', name: 'Video')
    ..limitMinutes = 45;
  final social = TrackedApp(packageName: 'app.social', name: 'Social')
    ..limitMinutes = 30;
  final noGoal = TrackedApp(packageName: 'app.game', name: 'Game');

  DayFlags fresh() => DayFlags(day: '2026-11-14');

  test('each app is judged against its own goal', () {
    final outcome = evaluateUsage(
      tracked: [video, social, noGoal],
      minutes: {'app.video': 36, 'app.social': 30, 'app.game': 500},
      flags: fresh(),
    );

    expect(outcome.events, hasLength(2));
    expect(outcome.events[0].app, video);
    expect(outcome.events[0].event, AppEvent.warning80);
    expect(outcome.events[0].usedMinutes, 36);
    expect(outcome.events[1].app, social);
    expect(outcome.events[1].event, AppEvent.limitReached);
  });

  test('what was triggered is recorded in the returned flags', () {
    final outcome = evaluateUsage(
      tracked: [video, social],
      minutes: {'app.video': 36, 'app.social': 30},
      flags: fresh(),
    );

    expect(outcome.flags.warned, {'app.video', 'app.social'});
    expect(outcome.flags.notified, {'app.social'});
  });

  test('a second check with the same usage triggers nothing', () {
    final minutes = {'app.video': 36};
    final first = evaluateUsage(
      tracked: [video],
      minutes: minutes,
      flags: fresh(),
    );
    final second = evaluateUsage(
      tracked: [video],
      minutes: minutes,
      flags: first.flags,
    );

    expect(second.events, isEmpty);
  });

  test('the flags passed in are not modified', () {
    final flags = fresh();
    evaluateUsage(tracked: [video], minutes: {'app.video': 45}, flags: flags);
    expect(flags.warned, isEmpty);
    expect(flags.notified, isEmpty);
  });

  test('apps missing from the usage map count as 0 minutes', () {
    final outcome = evaluateUsage(
      tracked: [video],
      minutes: const {},
      flags: fresh(),
    );
    expect(outcome.events, isEmpty);
  });
}
