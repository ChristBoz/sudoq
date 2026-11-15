// NAVIGATION: moving between screens in response to events that do not
// come from a button on the current screen: a warning becoming due, or a
// tap on a notification.

import 'package:flutter/material.dart';

import 'logic/usage_check.dart';
import 'models/app_event.dart';
import 'models/tracked_app.dart';
import 'screens/gate_screen.dart';
import 'screens/limit_reached_screen.dart';
import 'screens/sudoku_screen.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

/// Lets code outside a screen open screens and show messages.
final navigatorKey = GlobalKey<NavigatorState>();
final messengerKey = GlobalKey<ScaffoldMessengerState>();

/// Shows warnings and limit notices inside the app.
///
/// 80% warning: a short message at the bottom (FR06).
/// Limit reached: the full notice with its three choices (FR07).
void showEvents(List<TriggeredEvent> events) {
  for (final triggered in events) {
    final app = triggered.app;
    if (triggered.event == AppEvent.limitReached) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => LimitReachedScreen(
            appName: app.name,
            usedMinutes: triggered.usedMinutes,
            limitMinutes: app.limitMinutes ?? triggered.usedMinutes,
          ),
        ),
      );
    } else if (triggered.event == AppEvent.warning80) {
      messengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(
            '${app.name}: ${triggered.usedMinutes} of ${app.limitMinutes} '
            'min used, 80% of your daily goal.',
          ),
        ),
      );
    }
  }
}

/// Re-reads usage and shows whatever became due.
///
/// Runs every time suDOq comes to the front. If the blocker brought it
/// to the front because a blocked app was opened, the puzzle gate is
/// shown and takes priority over ordinary notices.
Future<void> refreshAndShowEvents() async {
  final blockedApp = await appState.takePendingGate();
  final events = await appState.refresh();

  if (blockedApp != null) {
    showGate(blockedApp);
  } else {
    showEvents(events);
  }
}

/// Opens the puzzle that must be solved before [app] can be used again.
void showGate(TrackedApp app) {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  // Only one gate at a time: close anything left open from before.
  navigator.popUntil((route) => route.isFirst);
  navigator.push(MaterialPageRoute(builder: (_) => GateScreen(app: app)));
}

/// Opens the right screen after a tap on a notification or its buttons.
void handleNotificationTap(NotificationTap tap) {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;

  switch (tap.target) {
    case NotificationTarget.sudoku:
      navigator.push(MaterialPageRoute(builder: (_) => const SudokuScreen()));

    case NotificationTarget.dashboard:
      navigator.popUntil((route) => route.isFirst);

    case NotificationTarget.limitScreen:
      final app = appState.trackedApp(tap.packageName);
      final limit = app?.limitMinutes;
      if (app == null || limit == null) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => LimitReachedScreen(
            appName: app.name,
            usedMinutes: appState.minutesToday(app.packageName) ?? limit,
            limitMinutes: limit,
          ),
        ),
      );
  }
}
