import 'package:flutter_test/flutter_test.dart';
import 'package:sudoq/logic/day_rollover.dart';
import 'package:sudoq/models/day_flags.dart';

void main() {
  test('dayKey pads months and days', () {
    expect(dayKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
  });

  test('startOfDay and startOfNextDay are local midnights', () {
    final time = DateTime(2026, 11, 14, 15, 30);
    expect(startOfDay(time), DateTime(2026, 11, 14));
    expect(startOfNextDay(time), DateTime(2026, 11, 15));
  });

  test('startOfNextDay crosses month and year ends', () {
    expect(startOfNextDay(DateTime(2026, 12, 31, 8)), DateTime(2027, 1, 1));
  });

  test('previousDays lists the days before today, oldest first', () {
    final days = previousDays(DateTime(2026, 11, 2, 9), 3);
    expect(days, [
      DateTime(2026, 10, 30),
      DateTime(2026, 10, 31),
      DateTime(2026, 11, 1),
    ]);
  });

  test('flags are kept during the same day', () {
    final flags = DayFlags(day: '2026-11-14', warned: {'app.video'});
    final result = flagsForToday(flags, DateTime(2026, 11, 14, 23, 59));
    expect(result.warned, {'app.video'});
  });

  test('flags reset after midnight', () {
    final flags = DayFlags(
      day: '2026-11-14',
      warned: {'app.video'},
      notified: {'app.video'},
    );
    final result = flagsForToday(flags, DateTime(2026, 11, 15, 0, 1));
    expect(result.day, '2026-11-15');
    expect(result.warned, isEmpty);
    expect(result.notified, isEmpty);
  });

  test('no saved flags gives fresh flags for today', () {
    expect(flagsForToday(null, DateTime(2026, 11, 14)).day, '2026-11-14');
  });
}
