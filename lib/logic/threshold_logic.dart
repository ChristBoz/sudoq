// LOGIC: pure Dart rules. No Flutter, no Android, no storage.
// Decides WHAT should happen; it never shows anything itself.

import '../models/app_event.dart';

/// Decides which event, if any, the current usage should trigger.
///
/// - 100% or more of the goal: [AppEvent.limitReached], once per day.
/// - 80% or more of the goal: [AppEvent.warning80], once per day.
/// - No goal set: always [AppEvent.none].
///
/// The caller is responsible for remembering that an event was shown
/// (the [warned80] / [notified100] flags).
AppEvent checkThreshold({
  required int usedMinutes,
  required int? limitMinutes,
  required bool warned80,
  required bool notified100,
}) {
  if (limitMinutes == null || limitMinutes <= 0) return AppEvent.none;

  if (usedMinutes >= limitMinutes) {
    return notified100 ? AppEvent.none : AppEvent.limitReached;
  }

  // used / limit >= 80%, written with whole numbers to avoid rounding errors.
  if (usedMinutes * 5 >= limitMinutes * 4) {
    return warned80 ? AppEvent.none : AppEvent.warning80;
  }

  return AppEvent.none;
}
