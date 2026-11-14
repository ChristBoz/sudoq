import 'package:flutter_test/flutter_test.dart';
import 'package:sudoq/logic/threshold_logic.dart';
import 'package:sudoq/models/app_event.dart';

AppEvent check(
  int used,
  int? limit, {
  bool warned80 = false,
  bool notified100 = false,
}) => checkThreshold(
  usedMinutes: used,
  limitMinutes: limit,
  warned80: warned80,
  notified100: notified100,
);

void main() {
  test('no goal set: never an event', () {
    expect(check(500, null), AppEvent.none);
  });

  test('below 80%: nothing', () {
    expect(check(35, 45), AppEvent.none);
  });

  test('AC02: 36 of 45 min is the 80% warning', () {
    expect(check(36, 45), AppEvent.warning80);
  });

  test('AC02: warning is not repeated the same day', () {
    expect(check(40, 45, warned80: true), AppEvent.none);
  });

  test('AC01: 45 of 45 min is limit reached', () {
    expect(check(45, 45, warned80: true), AppEvent.limitReached);
  });

  test('jumping straight past 100% reports limit reached, not the warning', () {
    expect(check(60, 45), AppEvent.limitReached);
  });

  test('limit reached is not repeated the same day', () {
    expect(check(90, 45, warned80: true, notified100: true), AppEvent.none);
  });
}
