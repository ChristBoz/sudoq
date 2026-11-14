// LOGIC: pure Dart rules. No Flutter, no Android, no storage.

/// 4 x 4 Sudoku rules (FR08). One fixed, prevalidated puzzle for the MVP.
class SudokuGame {
  SudokuGame() {
    reset();
  }

  static const int size = 4;

  /// 0 = empty. Unique solution:
  /// 1 2 3 4 / 3 4 1 2 / 4 3 2 1 / 2 1 4 3
  static const List<List<int>> _clues = [
    [1, 2, 0, 4],
    [0, 4, 1, 0],
    [4, 0, 0, 1],
    [0, 1, 4, 0],
  ];

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
  bool hasConflict(int row, int col) {
    final value = cells[row][col];
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
        if (sameUnit && cells[r][c] == value) return true;
      }
    }
    return false;
  }

  bool get isComplete {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (cells[r][c] == 0 || hasConflict(r, c)) return false;
      }
    }
    return true;
  }
}
