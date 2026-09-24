/// A pasted PGN as an Analysis tree — main line, variations, comments, arrows,
/// squares and assessments.
///
/// Until 16.9.2026 the Analysis import went through `chess.load_pgn` and
/// `getHistory()`. That keeps the main line only, and it also refuses the whole
/// text on things this app writes itself: a variation in brackets, and the
/// space `PgnExporterService` leaves in front of move one. So a repertoire
/// exported as PGN — whose alternates *are* its variations — came back as
/// „Invalid PGN format", from the same app that wrote it.
///
/// **Nothing here parses a move.** The line is read by [readStepTree] →
/// `LessonStepLine` → `MoveTree.parsePgn`, the one reader, which is what the
/// tutorial studio's PGN tab already uses.
library;

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/move_tree.dart';

const _standardStartFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// What a PGN came to.
///
/// [tip] is the end of the main line, where the screen stands. [rejectedMoves]
/// counts move tokens that could not be played and are **not** in the tree —
/// above zero the screen must say so, because a shorter game shown as the
/// whole one is the fault this app keeps having. [gameCount] above one means
/// only the first game was read.
typedef AnalysisPgnImport = ({
  AnalysisNode root,
  AnalysisNode tip,
  int moveCount,
  int rejectedMoves,
  Map<String, String> headers,
  int gameCount,
});

/// Reads the first game of [text], or returns null when it holds nothing to
/// show: no playable move and no `[FEN]` position either.
AnalysisPgnImport? readAnalysisPgn(String text) {
  final games = MoveTree.splitGames(text);
  final game = games.isEmpty ? null : games.first;
  final headers = game?.headers ?? const <String, String>{};

  final headerFen = headers['FEN']?.trim();
  final startFen = (headerFen != null && headerFen.isNotEmpty)
      ? headerFen
      : _standardStartFen;

  // A single game is handed over whole — the reader drops the header lines
  // itself. Only when there are several is the first game's body cut out.
  final body = games.length > 1 ? game!.pgnBody : text;
  final read = readStepTree(fen: startFen, pgn: body);

  final hasFen = headerFen != null && headerFen.isNotEmpty;
  if (read.root.children.isEmpty && !hasFen) return null;

  // Kept with the game, so the review can say how long a move took: the clock
  // after a move includes the increment (docs/PLAN-ZAGONETKE-IZ-PARTIJE.md,
  // phase 3). `-` and `?` say there is none.
  final timeControl = headers['TimeControl']?.trim();
  if (timeControl != null &&
      timeControl.isNotEmpty &&
      timeControl != '-' &&
      timeControl != '?') {
    read.root.timeControl = timeControl;
  }

  var tip = read.root;
  while (tip.children.isNotEmpty) {
    tip = tip.children.first;
  }

  int count(AnalysisNode node) =>
      node.children.fold(node.children.length, (sum, c) => sum + count(c));

  return (
    root: read.root,
    tip: tip,
    moveCount: count(read.root),
    rejectedMoves: read.rejectedMoves,
    headers: headers,
    gameCount: games.length,
  );
}
