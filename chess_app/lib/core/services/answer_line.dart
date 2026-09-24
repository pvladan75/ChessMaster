/// The answer line's one home — `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1.3
/// (§4, "the lines are cut by the tutorial's `answerPlyCount`, lifted to one
/// shared home, not copied").
///
/// The tutorial generator cut its answer lines with `answerPlyCount`
/// (`skeleton_moments.dart`), which now delegates here; the review's puzzles
/// (`local_puzzle_extractor_service.dart`) cut theirs the same way, at
/// [kRevealPlies] rather than the tutorial's shorter numbers (§3, "The whole
/// line is kept, and each reader cuts it" — the engine hands back the whole
/// PV at no cost, and each reader decides how much of it to show).
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/features/tutorial_studio/services/game_tutorial/board_queries.dart'
    show materialOf;

/// How many plies of [line], playable from [fen], the answer part shows:
/// [shortest] normally, but **never ending while [mover]** ('White' or
/// 'Black') **is still down material** from where they started — bounded by
/// [longest] rather than by the line's own length, because the engine hands
/// back the whole line and this must not become "show all of it" the day a
/// caller's numbers change.
///
/// Throws [StateError] on a move in [line] that does not play from [fen] —
/// the body of the tutorial's old `answerPlyCount`, unchanged by the move.
int answerLineLength(
  String fen,
  String mover,
  List<String> line, {
  required int shortest,
  required int longest,
}) {
  if (line.isEmpty) return 0;
  final board = chess.Chess.fromFEN(fen);
  final sign = mover == 'White' ? 1 : -1;
  final start = sign * materialOf(board);
  final after = <int>[];
  for (final san in line) {
    // `move` answers false and leaves the board where it was, so an unchecked
    // call measures every later ply from the wrong position. python-chess's
    // `push_san` raises; so does this.
    if (!board.move(san)) {
      throw StateError('$san cannot be played from ${board.fen}');
    }
    after.add(sign * materialOf(board));
  }
  final cap = longest < after.length ? longest : after.length;
  var cut = shortest < cap ? shortest : cap;
  if (cut == 0) return 0;
  while (cut < cap && after[cut - 1] < start) {
    cut++;
  }
  return cut;
}

/// The most plies a puzzle's reveal ever shows — the owner's choice of
/// 24.9.2026, raised from the tutorial's four/eight (§3).
const int kRevealPlies = 12;

/// [line] (SAN moves, playable from [fen]) cut for the reveal: at least 4
/// plies, at most [kRevealPlies], with the side to move in [fen] as the
/// mover whose material decides when to stop early. Throws [StateError] on a
/// move that does not play.
List<String> revealLine(String fen, List<String> line) {
  final mover = fen.trim().split(RegExp(r'\s+'))[1] == 'w' ? 'White' : 'Black';
  final cut = answerLineLength(
    fen,
    mover,
    line,
    shortest: 4,
    longest: kRevealPlies,
  );
  return line.sublist(0, cut);
}
