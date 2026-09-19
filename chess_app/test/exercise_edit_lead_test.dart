// exercise_edit_lead_test.dart — what phase 11's gate could not see
// (`docs/PLAN-EXERCISE.md`), found by grading and by mutation, 19.9.2026.
//
// 1. The gate's game exercise had Black to move *and* Black as the student,
//    so a board turned by the side to move passed it. A game's side is the
//    task's own: here White is to move and the student is Black.
// 2. „The main move cannot be removed" stood on the scholar line, where
//    removing Qh5 leaves a line that no longer replays — the *reader* refused
//    it, and the guard could be deleted unnoticed. On the back rank both
//    moves mate and nothing follows, so only the guard can say no.
// 3. The gate played its moves through `onMove`, which the screen reads
//    against `fenBefore(step)` — so nothing looked at the board the trainer
//    actually sees after choosing a step.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
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

const _fen = '4k3/8/8/8/8/8/8/4K2R w K - 0 1';

Map<String, dynamic> _game(String side) => {
      'id': 'ex_game',
      'fen': _fen,
      'sideToMove': 'w',
      'name': 'Hold the ending',
      'instruction': null,
      'themes': <String>[],
      'origin': 'manual',
      'task': {'type': 'game', 'fen': _fen, 'side': side, 'goal': 'hold'},
      'solution': null,
      'assignable': true,
      'blockedReason': null,
    };

const _scholar = 'rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 2';
const _backRank = '6k1/5ppp/8/8/8/8/5PPP/3RR1K1 w - - 0 1';

Map<String, dynamic> _find() => {
      'id': 'ex_find',
      'fen': _scholar,
      'sideToMove': 'w',
      'name': 'Queen out early',
      'instruction': null,
      'themes': <String>[],
      'origin': 'manual',
      'task': {'type': 'find'},
      'solution': [
        {
          'accept': ['Qh5', 'Qf3'],
          'reply': 'g6'
        },
        {
          'accept': ['Qxe5+'],
          'reply': null
        }
      ],
      'assignable': true,
      'blockedReason': null,
    };

void main() {
  test('the main move stays even where the line would replay without it', () {
    final edit = ExerciseLineEdit(fen: _backRank, steps: const [
      ExerciseStep(accept: ['Rd8#', 'Re8#'])
    ]);
    expect(edit.remove(0, 'Rd8#'), isFalse);
    expect(edit.steps.single.accept, ['Rd8#', 'Re8#']);
    expect(edit.remove(0, 'Re8#'), isTrue);
    expect(edit.steps.single.accept, ['Rd8#']);
  });

  testWidgets('choosing a step shows the board the student sees there',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: ExerciseEditorScreen(
        api: ExerciseApiService(
          authToken: 'tok',
          client: MockClient((r) async =>
              http.Response(jsonEncode({'exercise': _find()}), 200)),
        ),
        exerciseId: 'ex_find',
      ),
    ));
    await tester.pumpAndSettle();
    String shown() => tester
        .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
        .controller
        .getFen();
    expect(MoveTree.samePosition(shown(), _scholar), isTrue);

    await tester.ensureVisible(find.byKey(const Key('exercise-editor-step-1')));
    await tester.tap(find.byKey(const Key('exercise-editor-step-1')));
    await tester.pumpAndSettle();
    final edit = ExerciseLineEdit(fen: _scholar, steps: const [
      ExerciseStep(accept: ['Qh5', 'Qf3'], reply: 'g6'),
      ExerciseStep(accept: ['Qxe5+'])
    ]);
    expect(MoveTree.samePosition(shown(), edit.fenBefore(1)), isTrue,
        reason: 'after 1.Qh5 g6');
    expect(MoveTree.samePosition(shown(), _scholar), isFalse);
  });

  for (final entry in {
    'b': PlayerColor.black,
    'w': PlayerColor.white,
  }.entries) {
    testWidgets(
        'a game is turned to the side the student plays (${entry.key}), '
        'whoever is to move', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: ExerciseEditorScreen(
          api: ExerciseApiService(
            authToken: 'tok',
            client: MockClient((r) async =>
                http.Response(jsonEncode({'exercise': _game(entry.key)}), 200)),
          ),
          exerciseId: 'ex_game',
        ),
      ));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
            .boardOrientation,
        entry.value,
      );
    });
  }
}
