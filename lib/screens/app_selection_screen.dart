// SCREENS: UI only. Reads from state, passes taps to state.

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'dashboard_screen.dart';

/// Step 02: choose which apps to monitor (FR02).
///
/// Entertainment and social apps are listed by default. Calls, messaging
/// and everything else only appear after switching on "Show all apps".
class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({super.key, this.firstRun = false});

  final bool firstRun;

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    appState.loadInstalledApps();
  }

  void _done() {
    if (widget.firstRun) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select apps')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final installed = appState.installedApps;
          if (installed == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (installed.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'The list of installed apps could not be read on this '
                  'device.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          // Already-monitored apps always stay visible so they can be
          // switched off again.
          final apps = [
            for (final app in installed)
              if (_showAll ||
                  app.suggested ||
                  appState.isTracked(app.packageName))
                app,
          ];

          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Pick the entertainment apps you want to keep an eye on. '
                  'Calls and messaging apps are left out unless you choose '
                  'to show all apps.',
                ),
              ),
              SwitchListTile(
                title: const Text('Show all apps'),
                value: _showAll,
                onChanged: (value) => setState(() => _showAll = value),
              ),
              const Divider(height: 1),
              if (apps.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No entertainment apps were recognised. Switch on '
                    '"Show all apps" to pick from everything installed.',
                  ),
                ),
              for (final app in apps)
                CheckboxListTile(
                  title: Text(app.name),
                  value: appState.isTracked(app.packageName),
                  onChanged: (value) =>
                      appState.setTracked(app, value ?? false),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(onPressed: _done, child: const Text('Done')),
        ),
      ),
    );
  }
}
