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

    test('3. AnalysisNode no longer carries an engine evaluation', () {
      // Removed 4.9.2026. A node used to store the engine's number, written by
      // two paths that encoded a mate differently, and drawn on the card by a
      // decoder that only understood one of them. What the reader wants kept
      // about a position goes in `comment`, which they type.
      final node = AnalysisNode(
          fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');

      expect(node.toJson().containsKey('eval'), isFalse);
      expect(node.toJson().containsKey('evalDepth'), isFalse);
      // And an old saved tree that still has one simply loses it on the way in,
      // rather than failing to open.
      final old = AnalysisNode.fromJson({
        'fen': node.fen,
        'eval': 998.0,
        'evalDepth': 30,
        'children': const [],
      });
      expect(old.fen, node.fen);
      expect(old.toJson().containsKey('eval'), isFalse);
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
