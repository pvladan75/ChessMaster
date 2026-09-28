// A Black move says its number wherever the text was interrupted before it.
//
// `PgnExporterService` wrote `N...` only in front of the first move of a
// variation, so a tree whose root has Black to move came out as
// `Bxb1 (7... Be4 8. dxc6) 8. Rxb1 cxd5` — a main line that starts on a move
// with no number. The PGN standard writes `7... Bxb1` there, and again
// whenever a comment or a closed variation stands between a Black move and
// the White move before it.
//
// The reader is measured first, because every text this app has already
// stored is in the old form: `MoveTree.parsePgn` has to read both and get one
// tree, or the change to the writer would cost a stored line.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/pgn_span.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_import.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/move_tree.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Black to move, move seven — the position of the report.
const _black =
    'rn2kbnr/pp2pppp/2p5/3PNb2/8/1P4P1/1P1PPP1P/RNB1KB1R b KQkq - 0 7';

/// The movetext, without the headers and without the result.
String _body(String pgn) {
  final text = pgn.split('\n\n').last.trim();
  return text.endsWith(' *') ? text.substring(0, text.length - 2) : text;
}

String _written(String fen, String pgn) {
  final read = readStepTree(fen: fen, pgn: pgn);
  expect(read.rejectedMoves, 0, reason: 'the premise: "$pgn" replays');
  return _body(PgnExporterService.exportToPgn(read.root));
}

/// A tree as moves and words only, so two readings can be compared.
String _shape(MoveNode node) => '${node.san}{${node.comment}}'
    '[${node.children.map(_shape).join(' ')}]';

String _studioShape(AnalysisNode node) =>
    '${node.moveSan ?? 'Root'}{${node.comment}}'
    '[${node.children.map(_studioShape).join(' ')}]';

