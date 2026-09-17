import 'package:chess/chess.dart' as chess;
import 'package:chess_app/core/models/drill_outcome.dart';
import 'package:flutter_test/flutter_test.dart';

/// Played rather than hand-written, because a FEN typed from memory is exactly
/// the kind of unverified constant this test exists to argue against — the
/// first draft of it asserted against two positions that were not mates at all.
chess.Chess _afterMoves(List<String> sans) {
  final game = chess.Chess();
  for (final san in sans) {
    expect(game.move(san), isTrue, reason: 'illegal in fixture: $san');
  }
  return game;
}

/// Fool's mate: 1. f3 e5 2. g4 Qh4#. White is to move and mated.
chess.Chess _whiteIsMated() => _afterMoves(['f3', 'e5', 'g4', 'Qh4#']);

/// The mirror: 1. e4 f6 2. d4 g5 3. Qh5#. Black is to move and mated.
chess.Chess _blackIsMated() => _afterMoves(['e4', 'f6', 'd4', 'g5', 'Qh5#']);

void main() {
  group('sideToMoveOf', () {
    test('reads the side a drill hands to the reader', () {
      expect(
        sideToMoveOf('8/8/8/8/8/8/8/K6k w - - 0 1'),
        chess.Color.WHITE,
      );
      expect(
        sideToMoveOf('8/8/8/8/8/8/8/K6k b - - 0 1'),
        chess.Color.BLACK,
      );
    });

    test('a FEN with no side field loads as white rather than throwing', () {
      // A malformed position is a loading problem. It should surface as a board
      // that looks wrong, not as an exception thrown from inside a verdict.
      expect(sideToMoveOf('8/8/8/8/8/8/8/K6k'), chess.Color.WHITE);
    });
  });

  group('outcomeFor', () {
    test('the mated side loses, whichever side the reader is', () {
      final game = _whiteIsMated();
      expect(game.in_checkmate, isTrue);
      expect(outcomeFor(game, chess.Color.WHITE), DrillOutcome.readerLost);
      expect(outcomeFor(game, chess.Color.BLACK), DrillOutcome.readerWon);
    });

    test('and again with the colours the other way round', () {
      final game = _blackIsMated();
      expect(game.in_checkmate, isTrue);
      expect(outcomeFor(game, chess.Color.BLACK), DrillOutcome.readerLost);
      expect(outcomeFor(game, chess.Color.WHITE), DrillOutcome.readerWon);
    });

    test('a game still running is undecided', () {
      final game = chess.Chess();
      expect(outcomeFor(game, chess.Color.WHITE), DrillOutcome.undecided);
      expect(outcomeFor(game, chess.Color.BLACK), DrillOutcome.undecided);
    });

    test('stalemate is a draw for both sides, not a win for either', () {
      final game = chess.Chess.fromFEN('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      expect(game.in_stalemate, isTrue);
      expect(outcomeFor(game, chess.Color.WHITE), DrillOutcome.drawn);
      expect(outcomeFor(game, chess.Color.BLACK), DrillOutcome.drawn);
    });

    // The regression this file exists for. The AI Studio drills decided the
    // outcome by category: inside the engine's own move handler, `basic_mate`
    // reported a loss and every other category fell through to the victory
    // dialog. So in `winning_position` a mate delivered by Stockfish
    // congratulated the reader on delivering it and marked the drill solved.
    //
    // The verdict must depend on the board and the reader's side and on
    // nothing else — which is why this function takes neither a category nor
    // who moved last, and why there is no way to pass one in.
    test('a mate against the reader is a loss with no category to appeal to',
        () {
      final mated = _whiteIsMated();
      // The reader is white, whatever drill this is.
      expect(outcomeFor(mated, chess.Color.WHITE), DrillOutcome.readerLost);
    });
  });

  // Phase 0 of docs/PLAN-DOMACI-ZADATAK.md: the reason the game ended, one
  // position per ending. Each is proven to end by exactly its rule and by
  // none of the other four the board can read, so a rule that fires for the
  // wrong position — or two that overlap — is caught here and not in a
  // student's homework report.
  group('verdictFor names the ending', () {
    final boardEndings = <GameEnding, chess.Chess Function()>{
      GameEnding.checkmate: _whiteIsMated,
      GameEnding.stalemate: () =>
          chess.Chess.fromFEN('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1'),
      GameEnding.insufficientMaterial: () =>
          chess.Chess.fromFEN('k7/8/8/8/8/8/8/K6B w - - 0 1'),
      // Knights out and back twice: the start position for the third time.
      GameEnding.threefoldRepetition: () =>
          _afterMoves(['Nf3', 'Nf6', 'Ng1', 'Ng8', 'Nf3', 'Nf6', 'Ng1', 'Ng8']),
      // Loaded at 99 half-moves; one quiet rook move makes it a hundred.
      GameEnding.fiftyMoves: () {
        final game = chess.Chess.fromFEN('8/8/8/8/8/k7/8/K5R1 w - - 99 80');
        expect(game.move('Rg2'), isTrue);
        return game;
      },
    };
    bool holds(chess.Chess g, GameEnding e) => switch (e) {
          GameEnding.checkmate => g.in_checkmate,
          GameEnding.stalemate => g.in_stalemate,
          GameEnding.insufficientMaterial => g.insufficient_material,
          GameEnding.threefoldRepetition => g.in_threefold_repetition,
          GameEnding.fiftyMoves => g.half_moves >= 100,
          _ => false,
        };

    for (final entry in boardEndings.entries) {
      test('${entry.key.name}, and none of the other board endings', () {
        final game = entry.value();
        for (final other in boardEndings.keys) {
          expect(holds(game, other), other == entry.key,
              reason: '${other.name} on the ${entry.key.name} fixture');
        }
        final verdict = verdictFor(game, chess.Color.WHITE);
        expect(verdict.ending, entry.key);
        expect(verdict.isOver, isTrue);
        expect(
            verdict.outcome,
            entry.key == GameEnding.checkmate
                ? DrillOutcome.readerLost
                : DrillOutcome.drawn);
      });
    }

    test('a running game has no ending', () {
      final verdict = verdictFor(chess.Chess(), chess.Color.WHITE);
      expect(verdict, same(GameVerdict.undecided));
      expect(verdict.ending, isNull);
      expect(verdict.isOver, isFalse);
    });

    test(
        'the move limit ends an undecided game as a draw, counted from the '
        'position the drill loaded', () {
      final game = chess.Chess.fromFEN(
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      for (final san in ['e4', 'e5', 'Nf3', 'Nc6']) {
        expect(game.move(san), isTrue);
      }
      expect(verdictFor(game, chess.Color.WHITE, plyCap: 5).isOver, isFalse);
      final capped = verdictFor(game, chess.Color.WHITE, plyCap: 4);
      expect(capped.outcome, DrillOutcome.drawn);
      expect(capped.ending, GameEnding.moveLimit);
    });

    test('resigning loses a game the board has not ended', () {
      final verdict =
          verdictFor(chess.Chess(), chess.Color.BLACK, resigned: true);
      expect(verdict.outcome, DrillOutcome.readerLost);
      expect(verdict.ending, GameEnding.resignation);
    });

    test('the board is asked before the inputs', () {
      // Mated and „resigned" in the same call: the mate is what happened.
      final mated = _whiteIsMated();
      expect(verdictFor(mated, chess.Color.WHITE, resigned: true).ending,
          GameEnding.checkmate);
      // Stalemate with the limit also reached: the stalemate is named.
      final stale = chess.Chess.fromFEN('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
      expect(verdictFor(stale, chess.Color.WHITE, plyCap: 0).ending,
          GameEnding.stalemate);
    });

    test('outcomeFor is the verdict with the reason dropped', () {
      for (final make in boardEndings.values) {
        final game = make();
        for (final side in [chess.Color.WHITE, chess.Color.BLACK]) {
          expect(outcomeFor(game, side), verdictFor(game, side).outcome);
        }
      }
    });

    test('every ending has words', () {
      for (final ending in GameEnding.values) {
        expect(endingLabel(ending), isNotEmpty);
      }
      expect(endingLabel(GameEnding.stalemate), 'stalemate');
    });
  });

  group('isSideSwap', () {
    test('moving for the other side is a swap', () {
      expect(isSideSwap(chess.Color.WHITE, chess.Color.BLACK), isTrue);
      expect(isSideSwap(chess.Color.BLACK, chess.Color.WHITE), isTrue);
    });

    test('moving for your own side is not', () {
      expect(isSideSwap(chess.Color.WHITE, chess.Color.WHITE), isFalse);
      expect(isSideSwap(chess.Color.BLACK, chess.Color.BLACK), isFalse);
    });

    test('no side yet means nothing to swap away from', () {
      // Before a drill has loaded there is no reader's side, and announcing a
      // swap then would be announcing a change that did not happen.
      expect(isSideSwap(null, chess.Color.WHITE), isFalse);
      expect(isSideSwap(null, chess.Color.BLACK), isFalse);
    });
  });
}
