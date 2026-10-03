/// One judged move of a play-it-out drill.
///
/// What the drill says about it is the screen's: a `SpokenLine` per sentence
/// of the table in `docs/PLAN-GOVOR-IZ-KLIPOVA.md` (phase 4b), drawn and
/// played from the same tokens. This file holds only what the server said.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/speech/move_words.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/core/speech/vocabulary.dart';

class DrillStep {
  const DrillStep({
    required this.held,
    required this.goal,
    required this.outcome,
    required this.playedSan,
    required this.fen,
    this.closer,
    this.replySan,
    this.playedUci,
    this.replyUci,
    this.finished,
  });

  /// Whether the move kept the result the position started with.
  final bool held;

  /// What there was to hold: 'win' or 'draw'.
  final String goal;

  /// What is there now: 'win', 'draw' or 'loss'.
  final String outcome;

  final String playedSan;

  /// The position after the opponent's reply, or after the move when the drill
  /// ended there.
  final String fen;

  /// Nearer to converting than before. Null when the question does not apply —
  /// in a drawn position there is nothing to get nearer to.
  final bool? closer;

  final String? replySan;

  /// The move judged and the reply, as the server played them — kept for the
  /// tree `Open in Analysis` builds, which replays UCI so an underpromotion
  /// stays the piece it was (docs/PLAN-TRENER-ZAVRSNICA.md, phases 4–5).
  final String? playedUci;
  final String? replyUci;

  /// 'mate', 'stalemate', 'insufficient', 'repetition', 'fifty_moves', or null
  /// while it runs. 'draw_rule' is the older name for the last two together and
  /// is still accepted, so an old server does not go unread.
  final String? finished;

  /// True once the drill cannot continue, whichever way it went.
  bool get isOver => !held || finished != null;

  factory DrillStep.fromJson(Map<String, dynamic> json) => DrillStep(
        held: json['held'] == true,
        goal: json['goal']?.toString() ?? 'win',
        outcome: json['outcome']?.toString() ?? 'draw',
        playedSan: json['playedSan']?.toString() ?? '',
        fen: json['fen']?.toString() ?? '',
        closer: json['closer'] is bool ? json['closer'] as bool : null,
        replySan: (json['reply'] as Map<String, dynamic>?)?['san']?.toString(),
        playedUci: json['playedUci']?.toString(),
        replyUci: (json['reply'] as Map<String, dynamic>?)?['uci']?.toString(),
        finished: json['finished']?.toString(),
      );
}

/// How many more moves a claimed draw has to be held for.
///
/// A position can be drawn and still have something to get wrong, and then no
/// rule about material can honestly close it. What can be asked instead is a
/// demonstration: keep it for this many more moves and the exercise is over.
/// It is not a claim that the position is dead - it is a claim that the reader
/// can hold it, which is what the drill was teaching.
///
/// Eight of the reader's own moves — the opponent's replies are not counted,
/// so a claim runs sixteen half-moves. Long enough that a defence about to
/// collapse collapses inside it, short enough not to be the shuffling it
/// replaces. (Until 1.10.2026 this said „four moves each", which the code
/// never counted; docs/PLAN-TRENER-ZAVRSNICA.md, D13.)
const holdOutMoves = 8;

/// What the drill says after one judged move: the lines, whether they are
/// good news, and a note that is only drawn.
class DrillVerdict {
  const DrillVerdict({required this.lines, required this.good, this.note});

  final List<SpokenLine> lines;
  final bool good;

  /// Drawn under the lines and never said — only where the table has no way
  /// to say it.
  final String? note;
}

/// The facts of a move given in coordinates, read off the position it was
/// played in. Null when it is not legal there.
MoveFacts? _factsOfUci(String fen, String uci) {
  if (uci.length < 4) return null;
  try {
    return MoveWords.factsOf(fen, uci.substring(0, 2), uci.substring(2, 4),
        promotion: uci.length > 4 ? uci[4].toLowerCase() : null);
  } catch (_) {
    return null;
  }
}

