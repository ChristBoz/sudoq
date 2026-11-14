import 'package:flutter_test/flutter_test.dart';
import 'package:sudoq/logic/sudoku_game.dart';

const solution = [
  [1, 2, 3, 4],
  [3, 4, 1, 2],
  [4, 3, 2, 1],
  [2, 1, 4, 3],
];

void main() {
  test('clues cannot be overwritten', () {
    final game = SudokuGame();
    expect(game.isClue(0, 0), isTrue);
    expect(game.setCell(0, 0, 3), isFalse);
    expect(game.cells[0][0], 1);
  });

  test('a repeated digit in a row is a conflict', () {
    final game = SudokuGame();
    game.setCell(0, 2, 1); // row 0 already has a 1
    expect(game.hasConflict(0, 2), isTrue);
    expect(game.isComplete, isFalse);
  });

  test('the correct solution completes the puzzle', () {
    final game = SudokuGame();
    for (var r = 0; r < 4; r++) {
      for (var c = 0; c < 4; c++) {
        game.setCell(r, c, solution[r][c]);
      }
    }
    expect(game.isComplete, isTrue);
  });

  test('reset clears the entries but keeps the clues', () {
    final game = SudokuGame();
    game.setCell(0, 2, 3);
    game.reset();
    expect(game.cells[0][2], 0);
    expect(game.cells[0][0], 1);
  });
}
