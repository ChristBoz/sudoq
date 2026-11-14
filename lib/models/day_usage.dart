// MODELS: plain data only. No Android calls, no UI, no rules.

/// Usage of the monitored apps on one calendar day, for the 7-day summary.
class DayUsage {
  const DayUsage({required this.day, required this.minutes});

  /// Midnight at the start of the day, local time.
  final DateTime day;

  /// Package name -> minutes. Null when there is no data for this day.
  final Map<String, int>? minutes;

  bool get hasData => minutes != null;
}
