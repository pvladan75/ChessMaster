// exercise_edit_own_test.dart — what `docs/gates/exercise_edit_test.dart`
// cannot reach: layout at both sizes for a game and a one-move exercise, a
// promotion played as an alternative, a Black-to-move exercise, the sheet's
// own Cancel losing nothing, the leave guard, the Library's door refusing a
// bare scan, and the check running over the steps an edit was given.
//
// `docs/briefs/BRIEF-EXERCISE-FAZA11-APP.md`, „Your own tests".
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' show PlayerColor;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/exercises/screens/exercise_editor_screen.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/services/exercise_checker.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import 'support/landscape.dart' show loadRoboto;

const _kingAndRook = '4k3/8/8/8/8/8/8/4K2R b K - 0 1';
const _backRank = '6k1/5ppp/8/8/8/8/5PPP/3RR1K1 w - - 0 1';

/// The mirror of [_backRank]: Black delivers the mate, so Black is on move.
const _blackBackRank = '3rr1k1/5ppp/8/8/8/8/5PPP/6K1 b - - 0 1';

/// A lone king plus one pawn a move away from queening, kings well apart so
/// neither promotion square nor the pawn's path is contested — the only
/// question this position is here to ask is what a knight promotion is
/// accepted as.
const _promotionFen = '8/P7/8/8/8/3k4/8/6K1 w - - 0 1';

/// White to move and winning; Kc6/Kd6/Ke6 all keep the win, the same
/// position `exercise_check_own_test.dart` reads it as.
const _kpk = '8/8/8/3K4/3P4/8/8/3k4 w - - 0 1';

ThemeData _theme() =>
    ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]);

/// Answers `/exercises/:id` from [rows], by method, and keeps every request.
class _Server {
  _Server(this.rows, {this.libraryItems = const []});

  final Map<String, Map<String, dynamic>> rows;
  final List<Map<String, dynamic>> libraryItems;
  final requests = <http.Request>[];

  Iterable<http.Request> to(String path, String method) =>
      requests.where((r) => r.url.path == path && r.method == method);

  Map<String, dynamic> bodyOf(http.Request r) =>
      jsonDecode(r.body) as Map<String, dynamic>;

  http.Client client() => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path == '/library/positions') {
          return http.Response(jsonEncode({'items': libraryItems}), 200);
        }
        if (path == '/lessons') return http.Response('[]', 200);
        if (path == '/lessons/labels') return http.Response('[]', 200);
        if (!path.startsWith('/exercises/')) return http.Response('{}', 404);

        final id = path.substring('/exercises/'.length);
        final row = rows[id];
        if (row == null) {
          return http.Response(jsonEncode({'error': 'No such exercise.'}), 404);
        }
        if (request.method == 'GET') {
          return http.Response(jsonEncode({'exercise': row}), 200);
        }
        if (request.method == 'PUT') {
          final sent = jsonDecode(request.body) as Map<String, dynamic>;
          final saved = {
            ...row,
            'name': sent['name'],
            'instruction': sent['instruction'],
            'themes': sent['themes'],
            'solution': sent['solution'],
            'task': (sent['task'] as Map)['type'] == 'game'
                ? {...(sent['task'] as Map), 'fen': row['fen']}
                : sent['task']
          };
          rows[id] = saved.cast<String, dynamic>();
          return http.Response(jsonEncode({'exercise': saved}), 200);
        }
        return http.Response('{}', 405);
      });
}

Map<String, dynamic> _findRow({
  required String id,
  required String fen,
  String sideToMove = 'w',
  required List<Map<String, dynamic>> solution,
}) =>
    {
      'id': id,
      'fen': fen,
      'sideToMove': sideToMove,
      'name': 'Exercise $id',
      'instruction': null,
      'themes': <String>[],
      'origin': 'manual',
      'task': {'type': 'find'},
      'solution': solution,
      'needsReview': false,
      'assignable': true,
      'blockedReason': null,
    };

