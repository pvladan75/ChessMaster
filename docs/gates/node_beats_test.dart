// The gate for phase 6 of `docs/PLAN-PRIPREMA.md`, first half — the model and
// every reader, writer and copier of it. Pure: no widget, no server.
//
// Drafted by the lead on 27.9.2026 while phase 1 was being built, and kept
// here, outside `chess_app/test/`, because it names an API that does not exist
// yet. It moves to `chess_app/test/core/node_beats_test.dart` when the phase is
// briefed. **Not yet compiled and not yet watched going red.**
//
// ---------------------------------------------------------------------------
// THE FROZEN CONTRACT
//
// **A position may hold several beats** (D4). A beat is a sentence and the
// marks that stand while it is said.
//
//   class NodeBeat            in `lib/move_tree.dart`, beside ChessArrow and
//                             SquareMark, whose dialect it is written in
//     String comment
//     List<ChessArrow> arrows
//     List<SquareMark> squares
//     bool get isEmpty        no words, no arrow, no square
//     NodeBeat copy()         its own lists
//
// **Both tree models hold them the same way** — `MoveNode` and `AnalysisNode`:
//
//     List<NodeBeat> get beats     never empty
//     comment, arrows, squares     read and write `beats.first`, as fields
//                                  did: every screen that knows nothing of
//                                  beats goes on working on the first
//     NodeBeat get lastBeat
//     NodeBeat addBeat({int? after})   after the last when not said
//     bool removeBeatAt(int index)     false, and nothing removed, for the
//                                      only beat a node has
//   constructor: `comment:`, `arrows:`, `squares:` are the first beat, as
//   ever; `more:` is the beats after it.
//
// **An empty beat is not kept**, except as the only one a node has.
//
// **In a PGN** a node's beats are successive comments on its move, in order.
// A comment that holds only commands — a clock — is not a beat. A tree with
// one beat to a position is written **byte for byte** as it is today.
//
// **In a saved tree's JSON** `comment`, `arrows` and `squares` are the first
// beat, as ever, and `beats` holds the rest; the key is absent when there are
// none, so a tree with one beat to a position is the JSON it is today.
//
// **A part opened on a fork's position carries that position's last marks and
// none of its words** — what `section_split` and the draft controller do
// today with the one set of marks a position has.
//
// **One rule, one home**: outside the two model files, nothing builds a node
// by handing it another node's `arrows:` or `squares:`. A node is copied with
// `AnalysisNode.copyOf` / `copyTree`, or a root is made with
// `AnalysisNode.rootLike`.
// ---------------------------------------------------------------------------

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/move_tree.dart';

import '../support/dart_source.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1';

ChessArrow _arrow(String s) =>
    ChessArrow(colorCode: s[0], from: s.substring(1, 3), to: s.substring(3, 5));
SquareMark _square(String s) =>
    SquareMark(colorCode: s[0], square: s.substring(1, 3));

/// Everything a trainer can put on a tree, beats and all, as one string.
String _shape(AnalysisNode node) {
  final out = StringBuffer();
  void walk(AnalysisNode n) {
    out.write('${n.moveSan ?? '·'}${n.nag ?? ''}[');
    for (final b in n.beats) {
      out.write('«${b.comment}»'
          '${b.arrows.map((a) => '$a').join(',')}'
          '/${b.squares.map((s) => '$s').join(',')};');
    }
    out.write('](');
    for (final c in n.children) {
      walk(c);
    }
    out.write(')');
  }

  walk(node);
  return out.toString();
}

/// The text of a PGN without its headers: the exporter stamps today's date.
String _body(String pgn) => pgn
    .split('\n')
    .where((l) => !l.trimLeft().startsWith('['))
    .join('\n')
    .trim();

