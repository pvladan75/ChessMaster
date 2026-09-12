/// Phase 2 of `docs/PLAN-PGN-TUTORIJAL.md`: questions where the review marked
/// a blunder.
///
/// The fixture is the shape „Review entire game" actually writes — a `??` on the
/// move played and a `!` on the engine's line beside it — because that is the
/// only input this feature will ever have.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/pgn_game_import.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart'
    show endOfMainLine;
import 'package:chess_app/features/tutorial_studio/services/pgn_question_split.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';

void main() {
  /// One blunder, on move three, with the engine's move beside it.
  const oneBlunder = '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4?? '
      '(3... Bc5! { Better move } 4. O-O) 4. Nxe5 Qg5 *';

  /// Two, far enough apart to be two questions.
  const twoBlunders = '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4?? '
      '(3... Bc5! { Better move } 4. O-O) 4. Nxe5 Qg5 5. Nxf7?? '
      '(5. Bxf7+! { Better move } Ke7) Qxg2 *';

  TutorialSection sectionOf(String pgn) =>
      TutorialSection.fromStep(tutorialFromGame(pgn).positionList.single);

  group('where a question is made', () {
    test('a game with no marks stays one demonstration', () {
      final parts = sectionsWithQuestions(sectionOf('1. e4 e5 2. Nf3 *'));
      expect(parts, hasLength(1));
      expect(parts.single.kind, LessonStepKind.show);
    });

    test('a blunder with no better move beside it is not a question', () {
      // A `??` on its own is a move somebody disapproved of; the answer has to
      // come from somewhere, and the sideline is where the engine put it.
      final parts = sectionsWithQuestions(
          sectionOf('1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4?? *'));
      expect(parts, hasLength(1));
      expect(parts.single.kind, LessonStepKind.show);
    });

    test('an unmarked sideline is not an answer', () {
      // Found by mutation: „any sibling will do" passed every test above,
      // because none of them had a sideline that was not the engine's. A
      // trainer's own variation is a line they were looking at — offering its
      // first move to a child as the correct answer is the app asserting
      // something nobody said.
      final parts = sectionsWithQuestions(sectionOf(
          '1. e4 e5 2. Nf3 Nc6 3. Bc4 Nd4?? (3... a6 { Just looking }) 4. Nxe5 *'));

      expect(parts, hasLength(1));
      expect(parts.single.kind, LessonStepKind.show);
    });

    test('one blunder becomes demonstration, question, continuation', () {
      final parts = sectionsWithQuestions(sectionOf(oneBlunder));

      expect(parts.map((p) => p.kind).toList(), [
        LessonStepKind.show,
        LessonStepKind.askMove,
        LessonStepKind.show,
      ]);
    });

    test('the question stands on the position before the blunder', () {
      final parts = sectionsWithQuestions(sectionOf(oneBlunder));
      final demo = parts[0];
      final question = parts[1];

      // The join the viewer tests for: the demonstration ends where the
      // question begins, so the child's board is not rebuilt under them.
      expect(question.root.fen, endOfMainLine(demo.root).fen);
    });

    test('the answer is the engine move, not the move that was played', () {
      final parts = sectionsWithQuestions(sectionOf(oneBlunder));
      expect(parts[1].solutionSan, 'Bc5');
      expect(parts[1].solutionSan, isNot('Nd4'));
    });

    test('the continuation carries on with the game', () {
      // The move played is what happened; a tutorial about your own game must
      // not silently continue with a game you did not play.
      final parts = sectionsWithQuestions(sectionOf(oneBlunder));
      final continuation = parts[2];
      expect(continuation.root.children.first.moveSan, 'Nd4');
      // …and the engine's line is still there, as a sideline under it.
      expect(continuation.root.children.map((c) => c.moveSan), contains('Bc5'));
    });

    test('two blunders become two questions', () {
      final parts = sectionsWithQuestions(sectionOf(twoBlunders));
      final asked = parts.where((p) => p.kind == LessonStepKind.askMove);

      expect(asked, hasLength(2));
      expect(asked.map((p) => p.solutionSan).toList(), ['Bc5', 'Bxf7+']);
    });

    test('the ceiling is honoured', () {
      final parts =
          sectionsWithQuestions(sectionOf(twoBlunders), maxQuestions: 1);
      expect(
          parts.where((p) => p.kind == LessonStepKind.askMove), hasLength(1));
    });

    test('a ceiling of zero leaves the game alone', () {
      final parts =
          sectionsWithQuestions(sectionOf(twoBlunders), maxQuestions: 0);
      expect(parts, hasLength(1));
      expect(parts.single.kind, LessonStepKind.show);
    });

    test('the same blunder is not asked about twice', () {
      // The continuation opens with the move the question was about, so a
      // search that started at its first ply would find it again — for ever.
      final parts = sectionsWithQuestions(sectionOf(oneBlunder));
      final asked =
          parts.where((p) => p.kind == LessonStepKind.askMove).toList();
      expect(asked, hasLength(1));
      expect(parts.length, lessThan(5));
    });
  });

  group('what the child is asked', () {
    test('the sentence names the move and claims nothing about uniqueness', () {
      final parts = sectionsWithQuestions(sectionOf(oneBlunder));
      final asked = parts[1].instruction!;

      expect(asked, contains('Nd4'));
      // The fault the experiment caught: „the only move" is a claim the import
      // cannot check, and a child who finds a different good move is told they
      // are wrong.
      expect(asked.toLowerCase(), isNot(contains('only')));
      expect(asked.toLowerCase(), isNot(contains('best move')));
    });

    test('it names the side that actually moved', () {
      expect(askingSentence(fen: standardStartFen, playedSan: 'e4'),
          startsWith('White played e4'));
      const blackToMove =
          'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';
      expect(askingSentence(fen: blackToMove, playedSan: 'f5'),
          startsWith('Black played f5'));
    });

    test('it reads as one sentence a voice can say', () {
      final asked =
          sectionsWithQuestions(sectionOf(oneBlunder))[1].instruction!;
      // The format contract asks for 40 to 140 characters; it is read aloud to
      // a child and drawn under the board.
      expect(asked.length, inInclusiveRange(40, 140));
    });
  });

  group('the tutorial that comes out', () {
    test('is clean by the app.s own reader', () {
      final imported = withQuestionsFromBlunders(tutorialFromGame(oneBlunder));

      expect(imported.problems, isEmpty,
          reason: imported.problems.map((p) => p.sentence).join(' | '));
      expect(imported.clean, isTrue);
      expect(imported.storable, isTrue);
    });

    test('the question carries no line for the child to read the answer off',
        () {
      // Rule 9 of the format contract, and the one the studio refuses to save:
      // the viewer draws the move strip for every kind.
      final imported = withQuestionsFromBlunders(tutorialFromGame(oneBlunder));
      final question =
          imported.positionList.firstWhere((s) => s['kind'] == 'ask_move');

      expect(question['pgn'] ?? '', isEmpty);
      expect(question['solutionSan'], 'Bc5');
    });

    test('no part carries an id', () {
      // Two parts cut from one step must never share one: a step id resolves a
      // schedule row and a recorded answer.
      final imported = withQuestionsFromBlunders(tutorialFromGame(oneBlunder));
      expect(imported.positionList.any((s) => s.containsKey('id')), isFalse);
    });

    test('every part is named, and a question is named by what it asks', () {
      // The app names a part by its first sentence and falls back to „Part N"
      // — `TutorialSection.label`, which is the same function the parts list
      // and the child's viewer read. A question's first sentence is the
      // question, so that is its name; the demonstrations here carry no
      // sentence, so they are numbered.
      final imported = withQuestionsFromBlunders(tutorialFromGame(twoBlunders));
      final titles = imported.positionList.map((s) => s['title']).toList();

      expect(titles, hasLength(5));
      expect(titles.toSet(), hasLength(5), reason: 'no two parts share a name');
      expect(titles.where((t) => '$t'.startsWith('Part ')), hasLength(3));
      for (final step in imported.positionList) {
        if (step['kind'] == 'ask_move') {
          expect(step['title'],
              startsWith(step['instruction'].toString().split('.').first));
        }
      }
    });

    test('a game with nothing to ask about comes back as it went in', () {
      final plain = tutorialFromGame('1. e4 e5 2. Nf3 *');
      final imported = withQuestionsFromBlunders(plain);

      expect(imported.positionList, hasLength(1));
      expect(imported.title, plain.title);
      expect(imported.positionList.single['pgn'],
          plain.positionList.single['pgn']);
    });

    test('a file that could not be read is handed back untouched', () {
      final broken = ImportedTutorial.unreadable('not a PGN at all');
      expect(withQuestionsFromBlunders(broken), same(broken));
    });

    test('the count is reported before anything is cut', () {
      // What the import dialog says to the trainer before they choose.
      expect(questionsAvailableIn(tutorialFromGame(twoBlunders)), 2);
      expect(questionsAvailableIn(tutorialFromGame('1. e4 e5 *')), 0);
      expect(
          questionsAvailableIn(tutorialFromGame(twoBlunders), maxQuestions: 1),
          1);
    });
  });
}
