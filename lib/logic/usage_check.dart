// LOGIC: pure Dart rules. No Flutter, no Android, no storage.
// Applies the threshold rule to every monitored app at once. Both the
// open app and the background check use this, so they always agree.

import '../models/app_event.dart';
import '../models/day_flags.dart';
import '../models/tracked_app.dart';
import 'threshold_logic.dart';

/// One warning or notice that should be shown now.
class TriggeredEvent {
  const TriggeredEvent({
    required this.app,
    required this.event,
    required this.usedMinutes,
  });

  final TrackedApp app;
  final AppEvent event;
  final int usedMinutes;
}

/// What a check decided: what to show, and the flags to remember.
class CheckOutcome {
  const CheckOutcome({required this.events, required this.flags});

  final List<TriggeredEvent> events;

  /// Updated copy of the flags, with today's new events recorded.
  final DayFlags flags;
}

/// Checks every monitored app against its goal.
///
/// [minutes] is today's usage per package. [flags] says what was already
/// shown today; the returned flags include whatever is triggered now.
CheckOutcome evaluateUsage({
  required List<TrackedApp> tracked,
  required Map<String, int> minutes,
  required DayFlags flags,
}) {
  final updated = flags.copy();
  final events = <TriggeredEvent>[];

  for (final app in tracked) {
    final used = minutes[app.packageName] ?? 0;
    final event = checkThreshold(
      usedMinutes: used,
      limitMinutes: app.limitMinutes,
      warned80: updated.warned.contains(app.packageName),
      notified100: updated.notified.contains(app.packageName),
    );

    if (event == AppEvent.none) continue;

    updated.warned.add(app.packageName);
    if (event == AppEvent.limitReached) updated.notified.add(app.packageName);
    events.add(TriggeredEvent(app: app, event: event, usedMinutes: used));
  }

  return CheckOutcome(events: events, flags: updated);
}
