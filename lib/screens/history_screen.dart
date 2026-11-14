// SCREENS: UI only. Reads from state, passes taps to state.

import 'package:flutter/material.dart';

import '../models/day_usage.dart';
import '../models/tracked_app.dart';
import '../state/app_state.dart';

/// Seven-day summary for each monitored app (FR03, US05).
///
/// Days without data show a dash, never 0 minutes.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    appState.loadPastDays();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Last 7 days')),
      body: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final past = appState.pastDays;
          final apps = appState.trackedApps;
          if (past == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (apps.isEmpty) {
            return const Center(child: Text('No apps selected yet.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Minutes per day for each app you monitor. A dash means '
                'there is no data for that day.',
              ),
              const SizedBox(height: 8),
              for (final app in apps) _AppWeek(app: app, past: past),
            ],
          );
        },
      ),
    );
  }
}

class _AppWeek extends StatelessWidget {
  const _AppWeek({required this.app, required this.past});

  final TrackedApp app;
  final List<DayUsage> past;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final limit = app.limitMinutes;

    // Oldest day first, today last.
    final rows = <({String label, int? minutes})>[
      for (final day in past)
        (
          label: '${_weekdays[day.day.weekday - 1]} ${day.day.day}',
          minutes: day.minutes?[app.packageName],
        ),
      (label: 'Today', minutes: appState.minutesToday(app.packageName)),
    ];

    final known = [
      for (final row in rows)
        if (row.minutes != null) row.minutes!,
    ];
    final total = known.fold<int>(0, (sum, m) => sum + m);
    final longest = known.fold<int>(limit ?? 1, (a, b) => a > b ? a : b);
    final overGoal = limit == null
        ? 0
        : known.where((minutes) => minutes >= limit).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(app.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              known.isEmpty
                  ? 'No data for these days'
                  : 'Total $total min · average '
                        '${(total / known.length).round()} min a day'
                        '${limit == null ? '' : ' · goal $limit min'}',
            ),
            if (limit != null && known.isNotEmpty)
              Text('Goal reached on $overGoal of ${known.length} days'),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(row.label)),
                    Expanded(
                      flex: 5,
                      child: ExcludeSemantics(
                        child: LinearProgressIndicator(
                          value: row.minutes == null
                              ? 0
                              : (row.minutes! / longest).clamp(0.0, 1.0),
                          minHeight: 6,
                          color:
                              limit != null &&
                                  row.minutes != null &&
                                  row.minutes! >= limit
                              ? theme.colorScheme.error
                              : null,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        row.minutes == null ? '—' : '${row.minutes} min',
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
