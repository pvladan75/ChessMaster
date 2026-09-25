// A side nobody set is asked before a saved position is used — the owner,
// 23.9.2026: „popravi ovu rupu".
//
// A diagram does not print who is to move, and a FEN cannot say „nobody
// knows", so such a position is stored with White and marked for review. Only
// Saved Positions asked. The Library opened it in Analysis, made an exercise
// of it and added it to a tutorial as White to move, and the room put it on
// the shared board so — and the exercise made that way carried no mark, so it
// could reach a student. Every one of those doors now goes through
// `settledFen` (side_to_move_gate.dart).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/features/position_scanner/widgets/side_to_move_gate.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/theme/app_colors.dart';

const _unset = '4k3/8/8/8/8/8/8/R3K3 w - - 0 1';
const _settledBlack = '4k3/8/8/8/8/8/8/R3K3 b - - 0 1';
const _known = '6k1/5ppp/8/8/8/8/5PPP/3R2K1 w - - 0 1';

class _Server {
  _Server({this.refuse = false});

  /// The server refusing the side, as it does for one that cannot be to move.
  final bool refuse;
  final List<http.Request> sent = [];

  List<http.Request> get patches =>
      sent.where((r) => r.method == 'PATCH').toList();

  late final http.Client client = MockClient((req) async {
    sent.add(req);
    final path = req.url.path;
    if (req.method == 'PATCH' && path == '/scans/puzzles/u1') {
      if (refuse) {
        return http.Response(jsonEncode({'error': 'cannot'}), 422);
      }
      final side = (jsonDecode(req.body) as Map)['sideToMove'];
      return http.Response(
          jsonEncode({'fen': '4k3/8/8/8/8/8/8/R3K3 $side - - 0 1'}), 200);
    }
    if (path.endsWith('/library/positions')) {
      return http.Response(
          jsonEncode({
            'items': [
              {
                'kind': 'scan',
                'id': 'u1',
                'title': 'Side never set',
                'fen': _unset,
                'needsReview': true,
                'sourceTitle': 'Silman',
                'sourcePage': 12,
              },
              {
                'kind': 'scan',
                'id': 'k1',
                'title': 'Side known',
                'fen': _known,
                'instruction': 'White to play and win.',
                'sourceTitle': 'Silman',
                'sourcePage': 13,
              },
            ],
          }),
          200);
    }
    if (req.method == 'GET' && path == '/lessons') {
      return http.Response(
          jsonEncode([
            {'id': 7, 'title': 'Rook endings', 'position_list': []}
          ]),
          200);
    }
    if (req.method == 'POST' && path == '/lessons/7/steps') {
      return http.Response(jsonEncode({'ok': true}), 200);
    }
    if (path.endsWith('/puzzle-sets')) {
      return http.Response(jsonEncode({'items': []}), 200);
    }
    if (path.endsWith('/lessons/labels')) return http.Response('[]', 200);
    return http.Response('{}', 404);
  });
}

