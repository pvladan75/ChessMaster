// homework_closed_doors_test.dart — phase 12 of `docs/PLAN-EXERCISE.md` (§9,
// finding 4): while an assigned item is open, the engine, „send to Analysis"
// and the board's own copy-FEN are off.
//
// It does not stop a second device — the trainer's review of the moves played
// (phase 9) answers that. It stops the one-tap way.
//
// Every item a homework opens goes through one door, `assignmentItemScreen`,
// to one of four screens; each is pumped here and asked the same question of
// the one board widget. The controls at the bottom prove the question can be
// answered the other way: the same screens outside an assignment, and a plain
// board, still copy.
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/core/services/board_on_screen.dart';
import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/custom_puzzle_solver_screen.dart';
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/tactics_trainer/screens/tactics_trainer_screen.dart';
import 'package:chess_app/features/tactics_trainer/services/tactics_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import 'support/landscape.dart' show loadRoboto;

UserSession _session() => UserSession(
    token: 't', id: 1, email: 's@example.com', name: 'Student', role: 'user');

const _kingAndRook = '4k3/8/8/8/8/8/8/4K2R w K - 0 1';

const _puzzleBody = '''
{
  "puzzle": {
    "puzzle_id": "p1",
    "fen": "6k1/5ppp/8/8/8/8/8/R5K1 b - - 0 1",
    "setup_move": "h7h6",
    "solution": ["a1a8"],
    "rating": 1200,
    "themes": ["mateIn1"]
  },
  "selection": {"targetRating": 1200}
}
''';

Widget _app(Widget home) => ProviderScope(
      child: MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: home,
      ),
    );

ChessBoardWithOverlay _board(WidgetTester tester) =>
    tester.widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay));

