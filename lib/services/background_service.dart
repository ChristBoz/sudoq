// SERVICES: the only code that talks to the outside world.
// This one asks Android to run a usage check from time to time while the
// app is closed, and contains the code that runs then.
//
// Android decides the exact timing: checks happen roughly every 15
// minutes at best, and can be delayed by battery saving. A notice can
// therefore arrive some minutes after a goal is reached.

import 'dart:ui';

import 'package:workmanager/workmanager.dart';

import '../models/app_event.dart';
import 'notification_service.dart';
import 'storage_service.dart';
import 'usage_monitor.dart';
import 'usage_service.dart';

abstract class BackgroundService {
  /// Starts the periodic background check (does nothing if already on).
  Future<void> start();

  /// Stops it, for when monitoring is paused.
  Future<void> stop();
}

class WorkmanagerBackgroundService implements BackgroundService {
  static const _uniqueName = 'sudoq-usage-check';
  static const _taskName = 'usageCheck';

  @override
  Future<void> start() async {
    try {
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        _taskName,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
    } catch (_) {
      // Background work is unavailable; the app still checks when opened.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await Workmanager().cancelByUniqueName(_uniqueName);
    } catch (_) {}
  }
}

/// Android starts this function, with no screen, when a check is due.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      DartPluginRegistrant.ensureInitialized();
      await runBackgroundCheck(
        usage: AndroidUsageService(),
        storage: PrefsStorageService(),
        notifications: LocalNotificationService(),
        now: DateTime.now(),
      );
    } catch (_) {
      // A failed check is simply retried at the next interval.
    }
    return true;
  });
}

/// One background check: read usage, apply the rules, notify.
Future<void> runBackgroundCheck({
  required UsageService usage,
  required StorageService storage,
  required NotificationService notifications,
  required DateTime now,
}) async {
  final monitor = UsageMonitor(usage: usage, storage: storage);
  final result = await monitor.check(now);

  if (result.events.isEmpty || !result.settings.notificationsEnabled) return;

  await notifications.init();
  for (final triggered in result.events) {
    if (triggered.event == AppEvent.limitReached) {
      await notifications.showLimitReached(
        app: triggered.app,
        usedMinutes: triggered.usedMinutes,
      );
    } else {
      await notifications.showWarning(
        app: triggered.app,
        usedMinutes: triggered.usedMinutes,
      );
    }
  }
}
