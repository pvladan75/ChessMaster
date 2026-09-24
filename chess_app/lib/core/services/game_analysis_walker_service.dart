import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/core/models/game_moment.dart';
import 'package:chess_app/core/services/game_review_judge.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';
import 'package:chess_app/core/services/positional_evaluator_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/review_words.dart'
    show MomentWords;
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/core/services/eval_parsing.dart';

/// Which side's mistakes a blunder alert should flag — see
/// [GameAnalysisWalkerService.markMistakes].
enum BlunderAlertSide { white, black, both }

/// Walks an already-known sequence of moves (a real game, not engine-searched
/// branches) one ply at a time: gets the engine eval at every position,
/// derives each move's swing from the mover's own perspective, and runs both
/// [TacticalMotifDetector] and [PositionalEvaluatorService] on the
/// before/after pair — read by the tutorial (`game_facts.dart`).
///
/// **`annotateNodeChain` and `tagBlunders` are gone**
/// (`docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1.2b): the whole-game review is
/// `GameReviewJudge`'s now (`game_review_runner.dart`), which marks mistakes
/// by winning chances rather than a pawn threshold, and [markMistakes] below
/// applies its verdict rather than computing one of its own.
class GameAnalysisWalkerService {
  bool _cancelled = false;

  void cancel() => _cancelled = true;

  static const int _defaultDepth = 14;

  /// Analyzes every move in [uciMoves] starting from [startingFen]. Returns
  /// one [GameMoment] per move (empty if [uciMoves] is empty or a move fails
  /// to apply). [onProgress] reports positions evaluated so far out of the
  /// total (moves.length + 1, since the starting position is evaluated too).
  Future<List<GameMoment>> analyzeGame({
    required String startingFen,
    required List<String> uciMoves,
    required PositionAnalyzer analyzer,
    int depth = _defaultDepth,
    void Function(int processed, int total)? onProgress,
  }) async {
    _cancelled = false;
    const tacticalDetector = TacticalMotifDetector();
    const positionalEvaluator = PositionalEvaluatorService();

    // Shared with the review's judge (rule 12: one home, not copied) — see
    // the note there on why a promotion needs `legalMoves` rather than the
    // package's own list.
    final walked = walkGame(startingFen: startingFen, uciMoves: uciMoves);
    final fens = walked.fens;
    final sans = walked.sans;
    final appliedUci = walked.appliedUci;

    if (appliedUci.isEmpty) return const [];

    final total = fens.length;
    final evalsRaw = <String?>[];
    final linesRaw = <AnalysisLine?>[];
    for (var i = 0; i < fens.length; i++) {
      if (_cancelled) return const [];
      String? eval;
      AnalysisLine? line;
      try {
        final lines = await analyzer(fens[i],
            depth: depth, multiPV: 1, timeout: const Duration(seconds: 12));
        line = lines.isNotEmpty ? lines.first : null;
        eval = line?.evaluation;
      } catch (_) {
        eval = null;
        line = null;
      }
      evalsRaw.add(eval);
      linesRaw.add(line);
      onProgress?.call(i + 1, total);
    }

    final moments = <GameMoment>[];
    for (var i = 0; i < appliedUci.length; i++) {
      final fenBefore = fens[i];
      final fenAfter = fens[i + 1];
      final moverColor = chess.Chess.fromFEN(fenBefore).turn;

      final beforeForMover = _evalForMover(evalsRaw[i], moverColor);
      final afterForMover = _evalForMover(evalsRaw[i + 1], moverColor);
      final swing = (beforeForMover != null && afterForMover != null)
          ? afterForMover - beforeForMover
          : null;

      final tacticalDiff = tacticalDetector.explainMove(
        beforeFen: fenBefore,
        afterFen: fenAfter,
        lastMoveUci: appliedUci[i],
      );
      final positionalDiff = positionalEvaluator.explainMove(
          beforeFen: fenBefore, afterFen: fenAfter, lastMoveUci: appliedUci[i]);

      moments.add(GameMoment(
        plyIndex: i,
        moveSan: sans[i],
        moveUci: appliedUci[i],
        fenBefore: fenBefore,
        fenAfter: fenAfter,
        moverColor: moverColor,
        engineLineBefore: linesRaw[i],
        evalBeforeRaw: evalsRaw[i],
        evalAfterRaw: evalsRaw[i + 1],
        evalBeforeForMover: beforeForMover,
        evalAfterForMover: afterForMover,
        swingForMover: swing,
        tacticalComment: tacticalDetector.describeMoveDiff(tacticalDiff),
        positionalComment: positionalEvaluator.describeMoveDiff(positionalDiff),
      ));
    }

    return moments;
  }

