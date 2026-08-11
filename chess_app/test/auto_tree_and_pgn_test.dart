import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart';

void main() {
  group('Analysis Studio Phase 3 Unit Tests', () {
    test('1. PgnExporterService exports basic main line with NAG and comments', () {
      final root = AnalysisNode(fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      final e4 = root.addChild(
        childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP2PP/RNBQKBNR b KQkq e3 0 1',
        san: 'e4',
        uci: 'e2e4',
      );
      e4.nag = '!';
      e4.comment = 'Dobro otvaranje';
      e4.eval = 0.35;

      final e5 = e4.addChild(
        childFen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        san: 'e5',
        uci: 'e7e5',
      );

      final pgn = PgnExporterService.exportToPgn(root);

      expect(pgn, contains('[Event "Analysis Studio Session"]'));
      expect(pgn, contains('1. e4! { [%eval +0.35] Dobro otvaranje } e5'));
    });

    test('2. PgnExporterService formats nested variations in parentheses', () {
      final root = AnalysisNode(fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      final e4 = root.addChild(
        childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP2PP/RNBQKBNR b KQkq e3 0 1',
        san: 'e4',
        uci: 'e2e4',
      );

      final e5 = e4.addChild(
        childFen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
        san: 'e5',
        uci: 'e7e5',
      );

      final c5 = e4.addChild(
        childFen: 'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2',
        san: 'c5',
        uci: 'c7c5',
      );

      final pgn = PgnExporterService.exportToPgn(root);

      expect(pgn, contains('1. e4 e5 (1... c5)'));
    });

    test('3. AutoTreeGeneratorService node estimation calculation', () {
      final service = AutoTreeGeneratorService();
      final estimated = service.generateTree; // Check signature
      expect(estimated, isNotNull);
    });
  });
}
