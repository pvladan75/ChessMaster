import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/features/repertoire/services/repertoire_pgn.dart';
import 'package:chess_app/move_tree.dart';

/// The repertoire as a PGN file — the owner's report of 16.9.2026.
///
/// Read back through `LessonStepLine`, which is this app's own parser, wherever
/// the question is about a move or a comment. Asserting on where a sentence
/// sits in the text is how the tutorial export spent a mutation being green
/// about the wrong node: two placements read the same by string position and
/// differently to a reader. `contains` is for the headers, which are text and
/// nothing else.
const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// 1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3, Black to move — the position this whole
/// feature's conversation was about.
const _smithMorra =
    'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 0 4';
const _smithMorraPath = ['e4', 'c5', 'd4', 'cxd4', 'c3', 'dxc3', 'Nxc3'];

/// After 4...Nc6.
const _afterNc6 =
    'r1bqkbnr/pp1ppppp/2n5/8/4P3/2N5/PP3PPP/R1BQKBNR w KQkq - 1 5';

/// After 4...Nc6 5.Nf3.
const _afterNf3 =
    'r1bqkbnr/pp1ppppp/2n5/8/4P3/2N2N2/PP3PPP/R1BQKB1R b KQkq - 2 5';

/// After 4...d6.
const _afterD6 = 'rnbqkbnr/pp2pppp/3p4/8/4P3/2N5/PP3PPP/R1BQKBNR w KQkq - 0 5';

RepertoireTreeMove _mine(String uci, String san, String fen,
        {String role = 'primary',
        List<RepertoireTreeMove> children = const []}) =>
    RepertoireTreeMove(
      uci: uci,
      san: san,
      fen: fen,
      mine: true,
      role: role,
      children: children,
    );

RepertoireTreeMove _theirs(String uci, String san, String fen,
        {double share = 0.5, List<RepertoireTreeMove> children = const []}) =>
    RepertoireTreeMove(
      uci: uci,
      san: san,
      fen: fen,
      mine: false,
      share: share,
      state: 'open',
      children: children,
    );

/// The Smith-Morra as the server hands it back: Nc6 the main move with the
/// book's reply under it, d6 an alternate.
RepertoireTree _tree({List<String> rootPath = _smithMorraPath}) =>
    RepertoireTree(
      rootFen: _smithMorra,
      rootPath: rootPath,
      children: [
        _mine('b8c6', 'Nc6', _afterNc6, children: [
          _theirs('g1f3', 'Nf3', _afterNf3, share: 0.62),
        ]),
        _mine('d7d6', 'd6', _afterD6, role: 'alternate'),
      ],
      maxPly: 40,
    );

RepertoireComment _note(String fen, String body) =>
    RepertoireComment(fenKey: fenKeyOf(fen), body: body);

String _pgnOf(RepertoireTree tree,
        {Map<String, RepertoireComment> comments = const {}}) =>
    repertoirePgn(
      name: 'Smith-Morra, Black',
      color: 'b',
      tree: tree,
      comments: comments,
    );

/// The moves of the file's main line, read back the way the app reads one.
List<String> _mainLine(String pgn, {String from = _start}) =>
    LessonStepLine.read(fen: from, pgn: pgn).line.movesSan;

