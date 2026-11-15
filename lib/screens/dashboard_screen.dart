// SCREENS: UI only. Reads from state, passes taps to state.
// Must not contain rules (logic/) or call services directly.

import 'package:flutter/material.dart';

import '../models/tracked_app.dart';
import '../models/usage_result.dart';
import '../navigation.dart';
import '../state/app_state.dart';
import '../widgets/app_card.dart';
import '../widgets/goal_dialog.dart';
import '../widgets/notice_card.dart';
import 'app_selection_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

/// Step 04: today's usage compared with each goal (FR03, FR04).
/// Pull down to refresh.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _editGoal(BuildContext context, TrackedApp app) async {
    // The suggestion needs the past days; load them the first time.
    if (appState.pastDays == null) await appState.loadPastDays();
    if (!context.mounted) return;

    final package = app.packageName;
    final minutes = await showGoalDialog(
      context,
      appName: app.name,
      currentLimit: app.limitMinutes,
      suggestion: appState.suggestedGoal(package),
      averageMinutes: appState.recentAverage(package),
      observedDays: appState.observedDays(package),
    );
    if (minutes != null) await appState.setLimit(app, minutes);
  }

  Future<void> _simulate(TrackedApp app) async {
    showEvents(await appState.simulateUsage(app, 5));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today'),
        actions: [
          IconButton(
            tooltip: 'Last 7 days',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => _open(context, const HistoryScreen()),
          ),
          IconButton(
            tooltip: 'Select apps',
            icon: const Icon(Icons.apps),
            onPressed: () => _open(context, const AppSelectionScreen()),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => _open(context, const SettingsScreen()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final apps = appState.trackedApps;
          if (apps.isEmpty) {
            return _EmptyState(
              onSelect: () => _open(context, const AppSelectionScreen()),
            );
          }
          return RefreshIndicator(
            onRefresh: refreshAndShowEvents,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ..._notices(),
                for (final app in apps)
                  AppCard(
                    name: app.name,
                    usedMinutes: appState.minutesToday(app.packageName),
                    limitMinutes: app.limitMinutes,
                    simulatedMinutes: appState.simulatedMinutes(
                      app.packageName,
                    ),
                    onEditGoal: () => _editGoal(context, app),
                    onSimulate: appState.demoMode ? () => _simulate(app) : null,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Banners explaining anything unusual about the numbers below.
  List<Widget> _notices() {
    final usage = appState.usage;
    return [
      if (usage is UsageUnavailable)
        switch (usage.reason) {
          UsageProblem.noPermission => NoticeCard(
            title: 'Usage data unavailable',
            body:
                'Usage access is off, so suDOq cannot read how long apps '
                'were open. A dash is shown instead of minutes.',
            actionLabel: 'Grant usage access',
            onAction: appState.openUsageSettings,
          ),
          UsageProblem.noData => const NoticeCard(
            title: 'Usage data unavailable',
            body:
                'Android returned no usage data for today yet. Pull down '
                'to try again.',
          ),
          UsageProblem.error => const NoticeCard(
            title: 'Usage data unavailable',
            body: 'Usage could not be read on this device.',
          ),
        },
      if (appState.blockingEnabled && !appState.overlayGranted)
        NoticeCard(
          title: 'Sudoku cannot appear over apps',
          body:
              '"Display over other apps" is off, so suDOq cannot show the '
              'Sudoku when you open an app that is past its goal.',
          actionLabel: 'Allow display over other apps',
          onAction: appState.openOverlaySettings,
        ),
      if (appState.monitoringPaused)
        const NoticeCard(
          title: 'Monitoring paused',
          body:
              'No warnings, limit notices or Sudoku while paused. '
              'Resume in Settings.',
        ),
      if (appState.demoMode)
        const NoticeCard(
          title: 'Demo mode',
          body:
              'Simulated minutes can be added to test warnings. They are '
              'labelled and are not real usage.',
        ),
    ];
  }
}

/// AC07: nothing selected yet.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSelect});

  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No apps selected yet.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: onSelect, child: const Text('Select apps')),
          ],
        ),
      ),
    );
  }
}
