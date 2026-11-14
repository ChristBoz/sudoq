// SCREENS: UI only. Reads from state, passes taps to state.

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'app_selection_screen.dart';

/// Step 01: explain the purpose and the usage-access permission (FR01).
///
/// Usage access is optional: the user can continue without it, and the
/// dashboard then says clearly that usage data is unavailable.
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
            final granted = appState.usageAccessGranted;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 32),
                Text('suDOq', style: text.displaySmall),
                const SizedBox(height: 12),
                Text(
                  'See how long you spend on the apps you choose, set your '
                  'own daily goals, and take a short Sudoku break when you '
                  'reach one.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 24),
                Text('Usage access', style: text.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'To show how long each app was open, suDOq needs Android\'s '
                  '"Usage access". It only reads how long apps were in use: '
                  'no messages, no content, no contacts. Everything stays on '
                  'this phone.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap the button, find suDOq in the list, switch it on, '
                  'then come back here.',
                ),
                const SizedBox(height: 32),
                if (granted) ...[
                  const Row(
                    children: [
                      Icon(Icons.check_circle_outline),
                      SizedBox(width: 8),
                      Expanded(child: Text('Usage access granted')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _finish(context),
                    child: const Text('Continue'),
                  ),
                ] else ...[
                  FilledButton(
                    onPressed: appState.openUsageSettings,
                    child: const Text('Grant usage access'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _finish(context),
                    child: const Text('Continue without access'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
