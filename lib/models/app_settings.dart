// MODELS: plain data only. No Android calls, no UI, no rules.

import 'tracked_app.dart';

/// Everything the user chose, which must survive closing the app.
class AppSettings {
  AppSettings({
    this.onboarded = false,
    this.monitoringPaused = false,
    this.notificationsEnabled = true,
    this.blockingEnabled = true,
    this.historyStartMs,
    List<TrackedApp>? tracked,
  }) : tracked = tracked ?? [];

  /// True once the user finished the first-run screens.
  bool onboarded;

  /// True while the user paused warnings and notices (FR09).
  bool monitoringPaused;

  bool notificationsEnabled;

  /// True when opening an app past its goal requires solving a Sudoku.
  bool blockingEnabled;

  /// Set when the user deletes their history: usage before this moment is
  /// never read again. Milliseconds since 1970, or null if never deleted.
  int? historyStartMs;

  /// The apps the user chose to monitor, with their goals.
  final List<TrackedApp> tracked;

  Map<String, dynamic> toJson() => {
    'onboarded': onboarded,
    'monitoringPaused': monitoringPaused,
    'notificationsEnabled': notificationsEnabled,
    'blockingEnabled': blockingEnabled,
    'historyStartMs': historyStartMs,
    'tracked': [for (final app in tracked) app.toJson()],
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    onboarded: json['onboarded'] as bool? ?? false,
    monitoringPaused: json['monitoringPaused'] as bool? ?? false,
    notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
    blockingEnabled: json['blockingEnabled'] as bool? ?? true,
    historyStartMs: json['historyStartMs'] as int?,
    tracked: [
      for (final app in json['tracked'] as List? ?? const [])
        TrackedApp.fromJson(Map<String, dynamic>.from(app as Map)),
    ],
  );
}