Future<_Server> _openLibrary(WidgetTester tester, {bool refuse = false}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final server = _Server(refuse: refuse);
  final client = server.client;
  AnalysisPersistenceService.setInstance(
      AnalysisPersistenceService.withClient(client));
  addTearDown(AnalysisPersistenceService.resetInstance);
  final router = GoRouter(
    initialLocation: '/library',
    routes: [
      GoRoute(
        path: '/library',
        builder: (_, __) => LibraryScreen(
          session: UserSession(
              token: 'tok', id: 1, email: 'e', name: 'N', role: 'trener'),
          positionLibrary:
              PositionLibraryService(authToken: 'tok', client: client),
          lessonApi: LessonApiService(authToken: 'tok', client: client),
          exerciseApi: ExerciseApiService(authToken: 'tok', client: client),
          recordingApi: LessonRecordingApi(authToken: 'tok', client: client),
          scannerApi: ScannerApiService(authToken: 'tok', client: client),
        ),
      ),
      GoRoute(
        path: AppRoutes.analysis,
        builder: (_, state) => Scaffold(
            body: Text('ROUTE-ANALYSIS ${state.uri.queryParameters['fen']}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    routerConfig: router,
  ));
  await tester.pumpAndSettle();
  return server;
}

Finder _card(String id) => find.byKey(ValueKey('library-row-scan-$id'));

Finder _button(String id, String tooltip) =>
    find.descendant(of: _card(id), matching: find.byTooltip(tooltip));

Future<void> _answer(WidgetTester tester, String key) async {
  expect(find.byKey(const ValueKey('side-to-move-dialog')), findsOneWidget,
      reason: 'the side was not asked');
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

void main() {
  group('the gate itself', () {
    testWidgets('a position whose side is known passes without a question',
        (tester) async {
      final server = _Server();
      String? got;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => got = await settledFen(context,
                api: ScannerApiService(authToken: 't', client: server.client),
                puzzleId: 'k1',
                fen: _known,
                needsReview: false),
            child: const Text('go'),
          ),
        ),
      ));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(got, _known);
      expect(find.byKey(const ValueKey('side-to-move-dialog')), findsNothing);
      expect(server.sent, isEmpty);
    });
  });

  group('the Library', () {
    testWidgets('the card says the side is not set, and only that card',
        (tester) async {
      await _openLibrary(tester);
      String subtitle(String id) => tester
          .widget<Text>(find.byKey(ValueKey('library-subtitle-scan-$id')))
          .data!;
      expect(subtitle('u1'), startsWith('Side to move not set'));
      expect(subtitle('k1'), isNot(contains('Side to move')));
    });

    testWidgets('opening asks first, keeps the answer, and opens that side',
        (tester) async {
      final server = await _openLibrary(tester);
      await tester.tap(find.descendant(
          of: _card('u1'), matching: find.text('Side never set')));
      await tester.pumpAndSettle();
      await _answer(tester, 'side-to-move-black');
      expect(server.patches.single.body, contains('"sideToMove":"b"'));
      expect(find.text('ROUTE-ANALYSIS $_settledBlack'), findsOneWidget);
    });

    testWidgets('a known side opens without a question', (tester) async {
      final server = await _openLibrary(tester);
      await tester.tap(
          find.descendant(of: _card('k1'), matching: find.text('Side known')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('side-to-move-dialog')), findsNothing);
      expect(server.patches, isEmpty);
      expect(find.text('ROUTE-ANALYSIS $_known'), findsOneWidget);
    });

    testWidgets('„Make exercise" asks first and makes it on the side answered',
        (tester) async {
      final server = await _openLibrary(tester);
      await tester.tap(_button('u1', 'Make exercise'));
      await tester.pumpAndSettle();
      await _answer(tester, 'side-to-move-black');
      expect(server.patches, hasLength(1));
      final sheet =
          tester.widget<MakeExerciseSheet>(find.byType(MakeExerciseSheet));
      expect(sheet.moveTree!.root.fen, _settledBlack,
          reason: 'the exercise was made on the side nobody chose');
    });

    testWidgets('backing out of the question makes nothing', (tester) async {
      final server = await _openLibrary(tester);
      await tester.tap(_button('u1', 'Make exercise'));
      await tester.pumpAndSettle();
      await _answer(tester, 'side-to-move-cancel');
      expect(find.byType(MakeExerciseSheet), findsNothing);
      expect(server.patches, isEmpty);
    });

    testWidgets('a side the server refuses is said, and nothing is made',
        (tester) async {
      await _openLibrary(tester, refuse: true);
      await tester.tap(_button('u1', 'Make exercise'));
      await tester.pumpAndSettle();
      await _answer(tester, 'side-to-move-white');
      expect(find.byType(MakeExerciseSheet), findsNothing);
      expect(find.text('That side cannot be to move in this position.'),
          findsOneWidget);
    });

    testWidgets('„Add to tutorial" asks first and adds the side answered',
        (tester) async {
      final server = await _openLibrary(tester);
      await tester.tap(_button('u1', 'Add to tutorial'));
      await tester.pumpAndSettle();
      await _answer(tester, 'side-to-move-black');
      await tester.tap(find.text('Rook endings'));
      await tester.pumpAndSettle();
      final step = server.sent.lastWhere(
          (r) => r.method == 'POST' && r.url.path == '/lessons/7/steps');
      expect(step.body, contains(_settledBlack));
      expect(step.body, isNot(contains(_unset)));
    });

    testWidgets('„Add to tutorial" makes the task the part\'s first sentence',
        (tester) async {
      // Every part shows (docs/PLAN-TUTORIJAL-VIDEO.md, phase 4), and a film
      // reads the sentences on the board, not a task beside it — so the task
      // arrives as the comment on the part's starting position, where the
      // video says it.
      final server = await _openLibrary(tester);
      await tester.tap(_button('k1', 'Add to tutorial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rook endings'));
      await tester.pumpAndSettle();
      final sent = server.sent.lastWhere(
          (r) => r.method == 'POST' && r.url.path == '/lessons/7/steps');
      final step = (jsonDecode(sent.body) as Map)['step'] as Map;
      expect(step['fen'], _known);
      expect(step['pgn'], contains('{ White to play and win. }'));
      for (final field in ['instruction', 'kind', 'solutionSan']) {
        expect(step.containsKey(field), isFalse, reason: field);
      }
    });
  });
}
