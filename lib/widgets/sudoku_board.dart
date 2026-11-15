// WIDGETS: small reusable UI pieces. They only display what they are given
// and report changes through callbacks. They never touch state or services.

import 'package:flutter/material.dart';

import '../logic/sudoku_game.dart';

/// The playable puzzle: grid, message line and digit buttons.
///
/// Used by the voluntary Sudoku screen and by the gate shown when a
/// blocked app is opened. The rules themselves are in logic/sudoku_game.
class SudokuBoard extends StatefulWidget {
  const SudokuBoard({super.key, required this.game, this.onChanged});

  final SudokuGame game;

  /// Called after every move, so the parent can react to completion.
  final VoidCallback? onChanged;

  @override
  State<SudokuBoard> createState() => _SudokuBoardState();
}

class _SudokuBoardState extends State<SudokuBoard> {
  int? _row;
  int? _col;
  String? _message;

  SudokuGame get _game => widget.game;

  void _select(int row, int col) {
    setState(() {
      _row = row;
      _col = col;
      _message = _game.isClue(row, col) ? 'Clues cannot be changed.' : null;
    });
  }

  void _enter(int value) {
    final row = _row, col = _col;
    if (row == null || col == null) {
      setState(() => _message = 'Tap an empty cell first.');
      return;
    }
    setState(() {
      if (!_game.setCell(row, col, value)) {
        _message = 'Clues cannot be changed.';
      } else if (_game.hasConflict(row, col)) {
        _message = 'Each row, column and 2 × 2 box can hold a digit only once.';
      } else {
        _message = null;
      }
    });
    widget.onChanged?.call();
  }

  void _restart() {
    setState(() {
      _game.reset();
      _row = _col = null;
      _message = null;
    });
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final done = _game.isComplete;
    return Column(
      mainAxisSize: MainAxisSize.min,
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
                    key: ValueKey('digit-$n'),
                    onPressed: () => _enter(n),
                    child: Text('$n'),
                  ),
                ),
              IconButton(
                tooltip: 'Clear cell',
                icon: const Icon(Icons.backspace_outlined),
                onPressed: () => _enter(0),
              ),
              IconButton(
                tooltip: 'Restart puzzle',
                icon: const Icon(Icons.refresh),
                onPressed: _restart,
              ),
            ],
          ),
      ],
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
        key: ValueKey('cell-$r-$c'),
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
