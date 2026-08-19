import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/stockfish_service_native.dart';

/// A scanned position whose side to move the trainer settled to black.
/// Opened on the analysis board it produced an evaluation but an empty line.
const _blackToMove = '5K1k/7b/8/8/pr6/2P5/1B4p1/7R b - - 0 1';

void main() {
  test('the chess package accepts a black-to-move FEN from a scan', () {
    final game = chess.Chess.fromFEN(_blackToMove);
    expect(game.turn, chess.Color.BLACK);
    expect(game.moves().length, greaterThan(0),
        reason: 'black has legal moves here; chess.js counts 21');
  });

  test('an engine line for black is replayed into SAN, not swallowed', () {
    // A plausible PV for this position, as Stockfish would emit it.
    final game = chess.Chess.fromFEN(_blackToMove);
    final first = game.generate_moves().first;
    final pv = '${first.fromAlgebraic}${first.toAlgebraic}';

    final line = AnalysisLine.fromPv(
      multipv: 1,
      eval: '+1.00',
      pvString: pv,
      startingFen: _blackToMove,
    );

    expect(line.sanMoveList, isNotEmpty,
        reason:
            'an empty list is what the screen renders as "Nema dostupnih poteza"');
    expect(line.bestMoveSan, isNotEmpty);
    expect(line.fenList.length, 2);
  });

  _materialTests();

  test('the same line for white works, to isolate the side as the variable',
      () {
    const whiteToMove = '5K1k/7b/8/8/pr6/2P5/1B4p1/7R w - - 0 1';
    final game = chess.Chess.fromFEN(whiteToMove);
    final first = game.generate_moves().first;
    final pv = '${first.fromAlgebraic}${first.toAlgebraic}';

    final line = AnalysisLine.fromPv(
      multipv: 1,
      eval: '+1.00',
      pvString: pv,
      startingFen: whiteToMove,
    );
    expect(line.sanMoveList, isNotEmpty);
  });
}

/// The material fallback, which fires when the engine will not answer.
void _materialTests() {
  test('material is counted from White\'s side, whoever is to move', () {
    // The position from the report: white R+B+P = 9, black R+B+2P = 10, so
    // black is a pawn up and the number must be negative either way.
    const asBlack = '5K1k/7b/8/8/pr6/2P5/1B4p1/7R b - - 0 1';
    const asWhite = '5K1k/7b/8/8/pr6/2P5/1B4p1/7R w - - 0 1';

    expect(StockfishService.materialEvaluation(asBlack), -1.0,
        reason:
            'flipping the sign for black inverted the answer and read +1.00');
    expect(StockfishService.materialEvaluation(asWhite), -1.0);
    expect(StockfishService.materialEvaluation(asBlack),
        StockfishService.materialEvaluation(asWhite),
        reason: 'whose move it is cannot change who has more wood');
  });

  test('the starting position counts as level', () {
    expect(
      StockfishService.materialEvaluation(
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'),
      0.0,
    );
  });
}
