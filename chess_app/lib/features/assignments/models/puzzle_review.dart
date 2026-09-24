/// What a puzzle from a game reveals once it is answered —
/// `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, §4 and phase 5.
///
/// The server stores it (`custom_puzzles.review`, phase 2) and hands it over
/// only with the answer to an attempt, so nothing here is ever on screen
/// before the student has moved. [PuzzleReveal] decides which line goes under
/// which move; the solve screen only draws what it says.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/move_tree.dart' show ChessArrow;
import 'package:chess_app/services/app_logger.dart';

/// The stored review, as `readReview` (`services/exercise.js`) wrote it: SAN
/// lists, each already replayed on the server.
class PuzzleReview {
  const PuzzleReview({
    required this.played,
    required this.bestLine,
    this.refutationLine = const [],
    this.secondLine = const [],
    this.words,
    required this.bestChances,
    required this.playedChances,
    this.secondChances,
  });

  /// The game's move.
  final String played;

  /// The line behind the best move; its first move is the answer.
  final List<String> bestLine;

  /// The line after the game's move.
  final List<String> refutationLine;

  /// The engine's second line from the puzzle's position.
  final List<String> secondLine;

  /// The language model's explanation, when one was written.
  final String? words;

  final double bestChances;
  final double playedChances;
  final double? secondChances;

  /// Null for anything that is not a review the server could have written —
  /// said in the log, never guessed at: a half-read review would put one
  /// move's line under another.
  static PuzzleReview? fromJson(Object? json) {
    if (json == null) return null;
    try {
      final map = json as Map<String, dynamic>;
      List<String> sans(Object? raw) =>
          raw == null ? const [] : [for (final s in raw as List) s as String];
      final chances = map['chances'] as Map<String, dynamic>;
      final best = sans(map['bestLine']);
      if (best.isEmpty) throw const FormatException('no best line');
      return PuzzleReview(
        played: map['played'] as String,
        bestLine: best,
        refutationLine: sans(map['refutationLine']),
        secondLine: sans(map['secondLine']),
        words: (map['words'] as String?)?.trim().isEmpty ?? true
            ? null
            : (map['words'] as String).trim(),
        bestChances: (chances['best'] as num).toDouble(),
        playedChances: (chances['played'] as num).toDouble(),
        secondChances: (chances['second'] as num?)?.toDouble(),
      );
    } catch (e) {
      AppLogger.log('[PuzzleReview] not read: $e');
      return null;
    }
  }
}

enum RevealKind { played, best, yours }

/// One line the reveal can play on the board: from [startFen], the moves
/// [sans], the positions [fens] after each (so `fens.length == sans.length + 1`).
class RevealLine {
  RevealLine._(
      this.kind, this.title, this.caption, this.startFen, this.sans, this.fens);

  /// Replays [sans] from [fen], keeping only what plays. The server replayed
  /// the line before storing it, so a move that does not play here means the
  /// two ends disagree about a position — logged, and the line stops there
  /// rather than showing a board the move never reached.
  factory RevealLine.of(RevealKind kind, String title, String caption,
      String fen, List<String> sans) {
    final board = chess.Chess.fromFEN(fen);
    final kept = <String>[];
    final fens = <String>[fen];
    for (final san in sans) {
      if (!board.move(san)) {
        AppLogger.log('[PuzzleReveal] "$san" does not play from ${board.fen}');
        break;
      }
      kept.add(san);
      fens.add(board.fen);
    }
    return RevealLine._(kind, title, caption, fen, kept, fens);
  }

  final RevealKind kind;
  final String title;
  final String caption;
  final String startFen;
  final List<String> sans;
  final List<String> fens;

  int get length => sans.length;

  /// The move about to be played from ply [ply], as an arrow; none at the end.
  List<ChessArrow> arrowsAt(int ply) {
    if (ply < 0 || ply >= sans.length) return const [];
    final board = chess.Chess.fromFEN(fens[ply]);
    if (!board.move(sans[ply])) return const [];
    final move = board.history.last.move;
    return [
      ChessArrow(
        from: move.fromAlgebraic,
        to: move.toAlgebraic,
        colorCode: switch (kind) {
          RevealKind.played => 'R',
          RevealKind.best => 'G',
          RevealKind.yours => 'B',
        },
      ),
    ];
  }
}

/// Which lines a reveal offers, and what it says of the solver's own move.
///
/// **Never another move's line under the solver's move** (plan, phase 5): the
/// solver's move gets the engine's second line only when it *is* the second
/// line's first move; the game's move gets its own refutation; anything else
/// is told there is no line for it.
class PuzzleReveal {
  PuzzleReveal._(this.lines, this.note, this.words);

  factory PuzzleReveal.of({
    required String fen,
    required PuzzleReview review,
    required String? solverSan,
    required bool correct,
  }) {
    final best = review.bestLine.first;
    final lines = <RevealLine>[];

    if (review.played != best) {
      // Where the game's move still left the player better, its line is not
      // a refutation (Fable, F10: 10 of the owner's 33 puzzles).
      lines.add(RevealLine.of(
        RevealKind.played,
        'What was played: ${review.played}',
        review.playedChances >= 50
            ? 'How the advantage went'
            : 'Its refutation',
        fen,
        [review.played, ...review.refutationLine],
      ));
    }
    lines.add(RevealLine.of(RevealKind.best, 'What was best: $best',
        'The line behind it', fen, review.bestLine));

    String? note;
    if (solverSan != null && solverSan != best) {
      if (solverSan == review.played) {
        note = 'That was the game\'s move.';
      } else if (review.secondLine.isNotEmpty &&
          review.secondLine.first == solverSan) {
        final second = review.secondChances;
        lines.add(RevealLine.of(
          RevealKind.yours,
          'Your move: $solverSan',
          second != null && second < 50
              ? 'Holds less: the position turns against you'
              : 'Holds less than the best move',
          fen,
          review.secondLine,
        ));
      } else {
        note = correct
            ? 'Also right — no line is kept for this move.'
            : 'No line for this move.';
      }
    }
    return PuzzleReveal._(lines, note, review.words);
  }

  final List<RevealLine> lines;

  /// What is said of the solver's move when no line goes with it.
  final String? note;

  final String? words;
}
