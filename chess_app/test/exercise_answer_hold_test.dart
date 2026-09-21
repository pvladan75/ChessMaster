// „Find the move": the trainer sees the move they played, and can take the
// answer back — item 8 of the owner's review of 21.9.2026, his suggestion on
// TODO-provera 196.3:
//
//   „neka se prikaže potez koji trener igra kao rešenje, ovako trener ne vidi
//   da je odigrao pravi potez na tabli. A onda neka se tabla vrati u početnu
//   poziciju posle 2 sekunde i nek traži da trener odigra alternativu ako je
//   ima. I neka postoji mogućnost da trener izbriše potez kao rešenje, ako
//   želi da promeni."
//
// Three rules, each a case below:
//
//  1. **The move stays on the board, marked, for [kExerciseAnswerHold]**, and
//     the board takes no move meanwhile; then it goes back to the position
//     and asks for another move. A move the reader refuses is not held — the
//     board goes straight back and the refusal is said, as before.
//  2. **The answer has a × like every alternative.** Taking it back makes the
//     first alternative the answer; taking back the only move leaves no
//     answer, and there is nothing to save.
//  3. **The same on a saved exercise**, where until now Save stayed on even
//     with no answer left to send.
//
// It supersedes, openly, two rules checked live (192.4, 196.3/198.4): „the
// main move has no ×" and „the board goes back after every move". The cases
// that held them were rewritten in the same change, with the reason above.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/exercises/models/exercise.dart';
import 'package:chess_app/features/exercises/models/exercise_line_edit.dart';
import 'package:chess_app/features/exercises/screens/exercise_editor_screen.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// The same fixture the editor's own gates read (rule 12), so this file and
/// they cannot disagree about what the scholar position is.
Map<String, dynamic> _fixture() {
  final file = File('../docs/gates/exercise_line_cases.json');
  if (!file.existsSync()) {
    throw StateError('the shared fixture is missing: ${file.absolute.path}');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final fixture = _fixture();
  final scholar = ((fixture['positions'] as Map)['scholar']) as String;

  Map<String, dynamic> savedRow(List<String> accept) => {
        'id': 'ex_find',
        'fen': scholar,
        'sideToMove': 'w',
        'name': 'Queen out early',
        'instruction': null,
        'themes': <String>[],
        'origin': 'manual',
        'task': {'type': 'find'},
        'solution': [
          {'accept': accept}
        ],
        'needsReview': false,
        'assignable': true,
        'blockedReason': null,
      };

  http.Client server(Map<String, dynamic> row) => MockClient((req) async {
        if (req.method == 'GET' && req.url.path == '/exercises/ex_find') {
          return http.Response(jsonEncode({'exercise': row}), 200);
        }
        return http.Response('{}', 404);
      });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: screen,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> making(WidgetTester tester) => pump(
        tester,
        ExerciseEditorScreen.make(
          api: ExerciseApiService(authToken: 'tok', client: server(const {})),
          fen: scholar,
        ),
      );

  Future<void> editing(WidgetTester tester, List<String> accept) => pump(
        tester,
        ExerciseEditorScreen(
          api: ExerciseApiService(
              authToken: 'tok', client: server(savedRow(accept))),
          exerciseId: 'ex_find',
        ),
      );

  ChessBoardWithOverlay board(WidgetTester tester) =>
      tester.widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));

  /// A move as the real board reports one: made on the controller first, so
  /// „the board shows it" has something to show.
  Future<void> play(WidgetTester tester, String from, String to) async {
    board(tester).controller.makeMove(from: from, to: to);
    board(tester).onMove(from, to, '');
    await tester.pump();
  }

  bool onPosition(WidgetTester tester) =>
      MoveTree.samePosition(board(tester).controller.getFen(), scholar);

  final save = find.byKey(const Key('exercise-editor-save'));
  VoidCallback? saveAction(WidgetTester tester) =>
      tester.widget<FilledButton>(save).onPressed;

  group('1: the move is shown before the board goes back', () {
    testWidgets(
        'the answer stays on the board, marked, then the board asks '
        'for another', (tester) async {
      await making(tester);
      await play(tester, 'd1', 'h5');

      expect(onPosition(tester), isFalse,
          reason: 'the trainer never sees the move they played');
      expect(board(tester).lastMoveFrom, 'd1');
      expect(board(tester).lastMoveTo, 'h5');
      expect(board(tester).isAllowedToMove, isFalse,
          reason: 'a second move during the hold would be played on top of '
              'the first');
      expect(find.textContaining('Qh5 is the answer'), findsOneWidget);

      // Still there just short of the owner's two seconds. Without this the
      // case could not tell a hold from none: `pump()` fires no timer, not
      // even a zero-length one, so a hold of nothing passed (mutation M1).
      await tester.pump(const Duration(milliseconds: 1900));
      expect(onPosition(tester), isFalse,
          reason: 'the move was taken off the board before two seconds');
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(onPosition(tester), isTrue,
          reason: 'the board did not go back to the position');
      expect(board(tester).lastMoveFrom, isNull);
      expect(board(tester).isAllowedToMove, isTrue);
      expect(find.text('Play another move that should also count, or Save.'),
          findsOneWidget);
    });

    testWidgets('an alternative is shown the same way', (tester) async {
      await making(tester);
      await play(tester, 'd1', 'h5');
      await tester.pump(kExerciseAnswerHold);
      await play(tester, 'd1', 'f3');

      expect(onPosition(tester), isFalse);
      expect(find.textContaining('Qf3 is accepted as well'), findsOneWidget);
      await tester.pump(kExerciseAnswerHold);
      await tester.pump();
      expect(onPosition(tester), isTrue);
    });

    testWidgets('a refused move is not held: the board goes straight back',
        (tester) async {
      await making(tester);
      await play(tester, 'd1', 'h5');
      await tester.pump(kExerciseAnswerHold);
      // The same move twice is refused by the reader.
      await play(tester, 'd1', 'h5');

      expect(onPosition(tester), isTrue,
          reason: 'a refused move was held as if it counted');
      expect(board(tester).isAllowedToMove, isTrue);
      expect(find.byKey(const Key('exercise-editor-error')), findsOneWidget);
    });

    testWidgets('leaving during the hold leaves nothing running',
        (tester) async {
      // A timer that outlives its screen is a test that fails at teardown —
      // and in the app, a `setState` on a screen that is gone.
      await making(tester);
      await play(tester, 'd1', 'h5');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(kExerciseAnswerHold);
      expect(tester.takeException(), isNull);
    });
  });

  group('2: the answer can be taken back', () {
    test('taking the answer back makes the first alternative the answer', () {
      final edit = ExerciseLineEdit(fen: scholar, steps: const [
        ExerciseStep(accept: ['Qh5', 'Qf3'])
      ]);
      expect(edit.remove('Qh5'), isTrue);
      expect(edit.steps.single.accept, ['Qf3']);
    });

    test('taking back the only move leaves no answer', () {
      final edit = ExerciseLineEdit(fen: scholar, steps: const [
        ExerciseStep(accept: ['Qh5'])
      ]);
      expect(edit.remove('Qh5'), isTrue);
      expect(edit.steps, isEmpty);
      expect(edit.error, isNull, reason: 'taking a move back is not an error');
      expect(edit.remove('Qh5'), isFalse, reason: 'nothing left to take');
    });

    testWidgets('while making: the answer has a ×, and the next move leads',
        (tester) async {
      await making(tester);
      await play(tester, 'd1', 'h5');
      await tester.pump(kExerciseAnswerHold);
      await play(tester, 'd1', 'f3');
      await tester.pump(kExerciseAnswerHold);
      await tester.pump();

      final answerChip = find.byKey(const Key('exercise-editor-remove-Qh5'));
      expect(answerChip, findsOneWidget, reason: 'the answer has no ×');
      await tester.ensureVisible(answerChip);
      await tester.tap(answerChip);
      await tester.pumpAndSettle();

      expect(
          tester
              .widget<Text>(find.byKey(const Key('exercise-editor-line')))
              .data,
          'Qf3');
      expect(saveAction(tester), isNotNull);

      await tester.tap(find.byKey(const Key('exercise-editor-remove-Qf3')));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const Key('exercise-editor-making-hint')), findsOneWidget,
          reason: 'with no answer left the screen asks for one again');
      expect(saveAction(tester), isNull, reason: 'nothing left to save');
    });
  });

  group('3: a saved exercise', () {
    testWidgets('the answer has a × and the alternative takes its place',
        (tester) async {
      await editing(tester, ['Qh5', 'Qf3']);
      await tester.tap(find.byKey(const Key('exercise-editor-remove-Qh5')));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Text>(find.byKey(const Key('exercise-editor-line')))
              .data,
          'Qf3');
      expect(saveAction(tester), isNotNull);
    });

    testWidgets('with no answer left, Save is off', (tester) async {
      // Until 21.9.2026 Save on a saved exercise was always on, which was
      // harmless while the answer could not be taken out.
      await editing(tester, ['Qh5']);
      expect(saveAction(tester), isNotNull);
      await tester.tap(find.byKey(const Key('exercise-editor-remove-Qh5')));
      await tester.pumpAndSettle();
      expect(saveAction(tester), isNull,
          reason: 'an exercise with no answer could be sent to be saved');
    });
  });
}
