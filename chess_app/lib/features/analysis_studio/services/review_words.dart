/// The words for a whole-game review — `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`,
/// §3a and phase 3.
///
/// The engine writes the facts, the model only the words. This file is the
/// app's half of that: the moments a review offers for words (the mistakes,
/// then the only moves a player found, at most [kReviewWordsMoments]), the
/// request `POST /review-words` reads — held word for word to the shared
/// fixture `docs/gates/review_words_request.json` — and the judgement of what
/// comes back. **The server checks shape; the app checks truth**: every slot
/// goes through the tutorial's one claim check, `claimsFor`, in its third
/// mode, where a move the text names must be in the moment's own lines.
///
/// No HTTP and no engine here: the review's result goes in, a request and a
/// verdict come out, so the whole of it is held by pure tests.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/answer_line.dart' show revealLine;
import 'package:chess_app/core/services/finding_sentences.dart'
    show joinSentences;
import 'package:chess_app/core/services/game_review_judge.dart';
import 'package:chess_app/core/services/legal_moves.dart' show legalMoves;
import 'package:chess_app/core/services/move_clock.dart';
import 'package:chess_app/core/services/positional_evaluator_service.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/evaluation_words.dart'
    show wordsFor;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart'
    show claimsFor;

/// At most this many moments a review — the owner's choice of 25.9.2026: the
/// mistakes first by chances lost, then the only moves found.
const int kReviewWordsMoments = 10;

enum ReviewMomentKind { mistake, found }

/// One moment offered for words.
class ReviewMoment {
  const ReviewMoment({
    required this.id,
    required this.kind,
    required this.ply,
    required this.label,
    required this.mover,
    required this.played,
    required this.best,
    required this.better,
    required this.refutation,
    required this.second,
    required this.facts,
    required this.slots,
    required this.checks,
  });

  /// `m1`, `m2`, … in the order of the game.
  final String id;
  final ReviewMomentKind kind;

  /// Index of the move among the moves reviewed ([ReviewedMove.ply]).
  final int ply;
  final String label;

  /// `White` or `Black`.
  final String mover;
  final String played;
  final String best;
  final List<String> better;
  final List<String> refutation;
  final List<String> second;
  final String? facts;

  /// Slot name (`played`, `better`, `refutation`) → the facts beside it, in
  /// the order they are offered.
  final Map<String, String> slots;

  /// Slot name → what `claimsFor` judges that slot's words against.
  final Map<String, Map<String, dynamic>> checks;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'label': label,
        'mover': mover,
        'played': played,
        'best': best,
        'lines': {
          'better': better,
          if (refutation.isNotEmpty) 'refutation': refutation,
          if (second.isNotEmpty) 'second': second,
        },
        if (facts != null) 'facts': facts,
        'slots': [
          for (final e in slots.entries)
            {'id': '$id.${e.key}', 'text': e.value},
        ],
      };
}

/// The request for one review.
class ReviewWordsRequest {
  const ReviewWordsRequest({
    required this.game,
    this.opening,
    required this.moments,
  });

  /// The moves reviewed, numbered, without headers — headers name players.
  final String game;
  final String? opening;
  final List<ReviewMoment> moments;

  Map<String, dynamic> toJson() => {
        'game': game,
        if (opening != null) 'opening': opening,
        'moments': [for (final m in moments) m.toJson()],
      };
}

/// The words a moment kept, each null where the model wrote none or the check
/// refused it.
class MomentWords {
  const MomentWords({this.played, this.better, this.refutation});

  final String? played;
  final String? better;
  final String? refutation;

  bool get isEmpty => played == null && better == null && refutation == null;
}

/// What came back, judged.
class ReviewWordsVerdict {
  const ReviewWordsVerdict({required this.byPly, required this.refused});

  /// [ReviewedMove.ply] → the words its moment kept.
  final Map<int, MomentWords> byPly;

  /// Every reason a slot was refused, as `claimsFor` says it.
  final List<String> refused;

  int get accepted => byPly.values.fold(
        0,
        (n, w) =>
            n +
            (w.played != null ? 1 : 0) +
            (w.better != null ? 1 : 0) +
            (w.refutation != null ? 1 : 0),
      );
}

