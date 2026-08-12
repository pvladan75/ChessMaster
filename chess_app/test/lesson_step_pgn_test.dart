import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/move_tree.dart';

// A lesson "analysis step" is stored as {fen, pgn} where pgn comes from
// PgnExporterService.exportToPgn(AnalysisNode) and gets read back on the
// room screen via MoveTree.parsePgn. This guards that handoff.
void main() {
  test('AnalysisNode -> PGN -> MoveTree round-trip preserves moves, variation and comment', () {
    final root = AnalysisNode(fen: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    final e4 = root.addChild(
      childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP2PP/RNBQKBNR b KQkq e3 0 1',
      san: 'e4',
      uci: 'e2e4',
    );
    e4.comment = 'Glavna linija';
    e4.eval = 0.3;
    root.addChild(
      childFen: 'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1',
      san: 'd4',
      uci: 'd2d4',
    );
    final e5 = e4.addChild(
      childFen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
      san: 'e5',
      uci: 'e7e5',
    );

    final pgn = PgnExporterService.exportToPgn(root, includeEvalComments: true);

    final tree = MoveTree.parsePgn(pgn, startingFen: root.fen);
    expect(tree, isNotNull);

    // Main line: e4 then e5
    expect(tree!.root.children.length, 2); // e4 (main) + d4 (variation)
    final parsedE4 = tree.root.children[0];
    expect(parsedE4.san, 'e4');
    expect(parsedE4.comment, contains('Glavna linija'));
    expect(parsedE4.comment, contains('%eval'));
    expect(parsedE4.children.length, 1);
    expect(parsedE4.children[0].san, 'e5');
    expect(parsedE4.children[0].fen, e5.fen);

    final parsedD4 = tree.root.children[1];
    expect(parsedD4.san, 'd4');
  });
}