/// 1. e4 with two beats, 1... e5 with one, 1... c5 as a variation with three.
AnalysisNode _fixture() {
  final root = AnalysisNode(fen: _start);
  final e4 = root.addChild(childFen: _afterE4, san: 'e4', uci: 'e2e4');
  e4.comment = 'The pawn takes the centre.';
  e4.arrows.add(_arrow('Ge2e4'));
  e4.addBeat()
    ..comment = 'And it opens the bishop.'
    ..arrows.addAll([_arrow('Ge2e4'), _arrow('Bf1c4')])
    ..squares.add(_square('Rf7'));

  final e5 = e4.addChild(
      childFen:
          'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
      san: 'e5',
      uci: 'e7e5');
  e5.comment = 'Black answers in kind.';

  final c5 = e4.addChild(
      childFen:
          'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
      san: 'c5',
      uci: 'c7c5');
  c5.squares.add(_square('Gd4'));
  c5.addBeat().comment = 'The Sicilian.';
  c5.addBeat()
    ..comment = 'It fights for d4 from the side.'
    ..arrows.add(_arrow('Rc5d4'));
  return root;
}

/// A random tree of legal moves with random beats, from [seed].
AnalysisNode _random(int seed) {
  final r = Random(seed);
  const words = ['look', 'here', 'the', 'knight', 'weak', 'square', 'e4', 'Nf3'];
  const colours = ['R', 'O', 'G', 'B', 'P'];
  const files = 'abcdefgh';
  String sq() => '${files[r.nextInt(8)]}${1 + r.nextInt(8)}';

  void fill(NodeBeat beat) {
    if (r.nextInt(3) > 0) {
      beat.comment = [
        for (var i = 0; i <= r.nextInt(5); i++) words[r.nextInt(words.length)],
      ].join(' ');
    }
    for (var i = r.nextInt(3); i > 0; i--) {
      final from = sq();
      var to = sq();
      if (to == from) to = from == 'a1' ? 'a2' : 'a1';
      beat.arrows.add(
          ChessArrow(colorCode: colours[r.nextInt(5)], from: from, to: to));
    }
    for (var i = r.nextInt(3); i > 0; i--) {
      final at = sq();
      if (beat.squares.any((s) => s.square == at)) continue;
      beat.squares.add(SquareMark(colorCode: colours[r.nextInt(5)], square: at));
    }
  }

  void beats(AnalysisNode node) {
    fill(node.beats.first);
    for (var i = r.nextInt(4); i > 0; i--) {
      final beat = node.addBeat();
      fill(beat);
      // An empty beat is not kept, so a fixture must not count on one.
      if (beat.isEmpty) beat.comment = 'then';
    }
  }

  final root = AnalysisNode(fen: _start);
  beats(root);
  void grow(AnalysisNode node, int depth) {
    if (depth == 0) return;
    final moves = legalMoves(chess.Chess.fromFEN(node.fen));
    if (moves.isEmpty) return;
    final children = 1 + (r.nextInt(4) == 0 ? 1 + r.nextInt(2) : 0);
    for (var i = 0; i < children; i++) {
      final m = moves[r.nextInt(moves.length)];
      final played = playedMove(
        fen: node.fen,
        from: m['from'] as String,
        to: m['to'] as String,
        promotion: (m['promotion'] as String?) ?? '',
      );
      if (played == null) continue;
      final before = node.children.length;
      final child =
          node.addChild(childFen: played.fen, san: played.san, uci: played.uci);
      if (node.children.length == before) continue; // the move was there
      beats(child);
      grow(child, depth - 1);
    }
  }

  grow(root, 2 + r.nextInt(6));
  return root;
}

