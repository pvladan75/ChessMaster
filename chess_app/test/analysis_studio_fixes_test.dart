import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/position_info_service.dart';

void main() {
  group('Analysis Studio Fixes Tests', () {
    test('1. Verify clear board FEN parsing', () {
      const clearFen = '8/8/8/8/8/8/8/8 w - - 0 1';
      final info = PositionInfoService.analyzeFen(clearFen);

      expect(info.pieceCount, 0);
      expect(info.isEndgame, isTrue);
      expect(info.isSyzygyReady, isTrue);
    });

    test('2. Verify standard initial FEN parsing', () {
      const startFen =
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
      final info = PositionInfoService.analyzeFen(startFen);

      expect(info.pieceCount, 32);
      expect(info.isEndgame, isFalse);
    });

    test('3. Verify AnalysisNode tree root creation', () {
      final root = AnalysisNode(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      expect(root.isRoot, isTrue);
      expect(root.children, isEmpty);
    });
  });
}
