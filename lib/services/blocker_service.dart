// SERVICES: the only code that talks to the outside world.
// This one controls the blocker: the Kotlin service that notices when an
// app past its daily goal is opened and brings suDOq's puzzle to the
// front. It decides nothing; it passes the rules along and reports back.

import 'dart:convert';

import 'package:sudoq_usage/sudoq_usage.dart';

/// One app the blocker should stop once its goal is reached.
class BlockRule {
  const BlockRule({required this.limitMinutes, this.extraMinutes = 0});

  /// The daily goal in minutes.
  final int limitMinutes;

  /// Demo-mode simulated minutes, counted on top of measured usage.
  final int extraMinutes;
}

abstract class BlockerService {
  /// Whether "Display over other apps" is granted. Without it Android
  /// does not allow the puzzle to be brought to the front.
  Future<bool> hasOverlayPermission();

  /// Opens the Android screen where that permission is granted.
  Future<void> openOverlaySettings();

  /// Tells the blocker what to watch. [enabled] false stops it.
  /// [rules] maps package name -> rule, for monitored apps with a goal.
  Future<void> configure({
    required bool enabled,
    required int? historyStartMs,
    required Map<String, BlockRule> rules,
  });

  /// The package the blocker just stopped, or null. Asking clears it.
  Future<String?> takePendingGate();

  /// The puzzle was solved: let the app be used until the user leaves it,
  /// and bring it back to the front.
  Future<void> passGate(String packageName);

  /// The puzzle was refused: go to the phone's home screen.
  Future<void> goHome();
}

class AndroidBlockerService implements BlockerService {
  @override
  Future<bool> hasOverlayPermission() async {
    try {
      return await SudoqUsage.hasOverlayPermission();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openOverlaySettings() async {
    try {
      await SudoqUsage.openOverlaySettings();
    } catch (_) {}
  }

  @override
  Future<void> configure({
    required bool enabled,
    required int? historyStartMs,
    required Map<String, BlockRule> rules,
  }) async {
    final json = jsonEncode({
      'enabled': enabled,
      'historyStartMs': historyStartMs ?? 0,
      'apps': {
        for (final entry in rules.entries)
          entry.key: {
            'limit': entry.value.limitMinutes,
            'extra': entry.value.extraMinutes,
          },
      },
    });
    try {
      await SudoqUsage.configureBlocker(json);
    } catch (_) {
      // Not on Android: there is nothing to block.
    }
  }

  @override
  Future<String?> takePendingGate() async {
    try {
      return await SudoqUsage.takePendingGate();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> passGate(String packageName) async {
    try {
      await SudoqUsage.passGate(packageName);
    } catch (_) {}
  }

  @override
  Future<void> goHome() async {
    try {
      await SudoqUsage.goHome();
    } catch (_) {}
  }
}