  /// Marks with '??' exactly the moves [result] judged mistakes
  /// ([ReviewedMove.isMistake]) played by [side] — [chain] being the nodes of
  /// those moves, in order — and, when [insertAlternativeLine] is true,
  /// inserts the move's [ReviewedMove.bestLine] (the deepest look's) as a
  /// sibling variation of at most [alternativeLinePlies] plies. Nothing else
  /// decides a mark: no threshold of its own (rule 12).
  ///
  /// The review's words (`docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 3):
  /// [words] by [ReviewedMove.ply] go on the game's move, on the „Better move"
  /// line and — when [insertRefutation] — on the engine's line after the
  /// game's move, inserted as a line of its own (the owner's choice of
  /// 25.9.2026). **A comment already there is never overwritten**; only the
  /// review's own „Better move" label is added to.
  ///
  /// Returns how many moves were marked.
  int markMistakes({
    required List<AnalysisNode> chain,
    required GameReviewResult result,
    BlunderAlertSide side = BlunderAlertSide.both,
    bool insertAlternativeLine = true,
    int alternativeLinePlies = 4,
    Map<int, MomentWords> words = const {},
    bool insertRefutation = false,
  }) {
    var tagged = 0;
    for (var i = 0; i < result.moves.length && i < chain.length; i++) {
      final move = result.moves[i];
      final said = words[move.ply];
      final node = chain[i];
      if (!move.isMistake) {
        // A move the player found: its words, and nothing else.
        if (said?.played != null && node.comment.isEmpty) {
          node.comment = said!.played!;
        }
        continue;
      }
      if (side == BlunderAlertSide.white && !move.whiteMoved) continue;
      if (side == BlunderAlertSide.black && move.whiteMoved) continue;

      node.nag = '??';
      tagged++;
      if (said?.played != null && node.comment.isEmpty) {
        node.comment = said!.played!;
      }

      if (!insertAlternativeLine) continue;
      final betterLine = move.bestLine;
      final parent = node.parent;
      if (betterLine != null &&
          parent != null &&
          betterLine.sanMoveList.isNotEmpty &&
          betterLine.bestMoveLan != move.uci) {
        _insertLine(
          parent,
          betterLine.sanMoveList,
          alternativeLinePlies,
          label: _betterLabel,
          words: said?.better,
          nag: '!',
        );
      }

      final reply = move.replyLine;
      if (insertRefutation &&
          reply != null &&
          reply.sanMoveList.isNotEmpty &&
          // The game's own continuation is the first child; a move with none
          // would take the refutation as the game's next move.
          node.children.isNotEmpty) {
        _insertLine(
          node,
          reply.sanMoveList,
          alternativeLinePlies,
          label: _refutationLabel,
          words: said?.refutation,
        );
      }
    }
    return tagged;
  }

  static const _betterLabel = 'Better move';
  static const _refutationLabel = 'Refutation';

  /// Replays up to [maxPlies] moves of [sans] onto [parent] as a new branch
  /// (or reuses an existing one with the same first move — the game's own
  /// continuation included). The first move of a new branch is tagged [nag]
  /// and labelled [label]; [words] follow the label, and go only where the
  /// comment is empty or the review's own [label].
  void _insertLine(
    AnalysisNode parent,
    List<String> sans,
    int maxPlies, {
    required String label,
    String? words,
    String? nag,
  }) {
    final plies = sans.take(maxPlies).toList();
    if (plies.isEmpty) return;

    final game = chess.Chess.fromFEN(parent.fen);
    var cur = parent;
    for (var i = 0; i < plies.length; i++) {
      final san = plies[i];
      if (!game.move(san)) break;
      final moveObj = game.history.last.move;
      final uci = moveObj.fromAlgebraic +
          moveObj.toAlgebraic +
          (moveObj.promotion?.name ?? '');
      final child = cur.addChild(childFen: game.fen, san: san, uci: uci);
      if (i == 0) {
        // The game's own continuation is never labelled as a line beside it.
        if (!identical(child, cur.children.first)) {
          if (nag != null) child.nag = nag;
          if (child.comment.isEmpty) child.comment = label;
        }
        if (words != null &&
            (child.comment.isEmpty || child.comment == label)) {
          child.comment = child.comment.isEmpty ? words : '$label. $words';
        }
      }
      cur = child;
    }
  }

  double? _evalForMover(String? whiteRelativeRaw, chess.Color moverColor) {
    final whiteRelative = parseWhiteRelativeEval(whiteRelativeRaw);
    if (whiteRelative == null) return null;
    return moverColor == chess.Color.WHITE ? whiteRelative : -whiteRelative;
  }
}
