// MAIN: creates the services and state, starts the app, and refreshes
// usage whenever the app comes back to the front. Nothing else.

import 'package:flutter/material.dart';

import 'navigation.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/usage_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  appState = AppState(
    usage: AndroidUsageService(),
    storage: PrefsStorageService(),
    notifications: LocalNotificationService(),
    background: WorkmanagerBackgroundService(),
  );
  // Only the saved settings are loaded before the first screen, so the
  // app opens quickly. Usage is read right after (see _start below).
  await appState.loadSaved();

  runApp(const SudoqApp());
}

class SudoqApp extends StatefulWidget {
  const SudoqApp({super.key});

  @override
  State<SudoqApp> createState() => _SudoqAppState();
}

class _SudoqAppState extends State<SudoqApp> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Coming back from Android settings or another app: check again.
    _lifecycle = AppLifecycleListener(onResume: refreshAndShowEvents);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    showEvents(await appState.start(onTap: handleNotificationTap));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'suDOq',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: messengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: appState.onboarded
          ? const DashboardScreen()
          : const OnboardingScreen(),
    );
  }
}
