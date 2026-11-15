// SCREENS: UI only. Reads from state, passes taps to state.

import 'package:flutter/material.dart';

import '../logic/sudoku_game.dart';
import '../models/tracked_app.dart';
import '../state/app_state.dart';
import '../widgets/sudoku_board.dart';

/// The gate: shown when an app that reached its daily goal is opened.
///
/// The app can only be used again after this puzzle is solved, and only
/// until the user leaves it; opening it again brings a new puzzle. The
/// other way out is "Leave", which goes to the home screen.
class GateScreen extends StatefulWidget {
  const GateScreen({super.key, required this.app});

  final TrackedApp app;

  @override
  State<GateScreen> createState() => _GateScreenState();
}

class _GateScreenState extends State<GateScreen> {
  final _game = SudokuGame.random();

  Future<void> _continue() async {
    final navigator = Navigator.of(context);
    await appState.passGate(widget.app);
    if (navigator.mounted) navigator.pop();
  }

  Future<void> _leave() async {
    final navigator = Navigator.of(context);
    await appState.leaveGate();
    if (navigator.mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final app = widget.app;
    final limit = app.limitMinutes;
    final solved = _game.isComplete;

    return PopScope(
      // The back button must not skip the puzzle: it leaves the app.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Daily goal reached', style: text.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  limit == null
                      ? '${app.name} is past its daily goal.'
                      : '${app.name} is past its $limit min daily goal.',
                  style: text.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text('Solve this Sudoku to keep using ${app.name}.'),
                const SizedBox(height: 20),
                Center(
                  child: SudokuBoard(
                    game: _game,
                    onChanged: () => setState(() {}),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: solved ? _continue : null,
                  child: Text('Continue to ${app.name}'),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: _leave, child: Text('Leave ${app.name}')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
