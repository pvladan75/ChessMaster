/// A game's main line as an Analysis tree, from the moves the archive keeps.
///
/// `docs/PLAN-SKELET.md`, D4 (owner, 14.9.2026): an archive mistake opens its
/// game in Analysis, and the Analysis door makes the tutorial — one door. The
/// server returns a game as its starting position and its moves in UCI, which
/// is how `user_games.moves` stores them.
///
/// **A move that cannot be played ends the line there**, and [GameTree.playable]
/// says how far it got, so the screen can say so rather than show a shorter
/// game as if it were the whole one.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/board_queries.dart'
    show findMove;

/// A game handed to Analysis: where it starts, its moves, the ply to stand on,
/// and which side of the board faces the reader.
typedef AnalysisGame = ({
  String startFen,
  List<String> uciMoves,
  int cursorPly,
  bool blackOrientation,
});

typedef GameTree = ({AnalysisNode root, int playable});

/// The tree of [uciMoves] from [startFen]: one child per node.
GameTree analysisTreeFromMoves(String startFen, List<String> uciMoves) {
  final root = AnalysisNode(fen: startFen);
  final game = chess.Chess.fromFEN(startFen);
  var parent = root;
  var playable = 0;
  for (final raw in uciMoves) {
    if (raw.length < 4) break;
    final uci = _standardCastling(game, raw);
    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length > 4 ? uci.substring(4, 5) : '';
    Map<String, dynamic>? found;
    for (final m in legalMoves(game)) {
      if (m['from'] == from &&
          m['to'] == to &&
          (m['promotion'] ?? '') == promotion) {
        found = m;
        break;
      }
    }
    if (found == null) break;
    game.move({
      'from': from,
      'to': to,
      if (promotion.isNotEmpty) 'promotion': promotion,
    });
    final node = AnalysisNode(
      fen: game.fen,
      moveSan: found['san'] as String,
      moveUci: uci,
      parent: parent,
    );
    parent.children.add(node);
    parent = node;
    playable++;
  }
  return (root: root, playable: playable);
}

/// A game kept as SAN — a homework's „play it out", which the server stores as
/// the moves both sides played — as the game the Analysis door takes
/// (`docs/PLAN-EXERCISE.md`, phase 13). It stands on the last move: the
/// position reached is what is being judged.
///
/// **Null when the game does not replay whole**, from a position that is one.
/// [analysisTreeFromMoves] ends a line at the move it cannot play, which is
/// right for an archive that says how far it got; here a shorter game would be
/// shown to the trainer as the game the student played, so it is refused and
/// the caller says so.
AnalysisGame? analysisGameFromSans({
  required String startFen,
  required List<String> sans,
  required bool blackOrientation,
}) {
  if (chess.Chess.validate_fen(startFen)['valid'] != true) return null;
  final game = chess.Chess.fromFEN(startFen);
  final uciMoves = <String>[];
  for (final san in sans) {
    final chess.Move move;
    try {
      move = findMove(game, san.trim());
    } catch (_) {
      return null;
    }
    final promotion = move.promotion;
    uciMoves.add('${move.fromAlgebraic}${move.toAlgebraic}'
        '${promotion == null ? '' : promotion.toLowerCase()}');
    game.make_move(move);
  }
  return (
    startFen: startFen,
    uciMoves: uciMoves,
    cursorPly: uciMoves.length,
    blackOrientation: blackOrientation,
  );
}

/// The node [ply] moves down the main line from [root], or the last one when
/// the line is shorter — where Analysis stands when it opens a game on a
/// mistake.
AnalysisNode nodeAtPly(AnalysisNode root, int ply) {
  var node = root;
  for (var i = 0; i < ply && node.children.isNotEmpty; i++) {
    node = node.children.first;
  }
  return node;
}

/// Lichess writes castling as the king taking its own rook (`e1h1`); the board
/// here, and every UCI string in this app, moves the king two squares.
String _standardCastling(chess.Chess game, String uci) {
  const kingTakesRook = {
    'e1h1': 'e1g1',
    'e1a1': 'e1c1',
    'e8h8': 'e8g8',
    'e8a8': 'e8c8',
  };
  final standard = kingTakesRook[uci];
  if (standard == null) return uci;
  final piece = game.get(uci.substring(0, 2));
  return piece != null && piece.type == chess.PieceType.KING ? standard : uci;
}
