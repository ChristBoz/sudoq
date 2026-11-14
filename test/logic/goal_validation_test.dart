import 'package:flutter_test/flutter_test.dart';
import 'package:sudoq/logic/goal_validation.dart';

void main() {
  test('AC05: rejects 0, negatives, text and empty input', () {
    expect(validateLimit('0'), isNotNull);
    expect(validateLimit('-5'), isNotNull);
    expect(validateLimit('abc'), isNotNull);
    expect(validateLimit('4.5'), isNotNull);
    expect(validateLimit(''), isNotNull);
    expect(validateLimit(null), isNotNull);
  });

  test('accepts a positive whole number, with stray spaces', () {
    expect(validateLimit('45'), isNull);
    expect(validateLimit(' 45 '), isNull);
  });
}