void main() {
  group('the file is the repertoire', () {
    test('the main line is the primary move and the book\'s own reply', () {
      final pgn = _pgnOf(_tree());

      expect(_mainLine(pgn),
          ['e4', 'c5', 'd4', 'cxd4', 'c3', 'dxc3', 'Nxc3', 'Nc6', 'Nf3']);
    });

    test('an alternate is a variation, not a second main line', () {
      final tree = LessonStepLine.read(fen: _start, pgn: _pgnOf(_tree())).tree;
      expect(tree, isNotNull);

      final atRoot = _walk(tree!.root, _smithMorraPath);
      expect(atRoot.children.map((c) => c.san), ['Nc6', 'd6'],
          reason: 'the primary first — which is what PGN calls the main line');
    });

    test('every move replays: nothing in the file is unplayable', () {
      final read = LessonStepLine.read(fen: _start, pgn: _pgnOf(_tree()));
      expect(read.rejectedMoves, 0);
    });

    test('the card\'s label is not in the file', () {
      // `repertoireTreeToNodes` writes ` ★` and ` 45%` into `AnalysisNode.nag`
      // for the drawing, and the exporter writes `nag` straight after the move.
      // Exporting the picture would put `1. e4 ★ 62%` in the text, and a
      // reader would be right to refuse it.
      final pgn = _pgnOf(_tree());

      expect(pgn, isNot(contains('★')));
      expect(pgn, isNot(contains('%')));
      expect(pgn, isNot(contains('?')));
    });
  });

  group('the comments', () {
    test('are written on the move whose position they belong to', () {
      final pgn = _pgnOf(_tree(), comments: {
        fenKeyOf(_afterNf3): _note(_afterNf3, 'Now the gambit is accepted.'),
      });

      final read = LessonStepLine.read(fen: _start, pgn: pgn);
      final index = read.line.movesSan.indexOf('Nf3');
      expect(index, isNot(-1));
      expect(read.line.comments[index], contains('Now the gambit is accepted.'),
          reason: 'the comment belongs to the move, not to the one before it');
      expect(read.line.comments[read.line.movesSan.indexOf('Nc6')], isEmpty);
    });

    test('are left out when they are not asked for', () {
      final pgn = _pgnOf(_tree(), comments: const {});

      expect(pgn, isNot(contains('{')));
    });

    test('reach a move that is not on the main line', () {
      final pgn = _pgnOf(_tree(), comments: {
        fenKeyOf(_afterD6): _note(_afterD6, 'Playable, but passive.'),
      });

      final tree = LessonStepLine.read(fen: _start, pgn: pgn).tree!;
      final d6 = _walk(tree.root, [..._smithMorraPath, 'd6']);
      expect(d6.comment, contains('Playable, but passive.'));
    });
  });

  group('where the file starts', () {
    test('from move one, when the path really leads to the root', () {
      final pgn = _pgnOf(_tree());

      expect(pgn, isNot(contains('[SetUp')));
      expect(pgn, contains('1. e4 c5 2. d4'));
    });

    test('from the position itself, when the path does not replay', () {
      // A path that does not end on the root — the state a repertoire
      // extracted from a position nobody walked to arrives in. Guessing here
      // would write a file whose moves are not the ones it claims.
      final pgn = _pgnOf(_tree(rootPath: const ['e4', 'e5']));

      expect(pgn, contains('[SetUp "1"]'));
      expect(pgn, contains('[FEN "$_smithMorra"]'));
      expect(pgn, contains('Repertoire line: 1.e4 e5'),
          reason: 'the line is said in words when it cannot be played');
      expect(_mainLine(pgn, from: _smithMorra), ['Nc6', 'Nf3']);
    });

    test(
        'with no path at all, a root that is not the first position is a '
        'diagram', () {
      final pgn = _pgnOf(_tree(rootPath: const []));

      expect(pgn, contains('[FEN "$_smithMorra"]'));
      expect(_mainLine(pgn, from: _smithMorra), ['Nc6', 'Nf3']);
    });

    test('a note on the root travels either way', () {
      final own = _note(_smithMorra, 'Against the Morra I take and give back.');

      final played = _pgnOf(_tree(), comments: {fenKeyOf(_smithMorra): own});
      final diagram = _pgnOf(_tree(rootPath: const []),
          comments: {fenKeyOf(_smithMorra): own});

      expect(played, contains('Against the Morra I take and give back.'));
      expect(diagram, contains('Against the Morra I take and give back.'));
    });
  });

  group('what the file says it is', () {
    test('names the side the repertoire is written for', () {
      final black = repertoirePgnHeaders(name: 'Smith-Morra', color: 'b');
      final white = repertoirePgnHeaders(name: 'London', color: 'w');

      expect(black['Black'], 'Repertoire');
      expect(black['White'], 'Opponent');
      expect(white['White'], 'Repertoire');
      expect(white['Black'], 'Opponent');
      expect(black['Event'], contains('Smith-Morra'));
    });

    test('the whole tree is asked for, not the depth a screen draws', () {
      // `GET /repertoire/tree` clamps to 40 and defaults to 16. A file cut at
      // move eight with nothing said about it is a repertoire that looks
      // finished and is not.
      expect(repertoireExportMaxPly, 40);
    });
  });
}

/// The node at the end of [path], from [root].
MoveNode _walk(MoveNode root, List<String> path) {
  var at = root;
  for (final san in path) {
    final next = at.children.where((c) => c.san == san).firstOrNull;
    expect(next, isNotNull, reason: 'the file has no $san where one was built');
    at = next!;
  }
  return at;
}
