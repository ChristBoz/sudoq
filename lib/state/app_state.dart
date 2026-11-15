// STATE: the single place the screens read from and write to.
// It holds what is currently true, asks the services to load and save,
// and tells the UI to redraw. Rules live in logic/, Android in services/.

import 'package:flutter/foundation.dart';

import '../logic/day_rollover.dart';
import '../logic/goal_suggestion.dart';
import '../logic/usage_check.dart';
import '../models/app_settings.dart';
import '../models/day_flags.dart';
import '../models/day_usage.dart';
import '../models/installed_app.dart';
import '../models/tracked_app.dart';
import '../models/usage_result.dart';
import '../services/background_service.dart';
import '../services/blocker_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/usage_monitor.dart';
import '../services/usage_service.dart';

class AppState extends ChangeNotifier {
  AppState({
    required UsageService usage,
    required StorageService storage,
    required this._notifications,
    required this._background,
    required this._blocker,
    DateTime Function()? clock,
  }) : _usage = usage,
       _storage = storage,
       _clock = clock ?? DateTime.now,
       _monitor = UsageMonitor(usage: usage, storage: storage);

  final UsageService _usage;
  final StorageService _storage;
  final NotificationService _notifications;
  final BackgroundService _background;
  final BlockerService _blocker;
  final DateTime Function() _clock;
  final UsageMonitor _monitor;

  AppSettings _settings = AppSettings();
  DayFlags? _flags;
  Future<List<TriggeredEvent>>? _refreshing;

  // ---- What the screens read ---------------------------------------------

  bool get onboarded => _settings.onboarded;
  bool get monitoringPaused => _settings.monitoringPaused;
  bool get notificationsEnabled => _settings.notificationsEnabled;

  /// Whether opening an app past its goal requires solving a Sudoku.
  bool get blockingEnabled => _settings.blockingEnabled;

  /// The apps the user chose to monitor.
  List<TrackedApp> get trackedApps => List.unmodifiable(_settings.tracked);

  /// Whether "Usage access" is switched on in Android settings.
  bool usageAccessGranted = false;

  /// Whether "Display over other apps" is switched on. The blocker cannot
  /// bring the puzzle to the front without it.
  bool overlayGranted = false;

  /// Today's usage, or the reason there is none.
  UsageResult usage = const UsageUnavailable(UsageProblem.noPermission);

  /// Apps on the phone. Null until loaded for the "Select apps" screen.
  List<InstalledApp>? installedApps;

  /// The six days before today. Null until loaded.
  List<DayUsage>? pastDays;

  /// Demo mode lets a presenter add clearly labelled simulated minutes.
  /// It is never saved and is off after every restart.
  bool demoMode = false;
  final Map<String, int> _simulated = {};

  bool isTracked(String packageName) =>
      _settings.tracked.any((app) => app.packageName == packageName);

  TrackedApp? trackedApp(String packageName) {
    for (final app in _settings.tracked) {
      if (app.packageName == packageName) return app;
    }
    return null;
  }

  int simulatedMinutes(String packageName) => _simulated[packageName] ?? 0;

  /// Minutes to show for an app today, or null when there is no reading
  /// (AC06: missing data is never shown as 0 minutes).
  int? minutesToday(String packageName) {
    final simulated = simulatedMinutes(packageName);
    final reading = usage;
    if (reading is UsageData) {
      return reading.minutesFor(packageName) + simulated;
    }
    return simulated > 0 ? simulated : null;
  }

  /// A goal to offer in the goal editor, or null if there is not enough
  /// history yet (FR05).
  int? suggestedGoal(String packageName) =>
      suggestGoal(_pastMinutes(packageName));

  /// The recent daily average behind [suggestedGoal].
  int recentAverage(String packageName) =>
      averageMinutes(_pastMinutes(packageName));

  int observedDays(String packageName) => _pastMinutes(packageName).length;

  List<int> _pastMinutes(String packageName) => [
    for (final day in pastDays ?? const <DayUsage>[])
      if (day.minutes != null) day.minutes![packageName] ?? 0,
  ];

  // ---- Starting up -------------------------------------------------------

  /// Loads what was saved. Fast, so it runs before the first screen.
  Future<void> loadSaved() async {
    _settings = await _storage.loadSettings();
    notifyListeners();
  }

  /// Starts notifications and the background check, then reads usage.
  /// Returns warnings that became due while the app was closed.
  Future<List<TriggeredEvent>> start({NotificationTapHandler? onTap}) async {
    await _notifications.init(onTap: onTap);
    await _syncBackground();
    await _syncBlocker();
    return refresh();
  }

  // ---- Blocker -----------------------------------------------------------

  /// The app the blocker just stopped, if any. The puzzle must be shown
  /// for it. Asking clears it, so it is reported only once.
  Future<TrackedApp?> takePendingGate() async {
    final packageName = await _blocker.takePendingGate();
    if (packageName == null) return null;
    return trackedApp(packageName) ??
        TrackedApp(packageName: packageName, name: 'This app');
  }

  /// The puzzle was solved: the app can be used until the user leaves it.
  Future<void> passGate(TrackedApp app) => _blocker.passGate(app.packageName);

