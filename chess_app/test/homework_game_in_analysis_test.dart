// A played homework game opens in Analysis with its moves —
// `docs/PLAN-EXERCISE.md`, phase 13.
//
// Phase 9 put the moves of a game in front of the trainer as text, with two
// thumbnails. The owner (20.9.2026): to judge how a student played, the trainer
// needs the moves on a board, with the engine at hand. Analysis already has a
// door for a whole game (`AnalysisStudioScreen.initialGame`, the archive's);
// this is the review's way to it, and the student's own once the game is
// handed in.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';
import 'package:chess_app/features/analysis_studio/services/open_game_in_analysis.dart';
import 'package:chess_app/features/assignments/screens/assignment_review_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _studentId = 1;
const _trainerId = 9;

const _krk = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';
const _kpk = '8/8/8/4k3/8/4K3/4P3/8 b - - 0 1';

UserSession _session(int id) => UserSession(
      token: 'tok',
      id: id,
      email: 'a@example.com',
      name: id == _trainerId ? 'Trainer' : 'Student',
      role: id == _trainerId ? 'trener' : 'ucenik',
    );

Map<String, dynamic> _gameItem({
  String fen = _krk,
  String side = 'w',
  List<String> moves = const ['Ra8', 'Kd3', 'Ra3+'],
  bool attempted = true,
}) =>
    {
      'itemId': 7,
      'position': 0,
      'puzzleId': null,
      'kind': 'game',
      'attempted': attempted,
      'attemptedAt': attempted ? '2026-09-19T14:00:00.000Z' : null,
      'solved': attempted ? false : null,
      'msTaken': null,
      'playedSan': null,
      'title': null,
      'instruction': null,
      'fen': fen,
      'task': {
        'type': 'game',
        'side': side,
        'goal': 'win',
        'surviveMoves': 2,
      },
      'moves': moves,
      'finalFen': null,
      'ending': attempted ? 'moveTarget' : null,
      'judgedBy': attempted ? 'rules' : null,
      'pending': false,
    };

