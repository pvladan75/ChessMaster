import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/lessons/models/lesson_step_line.dart';

/// `LessonStepLine` is the one reader of a lesson step's line — the student's
/// screen and the trainer's studio both go through it.
///
/// What it is for: `MoveTree.parsePgn` skips a move it cannot play and says
/// nothing, so a `pgn` written from one position and a `fen` naming another
/// arrived as an empty tree that looked exactly like a step with no line in it.
/// Everything below is about telling those two apart.
void main() {
  const start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// Builds a chain of moves as the studio would, playing each SAN so the FENs
  /// are the real ones rather than transcribed by hand.
  AnalysisNode chain(String fen, List<String> sans, List<String> comments) {
    final game = chess.Chess.fromFEN(fen);
    final root = AnalysisNode(fen: fen);
    var node = root;
    for (var i = 0; i < sans.length; i++) {
      expect(game.move(sans[i]), isTrue, reason: '${sans[i]} must be legal');
      final made = game.history.last.move;
      node = node.addChild(
        childFen: game.fen,
        san: sans[i],
        uci: '${made.fromAlgebraic}${made.toAlgebraic}',
      );
      node.comment = comments[i];
    }
    return root;
  }

  AnalysisNode threeMover() => chain(
        start,
        ['e4', 'e5', 'Nf3'],
        ['komentar uz e4', 'komentar uz e5', 'komentar uz Nf3'],
      );

  AnalysisNode nodeAfter(AnalysisNode root, int plies) {
    var node = root;
    for (var i = 0; i < plies; i++) {
      node = node.children.first;
    }
    return node;
  }

  test('a line saved from its own position replays, with every note', () {
    final root = threeMover();

    final step = LessonStepLine.read(
      fen: root.fen,
      pgn: PgnExporterService.exportToPgn(root),
    );

    expect(step.replays, isTrue);
    expect(step.rejectedMoves, 0);
    expect(step.line.movesSan, ['e4', 'e5', 'Nf3']);
    expect(step.line.comments,
        ['komentar uz e4', 'komentar uz e5', 'komentar uz Nf3']);
  });

  group('the pairing that used to be saved is refused', () {
    // The studio sent `_currentNode.fen` with `exportToPgn(_rootNode)`. Standing
    // anywhere but the root, those describe different games — and which of the
    // two silent failures you got was decided by parity, which is why both are
    // here.

    test('an even number of plies in: not one move survives', () {
      final root = threeMover();
      final pgn = PgnExporterService.exportToPgn(root); // from the root
      final fen = nodeAfter(root, 3).fen; // …and a position three plies in

      final step = LessonStepLine.read(fen: fen, pgn: pgn);

      expect(step.replays, isFalse);
      expect(step.rejectedMoves, 3);
      // The student's screen: a still picture, no strip, and the trainer was
      // told the step had been saved.
      expect(step.line.movesSan, isEmpty);
    });

    test('an odd number of plies in: the line survives, shortened', () {
      final root = threeMover();
      final pgn = PgnExporterService.exportToPgn(root);
      final fen = nodeAfter(root, 1).fen; // after 1.e4

      final step = LessonStepLine.read(fen: fen, pgn: pgn);

      // Worse than empty, because it looks right: the moves that replay are
      // kept and the ones before the position are dropped, note and all.
      expect(step.line.movesSan, ['e5', 'Nf3']);
      expect(step.rejectedMoves, 1);
      expect(step.replays, isFalse,
          reason: 'a line missing a move is not a line that replays');
    });
  });

  test('a step with no line is a still position, not a failure', () {
    expect(LessonStepLine.read(fen: start, pgn: null).replays, isTrue);
    expect(LessonStepLine.read(fen: start, pgn: '   ').replays, isTrue);
    expect(LessonStepLine.read(fen: start, pgn: null).line.movesSan, isEmpty);
  });

  test('a leaf carries no moves and still replays', () {
    final root = threeMover();
    final leaf = nodeAfter(root, 3);

    final step = LessonStepLine.read(
      fen: leaf.fen,
      pgn: PgnExporterService.exportToPgn(leaf),
    );

    expect(step.replays, isTrue);
    expect(step.line.movesSan, isEmpty);
  });

  group('what must not be counted as a rejection', () {
    // `replays` is read as "refuse to save this step", so anything a real PGN
    // legitimately carries and this parser skips would block a good line.

    test('annotation glyphs on a move, including the studio\'s own !□', () {
      final step =
          LessonStepLine.read(fen: start, pgn: '1. e4!□ e5?! 2. Nf3!?');

      expect(step.rejectedMoves, 0);
      expect(step.line.movesSan, ['e4', 'e5', 'Nf3']);
    });

    test('numeric NAGs, which annotate the move before them', () {
      final step = LessonStepLine.read(fen: start, pgn: r'1. e4 $1 e5 $14');

      expect(step.rejectedMoves, 0);
      expect(step.line.movesSan, ['e4', 'e5']);
    });

    test('the result and the move numbers', () {
      final step = LessonStepLine.read(fen: start, pgn: '1. e4 e5 2. Nf3 *');

      expect(step.rejectedMoves, 0);
    });

    test('a result marker glued to the last move', () {
      // Reported live on 7.9.2026: a line typed into the studio's „PGN" tab
      // was refused with „1 potez ne može da se odigra", and the move it
      // named was legal. The star had no space in front of it, so the token
      // was `Nxb4*` and the last move of the line was thrown away — the one
      // shape where the count is above zero and the trainer is right.
      final step = LessonStepLine.read(
        fen: start,
        pgn: '1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. b4 d5 5. exd5 Nxb4*',
      );

      expect(step.rejectedMoves, 0);
      expect(step.line.movesSan.last, 'Nxb4');
    });
  });

  test('a token that is not a move at all is counted', () {
    final step = LessonStepLine.read(fen: start, pgn: '1. e4 Zz9');

    expect(step.rejectedMoves, 1);
    expect(step.replays, isFalse);
    expect(step.line.movesSan, ['e4'], reason: 'what did replay is still kept');
  });

  test('one bad token throws the rest of the line out of turn', () {
    // Not a quirk worth hiding: the skipped move leaves the wrong side to
    // move, so what follows is illegal too. The count is "how many tokens did
    // not fit", not "how many mistakes the trainer made" — either way it is
    // above zero, which is the only thing read.
    final step = LessonStepLine.read(fen: start, pgn: '1. e4 Zz9 2. Nf3');

    expect(step.rejectedMoves, 2);
    expect(step.replays, isFalse);
  });

  test('a note about the starting position survives the round trip', () {
    // The one place a sentence about a still diagram can live. Written by the
    // exporter, read back into `rootComment`, and — until this was fixed —
    // dropped by the exporter, so the trainer typed it and it was gone.
    final root = threeMover();
    root.comment = 'Pogledaj polje d5.';

    final step = LessonStepLine.read(
      fen: root.fen,
      pgn: PgnExporterService.exportToPgn(root),
    );

    expect(step.line.rootComment, 'Pogledaj polje d5.');
    expect(step.replays, isTrue);
    expect(step.line.movesSan, ['e4', 'e5', 'Nf3'],
        reason: 'the note must not swallow the first move');
  });
}