  /// The user chose not to solve the puzzle: back to the home screen.
  Future<void> leaveGate() => _blocker.goHome();

  Future<void> openOverlaySettings() => _blocker.openOverlaySettings();

  Future<void> setBlockingEnabled(bool value) async {
    _settings.blockingEnabled = value;
    await _save();
  }

  /// Sends the current goals to the blocker and switches it on or off.
  Future<void> _syncBlocker() => _blocker.configure(
    enabled:
        _settings.onboarded &&
        _settings.blockingEnabled &&
        !_settings.monitoringPaused,
    historyStartMs: _settings.historyStartMs,
    rules: {
      for (final app in _settings.tracked)
        if (app.limitMinutes != null)
          app.packageName: BlockRule(
            limitMinutes: app.limitMinutes!,
            extraMinutes: simulatedMinutes(app.packageName),
          ),
    },
  );

  // ---- Usage -------------------------------------------------------------

  /// Re-reads permission and today's usage, and applies the goal rules.
  ///
  /// Returns the warnings and notices to show now. Each is returned only
  /// once per app per day.
  Future<List<TriggeredEvent>> refresh() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<List<TriggeredEvent>> _doRefresh() async {
    final result = await _monitor.check(
      _clock(),
      settings: _settings,
      extraMinutes: _simulated,
    );
    usageAccessGranted = result.hasAccess;
    usage = result.usage;
    _flags = result.flags;
    overlayGranted = await _blocker.hasOverlayPermission();
    notifyListeners();
    return _settings.notificationsEnabled ? result.events : const [];
  }

  /// Loads the six days before today for the weekly summary.
  Future<void> loadPastDays() async {
    pastDays = await _monitor.pastDays(_clock(), _settings);
    notifyListeners();
  }

  Future<void> openUsageSettings() => _usage.openAccessSettings();

  // ---- Onboarding and settings -------------------------------------------

  Future<void> completeOnboarding() async {
    _settings.onboarded = true;
    await _save();
    await _notifications.requestPermission();
    await _syncBackground();
  }

  Future<void> setMonitoringPaused(bool value) async {
    _settings.monitoringPaused = value;
    await _save();
    await _syncBackground();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _settings.notificationsEnabled = value;
    await _save();
    if (value) await _notifications.requestPermission();
  }

  void setDemoMode(bool value) {
    demoMode = value;
    if (!value) _simulated.clear();
    notifyListeners();
    _syncBlocker();
  }

  // ---- Apps and goals ----------------------------------------------------

  Future<void> loadInstalledApps() async {
    installedApps = await _usage.installedApps();
    notifyListeners();
  }

  /// Starts or stops monitoring an app (FR02).
  Future<void> setTracked(InstalledApp app, bool tracked) async {
    if (tracked && !isTracked(app.packageName)) {
      _settings.tracked.add(
        TrackedApp(packageName: app.packageName, name: app.name),
      );
    } else if (!tracked) {
      _settings.tracked.removeWhere((t) => t.packageName == app.packageName);
      _simulated.remove(app.packageName);
    }
    // Stored summaries only cover the monitored apps, so rebuild them.
    pastDays = null;
    await _storage.saveSummaries({});
    await _save();
  }

  /// Saves a new daily goal (FR04). The caller validates the number.
  Future<void> setLimit(TrackedApp app, int minutes) async {
    app.limitMinutes = minutes;

    // A new goal starts fresh: its warnings may be shown again today.
    final flags = flagsForToday(_flags, _clock()).copy()
      ..warned.remove(app.packageName)
      ..notified.remove(app.packageName);
    _flags = flags;
    await _storage.saveFlags(flags);
    await _save();
  }

  /// Demo mode only: adds simulated minutes and returns what to show.
  Future<List<TriggeredEvent>> simulateUsage(TrackedApp app, int minutes) {
    _simulated[app.packageName] = simulatedMinutes(app.packageName) + minutes;
    _syncBlocker(); // the blocker counts simulated minutes too
    // If a check is already running, wait for it so the new minutes count.
    final running = _refreshing;
    if (running != null) return running.then((_) => refresh());
    return refresh();
  }

  /// FR09: deletes the usage suDOq holds and stops it from reading any
  /// usage from before this moment.
  Future<void> clearUsageHistory() async {
    final now = _clock();
    _settings.historyStartMs = now.millisecondsSinceEpoch;
    _simulated.clear();
    pastDays = null;
    _flags = DayFlags(day: dayKey(now));
    await _storage.saveSummaries({});
    await _storage.saveFlags(_flags!);
    await _save();
    await refresh();
  }

  // ---- Helpers -----------------------------------------------------------

  /// Every change to the settings goes through here, so the saved copy
  /// and the blocker's rules never fall behind.
  Future<void> _save() async {
    notifyListeners();
    await _storage.saveSettings(_settings);
    await _syncBlocker();
  }

  /// The background check runs only after onboarding and while not paused.
  Future<void> _syncBackground() async {
    if (_settings.onboarded && !_settings.monitoringPaused) {
      await _background.start();
    } else {
      await _background.stop();
    }
  }
}

/// The one shared instance the screens use. Created in main().
late AppState appState;
