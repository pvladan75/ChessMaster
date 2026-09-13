// Phase 4 of `docs/PLAN-PGN-TUTORIJAL.md`: a tutorial back out as PGN.
//
// The one question this file exists for is **where the file is cut**. Parts
// that continue one another are one game; a part that opens on a board of its
// own starts a new one. Everything about how a game is *written* belongs to
// `PgnExporterService`, which has its own tests — what is asserted here is what
// ends up in which game, and that what comes out can be read back in by the
// import this plan's phase 1 built.

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/analysis_studio/services/pgn_file_saver.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/pgn_game_import.dart';
import 'package:chess_app/features/tutorial_studio/services/pgn_question_split.dart';
import 'package:chess_app/features/tutorial_studio/services/pgn_tutorial_export.dart';
import 'package:chess_app/features/tutorial_studio/services/section_split.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';

const String startFen =
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// A rook ending, unrelated to anything that starts from the opening position.
const String endingFen = '6k1/5pp1/7p/8/8/8/5PPP/R5K1 w - - 0 1';

TutorialSection part({
  required String fen,
  String? pgn,
  String kind = 'show',
  String title = '',
  String? instruction,
  String? solutionSan,
}) =>
    TutorialSection.fromStep({
      'fen': fen,
      if (pgn != null) 'pgn': pgn,
      'kind': kind,
      'title': title,
      if (instruction != null) 'instruction': instruction,
      if (solutionSan != null) 'solutionSan': solutionSan,
    });

TutorialDraft draftOf(List<TutorialSection> sections,
        {String title = 'Test'}) =>
    TutorialDraft(title: title, sections: sections);

