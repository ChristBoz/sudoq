// SCREENS: UI only. Reads from state, passes taps to state.

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'sudoku_screen.dart';

/// Pause monitoring, notifications, delete history (FR09).
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete usage history?'),
        content: const Text(
          'suDOq will delete the usage summaries it keeps and will no '
          'longer show any usage from before now. Your goals and selected '
          'apps are kept. Android\'s own records are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await appState.clearUsageHistory();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Usage history deleted.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => ListView(
          children: [
            ListTile(
              leading: Icon(
                appState.usageAccessGranted
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
              ),
              title: const Text('Usage access'),
              subtitle: Text(
                appState.usageAccessGranted
                    ? 'Granted. Tap to change it in Android settings.'
                    : 'Not granted. Tap to open Android settings.',
              ),
              onTap: appState.openUsageSettings,
            ),
            ListTile(
              leading: Icon(
                appState.overlayGranted
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
              ),
              title: const Text('Display over other apps'),
              subtitle: Text(
                appState.overlayGranted
                    ? 'Granted. Tap to change it in Android settings.'
                    : 'Not granted. The Sudoku cannot appear over a '
                          'blocked app. Tap to open Android settings.',
              ),
              onTap: appState.openOverlaySettings,
            ),
            SwitchListTile(
              title: const Text('Require Sudoku past the goal'),
              subtitle: const Text(
                'Opening an app that reached its daily goal shows a '
                'Sudoku to solve first, every time',
              ),
              value: appState.blockingEnabled,
              onChanged: appState.setBlockingEnabled,
            ),
            SwitchListTile(
              title: const Text('Pause monitoring'),
              subtitle: const Text('No warnings, notices or Sudoku while on'),
              value: appState.monitoringPaused,
              onChanged: appState.setMonitoringPaused,
            ),
            SwitchListTile(
              title: const Text('Notifications'),
              subtitle: const Text('80% warning and limit-reached notice'),
              value: appState.notificationsEnabled,
              onChanged: appState.setNotificationsEnabled,
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete usage history'),
              subtitle: const Text('Removes the usage suDOq keeps'),
              onTap: () => _confirmDelete(context),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Demo mode'),
              subtitle: const Text(
                'Adds a button for simulated minutes, to test warnings. '
                'Turns off when the app restarts.',
              ),
              value: appState.demoMode,
              onChanged: appState.setDemoMode,
            ),
            ListTile(
              leading: const Icon(Icons.grid_4x4),
              title: const Text('Play Sudoku'),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SudokuScreen())),
            ),
          ],
        ),
      ),
    );
  }
}
