// „Postavi pitanje odavde" — the pure core, gated before the screen calls it.
//
// The studio already tells a trainer where a question belongs: „Dete bi videlo
// odgovor … Demonstracija ide u deo ispred pitanja — pitanje ostaje samo
// pozicija." A step's `pgn` is not redacted on its way to a child (the line
// *is* the lesson) and the viewer draws the move strip for every kind, so an
// `ask_move` step carrying a line hands the answer to anyone who presses
// „Sledeći potez". Until now the trainer had to build that arrangement by hand,
// and the one automatic route deleted their line to get there.
//
// The split does it and loses nothing:
//
//   A  the demonstration, exactly as it was, cut at the beat stood on
//   B  the question, a bare position on that beat — no moves at all
//   C  the continuation, from the same position, carrying the answer and
//      everything that followed it, sidelines included
//
// All three stand on positions that join, so the child's board never reloads:
// `LessonViewerScreen` crosses a join without touching the pieces, which is
// what makes „show, then ask, then show" one board and not three screens.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/section_split.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/move_tree.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A part carrying 1. e4 e5 2. Nf3 Nc6 3. Bb5, with a sideline after 2. Nf3.
TutorialSection italian() {
  final read = readStepTree(
    fen: _start,
    pgn: '1. e4 { Zauzimamo centar. } e5 2. Nf3 Nc6 (2... d6 { Filidor. }) '
        '3. Bb5 { Španska. }',
  );
  return TutorialSection(root: read.root, title: 'Deo 1', stepId: 'aaaa1111');
}

/// The node reached by walking [sans] down the main line.
AnalysisNode at(AnalysisNode root, List<String> sans) {
  var node = root;
  for (final san in sans) {
    node = node.children.firstWhere((c) => c.moveSan == san);
  }
  return node;
}

List<String> mainLineOf(TutorialSection section) {
  final out = <String>[];
  var node = section.root;
  while (node.children.isNotEmpty) {
    node = node.children.first;
    out.add(node.moveSan!);
  }
  return out;
}

