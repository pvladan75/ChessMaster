/// What the two detectors say a move changed, as the sentence a model is
/// shown — one home for it (rule 12).
///
/// The review's words (`review_words.dart`) wrote this for the game's move,
/// the better move and the refutation; the position study
/// (`docs/PLAN-STUDIJA-POZICIJE.md`) asks the same question of every move it
/// offers words for. Both call here.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/finding_sentences.dart'
    show joinSentences;
import 'package:chess_app/core/services/legal_moves.dart' show legalMoves;
import 'package:chess_app/core/services/positional_evaluator_service.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';

/// The detectors' sentence for the position after [san] from [fen], as the
/// tutorial sends it (`motifs_after_played`); null when they say nothing, or
/// when [san] does not play from [fen].
String? moveMotifSentence(String fen, String san) {
  final uci = uciOfSan(fen, san);
  final after = fenAfterSan(fen, san);
  if (uci == null || after == null) return null;
  const tactical = TacticalMotifDetector();
  const positional = PositionalEvaluatorService();
  final sentence = joinSentences([
    tactical.describeMoveDiff(
      tactical.explainMove(beforeFen: fen, afterFen: after, lastMoveUci: uci),
    ),
    positional.describeMoveDiff(
      positional.explainMove(beforeFen: fen, afterFen: after, lastMoveUci: uci),
    ),
  ]).trim();
  return sentence.isEmpty ? null : sentence;
}

/// The position after [san] from [fen]; null when the move does not play.
String? fenAfterSan(String fen, String san) {
  final board = chess.Chess.fromFEN(fen);
  return board.move(san) ? board.fen : null;
}

/// [san] from [fen] as `e2e4`, `e7e8q`; null when no legal move is spelled so.
String? uciOfSan(String fen, String san) {
  for (final move in legalMoves(chess.Chess.fromFEN(fen))) {
    if (move['san'] == san) {
      return '${move['from']}${move['to']}${move['promotion'] ?? ''}';
    }
  }
  return null;
}
