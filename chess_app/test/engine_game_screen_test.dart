// The exercise screen playing an assigned "play it out" game
// (docs/PLAN-DOMACI-ZADATAK.md §3, phase 2b) — driving the real screen with a
// fake engine reply and a fake API, per goal.
//
// The engine is faked the way `engine_subscriber_stack_test.dart` already
// does: `StockfishService` is a singleton, `onEvaluationChanged` is a public
// field, and the screen's own `attach()` puts its handler on top of the
// stack — so a test can call it directly with a chosen "best move" rather
// than spawning a real engine process. The API is faked with `MockClient`
// under `http.runWithClient` (CLAUDE.md rule 7: fake the client, assert on
// the request), which is how `landscape_screens_test.dart` fakes the server
// for other screens in this same file.

import 'dart:convert';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';
import 'package:chess_app/widgets/engine_opponent_sheet.dart';

import 'support/landscape.dart';

final _session = UserSession(
    id: 1, token: 'tok', email: 'e@x.com', name: 'N', role: 'ucenik');

/// Pumps the assigned-game screen as a whole app, with [size] as the window.
Future<void> _pump(
  WidgetTester tester,
  Size size, {
  required EngineGameTask task,
  int assignmentId = 42,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AiStudioScreen(
        userSession: _session,
        initialCategory: 'engine_game',
        engineGameTask: task,
        assignmentId: assignmentId,
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Taps a square on the one board on screen, by algebraic notation. Two
/// calls in a row (a square with the side-to-move's own piece, then the
/// destination) is a move, the same as a reader tapping a phone screen — the
/// screen's own `_handleSquareTap` reads exactly this pair of taps.
Future<void> _tapSquare(WidgetTester tester, String square,
    {required bool whiteAtBottom}) async {
  final rect = tester.getRect(find.byType(SkinnedChessBoard).first);
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square.substring(1));
  final col = whiteAtBottom ? file : 7 - file;
  final row = whiteAtBottom ? 8 - rank : rank - 1;
  final squareSize = rect.width / 8;
  final point = rect.topLeft +
      Offset(
          col * squareSize + squareSize / 2, row * squareSize + squareSize / 2);
  await tester.tapAt(point);
  await tester.pump();
}

Future<void> _playMove(WidgetTester tester, String from, String to,
    {required bool whiteAtBottom}) async {
  await _tapSquare(tester, from, whiteAtBottom: whiteAtBottom);
  await _tapSquare(tester, to, whiteAtBottom: whiteAtBottom);
}

/// The FEN reached from [startFen] after [sanMoves] — computed on a real
/// board rather than hand-typed, so a wrong guess fails loudly here instead
/// of quietly feeding the screen's stale-event filter a FEN it will discard
/// (`ai_studio_screen.dart` drops an engine evaluation whose FEN does not
/// match the board it is currently showing).
String _fenAfter(String startFen, List<String> sanMoves) {
  final game = chess.Chess.fromFEN(startFen);
  for (final san in sanMoves) {
    if (!game.move(san)) {
      throw StateError('test setup: "$san" is not legal after $sanMoves '
          'from $startFen');
    }
  }
  return game.fen;
}

/// Simulates the engine finishing its search with [bestMove] (LAN, e.g.
/// `d1d8`) for the position the screen is asking about right now. Real depth
/// and "final" both set high, so the screen's own depth/timeout race never
/// has to matter.
Future<void> _fakeEngineReply(
    WidgetTester tester, String bestMove, String analyzedFen) async {
  final service = StockfishService();
  final callback = service.onEvaluationChanged;
  expect(callback, isNotNull,
      reason: 'the screen must have attached to the engine by now');
  callback!('1.00', bestMove, '', 1, 40, true, analyzedFen);
  await tester.pump();
  // The 1-second pause before the engine's reply actually lands on the
  // board (ai_studio_screen.dart, `_playOpponentMove`).
  await tester.pump(const Duration(milliseconds: 1100));
  await tester.pump();
}

void main() {
  // Real glyphs, because the overflow assertions below measure whether a row
  // fits. Without this every letter is drawn as a square a full em wide, and
  // the AppBar's title row „overflows" by 134 px in the test and by nothing on
  // a phone — which is exactly what the first version of this file consumed as
  // a „pre-existing" exception (CLAUDE.md rule 8).
  setUpAll(loadRoboto);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final service = StockfishService();
    service.onEvaluationChanged = null;
    service.onMultiPVUpdated = null;
    // The reader's own default, pinned so this file does not depend on
    // whichever level an earlier test in the suite left the singleton at.
    AppSettingsService.instance.setEnginePlayLevel('srednje');
  });

  group('goals', () {
    testWidgets('win met: the dialog says the goal was met', (tester) async {
      final task = EngineGameTask.fromJson({
        'fen': '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1',
        'side': 'w',
        'goal': 'win',
        'plyCap': 40,
      })!;
      Map<String, dynamic>? sentBody;
      String? sentUrl;
      await http.runWithClient(() async {
        await _pump(tester, const Size(800, 900), task: task);
        await _playMove(tester, 'd1', 'd8', whiteAtBottom: true);
        await tester.pumpAndSettle();

        expect(find.text('Goal met'), findsOneWidget);
        expect(find.textContaining('checkmate'), findsWidgets);
      },
          () => MockClient((request) async {
                sentUrl = request.url.toString();
                sentBody = jsonDecode(request.body) as Map<String, dynamic>;
                return http.Response('{"ok":true}', 200);
              }));

      expect(sentBody, isNotNull, reason: 'the result must be posted');
      // The address, not only the payload: a MockClient answers any URL, so a
      // wrong one is invisible unless it is asserted (CLAUDE.md rule 7). The
      // first version of the screen posted to `/api/assignments/...`, which
      // this server does not serve.
      expect(sentUrl, endsWith('/assignments/42/game-result'));
      expect(sentUrl, isNot(contains('/api/')));
      expect(sentBody!['moves'], ['Rd8#']);
      expect(sentBody!.containsKey('goalMet'), isFalse,
          reason: 'the client never sends a verdict');
      expect(sentBody!.containsKey('ending'), isFalse);
      expect(sentBody!.containsKey('outcome'), isFalse);
    });

    testWidgets('win missed: the dialog says the goal was not met',
        (tester) async {
      final task = EngineGameTask.fromJson({
        'fen': '6k1/5ppp/p7/8/8/8/5PPP/3R2K1 b - - 0 1',
        'side': 'b',
        'goal': 'win',
        'plyCap': 40,
      })!;
      Map<String, dynamic>? sentBody;
      String? sentUrl;
      await http.runWithClient(() async {
        await _pump(tester, const Size(800, 900), task: task);
        await _playMove(tester, 'a6', 'a5', whiteAtBottom: false);
        await tester.pump();
        await _fakeEngineReply(tester, 'd1d8', _fenAfter(task.fen, ['a5']));
        await tester.pumpAndSettle();

        expect(find.text('Goal not met'), findsOneWidget);
        expect(find.textContaining('checkmate'), findsWidgets);
      },
          () => MockClient((request) async {
                sentUrl = request.url.toString();
                sentBody = jsonDecode(request.body) as Map<String, dynamic>;
                return http.Response('{"ok":true}', 200);
              }));

      expect(sentBody, isNotNull);
      expect(sentBody!['moves'], ['a5', 'Rd8#']);
      expect(sentBody!.containsKey('goalMet'), isFalse);
    });

    testWidgets('hold met: a stalemate is a draw held', (tester) async {
      final task = EngineGameTask.fromJson({
        'fen': '7k/8/6K1/8/8/8/8/5Q2 w - - 0 1',
        'side': 'w',
        'goal': 'hold',
        'plyCap': 40,
      })!;
      Map<String, dynamic>? sentBody;
      String? sentUrl;
      await http.runWithClient(() async {
        await _pump(tester, const Size(800, 900), task: task);
        await _playMove(tester, 'f1', 'f7', whiteAtBottom: true);
        await tester.pumpAndSettle();

        expect(find.text('Goal met'), findsOneWidget);
        expect(find.textContaining('stalemate'), findsWidgets);
      },
          () => MockClient((request) async {
                sentUrl = request.url.toString();
                sentBody = jsonDecode(request.body) as Map<String, dynamic>;
                return http.Response('{"ok":true}', 200);
              }));

      expect(sentBody, isNotNull);
      expect(sentBody!['moves'], ['Qf7']);
    });

    testWidgets('survive met: reaching the number is the goal', (tester) async {
      final task = EngineGameTask.fromJson({
        'fen': '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
        'side': 'w',
        'goal': 'survive',
        'surviveMoves': 2,
        'plyCap': 40,
      })!;
      Map<String, dynamic>? sentBody;
      String? sentUrl;
      await http.runWithClient(() async {
        await _pump(tester, const Size(800, 900), task: task);
        await _playMove(tester, 'e1', 'd2', whiteAtBottom: true);
        await tester.pump();
        await _fakeEngineReply(tester, 'e8e7', _fenAfter(task.fen, ['Kd2']));
        await _playMove(tester, 'd2', 'd3', whiteAtBottom: true);
        await tester.pumpAndSettle();

        expect(find.text('Goal met'), findsOneWidget);
        expect(find.text('The game ended: you were not beaten in 2 moves.'),
            findsOneWidget);
      },
          () => MockClient((request) async {
                sentUrl = request.url.toString();
                sentBody = jsonDecode(request.body) as Map<String, dynamic>;
                // Re-aimed 19.9.2026, phase 3b of docs/PLAN-EXERCISE.md. This
                // game stops at its move target with three pieces on the
                // board, so since phase 3a it is the **server** that says
                // whether the goal was met — a tablebase judges the position
                // reached, and the app cannot ask one. The fake used to answer
                // `{"ok":true}`, which no server sends any more; with that
                // answer the screen rightly says „not judged yet". It now
                // answers as `recordEngineGameResult` does, and „Goal met"
                // above is the server's word shown, not the app's own guess.
                return http.Response(
                    '{"ok":true,"goalMet":true,"judgedBy":"tablebase",'
                    '"pending":false,"ending":"moveTarget"}',
                    200);
              }));

      expect(sentBody, isNotNull);
      expect(sentBody!['moves'], ['Kd2', 'Ke7', 'Kd3']);
      expect(sentBody!.containsKey('goalMet'), isFalse);
    });

    testWidgets('survive missed: mated before the number', (tester) async {
      final task = EngineGameTask.fromJson({
        'fen': '6k1/5ppp/p7/8/8/8/5PPP/3R2K1 b - - 0 1',
        'side': 'b',
        'goal': 'survive',
        'surviveMoves': 10,
        'plyCap': 40,
      })!;
      Map<String, dynamic>? sentBody;
      String? sentUrl;
      await http.runWithClient(() async {
        await _pump(tester, const Size(800, 900), task: task);
        await _playMove(tester, 'a6', 'a5', whiteAtBottom: false);
        await tester.pump();
        await _fakeEngineReply(tester, 'd1d8', _fenAfter(task.fen, ['a5']));
        await tester.pumpAndSettle();

        expect(find.text('Goal not met'), findsOneWidget);
        expect(find.textContaining('checkmate'), findsWidgets);
      },
          () => MockClient((request) async {
                sentUrl = request.url.toString();
                sentBody = jsonDecode(request.body) as Map<String, dynamic>;
                return http.Response('{"ok":true}', 200);
              }));

      expect(sentBody, isNotNull);
      expect(sentBody!['moves'], ['a5', 'Rd8#']);
    });

    testWidgets("the engine plays at the task's strength, not the reader's",
        (tester) async {
      // The reader's own Settings level, pinned by `setUp` to 'srednje'
      // (depth 24). The task asks for 'lako' (depth 18) instead.
      final task = EngineGameTask.fromJson({
        'fen': '6k1/5ppp/p7/8/8/8/5PPP/3R2K1 b - - 0 1',
        'side': 'b',
        'goal': 'win',
        'level': 'lako',
        'plyCap': 40,
      })!;
      await http.runWithClient(() async {
        await _pump(tester, const Size(800, 900), task: task);
        await _playMove(tester, 'a6', 'a5', whiteAtBottom: false);
        await tester.pump();
        final callback = StockfishService().onEvaluationChanged;
        expect(callback, isNotNull);
        // Depth 20 sits strictly between the task's 'lako' (18) and the
        // reader's own 'srednje' (24): the screen plays the engine's move
        // here only if it is reading the task's depth. Reading Settings'
        // depth instead would still be waiting for 24, and the game would
        // not have ended yet.
        callback!(
            '1.00', 'd1d8', '', 1, 20, false, _fenAfter(task.fen, ['a5']));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.pumpAndSettle();

        expect(find.text('Goal not met'), findsOneWidget,
            reason: 'depth 20 clears the task\'s lako (18); reading '
                'Settings\' srednje (24) instead would still be waiting');
      }, () => MockClient((_) async => http.Response('{"ok":true}', 200)));
    });
  });

  group('the opponent sheet', () {
    testWidgets('is not offered on an assigned game', (tester) async {
      final task = EngineGameTask.fromJson({
        'fen': '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
        'side': 'w',
        'goal': 'hold',
        'plyCap': 40,
      })!;
      await http.runWithClient(() async {
        await _pump(tester, const Size(800, 900), task: task);
        expect(find.byType(EngineOpponentButton), findsNothing);
      }, () => MockClient((_) async => http.Response('{}', 200)));
    });

    testWidgets('is still offered on an ordinary drill', (tester) async {
      // Landscape, where the button actually lives on screen today — the
      // portrait header that would carry the same button
      // (`ai_studio_screen.dart`'s `backButtonCard`) is built but never
      // placed in the widget tree, on master already and unrelated to this
      // change; flagged separately rather than fixed here.
      tester.view.physicalSize = const Size(800, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await http.runWithClient(() async {
        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark()
                .copyWith(extensions: const [AppColorTokens.dark]),
            home: AiStudioScreen(
              userSession: _session,
              initialCategory: 'basic_mate',
              basicMateLevel: 'srednje',
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(EngineOpponentButton), findsOneWidget);
      }, () => MockClient((_) async => http.Response('{}', 200)));
    });
  });

  group('fits a phone', () {
    final task = EngineGameTask.fromJson({
      'fen': '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
      'side': 'w',
      'goal': 'survive',
      'surviveMoves': 5,
      'plyCap': 40,
    })!;

    testWidgets('portrait at 360×640, no overflow', (tester) async {
      await http.runWithClient(() async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark()
                .copyWith(extensions: const [AppColorTokens.dark]),
            home: AiStudioScreen(
              userSession: _session,
              initialCategory: 'engine_game',
              engineGameTask: task,
              assignmentId: 42,
            ),
          ),
        ));
        // Nothing is consumed here. The first frame throws no overflow once
        // the real font is loaded: measured on master for `basic_mate` and
        // for this screen at 360x640, first frame and settled.
        expect(tester.takeException(), isNull, reason: 'the first frame');
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }, () => MockClient((_) async => http.Response('{}', 200)));
    });

    testWidgets('landscape at 640×360, no overflow', (tester) async {
      await http.runWithClient(() async {
        await _pump(tester, const Size(640, 360), task: task);
        expect(tester.takeException(), isNull);
      }, () => MockClient((_) async => http.Response('{}', 200)));
    });
  });
}