/// A puzzle's explanation from its moment's words: for a mistake, what the
/// answer achieves and then what the game's move allowed; for a move found,
/// why it was the only one. Null when the moment kept no words.
String? puzzleWordsOf(MomentWords? words, ReviewMomentKind kind) {
  if (words == null) return null;
  final parts = kind == ReviewMomentKind.mistake
      ? [words.better, words.played]
      : [words.played];
  final said = [
    for (final p in parts)
      if (p != null) p
  ];
  return said.isEmpty ? null : said.join(' ');
}

/// The request for [result]'s words, or null when no moment qualifies.
///
/// [mistakePlies] are the mistakes that may be offered, in any order — ranked
/// here by chances lost; [foundPlies] the only moves found, in the order they
/// are preferred. Both are capped together at [kReviewWordsMoments], the
/// mistakes first. [clocks] is every move's clock from the game's start and
/// [clockOffset] the index of the first reviewed move in it
/// (`ReviewedGame.clocks`, `pathUci.length`).
ReviewWordsRequest? reviewWordsRequest({
  required GameReviewResult result,
  required Iterable<int> mistakePlies,
  required Iterable<int> foundPlies,
  List<double?> clocks = const [],
  int clockOffset = 0,
  String? timeControl,
  String? opening,
}) {
  if (result.moves.isEmpty) return null;
  final byPly = {for (final m in result.moves) m.ply: m};

  final mistakes = [
    for (final p in mistakePlies.toSet())
      if (byPly[p] != null && byPly[p]!.bestLine != null) byPly[p]!,
  ]..sort((a, b) {
      final lost = (b.judgement?.lostChances ?? 0)
          .compareTo(a.judgement?.lostChances ?? 0);
      return lost != 0 ? lost : a.ply.compareTo(b.ply);
    });
  final taken = <int>{for (final m in mistakes) m.ply};
  final found = [
    for (final p in foundPlies)
      if (byPly[p] != null && byPly[p]!.bestLine != null && taken.add(p))
        byPly[p]!,
  ];

  final chosen = <(ReviewedMove, ReviewMomentKind)>[
    for (final m in mistakes) (m, ReviewMomentKind.mistake),
    for (final m in found) (m, ReviewMomentKind.found),
  ].take(kReviewWordsMoments).toList()
    ..sort((a, b) => a.$1.ply.compareTo(b.$1.ply));

  final control = TimeControl.parse(timeControl);
  final moments = <ReviewMoment>[];
  for (final (move, kind) in chosen) {
    final moment = _moment(
      move,
      kind,
      id: 'm${moments.length + 1}',
      clock: clockWords(
        move.whiteMoved ? 'White' : 'Black',
        clocks,
        clockOffset + move.ply,
        control,
      ),
    );
    if (moment != null) moments.add(moment);
  }
  if (moments.isEmpty) return null;
  return ReviewWordsRequest(
    game: movetextOf(result.moves),
    opening: opening,
    moments: moments,
  );
}

/// The words in [slots] (`m1.played` → text) judged against [request]: a slot
/// is kept only when `claimsFor` finds nothing in it.
ReviewWordsVerdict judgeReviewWords(
  ReviewWordsRequest request,
  Map<String, String> slots,
) {
  final byPly = <int, MomentWords>{};
  final refused = <String>[];
  for (final m in request.moments) {
    String? kept(String name) {
      final sid = '${m.id}.$name';
      final text = slots[sid];
      final facts = m.checks[name];
      if (text == null || facts == null) return null;
      final claims = claimsFor(sid, text, facts);
      if (claims.isEmpty) return text;
      refused.addAll(claims);
      return null;
    }

    final words = MomentWords(
      played: kept('played'),
      better: kept('better'),
      refutation: kept('refutation'),
    );
    if (!words.isEmpty) byPly[m.ply] = words;
  }
  return ReviewWordsVerdict(byPly: byPly, refused: refused);
}

/// The reviewed moves as numbered movetext: `1. e4 e5 2. Nf3`, or `5... Nf6`
/// when the review starts on Black's move.
String movetextOf(List<ReviewedMove> moves) {
  final out = <String>[];
  for (var i = 0; i < moves.length; i++) {
    final m = moves[i];
    final number = _fullmove(m.fenBefore);
    if (m.whiteMoved) {
      out.add('$number. ${m.san}');
    } else if (i == 0) {
      out.add('$number... ${m.san}');
    } else {
      out.add(m.san);
    }
  }
  return out.join(' ');
}

// --- One moment -------------------------------------------------------------