Future<void> _pumpReview(
  WidgetTester tester,
  Map<String, dynamic> item, {
  Size size = const Size(900, 1400),
  int viewer = _trainerId,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final isTrainer = viewer == _trainerId;
  final review = {
    'assignment': {
      'id': 603,
      'title': 'Play it out',
      'kind': 'engine_game',
      'instructions': null,
      'dueAt': null,
      'completedAt': '2026-09-19T14:00:00.000Z',
      'createdAt': '2026-09-19T13:00:00.000Z',
      'trainerName': 'Trainer',
      'studentName': 'Ana',
    },
    'viewer': {'isTrainer': isTrainer, 'isStudent': !isTrainer},
    'items': [item],
    'notes': <dynamic>[],
  };
  final client = MockClient((request) async {
    if (request.url.path == '/assignments/603/review') {
      return http.Response(jsonEncode(review), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    return http.Response('{"error":"not found"}', 404);
  });
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AssignmentReviewScreen(
        session: _session(viewer),
        assignmentId: 603,
        title: 'Play it out',
        api: AssignmentApiService(authToken: 'tok', client: client),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

final _door = find.byKey(const Key('review-game-analysis-7'));

void main() {
  late List<AnalysisGame> opened;

  setUp(() {
    opened = [];
    debugOpenGameInAnalysis = (context, game) async => opened.add(game);
  });
  tearDown(() => debugOpenGameInAnalysis = null);

  testWidgets('the trainer opens the game whole, standing on its last move',
      (tester) async {
    await _pumpReview(tester, _gameItem());
    expect(_door, findsOneWidget);
    await tester.tap(_door);
    await tester.pumpAndSettle();

    expect(opened, hasLength(1));
    final game = opened.single;
    expect(game.startFen, _krk);
    expect(game.uciMoves, ['a1a8', 'e3d3', 'a8a3']);
    expect(game.cursorPly, 3);
    expect(game.blackOrientation, isFalse);
  });

  testWidgets('the board faces the side the student played', (tester) async {
    await _pumpReview(
      tester,
      _gameItem(fen: _kpk, side: 'b', moves: const ['Kd5', 'Kd3']),
    );
    await tester.tap(_door);
    await tester.pumpAndSettle();
    expect(opened.single.blackOrientation, isTrue);
    expect(opened.single.uciMoves, ['e5d5', 'e3d3']);
  });

  testWidgets('the student has the same door — the game is handed in',
      (tester) async {
    await _pumpReview(tester, _gameItem(), viewer: _studentId);
    await tester.tap(_door);
    await tester.pumpAndSettle();
    expect(opened.single.uciMoves, hasLength(3));
  });

  testWidgets('a game that was never played has no door', (tester) async {
    await _pumpReview(tester, _gameItem(moves: const [], attempted: false));
    expect(find.byKey(const Key('review-game-7')), findsOneWidget);
    expect(_door, findsNothing);
  });

  testWidgets('a game that does not replay is refused, not opened short',
      (tester) async {
    // The second move is the one that cannot be played.
    await _pumpReview(tester, _gameItem(moves: const ['Ra8', 'Kd1', 'Ra3+']));
    await tester.tap(_door);
    await tester.pumpAndSettle();
    expect(opened, isEmpty);
    expect(find.textContaining('cannot be replayed'), findsOneWidget);
  });

  testWidgets('the card holds the door on a phone', (tester) async {
    await _pumpReview(tester, _gameItem(), size: const Size(360, 640));
    await tester.ensureVisible(_door);
    expect(tester.takeException(), isNull);
    expect(_door, findsOneWidget);
  });

  // The student's side of the same door. Phase 12 closes Analysis while an
  // assigned game is being played and opens it once it is handed in
  // (`homework_closed_doors_test.dart` holds that rule); what this asks is
  // that the open door carries the game, not the bare position it ended on.
  group('the finished game itself', () {
    const mateInOne = '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1';

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final service = StockfishService();
      service.onEvaluationChanged = null;
      service.onMultiPVUpdated = null;
    });

    Future<void> tapSquare(WidgetTester tester, String square) async {
      final rect = tester.getRect(find.byType(SkinnedChessBoard).first);
      final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = int.parse(square.substring(1));
      final side = rect.width / 8;
      await tester.tapAt(rect.topLeft +
          Offset(file * side + side / 2, (8 - rank) * side + side / 2));
      await tester.pump();
    }

    testWidgets('handed in, Analysis is given the moves that were played',
        (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final task = EngineGameTask.fromJson(
          {'fen': mateInOne, 'side': 'w', 'goal': 'win', 'plyCap': 40})!;

      await http.runWithClient(() async {
        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark()
                .copyWith(extensions: const [AppColorTokens.dark]),
            home: AiStudioScreen(
              userSession: _session(_studentId),
              initialCategory: 'engine_game',
              engineGameTask: task,
              assignmentId: 42,
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.biotech), findsNothing,
            reason: 'control: closed while the game is being played');

        await tapSquare(tester, 'd1');
        await tapSquare(tester, 'd8');
        await tester.pumpAndSettle();
        expect(find.text('Goal met'), findsOneWidget);
        // The closing dialog, put away by its barrier — „Back" would leave
        // the screen.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byIcon(Icons.biotech).first);
        await tester.tap(find.byIcon(Icons.biotech).first);
        await tester.pumpAndSettle();
      }, () => MockClient((_) async => http.Response('{"ok":true}', 200)));

      expect(opened, hasLength(1));
      expect(opened.single.startFen, mateInOne);
      expect(opened.single.uciMoves, ['d1d8']);
      expect(opened.single.cursorPly, 1);
      expect(opened.single.blackOrientation, isFalse);
    });
  });
}