/// The position after [uci] is played in [fen], or null when it cannot be.
String? _fenAfter(String fen, String uci) {
  if (uci.length < 4) return null;
  try {
    final board = chess.Chess.fromFEN(fen);
    final played = board.move({
      'from': uci.substring(0, 2),
      'to': uci.substring(2, 4),
      'promotion': uci.length > 4 ? uci[4].toLowerCase() : 'q',
    });
    return played == false ? null : board.fen;
  } catch (_) {
    return null;
  }
}

/// What the drill says after one judged move — the table of
/// `docs/PLAN-GOVOR-IZ-KLIPOVA.md`, phase 4b. A move is said as a move, never
/// as its notation; what the table has no row for is not said. [uci] is the
/// move the reader played in [fenBefore]; [holdLeft] is the claimed draw's
/// count after this move, or null when no claim stands.
///
/// Never a number of moves to the end. DTZ counts half-moves to the next
/// capture or pawn move rather than moves to mate, and after a conversion it
/// starts again, so „eighteen moves to go" would be wrong twice over. What is
/// true, and what a reader can act on, is whether the result held — and, in a
/// claimed draw, how many of the reader's own moves are left to hold.
DrillVerdict drillVerdict(
  DrillStep step, {
  required String fenBefore,
  required String uci,
  required bool claimed,
  required int? holdLeft,
}) {
  DrillVerdict one(SpeechToken t, {required bool good}) => DrillVerdict(
        lines: [
          SpokenLine([t])
        ],
        good: good,
      );
  if (claimed) return one(SpeechVocabulary.drawHeldCompleted, good: true);
  final draw = step.goal == 'draw';
  final facts = _factsOfUci(fenBefore, step.playedUci ?? uci);

  // The move the drill ends on, and what it cost.
  DrillVerdict ending(SpeechToken tail) {
    if (facts == null) {
      // The server judged a move this client cannot read: say so on the
      // screen rather than say nothing.
      return DrillVerdict(
        lines: const [],
        good: false,
        note: '${step.playedSan} did not hold.',
      );
    }
    return DrillVerdict(
      lines: [
        SpokenLine([...MoveWords.bare(facts), tail])
      ],
      good: false,
    );
  }

  if (!step.held) {
    // A win that is let go does not always land on a draw, and saying so when
    // it does not is a false statement about the position, not a rounding.
    return ending(draw
        ? SpeechVocabulary.losesDrawDrillStops
        : (step.outcome == 'loss'
            ? SpeechVocabulary.letsWinGoLost
            : SpeechVocabulary.letsWinGoDraw));
  }
  final finished = step.finished;
  if (finished == 'mate') {
    return one(SpeechVocabulary.checkmateCompleted, good: true);
  }
  if (finished != null) {
    // A draw by rule: held, when the draw was the task; when the win was the
    // task, the win is what went — running the moves out is not a success.
    return draw
        ? one(SpeechVocabulary.drawHeldCompleted, good: true)
        : ending(SpeechVocabulary.letsWinGoDraw);
  }

  final left = holdLeft;
  final lines = <SpokenLine>[
    SpokenLine([
      SpeechVocabulary.goodKeepGoing,
      if (draw && left != null && left > 0) ...[
        SpeechVocabulary.movesLeftToHold,
        SpeechVocabulary.number(left.clamp(0, 99)),
      ],
    ]),
  ];
  // The opponent's reply, said as a move from the position it was played in.
  final reply = step.replyUci;
  final afterMine =
      reply == null ? null : _fenAfter(fenBefore, step.playedUci ?? uci);
  final replyFacts =
      reply == null || afterMine == null ? null : _factsOfUci(afterMine, reply);
  if (replyFacts != null) lines.add(MoveWords.line(replyFacts));
  return DrillVerdict(lines: lines, good: true);
}