ReviewMoment? _moment(
  ReviewedMove m,
  ReviewMomentKind kind, {
  required String id,
  String? clock,
}) {
  final bestLine = m.bestLine!;
  final better = _cut(m.fenBefore, bestLine.sanMoveList);
  if (better == null || better.isEmpty) return null;
  final second = m.secondLine == null
      ? const <String>[]
      : (_cut(m.fenBefore, m.secondLine!.sanMoveList) ?? const <String>[]);
  final reply = m.replyLine;
  final refutation = kind == ReviewMomentKind.mistake && reply != null
      ? (_cut(m.fenAfter, reply.sanMoveList) ?? const <String>[])
      : const <String>[];

  final mover = m.whiteMoved ? 'White' : 'Black';
  final opponent = m.whiteMoved ? 'Black' : 'White';
  final bestWords = _evalWords(bestLine.evaluation);
  final afterWords = reply == null ? null : _evalWords(reply.evaluation);
  final secondWords =
      m.secondLine == null ? null : _evalWords(m.secondLine!.evaluation);
  final bestMates = _mates(bestLine.evaluation, m.whiteMoved);
  final replyMates = reply != null && _mates(reply.evaluation, !m.whiteMoved);

  final allMoves = [m.san, ...better, ...refutation, ...second];
  final playedMotif = _motif(m.fenBefore, m.san);

  final String? facts;
  final slots = <String, String>{};
  final checks = <String, Map<String, dynamic>>{};

  if (kind == ReviewMomentKind.mistake) {
    facts = _sentence([
      if (bestWords != null && afterWords != null)
        'With the best move, ${better.first}, ${_it(bestWords)}; after '
            '${m.san}, ${_it(afterWords)}.'
      else if (bestWords != null)
        'With the best move, ${better.first}, ${_it(bestWords)}.',
      if (clock != null) _capital(clock),
    ]);
    final refutationGain = _gain(m.fenAfter, refutation, opponent);
    slots['played'] = _sentence([
      'The game\'s move, ${m.san}.',
      if (afterWords != null) 'After it, ${_it(afterWords)}.',
      if (refutationGain > 0)
        'It lets $opponent win ${_material(refutationGain)}.',
      if (playedMotif != null) 'On the board after it: $playedMotif',
    ])!;
    final betterGain = _gain(m.fenBefore, better, mover);
    final betterMotif = _motif(m.fenBefore, better.first);
    slots['better'] = _sentence([
      'The better line: ${better.join(' ')}.',
      if (bestWords != null) 'With it, ${_it(bestWords)}.',
      if (betterGain > 0) 'It wins ${_material(betterGain)} for $mover.',
      if (betterMotif != null)
        'On the board after ${better.first}: $betterMotif',
    ])!;
    checks['played'] = _check(
      facts,
      slots['played']!,
      [if (playedMotif != null) playedMotif],
      gain: refutationGain,
      mate: replyMates,
      lines: allMoves,
    );
    checks['better'] = _check(
      facts,
      slots['better']!,
      [if (betterMotif != null) betterMotif],
      gain: betterGain,
      mate: bestMates,
      lines: allMoves,
    );
    if (refutation.isNotEmpty) {
      final afterPlayed = _after(m.fenBefore, m.san);
      final refutationMotif =
          afterPlayed == null ? null : _motif(afterPlayed, refutation.first);
      slots['refutation'] = _sentence([
        'After ${m.san}, the refutation: ${refutation.join(' ')}.',
        if (refutationGain > 0)
          'It wins ${_material(refutationGain)} for $opponent.',
        if (refutationMotif != null)
          'On the board after ${refutation.first}: $refutationMotif',
      ])!;
      checks['refutation'] = _check(
        facts,
        slots['refutation']!,
        [if (refutationMotif != null) refutationMotif],
        gain: refutationGain,
        mate: replyMates,
        lines: allMoves,
      );
    }
  } else {
    facts = _sentence([
      if (bestWords != null && secondWords != null && second.isNotEmpty)
        'Only ${m.san} held: with it, ${_it(bestWords)}; with the next best, '
            '${second.first}, ${_it(secondWords)}.'
      else if (bestWords != null)
        'Only ${m.san} held: with it, ${_it(bestWords)}.',
      if (clock != null) _capital(clock),
    ]);
    slots['played'] = _sentence([
      'The only move that held, ${m.san}, and the game found it.',
      if (playedMotif != null) 'On the board after it: $playedMotif',
    ])!;
    checks['played'] = _check(
      facts,
      slots['played']!,
      [if (playedMotif != null) playedMotif],
      gain: _gain(m.fenBefore, better, mover),
      mate: bestMates,
      lines: allMoves,
    );
  }

  return ReviewMoment(
    id: id,
    kind: kind,
    ply: m.ply,
    label: m.whiteMoved
        ? '${_fullmove(m.fenBefore)}. ${m.san}'
        : '${_fullmove(m.fenBefore)}...${m.san}',
    mover: mover,
    played: m.san,
    best: better.first,
    better: better,
    refutation: refutation,
    second: second,
    facts: facts,
    slots: slots,
    checks: checks,
  );
}