void main() {
  final copied = <String>[];

  setUpAll(loadRoboto);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BoardOnScreen.reset();
    copied.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add((call.arguments as Map)['text'] as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<void> rightClickBoard(WidgetTester tester) async {
    final centre = tester.getCenter(find.byType(ChessBoardWithOverlay));
    final gesture = await tester.startGesture(centre,
        kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Widget plainBoard({required bool copyPosition}) => Scaffold(
        body: Center(
          child: ChessBoardWithOverlay(
            controller: ChessBoardController.fromFEN(_kingAndRook),
            boardOrientation: PlayerColor.white,
            boardSize: 320,
            isAllowedToMove: true,
            isDrawingMode: false,
            drawingStartSquare: null,
            arrows: const [],
            engineArrows: const [],
            onMove: (_, __, ___) {},
            onSquareTapForDrawing: (_) {},
            copyPosition: copyPosition,
          ),
        ),
      );

  group('the board', () {
    testWidgets('a board told not to gives no FEN away, by either way in',
        (tester) async {
      await tester.pumpWidget(_app(plainBoard(copyPosition: false)));
      await tester.pump();

      await rightClickBoard(tester);
      expect(copied, isEmpty, reason: 'the right click');

      // Ctrl+C asks whoever is on top. A closed board must *be* on top and
      // say no — were it simply absent, the board of the screen underneath
      // would answer instead.
      expect(BoardOnScreen.isPresent, isTrue);
      BoardOnScreen.copyPosition();
      await tester.pump(const Duration(milliseconds: 50));
      expect(copied, isEmpty, reason: 'Ctrl+C');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a closed board on top does not let the one beneath answer',
        (tester) async {
      var beneath = 0;
      BoardOnScreen.register(() => beneath++);
      await tester.pumpWidget(_app(plainBoard(copyPosition: false)));
      await tester.pump();
      BoardOnScreen.copyPosition();
      expect(beneath, 0);
      expect(copied, isEmpty);
    });

    testWidgets('control: every other board still copies, both ways',
        (tester) async {
      await tester.pumpWidget(_app(plainBoard(copyPosition: true)));
      await tester.pump();
      await rightClickBoard(tester);
      expect(copied, [_kingAndRook]);
      BoardOnScreen.copyPosition();
      await tester.pump(const Duration(milliseconds: 50));
      expect(copied, [_kingAndRook, _kingAndRook]);
    });
  });

  group('play it out, assigned', () {
    final task = EngineGameTask.fromJson({
      'fen': _kingAndRook,
      'side': 'w',
      'goal': 'win',
      'plyCap': 40,
    })!;

    Future<void> pump(WidgetTester tester, Size size,
        {required int? assignmentId}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(AiStudioScreen(
        userSession: _session(),
        initialCategory: 'engine_game',
        engineGameTask: task,
        assignmentId: assignmentId,
      )));
      await tester.pumpAndSettle();
    }

    for (final size in [const Size(360, 640), const Size(800, 400)]) {
      final at = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('no engine, no Analysis, no FEN at $at', (tester) async {
        await http.runWithClient(() async {
          var beneath = 0;
          BoardOnScreen.register(() => beneath++);
          await pump(tester, size, assignmentId: 42);
          expect(tester.takeException(), isNull);
          BoardOnScreen.copyPosition();

          expect(find.byIcon(Icons.biotech), findsNothing,
              reason: 'every door to Analysis carries this icon');
          expect(find.textContaining('Analysis'), findsNothing);
          expect(find.byType(StockfishAnalysisWidget), findsNothing);
          // This screen draws its own board, which never copied; what it
          // must not do is let Ctrl+C through to a board beneath it.
          expect(beneath, 0);
          for (final menu
              in tester.widgetList<BoardViewMenu>(find.byType(BoardViewMenu))) {
            expect(menu.engine, isFalse,
                reason: 'no switch for the engine\'s arrows either');
          }
        }, () => MockClient((_) async => http.Response('{}', 200)));
      });

      testWidgets(
          'control: the same game outside an assignment keeps them '
          'at $at', (tester) async {
        await http.runWithClient(() async {
          await pump(tester, size, assignmentId: null);
          expect(find.byIcon(Icons.biotech), findsWidgets);
          expect(find.byType(StockfishAnalysisWidget), findsWidgets);
        }, () => MockClient((_) async => http.Response('{}', 200)));
      });
    }
  });

  group('the other three screens an item opens', () {
    testWidgets('find the move', (tester) async {
      await tester.pumpWidget(_app(CustomPuzzleSolverScreen(
        session: _session(),
        detail: const AssignmentDetail(
          assignment: Assignment(id: 42, title: 'Openings'),
          items: [],
        ),
        positions: const [
          CustomPosition(puzzleId: 'ex_1', fen: _kingAndRook, sideToMove: 'w'),
        ],
        startIndex: 0,
        api: AssignmentApiService(
            authToken: 't',
            client: MockClient((_) async => http.Response('{}', 200))),
        onAnswered: (_, __) {},
      )));
      await tester.pumpAndSettle();
      expect(_board(tester).copyPosition, isFalse);
      await rightClickBoard(tester);
      expect(copied, isEmpty);
    });

    testWidgets('a tutorial', (tester) async {
      await tester.pumpWidget(_app(LessonViewerScreen(
        session: _session(),
        detail: const AssignmentDetail(
          assignment: Assignment(
              id: 5,
              title: 'A tutorial',
              kind: AssignmentKind.lesson,
              totalItems: 1),
          items: [AssignmentItem(puzzleId: null, position: 0)],
          steps: [
            LessonStep(
                title: 'One', fen: _kingAndRook, instruction: 'White to play.'),
          ],
        ),
      )));
      await tester.pump();
      expect(_board(tester).copyPosition, isFalse);
    });

    Future<void> pumpTactics(WidgetTester tester,
        {List<String>? puzzleIds, int? assignmentId}) async {
      await tester.pumpWidget(_app(TacticsTrainerScreen(
        session: _session(),
        puzzleIds: puzzleIds,
        assignmentId: assignmentId,
        api: TacticsApiService(
          authToken: 't',
          client: MockClient((req) async {
            if (req.url.path.contains('/by-id/')) {
              final puzzle = (jsonDecode(_puzzleBody) as Map)['puzzle'];
              return http.Response(jsonEncode({'puzzle': puzzle}), 200);
            }
            return http.Response(_puzzleBody, 200);
          }),
        ),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('assigned puzzles', (tester) async {
      await pumpTactics(tester, puzzleIds: const ['p1'], assignmentId: 42);
      expect(_board(tester).copyPosition, isFalse);
    });

    testWidgets('control: free tactics practice still copies', (tester) async {
      await pumpTactics(tester);
      expect(_board(tester).copyPosition, isTrue);
    });
  });
}
