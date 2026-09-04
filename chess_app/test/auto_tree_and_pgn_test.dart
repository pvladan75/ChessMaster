import 'package:flutter_test/flutter_test.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart';
import 'package:chess_app/models/analysis_models.dart';

/// Deterministic stand-in for the engine.
///
/// Returns the first legal moves of whatever position it is handed, so the
/// generator's branching, pruning and cancellation logic can be tested without
/// a real Stockfish process or a network call.
class _FakeEngine {
  final List<String> evaluations;
  final void Function(int callCount)? onCall;
  int callCount = 0;

  _FakeEngine({this.evaluations = const ['+0.30', '+0.20'], this.onCall});

  Future<List<AnalysisLine>> analyze(
    String fen, {
    required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    callCount++;
    onCall?.call(callCount);

    final game = chess.Chess.fromFEN(fen);
    final legal = game.generate_moves();

    final lines = <AnalysisLine>[];
    for (var i = 0; i < multiPV && i < legal.length; i++) {
      final move = legal[i];
      final uci = move.fromAlgebraic + move.toAlgebraic;
      lines.add(AnalysisLine.fromPv(
        multipv: i + 1,
        depth: depth,
        eval: i < evaluations.length ? evaluations[i] : '+0.10',
        pvString: uci,
        startingFen: fen,
      ));
    }
    return lines;
  }
}

void main() {
  group('Analysis Studio Phase 3 Unit Tests', () {
    test('1. PgnExporterService exports basic main line with NAG and comments',
        () {
      final root = AnalysisNode(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      final e4 = root.addChild(
        childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP2PP/RNBQKBNR b KQkq e3 0 1',
        san: 'e4',
        uci: 'e2e4',
      );
      e4.nag = '!';
      e4.comment = 'Dobro otvaranje';

      final e5 = e4.addChild(
        childFen:
            'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        san: 'e5',
        uci: 'e7e5',
      );

      final pgn = PgnExporterService.exportToPgn(root);

      expect(pgn, contains('[Event "Analysis Studio Session"]'));
      // No `[%eval …]`: a node stopped carrying the engine's number on
      // 4.9.2026, so an export carries the reader's comment and the NAG.
      expect(pgn, contains('1. e4! { Dobro otvaranje } e5'));
      expect(pgn, isNot(contains('%eval')));
    });

    test('2. PgnExporterService formats nested variations in parentheses', () {
      final root = AnalysisNode(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      final e4 = root.addChild(
        childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP2PP/RNBQKBNR b KQkq e3 0 1',
        san: 'e4',
        uci: 'e2e4',
      );

      final e5 = e4.addChild(
        childFen:
            'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        san: 'e5',
        uci: 'e7e5',
      );

      final c5 = e4.addChild(
        childFen:
            'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2',
        san: 'c5',
        uci: 'c7c5',
      );

      final pgn = PgnExporterService.exportToPgn(root);

      expect(pgn, contains('1. e4 e5 (1... c5)'));
    });

    test('3. AutoTreeGeneratorService node estimation calculation', () {
      final service = AutoTreeGeneratorService();
      final estimated = service.calculateEstimatedNodes(4, 2);
      // Level 1: 2, Level 2: 4, Level 3: 8, Level 4: 16 -> Sum = 30
      expect(estimated, equals(30));
    });

    test('3b. Analyzed-position count matches what progress actually reports',
        () async {
      final service = AutoTreeGeneratorService();

      // Root plus each ply below the last: 1 + 2 + 4 + 8 = 15 engine calls.
      expect(service.calculateAnalyzedPositions(4, 2), equals(15));
      expect(service.calculateAnalyzedPositions(1, 3), equals(1));
      expect(service.calculateAnalyzedPositions(3, 3), equals(13));

      // The estimate must match the real number of engine calls, otherwise the
      // progress bar cannot reach 100%.
      final engine = _FakeEngine();
      int? reportedTotal;
      await service.generateTree(
        startNode: AnalysisNode(
            fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1'),
        params: AutoAnalysisParams(
          pliesDepth: 3,
          candidateCount: 2,
          engineDepth: 10,
          deltaCutoff: 5.0,
        ),
        analyzer: engine.analyze,
        onProgress: (processed, total, _) => reportedTotal = total,
      );

      expect(
          engine.callCount, equals(service.calculateAnalyzedPositions(3, 2)));
      expect(reportedTotal, equals(engine.callCount));
    });

    test(
        '4. AutoTreeGeneratorService generates candidate branches synchronously',
        () async {
      final service = AutoTreeGeneratorService();
      final root = AnalysisNode(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      final engine = _FakeEngine();

      final params = AutoAnalysisParams(
        pliesDepth: 2,
        candidateCount: 2,
        engineDepth: 10,
        deltaCutoff: 2.0,
      );

      await service.generateTree(
        startNode: root,
        params: params,
        analyzer: engine.analyze,
      );

      // Two candidates at ply 1, each expanded into two more at ply 2.
      expect(root.children.length, 2);
      expect(root.children.first.moveSan, isNotNull);
      for (final child in root.children) {
        expect(child.children.length, 2,
            reason: 'each ply-1 node expands once more');
      }
      expect(engine.callCount, 3,
          reason: 'root plus two ply-1 nodes are analyzed');
    });

    test(
        '5. AutoTreeGeneratorService prunes candidates beyond the delta cutoff',
        () async {
      final service = AutoTreeGeneratorService();
      final root = AnalysisNode(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      // Second candidate is 3 pawns worse than the best, beyond a 1.0 cutoff.
      final engine = _FakeEngine(evaluations: ['+0.30', '-2.70']);

      await service.generateTree(
        startNode: root,
        params: AutoAnalysisParams(
          pliesDepth: 1,
          candidateCount: 2,
          engineDepth: 10,
          deltaCutoff: 1.0,
        ),
        analyzer: engine.analyze,
      );

      expect(root.children.length, 1, reason: 'the losing candidate is pruned');
    });

    test('6. AutoTreeGeneratorService cancel stops recursion', () async {
      final service = AutoTreeGeneratorService();
      final root = AnalysisNode(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      // Cancels as soon as the engine is consulted the first time.
      final engine = _FakeEngine(onCall: (count) {
        if (count == 1) service.cancel();
      });

      await service.generateTree(
        startNode: root,
        params: AutoAnalysisParams(
          pliesDepth: 4,
          candidateCount: 2,
          engineDepth: 10,
          deltaCutoff: 5.0,
        ),
        analyzer: engine.analyze,
      );

      expect(engine.callCount, 1, reason: 'recursion stops after the cancel');
      expect(root.children, isEmpty);
    });
  });
}
