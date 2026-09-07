// The gate for P1 and P2 of `docs/PLAN-STUDIO-REDIZAJN.md` — the model half of
// the studio redesign: a section that keeps its tree, a section that keeps its
// server id, and a saved tutorial that can be read back into a draft.
//
// Written before the work, and kept here rather than in `test/` until it lands:
// a gate that names classes nobody has written does not compile, and a suite
// that does not compile says nothing about anything else. It moves to
// `chess_app/test/tutorial_section_test.dart` in the merge commit, the way the
// vocabulary, branching, authoring and step-order gates were moved.
//
// ---------------------------------------------------------------------------
// WHAT THIS FILE IS FOR
//
// Two faults, and both of them are silent:
//
//   * **A trainer's words and arrows disappearing on reopen.** The only reader
//     that keeps them is `LessonStepLine.read` → `MoveTree`.
//     `AnalysisStudioScreen._importPgn` goes through `chess.load_pgn` and
//     `getHistory()`, which keeps the main line and throws away every comment,
//     every `[%cal]`, every `[%csl]` and every variation. A reopen routed
//     through that would look perfect and lose the lesson.
//   * **A child's schedule orphaned by a save.** `assignment_items.step_key`
//     and `review_items.step_key` name a step by its `id` and nothing joins on
//     it. `PUT /lessons/:id` guards against a list that lost its ids — and the
//     guard requires `storedList.length === steps.length`, so it **cannot fire**
//     the moment a section is added or removed, which is the whole point of the
//     screen being built. Below is the only thing there.
//
// Every test here runs with no widget tree. That is deliberate: the model is
// the contract, and a gate that has to pump frames to read it is a gate that
// will be edited the first time the layout moves.
//
// ---------------------------------------------------------------------------
// NOT ASSERTED HERE, AND WHERE IT LIVES INSTEAD
//
//   * `beatsOf` and the timeline           — P6, its own gate
//   * the answer-leak refusal (§7.1)       — P8, its own gate
//   * POST-then-PUT save routing (§6)      — P3, once `LessonApiService`
//                                            answers with the saved row
//   * „Deo" replacing „Primer"             — a UI string, and it lands with the
//                                            screen in P5. P1/P2 leave every
//                                            user-facing string alone, which is
//                                            why `tutorial_authoring_test.dart`
//                                            must pass **unedited**.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/move_tree.dart' show SquareMark;

const String openingFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A line with everything a trainer can put on one: a note about the starting
/// position, a sentence on a move, an arrow, a coloured square, and a sideline.
///
/// Written by hand rather than exported, because what is being proved is that
/// the *reader* keeps all five — an export of a tree this file built would
/// prove only that two functions of mine agree with each other.
const String richPgn = '{ Pogledaj centar. [%csl Gd4,Ge4] } '
    '1. e4 { Zauzima centar. [%cal Ge2e4] } '
    'e5 (1... c5 { Sicilijanka — druga ideja. }) '
    '2. Nf3';

Map<String, dynamic> savedStep({
  required String id,
  String title = 'Pozicija',
  String fen = openingFen,
  String? pgn,
  String kind = 'show',
  String? instruction,
  String? solutionSan,
  List<String>? acceptedSans,
  List<Map<String, dynamic>>? choices,
  // Part of what the server stores since 7.9.2026, so part of what a round
  // trip has to bring back. It is written here rather than defaulted away
  // because the interesting case is a step that carries it: a step that does
  // *not* is the legacy one, and `fromStep` deliberately answers for that with
  // the guess the child's viewer was already making, which is a different
  // test.
  bool blackOrientation = false,
}) =>
    {
      'id': id,
      'title': title,
      'fen': fen,
      if (pgn != null) 'pgn': pgn,
      'kind': kind,
      'blackOrientation': blackOrientation,
      if (instruction != null) 'instruction': instruction,
      if (solutionSan != null) 'solutionSan': solutionSan,
      if (acceptedSans != null) 'acceptedSans': acceptedSans,
      if (choices != null) 'choices': choices,
    };

AnalysisNode? childBySan(AnalysisNode node, String san) {
  for (final child in node.children) {
    if (child.moveSan == san) return child;
  }
  return null;
}

