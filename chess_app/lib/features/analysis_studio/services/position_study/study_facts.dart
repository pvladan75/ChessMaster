/// The facts of a position study — `docs/PLAN-STUDIJA-POZICIJE.md`, §1–2.
///
/// A position goes in; the main line, the side lines worth showing and
/// everything that may be said about them come out. **No words are written
/// here and no screen is known**: the engine and the tablebase are injected,
/// so the whole of it runs in a test or a headless tool.
///
/// **Every judgement is `mistake_rule.dart`'s** — winning chances, the
/// mistake threshold, the only move — and every search passes
/// `searchProblem` before it counts: a search stopped by its timeout is not a
/// fact, and the study says how many it lost.
library;

import 'package:chess/chess.dart' as chess;

import 'package:chess_app/core/services/answer_line.dart' show answerLineLength;
import 'package:chess_app/core/services/game_review_judge.dart'
    show TablebaseLookup, invertOutcome, tablebaseOutcomeOf;
import 'package:chess_app/core/services/mistake_rule.dart';
import 'package:chess_app/core/services/move_motif.dart';
import 'package:chess_app/core/services/positional_evaluator_service.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/features/analysis_studio/services/position_study/study_board.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart'
    show SyzygyResult;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/game_facts.dart'
    show searchProblem;
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/fen_legality.dart' show fenIllegalReason;

/// The main line is at least this long and at most that.
const int kStudyMinPlies = 4;
const int kStudyMaxPlies = 8;

/// A move that loses fewer chances than this is a real choice beside the
/// best; one that loses this many or more is worth explaining as worse.
const double kStudyCloseChoice = 5;

const int kStudyAlternatives = 2;
const int kStudyAlternativePlies = 4;

/// How many tempting moves are searched, and how many shown.
const int kStudyTemptingSearched = 3;
const int kStudyTemptingShown = 2;

/// Lines asked for at the start, and at every later node of the main line.
const int kStudyStartLines = 3;
const int kStudyNodeLines = 2;

/// After how many main-line moves a capture the engine does not play is
/// still asked about.
const int kStudyTrapPlies = 3;

/// The most searches a study can ask for — what its progress is counted
/// against: the start, the threat, three tempting moves with a greedy line
/// each, seven further nodes, three traps and the piece each one's
/// punishment may give up, the idea.
const int kStudySearchBudget = 1 + 1 + 3 * 3 + 7 + 3 * 2 + 1;

