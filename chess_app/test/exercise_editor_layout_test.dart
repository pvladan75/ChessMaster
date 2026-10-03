// The gate of phase 5 of docs/PLAN-EKRANI.md: the exercise editor as the owner
// chose from `docs/skice/ekrani/compare_editor.png` — on a window the board
// sized by the window's height (the shared `TrainerBoardLayout`, rule R1) with
// the task and its answers in a panel beside it, and `Save` a button of its own
// width in that panel instead of a bar the width of the window (R4). The phone
// keeps a plain button.
//
// The app's own theme with real Roboto, as phase 1 taught.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/exercises/screens/exercise_editor_screen.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/trainer_board_layout.dart';

import 'support/landscape.dart';
import 'support/render_look.dart';

const _window = Size(1536, 792);
const _small = Size(900, 700);
const _phone = Size(360, 640);

const _backRank = '6k1/5ppp/8/8/8/8/5PPP/3RR1K1 w - - 0 1';
const _kingAndRook = '4k3/8/8/8/8/8/8/4K2R b K - 0 1';

Map<String, dynamic> _findRow() => {
      'id': 'ex1',
      'fen': _backRank,
      'sideToMove': 'w',
      'name': 'Back-rank mate',
      'instruction': null,
      'themes': <String>[],
      'origin': 'manual',
      'task': {'type': 'find'},
      'solution': [
        {
          'accept': ['Rd8#', 'Re8#']
        }
      ],
      'needsReview': false,
      'assignable': true,
      'blockedReason': null,
    };

Map<String, dynamic> _gameRow() => {
      'id': 'ex2',
      'fen': _kingAndRook,
      'sideToMove': 'b',
      'name': 'Hold the ending',
      'instruction': null,
      'themes': <String>[],
      'origin': 'manual',
      'task': {
        'type': 'game',
        'fen': _kingAndRook,
        'side': 'b',
        'goal': 'hold',
        'surviveMoves': 7,
        'level': 'tesko',
        'thinkSeconds': 3,
        'plyCap': 300,
      },
      'solution': null,
      'needsReview': false,
      'assignable': true,
      'blockedReason': null,
    };

Future<void> _pump(
    WidgetTester tester, Size size, Map<String, dynamic> row) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final client = MockClient((request) async {
    if (request.url.path == '/exercises/${row['id']}' &&
        request.method == 'GET') {
      return http.Response(jsonEncode({'exercise': row}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    return http.Response('[]', 200);
  });
  await tester.pumpWidget(MaterialApp(
    theme: robotoTheme(AppTheme.dark),
    home: ExerciseEditorScreen(
      key: UniqueKey(),
      api: ExerciseApiService(authToken: 'tok', client: client),
      exerciseId: row['id'] as String,
    ),
  ));
  await tester.pumpAndSettle();
}

Rect _rect(WidgetTester tester, Finder f) {
  expect(f, findsOneWidget);
  return tester.getRect(f);
}

Finder get _save => find.byKey(const Key('exercise-editor-save'));
Finder get _board => find.byType(ChessBoardWithOverlay);

void main() {
  setUpAll(loadRoboto);

  for (final (size, minBoard) in [(_window, 520.0), (_small, 400.0)]) {
    testWidgets(
        'a find exercise on a window of ${sizeLabel(size)}: the shared layout, '
        'a square board of at least $minBoard, Save in the panel beside it',
        (tester) async {
      await _pump(tester, size, _findRow());
      expect(tester.takeException(), isNull);
      expect(find.byType(TrainerBoardLayout), findsOneWidget);
      final board = _rect(tester, _board);
      expect(board.width, closeTo(board.height, 0.01));
      expect(board.width, greaterThanOrEqualTo(minBoard));
      // The task and the answers stand beside the board.
      final answer =
          _rect(tester, find.byKey(const Key('exercise-editor-remove-Rd8#')));
      expect(answer.left, greaterThanOrEqualTo(board.right));
      // Save is in that panel, a button of its own width, on screen.
      final save = _rect(tester, _save);
      expect(save.left, greaterThanOrEqualTo(board.right),
          reason: 'Save stands in the panel, not under the board');
      expect(save.width, lessThan(400),
          reason: 'a button, not a bar the width of the window (R4)');
      expectOnScreen(tester, size, _save);
      expect(tester.widget(_save), isA<FilledButton>());
    });
  }

  testWidgets('a game exercise on a window: the same layout and Save',
      (tester) async {
    await _pump(tester, _window, _gameRow());
    expect(tester.takeException(), isNull);
    expect(find.byType(TrainerBoardLayout), findsOneWidget);
    final board = _rect(tester, _board);
    expect(_rect(tester, _save).left, greaterThanOrEqualTo(board.right));
    expectOnScreen(tester, _window, _save);
  });

  testWidgets('on a 360 dp phone: nothing overflows, Save is reachable',
      (tester) async {
    await _pump(tester, _phone, _findRow());
    expect(tester.takeException(), isNull);
    final board = _rect(tester, _board);
    expect(board.width, closeTo(board.height, 0.01));
    expect(_save, findsOneWidget);
  });
}
