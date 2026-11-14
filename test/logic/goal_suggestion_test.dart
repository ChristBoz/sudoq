import 'package:flutter_test/flutter_test.dart';
import 'package:sudoq/logic/goal_suggestion.dart';

void main() {
  test('no suggestion before the observation period is over', () {
    expect(suggestGoal([60, 60]), isNull);
  });

  test('suggests a little under the recent average, rounded to 5', () {
    // average 60 -> 54 -> rounded to 55
    expect(suggestGoal([60, 60, 60]), 55);
    // average 100 -> 90
    expect(suggestGoal([80, 100, 120]), 90);
  });

  test('days with zero use count towards the average', () {
    // average 20 -> 18 -> rounded to 20
    expect(suggestGoal([60, 0, 0]), 20);
  });

  test('no suggestion for an app that is barely used', () {
    expect(suggestGoal([2, 3, 1]), isNull);
  });

  test('never suggests less than 5 minutes', () {
    expect(suggestGoal([5, 5, 5]), 5);
  });

  test('averageMinutes rounds and handles no data', () {
    expect(averageMinutes([10, 11]), 11);
    expect(averageMinutes([]), 0);
  });
}
