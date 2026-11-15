// DART SIDE OF THE KOTLIN BRIDGE.
// One method per Kotlin method, returning raw values. No app rules here:
// the app's services/usage_service.dart turns these into app models.

import 'package:flutter/services.dart';

/// One installed app, as reported by Android.
class RawInstalledApp {
  const RawInstalledApp({
    required this.packageName,
    required this.name,
    required this.category,
  });

  final String packageName;
  final String name;

  /// Android's ApplicationInfo.category: 0 game, 1 audio, 2 video, 3 image,
  /// 4 social, 5 news, 6 maps, 7 productivity, -1 not declared.
  final int category;
}

/// Raw foreground time between two moments.
class RawUsage {
  const RawUsage({required this.eventCount, required this.usageMs});

  /// How many usage events Android returned. 0 = Android had no data.
  final int eventCount;

  /// Package name -> milliseconds in the foreground.
  final Map<String, int> usageMs;
}

class SudoqUsage {
  static const _channel = MethodChannel('sudoq_usage');

  /// Whether "Usage access" is switched on for this app.
  static Future<bool> hasUsageAccess() async =>
      await _channel.invokeMethod<bool>('hasUsageAccess') ?? false;

  /// Opens the Android settings screen where the user grants usage access.
  static Future<void> openUsageSettings() =>
      _channel.invokeMethod<void>('openUsageSettings');

  /// Apps with a launcher icon, excluding this app.
  static Future<List<RawInstalledApp>> getInstalledApps() async {
    final raw = await _channel.invokeListMethod<Map>('getInstalledApps') ?? [];
    return [
      for (final app in raw)
        RawInstalledApp(
          packageName: app['package'] as String,
          name: app['name'] as String,
          category: (app['category'] as int?) ?? -1,
        ),
    ];
  }

  /// Foreground time per app between [startMs] and [endMs]
  /// (milliseconds since 1970).
  static Future<RawUsage> getUsage({
    required int startMs,
    required int endMs,
  }) async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('getUsage', {
      'start': startMs,
      'end': endMs,
    });
    final usage = (raw?['usageMs'] as Map?) ?? const {};
    return RawUsage(
      eventCount: (raw?['eventCount'] as int?) ?? 0,
      usageMs: {
        for (final entry in usage.entries)
          entry.key as String: (entry.value as num).toInt(),
      },
    );
  }

  // ---- Blocker -------------------------------------------------------------

  /// Whether "Display over other apps" is switched on for this app. The
  /// blocker needs it to bring the puzzle to the front.
  static Future<bool> hasOverlayPermission() async =>
      await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;

  /// Opens the Android screen where "Display over other apps" is granted.
  static Future<void> openOverlaySettings() =>
      _channel.invokeMethod<void>('openOverlaySettings');

  /// Saves the blocker's rules (see BlockerConfig.kt for the JSON shape)
  /// and starts or stops the background service to match.
  static Future<void> configureBlocker(String json) =>
      _channel.invokeMethod<void>('configureBlocker', {'json': json});

  /// The package the blocker just stopped, or null. Reading it clears it.
  static Future<String?> takePendingGate() =>
      _channel.invokeMethod<String>('takePendingGate');

  /// The puzzle for [packageName] was solved: allow the app until the user
  /// leaves it, and bring it back to the front.
  static Future<void> passGate(String packageName) =>
      _channel.invokeMethod<void>('passGate', {'package': packageName});

  /// Sends the user to the phone's home screen.
  static Future<void> goHome() => _channel.invokeMethod<void>('goHome');
}
