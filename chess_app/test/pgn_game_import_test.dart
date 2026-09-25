/// Phase 1 of `docs/PLAN-PGN-TUTORIJAL.md`: a PGN becomes tutorial parts.
///
/// The reader is `readStepTree` and the judge is `problemsWithStep`, both of
/// which are already tested where they live. What is tested here is the two
/// questions those cannot answer — where one game ends and the next begins, and
/// what the tutorial is called — plus the join to them, because a reader that is
/// right and reached wrongly is the fault this repository keeps finding.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/services/pgn_game_import.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';

void main() {
  const oneGame = '''
[Event "Rated blitz game"]
[Site "https://lichess.org/abcd1234"]
[Date "2026.07.03"]
[White "pvladan"]
[Black "Opponent"]
[Result "0-1"]

1. e4 e5 2. Nf3 Nc6 3. Bc4 Be7 4. c3 Nf6 5. d4 exd4 0-1
''';

  const reviewed = '''
[Event "Analysis Studio Session"]
[Site "Chess trainer"]
[Date "2026.09.12"]
[White "Player"]
[Black "Analysis Engine"]
[Result "*"]

1. e4 { White takes the centre. [%csl Ge4] } e5 2. Nf3 Nc6 3. Bc4 Nd4?? (3... Bc5! { Better move } 4. O-O) 4. Nxe5 *
''';

  group('splitting a file into games', () {
    test('one game is one game', () {
      expect(pgnGamesOf(oneGame), hasLength(1));
    });

    test('two games are two, cut at the header boundary', () {
      final games = pgnGamesOf('$oneGame\n$reviewed');
      expect(games, hasLength(2));
      expect(games.first, contains('lichess.org'));
      expect(games.last, contains('Nd4??'));
    });

    test('a bare movetext with no headers is still a game', () {
      // The commonest thing anybody pastes.
      expect(pgnGamesOf('1. e4 e5 2. Nf3'), ['1. e4 e5 2. Nf3']);
    });

    test('prose in front of the first header is dropped', () {
      final games = pgnGamesOf('Evo moje partije, pogledaj:\n\n$oneGame');
      expect(games, hasLength(1));
      expect(games.single, startsWith('[Event '));
    });

    test('an empty text holds no games', () {
      expect(pgnGamesOf('   \n  '), isEmpty);
    });
  });

  group('the moves, and where they start', () {
    test(
        'the header block comes off and the text ends the way the contract asks',
        () {
      final moves = moveTextOf('[Event "x"]\n[White "a"]\n\n1. e4 e5');
      expect(moves, '1. e4 e5 *');
    });

    test('a result already written is left alone', () {
      // Rewriting `0-1` as `*` would tell a reader the game was unfinished.
      expect(moveTextOf(oneGame), endsWith('0-1'));
    });

    test('a comment holding an arrow is not mistaken for a header', () {
      // `[%csl ...]` is bracketed and lives inside a comment; the header
      // pattern rules it out by its second character, and this is the test that
      // says so.
      final moves = moveTextOf(reviewed);
      expect(moves, contains('[%csl Ge4]'));
      expect(moves, isNot(contains('[Event')));
    });

    test('a game with a FEN header starts there', () {
      const endgame =
          '[SetUp "1"]\n[FEN "8/8/8/8/8/5k2/6p1/6K1 w - - 0 1"]\n\n1. Kh2 g1=Q+';
      final tutorial = tutorialFromGame(endgame);
      expect(tutorial.positionList.single['fen'],
          '8/8/8/8/8/5k2/6p1/6K1 w - - 0 1');
      expect(tutorial.problems, isEmpty, reason: 'the line replays from there');
    });

    test('a game with no FEN header starts from the opening position', () {
      final tutorial = tutorialFromGame('1. e4 e5 2. Nf3');
      expect(tutorial.positionList.single['fen'], standardStartFen);
      expect(tutorial.clean, isTrue);
    });
  });

  group('the title', () {
    test('is the players when the file says who they were', () {
      expect(titleOf(oneGame), 'pvladan - Opponent (2026.07.03)');
    });

    test('is not the stamp this app puts on every export', () {
      // „Player" against „Analysis Engine" is what `PgnExporterService` writes
      // whatever is on the board: a title built from it reads the same for
      // every game a trainer ever imported.
      final title = titleOf(reviewed, fileName: 'my-games.pgn');
      expect(title, isNot(contains('Analysis Engine')));
      expect(title.toLowerCase(), contains('my games'));
    });

    test('numbers the games when a file holds several', () {
      final tutorials =
          tutorialsFromPgn('$reviewed\n$reviewed', fileName: 'batch.pgn');
      expect(tutorials, hasLength(2));
      expect(tutorials[0].title, endsWith('1'));
      expect(tutorials[1].title, endsWith('2'));
    });

    test('does not number a file that holds one game', () {
      final tutorials = tutorialsFromPgn(reviewed, fileName: 'batch.pgn');
      expect(tutorials.single.title, isNot(endsWith('1')));
    });
  });

  group('what comes out is what the rest of the app already reads', () {
    test('one line is one part, not one part per comment', () {
      // An annotated game is one continuous line and the viewer narrates it
      // move by move; a part per comment is a transcript with a page-turn
      // between every sentence.
      //
      // Superseded in part 26.9.2026 by D2 of `docs/PLAN-MAPA-DELOVA.md`:
      // this case asserted one part for [reviewed], whose `(3... Bc5! …)` the
      // film never showed. A side line is a part of its own now — up to the
      // fork, the side line, the game going on — and still not a part per
      // comment.
      final tutorial = tutorialFromGame(reviewed);
      expect(tutorial.positionList, hasLength(3));
      for (final part in tutorial.positionList) {
        expect(part['kind'] ?? 'show', 'show');
      }
      expect(tutorial.problems, isEmpty);
    });

    test('a game with no side line is one part, its text as it came', () {
      final tutorial = tutorialFromGame(oneGame);
      expect(tutorial.positionList, hasLength(1));
      expect(tutorial.positionList.single['kind'], 'show');
      expect(tutorial.positionList.single['title'], 'Part 1');
    });

    test('the comments, the arrows and the assessment all travel', () {
      // Across the parts: the side line is re-written by the app's own writer
      // when it becomes a part, and what a reader reads must survive that.
      final pgn = tutorialFromGame(reviewed)
          .positionList
          .map((p) => p['pgn'] as String)
          .join(' ');
      expect(pgn, contains('White takes the centre.'));
      expect(pgn, contains('[%csl Ge4]'));
      expect(pgn, contains('Nd4??'), reason: 'phase 2 reads this mark');
      expect(pgn, contains('Bc5!'));
      expect(pgn, contains('Better move'));
    });

    test('a line that does not replay is reported, not silently shortened', () {
      // A game whose header FEN belongs to a different position: the whole
      // point of asking the child's own reader before anything is saved.
      const wrong = '[SetUp "1"]\n[FEN "8/8/8/8/8/5k2/6p1/6K1 w - - 0 1"]\n\n'
          '1. e4 e5 2. Nf3';
      final tutorial = tutorialFromGame(wrong);
      expect(tutorial.problems, isNotEmpty);
      expect(tutorial.problems.first.fault, ImportFault.damaged);
      expect(tutorial.openable, isTrue,
          reason: 'a trainer can see what is wrong with it better than we can');
    });

    test('a game with no moves is refused with a reason', () {
      final tutorial = tutorialFromGame('[Event "x"]\n[White "a"]\n');
      expect(tutorial.openable, isFalse);
      expect(tutorial.problems.single.message, contains('no moves'));
    });

    test('one broken game does not take the others down', () {
      const broken = '[Event "x"]\n[SetUp "1"]\n'
          '[FEN "8/8/8/8/8/5k2/6p1/6K1 w - - 0 1"]\n\n1. e4 e5 *';
      // A blank line in front of `[Event` is what makes a boundary, and the
      // fixture has to write one: this is a file as an editor would hold it,
      // not three strings glued together.
      final tutorials = tutorialsFromPgn('$oneGame\n$broken\n\n$reviewed',
          fileName: 'mixed.pgn');

      expect(tutorials, hasLength(3));
      expect(tutorials[0].clean, isTrue);
      expect(tutorials[1].clean, isFalse);
      expect(tutorials[2].clean, isTrue);
    });

    test('the labels the trainer chose reach every game', () {
      final tutorials =
          tutorialsFromPgn('$oneGame\n$reviewed', tags: ['my games']);
      expect(tutorials.map((t) => t.tags), everyElement(contains('my games')));
    });

    test('no step carries an id', () {
      // A step id resolves a schedule row and a recorded answer; the server
      // mints them. Same rule the JSON import already follows.
      final tutorial = tutorialFromGame(oneGame);
      expect(tutorial.positionList.single.containsKey('id'), isFalse);
      expect(tutorial.asLesson.containsKey('id'), isFalse);
    });
  });
}
