import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/position_info_service.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';

void main() {
  group('Analysis Studio Phase 2 Tests', () {
    test('1. PositionInfoService opening detection (> 7 pieces)', () {
      const e4Fen =
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
      final info = PositionInfoService.analyzeFen(e4Fen);

      expect(info.pieceCount, 32);
      expect(info.isEndgame, isFalse);
      expect(info.isSyzygyReady, isFalse);
      expect(info.openingName, contains('King\'s Pawn Opening'));
    });

    test('2. PositionInfoService endgame & Syzygy readiness (<= 7 pieces)', () {
      const endgameFen = '8/8/4k3/8/8/4K3/4P3/8 w - - 0 1'; // 3 pieces: K, k, P
      final info = PositionInfoService.analyzeFen(endgameFen);

      expect(info.pieceCount, 3);
      expect(info.isEndgame, isTrue);
      expect(info.isSyzygyReady, isTrue);
      expect(info.openingName, contains('Syzygy Tablebase Podrška Spremna'));
    });

    test('3. AnalysisNode eval storage persistence', () {
      final node = AnalysisNode(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      expect(node.eval, isNull);

      node.eval = 1.45;
      expect(node.eval, equals(1.45));
    });

    test('4. EngineArrow creation for Multi-PV ranks', () {
      final arrow1 =
          EngineArrow(from: 'e2', to: 'e4', evalText: '+0.30', rank: 1);
      final arrow2 =
          EngineArrow(from: 'd2', to: 'd4', evalText: '+0.25', rank: 2);

      expect(arrow1.rank, equals(1));
      expect(arrow1.from, equals('e2'));
      expect(arrow1.to, equals('e4'));

      expect(arrow2.rank, equals(2));
      expect(arrow2.from, equals('d2'));
      expect(arrow2.to, equals('d4'));
    });

    test('5. Custom FEN initialization and position analysis trigger', () {
      const customFen =
          'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';
      final root = AnalysisNode(fen: customFen);

      expect(root.fen, equals(customFen));
      expect(root.isRoot, isTrue);
      final info = PositionInfoService.analyzeFen(root.fen);
      expect(info.pieceCount, 32);
    });
  });
}
