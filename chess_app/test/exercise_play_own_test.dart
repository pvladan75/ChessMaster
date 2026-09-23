// One's own game exercise is played and recorded — docs/PLAN-MATERIJAL.md,
// phase 5.
//
// The Library card of one's own settled game exercise has „Play" (Solve, for
// a game): the exercise screen plays the task against the engine, and the end
// goes to `POST /exercises/:id/game-result` — never to an assignment. Alone,
// „Play N moves" is „played and nothing more" (decision 4): the dialog says
// „Played" and names no trainer. A game the tablebase did not answer is said
// not to have counted, because nothing asks again for one's own game.
//
// The engine is faked as `engine_game_screen_test.dart` fakes it: the screen
// attaches to the `StockfishService` singleton, and a test calls its handler
// with a chosen best move. The server is a MockClient behind the exercise
// seam; every other request is caught by `http.runWithClient` so a post to an
// assignment would be seen (rule 7).

import 'dart:convert';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';

import 'support/landscape.dart';

final _session =
    UserSession(id: 1, token: 'tok', email: 'e', name: 'N', role: 'korisnik');

const _mateFen = '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1';
const _rookFen = '4k3/8/8/8/8/8/8/4K2R w - - 0 1';

/// Every request the screen makes, by method and path.
class _Server {
  _Server(this.answer);
  final Map<String, Object?> answer;
  final List<http.Request> sent = [];

  http.Client get client => MockClient((req) async {
        sent.add(req);
        if (req.url.path.endsWith('/game-result')) {
          return http.Response(jsonEncode(answer), 200);
        }
        return http.Response('{}', 404);
      });

  List<String> get paths => [for (final r in sent) r.url.path];
}

Future<void> _tapSquare(WidgetTester tester, String square) async {
  final rect = tester.getRect(find.byType(SkinnedChessBoard).first);
  final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
  final rank = int.parse(square.substring(1));
  final size = rect.width / 8;
  await tester.tapAt(rect.topLeft +
      Offset(file * size + size / 2, (8 - rank) * size + size / 2));
  await tester.pump();
}

Future<void> _play(WidgetTester tester, String from, String to) async {
  await _tapSquare(tester, from);
  await _tapSquare(tester, to);
}

String _fenAfter(String start, List<String> sans) {
  final game = chess.Chess.fromFEN(start);
  for (final san in sans) {
    if (!game.move(san)) throw StateError('$san is not legal');
  }
  return game.fen;
}

Future<void> _engineReplies(
    WidgetTester tester, String bestMove, String fen) async {
  final callback = StockfishService().onEvaluationChanged;
  expect(callback, isNotNull, reason: 'the screen never asked the engine');
  callback!('1.00', bestMove, '', 1, 40, true, fen);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1100));
  await tester.pump();
}