void main() {
  group('where the file is cut', () {
    test('parts that continue one another are one game', () {
      final a = part(fen: startFen, pgn: '1. e4 e5 *');
      // Exactly the way „Novi prikaz odavde" builds the next part: on the
      // position the line in front ran out at.
      final b = part(fen: endOfMainLine(a.root).fen, pgn: '2. Nf3 Nc6 *');

      final games = pgnGamesOfTutorial(draftOf([a, b]));

      expect(games, hasLength(1));
      expect(games.single, contains('1. e4 e5 2. Nf3 Nc6'));
      // One game from the opening position needs no starting position written
      // out; it is where every game starts.
      expect(games.single, isNot(contains('[FEN')));
    });

    test('a part on a board of its own starts a new game', () {
      final a = part(fen: startFen, pgn: '1. e4 e5 *');
      final b = part(fen: endingFen, pgn: '1. Ra8+ Kh7 *');

      final games = pgnGamesOfTutorial(draftOf([a, b]));

      expect(games, hasLength(2));
      expect(games[0], contains('1. e4 e5'));
      expect(games[1], contains('[SetUp "1"]'));
      expect(games[1], contains('[FEN "$endingFen"]'));
      expect(games[1], contains('Ra8+'));
      // And the second game is not glued to the first: a reader that cannot
      // tell them apart has one game with an illegal move in it.
      expect(games[0], isNot(contains('Ra8+')));
    });

    test('the join ignores the two counters nobody can see', () {
      // `MoveTree.samePosition` compares placement, side to move, castling and
      // en passant — not the halfmove clock or the move number. A part written
      // from a FEN typed by hand routinely disagrees about those, and it is the
      // same board.
      final a = part(fen: startFen, pgn: '1. e4 e5 *');
      final end = endOfMainLine(a.root).fen;
      final fields = end.split(' ');
      final restated = '${fields.take(4).join(' ')} 9 30';
      final b = part(fen: restated, pgn: '2. Nf3 *');

      expect(pgnGamesOfTutorial(draftOf([a, b])), hasLength(1));
    });

    test('three parts, a break in the middle, are two games', () {
      final a = part(fen: startFen, pgn: '1. e4 e5 *');
      final b = part(fen: endingFen, pgn: '1. Ra8+ *');
      final c = part(fen: endOfMainLine(b.root).fen, pgn: '1... Kh7 *');

      final games = pgnGamesOfTutorial(draftOf([a, b, c]));

      expect(games, hasLength(2));
      expect(games[1], contains('Ra8+'));
      expect(games[1], contains('Kh7'));
    });

    test('a tutorial of one bare diagram is still a game', () {
      final games = pgnGamesOfTutorial(draftOf([
        part(fen: endingFen, pgn: '{ Look at the a-file. } *'),
      ]));

      expect(games, hasLength(1));
      expect(games.single, contains('Look at the a-file.'));
      expect(games.single, contains('[FEN "$endingFen"]'));
    });
  });

  group('what a game carries', () {
    test('a question cut by phase 2 comes back out as one game', () {
      // The shape `splitForQuestion` makes: demonstration, a bare position that
      // asks, and the continuation. All three stand on positions that join, so
      // the game the trainer imported is the game that leaves.
      final imported = tutorialsFromPgn(
        '[Event "Game"]\n[White "A"]\n[Black "B"]\n\n'
        '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4?? (3... Bc5! { Better } 4. O-O) '
        '4. Nxe5 *',
        fileName: 'game.pgn',
      ).single;
      final withQuestions = withQuestionsFromBlunders(imported);
      expect(withQuestions.positionList.length, greaterThan(1),
          reason: 'the fixture must actually have been cut');

      final draft = draftOf([
        for (final step in withQuestions.positionList)
          TutorialSection.fromStep(step),
      ]);
      final games = pgnGamesOfTutorial(draft);

      expect(games, hasLength(1));

      // Read back rather than matched as a string: the question's sentence
      // stands between `Bc4` and `Nd4`, which is where it belongs and which no
      // substring of the move text can confirm.
      final read = readStepTree(fen: startFen, pgn: games.single);
      final mainLine = <String>[];
      var node = read.root;
      while (node.children.isNotEmpty) {
        node = node.children.first;
        mainLine.add(node.moveSan ?? '');
      }
      expect(mainLine, ['e4', 'e5', 'Nf3', 'Nc6', 'Bc4', 'Nd4', 'Nxe5'],
          reason: 'the game that was imported is the game that leaves');

      final bc4 = read.root.children.first.children.first.children.first
          .children.first.children.first;
      expect(bc4.moveSan, 'Bc4');
      expect(bc4.comment, contains('What should Black have played instead?'));
      // The engine's line is still a sideline under the blunder's position, as
      // it was in the game.
      expect(bc4.children.map((c) => c.moveSan), containsAll(['Nd4', 'Bc5']));
    });

    test('the task travels as the sentence it is', () {
      final a = part(fen: startFen, pgn: '1. e4 e5 *');
      final b = part(
        fen: endOfMainLine(a.root).fen,
        kind: 'ask_move',
        instruction: 'What should White play here?',
        solutionSan: 'Nf3',
      );

      final text = pgnGamesOfTutorial(draftOf([a, b])).single;

      expect(text, contains('What should White play here?'));
      // What it asks, and the answer it would accept, have no home in a PGN —
      // and must not be invented one. A move nobody played written into the
      // game is a different game.
      expect(text, isNot(contains('ask_move')));
      expect(text, isNot(contains('Nf3')));
    });

    test('a task is written beside a note about the position, not over it', () {
      final text = pgnGamesOfTutorial(draftOf([
        part(
          fen: endingFen,
          pgn: '{ The rook is the strongest piece here. } *',
          kind: 'ask_move',
          instruction: 'Find the check.',
        ),
      ])).single;

      expect(text, contains('The rook is the strongest piece here.'));
      expect(text, contains('Find the check.'));
    });

    test("a joined part's own sentence lands on the position it describes", () {
      final a = part(fen: startFen, pgn: '1. e4 e5 *');
      final b = part(
        fen: endOfMainLine(a.root).fen,
        pgn: '{ Both sides have taken the centre. } 2. Nf3 *',
      );

      final text = pgnGamesOfTutorial(draftOf([a, b])).single;

      // Read back through the parser rather than judged by where the sentence
      // stands in the string: „before Nf3" and „after e5" are the same place in
      // a text and different nodes in a tree, and the „Tok" gate has already
      // been fooled by exactly that once.
      final read = readStepTree(fen: startFen, pgn: text);
      final e5 = read.root.children.first.children.first;
      expect(e5.moveSan, 'e5');
      expect(e5.comment, contains('Both sides have taken the centre.'));
    });

    test('a drawing that both parts carry is drawn once', () {
      // `splitForQuestion` copies the cursor's arrows onto the question it
      // makes, because the board does not reload across the join and a circle
      // that vanished there would be a flicker. So the two parts either side of
      // a join hold the same arrow, and writing both would put it in the file
      // twice — on every question this app has ever cut.
      final whole =
          part(fen: startFen, pgn: '1. e4 { [%cal Ge2e4][%csl Rd5] } e5 *');
      final cursor = whole.root.children.first;
      final parts = splitForQuestion(whole, cursor);
      expect(parts.length, greaterThan(1));

      final text = pgnGamesOfTutorial(draftOf(parts)).single;

      expect(RegExp(r'\[%cal Ge2e4\]').allMatches(text), hasLength(1));
      // Written as the arrow's twin: a coloured square is copied across the
      // join by the same line of `splitForQuestion`, and a pair fixed by halves
      // is how the rank numbers spent two days invisible after the file letters
      // were put right.
      expect(RegExp(r'\[%csl Rd5\]').allMatches(text), hasLength(1));
    });

    test('the assessments and the drawings survive', () {
      final text = pgnGamesOfTutorial(draftOf([
        part(fen: startFen, pgn: '1. e4?! { [%cal Ge2e4] } e5 *'),
      ])).single;

      expect(text, contains('e4?!'));
      expect(text, contains('[%cal Ge2e4]'));
    });
  });

  group('the headers', () {
    test('the tutorial name is the event', () {
      final text = pgnGamesOfTutorial(
        draftOf([part(fen: startFen, pgn: '1. e4 *')], title: 'Opposition'),
      ).single;

      expect(text, contains('[Event "Opposition"]'));
      // „Analysis Studio Session" is what this app stamps on an analysis, and
      // `titleOf` refuses it as a title for exactly that reason.
      expect(text, isNot(contains('Analysis Studio Session')));
      // Nobody played this. „Player" against „Analysis Engine" would read as
      // two people who did.
      expect(text, contains('[White "?"]'));
      expect(text, contains('[Black "?"]'));
    });

    test('an unnamed tutorial says so rather than borrowing a name', () {
      final text = pgnGamesOfTutorial(
        draftOf([part(fen: startFen, pgn: '1. e4 *')], title: ''),
      ).single;

      expect(text, contains('[Event "Tutorial"]'));
    });

    test('games of one tutorial are numbered', () {
      final several = pgnGamesOfTutorial(draftOf([
        part(fen: startFen, pgn: '1. e4 *'),
        part(fen: endingFen, pgn: '1. Ra8+ *'),
      ]));
      expect(several[0], contains('[Round "1"]'));
      expect(several[1], contains('[Round "2"]'));
    });
  });

  group('the file', () {
    test('reads back as the games it was written as', () {
      // The strongest thing available: the import this plan's phase 1 built is
      // the reader, so a file that does not come back is a file that was not
      // written.
      final a = part(fen: startFen, pgn: '1. e4 e5 *');
      final draft = draftOf([
        a,
        part(fen: endOfMainLine(a.root).fen, pgn: '2. Nf3 Nc6 *'),
        part(fen: endingFen, pgn: '1. Ra8+ Kh7 *'),
      ], title: 'Two lessons');

      final text = pgnFileOfTutorial(draft);
      final read = tutorialsFromPgn(text, fileName: 'two-lessons.pgn');

      expect(read, hasLength(2));
      for (final tutorial in read) {
        expect(tutorial.problems, isEmpty,
            reason: 'a game this app wrote must replay in this app: '
                '${tutorial.problems.map((p) => p.sentence).toList()}');
        expect(tutorial.clean, isTrue);
      }
      expect(read[0].positionList.single['pgn'], contains('Nc6'));
      expect(read[1].positionList.single['fen'], endingFen);
    });

    test('the games are separated the way the splitter reads them', () {
      final text = pgnFileOfTutorial(draftOf([
        part(fen: startFen, pgn: '1. e4 *'),
        part(fen: endingFen, pgn: '1. Ra8+ *'),
      ]));

      expect(pgnGamesOf(text), hasLength(2));
    });
  });

  group('the draft is not touched', () {
    test('an export changes neither the trees nor what they hold', () {
      final a = part(fen: startFen, pgn: '1. e4 e5 *');
      final b = part(
        fen: endOfMainLine(a.root).fen,
        kind: 'ask_move',
        instruction: 'What now?',
      );
      final draft = draftOf([a, b]);
      final before = [for (final s in draft.sections) treeSignature(s.root)];
      final idBefore = a.root.id;

      pgnFileOfTutorial(draft);

      expect([for (final s in draft.sections) treeSignature(s.root)], before,
          reason: 'grafting one part onto another must happen on copies');
      expect(a.root.id, idBefore);
      expect(a.root.children.single.moveSan, 'e4');
      // The task was written onto a copy's root, not onto the part the trainer
      // is still editing.
      expect(b.root.comment, isEmpty);
      expect(b.kind, LessonStepKind.askMove);
    });
  });

  group('what the file is called', () {
    test('the tutorial names it', () {
      expect(tutorialPgnFileName('Opposition', DateTime(2026, 9, 13)),
          'Opposition.pgn',
          reason: 'the trainer named it; a file name is not the place to '
              'restyle their words');
      expect(tutorialPgnFileName('Kralj i pešak', DateTime(2026, 9, 13)),
          'Kralj-i-pešak.pgn',
          reason: 'the app writes UTF-8 names everywhere else');
    });

    test('a name a file system refuses is not offered to the picker', () {
      final name =
          tutorialPgnFileName('Mat: "Anastasia" / 2?', DateTime(2026, 9, 13));
      expect(name, isNot(contains(RegExp(r'[\\/:*?"<>|]'))));
      expect(name, endsWith('.pgn'));
    });

    test('an unnamed tutorial falls back to the date', () {
      expect(tutorialPgnFileName('   ', DateTime(2026, 9, 2)),
          'tutorial-2026-09-02.pgn');
    });

    test('a sentence for a title is cut to a length a file system takes', () {
      final name = tutorialPgnFileName('word ' * 40, DateTime(2026, 9, 13));
      expect(name.length, lessThanOrEqualTo(64));
    });
  });
}
