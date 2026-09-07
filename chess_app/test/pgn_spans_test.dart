import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/move_tree.dart';

/// T1 of `docs/PLAN-PGN-TEKST.md` — the exporter says where it wrote each node.
///
/// The pure half of the „PGN" tab. Everything about *which move a caret is in*
/// is decided here, without a widget and without a text field, so the batch that
/// draws the tab and its right-click menu has nothing left to decide.
///
/// The rule the whole thing rests on: a span is an offset into the string the
/// caller was handed. Every assertion below therefore reads the text back
/// through `substring` rather than trusting a number — a span that is off by the
/// length of a header is a menu that puts an arrow on the wrong move.
void main() {
  const startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  const midFen = '4k3/8/5K2/4P3/8/8/8/8 w - - 0 12';

  /// 1. e4 e5 2. Nf3 with a sentence on the first two.
  AnalysisNode threeMover() {
    final root = AnalysisNode(fen: startFen);
    final e4 = root.addChild(
      childFen: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1',
      san: 'e4',
      uci: 'e2e4',
    );
    e4.comment = 'Beli zauzima centar.';
    final e5 = e4.addChild(
      childFen: 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2',
      san: 'e5',
      uci: 'e7e5',
    );
    e5.comment = 'Klasičan odgovor.';
    e5.addChild(
      childFen:
          'rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 1 2',
      san: 'Nf3',
      uci: 'g1f3',
    );
    return root;
  }

  String textOf(PgnWithSpans out, PgnSpan span) =>
      out.pgn.substring(span.start, span.end);

  List<PgnSpan> spansOf(PgnWithSpans out, String nodeId) =>
      out.spans.where((s) => s.nodeId == nodeId).toList();

  group('a move knows where it is', () {
    test('the span is the move token, without its number', () {
      final root = threeMover();
      final e4 = root.children.first;

      final out = PgnExporterService.exportWithSpans(root);
      final move =
          spansOf(out, e4.id).firstWhere((s) => s.kind == PgnSpanKind.move);

      expect(textOf(out, move), 'e4',
          reason: 'the span covers something other than the move — „1. e4" '
              'means the number was taken in with it');
    });

    test('a NAG belongs to the move it marks', () {
      final root = threeMover();
      final e4 = root.children.first..nag = '!';

      final out = PgnExporterService.exportWithSpans(root);
      final move =
          spansOf(out, e4.id).firstWhere((s) => s.kind == PgnSpanKind.move);

      expect(textOf(out, move), 'e4!');
    });

    test('every move of the line gets exactly one span', () {
      final root = threeMover();
      final ids = <String>[];
      var node = root;
      while (node.children.isNotEmpty) {
        node = node.children.first;
        ids.add(node.id);
      }

      final out = PgnExporterService.exportWithSpans(root);

      for (final id in ids) {
        expect(
            spansOf(out, id).where((s) => s.kind == PgnSpanKind.move).length, 1,
            reason: 'node $id has the wrong number of move spans');
      }
    });

    test('a sideline is written and mapped like any other move', () {
      final root = threeMover();
      final e4 = root.children.first;
      final c5 = e4.addChild(
        childFen:
            'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2',
        san: 'c5',
        uci: 'c7c5',
      );
      c5.comment = 'Sicilijanka.';

      final out = PgnExporterService.exportWithSpans(root);
      final move =
          spansOf(out, c5.id).firstWhere((s) => s.kind == PgnSpanKind.move);
      final comment =
          spansOf(out, c5.id).firstWhere((s) => s.kind == PgnSpanKind.comment);

      expect(textOf(out, move), 'c5');
      expect(textOf(out, comment), contains('Sicilijanka.'));
      expect(out.pgn.substring(0, move.start), contains('('),
          reason: 'the sideline was not written as a variation at all');
    });
  });

  group('a comment knows where it is', () {
    test('the span is the whole brace, words and marks together', () {
      final root = threeMover();
      final e4 = root.children.first
        ..arrows.add(ChessArrow(from: 'd2', to: 'd4', colorCode: 'G'))
        ..squares.add(SquareMark(square: 'd5', colorCode: 'R'));

      final out = PgnExporterService.exportWithSpans(root);
      final comment =
          spansOf(out, e4.id).firstWhere((s) => s.kind == PgnSpanKind.comment);
      final text = textOf(out, comment);

      expect(text.startsWith('{'), isTrue);
      expect(text.endsWith('}'), isTrue);
      expect(text, contains('Beli zauzima centar.'));
      expect(text, contains('[%cal Gd2d4]'));
      expect(text, contains('[%csl Rd5]'));
    });

    test('a node with nothing to say has no comment span', () {
      final root = threeMover();
      final nf3 = root.children.first.children.first.children.first;

      final out = PgnExporterService.exportWithSpans(root);

      expect(spansOf(out, nf3.id).where((s) => s.kind == PgnSpanKind.comment),
          isEmpty);
    });

    test('the note on the starting position belongs to the root', () {
      // „Pogledaj polje d5" is a whole part, and the only place its sentence
      // can live is the root — written ahead of move one.
      final root = threeMover()..comment = 'Ovo je uvod.';

      final out = PgnExporterService.exportWithSpans(root);
      final rootSpan = spansOf(out, root.id).single;

      expect(rootSpan.kind, PgnSpanKind.comment);
      expect(textOf(out, rootSpan), contains('Ovo je uvod.'));
      expect(out.pgn.indexOf('e4'), greaterThan(rootSpan.end),
          reason: 'the opening note was written after the first move');
    });

    test('a part with no moves at all still maps its one sentence', () {
      final root = AnalysisNode(fen: midFen)..comment = 'Pogledaj polje d5.';

      final out = PgnExporterService.exportWithSpans(root);

      expect(out.spans, hasLength(1));
      expect(textOf(out, out.spans.single), contains('Pogledaj polje d5.'));
      expect(out.spans.single.nodeId, root.id);
    });
  });

  group('finding the node under a caret', () {
    test('inside a move, and at both of its edges', () {
      final root = threeMover();
      final e4 = root.children.first;

      final out = PgnExporterService.exportWithSpans(root);
      final move =
          spansOf(out, e4.id).firstWhere((s) => s.kind == PgnSpanKind.move);

      expect(out.nodeIdAt(move.start), e4.id);
      expect(out.nodeIdAt(move.start + 1), e4.id);
      expect(out.nodeIdAt(move.end), e4.id,
          reason: 'a caret just after „e4" is a caret in „e4" — that is where '
              'it lands when somebody clicks at the end of the move');
    });

    test('inside a comment it is the same node as the move', () {
      final root = threeMover();
      final e4 = root.children.first;

      final out = PgnExporterService.exportWithSpans(root);
      final comment =
          spansOf(out, e4.id).firstWhere((s) => s.kind == PgnSpanKind.comment);

      expect(out.nodeIdAt(comment.start + 3), e4.id);
      expect(out.spanAt(comment.start + 3)?.kind, PgnSpanKind.comment,
          reason: 'the caller cannot tell a comment from a move, so a menu '
              'cannot know whether to offer editing the words');
    });

    test('in the headers it is nobody', () {
      final root = threeMover();

      final out = PgnExporterService.exportWithSpans(root);

      expect(out.nodeIdAt(5), isNull, reason: 'a header is not a move');
      expect(out.nodeIdAt(out.pgn.indexOf('[Result')), isNull);
    });

    test('the offset just after a token still belongs to that token', () {
      // The consequence of a caret sitting *between* characters, and it is a
      // decision rather than an accident: the position right after „e4" is
      // where the caret lands when somebody clicks at the end of the move, and
      // the single space that follows a token is the same offset. So one space
      // of gap belongs to the token on its left, and only a wider gap belongs
      // to nobody. A menu that answered „nothing" for a click at the end of a
      // move would be a menu nobody could aim.
      final root = threeMover();
      final e4 = root.children.first;

      final out = PgnExporterService.exportWithSpans(root);
      final comment =
          spansOf(out, e4.id).firstWhere((s) => s.kind == PgnSpanKind.comment);

      expect(out.pgn[comment.end], ' ',
          reason: 'the shape this test is about has changed');
      expect(out.nodeIdAt(comment.end), e4.id);
      expect(out.nodeIdAt(comment.end + 1), isNot(e4.id),
          reason: 'a whole character of gap was given to the move on its left, '
              'so the next move cannot be reached by clicking in front of it');
    });
  });

  group('the map describes the string it came with', () {
    test('spans are in writing order and never overlap', () {
      final root = threeMover();
      final e4 = root.children.first;
      e4
          .addChild(
            childFen:
                'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2',
            san: 'c5',
            uci: 'c7c5',
          )
          .comment = 'Sicilijanka.';

      final out = PgnExporterService.exportWithSpans(root);

      for (var i = 1; i < out.spans.length; i++) {
        expect(out.spans[i].start, greaterThanOrEqualTo(out.spans[i - 1].end),
            reason: 'span $i starts before span ${i - 1} ends');
      }
    });

    test('every span points inside the text that was returned', () {
      final root = threeMover()..comment = 'Uvod.';

      final out = PgnExporterService.exportWithSpans(root);

      for (final span in out.spans) {
        expect(span.start, greaterThanOrEqualTo(0));
        expect(span.end, lessThanOrEqualTo(out.pgn.length),
            reason: 'a span runs past the end of the string — the trim that '
                'happens on the way out was not accounted for');
        expect(textOf(out, span).trim(), isNotEmpty);
      }
    });

    test('the text is the same one `exportToPgn` returns', () {
      final root = threeMover();

      final plain = PgnExporterService.exportToPgn(root);
      final withSpans = PgnExporterService.exportWithSpans(root);

      // Compared from the movetext down: the headers carry a `[Date]` stamped
      // from the clock, and two calls either side of midnight are allowed to
      // differ there and nowhere else.
      String moves(String pgn) => pgn.split('\n\n').last;
      expect(moves(withSpans.pgn), moves(plain));
    });
  });
}