/// The exercise screen over [task], posting to [server] as exercise `ex_1`.
/// Anything posted elsewhere lands in [stray].
Future<void> _screen(WidgetTester tester, Map<String, Object?> task,
    _Server server, List<String> stray, Future<void> Function() body) async {
  tester.view.physicalSize = const Size(800, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await http.runWithClient(() async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: AiStudioScreen(
          userSession: _session,
          initialCategory: 'engine_game',
          engineGameTask: EngineGameTask.fromJson(task)!,
          exerciseId: 'ex_1',
          exerciseApi:
              ExerciseApiService(authToken: 'tok', client: server.client),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await body();
  },
      () => MockClient((req) async {
            stray.add('${req.method} ${req.url.path}');
            return http.Response('{}', 404);
          }));
}

void main() {
  setUpAll(loadRoboto);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final service = StockfishService();
    service.onEvaluationChanged = null;
    service.onMultiPVUpdated = null;
    AppSettingsService.instance.setEnginePlayLevel('srednje');
  });

  group('the game goes to the exercise, and only there', () {
    testWidgets('a win: the moves are posted to /exercises/ex_1/game-result',
        (tester) async {
      final server = _Server({
        'goalMet': true,
        'judgedBy': 'rules',
        'pending': false,
        'ending': 'checkmate',
        'outcome': 'won',
      });
      final stray = <String>[];
      await _screen(
          tester,
          {'fen': _mateFen, 'side': 'w', 'goal': 'win', 'plyCap': 40},
          server,
          stray, () async {
        await _play(tester, 'd1', 'd8');
        await tester.pumpAndSettle();
        expect(find.text('Goal met'), findsOneWidget);
      });

      expect(server.paths, ['/exercises/ex_1/game-result']);
      final body = jsonDecode(server.sent.single.body) as Map<String, dynamic>;
      expect(body['moves'], ['Rd8#']);
      expect(body.containsKey('goalMet'), isFalse,
          reason: 'the client never sends a verdict');
      expect(stray.where((s) => s.contains('/assignments')), isEmpty,
          reason: 'an own game was posted to a homework');
    });

    testWidgets(
        'a hold the tablebase did not answer: not judged, and said not to '
        'have counted', (tester) async {
      final server = _Server({
        'goalMet': null,
        'judgedBy': null,
        'pending': true,
        'ending': 'moveTarget',
        'outcome': 'undecided',
      });
      await _screen(
          tester,
          {
            'fen': _rookFen,
            'side': 'w',
            'goal': 'hold',
            'surviveMoves': 2,
            'plyCap': 40
          },
          server,
          [], () async {
        await _play(tester, 'e1', 'd2');
        await tester.pump();
        await _engineReplies(tester, 'e8e7', _fenAfter(_rookFen, ['Kd2']));
        await _play(tester, 'd2', 'd3');
        await tester.pumpAndSettle();
        expect(find.text('Not judged yet'), findsOneWidget);
        expect(
            find.textContaining('this game was not counted'), findsOneWidget);
      });
      expect(server.paths, ['/exercises/ex_1/game-result']);
    });

    testWidgets('„Play N moves" alone is „Played", and no trainer is named',
        (tester) async {
      final server = _Server({
        'goalMet': null,
        'judgedBy': null,
        'pending': false,
        'ending': 'moveTarget',
        'outcome': 'undecided',
      });
      await _screen(
          tester,
          {
            'fen': _rookFen,
            'side': 'w',
            'goal': 'play',
            'surviveMoves': 2,
            'plyCap': 40
          },
          server,
          [], () async {
        await _play(tester, 'e1', 'd2');
        await tester.pump();
        await _engineReplies(tester, 'e8e7', _fenAfter(_rookFen, ['Kd2']));
        await _play(tester, 'd2', 'd3');
        await tester.pumpAndSettle();
        expect(find.text('Played'), findsOneWidget);
        expect(find.text('Not judged yet'), findsNothing);
        expect(find.textContaining('trainer'), findsNothing,
            reason: 'nobody is watching a game played alone');
      });
      expect(server.paths, ['/exercises/ex_1/game-result']);
    });
  });

  group('the Library card', () {
    Future<List<Route<dynamic>>> openLibrary(WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final client = MockClient((req) async {
        final path = req.url.path;
        if (path.endsWith('/library/positions')) {
          return http.Response(
              jsonEncode({
                'items': [
                  {
                    'kind': 'scan',
                    'id': 'ex_hold',
                    'title': 'Hold it',
                    'fen': _rookFen,
                    'origin': 'manual',
                    'isExercise': true,
                    'assignable': true,
                    'task': {
                      'type': 'game',
                      'fen': _rookFen,
                      'side': 'w',
                      'goal': 'hold',
                      'surviveMoves': 2,
                    },
                  },
                  {
                    'kind': 'scan',
                    'id': 'cust_find',
                    'title': 'Mate in one',
                    'fen': _mateFen,
                    'hasSolution': true,
                    'isExercise': true,
                    'assignable': true,
                  },
                  {
                    'kind': 'scan',
                    'id': 'ex_unsure',
                    'title': 'Side unknown',
                    'fen': _rookFen,
                    'isExercise': true,
                    'assignable': false,
                    'needsReview': true,
                    'task': {
                      'type': 'game',
                      'fen': _rookFen,
                      'side': 'w',
                      'goal': 'win',
                    },
                  },
                ],
              }),
              200);
        }
        if (path.endsWith('/lessons/labels')) return http.Response('[]', 200);
        if (path.endsWith('/lessons')) return http.Response('[]', 200);
        return http.Response('{}', 404);
      });
      AnalysisPersistenceService.setInstance(
          AnalysisPersistenceService.withClient(client));
      addTearDown(AnalysisPersistenceService.resetInstance);
      final pushed = <Route<dynamic>>[];
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: ThemeData.light()
              .copyWith(extensions: const [AppColorTokens.light]),
          navigatorObservers: [_Pushed(pushed)],
          home: LibraryScreen(
            session: _session,
            positionLibrary:
                PositionLibraryService(authToken: 'tok', client: client),
            lessonApi: LessonApiService(authToken: 'tok', client: client),
            exerciseApi: ExerciseApiService(authToken: 'tok', client: client),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return pushed;
    }

    Finder playOn(String id) => find.descendant(
        of: find.byKey(ValueKey('library-row-scan-$id')),
        matching: find.byTooltip('Play'));

    testWidgets('Play opens the game with its task and its exercise',
        (tester) async {
      await openLibrary(tester);
      await tester.tap(playOn('ex_hold'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      final screen = tester.widget<AiStudioScreen>(find.byType(AiStudioScreen));
      expect(screen.exerciseId, 'ex_hold');
      expect(screen.assignmentId, isNull);
      expect(screen.initialCategory, 'engine_game');
      expect(screen.engineGameTask!.fen, _rookFen);
      expect(screen.engineGameTask!.surviveMoves, 2);
    });

    testWidgets('Play is on a settled game exercise only', (tester) async {
      await openLibrary(tester);
      expect(playOn('ex_hold'), findsOneWidget);
      for (final id in ['cust_find', 'ex_unsure']) {
        expect(find.byKey(ValueKey('library-row-scan-$id')), findsOneWidget);
        expect(playOn(id), findsNothing, reason: '$id offers Play');
      }
    });
  });
}

class _Pushed extends NavigatorObserver {
  _Pushed(this.routes);
  final List<Route<dynamic>> routes;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      routes.add(route);
}
