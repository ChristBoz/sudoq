// SCREENS: UI only. Shows what it is given and navigates.

import 'package:flutter/material.dart';

import 'sudoku_screen.dart';

/// Step 05: limit-reached notice with three choices (FR07).
///
/// Nothing here changes the tracked usage or the goal (AC04): the puzzle
/// is an optional break, not a way to earn more time.
class LimitReachedScreen extends StatelessWidget {
  const LimitReachedScreen({
    super.key,
    required this.appName,
    required this.usedMinutes,
    required this.limitMinutes,
  });

  final String appName;
  final int usedMinutes;
  final int limitMinutes;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        // Centred, and scrollable if the text is too large for the screen.
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('You reached your goal', style: text.headlineMedium),
                const SizedBox(height: 12),
                Text(
                  '$appName: $usedMinutes of $limitMinutes min today. '
                  'Try a quick Sudoku break?',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const SudokuScreen()),
                  ),
                  child: const Text('Play Sudoku'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('View usage'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
