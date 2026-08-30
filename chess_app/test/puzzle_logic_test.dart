import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/services/puzzle_engine.dart';

void main() {
  group('PuzzleEngine Unit Tests', () {
    test('1. Validates correct user move in single-line solution', () {
      final Map<String, dynamic> singleLineSolutions = {
        'b3b2': {
          'c2c1q': {
            'e2e3': 'CHECKMATE',
          },
        },
      };

      final engine = PuzzleEngine(singleLineSolutions);

      expect(engine.totalVariations, equals(1));
      expect(engine.completedVariations, equals(0));

      // Play correct first move
      final result1 = engine.playUserMove('b3b2');
      expect(result1, equals(MoveValidationResult.correct));
      expect(engine.visitedMovePath, contains('b3b2'));

      // Play opponent move
      final oppMove = engine.playOpponentResponse();
      expect(oppMove, equals('c2c1q'));

      // Play winning checkmate move
      final result2 = engine.playUserMove('e2e3');
      expect(result2, equals(MoveValidationResult.checkmate));
      expect(engine.completedVariations, equals(1));
      expect(engine.isFullySolved, isTrue);
    });

    test('2. Rejects incorrect user move', () {
      final Map<String, dynamic> solutions = {
        'd6g6': {
          'e5f4': 'CHECKMATE',
        },
      };

      final engine = PuzzleEngine(solutions);

      final result = engine.playUserMove('a1a2'); // Wrong move
      expect(result, equals(MoveValidationResult.incorrect));
      expect(engine.completedVariations, equals(0));
      expect(engine.isFullySolved, isFalse);
    });

    test('3. Handles pawn promotion UCI case-insensitivity (c2c1q vs c2c1Q)',
        () {
      final Map<String, dynamic> solutions = {
        'c2c1q': 'CHECKMATE',
      };

      final engine = PuzzleEngine(solutions);

      final result = engine.playUserMove('C2C1Q'); // Upper case
      expect(result, equals(MoveValidationResult.checkmate));
      expect(engine.isFullySolved, isTrue);
    });

    test(
        '4. Detects variation branch points when opponent has multiple defensive moves',
        () {
      // Puzzle: f1h3 user move, opponent can defend with e4d3 or e4f3
      final Map<String, dynamic> multiBranchSolutions = {
        'f1h3': {
          'e4d3': {
            'h3f5': 'CHECKMATE',
          },
          'e4f3': {
            'h3g2': 'CHECKMATE',
          },
        },
      };

      final engine = PuzzleEngine(multiBranchSolutions);

      // Opponent has 2 defensive lines, so total variations = 2
      expect(engine.totalVariations, equals(2));

      // First user move
      final res1 = engine.playUserMove('f1h3');
      expect(res1, equals(MoveValidationResult.correct));

      // Opponent responds (registers branch point for remaining 'e4f3')
      final oppRes = engine.playOpponentResponse();
      expect(oppRes, equals('e4d3'));
      expect(engine.branchPoints.length, equals(1));
      expect(
          engine.branchPoints.first.remainingOpponentMoves, contains('e4f3'));

      // Complete line 1
      final res2 = engine.playUserMove('h3f5');
      expect(res2, equals(MoveValidationResult.checkmate));
      expect(engine.completedVariations, equals(1));
      expect(engine.isFullySolved, isFalse); // Only line 1 solved

      // Rewind to branch point for line 2
      final hasBranch = engine.rewindToNextVariation();
      expect(hasBranch, isTrue);
    });

    test('5. Solves 100% of puzzle when all defensive branches are completed',
        () {
      final Map<String, dynamic> multiBranchSolutions = {
        'f1h3': {
          'e4d3': {
            'h3f5': 'CHECKMATE',
          },
          'e4f3': {
            'h3g2': 'CHECKMATE',
          },
        },
      };

      final engine = PuzzleEngine(multiBranchSolutions);

      // Line 1
      engine.playUserMove('f1h3');
      engine.playOpponentResponse(); // e4d3
      engine.playUserMove('h3f5'); // Mat
      expect(engine.completedVariations, equals(1));

      // Rewind to branch point for Line 2
      final hasBranch = engine.rewindToNextVariation();
      expect(hasBranch, isTrue);

      final nextOpp = engine.playOpponentResponse(); // e4f3
      expect(nextOpp, equals('e4f3'));

      final res2 = engine.playUserMove('h3g2'); // Mat
      expect(res2, equals(MoveValidationResult.checkmate));
      expect(engine.completedVariations, equals(2));
      expect(engine.isFullySolved, isTrue);
    });
  });
}