void main() {
  group('the three parts a split makes', () {
    test('the demonstration stops where the trainer was standing', () {
      final part = italian();
      final parts = splitForQuestion(part, at(part.root, ['e4', 'e5', 'Nf3']));

      expect(parts, hasLength(3));
      expect(mainLineOf(parts[0]), ['e4', 'e5', 'Nf3']);
      expect(parts[0].kind, LessonStepKind.show);
    });

    test('the question is a bare position and carries no moves at all', () {
      final part = italian();
      final cursor = at(part.root, ['e4', 'e5', 'Nf3']);
      final parts = splitForQuestion(part, cursor);

      expect(parts[1].kind, LessonStepKind.askMove);
      expect(parts[1].root.children, isEmpty,
          reason: 'a question that carries its line shows the answer on the '
              'move strip');
      expect(parts[1].root.fen, cursor.fen);
    });

    test('the move the trainer had already played becomes the answer', () {
      final part = italian();
      final parts = splitForQuestion(part, at(part.root, ['e4', 'e5', 'Nf3']));

      expect(parts[1].solutionSan, 'Nc6');
    });

    test('the continuation keeps the answer and everything after it', () {
      final part = italian();
      final cursor = at(part.root, ['e4', 'e5', 'Nf3']);
      final parts = splitForQuestion(part, cursor);

      expect(parts[2].kind, LessonStepKind.show);
      expect(parts[2].root.fen, cursor.fen,
          reason: 'the continuation starts on the asked position, so the child '
              'answers and then watches the answer played');
      expect(mainLineOf(parts[2]), ['Nc6', 'Bb5']);
    });

    test('and the sidelines of the continuation with it', () {
      final part = italian();
      final parts = splitForQuestion(part, at(part.root, ['e4', 'e5', 'Nf3']));

      expect(parts[2].root.children.map((c) => c.moveSan), ['Nc6', 'd6'],
          reason: 'a branch the trainer wrote was dropped by the split');
    });

    test('every part stands on a position that joins the one before it', () {
      final part = italian();
      final parts = splitForQuestion(part, at(part.root, ['e4', 'e5', 'Nf3']));

      // The rule `LessonViewerScreen` reads: a step that opens on the position
      // the one before it ended on does not reload the board.
      expect(
        MoveTree.samePosition(
            endOfMainLine(parts[0].root).fen, parts[1].root.fen),
        isTrue,
      );
      expect(
        MoveTree.samePosition(
            endOfMainLine(parts[1].root).fen, parts[2].root.fen),
        isTrue,
      );
    });
  });

  group('what must not be lost, and what must not be said twice', () {
    test('the words written on the beat stay with the demonstration', () {
      final part = italian();
      final cursor = at(part.root, ['e4']);
      final parts = splitForQuestion(part, cursor);

      expect(endOfMainLine(parts[0].root).comment, 'Zauzimamo centar.');
      expect(parts[1].root.comment, isEmpty,
          reason: 'the sentence has already been read out by the part before');
      expect(parts[2].root.comment, isEmpty,
          reason: 'and it must not be read out a third time');
    });

    test('the marks drawn on it are on the question too', () {
      // The board does not reload across a join, so a mark that vanishes when
      // the question starts is a flicker in the middle of one continuous board.
      final part = italian();
      final cursor = at(part.root, ['e4']);
      cursor.arrows.addAll(MoveTree.parsePgnArrows('[%cal Gd2d4]'));
      cursor.squares.addAll(MoveTree.parsePgnSquares('[%csl Rf7]'));

      final parts = splitForQuestion(part, cursor);

      expect(parts[1].root.arrows, hasLength(1));
      expect(parts[1].root.squares, hasLength(1));
    });

    test('the question keeps the words when there is no part before it', () {
      // Standing on the part's own starting position: there is no
      // demonstration to make, so the sentence written there has nowhere else
      // to go.
      final part = italian();
      part.root.comment = 'Pogledaj centar.';
      final parts = splitForQuestion(part, part.root);

      expect(parts, hasLength(2));
      expect(parts[0].kind, LessonStepKind.askMove);
      expect(parts[0].root.comment, 'Pogledaj centar.');
      expect(mainLineOf(parts[1]), ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
    });

    test('a question with offered answers splits exactly the same way', () {
      // The second of the three actions the panel offers. Only the kind
      // differs: where the question is, what it stands on, and what happens to
      // the line are one rule, not two.
      final part = italian();
      final parts = splitForQuestion(
        part,
        at(part.root, ['e4', 'e5', 'Nf3']),
        kind: LessonStepKind.askChoice,
      );

      expect(parts, hasLength(3));
      expect(parts[1].kind, LessonStepKind.askChoice);
      expect(parts[1].root.children, isEmpty);
      expect(parts[1].solutionSan, 'Nc6',
          reason: 'the move is a property of the position, not of the way the '
              'question is asked');
      expect(mainLineOf(parts[2]), ['Nc6', 'Bb5']);
    });

    test('a question asked on a sideline is demonstrated down that sideline',
        () {
      // The demonstration has to end where the question begins. Standing on
      // 2... d6 and asking about it, a part A that walked its old main line
      // (2... Nc6) would end somewhere the question is not, and the child
      // would be asked about a position they were never shown.
      final part = italian();
      final cursor = at(part.root, ['e4', 'e5', 'Nf3', 'd6']);

      final parts = splitForQuestion(part, cursor);

      expect(mainLineOf(parts[0]), ['e4', 'e5', 'Nf3', 'd6']);
      expect(
        MoveTree.samePosition(
            endOfMainLine(parts[0].root).fen, parts[1].root.fen),
        isTrue,
      );
      expect(
          at(parts[0].root, ['e4', 'e5', 'Nf3']).children.map((c) => c.moveSan),
          ['d6', 'Nc6'],
          reason: 'the line that was the main one is still in the tree, one '
              'place further down');
    });

    test('standing at the end of the line asks with no answer yet', () {
      final part = italian();
      final parts = splitForQuestion(
          part, at(part.root, ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']));

      expect(parts, hasLength(2));
      expect(parts[1].kind, LessonStepKind.askMove);
      expect(parts[1].solutionSan, isNull,
          reason: 'there is no move after the cursor to take as the answer — '
              'the trainer plays it on the board');
    });
  });

  group('identity, and the text that describes the old shape', () {
    test('the demonstration keeps the step id and the others take none', () {
      final part = italian();
      final parts = splitForQuestion(part, at(part.root, ['e4', 'e5']));

      expect(parts[0].stepId, 'aaaa1111',
          reason: 'it is the same step, shortened — a schedule row still '
              'names it');
      expect(parts[1].stepId, isNull);
      expect(parts[2].stepId, isNull);
    });

    test('with nothing in front, the continuation keeps the id and the name',
        () {
      // A question placed at the part's own starting position: the
      // continuation carries the whole original line, so it is the step a
      // child's schedule and answers name. Until 11.9.2026 no part kept it.
      final part = italian();
      final parts = splitForQuestion(part, part.root);

      expect(parts.map((p) => p.stepId), [null, 'aaaa1111']);
      expect(parts[1].title, 'Deo 1');
      expect(parts[0].title, isEmpty);
    });

    test('with nothing in front or after, the question is the whole part', () {
      final part = TutorialSection(
        root: AnalysisNode(fen: _start),
        title: 'Pogledaj centar',
        stepId: 'cccc3333',
      );
      final parts = splitForQuestion(part, part.root);

      expect(parts, hasLength(1));
      expect(parts.single.stepId, 'cccc3333');
      expect(parts.single.title, 'Pogledaj centar');
    });

    test('no part is written back as the text of the part it came from', () {
      // The trap this is written for: `TutorialSection` decides „untouched" by
      // comparing `treeSignature` against the tree it holds, and it takes that
      // reading in its constructor. A new part built with the old `storedPgn`
      // would therefore look pristine on a tree that text does not describe,
      // and the save would send the whole original line as the shortened
      // part's.
      final part = TutorialSection.fromStep({
        'id': 'bbbb2222',
        'title': 'Deo 1',
        'fen': _start,
        'pgn': '1. e4 e5 2. Nf3',
      });

      final parts = splitForQuestion(part, at(part.root, ['e4']));

      for (final made in parts) {
        expect(made.isPristine, isFalse,
            reason: 'a split part carries the text of a tree it is not');
      }
      expect(parts[0].toJson()['pgn'], isNot(contains('Nf3')));
    });

    test('all three stand the way the part they came from stood', () {
      final part = italian()..blackOrientation = true;
      final parts = splitForQuestion(part, at(part.root, ['e4']));

      expect(parts.map((s) => s.blackOrientation), everyElement(isTrue),
          reason: 'the board turns over in the middle of one demonstration');
    });

    test('the original is not touched', () {
      final part = italian();
      splitForQuestion(part, at(part.root, ['e4', 'e5']));

      expect(mainLineOf(part), ['e4', 'e5', 'Nf3', 'Nc6', 'Bb5']);
    });
  });
}