/// A position no study can be made of: not chess, or a game already over.
class StudyRefused implements Exception {
  const StudyRefused(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

/// Thrown out of [PositionStudyBuilder.build] when its caller cancelled.
class StudyCancelled implements Exception {
  const StudyCancelled();
}

/// One line the engine gave at the start.
class StudyCandidate {
  const StudyCandidate({
    required this.line,
    required this.evaluation,
    required this.chances,
    required this.lost,
  });

  /// The candidate move and what follows it, cut for showing.
  final List<StudyMove> line;

  /// From White's side, in the app's spelling (`+0.35`, `M3`).
  final String evaluation;

  /// For the side to move at the start.
  final double chances;

  /// Against the best line; zero for the best itself.
  final double lost;

  StudyMove get move => line.first;
}

/// What the tablebase knows of a position of seven men or fewer.
class StudyTablebase {
  const StudyTablebase({
    required this.outcome,
    required this.keeping,
    required this.spoiling,
  });

  /// For the side to move.
  final TablebaseOutcome outcome;

  /// The moves that keep [outcome], best first, as `(uci, san)`.
  final List<({String uci, String san})> keeping;

  /// The moves that make it worse.
  final List<({String uci, String san})> spoiling;

  /// „a win for White", „a draw" — for [side] to move.
  String words(String side) => switch (outcome) {
        TablebaseOutcome.win => 'a win for $side',
        TablebaseOutcome.draw => 'a draw',
        TablebaseOutcome.loss => 'a win for ${otherSide(side)}',
      };
}

/// What the other side would do if the side to move passed.
class StudyThreat {
  const StudyThreat({
    required this.line,
    required this.evaluation,
    required this.cost,
    required this.won,
    required this.wonWords,
    required this.mates,
    required this.motif,
  });

  /// From the position with the other side to move; the first is the threat.
  final List<StudyMove> line;
  final String evaluation;

  /// The chances the side to move would lose by letting it happen.
  final double cost;
  final int won;
  final String? wonWords;
  final bool mates;
  final String? motif;

  StudyMove get move => line.first;
}

/// What the first move of the main line prepares: the mover's best move if
/// it could move again.
class StudyIdea {
  const StudyIdea({
    required this.move,
    required this.inMainLine,
    required this.threatens,
    required this.won,
    required this.wonWords,
    required this.mates,
    required this.stoppedBy,
  });

  final StudyMove move;

  /// The main line goes on to play it.
  final bool inMainLine;

  /// Left alone it would win material or mate, at a cost of at least
  /// [kMistakeLoss] to the other side.
  final bool threatens;
  final int won;
  final String? wonWords;
  final bool mates;

  /// The reply in the main line, when [threatens] and the main line never
  /// plays the idea: the move that met it.
  final String? stoppedBy;
}

/// A capture that wins material and loses evaluation — the owner's
/// definition, 28.9.2026.
class StudyTrap {
  const StudyTrap({
    required this.move,
    required this.punishment,
    required this.declined,
    required this.recapture,
    required this.evaluation,
    required this.lost,
    required this.won,
    required this.wonWords,
    required this.mates,
    required this.motif,
  });

  /// The capture.
  final StudyMove move;

  /// What follows it, the punishing move first. When that move gives a
  /// piece up, the line takes it — see [declined].
  final List<StudyMove> punishment;

  /// The engine's own continuation after the punishing move, when it
  /// declines a piece that [punishment] takes; empty otherwise. It starts
  /// from the position after the punishing move.
  final List<StudyMove> declined;

  /// The capture takes back what was just taken: it wins nothing, it only
  /// looks automatic.
  final bool recapture;
  final String evaluation;

  /// The chances the capture loses against the best move there.
  final double lost;

  /// What the punisher has won by the end of [punishment].
  final int won;
  final String? wonWords;
  final bool mates;

  /// The detectors' sentence for the punishing move.
  final String? motif;
}

/// One move of the main line.
class StudyStep {
  const StudyStep({
    required this.move,
    required this.evaluation,
    required this.onlyMove,
    required this.forced,
    required this.trivial,
    required this.second,
    required this.secondEvaluation,
    required this.motif,
    required this.tablebase,
    required this.trap,
  });

  final StudyMove move;

  /// The engine's value of the line from the position before the move.
  final String evaluation;

  /// The next best loses at least [kStandsOut], or the tablebase keeps the
  /// result with this move alone.
  final bool onlyMove;

  /// The only legal move.
  final bool forced;

  /// A move that needs no finding (`isTrivialFind`): a recapture, a way out
  /// of check, one of three legal moves or fewer.
  final bool trivial;
  final String? second;
  final String? secondEvaluation;
  final String? motif;

  /// Of the position before the move.
  final StudyTablebase? tablebase;

  /// A capture in the position before the move that the engine does not
  /// play, and why.
  final StudyTrap? trap;
}

/// A move a reader would look at, and why it is not the move.
class StudyTempting {
  const StudyTempting({
    required this.natural,
    required this.evaluation,
    required this.lost,
    required this.defence,
    required this.won,
    required this.wonWords,
    required this.mates,
    required this.motif,
    required this.greedy,
  });

  final NaturalMove natural;

  /// After the move, with the best play for both.
  final String evaluation;
  final double lost;

  /// What follows the move with the best play for both, the reply first.
  final List<StudyMove> defence;

  /// What the other side has won by the end of [defence].
  final int won;
  final String? wonWords;
  final bool mates;

  /// The detectors' sentence for the reply.
  final String? motif;

  /// The capture the move was made for, played after the reply, and what
  /// punishes it; null when it is not there, or is not a mistake.
  final StudyTrap? greedy;

  StudyMove get move => natural.move;

  /// `?` from a mistake, `?!` from a move merely worse, none for a move that
  /// is shown only for the trap behind it.
  String? get nag => lost >= kMistakeLoss
      ? '?'
      : lost >= kStudyCloseChoice
          ? '?!'
          : null;
}

/// What is known of one move that was played — „Generate AI comment".
class StudyMoveFacts {
  const StudyMoveFacts({
    required this.move,
    required this.best,
    required this.bestLine,
    required this.bestEvaluation,
    required this.evaluation,
    required this.lost,
    required this.follows,
    required this.declined,
    required this.onlyMove,
    required this.motif,
    required this.idea,
    required this.tablebase,
    required this.searches,
  });

  /// The move the comment is about.
  final StudyMove move;

  /// The engine's move in the position it was played in — [move] itself
  /// when the move is the best.
  final StudyMove best;

  /// The engine's line from that position, [best] first.
  final List<StudyMove> bestLine;
  final String bestEvaluation;

  /// After [move], with the best play for both.
  final String evaluation;

  /// The chances [move] loses against [best]; zero when it is the best.
  final double lost;

  /// What follows [move], the reply first — told as a player would meet it
  /// (a piece offered is taken), with the engine's own line in [declined].
  final List<StudyMove> follows;
  final List<StudyMove> declined;
  final bool onlyMove;
  final String? motif;

  /// What [move] prepares, asked only when it is the best move.
  final StudyIdea? idea;

  /// Of the position the move was played in.
  final StudyTablebase? tablebase;
  final int searches;

  bool get isBest => move.uci == best.uci;
}

/// Everything a study knows.
class PositionStudy {
  const PositionStudy({
    required this.fen,
    required this.depth,
    required this.evaluation,
    required this.candidates,
    required this.tablebase,
    required this.material,
    required this.tactical,
    required this.positional,
    required this.squares,
    required this.threat,
    required this.idea,
    required this.mainLine,
    required this.alternatives,
    required this.tempting,
    required this.outcomeFen,
    required this.outcomeEvaluation,
    required this.outcomeTablebase,
    required this.searches,
    required this.problems,
  });

  final String fen;
  final int depth;
  final String evaluation;
  final List<StudyCandidate> candidates;
  final StudyTablebase? tablebase;

  /// „Material is level." — of the start.
  final String material;

  /// The detectors' sentences about the start, the weightiest first.
  final List<String> tactical;
  final List<String> positional;

  /// The squares those sentences are about.
  final List<String> squares;
  final StudyThreat? threat;
  final StudyIdea? idea;
  final List<StudyStep> mainLine;
  final List<StudyCandidate> alternatives;
  final List<StudyTempting> tempting;

  /// Where the main line ends, and what the engine and the tablebase make
  /// of it.
  final String outcomeFen;
  final String outcomeEvaluation;
  final StudyTablebase? outcomeTablebase;

  /// Searches asked for, and why some did not count.
  final int searches;
  final List<String> problems;

  String get side => sideToMoveIn(fen);
}

typedef StudyProgress = void Function(int searched, int budget, String what);

class PositionStudyBuilder {
  PositionStudyBuilder({
    required this.analyzer,
    required this.depth,
    this.tablebase,
    this.timeout = const Duration(seconds: 90),
    this.isCancelled,
  });

  final PositionAnalyzer analyzer;
  final int depth;

  /// Asked only with [kTablebaseMen] or fewer; null asks nothing.
  final TablebaseLookup? tablebase;
  final Duration timeout;
  final bool Function()? isCancelled;

  int _searches = 0;
  final _problems = <String>[];
  StudyProgress? _onProgress;

  /// The position and nothing under it: what stands on the board, the
  /// threat, and the engine's own line as it came — two searches, for the
  /// comment a reader asks for about one position. No move of the line is
  /// searched again, so nothing here says a move is the only one.
  Future<PositionStudy> buildOverview(String fen,
      {StudyProgress? onProgress}) async {
    _searches = 0;
    _problems.clear();
    _onProgress = onProgress;

    final illegal = fenIllegalReason(fen);
    if (illegal != null) throw StudyRefused(illegal);
    if (chess.Chess.fromFEN(fen).game_over) {
      throw const StudyRefused('The game is over in this position.');
    }
    final white = whiteToMoveIn(fen);
    final side = sideToMoveIn(fen);
    final rootLines =
        await _search(fen, kStudyStartLines, 'Reading the position');
    if (rootLines == null) {
      throw StudyRefused('The engine did not answer for this position: '
          '${_problems.isEmpty ? 'no lines' : _problems.last}.');
    }
    final tb = await _tablebaseAt(fen);
    final bestChances = _chances(rootLines.first.evaluation, white);
    final threat = await _threat(fen, bestChances);

    var sans = rootLines.first.sanMoveList;
    if (tb != null && _decisive(tb)) {
      sans = await _tablebaseLine(fen, tb, 6);
    } else if (tb != null &&
        tb.keeping.isNotEmpty &&
        !tb.keeping.any((k) => k.uci == rootLines.first.bestMoveLan)) {
      sans = [tb.keeping.first.san];
    }
    final line = _cut(fen, side, sans, shortest: kStudyMinPlies, longest: 6);
    if (line == null) {
      throw const StudyRefused(
          'The engine gave no move that plays from this position.');
    }
    final start = _findings(fen);
    final outcomeFen = line.last.fenAfter;
    return PositionStudy(
      fen: fen,
      depth: depth,
      evaluation: rootLines.first.evaluation,
      candidates: const [],
      tablebase: tb,
      material: materialWords(fen),
      tactical: start.tactical,
      positional: start.positional,
      squares: start.squares,
      threat: threat,
      idea: null,
      mainLine: [
        for (final move in line)
          StudyStep(
            move: move,
            evaluation: rootLines.first.evaluation,
            onlyMove: false,
            forced: false,
            trivial: true,
            second: null,
            secondEvaluation: null,
            motif: null,
            tablebase: null,
            trap: null,
          ),
      ],
      alternatives: const [],
      tempting: const [],
      outcomeFen: outcomeFen,
      outcomeEvaluation: rootLines.first.evaluation,
      outcomeTablebase: null,
      searches: _searches,
      problems: List.unmodifiable(_problems),
    );
  }

  /// One move that was played: how it stands against the engine's own, what
  /// follows it, and what it is for — three searches at the most.
  Future<StudyMoveFacts> moveFacts(String fen, String uci,
      {StudyProgress? onProgress}) async {
    _searches = 0;
    _problems.clear();
    _onProgress = onProgress;

    final illegal = fenIllegalReason(fen);
    if (illegal != null) throw StudyRefused(illegal);
    final move = playUci(fen, uci);
    if (move == null) {
      throw const StudyRefused('This move does not play from its position.');
    }
    final white = whiteToMoveIn(fen);
    final lines = await _search(fen, kStudyNodeLines, 'The position before');
    if (lines == null) {
      throw StudyRefused('The engine did not answer for this position: '
          '${_problems.isEmpty ? 'no lines' : _problems.last}.');
    }
    final tb = await _tablebaseAt(fen);
    final top = lines.first;
    final best = playUci(fen, top.bestMoveLan) ?? move;
    final bestLine = _cut(fen, move.mover, top.sanMoveList,
            shortest: kStudyAlternativePlies, longest: kStudyMaxPlies) ??
        [best];
    final bestChances = _chances(top.evaluation, white);

    if (best.uci == move.uci) {
      final second = lines.length > 1 ? lines[1] : null;
      final only = !isTrivialFind(fen, move.uci) &&
          second != null &&
          bestChances - _chances(second.evaluation, white) >= kStandsOut;
      final steps = [
        for (final m in bestLine)
          StudyStep(
            move: m,
            evaluation: top.evaluation,
            onlyMove: false,
            forced: false,
            trivial: true,
            second: null,
            secondEvaluation: null,
            motif: null,
            tablebase: null,
            trap: null,
          ),
      ];
      return StudyMoveFacts(
        move: move,
        best: best,
        bestLine: bestLine,
        bestEvaluation: top.evaluation,
        evaluation: top.evaluation,
        lost: 0,
        follows: bestLine.skip(1).toList(),
        declined: const [],
        onlyMove: only,
        motif: studyMotif(fen, move.san),
        idea: await _idea(steps, bestChances, white),
        tablebase: tb,
        searches: _searches,
      );
    }

    var evaluation = top.evaluation;
    var follows = const <StudyMove>[];
    var declined = const <StudyMove>[];
    if (!chess.Chess.fromFEN(move.fenAfter).game_over) {
      final after = await _search(move.fenAfter, 1, 'After ${move.san}');
      if (after == null) {
        throw StudyRefused('The engine did not answer after ${move.san}: '
            '${_problems.isEmpty ? 'no lines' : _problems.last}.');
      }
      evaluation = after.first.evaluation;
      final told = await _told(
          move.fenAfter, otherSide(move.mover), after.first.sanMoveList);
      follows = told?.line ?? const [];
      declined = told?.declined ?? const [];
    }
    return StudyMoveFacts(
      move: move,
      best: best,
      bestLine: bestLine,
      bestEvaluation: top.evaluation,
      evaluation: evaluation,
      lost: _atLeastZero(bestChances - _chances(evaluation, white)),
      follows: follows,
      declined: declined,
      onlyMove: false,
      motif: studyMotif(fen, move.san),
      idea: null,
      tablebase: tb,
      searches: _searches,
    );
  }

  Future<PositionStudy> build(String fen, {StudyProgress? onProgress}) async {
    _searches = 0;
    _problems.clear();
    _onProgress = onProgress;

    final illegal = fenIllegalReason(fen);
    if (illegal != null) throw StudyRefused(illegal);
    final board = chess.Chess.fromFEN(fen);
    if (board.game_over) {
      throw const StudyRefused('The game is over in this position.');
    }

    final white = whiteToMoveIn(fen);
    final side = sideToMoveIn(fen);
    double chancesOf(String evaluation) => _chances(evaluation, white);

    final rootLines =
        await _search(fen, kStudyStartLines, 'Reading the position');
    if (rootLines == null) {
      throw StudyRefused('The engine did not answer for this position: '
          '${_problems.isEmpty ? 'no lines' : _problems.last}.');
    }
    final rootTablebase = await _tablebaseAt(fen);
    final bestChances = chancesOf(rootLines.first.evaluation);
    final decided = rootTablebase == null && isDecided(bestChances);

    final candidates = <StudyCandidate>[
      for (final line in rootLines)
        if (_cut(fen, side, line.sanMoveList,
                shortest: kStudyAlternativePlies, longest: kStudyMaxPlies)
            case final cut?)
          StudyCandidate(
            line: cut,
            evaluation: line.evaluation,
            chances: chancesOf(line.evaluation),
            lost: _atLeastZero(bestChances - chancesOf(line.evaluation)),
          ),
    ];

    final threat = await _threat(fen, bestChances);
    final mainLine = await _mainLine(fen, rootLines, rootTablebase);
    if (mainLine.isEmpty) {
      throw const StudyRefused(
          'The engine gave no move that plays from this position.');
    }
    final idea = await _idea(mainLine, bestChances, white);

    final first = mainLine.first.move.uci;
    final keepers = rootTablebase?.keeping.map((k) => k.uci).toSet();
    // With the result known and no move changing it, no move is a choice.
    final settled = rootTablebase != null &&
        (rootTablebase.outcome == TablebaseOutcome.loss ||
            rootTablebase.spoiling.isEmpty);
    final alternatives = decided || settled
        ? const <StudyCandidate>[]
        : [
            for (final c in candidates)
              if (c.move.uci != first &&
                  c.lost < kStudyCloseChoice &&
                  (keepers == null || keepers.contains(c.move.uci)))
                c,
          ].take(kStudyAlternatives).toList();

    final tempting = decided || rootTablebase != null
        ? const <StudyTempting>[]
        : await _tempting(
            fen,
            bestChances,
            shown: {first, for (final a in alternatives) a.move.uci},
          );

    final outcomeFen = mainLine.last.move.fenAfter;
    final start = _findings(fen);
    return PositionStudy(
      fen: fen,
      depth: depth,
      evaluation: rootLines.first.evaluation,
      candidates: candidates,
      tablebase: rootTablebase,
      material: materialWords(fen),
      tactical: start.tactical,
      positional: start.positional,
      squares: start.squares,
      threat: threat,
      idea: idea,
      mainLine: mainLine,
      alternatives: alternatives,
      tempting: tempting,
      outcomeFen: outcomeFen,
      outcomeEvaluation: mainLine.last.evaluation,
      outcomeTablebase: await _tablebaseAt(outcomeFen),
      searches: _searches,
      problems: List.unmodifiable(_problems),
    );
  }

  // --- The engine ------------------------------------------------------------

  /// [lines] lines for [fen], or null — and a problem written down — when the
  /// search did not come back whole.
  Future<List<AnalysisLine>?> _search(
      String fen, int lines, String what) async {
    if (isCancelled?.call() ?? false) throw const StudyCancelled();
    _onProgress?.call(_searches, kStudySearchBudget, what);
    _searches++;
    final List<AnalysisLine> answer;
    try {
      answer =
          await analyzer(fen, depth: depth, multiPV: lines, timeout: timeout);
    } catch (e) {
      _problems.add('$what: the engine failed ($e)');
      return null;
    }
    if (isCancelled?.call() ?? false) throw const StudyCancelled();
    final sorted = [...answer]..sort((a, b) => a.multipv.compareTo(b.multipv));
    final problem = searchProblem(fen, sorted, depth: depth, multiPv: lines);
    if (problem != null) {
      _problems.add('$what: $problem');
      return null;
    }
    if (sorted.isEmpty || sorted.first.sanMoveList.isEmpty) {
      _problems.add('$what: a line with no move');
      return null;
    }
    return sorted;
  }

  Future<StudyTablebase?> _tablebaseAt(String fen) async {
    final lookup = tablebase;
    if (lookup == null || menIn(fen) > kTablebaseMen) return null;
    if (chess.Chess.fromFEN(fen).game_over) return null;
    final SyzygyResult? result;
    try {
      result = await lookup(fen);
    } catch (_) {
      return null;
    }
    if (result == null) return null;
    final outcome = tablebaseOutcomeOf(result.category);
    if (outcome == null) return null;
    final keeping = <({String uci, String san})>[];
    final spoiling = <({String uci, String san})>[];
    for (final m in result.moves) {
      final after = tablebaseOutcomeOf(m.category);
      if (after == null) continue;
      (invertOutcome(after) == outcome ? keeping : spoiling)
          .add((uci: m.uci, san: m.san));
    }
    return StudyTablebase(
        outcome: outcome, keeping: keeping, spoiling: spoiling);
  }

  /// Whether the tablebase knows a win or a loss here, where its first move
  /// is the best one; in a draw it is only one of many.
  static bool _decisive(StudyTablebase tb) =>
      tb.outcome != TablebaseOutcome.draw;

  /// The tablebase's own line from [fen]: at every position the first move
  /// it lists that keeps the result, for [plies] or as long as it answers.
  Future<List<String>> _tablebaseLine(
      String fen, StudyTablebase root, int plies) async {
    final sans = <String>[];
    var at = fen;
    StudyTablebase? tb = root;
    while (sans.length < plies && tb != null && tb.keeping.isNotEmpty) {
      final move = playUci(at, tb.keeping.first.uci);
      if (move == null) break;
      sans.add(move.san);
      at = move.fenAfter;
      tb = await _tablebaseAt(at);
    }
    return sans;
  }

  // --- The threat --------------------------------------------------------------

  Future<StudyThreat?> _threat(String fen, double bestChances) async {
    final passed = passedFen(fen);
    if (passed == null) return null;
    final lines = await _search(passed, 1, 'Looking for a threat');
    if (lines == null) return null;
    final line = lines.first;
    final white = whiteToMoveIn(fen);
    final other = otherSide(sideToMoveIn(fen));
    final cost = bestChances - _chances(line.evaluation, white);
    final cut = _cut(passed, other, line.sanMoveList, shortest: 3, longest: 7);
    if (cut == null) return null;
    final won = wonBetween(passed, cut.last.fenAfter, other);
    final mates = _matesFor(line.evaluation, white: !white);
    // The cost alone is not a threat — a side that can win a pawn back now
    // loses by passing, and nothing threatens it (the owner's position of
    // 28.9.2026) — and neither is a quiet move with a pawn somewhere behind
    // it: a threat mates, wins a piece, or takes or checks at once.
    final first = cut.first;
    final concrete = mates ||
        won.points >= kNaturalAttackValue ||
        (won.points > 0 && (first.capture || first.check));
    if (cost < kMistakeLoss || !concrete) return null;
    return StudyThreat(
      line: cut,
      evaluation: line.evaluation,
      cost: cost,
      won: won.points,
      wonWords: won.words,
      mates: mates,
      motif: studyMotif(passed, cut.first.san),
    );
  }

  // --- The main line -----------------------------------------------------------

  Future<List<StudyStep>> _mainLine(
    String fen,
    List<AnalysisLine> rootLines,
    StudyTablebase? rootTablebase,
  ) async {
    final side = sideToMoveIn(fen);
    final steps = <StudyStep>[];
    var at = fen;
    List<AnalysisLine>? lines = rootLines;
    var tb = rootTablebase;
    StudyMove? previous;

    for (var ply = 0; ply < kStudyMaxPlies; ply++) {
      if (ply > 0) {
        if (chess.Chess.fromFEN(at).game_over) break;
        lines =
            await _search(at, kStudyNodeLines, 'Main line, move ${ply + 1}');
        if (lines == null) break;
        tb = await _tablebaseAt(at);
      }
      final white = whiteToMoveIn(at);
      final best = lines!.first;
      var move =
          playUci(at, best.bestMoveLan) ?? playSan(at, best.sanMoveList.first);
      var fromEngine = true;
      if (tb != null &&
          tb.keeping.isNotEmpty &&
          (_decisive(tb)
              ? tb.keeping.first.uci != move?.uci
              : !tb.keeping.any((k) => k.uci == move?.uci))) {
        // The tablebase knows the result, and the move is its own: the first
        // it lists that keeps the result, which is the shortest road to mate
        // for the winner and the longest for the loser. Until 30.9.2026 the
        // engine's move stood whenever it kept the result, and a move can
        // keep a win and go nowhere: the owner's rook ending came back as
        // Kf3 Rb7 Kg3 Rg7+ Kf3, a repetition. In a draw every drawing move
        // is as good as the next, so there the engine's move stands unless
        // it gives the draw away.
        move = playUci(at, tb.keeping.first.uci);
        fromEngine = false;
      }
      if (move == null) break;

      final legal = chess.Chess.fromFEN(at).moves().length;
      final second = lines.length > 1 && fromEngine ? lines[1] : null;
      // A recapture, a way out of check, one of three legal moves: a move
      // that needs no finding is not an only move worth a mark.
      final trivial = isTrivialFind(at, move.uci, previousUci: previous?.uci) ||
          (move.capture &&
              move.taken >= kNaturalAttackValue &&
              soundCaptures(at).any((c) => c.uci == move!.uci));
      final bool only;
      if (tb != null) {
        only = legal > 1 &&
            tb.keeping.length == 1 &&
            tb.outcome != TablebaseOutcome.loss;
      } else {
        only = !trivial &&
            second != null &&
            _chances(best.evaluation, white) -
                    _chances(second.evaluation, white) >=
                kStandsOut;
      }

      final trap = ply >= 1 && ply <= kStudyTrapPlies && tb == null
          ? await _trap(at, move, _chances(best.evaluation, white),
              previous: previous)
          : null;

      steps.add(StudyStep(
        move: move,
        evaluation: best.evaluation,
        onlyMove: only,
        forced: legal == 1,
        trivial: trivial,
        second: second?.sanMoveList.first,
        secondEvaluation: second?.evaluation,
        motif: studyMotif(at, move.san),
        tablebase: tb,
        trap: trap,
      ));
      at = move.fenAfter;
      previous = move;

      if (steps.length < kStudyMinPlies) continue;
      // An exact line is not in the middle of anything the engine's rule for
      // stopping can see: it runs its full length, as far as it can show.
      if (tb != null && _decisive(tb)) continue;
      final next = fromEngine && best.sanMoveList.length > 1
          ? playSan(at, best.sanMoveList[1])
          : null;
      final loud = move.capture ||
          move.check ||
          (next != null && (next.capture || next.check));
      // The side the study is for is behind where it started: the line is
      // in the middle of something and says nothing yet.
      final down = wonBetween(fen, at, otherSide(side)).points > 0 &&
          !isDecided(_chances(best.evaluation, whiteToMoveIn(fen)));
      if (!loud && !down) break;
    }
    return steps;
  }

  /// The most valuable capture of a piece or more in [fen] that is not
  /// [played], when it loses at least [kMistakeLoss] — a trap. A capture of
  /// the piece that has just moved ([previous]) is shown whatever it loses:
  /// the engine has declined what was offered, and the reader asks why.
  Future<StudyTrap?> _trap(
    String fen,
    StudyMove played,
    double bestChances, {
    required StudyMove? previous,
  }) async {
    final captures = soundCaptures(fen)
        .where((c) => c.taken >= kNaturalAttackValue && c.uci != played.uci)
        .toList()
      ..sort((a, b) => b.taken.compareTo(a.taken));
    if (captures.isEmpty) return null;
    final capture = captures.first;
    return _punished(
      capture,
      bestChances,
      'Why not ${capture.san}',
      always: previous != null && capture.to == previous.to,
      recapture:
          previous != null && previous.capture && capture.to == previous.to,
    );
  }

  /// [capture] as a trap: what punishes it, when it loses at least
  /// [kMistakeLoss] against [bestChances], the chances of the side that
  /// plays it with the best move instead — or whatever it loses, with
  /// [always].
  ///
  /// **The punishing move is followed the way a player would meet it.** When
  /// it gives a piece up and the engine's line declines it, the line shown
  /// takes the piece — that is where the point of the move is — and the
  /// engine's own defence stands beside it, short. The engine alone shows
  /// 9. Rxa7 Nxc6; what a reader has to see is 9. Rxa7 Rxa7 10. c7.
  Future<StudyTrap?> _punished(
    StudyMove capture,
    double bestChances,
    String what, {
    bool always = false,
    bool recapture = false,
  }) async {
    if (capture.mate) return null;
    if (chess.Chess.fromFEN(capture.fenAfter).game_over) return null;
    final lines = await _search(capture.fenAfter, 1, what);
    if (lines == null) return null;
    final line = lines.first;
    final lost = bestChances - _chances(line.evaluation, capture.whiteMoved);
    if (!always && lost < kMistakeLoss) return null;
    final punisher = otherSide(capture.mover);
    final told = await _told(capture.fenAfter, punisher, line.sanMoveList);
    if (told == null) return null;
    final won =
        wonBetween(capture.fenBefore, told.line.last.fenAfter, punisher);
    return StudyTrap(
      move: capture,
      punishment: told.line,
      declined: told.declined,
      recapture: recapture,
      evaluation: line.evaluation,
      lost: _atLeastZero(lost),
      won: won.points,
      wonWords: won.words,
      mates: _matesFor(line.evaluation, white: !capture.whiteMoved),
      motif: studyMotif(capture.fenAfter, told.line.first.san),
    );
  }

  /// The engine's line [sans] from [fen], told for [hero], whose move is
  /// first: cut as every line is — and, when that first move puts a piece
  /// where it can be taken and the line does not take it, with the piece
  /// taken and what follows, the engine's own continuation kept as
  /// `declined`.
  Future<({List<StudyMove> line, List<StudyMove> declined})?> _told(
      String fen, String hero, List<String> sans) async {
    final plain = _cut(fen, hero, sans, shortest: 3, longest: 9);
    if (plain == null) return null;
    final first = plain.first;
    final taking = soundCaptures(first.fenAfter)
        .where((c) => c.to == first.to)
        .firstOrNull;
    final offered = taking != null && taking.taken >= kNaturalAttackValue;
    final declines =
        sans.length > 1 && playSan(first.fenAfter, sans[1])?.uci != taking?.uci;
    const asItCame = <StudyMove>[];
    if (!offered || !declines) return (line: plain, declined: asItCame);

    final more = await _search(taking.fenAfter, 1, 'Taking with ${taking.san}');
    if (more == null) return (line: plain, declined: asItCame);
    // Cut from where the line began, not from where the piece was taken:
    // the hero is a piece down from the first, and the line must run until
    // it has that back — the pawn queening is the point of 9. Rxa7.
    final whole = _cut(
      fen,
      hero,
      [first.san, taking.san, ...more.first.sanMoveList],
      shortest: 3,
      longest: 11,
    );
    if (whole == null || whole.length < 2) {
      return (line: plain, declined: asItCame);
    }
    return (line: whole, declined: plain.skip(1).take(3).toList());
  }

  // --- The idea ----------------------------------------------------------------

  Future<StudyIdea?> _idea(
      List<StudyStep> mainLine, double bestChances, bool white) async {
    final first = mainLine.first.move;
    if (first.check || first.mate) return null;
    final passed = passedFen(first.fenAfter);
    if (passed == null) return null;
    final lines = await _search(passed, 1, 'What ${first.san} prepares');
    if (lines == null) return null;
    final line = lines.first;
    final move = playUci(passed, line.bestMoveLan);
    if (move == null) return null;

    final mover = first.mover;
    final cut = _cut(passed, mover, line.sanMoveList, shortest: 1, longest: 5);
    final won = cut == null
        ? (points: 0, words: null)
        : wonBetween(passed, cut.last.fenAfter, mover);
    final mates = _matesFor(line.evaluation, white: white);
    final gain = _chances(line.evaluation, white) - bestChances;
    final threatens = gain >= kMistakeLoss && (won.points > 0 || mates);
    final inMainLine = [
      for (var i = 2; i < mainLine.length; i += 2) mainLine[i].move.uci
    ].contains(move.uci);
    if (!threatens && !inMainLine) return null;
    return StudyIdea(
      move: move,
      inMainLine: inMainLine,
      threatens: threatens,
      won: threatens ? won.points : 0,
      wonWords: threatens ? won.words : null,
      mates: threatens && mates,
      stoppedBy: threatens && !inMainLine && mainLine.length > 1
          ? mainLine[1].move.san
          : null,
    );
  }

  // --- The tempting moves ------------------------------------------------------

  Future<List<StudyTempting>> _tempting(
    String fen,
    double bestChances, {
    required Set<String> shown,
  }) async {
    final white = whiteToMoveIn(fen);
    final other = otherSide(sideToMoveIn(fen));
    final out = <StudyTempting>[];
    final naturals = naturalMoves(fen)
        .where((n) => !shown.contains(n.move.uci))
        .take(kStudyTemptingSearched);

    for (final natural in naturals) {
      if (out.length >= kStudyTemptingShown) break;
      final move = natural.move;
      if (chess.Chess.fromFEN(move.fenAfter).game_over) continue;

      // Two replies, not one: a trap stands behind a reply, and of two
      // replies as good as each other the engine's first is an accident of
      // depth. At depth 20 it met 7...Be4 with 8.f3, at 22 with 8.dxc6.
      final replies = await _search(move.fenAfter, 2, 'Trying ${move.san}');
      if (replies == null) continue;
      final evaluation = replies.first.evaluation;
      final lost = _atLeastZero(bestChances - _chances(evaluation, white));
      final replyChances = _chances(evaluation, !white);

      List<StudyMove>? defence;
      StudyTrap? greedy;
      for (final reply in replies) {
        final close = replyChances - _chances(reply.evaluation, !white) <
            kStudyCloseChoice;
        if (!close) continue;
        final line = _cut(move.fenAfter, other, reply.sanMoveList,
            shortest: 3, longest: 9);
        if (line == null) continue;
        defence ??= line;
        final trap = await _greedy(
          natural,
          line,
          _chances(reply.evaluation, white),
        );
        if (trap != null) {
          defence = line;
          greedy = trap;
          break;
        }
      }
      if (defence == null) continue;
      if (lost < kStudyCloseChoice && greedy == null) continue;

      final won = wonBetween(fen, defence.last.fenAfter, other);
      out.add(StudyTempting(
        natural: natural,
        evaluation: evaluation,
        lost: lost,
        defence: defence,
        won: won.points,
        wonWords: won.words,
        mates: _matesFor(evaluation, white: !white),
        motif: studyMotif(move.fenAfter, defence.first.san),
        greedy: greedy,
      ));
    }
    return out;
  }

  /// The capture [natural] was made for, played after the reply, when it is
  /// still there, is not the best defence itself, and is a mistake.
  Future<StudyTrap?> _greedy(
    NaturalMove natural,
    List<StudyMove> defence,
    double chancesWithDefence,
  ) async {
    final aim = natural.aim;
    if (aim == null || defence.isEmpty) return null;
    final reply = defence.first;
    final capture = playUci(reply.fenAfter, aim.uci);
    if (capture == null || !capture.capture) return null;
    if (defence.length > 1 && defence[1].uci == capture.uci) return null;
    return _punished(
      capture,
      chancesWithDefence,
      'Taking with ${capture.san}',
    );
  }

  // --- What stands on the board ------------------------------------------------

  ({List<String> tactical, List<String> positional, List<String> squares})
      _findings(String fen) {
    final tactical = [
      ...const TacticalMotifDetector().detect(fen: fen).findings
    ]..sort((a, b) => b.significance.compareTo(a.significance));
    final positional = [
      ...const PositionalEvaluatorService().evaluate(fen: fen).findings
    ]..sort((a, b) => b.significance.compareTo(a.significance));
    final saidTactical = tactical.take(3).toList();
    final weighty = positional.where((f) => f.significance >= 3).toList();
    // One sentence a kind: three isolated pawns are one fact about the
    // structure, and a model handed three sentences writes three.
    final kinds = <String>{};
    final saidPositional = [
      for (final f in weighty.isNotEmpty ? weighty : positional.take(1))
        if (kinds.add(f.factors.map((k) => k.name).join('+'))) f,
    ].take(3).toList();
    final squares = <String>{
      for (final f in saidTactical) ...f.affectedSquares,
      for (final f in saidPositional) ...f.affectedSquares,
    };
    return (
      tactical: [for (final f in saidTactical) f.description],
      positional: [for (final f in saidPositional) f.description],
      squares: squares.take(6).toList(),
    );
  }
}

/// `moveMotifSentence`, without the pairs that cancel each other: the
/// detectors compare two positions from the mover's side and from the other,
/// and a change both report — „White's pawns hold more of the centre" beside
/// „White's pawns no longer hold more of the centre" — is no change. Both
/// sentences go.
String? studyMotif(String fen, String san) {
  final whole = moveMotifSentence(fen, san);
  if (whole == null) return null;
  final sentences = whole
      .split(RegExp(r'(?<=\.)\s+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  String bare(String s) => s
      .replaceAll(RegExp(r'\b(no longer |is no longer |are no longer )'), '')
      .replaceAll(RegExp(r'\b(is|are) '), '')
      .toLowerCase();
  final gone = {
    for (final s in sentences)
      if (s.contains('no longer')) bare(s)
  };
  final kept = [
    for (final s in sentences)
      if (!gone.contains(bare(s))) s
  ];
  // Three at the most: the detectors write the weightiest first, and a
  // model handed six sentences about a move repeats six.
  return kept.isEmpty ? null : kept.take(3).join(' ');
}

// --- Small things --------------------------------------------------------------

double _atLeastZero(double v) => v < 0 ? 0 : v;

/// The winning chances [evaluation] (from White's side) gives White or Black.
double _chances(String evaluation, bool forWhite) => winningChances(
    EngineValue.fromEvaluation(evaluation, whiteToMove: forWhite));

/// Whether [evaluation] is a forced mate by White ([white]) or by Black.
bool _matesFor(String evaluation, {required bool white}) {
  final m = RegExp(r'^(-)?M(\d+)$').firstMatch(evaluation.trim());
  if (m == null) return false;
  return (m.group(1) == null) == white;
}

/// [sans] from [fen] as moves, cut so that it never ends while [mover] is
/// down material; null when nothing of it plays.
List<StudyMove>? _cut(
  String fen,
  String mover,
  List<String> sans, {
  required int shortest,
  required int longest,
}) {
  final played = playLine(fen, sans);
  if (played.isEmpty) return null;
  final int length;
  try {
    length = answerLineLength(
      fen,
      mover,
      [for (final m in played) m.san],
      shortest: shortest,
      longest: longest,
    );
  } on StateError {
    return null;
  }
  return length == 0 ? null : played.sublist(0, length);
}