void main() {
  group('the reader takes a Black move with its number and without', () {
    const forms = {
      'numbered': '7... Bxb1 8. Rxb1',
      'bare': 'Bxb1 8. Rxb1',
      'glued': '7...Bxb1 8.Rxb1',
    };

    for (final MapEntry(key: name, value: pgn) in forms.entries) {
      test('$name: "$pgn"', () {
        final tree = MoveTree.parsePgn(pgn, startingFen: _black)!;
        expect(tree.rejectedMoves, 0);
        expect(_shape(tree.root), 'Root{}[Bxb1{}[Rxb1{}[]]]');
      });
    }

    test('after a comment and after a variation, both forms are one tree', () {
      const numbered = '7... Be4 { Steps aside. } 8. dxc6 { Takes. } '
          '(8. f3 Bxd5) 8... Nxc6';
      const bare = 'Be4 { Steps aside. } 8. dxc6 { Takes. } (8. f3 Bxd5) Nxc6';
      final a = MoveTree.parsePgn(numbered, startingFen: _black)!;
      final b = MoveTree.parsePgn(bare, startingFen: _black)!;
      expect(a.rejectedMoves, 0);
      expect(b.rejectedMoves, 0);
      expect(
          _shape(a.root),
          'Root{}[Be4{Steps aside.}[dxc6{Takes.}[Nxc6{}[]] '
          'f3{}[Bxd5{}[]]]]');
      expect(_shape(b.root), _shape(a.root));
    });

    test('Analysis reads both from a pasted game', () {
      String game(String moves) => '[SetUp "1"]\n[FEN "$_black"]\n\n$moves *';
      final numbered = readAnalysisPgn(game('7... Bxb1 8. Rxb1'))!;
      final bare = readAnalysisPgn(game('Bxb1 8. Rxb1'))!;
      expect(numbered.rejectedMoves, 0);
      expect(bare.rejectedMoves, 0);
      expect(numbered.moveCount, 2);
      expect(_studioShape(numbered.root), 'Root{}[Bxb1{}[Rxb1{}[]]]');
      expect(_studioShape(bare.root), _studioShape(numbered.root));
    });
  });

  group('the writer numbers a Black move', () {
    test('when it is the first move of the text', () {
      expect(_written(_black, 'Bxb1 (Be4 8. dxc6) 8. Rxb1 cxd5'),
          '7... Bxb1 (7... Be4 8. dxc6) 8. Rxb1 cxd5');
    });

    test('when a note on the starting position stands in front of it', () {
      // Two spaces after the root's note are what the exporter has always
      // written, in front of a White move as well; this case is about the
      // number, so the literal is the one a run gives.
      expect(_written(_black, '{ Black to move. } Bxb1 8. Rxb1'),
          '{ Black to move. }  7... Bxb1 8. Rxb1');
      expect(_written(_start, '{ White to move. } 1. e4 e5'),
          '{ White to move. }  1. e4 e5');
    });

    test('after a closed variation', () {
      expect(_written(_black, 'Be4 8. dxc6 (8. f3 Bxd5) Nxc6'),
          '7... Be4 8. dxc6 (8. f3 Bxd5) 8... Nxc6');
    });

    test('after a comment', () {
      expect(_written(_start, '1. e4 { Takes the centre. } e5 2. Nf3'),
          '1. e4 { Takes the centre. } 1... e5 2. Nf3');
    });

    test('after a comment inside a variation', () {
      expect(_written(_start, '1. e4 e5 (1... c5 2. Nf3 { Open. } d6) 2. Nf3'),
          '1. e4 e5 (1... c5 2. Nf3 { Open. } 2... d6) 2. Nf3');
    });

    test('after a comment on the first move of a variation', () {
      // Its own case: the first move of a variation is written by another
      // call than the moves after it, and a mutation that dropped the
      // comment there survived the case above.
      expect(_written(_start, '1. e4 (1. d4 { The queen\'s pawn. } d5) e5'),
          '1. e4 (1. d4 { The queen\'s pawn. } 1... d5) 1... e5');
    });

    test('after a comment that is only a clock', () {
      expect(
          _written(
              _start, '1. e4 { [%clk 0:03:00] } e5 { [%clk 0:02:58] } 2. Nf3'),
          '1. e4 { [%clk 0:03:00] } 1... e5 { [%clk 0:02:58] } 2. Nf3');
    });

    test('and nowhere else', () {
      expect(_written(_start, '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6'),
          '1. e4 e5 2. Nf3 Nc6 3. Bb5 a6');
      // A variation on Black's move closes in front of a White move, which
      // has its number anyway; the Black move after it follows that White
      // move directly.
      expect(_written(_start, '1. e4 e5 (1... c5) 2. Nf3 Nc6'),
          '1. e4 e5 (1... c5) 2. Nf3 Nc6');
    });
  });

  group('the number is not the move', () {
    test('a Black move\'s span is the move, with its number in front of it',
        () {
      final root =
          readStepTree(fen: _black, pgn: 'Bxb1 { Takes. } 8. Rxb1 { Back. } a6')
              .root;
      final out = PgnExporterService.exportWithSpans(root);

      String moveText(AnalysisNode node) {
        final span = out.spans.singleWhere(
            (s) => s.nodeId == node.id && s.kind == PgnSpanKind.move);
        return out.pgn.substring(span.start, span.end);
      }

      String before(AnalysisNode node, int length) {
        final span = out.spans.singleWhere(
            (s) => s.nodeId == node.id && s.kind == PgnSpanKind.move);
        return out.pgn.substring(span.start - length, span.start);
      }

      final bxb1 = root.children.single;
      final rxb1 = bxb1.children.single;
      final a6 = rxb1.children.single;

      expect(moveText(bxb1), 'Bxb1');
      expect(before(bxb1, 5), '7... ');
      expect(moveText(rxb1), 'Rxb1');
      expect(moveText(a6), 'a6');
      expect(before(a6, 5), '8... ');
      expect(out.nodeIdAt(out.pgn.indexOf('8... ') + 2), isNot(a6.id),
          reason: 'a caret in the number is not a caret in the move');
    });

    test('spans stay in writing order and never overlap', () {
      final root = readStepTree(
              fen: _black,
              pgn: '{ Start. } Be4 { One. } 8. dxc6 (8. f3 { Two. } Bxd5) Nxc6')
          .root;
      final out = PgnExporterService.exportWithSpans(root);
      for (var i = 1; i < out.spans.length; i++) {
        expect(out.spans[i].start, greaterThanOrEqualTo(out.spans[i - 1].end));
      }
      for (final span in out.spans) {
        expect(out.pgn.substring(span.start, span.end), isNot(contains('...')),
            reason: 'a number was taken into a span');
      }
    });
  });

  group('what is written is read back', () {
    const lines = {
      _black: 'Bxb1 (Be4 { Aside. } 8. dxc6 (8. f3 Bxd5) Nxc6) 8. Rxb1 cxd5',
      _start: '{ A note. } 1. e4 { One. } e5 { Two. } (1... c5 { Three. } '
          '2. Nf3 d6) 2. Nf3 Nc6',
    };

    for (final MapEntry(key: fen, value: pgn) in lines.entries) {
      test(pgn, () {
        final first = readStepTree(fen: fen, pgn: pgn);
        expect(first.rejectedMoves, 0);
        final text = PgnExporterService.exportToPgn(first.root);
        final again = readStepTree(fen: fen, pgn: text);
        expect(again.rejectedMoves, 0);
        expect(_studioShape(again.root), _studioShape(first.root));
        expect(_body(PgnExporterService.exportToPgn(again.root)), _body(text),
            reason: 'written twice, the text is the same text');
      });
    }
  });
}
