// „Assign to student" on a Library card — phase 0 of
// `docs/PLAN-MATERIJAL.md`.
//
// **A game exercise could never be assigned from its card.** The card posted
// to `/assignments/custom`, whose `createCustomAssignment` asks
// `assignableProblem(row)` with the default „as a find item" and so refused
// every game task — 400 once all were refused. The one writer of an
// `engine_game` assignment is a homework's send, so the card now opens the
// homework editor holding that one item; a find exercise keeps the direct
// dialog.
//
// **The dialog listed pending students**, whom the server then refuses. It
// lists accepted ones only.
//
// One fake server behind every seam, recording each request (rule 7): what the
// editor was given is read off the homework it saves, not off its arguments.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/puzzle_set_api_service.dart';
import 'package:chess_app/core/services/puzzle_set_repository.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/homework/screens/homework_editor_screen.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/features/position_scanner/widgets/assign_positions_dialog.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/theme/app_colors.dart';

const _findFen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
const _gameFen = '8/8/8/4k3/8/8/4P3/4K3 b - - 0 1';

/// The game exercise's task as the shelf sends it. Every field but `type` is
/// what the homework item must carry; `surviveMoves` is here so a copy that
/// kept only `fen`, `side` and `goal` would be seen.
const _gameTask = {
  'type': 'game',
  'fen': _gameFen,
  'side': 'b',
  'goal': 'hold',
  'surviveMoves': 20,
};

class _Server {
  final List<http.Request> requests = [];

  List<http.Request> posts(String path) =>
      requests.where((r) => r.method == 'POST' && r.url.path == path).toList();

  http.Client get client => MockClient((req) async {
        requests.add(req);
        final path = req.url.path;
        if (path.endsWith('/library/positions')) {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'kind': 'scan',
                  'id': 'cust_find',
                  'title': 'Mate in one',
                  'fen': _findFen,
                  'hasSolution': true,
                  'isExercise': true,
                  'solutionSan': 'Ra8#',
                  'assignable': true,
                },
                {
                  'kind': 'scan',
                  'id': 'ex_game',
                  'title': 'Hold the pawn ending',
                  'fen': _gameFen,
                  'assignable': true,
                  'origin': 'manual',
                  'task': _gameTask,
                  'isExercise': true,
                },
              ],
            }),
            200,
          );
        }
        if (path.endsWith('/trainer/students')) {
          return http.Response(
            jsonEncode({
              'students': [
                {'id': 5, 'name': 'Ana', 'status': 'accepted'},
                {'id': 6, 'name': 'Boris', 'status': 'pending'},
              ],
            }),
            200,
          );
        }
        if (path == '/assignments/custom' && req.method == 'POST') {
          return http.Response(jsonEncode({'id': 1, 'refused': []}), 201);
        }
        if (path == '/homeworks' && req.method == 'POST') {
          return http.Response(
              jsonEncode({'id': 1, 'title': 'X', 'items': <dynamic>[]}), 201);
        }
        if (path.endsWith('/puzzle-sets')) {
          return http.Response(jsonEncode({'items': []}), 200);
        }
        if (path.endsWith('/lessons/labels')) return http.Response('[]', 200);
        if (path.endsWith('/lessons')) return http.Response('[]', 200);
        return http.Response('{}', 404);
      });
}

Future<_Server> _open(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final server = _Server();
  final client = server.client;
  AnalysisPersistenceService.setInstance(
      AnalysisPersistenceService.withClient(client));
  addTearDown(AnalysisPersistenceService.resetInstance);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: LibraryScreen(
      session: UserSession(
          token: 'tok', id: 1, email: 'e', name: 'N', role: 'trener'),
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
      lessonApi: LessonApiService(authToken: 'tok', client: client),
      exerciseApi: ExerciseApiService(authToken: 'tok', client: client),
      homeworkApi: HomeworkApiService(authToken: 'tok', client: client),
      puzzleSets: PuzzleSetRepository(
        api: PuzzleSetApiService(authToken: 'tok', client: client),
      ),
      recordingApi: LessonRecordingApi(authToken: 'tok', client: client),
      scannerApi: ScannerApiService(authToken: 'tok', client: client),
    ),
  ));
  await tester.pumpAndSettle();
  return server;
}

Finder _assignOn(String kindAndId) => find.descendant(
      of: find.byKey(ValueKey('library-row-$kindAndId')),
      matching: find.byTooltip('Assign to student'),
    );

void main() {
  testWidgets(
      'a game exercise opens the homework editor holding that one item, '
      'and nothing is posted to /assignments/custom', (tester) async {
    final server = await _open(tester);
    expect(_assignOn('scan-ex_game'), findsOneWidget,
        reason: 'the game exercise lost its Assign button');

    await tester.tap(_assignOn('scan-ex_game'));
    await tester.pumpAndSettle();

    expect(find.byType(AssignPositionsDialog), findsNothing,
        reason: 'a game went to the dialog that can only make a find item');
    expect(find.byType(HomeworkEditorScreen), findsOneWidget);
    expect(find.byKey(const Key('homework-remove-new-1')), findsOneWidget,
        reason: 'the editor opened without the exercise in it');
    expect(find.byKey(const Key('homework-remove-new-2')), findsNothing);

    await tester.enterText(find.byKey(const Key('homework-title')), 'Hold it');
    await tester.tap(find.byKey(const Key('homework-save')));
    await tester.pumpAndSettle();

    final saved = server.posts('/homeworks');
    expect(saved, hasLength(1));
    final body = jsonDecode(saved.single.body) as Map<String, dynamic>;
    final items = (body['items'] as List).cast<Map<String, dynamic>>();
    expect(items, hasLength(1));
    expect(items.single['kind'], 'engine_game');
    expect(
        items.single['task'],
        {
          'fen': _gameFen,
          'side': 'b',
          'goal': 'hold',
          'surviveMoves': 20,
        },
        reason: 'the item carries the exercise\'s task minus its `type`');

    expect(server.posts('/assignments/custom'), isEmpty);
  });

  testWidgets('a find exercise still posts to /assignments/custom',
      (tester) async {
    final server = await _open(tester);
    await tester.tap(_assignOn('scan-cust_find'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeworkEditorScreen), findsNothing);
    expect(find.byType(AssignPositionsDialog), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Assignment title'), 'Mates');
    await tester.tap(find.widgetWithText(FilledButton, 'Assign'));
    await tester.pumpAndSettle();

    final posted = server.posts('/assignments/custom');
    expect(posted, hasLength(1));
    final body = jsonDecode(posted.single.body) as Map<String, dynamic>;
    expect(body['studentId'], 5);
    expect(body['puzzleIds'], ['cust_find']);
    expect(server.posts('/homeworks'), isEmpty);
  });

  testWidgets('the dialog lists accepted students only', (tester) async {
    await _open(tester);
    await tester.tap(_assignOn('scan-cust_find'));
    await tester.pumpAndSettle();

    // „Ana" is asked for first: „Boris is not there" is also true of a menu
    // that never opened.
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();

    expect(find.text('Ana'), findsWidgets,
        reason: 'the accepted student is missing — the menu is not open');
    expect(find.text('Boris'), findsNothing,
        reason: 'a pending student is offered, whom the server refuses');
  });
}
