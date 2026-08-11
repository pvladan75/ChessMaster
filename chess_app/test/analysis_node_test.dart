import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';

void main() {
  group('AnalysisNode Unit Tests', () {
    test('1. Root node initialization', () {
      final root = AnalysisNode(fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      expect(root.isRoot, isTrue);
      expect(root.isMainLine, isTrue);
      expect(root.children, isEmpty);
      expect(root.moveSan, isNull);
    });

    test('2. Add child nodes and check main line', () {
      final root = AnalysisNode(fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      
      final e4 = root.addChild(
        childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP2PP/RNBQKBNR b KQkq e3 0 1',
        san: 'e4',
        uci: 'e2e4',
      );

      final d4 = root.addChild(
        childFen: 'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1',
        san: 'd4',
        uci: 'd2d4',
      );

      expect(root.children.length, 2);
      expect(e4.isMainLine, isTrue);
      expect(d4.isMainLine, isFalse);
    });

    test('3. Promote variation node to main line', () {
      final root = AnalysisNode(fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      
      final e4 = root.addChild(
        childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP2PP/RNBQKBNR b KQkq e3 0 1',
        san: 'e4',
        uci: 'e2e4',
      );

      final d4 = root.addChild(
        childFen: 'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1',
        san: 'd4',
        uci: 'd2d4',
      );

      // Initially e4 is main line
      expect(root.children.first.moveSan, 'e4');

      // Promote d4 to main line
      root.promoteToMainLine(d4);

      expect(root.children.first.moveSan, 'd4');
      expect(d4.isMainLine, isTrue);
      expect(e4.isMainLine, isFalse);
    });

    test('4. Remove child node', () {
      final root = AnalysisNode(fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
      final e4 = root.addChild(
        childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP2PP/RNBQKBNR b KQkq e3 0 1',
        san: 'e4',
        uci: 'e2e4',
      );

      expect(root.children.length, 1);
      root.removeChild(e4);
      expect(root.children, isEmpty);
    });
  });
}