Map<String, dynamic> _check(
  String? facts,
  String slot,
  List<String> motifs, {
  required int gain,
  required bool mate,
  required List<String> lines,
}) =>
    {
      'text': '${facts ?? ''} $slot',
      'motifs': motifs.join(' '),
      'gain': gain,
      'mate': mate,
      'lines': lines,
    };

// --- Words ------------------------------------------------------------------

/// An engine evaluation (`+0.39`, `M3`, `-M2`) as `evaluation_words.dart`
/// speaks it; null when it is not one.
String? _evalWords(String evaluation) {
  final raw = evaluation.trim();
  final mate = RegExp(r'^(-)?M(\d+)$').firstMatch(raw);
  try {
    if (mate != null) {
      return wordsFor('#${mate.group(1) ?? ''}${mate.group(2)}');
    }
    return wordsFor(raw);
  } on FormatException {
    return null;
  }
}

/// „about even" reads as a clause only with a subject.
String _it(String words) => switch (words) {
      'about even' || 'a draw' || 'checkmate' || 'unknown' => 'it is $words',
      _ => words,
    };

String _capital(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

String? _sentence(List<String> parts) {
  final said = [
    for (final p in parts)
      if (p.trim().isNotEmpty) p.trim()
  ];
  return said.isEmpty ? null : said.join(' ');
}

bool _mates(String evaluation, bool whiteToMove) {
  final m = RegExp(r'^(-)?M(\d+)$').firstMatch(evaluation.trim());
  if (m == null) return false;
  return (m.group(1) == null) == whiteToMove;
}

String _material(int points) => switch (points) {
      1 => 'a pawn',
      2 => 'two pawns',
      3 => 'a piece\'s worth of material',
      5 => 'a rook\'s worth of material',
      9 => 'a queen\'s worth of material',
      _ => '$points points of material',
    };

const _values = {'p': 1, 'n': 3, 'b': 3, 'r': 5, 'q': 9};

int _balance(String fen, String side) {
  var white = 0;
  var black = 0;
  for (final ch in fen.split(' ').first.split('')) {
    final v = _values[ch.toLowerCase()];
    if (v == null) continue;
    if (ch == ch.toUpperCase()) {
      white += v;
    } else {
      black += v;
    }
  }
  return side == 'White' ? white - black : black - white;
}

/// Material [side] gains over [line] from [fen]; never below zero.
int _gain(String fen, List<String> line, String side) {
  if (line.isEmpty) return 0;
  final board = chess.Chess.fromFEN(fen);
  for (final san in line) {
    if (!board.move(san)) return 0;
  }
  final gained = _balance(board.fen, side) - _balance(fen, side);
  return gained > 0 ? gained : 0;
}

/// The detectors' sentence for the position after [san] from [fen], as the
/// tutorial sends it (`motifs_after_played`); null when they say nothing.
String? _motif(String fen, String san) {
  final uci = _uciOf(fen, san);
  final after = _after(fen, san);
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

String? _after(String fen, String san) {
  final board = chess.Chess.fromFEN(fen);
  return board.move(san) ? board.fen : null;
}

String? _uciOf(String fen, String san) {
  for (final move in legalMoves(chess.Chess.fromFEN(fen))) {
    if (move['san'] == san) {
      return '${move['from']}${move['to']}${move['promotion'] ?? ''}';
    }
  }
  return null;
}

/// [revealLine], and null when a move of [line] does not play from [fen] —
/// a line that does not replay is never offered.
List<String>? _cut(String fen, List<String> line) {
  try {
    final cut = revealLine(fen, line);
    final board = chess.Chess.fromFEN(fen);
    for (final san in cut) {
      if (!board.move(san)) return null;
    }
    return cut;
  } catch (_) {
    return null;
  }
}

String _fullmove(String fen) {
  final fields = fen.trim().split(RegExp(r'\s+'));
  return fields.length > 5 ? fields[5] : '1';
}