Map<String, dynamic> _gameRow(String id) => {
      'id': id,
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

Future<_Server> _pumpEditor(
  WidgetTester tester,
  Map<String, Map<String, dynamic>> rows,
  String id, {
  Size size = const Size(360, 640),
  ExerciseChecker checker = defaultExerciseChecker,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final server = _Server(rows);
  await tester.pumpWidget(MaterialApp(
    theme: _theme(),
    home: ExerciseEditorScreen(
      api: ExerciseApiService(authToken: 'tok', client: server.client()),
      exerciseId: id,
      checker: checker,
    ),
  ));
  await tester.pumpAndSettle();
  return server;
}

/// Pushes the editor on top of a real route, so leaving it is a real pop a
/// `PopScope` can actually intercept — `pumpEditor`'s `home:` has nowhere to
/// pop back to.
Future<_Server> _pumpEditorPushed(WidgetTester tester,
    Map<String, Map<String, dynamic>> rows, String id) async {
  final server = _Server(rows);
  await tester.pumpWidget(MaterialApp(
    theme: _theme(),
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ExerciseEditorScreen(
              api:
                  ExerciseApiService(authToken: 'tok', client: server.client()),
              exerciseId: id,
            ),
          )),
          child: const Text('open'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return server;
}

String lineText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('exercise-editor-line'))).data!;

SyzygyResult _tb(String fen, String category, Map<String, String> moves) =>
    SyzygyResult.fromJson(fen, {
      'category': category,
      'moves': [
        for (final m in moves.entries)
          {'uci': 'a1a1', 'san': m.key, 'category': m.value},
      ],
    });

void main() {
  setUpAll(loadRoboto);

  group('layout: a game and a one-move exercise', () {
    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets(
          'a game exercise, at ${size.width.toInt()}x${size.height.toInt()}: '
          'no overflow, Save reachable', (tester) async {
        await _pumpEditor(tester, {'ex_1': _gameRow('ex_1')}, 'ex_1',
            size: size);
        expect(tester.takeException(), isNull);
        await tester
            .ensureVisible(find.byKey(const Key('exercise-editor-save')));
        expect(find.byKey(const Key('exercise-editor-save')), findsOneWidget);
      });

      testWidgets(
          'a one-move exercise — no step to choose between — at '
          '${size.width.toInt()}x${size.height.toInt()}: no overflow, Save '
          'reachable', (tester) async {
        final row = _findRow(id: 'ex_1', fen: _backRank, solution: const [
          {
            'accept': ['Rd8'],
          }
        ]);
        await _pumpEditor(tester, {'ex_1': row}, 'ex_1', size: size);
        expect(tester.takeException(), isNull);
        expect(lineText(tester), 'Rd8#');
        await tester
            .ensureVisible(find.byKey(const Key('exercise-editor-save')));
        expect(find.byKey(const Key('exercise-editor-save')), findsOneWidget);
      });
    }
  });

  group('a promotion as an alternative', () {
    testWidgets(
        'onMove(from, to, "n") adds the knight promotion as the board spells it',
        (tester) async {
      final row = _findRow(
        id: 'ex_1',
        fen: _promotionFen,
        solution: const [
          {
            'accept': ['a8=Q'],
          }
        ],
      );
      await _pumpEditor(tester, {'ex_1': row}, 'ex_1');
      expect(lineText(tester), 'a8=Q');

      tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
          .onMove('a7', 'a8', 'n');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(lineText(tester), 'a8=Q (or a8=N)');
    });
  });

  group('Black to move', () {
    testWidgets('the board is turned to Black, and a move played lands there',
        (tester) async {
      final row = _findRow(
        id: 'ex_1',
        fen: _blackBackRank,
        sideToMove: 'b',
        solution: const [
          {
            'accept': ['Rd1'],
          }
        ],
      );
      await _pumpEditor(tester, {'ex_1': row}, 'ex_1');
      expect(lineText(tester), 'Rd1#');
      expect(
          tester
              .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
              .boardOrientation,
          PlayerColor.black);

      // e8-e1 is legal only for Black's rook — proof the move is read on the
      // position's own side to move, not assumed to be White's.
      tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
          .onMove('e8', 'e1', '');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(lineText(tester), 'Rd1# (or Re1#)');
    });
  });

  group("Cancel in the sheet loses nothing", () {
    testWidgets(
        'the editor is still open, the alternative is still in the line, '
        'and no PUT was sent', (tester) async {
      final row = _findRow(
        id: 'ex_1',
        fen: _backRank,
        solution: const [
          {
            'accept': ['Rd8'],
          }
        ],
      );
      final server = await _pumpEditor(tester, {'ex_1': row}, 'ex_1');

      tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
          .onMove('e1', 'e8', '');
      await tester.pumpAndSettle();
      expect(lineText(tester), 'Rd8# (or Re8#)');

      await tester.ensureVisible(find.byKey(const Key('exercise-editor-save')));
      await tester.tap(find.byKey(const Key('exercise-editor-save')));
      await tester.pumpAndSettle();
      expect(find.byType(MakeExerciseSheet), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(MakeExerciseSheet), findsNothing);
      expect(find.byType(ExerciseEditorScreen), findsOneWidget);
      expect(lineText(tester), 'Rd8# (or Re8#)',
          reason: 'the alternative played before Save was opened is still '
              'there');
      expect(server.to('/exercises/ex_1', 'PUT'), isEmpty);
    });
  });

  group('leaving the editor', () {
    testWidgets('with no change, the back button pops at once', (tester) async {
      await _pumpEditorPushed(
          tester,
          {
            'ex_1': _findRow(id: 'ex_1', fen: _backRank, solution: const [
              {
                'accept': ['Rd8'],
              }
            ])
          },
          'ex_1');

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(find.byType(ExerciseEditorScreen), findsNothing);
      expect(find.text('Discard the unsaved change?'), findsNothing);
    });

    testWidgets('with an unsaved change, leaving asks first', (tester) async {
      await _pumpEditorPushed(
          tester,
          {
            'ex_1': _findRow(id: 'ex_1', fen: _backRank, solution: const [
              {
                'accept': ['Rd8'],
              }
            ])
          },
          'ex_1');

      tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
          .onMove('e1', 'e8', '');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Discard the unsaved change?'), findsOneWidget);
      expect(find.byType(ExerciseEditorScreen), findsOneWidget,
          reason: 'still open — waiting for a choice');

      // "Keep editing" leaves everything as it was.
      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseEditorScreen), findsOneWidget);
      expect(lineText(tester), 'Rd8# (or Re8#)');

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exercise-editor-discard')));
      await tester.pumpAndSettle();
      expect(find.byType(ExerciseEditorScreen), findsNothing);
    });
  });

  group('the Library door refuses a bare scan', () {
    Map<String, dynamic> item(String id, String title,
            {bool hasSolution = true, bool fromTrainer = false}) =>
        {
          'kind': 'scan',
          'id': id,
          'title': title,
          'fen': _backRank,
          'assignable': hasSolution,
          'hasSolution': hasSolution,
          'fromTrainer': fromTrainer,
          'origin': 'book',
        };

    testWidgets(
        'a bare scan (hasSolution: false, no game task) does not open the '
        'editor and asks for no /exercises/…', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final server = _Server({}, libraryItems: [
        item('bare', 'A position with no answer', hasSolution: false),
      ]);
      final client = server.client();
      await tester.pumpWidget(MaterialApp(
        theme: _theme(),
        home: LibraryScreen(
          session: UserSession(
              token: 'tok',
              id: 1,
              email: 't@example.com',
              name: 'Trainer',
              role: 'trener'),
          lessonApi: LessonApiService(authToken: 'tok', client: client),
          positionLibrary:
              PositionLibraryService(authToken: 'tok', client: client),
          exerciseApi: ExerciseApiService(authToken: 'tok', client: client),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('library-row-scan-bare')),
          matching: find.byType(ListTile)));
      await tester.pump();
      // Whatever a bare position's tap does today (it asks the router for
      // Analysis, which a bare MaterialApp has none of) is not this test's
      // business; that it does not open the editor, or ask the server for an
      // exercise that does not exist, is.
      tester.takeException();

      expect(find.byType(ExerciseEditorScreen), findsNothing);
      expect(server.to('/exercises/bare', 'GET'), isEmpty);
    });
  });

  group('the sheet in edit mode runs the check over the steps it was given',
      () {
    testWidgets(
        "an alsoKeeps finding's Accept puts its moves into the PUT's "
        'solution[0].accept after the ones already there', (tester) async {
      final winning = _tb(_kpk, 'win', {
        'Kc6': 'loss',
        'Kd6': 'loss',
        'Ke6': 'loss',
        'Kc4': 'draw',
        'Ke4': 'draw',
      });
      final checker = ExerciseChecker(
        tablebase: (fen) async => fen == _kpk ? winning : null,
        engine: (fen) async => fail('this scenario has seven pieces or fewer'),
      );
      final row = _findRow(id: 'ex_1', fen: _kpk, solution: const [
        {
          'accept': ['Kc6'],
        }
      ]);
      final server =
          await _pumpEditor(tester, {'ex_1': row}, 'ex_1', checker: checker);

      await tester.ensureVisible(find.byKey(const Key('exercise-editor-save')));
      await tester.tap(find.byKey(const Key('exercise-editor-save')));
      await tester.pumpAndSettle();
      expect(find.byType(MakeExerciseSheet), findsOneWidget);

      expect(find.textContaining('Kd6'), findsOneWidget,
          reason: 'the check ran over the steps the editor was given, not '
              'an empty line');
      await tester.tap(find.widgetWithText(TextButton, 'Accept'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      final body = server.bodyOf(server.to('/exercises/ex_1', 'PUT').single);
      final accept =
          ((body['solution'] as List).first as Map)['accept'] as List;
      expect(accept, ['Kc6', 'Kd6', 'Ke6']);
    });
  });
}
