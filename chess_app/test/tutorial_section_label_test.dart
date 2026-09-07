// What a part is called, on the screen and on the child's.
//
// „Deo 1, Deo 2, Deo 3" is a list that says nothing about a tutorial, and the
// word is an idea the trainer should not have to hold: they write a
// demonstration, ask a question, start a new position. So a part is called by
// what it says, and the trainer may overrule that by typing a name.
//
// **One function, read by the panel and by the wire.** Batch 57's finding was
// a panel that labelled a row from its own index while the stored title said
// something else — the right words over the wrong data — and the fix was to
// assert on the request. The same rule applies here: what the trainer reads in
// the list is what the child is sent, because it is computed once.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

TutorialSection partWith(String pgn, {String title = ''}) {
  final read = readStepTree(fen: _start, pgn: pgn);
  return TutorialSection(root: read.root, title: title);
}

void main() {
  group('what a part is called', () {
    test('a name the trainer typed is the name, and nothing overrules it', () {
      final part = partWith('1. e4 { Zauzimamo centar. }', title: 'Uvod');

      expect(part.label(0), 'Uvod');
    });

    test('otherwise it is called by what it says', () {
      final part = partWith('1. e4 { Zauzimamo centar. } e5');

      expect(part.label(0), 'Zauzimamo centar.');
    });

    test('the words about the starting position come first', () {
      // They are written before move one and are what the part opens with.
      final part =
          partWith('{ Pogledaj polje d5. } 1. e4 { Zauzimamo centar. }');

      expect(part.label(0), 'Pogledaj polje d5.');
    });

    test('one sentence, not the whole paragraph', () {
      final part = partWith('1. e4 { Zauzimamo centar. Sada crni bira kako '
          'će da odgovori na to, i ima nekoliko načina. }');

      expect(part.label(0), 'Zauzimamo centar.');
    });

    test('a sentence with no full stop is cut, not printed whole', () {
      final part = partWith('1. e4 { ${'ovo je vrlo duga rečenica ' * 8} }');

      expect(part.label(0).length, lessThanOrEqualTo(60));
      expect(part.label(0), endsWith('…'));
    });

    test('a question is called by what it asks', () {
      final part = partWith('')
        ..kind = LessonStepKind.askMove
        ..instruction = 'Nađi najbolji potez za belog.';

      expect(part.label(0), 'Nađi najbolji potez za belog.');
    });

    test('a part with no words at all falls back on the number', () {
      // Rare — a part almost always carries either a sentence or a task — and
      // the only place the word „Deo" is still read.
      expect(partWith('1. e4').label(2), 'Deo 3');
    });

    test('a generated name from an older tutorial is not a name', () {
      // Everything written before this was stored as „Deo 2" or „Primer 2",
      // and reading those as the trainer's own would pin a list of numbers
      // over a tutorial that has plenty to say for itself.
      final part = partWith('1. e4 { Zauzimamo centar. }', title: 'Deo 2');

      expect(part.label(0), 'Zauzimamo centar.');
    });
  });

  group('and it is the name the child is sent', () {
    test('the wire carries the label, not the stored placeholder', () {
      final part = partWith('1. e4 { Zauzimamo centar. }', title: 'Deo 1');

      expect(part.toJson(index: 0)['title'], 'Zauzimamo centar.');
    });

    test('a trainer\'s own name reaches the child unchanged', () {
      final part = partWith('1. e4 { Zauzimamo centar. }', title: 'Uvod');

      expect(part.toJson(index: 0)['title'], 'Uvod');
    });
  });
}
