// SCREENS: UI only. The puzzle rules live in logic/sudoku_game.dart.

import 'package:flutter/material.dart';

import '../logic/sudoku_game.dart';

/// Step 06: offline 4 x 4 Sudoku (FR08). Completing it changes nothing
/// about tracked usage or goals (AC04).
class SudokuScreen extends StatefulWidget {
  const SudokuScreen({super.key});

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  final _game = SudokuGame();
  int? _row;
  int? _col;
  String? _message;

  void _select(int row, int col) {
    setState(() {
      _row = row;
      _col = col;
      _message = _game.isClue(row, col) ? 'Clues cannot be changed.' : null;
    });
  }

  void _enter(int value) {
    final row = _row, col = _col;
    if (row == null || col == null) return;
    setState(() {
      if (!_game.setCell(row, col, value)) {
        _message = 'Clues cannot be changed.';
      } else if (_game.hasConflict(row, col)) {
        _message = 'Each row, column and 2 × 2 box can hold a digit only once.';
      } else {
        _message = null;
      }
    });
  }

  void _reset() {
    setState(() {
      _game.reset();
      _row = _col = null;
      _message = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final done = _game.isComplete;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku break'),
        actions: [
          IconButton(
            tooltip: 'Restart',
            icon: const Icon(Icons.refresh),
            onPressed: _reset,
          ),
        ],
      ),
      // Scrollable, so nothing is cut off on small screens or large text.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text('Fill 1–4 once in every row, column and 2 × 2 box.'),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: AspectRatio(aspectRatio: 1, child: _grid(context)),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Text(
                done ? 'Nicely done — puzzle complete!' : (_message ?? ''),
                textAlign: TextAlign.center,
              ),
            ),
            if (!done)
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (var n = 1; n <= SudokuGame.size; n++)
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: FilledButton.tonal(
                        onPressed: () => _enter(n),
                        child: Text('$n'),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Clear cell',
                    icon: const Icon(Icons.backspace_outlined),
                    onPressed: () => _enter(0),
                  ),
                ],
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(done ? 'Back to dashboard' : 'Exit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var r = 0; r < SudokuGame.size; r++)
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < SudokuGame.size; c++)
                  Expanded(child: _cell(r, c, scheme)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(int r, int c, ColorScheme scheme) {
    final value = _game.cells[r][c];
    final clue = _game.isClue(r, c);
    final conflict = _game.hasConflict(r, c);
    final selected = r == _row && c == _col;
    BorderSide side(bool thick) =>
        BorderSide(color: scheme.outline, width: thick ? 3 : 1);
    return Semantics(
      label:
          'Row ${r + 1}, column ${c + 1}, '
          '${value == 0 ? 'empty' : value}'
          '${clue ? ', clue' : ''}${conflict ? ', conflict' : ''}',
      button: true,
      child: InkWell(
        onTap: () => _select(r, c),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : clue
                ? scheme.surfaceContainerHighest
                : null,
            border: Border(
              top: side(r % 2 == 0),
              left: side(c % 2 == 0),
              bottom: side(r == SudokuGame.size - 1),
              right: side(c == SudokuGame.size - 1),
            ),
          ),
          // Conflicts are marked with "!" as well as colour (NFR05).
          child: Text(
            value == 0 ? '' : (conflict && !clue ? '$value!' : '$value'),
            style: TextStyle(
              fontSize: 28,
              fontWeight: clue ? FontWeight.bold : FontWeight.normal,
              color: conflict && !clue ? scheme.error : null,
            ),
          ),
        ),
      ),
    );
  }
}