void main() {
  group('a node', () {
    test('has one beat, and its three fields are that beat', () {
      final node = AnalysisNode(
        fen: _start,
        comment: 'Look at d5.',
        arrows: [_arrow('Ge2e4')],
        squares: [_square('Rd5')],
      );
      expect(node.beats, hasLength(1));
      expect(node.beats.first.comment, 'Look at d5.');
      expect(identical(node.arrows, node.beats.first.arrows), isTrue,
          reason: 'a mark drawn through the field must land on the beat');
      expect(identical(node.squares, node.beats.first.squares), isTrue);

      node.comment = 'Look at d5 again.';
      node.arrows.add(_arrow('Rd1d5'));
      expect(node.beats.first.comment, 'Look at d5 again.');
      expect(node.beats.first.arrows, hasLength(2));
      expect(node.lastBeat, same(node.beats.first));
    });

    test('takes a beat after the last, or after the one it is told', () {
      final node = AnalysisNode(fen: _start, comment: 'one');
      node.addBeat().comment = 'three';
      node.addBeat(after: 0).comment = 'two';
      expect([for (final b in node.beats) b.comment], ['one', 'two', 'three']);
      expect(node.comment, 'one');
      expect(node.lastBeat.comment, 'three');
    });

    test('gives a beat up, but never its only one', () {
      final node = AnalysisNode(fen: _start, comment: 'one');
      node.addBeat().comment = 'two';
      expect(node.removeBeatAt(0), isTrue);
      expect([for (final b in node.beats) b.comment], ['two']);
      expect(node.comment, 'two',
          reason: 'the fields follow whichever beat is first now');
      expect(node.removeBeatAt(0), isFalse);
      expect(node.beats, hasLength(1));
      expect(node.removeBeatAt(5), isFalse);
    });

    test('the room\'s model holds them the same way', () {
      final node = MoveNode(san: 'e4', fen: _afterE4, from: 'e2', to: 'e4');
      node.comment = 'one';
      node.addBeat()
        ..comment = 'two'
        ..arrows.add(_arrow('Ge2e4'));
      expect([for (final b in node.beats) b.comment], ['one', 'two']);
      expect(identical(node.arrows, node.beats.first.arrows), isTrue);
      expect(node.lastBeat.arrows, hasLength(1));
    });

    test('a copied beat has lists of its own', () {
      final beat = NodeBeat(comment: 'one', arrows: [_arrow('Ge2e4')]);
      final copy = beat.copy();
      copy.arrows.clear();
      copy.comment = 'two';
      expect(beat.arrows, hasLength(1));
      expect(beat.comment, 'one');
    });
  });

  group('in a PGN', () {
    test('a position\'s beats are successive comments on its move', () {
      final body = _body(PgnExporterService.exportToPgn(_fixture()));
      expect(
          body,
          contains('1. e4 { The pawn takes the centre. [%cal Ge2e4] } '
              '{ And it opens the bishop. [%cal Ge2e4,Bf1c4] [%csl Rf7] }'));
      expect(
          body,
          contains('1... c5 { [%csl Gd4] } { The Sicilian. } '
              '{ It fights for d4 from the side. [%cal Rc5d4] }'));
    });

    test('and come back as they were', () {
      final tree = _fixture();
      final read = readStepTree(
          fen: _start, pgn: PgnExporterService.exportToPgn(tree));
      expect(read.rejectedMoves, 0);
      expect(_shape(read.root), _shape(tree));
    });

    test('two comments on a move are two beats — the second replaced the first',
        () {
      // Red on master: `parsePgn` assigns the node's comment at every closing
      // brace, so this read as „two" with the arrow of „one" gone.
      final read = readStepTree(
          fen: _start,
          pgn: '1. e4 { one [%cal Ge2e4] } { two [%csl Rd5] } 1... e5');
      final e4 = read.root.children.single;
      expect([for (final b in e4.beats) b.comment], ['one', 'two']);
      expect(['${e4.beats[0].arrows.single}', '${e4.beats[1].squares.single}'],
          ['Ge2e4', 'Rd5']);
      expect(e4.beats[1].arrows, isEmpty,
          reason: 'a beat\'s marks are its own, not the union');
    });

    test('a comment that is only a clock is not a beat', () {
      final read = readStepTree(
          fen: _start,
          pgn: '1. e4 { [%clk 0:03:00] } { Takes the centre. } '
              '1... e5 { [%clk 0:02:58] }');
      final e4 = read.root.children.single;
      expect([for (final b in e4.beats) b.comment], ['Takes the centre.']);
      expect(e4.clockSeconds, 180);
      final e5 = e4.children.single;
      expect(e5.beats, hasLength(1));
      expect(e5.beats.single.isEmpty, isTrue);
      expect(e5.clockSeconds, 178);
    });

    test('an empty beat is not written, and the clock is written once', () {
      final root = AnalysisNode(fen: _start);
      final e4 = root.addChild(childFen: _afterE4, san: 'e4', uci: 'e2e4');
      e4.clockSeconds = 180;
      e4.addBeat(); // nothing said, nothing drawn
      e4.addBeat().comment = 'Takes the centre.';
      final body = _body(PgnExporterService.exportToPgn(root));
      expect('{'.allMatches(body), hasLength(1));
      expect('[%clk'.allMatches(body), hasLength(1));
      expect(body, contains('Takes the centre.'));
    });

    test('the room\'s writer and reader agree with the studio\'s', () {
      final text = _body(PgnExporterService.exportToPgn(_fixture()));
      final tree = MoveTree.parsePgn(text, startingFen: _start)!;
      final e4 = tree.root.children.single;
      expect([for (final b in e4.beats) b.comment],
          ['The pawn takes the centre.', 'And it opens the bishop.']);
      final again = MoveTree.parsePgn(tree.exportToPgn(), startingFen: _start)!;
      expect([for (final b in again.root.children.single.beats) b.comment],
          ['The pawn takes the centre.', 'And it opens the bishop.']);
      expect(
          [
            for (final b in again.root.children.single.children[1].beats)
              '${b.comment}|${b.arrows.join(',')}|${b.squares.join(',')}'
          ],
          ['||Gd4', 'The Sicilian.||', 'It fights for d4 from the side.|Rc5d4|']);
    });

    test('a tree with one beat to a position is written as it is today', () {
      // The text is a literal: what `master` writes for this tree.
      final root = AnalysisNode(fen: _start);
      final e4 = root.addChild(childFen: _afterE4, san: 'e4', uci: 'e2e4')
        ..comment = 'Takes the centre.'
        ..arrows.add(_arrow('Ge2e4'))
        ..squares.add(_square('Rd5'))
        ..clockSeconds = 180;
      e4.addChild(
          childFen:
              'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2',
          san: 'e5',
          uci: 'e7e5');
      expect(
          _body(PgnExporterService.exportToPgn(root)),
          startsWith('1. e4 { Takes the centre. [%cal Ge2e4] [%csl Rd5] '
              '[%clk 0:03:00] } e5'));
    });
  });

  group('in a saved tree', () {
    test('the first beat is where it always was, and the rest are beside it',
        () {
      final json = _fixture().toJson();
      final e4 = (json['children'] as List).single as Map<String, dynamic>;
      expect(e4['comment'], 'The pawn takes the centre.');
      expect(e4['arrows'], ['Ge2e4']);
      expect(e4['beats'], [
        {
          'comment': 'And it opens the bishop.',
          'arrows': ['Ge2e4', 'Bf1c4'],
          'squares': ['Rf7'],
        },
      ]);
      final e5 = (e4['children'] as List).first as Map<String, dynamic>;
      expect(e5.containsKey('beats'), isFalse,
          reason: 'a position with one beat is the JSON it is today');
      expect(json.containsKey('beats'), isFalse);
    });

    test('and it comes back as it was', () {
      final tree = _fixture();
      final back = AnalysisNode.fromJson(
          jsonDecode(jsonEncode(tree.toJson())) as Map<String, dynamic>);
      expect(_shape(back), _shape(tree));
    });

    test('a tree saved before beats existed opens as it did', () {
      final old = AnalysisNode.fromJson({
        'fen': _start,
        'comment': 'An old note.',
        'arrows': ['Ge2e4'],
        'children': <Object>[],
      });
      expect(old.beats, hasLength(1));
      expect(old.comment, 'An old note.');
      expect('${old.arrows.single}', 'Ge2e4');
    });
  });

  group('whoever copies a tree', () {
    test('copyTree keeps every beat, in lists of its own', () {
      final tree = _fixture();
      final copy = copyTree(tree);
      expect(_shape(copy), _shape(tree));
      copy.children.single.beats[1].arrows.clear();
      expect(tree.children.single.beats[1].arrows, hasLength(2));
    });

    test('the tree\'s signature sees a beat after the first', () {
      // An edit the signature cannot see is an edit the next save writes back
      // as the text it had stored.
      final tree = _fixture();
      final before = treeSignature(tree);
      tree.children.single.beats[1].comment = 'And it opens the queen too.';
      expect(treeSignature(tree), isNot(before));

      final marks = treeSignature(tree);
      tree.children.single.beats[1].squares.clear();
      expect(treeSignature(tree), isNot(marks));

      final count = treeSignature(tree);
      tree.children.single.removeBeatAt(1);
      expect(treeSignature(tree), isNot(count));
    });

    test('and the signature of a tree with one beat each is what it was', () {
      // A literal, taken on master: a stored part must go on being written
      // back as the text it was read from.
      final root = AnalysisNode(fen: _start);
      root.addChild(childFen: _afterE4, san: 'e4', uci: 'e2e4')
        ..comment = 'Takes the centre.'
        ..arrows.add(_arrow('Ge2e4'));
      expect(treeSignature(root), '|||||1;e4||Takes the centre.|Ge2e4||0;');
    });

    test('a root made like a position has its last marks and no words', () {
      final e4 = _fixture().children.single;
      final root = AnalysisNode.rootLike(e4);
      expect(root.fen, e4.fen);
      expect(root.moveSan, isNull);
      expect(root.beats, hasLength(1));
      expect(root.comment, isEmpty);
      expect([for (final a in root.arrows) '$a'], ['Ge2e4', 'Bf1c4']);
      expect([for (final s in root.squares) '$s'], ['Rf7']);
      root.arrows.clear();
      expect(e4.lastBeat.arrows, hasLength(2),
          reason: 'the new root drew on the old position\'s list');

      final kept = AnalysisNode.rootLike(e4, keepWords: true);
      expect([for (final b in kept.beats) b.comment],
          ['The pawn takes the centre.', 'And it opens the bishop.']);
    });
  });

  group('any tree at all', () {
    for (var seed = 1; seed <= 400; seed++) {
      test('seed $seed goes through every door and comes out as it went in',
          () {
        final tree = _random(seed);
        final shape = _shape(tree);

        final text = PgnExporterService.exportToPgn(tree);
        final read = readStepTree(fen: _start, pgn: text);
        expect(read.rejectedMoves, 0);
        expect(_shape(read.root), shape, reason: 'the studio\'s PGN');
        expect(_body(PgnExporterService.exportToPgn(read.root)), _body(text),
            reason: 'written twice, the text is the same text');

        final room = MoveTree.parsePgn(_body(text), startingFen: _start)!;
        final viaRoom = readStepTree(fen: _start, pgn: room.exportToPgn());
        expect(_shape(viaRoom.root), shape, reason: 'through the room\'s model');

        final json = jsonDecode(jsonEncode(tree.toJson()));
        expect(_shape(AnalysisNode.fromJson(json as Map<String, dynamic>)),
            shape,
            reason: 'the saved tree');
        expect(_shape(copyTree(tree)), shape, reason: 'copyTree');
      });
    }
  });

  group('one rule, one home', () {
    test('nothing outside the models hands a node another node\'s marks', () {
      const allowed = {
        'lib/move_tree.dart',
        'lib/features/analysis_studio/models/analysis_node.dart',
      };
      final builds = RegExp(r'\b(AnalysisNode|MoveNode)\s*\(');
      // Handing over another node's list: `arrows: [...fork.arrows]`. A node
      // given marks made from something else, a generated tutorial's, is not
      // a copy.
      final marks =
          RegExp(r'\b(arrows|squares)\s*:[^,)]*\.\s*(arrows|squares)\b');
      final found = <String>[];
      var walked = 0;

      for (final file in Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))) {
        final path = file.path.replaceAll('\\', '/');
        if (allowed.contains(path)) continue;
        walked++;
        final code = partsOf(file.readAsStringSync())
            .where((p) =>
                p.kind == SourcePart.code || p.kind == SourcePart.interpolation)
            .map((p) => p.text)
            .join(' ');
        for (final match in builds.allMatches(code)) {
          // The argument list, by its brackets.
          var depth = 0;
          var end = match.end - 1;
          for (; end < code.length; end++) {
            if (code[end] == '(') depth++;
            if (code[end] == ')' && --depth == 0) break;
          }
          if (marks.hasMatch(code.substring(match.end, end))) {
            found.add('$path: ${match.group(1)}(… arrows/squares: …)');
          }
        }
      }
      expect(walked, greaterThan(200),
          reason: 'the walk did not reach the app');
      expect(found, isEmpty,
          reason: 'copy a node with copyOf / copyTree, or make a root with '
              'rootLike — a node built by hand forgets the beats after the '
              'first');
    });
  });
}
