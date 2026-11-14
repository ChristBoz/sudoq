// LOGIC: pure Dart rules. No Flutter, no Android, no storage.
// Everything about "which day is it" lives here. A day is the phone's
// local calendar day, so it follows time-zone changes automatically.

import '../models/day_flags.dart';

/// "2026-11-14" for any moment on that local day.
String dayKey(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)}';
}

/// Local midnight at the start of [time]'s day.
DateTime startOfDay(DateTime time) => DateTime(time.year, time.month, time.day);

/// Local midnight at the start of the next day.
///
/// Built from the calendar date rather than by adding 24 hours, so days
/// with a clock change (23 or 25 hours long) still end at midnight.
DateTime startOfNextDay(DateTime time) =>
    DateTime(time.year, time.month, time.day + 1);

/// The [count] days before today, oldest first (today is not included).
List<DateTime> previousDays(DateTime now, int count) => [
  for (var back = count; back >= 1; back--)
    DateTime(now.year, now.month, now.day - back),
];

/// Returns [flags] if they belong to today, otherwise fresh empty flags.
/// This is what resets the once-per-day warnings at midnight.
DayFlags flagsForToday(DayFlags? flags, DateTime now) {
  final today = dayKey(now);
  if (flags != null && flags.day == today) return flags;
  return DayFlags(day: today);
}
