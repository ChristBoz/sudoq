// LOGIC: pure Dart rules. No Flutter, no Android, no storage.

import 'dart:math';

/// 4 x 4 Sudoku rules (FR08).
///
/// `SudokuGame()` is one fixed puzzle (used by tests). `SudokuGame.random()`
/// makes a new puzzle each time, so the puzzle shown when an app is
/// blocked cannot simply be memorised.
class SudokuGame {
  /// A game from the given clues (0 = empty), or the fixed puzzle.
  SudokuGame([List<List<int>>? clues])
    : _clues = [
        for (final row in clues ?? _fixedClues) List<int>.unmodifiable(row),
      ] {
    reset();
  }

  /// A new random puzzle with exactly one solution.
  factory SudokuGame.random([Random? random]) =>
      SudokuGame(_randomClues(random ?? Random()));

  static const int size = 4;

  /// Unique solution: 1 2 3 4 / 3 4 1 2 / 4 3 2 1 / 2 1 4 3
  static const List<List<int>> _fixedClues = [
    [1, 2, 0, 4],
    [0, 4, 1, 0],
    [4, 0, 0, 1],
    [0, 1, 4, 0],
  ];

  final List<List<int>> _clues;

  late List<List<int>> cells;

  void reset() {
    cells = [for (final row in _clues) List<int>.of(row)];
  }

  bool isClue(int row, int col) => _clues[row][col] != 0;

  /// Returns false if the cell is a clue and cannot be changed.
  bool setCell(int row, int col, int value) {
    if (isClue(row, col)) return false;
    cells[row][col] = value;
    return true;
  }

  /// True when the digit in this cell repeats in its row, column or 2 x 2 box.
  bool hasConflict(int row, int col) => _conflicts(cells, row, col);

  bool get isComplete {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (cells[r][c] == 0 || hasConflict(r, c)) return false;
      }
    }
    return true;
  }

  /// How many ways the clues can be completed, counted up to [limit].
  /// A proper puzzle has exactly 1.
  int countSolutions({int limit = 2}) =>
      _countSolutions([for (final row in _clues) List<int>.of(row)], limit);

  // ---- Shared rule ---------------------------------------------------------

  static bool _conflicts(List<List<int>> grid, int row, int col) {
    final value = grid[row][col];
    if (value == 0) return false;
    final boxRow = row - row % 2;
    final boxCol = col - col % 2;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (r == row && c == col) continue;
        final sameUnit =
            r == row ||
            c == col ||
            (r - r % 2 == boxRow && c - c % 2 == boxCol);
        if (sameUnit && grid[r][c] == value) return true;
      }
    }
    return false;
  }

  // ---- Making random puzzles ------------------------------------------------

  /// Tries every way to fill the empty cells and counts the valid ones.
  static int _countSolutions(List<List<int>> grid, int limit) {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (grid[r][c] != 0) continue;
        var count = 0;
        for (var value = 1; value <= size; value++) {
          grid[r][c] = value;
          if (!_conflicts(grid, r, c)) {
            count += _countSolutions(grid, limit - count);
            if (count >= limit) break;
          }
        }
        grid[r][c] = 0;
        return count;
      }
    }
    return 1; // no empty cell left: this is one complete solution
  }

  /// A full valid grid, made by shuffling a known one in ways that keep
  /// it valid: renaming digits, and swapping rows/columns inside a band.
  static List<List<int>> _randomSolution(Random random) {
    const base = [
      [1, 2, 3, 4],
      [3, 4, 1, 2],
      [2, 1, 4, 3],
      [4, 3, 2, 1],
    ];
    final digits = [1, 2, 3, 4]..shuffle(random);

    // Order of rows: keep pairs (0,1) and (2,3) together, shuffle within
    // and between the pairs. Same for columns.
    List<int> order() {
      final top = [0, 1]..shuffle(random);
      final bottom = [2, 3]..shuffle(random);
      return random.nextBool() ? [...top, ...bottom] : [...bottom, ...top];
    }

    final rows = order();
    final cols = order();
    return [
      for (final r in rows) [for (final c in cols) digits[base[r][c] - 1]],
    ];
  }

  /// Removes digits from a full grid, one at a time in random order, as
  /// long as the puzzle still has exactly one solution.
  static List<List<int>> _randomClues(Random random) {
    final grid = _randomSolution(random);
    final positions = [for (var i = 0; i < size * size; i++) i]
      ..shuffle(random);

    for (final position in positions) {
      final r = position ~/ size;
      final c = position % size;
      final removed = grid[r][c];
      grid[r][c] = 0;
      final stillUnique =
          _countSolutions([for (final row in grid) List<int>.of(row)], 2) == 1;
      if (!stillUnique) grid[r][c] = removed;
    }
    return grid;
  }
}