void main() {
  group('P1 — the reader keeps what the trainer wrote', () {
    test('a line comes back with its words, its arrows and its sidelines', () {
      final read = readStepTree(fen: openingFen, pgn: richPgn);
      final root = read.root;

      // The note about the starting position. It is the only place a sentence
      // about a *still* board can live, and a still board is most of what a
      // tutorial is.
      expect(root.comment, 'Pogledaj centar.');
      expect(root.squares.map((s) => s.toString()).toList(), ['Gd4', 'Ge4']);
      expect(root.fen, openingFen);

      final e4 = childBySan(root, 'e4');
      expect(e4, isNotNull, reason: 'the main line did not survive the read');
      expect(e4!.comment, 'Zauzima centar.');
      expect(e4.arrows.map((a) => a.toString()).toList(), ['Ge2e4'],
          reason: '[%cal] is the trainer pointing at the board; '
              'a reader that drops it drops half the lesson');

      // The sideline. `chess.load_pgn` keeps the main line only, so this is the
      // assertion that fails the moment the wrong reader is used.
      expect(e4.children.length, 2,
          reason: 'the sideline was thrown away — this is _importPgn, '
              'not LessonStepLine');
      expect(e4.children.first.moveSan, 'e5');
      final c5 = childBySan(e4, 'c5');
      expect(c5, isNotNull);
      expect(c5!.comment, 'Sicilijanka — druga ideja.');

      // And the line goes on past the fork.
      expect(childBySan(e4.children.first, 'Nf3'), isNotNull);
    });

    test('every node knows its parent, so the cursor can walk back', () {
      final root = readStepTree(fen: openingFen, pgn: richPgn).root;
      final e4 = childBySan(root, 'e4')!;
      expect(e4.parent, same(root));
      expect(childBySan(e4, 'c5')!.parent, same(e4));
      expect(root.isRoot, isTrue);
    });

    test('a step with no line is a bare root on its own position', () {
      const midgame = '8/8/4k3/8/8/4K3/4P3/8 w - - 0 1';
      final read = readStepTree(fen: midgame, pgn: null);
      expect(read.root.fen, midgame);
      expect(read.root.children, isEmpty);
      expect(read.rejectedMoves, 0);

      // The empty string is the same thing and must not be parsed.
      expect(readStepTree(fen: midgame, pgn: '  ').root.children, isEmpty);
    });

    test('a line that does not belong to its position is reported, not hidden',
        () {
      // The oldest fault in this repository: `MoveTree.parsePgn` skips a move
      // it cannot play **without a word**, so a step whose pgn was written from
      // one position and whose fen names another arrived as a still picture and
      // nobody was told. `rejectedMoves` is the difference between that and a
      // step that was always meant to be a diagram.
      final read = readStepTree(
        fen: 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 1',
        pgn: '1. e4 e5 2. Nf3',
      );
      expect(read.rejectedMoves, greaterThan(0),
          reason: 'a line from a different game replayed in silence');
    });

    test('a promotion keeps a uci that says what it promoted to', () {
      final read = readStepTree(
        fen: '8/4P3/8/8/8/8/8/k3K3 w - - 0 1',
        pgn: '1. e8=Q',
      );
      final promoted = read.root.children.single;
      expect(promoted.moveSan, 'e8=Q');
      expect(promoted.moveUci, 'e7e8q',
          reason: 'a uci with no promotion letter is a move the board refuses');
    });
  });

  group('P1 — a section is one step, and it keeps its identity', () {
    test('a saved step read and written back is byte-identical', () {
      // The whole safety story in one assertion. Every field the server can
      // store is here: if a round trip drops one, a trainer who only renamed
      // their tutorial silently loses it.
      final step = savedStep(
        id: 'a1b2c3d4',
        title: 'Otvaranje',
        pgn: richPgn,
        kind: 'ask_move',
        instruction: 'Odigraj najbolji potez.',
        solutionSan: 'Nf3',
        acceptedSans: ['Bc4', 'Nc3'],
      );

      final section = TutorialSection.fromStep(step);
      expect(section.toJson(), step);
    });

    test('a question with answers survives the round trip', () {
      final step = savedStep(
        id: 'ffff0000',
        title: 'Zašto centar',
        kind: 'ask_choice',
        instruction: 'Zašto je e4 dobar potez?',
        choices: [
          {'text': 'Kontrola centra', 'correct': true},
          {'text': 'Napad na kralja', 'correct': false},
        ],
      );

      final section = TutorialSection.fromStep(step);
      expect(section.kind, LessonStepKind.askChoice);
      expect(section.choices.map((c) => c.text).toList(),
          ['Kontrola centra', 'Napad na kralja']);
      expect(section.choices.map((c) => c.correct).toList(), [true, false]);
      expect(section.toJson(), step);
    });

    test('the pgn is the stored text while the tree is untouched', () {
      // Not a tidiness. `PgnExporterService` writes a fresh `[Date]` header on
      // every call and formats a line its own way, so re-exporting an untouched
      // section would rewrite text the trainer never edited — and any single
      // thing the exporter cannot say that the parser could read would be lost
      // on the first save of a tutorial nobody changed.
      final section =
          TutorialSection.fromStep(savedStep(id: 'aaaa1111', pgn: richPgn));
      expect(section.toJson()['pgn'], richPgn);
    });

    test('editing the tree replaces the pgn and keeps the id', () {
      final section =
          TutorialSection.fromStep(savedStep(id: 'aaaa1111', pgn: richPgn));
      final e4 = childBySan(section.root, 'e4')!;
      e4.comment = 'Nova rečenica.';

      final written = section.toJson();
      expect(written['pgn'], isNot(richPgn),
          reason: 'the edit was not written — the trainer typed into nothing');
      expect(written['pgn'].toString(), contains('Nova rečenica.'));
      expect(written['id'], 'aaaa1111',
          reason: 'editing a section must never re-mint its id');
    });

    test('a section that has never been saved sends no id at all', () {
      final section = TutorialSection.blank(fen: openingFen);
      section.title = 'Primer 1';
      final written = section.toJson();
      expect(written.containsKey('id'), isFalse,
          reason: 'the server mints the id; a client-invented one is refused');
      expect(written['fen'], openingFen);
      expect(written['kind'], 'show');
    });

    test('a note about the starting position is not thrown away', () {
      // Found by a mutation on the P3a gate, and it was a real bug rather than
      // a weak test. A part's line used to be judged by its move count alone,
      // so a part with **no moves** sent no pgn — and the note about the
      // starting position, the arrows and the coloured squares live on the
      // root, which is the only place they can live. „Pogledaj polje d5" is a
      // whole step, `PgnExporterService` was taught to write that comment ahead
      // of move one so it could travel, and this threw it away again on the way
      // out. The child got a bare diagram and nobody was told.
      final section = TutorialSection.blank(fen: openingFen);
      section.root.comment = 'Pogledaj centar.';

      final pgn = section.toJson()['pgn']?.toString() ?? '';
      expect(pgn, contains('Pogledaj centar.'));

      // And it survives the round trip back through the child's own reader.
      final back = readStepTree(fen: openingFen, pgn: pgn);
      expect(back.root.comment, 'Pogledaj centar.');
      expect(back.root.children, isEmpty);
    });

    test('an arrow on a still position travels too', () {
      final section = TutorialSection.blank(fen: openingFen);
      section.root.squares.add(SquareMark(square: 'd5', colorCode: 'G'));

      final pgn = section.toJson()['pgn']?.toString() ?? '';
      final back = readStepTree(fen: openingFen, pgn: pgn);
      expect(back.root.squares.single.toString(), 'Gd5');
    });

    test('a section with no moves says nothing about a line at all', () {
      // Batch 54's correction still holds — `PgnExporterService` always writes
      // headers, so an exported empty tree is *not* the empty string and a step
      // that is only a diagram would otherwise arrive carrying a PGN with no
      // moves in it. What changes here is the form of the answer. `''` and an
      // absent key are the same thing to `buildLessonStep`, which reads
      // `if (pgn) entry.pgn = pgn` — but only absence lets a step that was
      // stored without a line come back without one, and that round trip is
      // what P2 is for.
      final section = TutorialSection.blank(fen: openingFen);
      expect(section.toJson().containsKey('pgn'), isFalse);
    });
  });

  group('P2 — a saved tutorial opens as a draft', () {
    Map<String, dynamic> lesson() => {
          'id': 77,
          'title': 'Opozicija',
          'position_list': [
            savedStep(id: 'step0001', title: 'Uvod', pgn: richPgn),
            savedStep(
              id: 'step0002',
              title: 'Pitanje',
              kind: 'ask_move',
              instruction: 'Nađi potez.',
              solutionSan: 'Nf3',
            ),
          ],
        };

    test('the draft learns which tutorial it is', () {
      final draft = TutorialDraft.fromLesson(lesson());
      expect(draft.lessonId, 77,
          reason: 'a draft that does not know its id saves a second tutorial');
      expect(draft.title, 'Opozicija');
      expect(draft.sections.length, 2);
      expect(draft.sections.map((s) => s.title).toList(), ['Uvod', 'Pitanje']);
      expect(draft.sections.map((s) => s.stepId).toList(),
          ['step0001', 'step0002']);
    });

    test('loaded and saved unchanged is byte-identical, ids included', () {
      final source = lesson();
      final draft = TutorialDraft.fromLesson(source);
      expect(draft.positionList, source['position_list']);
    });

    test('adding a section in the middle keeps every other id', () {
      final draft = TutorialDraft.fromLesson(lesson());
      draft.selected = 0;
      draft.addSection(continueFromEnd: true);

      expect(draft.sections.length, 3);
      final ids = draft.positionList.map((s) => s['id']).toList();
      expect(ids.first, 'step0001');
      expect(ids.last, 'step0002',
          reason: 'inserting a section renamed a step the children are '
              'scheduled against');
      expect(draft.sections[1].stepId, isNull);
      expect(draft.selected, 1,
          reason: 'the trainer is left standing on the section they just made');
    });

    test('a new section continues from the end of the line before it', () {
      // What makes show → ask one board with no reset on the child's screen.
      final draft = TutorialDraft.fromLesson(lesson());
      draft.selected = 0;
      final endOfLine = readStepTree(fen: openingFen, pgn: richPgn);
      var last = endOfLine.root;
      while (last.children.isNotEmpty) {
        last = last.children.first;
      }

      draft.addSection(continueFromEnd: true);
      expect(draft.sections[1].root.fen, last.fen);
      expect(draft.sections[1].root.children, isEmpty);
    });

    test('a new section can also start on a board of its own', () {
      final draft = TutorialDraft.fromLesson(lesson());
      draft.selected = 0;
      draft.addSection(continueFromEnd: false);
      expect(draft.sections[1].root.fen, TutorialDraft.startFen);
    });

    test('the last section cannot be removed', () {
      // `PUT` writes `position_list = NULL` for an empty list, so a tutorial
      // emptied here loses every step with nothing left to join on and
      // complain.
      final draft = TutorialDraft.fromLesson(lesson());
      expect(draft.removeSection(1), isTrue);
      expect(draft.removeSection(0), isFalse);
      expect(draft.sections.length, 1);
    });

    test('reordering moves the section and not just its name', () {
      final draft = TutorialDraft.fromLesson(lesson());
      draft.moveSection(0, 1);
      expect(draft.positionList.map((s) => s['id']).toList(),
          ['step0002', 'step0001']);
      expect(draft.sections.first.instruction, 'Nađi potez.',
          reason: 'the row moved but the work behind it did not');
    });

    test('a cloned section is a copy, not a second name for one step', () {
      final draft = TutorialDraft.fromLesson(lesson());
      draft.cloneSection(0);
      expect(draft.sections.length, 3);
      expect(draft.sections[1].stepId, isNull,
          reason: 'two sections carrying one step id is a child’s progress '
              'appearing in the wrong half of the tutorial');
      expect(draft.sections[1].root.children.first.comment,
          draft.sections[0].root.children.first.comment);

      // A copy, not a share: editing one must not edit the other.
      draft.sections[1].root.comment = 'Izmenjeno.';
      expect(draft.sections[0].root.comment, 'Pogledaj centar.');
    });

    test('a lesson with no steps opens as one empty section', () {
      final draft = TutorialDraft.fromLesson({
        'id': 5,
        'title': 'Prazna',
        'position_list': null,
      });
      expect(draft.sections.length, 1);
      expect(draft.sections.single.stepId, isNull);
    });
  });

  group('P2 — the local draft slot knows which tutorial it holds', () {
    test('a draft round-trips through its own json', () {
      final draft = TutorialDraft.fromLesson({
        'id': 12,
        'title': 'Opozicija',
        'position_list': [savedStep(id: 'step0001', pgn: richPgn)],
      });
      draft.sections.single.root.comment = 'Izmenjeno pre čuvanja.';

      final back = TutorialDraft.fromJson(draft.toJson());
      expect(back.lessonId, 12);
      expect(back.title, 'Opozicija');
      expect(back.sections.single.stepId, 'step0001');
      expect(back.sections.single.root.comment, 'Izmenjeno pre čuvanja.');
      expect(
          childBySan(back.sections.single.root, 'e4')!.arrows.single.toString(),
          'Ge2e4',
          reason: 'the local slot stores the tree, so an arrow drawn and not '
              'yet saved must survive closing the window');
    });

    test('a draft stored in the old shape still opens', () {
      // The slot held `{title, examples:[{fen, pgn}]}` until this work. A
      // trainer upgrading mid-tutorial must not lose it — and reading it is
      // free, because the converter this phase adds is exactly what it needs.
      final back = TutorialDraft.fromJson({
        'title': 'Stari nacrt',
        'examples': [
          {'fen': openingFen, 'pgn': richPgn, 'title': 'Primer 1'},
        ],
      });
      expect(back.lessonId, isNull);
      expect(back.title, 'Stari nacrt');
      expect(back.sections.single.title, 'Primer 1');
      expect(childBySan(back.sections.single.root, 'e4')!.comment,
          'Zauzima centar.');
    });
  });
}
