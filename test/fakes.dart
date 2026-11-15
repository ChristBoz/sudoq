// Stand-ins for the services, so tests run without a phone.

import 'package:sudoq/models/app_settings.dart';
import 'package:sudoq/models/day_flags.dart';
import 'package:sudoq/models/installed_app.dart';
import 'package:sudoq/models/tracked_app.dart';
import 'package:sudoq/models/usage_result.dart';
import 'package:sudoq/services/background_service.dart';
import 'package:sudoq/services/blocker_service.dart';
import 'package:sudoq/services/notification_service.dart';
import 'package:sudoq/services/storage_service.dart';
import 'package:sudoq/services/usage_service.dart';
import 'package:sudoq/state/app_state.dart';

/// Pretends to be Android. Tests set [access] and [minutes] directly.
class FakeUsageService implements UsageService {
  bool access = true;

  /// What "today" returns. Null = Android returned nothing.
  Map<String, int>? minutes = {};

  /// Day start -> minutes, for past days. Missing days have no data.
  final Map<DateTime, Map<String, int>> pastDays = {};

  List<InstalledApp> installed = const [
    InstalledApp(packageName: 'app.video', name: 'Video', suggested: true),
    InstalledApp(packageName: 'app.social', name: 'Social', suggested: true),
    InstalledApp(packageName: 'app.chat', name: 'Chat', suggested: false),
  ];

  bool settingsOpened = false;
  final List<({DateTime start, DateTime end})> queries = [];

  @override
  Future<bool> hasAccess() async => access;

  @override
  Future<void> openAccessSettings() async => settingsOpened = true;

  @override
  Future<List<InstalledApp>> installedApps() async => installed;

  @override
  Future<UsageResult> usageBetween(
    DateTime start,
    DateTime end, {
    bool emptyMeansZero = false,
  }) async {
    queries.add((start: start, end: end));
    if (!access) return const UsageUnavailable(UsageProblem.noPermission);

    final day = DateTime(start.year, start.month, start.day);
    final today = DateTime(now.year, now.month, now.day);
    final data = day == today ? minutes : pastDays[day];
    if (data == null) {
      return emptyMeansZero
          ? const UsageData({})
          : const UsageUnavailable(UsageProblem.noData);
    }
    return UsageData(data);
  }

  /// The test's idea of "now", so today can be told apart from past days.
  DateTime now = DateTime(2026, 11, 14, 15, 0);
}

/// Keeps everything in memory instead of on disk.
class MemoryStorageService implements StorageService {
  AppSettings settings = AppSettings();
  DayFlags? flags;
  Summaries summaries = {};

  // Saving and loading go through JSON, like the real storage does.
  @override
  Future<AppSettings> loadSettings() async =>
      AppSettings.fromJson(settings.toJson());

  @override
  Future<void> saveSettings(AppSettings value) async =>
      settings = AppSettings.fromJson(value.toJson());

  @override
  Future<DayFlags?> loadFlags() async => flags?.copy();

  @override
  Future<void> saveFlags(DayFlags value) async => flags = value.copy();

  @override
  Future<Summaries> loadSummaries() async => {
    for (final entry in summaries.entries) entry.key: {...entry.value},
  };

  @override
  Future<void> saveSummaries(Summaries value) async => summaries = {
    for (final entry in value.entries) entry.key: {...entry.value},
  };
}

/// Records which notifications would have been shown.
class FakeNotificationService implements NotificationService {
  final List<String> shown = [];
  bool permissionRequested = false;
  NotificationTapHandler? onTap;

  @override
  Future<void> init({NotificationTapHandler? onTap}) async =>
      this.onTap = onTap;

  @override
  Future<bool> requestPermission() async => permissionRequested = true;

  @override
  Future<void> showWarning({
    required TrackedApp app,
    required int usedMinutes,
  }) async => shown.add('warning:${app.packageName}:$usedMinutes');

  @override
  Future<void> showLimitReached({
    required TrackedApp app,
    required int usedMinutes,
  }) async => shown.add('limit:${app.packageName}:$usedMinutes');
}

class FakeBackgroundService implements BackgroundService {
  bool running = false;

  @override
  Future<void> start() async => running = true;

  @override
  Future<void> stop() async => running = false;
}

/// Pretends to be the Kotlin blocker. Tests set [pendingGate] to act as
/// if a blocked app had just been opened.
class FakeBlockerService implements BlockerService {
  bool overlay = true;
  bool overlaySettingsOpened = false;

  /// The last rules the app sent.
  bool enabled = false;
  int? historyStartMs;
  Map<String, BlockRule> rules = {};

  String? pendingGate;
  final List<String> passed = [];
  int wentHome = 0;

  @override
  Future<bool> hasOverlayPermission() async => overlay;

  @override
  Future<void> openOverlaySettings() async => overlaySettingsOpened = true;

  @override
  Future<void> configure({
    required bool enabled,
    required int? historyStartMs,
    required Map<String, BlockRule> rules,
  }) async {
    this.enabled = enabled;
    this.historyStartMs = historyStartMs;
    this.rules = rules;
  }

  @override
  Future<String?> takePendingGate() async {
    final gate = pendingGate;
    pendingGate = null;
    return gate;
  }

  @override
  Future<void> passGate(String packageName) async => passed.add(packageName);

  @override
  Future<void> goHome() async => wentHome++;
}

/// An [AppState] wired to fakes, with a clock the test controls.
class TestApp {
  TestApp({DateTime? now}) : now = now ?? DateTime(2026, 11, 14, 15, 0) {
    usage.now = this.now;
    state = newState();
  }

  DateTime now;
  final usage = FakeUsageService();
  final storage = MemoryStorageService();
  final notifications = FakeNotificationService();
  final background = FakeBackgroundService();
  final blocker = FakeBlockerService();
  late final AppState state;

  /// A fresh AppState on the same storage, as after restarting the app.
  AppState newState() => AppState(
    usage: usage,
    storage: storage,
    notifications: notifications,
    background: background,
    blocker: blocker,
    clock: () => now,
  );

  /// Moves the clock, e.g. past midnight.
  void setNow(DateTime value) {
    now = value;
    usage.now = value;
  }

  /// Finishes onboarding and monitors "app.video" with the given goal.
  Future<TrackedApp> trackVideo({int? limit}) async {
    await state.completeOnboarding();
    await state.setTracked(usage.installed.first, true);
    final app = state.trackedApps.first;
    if (limit != null) await state.setLimit(app, limit);
    return app;
  }
}
