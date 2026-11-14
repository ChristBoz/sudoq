// SERVICES: the only code that talks to the outside world.
// This one shows Android notifications and reports taps on them.
// It decides nothing: logic/ decides WHEN, this only shows.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/tracked_app.dart';

/// Where a tap on a notification should take the user.
enum NotificationTarget { limitScreen, sudoku, dashboard }

class NotificationTap {
  const NotificationTap({required this.target, required this.packageName});

  final NotificationTarget target;

  /// The app the notification was about.
  final String packageName;
}

typedef NotificationTapHandler = void Function(NotificationTap tap);

abstract class NotificationService {
  /// Prepares notifications. [onTap] is only given by the open app; the
  /// background check passes nothing.
  Future<void> init({NotificationTapHandler? onTap});

  /// Asks for the Android 13+ notification permission.
  Future<bool> requestPermission();

  /// FR06: usage reached 80% of the goal.
  Future<void> showWarning({required TrackedApp app, required int usedMinutes});

  /// FR07: usage reached the goal. Has "Play Sudoku", "View usage" and
  /// "Dismiss" buttons.
  Future<void> showLimitReached({
    required TrackedApp app,
    required int usedMinutes,
  });
}

/// Needed by the notifications package for buttons pressed while the app
/// is closed. "Dismiss" only removes the notification, so nothing to do.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {}

class LocalNotificationService implements NotificationService {
  static const _channelId = 'sudoq_goals';
  static const _channelName = 'Usage goals';
  static const _channelDescription =
      'Warnings at 80% of a daily goal and notices when a goal is reached';

  static const _sudokuAction = 'sudoku';
  static const _usageAction = 'usage';
  static const _dismissAction = 'dismiss';

  final _plugin = FlutterLocalNotificationsPlugin();
  NotificationTapHandler? _onTap;
  bool _ready = false;

  @override
  Future<void> init({NotificationTapHandler? onTap}) async {
    _onTap = onTap;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: _handle,
        onDidReceiveBackgroundNotificationResponse:
            notificationBackgroundHandler,
      );
      _ready = true;

      // The app may have been started by tapping a notification.
      if (onTap != null) {
        final launch = await _plugin.getNotificationAppLaunchDetails();
        final response = launch?.notificationResponse;
        if (launch?.didNotificationLaunchApp == true && response != null) {
          _handle(response);
        }
      }
    } catch (_) {
      _ready = false; // notifications are unavailable on this platform
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      return await android?.requestNotificationsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showWarning({
    required TrackedApp app,
    required int usedMinutes,
  }) => _show(
    id: _idFor(app.packageName, 1),
    title: '${app.name}: 80% of your goal',
    body: '$usedMinutes of ${app.limitMinutes} min used today.',
    payload: 'warn|${app.packageName}',
  );

  @override
  Future<void> showLimitReached({
    required TrackedApp app,
    required int usedMinutes,
  }) => _show(
    id: _idFor(app.packageName, 2),
    title: 'You reached your ${app.name} goal',
    body:
        '$usedMinutes of ${app.limitMinutes} min today. '
        'Try a quick Sudoku break?',
    payload: 'limit|${app.packageName}',
    actions: const [
      AndroidNotificationAction(
        _sudokuAction,
        'Play Sudoku',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(
        _usageAction,
        'View usage',
        showsUserInterface: true,
      ),
      AndroidNotificationAction(_dismissAction, 'Dismiss'),
    ],
  );

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String payload,
    List<AndroidNotificationAction>? actions,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
            actions: actions,
          ),
        ),
      );
    } catch (_) {
      // Permission denied or notifications blocked: nothing to show.
    }
  }

  /// Turns a tap into "where should the app go".
  void _handle(NotificationResponse response) {
    final onTap = _onTap;
    final parts = (response.payload ?? '').split('|');
    if (onTap == null || parts.length != 2) return;
    final kind = parts[0];
    final packageName = parts[1];

    final NotificationTarget target;
    switch (response.actionId) {
      case _dismissAction:
        return;
      case _sudokuAction:
        target = NotificationTarget.sudoku;
      case _usageAction:
        target = NotificationTarget.dashboard;
      default:
        // The notification itself was tapped, not a button.
        target = kind == 'limit'
            ? NotificationTarget.limitScreen
            : NotificationTarget.dashboard;
    }
    onTap(NotificationTap(target: target, packageName: packageName));
  }

  /// A stable number per app and kind, so a newer notification about the
  /// same app replaces the older one instead of piling up.
  int _idFor(String packageName, int kind) {
    var hash = 0;
    for (final unit in packageName.codeUnits) {
      hash = (hash * 31 + unit) & 0x0FFFFFFF;
    }
    return hash * 4 + kind;
  }
}
