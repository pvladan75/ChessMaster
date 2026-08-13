import 'package:chess_app/core/models/game_moment.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/core/services/tactical_motif_detector.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart' show PositionAnalyzer;

/// One blunder-derived exercise: the position right after the mistake (the
/// side to move there is the puzzle solver), tagged with why it's winnable.
class LocalPuzzle {
  final String id;
  final String fen;
  final String themeLabel;
  final String? themeKey;
  final double swing;
  final String sourceMoveSan;
  final int sourcePlyIndex;

  const LocalPuzzle({
    required this.id,
    required this.fen,
    required this.themeLabel,
    required this.themeKey,
    required this.swing,
    required this.sourceMoveSan,
    required this.sourcePlyIndex,
  });

  /// Shape consumed by the rest of the app's puzzle-solving flow (see
  /// `LocalPuzzleService` / `PuzzleApiService`): 'winning_position' puzzles
  /// there are already solved by live engine verification of the player's
  /// moves rather than a precomputed solution tree, which is exactly what a
  /// freshly-extracted blunder needs — no solution tree to build.
  Map<String, dynamic> toPuzzleMap() {
    return {
      'id': id,
      'puzzle_id': id,
      'fen': fen,
      'type': 'winning_position',
      'solutions': const {},
      'isLocal': true,
      'theme': themeKey,
      'themeLabel': themeLabel,
      'sourceMoveSan': sourceMoveSan,
    };
  }
}

/// Turns a played game into a set of tactical exercises: walks the game
/// looking for moves that gave up a large amount of eval (a blunder), and
/// for each one packages the position right after it as a puzzle — the
/// opponent, now to move, has a genuine tactical shot that
/// [TacticalMotifDetector] can name (fork, pin, hanging piece, ...).
///
/// Reuses [GameAnalysisWalkerService] for the actual engine walk, so this
/// class is just the "which moments are worth turning into puzzles, and how
/// do we label them" layer on top.
class LocalPuzzleExtractorService {
  final GameAnalysisWalkerService _walker = GameAnalysisWalkerService();
  static const TacticalMotifDetector _tacticalDetector = TacticalMotifDetector();

  void cancel() => _walker.cancel();

  /// [blunderThreshold] is in pawn units — the default (2.0) roughly matches
  /// "the kind of mistake a human opponent could realistically punish",
  /// not just engine noise between two roughly-equal moves.
  Future<List<LocalPuzzle>> extractPuzzles({
    required String startingFen,
    required List<String> uciMoves,
    required PositionAnalyzer analyzer,
    double blunderThreshold = 2.0,
    int maxPuzzles = 5,
    int depth = 14,
    void Function(int processed, int total)? onProgress,
  }) async {
    final moments = await _walker.analyzeGame(
      startingFen: startingFen,
      uciMoves: uciMoves,
      analyzer: analyzer,
      depth: depth,
      onProgress: onProgress,
    );

    final blunders = moments.where((m) => m.isBlunderBeyond(blunderThreshold)).toList()
      // Worst blunders (most negative swing) first.
      ..sort((a, b) => a.swingForMover!.compareTo(b.swingForMover!));

    final puzzles = <LocalPuzzle>[];
    for (final moment in blunders.take(maxPuzzles)) {
      puzzles.add(_buildPuzzle(moment));
    }
    return puzzles;
  }

  LocalPuzzle _buildPuzzle(GameMoment moment) {
    // `detect()` on the post-blunder position treats whoever just moved (the
    // blunderer) as "mover" — so a favorsMover=false finding is the thing
    // that now favors the opponent, i.e. the puzzle solver's winning idea.
    final result = _tacticalDetector.detect(fen: moment.fenAfter, lastMoveUci: moment.moveUci);
    final solverFindings = result.findings.where((f) => !f.favorsMover).toList()
      ..sort((a, b) => b.significance.compareTo(a.significance));

    final best = solverFindings.isNotEmpty ? solverFindings.first : null;

    return LocalPuzzle(
      id: 'local_${moment.plyIndex}_${DateTime.now().microsecondsSinceEpoch}',
      fen: moment.fenAfter,
      themeLabel: best?.description ?? 'Protivnik je napravio grešku — pronađi najbolji nastavak',
      themeKey: best?.motifs.isNotEmpty == true ? best!.motifs.first.name : null,
      swing: moment.swingForMover ?? 0,
      sourceMoveSan: moment.moveSan,
      sourcePlyIndex: moment.plyIndex,
    );
  }
}
