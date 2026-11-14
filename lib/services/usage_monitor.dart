// SERVICES: the one routine that reads usage and applies the rules.
// It connects the usage service, storage and logic/, and is used by both
// the open app (state/) and the background check, so they cannot disagree.
// It shows nothing itself: it returns what should be shown.

import '../logic/day_rollover.dart';
import '../logic/usage_check.dart';
import '../models/app_settings.dart';
import '../models/day_flags.dart';
import '../models/day_usage.dart';
import '../models/usage_result.dart';
import 'storage_service.dart';
import 'usage_service.dart';

/// Everything one check found out.
class MonitorResult {
  const MonitorResult({
    required this.settings,
    required this.hasAccess,
    required this.usage,
    required this.events,
    required this.flags,
  });

  final AppSettings settings;
  final bool hasAccess;

  /// Today's usage, or why there is none.
  final UsageResult usage;

  /// Warnings and notices that should be shown now (already recorded in
  /// [flags], so they will not be reported again today).
  final List<TriggeredEvent> events;

  final DayFlags flags;
}

class UsageMonitor {
  UsageMonitor({required this.usage, required this.storage});

  final UsageService usage;
  final StorageService storage;

  /// How many past days the weekly summary shows besides today.
  static const int pastDayCount = 6;

  /// Reads today's usage and decides which warnings are due.
  ///
  /// [settings] is passed by the open app, which already has them in
  /// memory; the background check leaves it out and they are loaded.
  /// [extraMinutes] is demo-mode simulated usage, added on top.
  Future<MonitorResult> check(
    DateTime now, {
    AppSettings? settings,
    Map<String, int> extraMinutes = const {},
  }) async {
    final current = settings ?? await storage.loadSettings();
    var flags = flagsForToday(await storage.loadFlags(), now);

    final hasAccess = await usage.hasAccess();
    final UsageResult today;
    if (!hasAccess) {
      today = const UsageUnavailable(UsageProblem.noPermission);
    } else {
      final range = _todayRange(now, current.historyStartMs);
      today = await usage.usageBetween(
        range.start,
        now,
        emptyMeansZero: range.shortened,
      );
    }

    var events = const <TriggeredEvent>[];
    final canEvaluate = today is UsageData || extraMinutes.isNotEmpty;
    if (current.onboarded && !current.monitoringPaused && canEvaluate) {
      final outcome = evaluateUsage(
        tracked: current.tracked,
        minutes: _combine(today, extraMinutes),
        flags: flags,
      );
      events = outcome.events;
      flags = outcome.flags;
    }

    await storage.saveFlags(flags);
    return MonitorResult(
      settings: current,
      hasAccess: hasAccess,
      usage: today,
      events: events,
      flags: flags,
    );
  }

  /// Usage of the monitored apps for the days before today, oldest first.
  ///
  /// Past days never change, so each is read from Android once and then
  /// kept in local storage. Days without data come back with no minutes.
  Future<List<DayUsage>> pastDays(DateTime now, AppSettings settings) async {
    final days = previousDays(now, pastDayCount);
    final tracked = {for (final app in settings.tracked) app.packageName};
    final saved = await storage.loadSummaries();
    final hasAccess = await usage.hasAccess();
    final historyStart = settings.historyStartMs;

    final result = <DayUsage>[];
    var changed = false;

    for (final day in days) {
      final key = dayKey(day);
      final end = startOfNextDay(day);

      if (saved.containsKey(key)) {
        result.add(DayUsage(day: day, minutes: saved[key]));
        continue;
      }

      // Deleted history is never read again.
      final deleted =
          historyStart != null && end.millisecondsSinceEpoch <= historyStart;
      if (!hasAccess || deleted) {
        result.add(DayUsage(day: day, minutes: null));
        continue;
      }

      var start = day;
      if (historyStart != null && historyStart > day.millisecondsSinceEpoch) {
        start = DateTime.fromMillisecondsSinceEpoch(historyStart);
      }

      final reading = await usage.usageBetween(start, end);
      if (reading is UsageData) {
        final minutes = {
          for (final package in tracked) package: reading.minutesFor(package),
        };
        saved[key] = minutes;
        changed = true;
        result.add(DayUsage(day: day, minutes: minutes));
      } else {
        result.add(DayUsage(day: day, minutes: null));
      }
    }

    // Keep only the days still shown; older summaries are dropped.
    final keep = {for (final day in days) dayKey(day)};
    final before = saved.length;
    saved.removeWhere((key, _) => !keep.contains(key));
    if (changed || saved.length != before) await storage.saveSummaries(saved);

    return result;
  }

  /// Today starts at local midnight, or at the moment history was deleted
  /// if that was later.
  ({DateTime start, bool shortened}) _todayRange(
    DateTime now,
    int? historyStartMs,
  ) {
    final midnight = startOfDay(now);
    if (historyStartMs != null &&
        historyStartMs > midnight.millisecondsSinceEpoch) {
      return (
        start: DateTime.fromMillisecondsSinceEpoch(historyStartMs),
        shortened: true,
      );
    }
    return (start: midnight, shortened: false);
  }

  Map<String, int> _combine(UsageResult today, Map<String, int> extra) {
    final minutes = <String, int>{if (today is UsageData) ...today.minutes};
    for (final entry in extra.entries) {
      minutes[entry.key] = (minutes[entry.key] ?? 0) + entry.value;
    }
    return minutes;
  }
}
