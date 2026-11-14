// LOGIC: pure Dart rules. No Flutter, no Android, no storage.

/// How many days of data are needed before a goal is suggested (FR05).
const int observationDays = 3;

/// Suggests a daily goal from the minutes used on recent days.
///
/// The suggestion is slightly below the recent average (10% less), rounded
/// to 5 minutes. It is only a starting point the user can change, not a
/// health recommendation.
///
/// Returns null when there are fewer than [observationDays] days of data,
/// or when the app is barely used.
int? suggestGoal(List<int> pastDailyMinutes) {
  if (pastDailyMinutes.length < observationDays) return null;

  final total = pastDailyMinutes.fold<int>(0, (sum, m) => sum + m);
  final average = total / pastDailyMinutes.length;
  if (average < 5) return null;

  final rounded = ((average * 0.9) / 5).round() * 5;
  return rounded < 5 ? 5 : rounded;
}

/// The average the suggestion is based on, for explaining it to the user.
int averageMinutes(List<int> pastDailyMinutes) {
  if (pastDailyMinutes.isEmpty) return 0;
  final total = pastDailyMinutes.fold<int>(0, (sum, m) => sum + m);
  return (total / pastDailyMinutes.length).round();
}
