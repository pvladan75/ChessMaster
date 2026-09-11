// „Insert a line here" — phase 3 of docs/PLAN-STUDIO-ISTORIJA.md, without a
// screen.
//
// The owner's example, 11.9.2026: from 8/3k4/1n3b2/8/8/8/2PK4/2R5 w, the line
// 1. Ra1 Kc6 2. Ra6 Bb2 3. c3 Kb5, and a second line 2. Ra8 Bb2 to be shown
// from the position after Kc6. Three parts: up to Kc6, the new line, and the
// original continuation — with every sentence, arrow and square kept.
//
// Each part is written out the way a save writes it and read back through
// `LessonStepLine`, the child's own parser, and every sentence is asserted on
// the move that carried it. A cut that kept the sentences and moved them one
// move along would pass a test that only counted them.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/section_split.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';

const _fen = '8/3k4/1n3b2/8/8/8/2PK4/2R5 w - - 0 1';

/// The owner's line, with a sentence, an arrow or a square on every move.
const _pgn = '{The rook has a job. [%csl Gc1]} '
    '1. Ra1 {Rook to the a-file. [%cal Ga1a8]} '
    'Kc6 {The king steps up. [%csl Rc6]} '
    '2. Ra6 {Check along the sixth. [%cal Ga6c6]} '
    'Bb2 {The bishop hits a1. [%csl Gb2]} '
    '3. c3 {The pawn closes the diagonal. [%cal Gc2c3]} '
    'Kb5 {And the rook is attacked. [%csl Ra6]}';

TutorialSection _part({String pgn = _pgn, String? id = 'orig'}) =>
    TutorialSection.fromStep({
      'id': id,
      'fen': _fen,
      'title': 'The rook behind',
      'kind': 'show',
      'pgn': pgn,
    });

/// Down the main line, [plies] moves from the root.
AnalysisNode _at(TutorialSection part, int plies) {
  var node = part.root;
  for (var i = 0; i < plies; i++) {
    node = node.children.first;
  }
  return node;
}

/// A part as the child will read it.
LessonStepLine _read(TutorialSection part) {
  final wire = part.toJson();
  return LessonStepLine.read(
      fen: wire['fen'] as String, pgn: wire['pgn'] as String?);
}

void main() {
  test('the owner\'s example: up to Kc6, a new line, and the rest', () {
    final part = _part();
    expect(_read(part).line.movesSan, hasLength(6), reason: 'the premise');

    final cut = splitForLine(part, _at(part, 2));
    expect(cut.parts, hasLength(3));
    final [a, b, c] = cut.parts;
    expect(identical(cut.line, b), isTrue);

    final first = _read(a);
    expect(first.replays, isTrue);
    expect(first.line.movesSan, ['Ra1', 'Kc6']);
    expect(first.line.rootComment, 'The rook has a job.');
    expect(first.line.comments, ['Rook to the a-file.', 'The king steps up.']);
    expect(first.line.arrows.first.single.toString(), contains('a1a8'));
    expect(first.line.squares.last.single.toString(), 'Rc6');

    final line = _read(b);
    expect(line.line.movesSan, isEmpty, reason: 'the trainer plays it next');
    expect(b.root.fen, endOfMainLine(a.root).fen,
        reason: 'it starts where A stops, so the board does not reload');
    expect(line.line.rootComment, isEmpty,
        reason: 'A has just read that sentence out');
    expect(line.line.rootSquares.single.toString(), 'Rc6',
        reason: 'the square on Kc6 stays on the board across the join');

    final rest = _read(c);
    expect(rest.replays, isTrue);
    expect(c.root.fen, b.root.fen);
    expect(rest.line.movesSan, ['Ra6', 'Bb2', 'c3', 'Kb5']);
    expect(rest.line.comments, [
      'Check along the sixth.',
      'The bishop hits a1.',
      'The pawn closes the diagonal.',
      'And the rook is attacked.',
    ]);
    expect(rest.line.arrows[0].single.toString(), contains('a6c6'));
    expect(rest.line.squares[1].single.toString(), 'Gb2');
    expect(rest.line.arrows[2].single.toString(), contains('c2c3'));
    expect(rest.line.squares[3].single.toString(), 'Ra6');
    expect(rest.line.rootSquares.single.toString(), 'Rc6',
        reason: 'the board reloads on this position after B, so its marks '
            'are drawn again');
  });

  test('the first part keeps the step id and the name, the others are new', () {
    // A step id is what a child's schedule and recorded answers name a step
    // by. The part that is still the start of the tutorial keeps it.
    final part = _part();
    final [a, b, c] = splitForLine(part, _at(part, 2)).parts;
    expect([a.stepId, b.stepId, c.stepId], ['orig', null, null]);
    expect(a.title, 'The rook behind');
    expect([b.kind, c.kind], [LessonStepKind.show, LessonStepKind.show]);
  });

  test('a sideline already played at the cut becomes the new line', () {
    // The trainer played 2. Ra8 Bb2 as a variation first and cut afterwards.
    final part = _part(
        pgn: '1. Ra1 Kc6 2. Ra6 (2. Ra8 {The long way.} Bb2) '
            '2... Bb2 3. c3 Kb5');
    final [_, b, c] = splitForLine(part, _at(part, 2)).parts;

    expect(_read(b).line.movesSan, ['Ra8', 'Bb2']);
    expect(_read(b).line.comments.first, 'The long way.');
    expect(_read(c).line.movesSan, ['Ra6', 'Bb2', 'c3', 'Kb5']);
    expect(c.root.children, hasLength(1),
        reason: 'the sideline went to B and is not in C as well');
  });

  test('cut at the starting position: no first part, and the rest keeps the id',
      () {
    final part = _part();
    final cut = splitForLine(part, part.root);
    expect(cut.parts, hasLength(2));
    final [b, c] = cut.parts;

    expect(identical(cut.line, b), isTrue);
    expect(_read(b).line.rootComment, 'The rook has a job.',
        reason:
            'with nothing in front, B is where the opening sentence is read');
    expect(_read(c).line.movesSan, hasLength(6));
    expect(c.stepId, 'orig',
        reason: 'C is the original part; the line was put in front of it');
    expect(c.title, 'The rook behind');
  });

  test('cut at the end of the line: no continuation', () {
    final part = _part();
    final cut = splitForLine(part, _at(part, 6));
    expect(cut.parts, hasLength(2));
    expect(_read(cut.parts.first).line.movesSan, hasLength(6));
    expect(cut.parts.first.stepId, 'orig');
    expect(identical(cut.line, cut.parts.last), isTrue);
  });

  test('cut on a sideline: the first part ends where the new line begins', () {
    final part = _part(pgn: '1. Ra1 Kc6 (1... Ke6 2. Re1+) 2. Ra6 Bb2');
    final sideline = part.root.children.first.children[1]; // 1... Ke6
    final [a, b, c] = splitForLine(part, sideline).parts;

    expect(_read(a).line.movesSan, ['Ra1', 'Ke6']);
    expect(b.root.fen, sideline.fen);
    expect(_read(c).line.movesSan, ['Re1+']);
  });

  test('the part it was given is left as it was', () {
    final part = _part();
    final before = treeSignature(part.root);
    splitForLine(part, _at(part, 2));
    expect(treeSignature(part.root), before);
    expect(part.stepId, 'orig');
  });

  test('only a demonstration with a line can be cut', () {
    expect(canSplitForLine(_part()), isTrue);
    expect(canSplitForLine(TutorialSection.blank(fen: _fen)), isFalse);
    final question = _part()..kind = LessonStepKind.askMove;
    expect(canSplitForLine(question), isFalse);
  });
}
