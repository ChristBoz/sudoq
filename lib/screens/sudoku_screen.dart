// SCREENS: UI only. The puzzle rules live in logic/sudoku_game.dart.

import 'package:flutter/material.dart';

import '../logic/sudoku_game.dart';
import '../widgets/sudoku_board.dart';

/// A voluntary Sudoku break, opened from a notice or from Settings.
/// The player can leave at any time (US04).
class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  final _game = SudokuGame.random();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sudoku break')),
      // Scrollable, so nothing is cut off on small screens or large text.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SudokuBoard(game: _game, onChanged: () => setState(() {})),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_game.isComplete ? 'Back to dashboard' : 'Exit'),
            ),
          ],
        ),
      ),
    );
  }
}
