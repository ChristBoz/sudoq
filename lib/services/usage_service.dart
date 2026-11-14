// SERVICES: the only code that talks to the outside world.
// This one talks to Android (through the Kotlin bridge in
// packages/sudoq_usage) and turns raw answers into app models.
// It contains no rules about goals or warnings.

import 'package:sudoq_usage/sudoq_usage.dart';

import '../logic/app_filter.dart';
import '../models/installed_app.dart';
import '../models/usage_result.dart';

/// What the rest of the app needs to know about usage. Tests replace this
/// with a fake, so no phone is needed to test the app's behaviour.
abstract class UsageService {
  /// Whether the user has switched on "Usage access" for suDOq.
  Future<bool> hasAccess();

  /// Opens the Android screen where the user grants usage access.
  Future<void> openAccessSettings();

  /// Apps on the phone that could be monitored, sorted by name.
  Future<List<InstalledApp>> installedApps();

  /// Foreground minutes per app between [start] and [end].
  ///
  /// When Android returns nothing at all, the answer is "no data" rather
  /// than zero minutes. Pass [emptyMeansZero] for periods so short that
  /// "nothing happened yet" is the honest reading.
  Future<UsageResult> usageBetween(
    DateTime start,
    DateTime end, {
    bool emptyMeansZero = false,
  });
}

class AndroidUsageService implements UsageService {
  @override
  Future<bool> hasAccess() async {
    try {
      return await SudoqUsage.hasUsageAccess();
    } catch (_) {
      return false; // not on Android, or the bridge is missing
    }
  }

  @override
  Future<void> openAccessSettings() async {
    try {
      await SudoqUsage.openUsageSettings();
    } catch (_) {
      // Nothing to open on this platform.
    }
  }

  @override
  Future<List<InstalledApp>> installedApps() async {
    try {
      final raw = await SudoqUsage.getInstalledApps();
      final apps = [
        for (final app in raw)
          InstalledApp(
            packageName: app.packageName,
            name: app.name,
            suggested: isSuggestedApp(
              packageName: app.packageName,
              category: app.category,
            ),
          ),
      ];
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return apps;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<UsageResult> usageBetween(
    DateTime start,
    DateTime end, {
    bool emptyMeansZero = false,
  }) async {
    try {
      if (!await SudoqUsage.hasUsageAccess()) {
        return const UsageUnavailable(UsageProblem.noPermission);
      }
      final raw = await SudoqUsage.getUsage(
        startMs: start.millisecondsSinceEpoch,
        endMs: end.millisecondsSinceEpoch,
      );
      if (raw.eventCount == 0 && !emptyMeansZero) {
        return const UsageUnavailable(UsageProblem.noData);
      }
      return UsageData({
        for (final entry in raw.usageMs.entries)
          entry.key: entry.value ~/ Duration.millisecondsPerMinute,
      });
    } catch (_) {
      return const UsageUnavailable(UsageProblem.error);
    }
  }
}
