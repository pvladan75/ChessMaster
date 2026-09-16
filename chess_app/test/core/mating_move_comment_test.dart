// A mating move gets no automatic comment.
//
// Reported from a phone on 16.9.2026: under Rh5# the Analysis Studio wrote that
// the rook "skewers the black king on f5 and the bishop on d5 behind it", and
// the owner asked for no comment rather than a better one. The `#` says it.
//
// The findings themselves are left alone: a tutorial's facts read them after
// a mate too, and `game_tutorial_facts_test` compares those with the harness.
// So the rule is where a comment is written, [autoMoveComment], and these tests
// feed it the detectors' real output — which after these moves is not empty.

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/finding_sentences.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/core/services/positional_evaluator_service.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/models/analysis_models.dart';

/// The reported position, one move before: White plays Rh5# from h4. The rook
/// on h5 then stands on the rank of the black king on f5 with the bishop on d5
/// behind it, which is the skewer the comment named.
const _before = 'r1n2N1K/3p4/2pp1pP1/1nbb1k2/7R/2N1Bp1P/3P4/q7 w - - 0 1';
const _mate = 'h4h5';

/// A mate the positional evaluator does have something to say about:
/// „White's pawns hold more of the centre." after Qxf7#, found by walking
/// random games to a mate.
const _positionalBefore =
    '1nbqkb1r/r1p1p1p1/3p1n1p/1P1QNp2/4P3/2P4P/1P1P1P2/1NB1KB1R w K - 6 13';
const _positionalMate = 'd5f7';

String _after(String fen, String uci) {
  final game = chess.Chess.fromFEN(fen);
  final ok =
      game.move({'from': uci.substring(0, 2), 'to': uci.substring(2, 4)});
  expect(ok, isTrue, reason: '$uci is not legal in $fen');
  return game.fen;
}

void main() {
  const detector = TacticalMotifDetector();
  const evaluator = PositionalEvaluatorService();

  test('the reported mate still has its findings, and gets no comment', () {
    final after = _after(_before, _mate);
    expect(isCheckmate(after), isTrue);

    final said = detector.describeMoveDiff(detector.explainMove(
        beforeFen: _before, afterFen: after, lastMoveUci: _mate));
    // The input the rule has to silence — without it the test proves nothing.
    expect(said, contains('skewers'));

    expect(autoMoveComment(afterFen: after, parts: [said]), isEmpty);
  });

  test('a mate the positional evaluator speaks about gets no comment either',
      () {
    final after = _after(_positionalBefore, _positionalMate);
    expect(isCheckmate(after), isTrue);

    final said = evaluator.describeMoveDiff(evaluator.explainMove(
        beforeFen: _positionalBefore,
        afterFen: after,
        lastMoveUci: _positionalMate));
    expect(said, isNotEmpty);

    expect(autoMoveComment(afterFen: after, parts: [said]), isEmpty);
  });

  test('a move that is not mate keeps its comment', () {
    const before = '3r2k1/8/8/8/8/8/8/3Q2K1 w - - 0 1';
    final after = _after(before, 'd1d5');
    final said = detector.describeMoveDiff(detector.explainMove(
        beforeFen: before, afterFen: after, lastMoveUci: 'd1d5'));
    expect(said, isNotEmpty);
    expect(autoMoveComment(afterFen: after, parts: [said]), said);
  });

  test('reviewing a game writes no comment on its mating move', () async {
    final root = AnalysisNode(fen: _before);
    final mate = root.addChild(
        childFen: _after(_before, _mate), san: 'Rh5#', uci: _mate);

    final walk = await GameAnalysisWalkerService().annotateNodeChain(
      startNode: root,
      analyzer: (fen,
              {required depth,
              required multiPV,
              Duration timeout = const Duration(seconds: 10)}) async =>
          [
        AnalysisLine.fromPv(
            multipv: 1,
            depth: depth,
            eval: '0.00',
            pvString: '',
            startingFen: fen),
      ],
    );

    // The moment keeps what the detectors found; the node is left without.
    expect(walk.moments.single.combinedComment, contains('skewers'));
    expect(mate.comment, isEmpty);
  });
}
