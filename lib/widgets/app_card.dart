// WIDGETS: small reusable UI pieces. They only display what they are given
// and report taps through callbacks. They never touch state or services.

import 'package:flutter/material.dart';

/// One monitored app on the dashboard: usage, goal, progress bar, actions.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.name,
    required this.usedMinutes,
    required this.limitMinutes,
    required this.onEditGoal,
    this.simulatedMinutes = 0,
    this.onSimulate,
  });

  final String name;

  /// Minutes today, or null when there is no reading. Null is shown as a
  /// dash, never as 0 (AC06).
  final int? usedMinutes;

  /// The daily goal, or null when none is set.
  final int? limitMinutes;

  /// How many of [usedMinutes] are simulated (demo mode).
  final int simulatedMinutes;

  final VoidCallback onEditGoal;

  /// Shown only in demo mode. Null hides the button.
  final VoidCallback? onSimulate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final used = usedMinutes;
    final limit = limitMinutes;
    final usedText = used == null ? '—' : '$used';
    final reached = used != null && limit != null && used >= limit;
    final progress = (used == null || limit == null || limit <= 0)
        ? 0.0
        : (used / limit).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              limit == null
                  ? '$usedText min today · no goal set'
                  : '$usedText / $limit min today',
            ),
            // Said in words as well as shown by the bar (NFR05).
            if (reached)
              Text(
                'Daily goal reached',
                style: TextStyle(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (simulatedMinutes > 0)
              Text(
                'Includes $simulatedMinutes simulated min (demo mode)',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            const SizedBox(height: 8),
            if (limit != null)
              Semantics(
                label: used == null
                    ? 'No usage reading'
                    : '${(progress * 100).round()} percent of daily goal used',
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  color: reached ? theme.colorScheme.error : null,
                ),
              ),
            const SizedBox(height: 8),
            // Wrap, so the buttons move to a new line with large text.
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: onEditGoal,
                  child: Text(limit == null ? 'Set goal' : 'Edit goal'),
                ),
                if (onSimulate != null)
                  TextButton(
                    onPressed: onSimulate,
                    child: const Text('+5 min (simulated)'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
