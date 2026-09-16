/// The Analysis import reads what the app itself exports.
///
/// Reported 16.9.2026: a repertoire exported as PGN and pasted into Analysis
/// was refused as „Invalid PGN format". The import went through
/// `chess.load_pgn`, which rejects a variation in brackets and the space the
/// exporter writes in front of move one — and would have kept only the main
/// line had it accepted the text.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_import.dart';

/// The file from the report, byte for byte, including the leading space.
const reported =
    '''[Event "Repertoire: Italian Game: Evans Gambit Accepted — White"]
[Site "Chess trainer"]
[Date "2026.09.16"]
[Round "1"]
[White "Repertoire"]
[Black "Opponent"]
[Result "*"]
[Annotator "Repertoire (White)"]

 1. e4 e5 2. Nf3 Nc6 3. Bc4 Bc5 4. b4 Bxb4 { This is Evans Gambit Accepted } 5. c3 { The best moves here are Ba5, Bc5 and Be7 } Ba5 (5... Be7) (5... Bc5) 6. d4 { Strike into center. Black must decide: d6 or exd4 } d6 (6... exd4 7. Qb3 Qe7 8. O-O Bb6 (8... dxc3 9. Nxc3 Bxc3 10. Qxc3 Nf6 11. Ba3)) 7. Qb3 Qd7 (7... Nxd4 8. Nxd4 exd4 9. Bxf7+ Kf8 10. O-O dxc3 11. e5 Qe7 12. e6) 8. O-O Bb6 9. Nbd2 Na5 10. Qc2 Nxc4 11. Nxc4 Qc6 12. Nxb6 axb6 13. dxe5 dxe5 14. Nxe5 *''';

List<String> mainLine(AnalysisNode root) {
  final out = <String>[];
  var node = root;
  while (node.children.isNotEmpty) {
    node = node.children.first;
    out.add(node.moveSan!);
  }
  return out;
}

AnalysisNode childAfter(AnalysisNode root, List<String> sans) {
  var node = root;
  for (final san in sans) {
    node = node.children.firstWhere((c) => c.moveSan == san);
  }
  return node;
}

void main() {
  test('the reported repertoire file is read, all of it', () {
    final read = readAnalysisPgn(reported);

    expect(read, isNotNull, reason: 'the file was refused as invalid');
    read!;
    expect(read.rejectedMoves, 0);
    expect(read.gameCount, 1);
    expect(mainLine(read.root), hasLength(27),
        reason: 'the main line runs 1. e4 to 14. Nxe5');
    expect(read.tip.moveSan, 'Nxe5');
    // 27 on the main line; 1 + 1 + 5 + 6 (nested) + 10 in the variations.
    expect(read.moveCount, 50);
    expect(read.headers['White'], 'Repertoire');
    expect(read.headers['Result'], '*');
  });

  test('variations stay variations, in their order, nested ones too', () {
    final root = readAnalysisPgn(reported)!.root;

    final afterC3 = childAfter(
        root, ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'b4', 'Bxb4', 'c3']);
    expect(afterC3.children.map((c) => c.moveSan), ['Ba5', 'Be7', 'Bc5'],
        reason: 'the main move first, then the alternates as written');

    final nested = childAfter(root, [
      'e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'b4', 'Bxb4', 'c3', 'Ba5', //
      'd4', 'exd4', 'Qb3', 'Qe7', 'O-O',
    ]);
    expect(nested.children.map((c) => c.moveSan), ['Bb6', 'dxc3']);
    expect(
        mainLine(nested.children[1]), ['Nxc3', 'Bxc3', 'Qxc3', 'Nf6', 'Ba3']);
  });

  test('comments land on the move they follow', () {
    final root = readAnalysisPgn(reported)!.root;
    final bxb4 = childAfter(
        root, ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Bc5', 'b4', 'Bxb4']);
    expect(bxb4.comment, 'This is Evans Gambit Accepted');
    expect(bxb4.children.first.comment,
        'The best moves here are Ba5, Bc5 and Be7');
  });

  test('what Analysis exports, Analysis imports back unchanged', () {
    final original = readAnalysisPgn(reported)!.root;
    final exported = PgnExporterService.exportToPgn(original);
    final again = readAnalysisPgn(exported)!;

    expect(again.rejectedMoves, 0);
    expect(again.moveCount, 50);
    expect(PgnExporterService.exportToPgn(again.root), exported);
  });

  test('a move that cannot be played is counted, not silently dropped', () {
    final read = readAnalysisPgn('1. e4 e5 2. Nf3 Ke7 3. Bc4 Qxz9 *')!;
    expect(read.rejectedMoves, greaterThan(0));
  });

  test('a Chess.com game, with a clock after every move, reads whole', () {
    // The platform tab hands its games to the same import. `1...` after a
    // comment and `{[%clk ...]}` on every move are what that export looks like.
    const chessCom = '''
[Event "Live Chess"]
[White "Hikaru"]
[Black "only_strong_moves"]
[Result "1-0"]
[WhiteElo "3466"]

1. e4 {[%clk 0:02:59.9]} 1... e5 {[%clk 0:02:59.8]} 2. Nf3 {[%clk 0:02:58.5]} 2... Nc6 {[%clk 0:02:58.1]} 1-0
''';
    final read = readAnalysisPgn(chessCom)!;
    expect(read.rejectedMoves, 0);
    expect(mainLine(read.root), ['e4', 'e5', 'Nf3', 'Nc6']);
    expect(read.tip.comment, isEmpty,
        reason: 'a clock is not a sentence for the reader');
    expect(read.headers['WhiteElo'], '3466');
  });

  test('text with nothing to show is refused', () {
    expect(readAnalysisPgn('hello there'), isNull);
    expect(readAnalysisPgn(''), isNull);
  });

  test('a position with no moves is a position, not an error', () {
    const fen = '4k3/8/5K2/4P3/8/8/8/8 w - - 0 12';
    final read = readAnalysisPgn('[SetUp "1"]\n[FEN "$fen"]\n\n*');
    expect(read, isNotNull);
    expect(read!.root.fen, fen);
    expect(read.moveCount, 0);
  });

  test('from a [FEN], the moves are played from that position', () {
    const fen = '4k3/8/5K2/4P3/8/8/8/8 w - - 0 12';
    final read =
        readAnalysisPgn('[SetUp "1"]\n[FEN "$fen"]\n\n12. e6 Kf8 13. e7+ *')!;
    expect(read.rejectedMoves, 0);
    expect(mainLine(read.root), ['e6', 'Kf8', 'e7+']);
  });

  test('of several games, the first is read and the count is said', () {
    const two =
        '[Event "a"]\n\n1. d4 d5 *\n\n[Event "b"]\n\n1. e4 c5 2. Nf3 *\n';
    final read = readAnalysisPgn(two)!;
    expect(read.gameCount, 2);
    expect(read.rejectedMoves, 0);
    expect(mainLine(read.root), ['d4', 'd5']);
  });
}
