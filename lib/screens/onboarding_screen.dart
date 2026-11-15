// SCREENS: UI only. Reads from state, passes taps to state.

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'app_selection_screen.dart';

/// Step 01: explain the purpose and the two permissions (FR01).
///
///  - Usage access: to read how long each app was open.
///  - Display over other apps: to show the Sudoku when an app past its
///    goal is opened.
///
/// Both are optional. Without them the app says clearly what is missing.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  Future<void> _finish(BuildContext context) async {
    await appState.completeOnboarding();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const AppSelectionScreen(firstRun: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: appState,
          builder: (context, _) {
            final allGranted =
                appState.usageAccessGranted && appState.overlayGranted;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 24),
                Text('suDOq', style: text.displaySmall),
                const SizedBox(height: 12),
                Text(
                  'Set your own daily goals for the apps you choose. When '
                  'you open an app that is past its goal, you solve a short '
                  'Sudoku before you can keep using it.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 24),
                _PermissionStep(
                  number: 1,
                  title: 'Usage access',
                  body:
                      'Lets suDOq read how long each app was open. It reads '
                      'no messages, content or contacts, and everything '
                      'stays on this phone.',
                  granted: appState.usageAccessGranted,
                  buttonLabel: 'Grant usage access',
                  onPressed: appState.openUsageSettings,
                ),
                const SizedBox(height: 16),
                _PermissionStep(
                  number: 2,
                  title: 'Display over other apps',
                  body:
                      'Lets suDOq bring the Sudoku to the front when you '
                      'open an app that is past its goal.',
                  granted: appState.overlayGranted,
                  buttonLabel: 'Allow display over other apps',
                  onPressed: appState.openOverlaySettings,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Each button opens Android settings. Find suDOq, switch '
                  'it on, then come back here.',
                ),
                const SizedBox(height: 24),
                if (allGranted)
                  FilledButton(
                    onPressed: () => _finish(context),
                    child: const Text('Continue'),
                  )
                else
                  TextButton(
                    onPressed: () => _finish(context),
                    child: const Text('Continue without these permissions'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PermissionStep extends StatelessWidget {
  const _PermissionStep({
    required this.number,
    required this.title,
    required this.body,
    required this.granted,
    required this.buttonLabel,
    required this.onPressed,
  });

  final int number;
  final String title;
  final String body;
  final bool granted;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$number. $title', style: text.titleMedium),
        const SizedBox(height: 4),
        Text(body),
        const SizedBox(height: 8),
        if (granted)
          Row(
            children: [
              const Icon(Icons.check_circle_outline),
              const SizedBox(width: 8),
              Expanded(child: Text('$title granted')),
            ],
          )
        else
          FilledButton.tonal(onPressed: onPressed, child: Text(buttonLabel)),
      ],
    );
  }
}
