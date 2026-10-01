// puzzle_history_words.dart — how a row of the puzzle list reads.
//
// The server decides what a puzzle is and where it stands
// (`GET /api/puzzles/list`, docs/PLAN-NAPREDAK-VEZBI.md §7); this file only
// puts it into words, in one place, so the row, the pane and the sheet say the
// same thing. Everything a state is told by is a word, never a colour: the
// owner is colour-blind, and a green beside a red tells him nothing.

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show themeLabel;

/// What each source is called where a reader chooses between them — the
/// source menu above the list. The Practise cards' own names.
const Map<String, String> puzzleSourceNames = {
  PuzzleSource.lichess: 'Tactics',
  PuzzleSource.matePuzzle: 'Mate puzzles',
  PuzzleSource.winningPosition: 'Winning positions',
  PuzzleSource.endgame: 'Endgames',
  PuzzleSource.blunderGame: 'Game blunders',
  PuzzleSource.basicMate: 'Basic checkmates',
  PuzzleSource.own: 'My exercises',
};

/// One puzzle of a source, before anything more is known of it.
const Map<String, String> _oneOf = {
  PuzzleSource.lichess: 'Tactics',
  PuzzleSource.matePuzzle: 'Mate puzzle',
  PuzzleSource.winningPosition: 'Winning position',
  PuzzleSource.endgame: 'Endgame',
  PuzzleSource.blunderGame: 'Game blunder',
  PuzzleSource.basicMate: 'Basic checkmate',
  PuzzleSource.own: 'My exercise',
};

String _capitalised(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// The move number written in a FEN — its sixth field.
int? _moveNumberOf(String? fen) {
  final fields = (fen ?? '').trim().split(RegExp(r'\s+'));
  return fields.length >= 6 ? int.tryParse(fields[5]) : null;
}

/// What the puzzle is: „Mate in 2", „Tactics · fork, pin", „Rook and pawn
/// versus rook · Hold a draw", „Game blunder · move 34", „Basic checkmate ·
/// easy", or an own exercise's task. A puzzle that is gone says so.
String puzzleKindWords(PuzzleListItem item) {
  final kind = _oneOf[item.source] ?? 'Puzzle';
  if (!item.available) return '$kind · no longer available';
  final detail = item.detail;
  switch (item.source) {
    case PuzzleSource.lichess:
      // The server sends motifs only (`trainableThemes`); two are enough to
      // tell one puzzle from the next.
      final motifs = ((detail['themes'] as List?) ?? const [])
          .map((t) => themeLabel(t.toString()))
          .take(2)
          .toList();
      return motifs.isEmpty ? kind : '$kind · ${motifs.join(', ')}';
    case PuzzleSource.matePuzzle:
      final depth = (detail['mateDepth'] as num?)?.toInt();
      return depth == null ? kind : 'Mate in $depth';
    case PuzzleSource.endgame:
      final label = detail['materialLabel']?.toString();
      final mode = switch (detail['mode']) {
        'win' => 'Win',
        'draw' => 'Hold a draw',
        _ => null,
      };
      final what =
          (label == null || label.isEmpty) ? kind : _capitalised(label);
      return mode == null ? what : '$what · $mode';
    case PuzzleSource.blunderGame:
      // A blunder's ply counts from the board its walk starts on, not from
      // move one; the position's own move number is the one a player knows.
      final move = _moveNumberOf(item.fen);
      return move == null ? kind : '$kind · move $move';
    case PuzzleSource.basicMate:
      final preset = detail['preset']?.toString();
      return preset == null || preset.isEmpty ? kind : '$kind · $preset';
    case PuzzleSource.own:
      final task = detail['instruction']?.toString().trim();
      return task == null || task.isEmpty ? kind : task;
    default:
      return kind;
  }
}

/// Where it stands, in words: „Solved first try", „Solved on try 3",
/// „Solved with a hint", „Failed", „Skipped".
String puzzleStateWords(PuzzleListItem item) {
  switch (item.state) {
    case PuzzleState.solved:
      if (item.firstTry) return 'Solved first try';
      final on = item.solvedOnTry;
      // The first answer solved it and still was not a first-try solve: it
      // had a hint.
      if (on == 1) return 'Solved with a hint';
      return on == null ? 'Solved' : 'Solved on try $on';
    case PuzzleState.skipped:
      return 'Skipped';
    default:
      return 'Failed';
  }
}

/// „1 try", „3 tries" — answers, not skips. Null for a puzzle only ever
/// skipped.
String? puzzleTriesWords(PuzzleListItem item) {
  if (item.tries <= 0) return null;
  return item.tries == 1 ? '1 try' : '${item.tries} tries';
}

/// A day as the app writes one everywhere else: 28.9.2026.
String puzzleDateWords(DateTime at) {
  final local = at.toLocal();
  return '${local.day}.${local.month}.${local.year}';
}

/// The row's second line: where it stands, how many tries, and when last.
/// A solved puzzle's state already says which try did it — „Solved on try 2
/// · 2 tries" says one thing twice — so the count is for the others.
String puzzleSummaryWords(PuzzleListItem item) => [
      puzzleStateWords(item),
      if (item.state != PuzzleState.solved) puzzleTriesWords(item),
      puzzleDateWords(item.latestAt),
    ].whereType<String>().join(' · ');
