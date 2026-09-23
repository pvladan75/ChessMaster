// Extra widget tests for phase 3b of `docs/PLAN-DOMACI-ZADATAK.md` — the
// trainer's homework editor and its two doors — that the copied gate
// (`homework_editor_test.dart`) does not reach:
//
//   1. Reachability, pumped: the Teach card and the Library chip, found at
//      360×800 and 800×360, each actually opening the homework list
//      (CLAUDE.md rule 10 — a control nothing places in the tree is not a
//      feature).
//   2. Adding one item of each of the four kinds, asserting the saved body
//      carries the right `kind` and a task the server would accept.
//   3. A refusal — 400 with the server's own sentence — reaches the screen,
//      and the editor does not claim it saved.
//
// Every fake here is a `MockClient` that answers by URL *path*, and every
// assertion below reads the recorded request rather than trusting what the
// fake handed back — a `MockClient` answers whatever it is asked, so a wrong
// address is invisible unless the address itself is checked (CLAUDE.md rule
// 7, and the `/api/assignments` slip of phase 2b).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/homework/screens/homework_editor_screen.dart';
import 'package:chess_app/features/homework/screens/homework_list_screen.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/features/homework/widgets/homework_library_card.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/home/teach_tab.dart';

import 'support/landscape.dart';

UserSession _session() => UserSession(
      token: 'tok',
      id: 1,
      email: 't@example.com',
      name: 'Trainer',
      role: 'trener',
    );

/// One client, every endpoint an "Add" flow or the Library screen can reach —
/// so a single recorder sees all of it, the same rule the editor's own
/// pickers are built on (one shared `http.Client`).
class _MultiRecorder {
  final List<http.Request> requests = [];

  http.Client client() => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        final method = request.method;

        if (path == '/lessons' && method == 'GET') {
          return http.Response(
              jsonEncode([
                {
                  'id': 5,
                  'title': 'My Tutorial',
                  'position_list': [1],
                },
              ]),
              200);
        }
        if (path == '/library/positions' && method == 'GET') {
          return http.Response(
              jsonEncode({
                'items': [
                  {
                    'kind': 'scan',
                    'id': 'cust_1',
                    'title': 'Mate in 2',
                    'fen': '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
                    'assignable': true,
                    'hasSolution': true,
                    'isExercise': true,
                  },
                  // A game exercise — made in Preparation since phase 3b, and
                  // picked here through the same „Exercises" door as a
                  // find-the-move one (`docs/PLAN-EXERCISE.md` phase 4).
                  {
                    'kind': 'scan',
                    'id': 'cust_2',
                    'title': 'Win it',
                    'fen': '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
                    'assignable': true,
                    'origin': 'manual',
                    'isExercise': true,
                    'task': {
                      'type': 'game',
                      'fen': '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
                      'side': 'w',
                      'goal': 'win',
                    },
                  },
                ],
              }),
              200);
        }
        if (path == '/lessons/labels' && method == 'GET') {
          return http.Response(jsonEncode(<String>[]), 200);
        }
        if (path == '/homeworks' && method == 'GET') {
          return http.Response(jsonEncode({'homeworks': <dynamic>[]}), 200);
        }
        if (path == '/homeworks' && method == 'POST') {
          final sentTitle =
              (jsonDecode(request.body) as Map)['title']?.toString() ?? '';
          return http.Response(
              jsonEncode({
                'id': 1,
                'title': sentTitle,
                'instructions': null,
                'items': <dynamic>[],
              }),
              201);
        }
        return http.Response('{"error":"not found"}', 404);
      });

  List<http.Request> to(String path, {String? method}) => requests
      .where(
          (r) => r.url.path == path && (method == null || r.method == method))
      .toList();

  Map<String, dynamic> bodyOf(String path, String method) =>
      jsonDecode(to(path, method: method).last.body) as Map<String, dynamic>;
}

/// A client that answers `/homeworks` with a fixed refusal, for the "a
/// refusal is shown" test.
class _RefusingRecorder {
  final List<http.Request> requests = [];

  http.Client client() => MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/homeworks') {
          return http.Response(jsonEncode({'homeworks': <dynamic>[]}), 200);
        }
        return http.Response(
          jsonEncode({
            'error': 'item 2: a positions item needs at least one position.',
          }),
          400,
        );
      });
}

void main() {
  setUpAll(loadRoboto);

  group('reachability, pumped', () {
    for (final size in [const Size(360, 800), const Size(800, 360)]) {
      testWidgets(
          'the Teach card opens the homework list at '
          '${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        final recorder = _MultiRecorder();
        final api =
            HomeworkApiService(authToken: 'tok', client: recorder.client());

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppColorTokens.dark]),
          home: Scaffold(
            body: TeachTab(
              homeworkCard: HomeworkLibraryCard(session: _session(), api: api),
              onOpenPreparation: () {},
              onStartSession: () async {},
              onOpenLibrary: () {},
              onOpenScanner: () {},
              studentsSection: const SizedBox(),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final card = find.byKey(const Key('homework-teach-card'));
        expect(card, findsOneWidget,
            reason: 'the card is actually in the tree');
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('homework-teach-open')));
        await tester.pumpAndSettle();

        expect(find.byType(HomeworkListScreen), findsOneWidget);
        expect(recorder.to('/homeworks', method: 'GET'), isNotEmpty,
            reason: 'the list actually asked the server for homeworks');
      });
    }

    for (final size in [const Size(360, 800), const Size(800, 360)]) {
      testWidgets(
          'the Library chip opens the homework list at '
          '${size.width.toInt()}×${size.height.toInt()}', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final recorder = _MultiRecorder();
        final client = recorder.client();

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppColorTokens.dark]),
          home: LibraryScreen(
            session: _session(),
            lessonApi: LessonApiService(authToken: 'tok', client: client),
            positionLibrary:
                PositionLibraryService(authToken: 'tok', client: client),
            homeworkApi: HomeworkApiService(authToken: 'tok', client: client),
          ),
        ));
        await tester.pumpAndSettle();

        final chip = find.byKey(const Key('library-homework-chip'));
        expect(chip, findsOneWidget,
            reason: 'the chip is actually in the tree');
        expect(tester.takeException(), isNull);

        await tester.tap(chip);
        await tester.pumpAndSettle();

        expect(find.byType(HomeworkListScreen), findsOneWidget);
      });
    }
  });

  group('adding an item', () {
    // Until `docs/PLAN-EXERCISE.md` phase 4, 18.9.2026, „Positions" and „Play
    // it out" were two separate doors. Superseded the same day: a trainer
    // does not send a position, they send an exercise, so both are now one
    // door — „Exercises" — and picking a find one together with a game one
    // adds two rows (`homeworkItemsFromExercises`).
    testWidgets(
        'a tutorial, two exercises and a puzzle set carry the right '
        'kind and task', (tester) async {
      final recorder = _MultiRecorder();
      final api =
          HomeworkApiService(authToken: 'tok', client: recorder.client());

      // Tall enough that "Add" and "Save" stay reachable with four rows on
      // screen — this test drives the flow, it does not measure layout.
      tester.view.physicalSize = const Size(400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: HomeworkEditorScreen(homeworkId: null, api: api),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('homework-title')), 'Mixed homework');

      // A tutorial.
      await tester.tap(find.byKey(const Key('homework-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A tutorial'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Tutorial'));
      await tester.pumpAndSettle();

      // Exercises — one find, one game, picked together.
      await tester.tap(find.byKey(const Key('homework-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Exercises'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mate in 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Win it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add (2)'));
      await tester.pumpAndSettle();

      // A puzzle set — defaults are enough.
      await tester.tap(find.byKey(const Key('homework-add')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('A puzzle set'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('homework-puzzle-submit')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Three doors, not four: „Play it out" is gone from the sheet — an
      // existing row already labelled that way (the game exercise just
      // added) must not make this a false pass.
      await tester.tap(find.byKey(const Key('homework-add')));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Play it out'), findsNothing);
      await tester.tapAt(const Offset(1, 1)); // dismiss the sheet
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('homework-save')));
      await tester.pumpAndSettle();

      expect(recorder.to('/homeworks', method: 'POST'), isNotEmpty);
      final body = recorder.bodyOf('/homeworks', 'POST');
      final items = (body['items'] as List).cast<Map<String, dynamic>>();
      expect(items.map((i) => i['kind']),
          ['lesson', 'positions', 'engine_game', 'puzzles']);

      expect(items[0]['task']['lessonId'], 5);
      expect(items[1]['task']['puzzleIds'], ['cust_1']);
      expect(items[2]['task']['fen'], '4k3/8/8/8/8/8/8/4K2R w - - 0 1');
      expect(items[2]['task']['side'], 'w');
      expect(items[2]['task']['goal'], 'win');
      expect(items[3]['task']['count'], isA<int>());

      // New items send no key at all.
      for (final item in items) {
        expect(item.containsKey('itemKey'), isFalse);
      }
    });
  });

  group('a refusal', () {
    testWidgets('is shown, and the editor does not claim it saved',
        (tester) async {
      final recorder = _RefusingRecorder();
      final api =
          HomeworkApiService(authToken: 'tok', client: recorder.client());

      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: HomeworkEditorScreen(homeworkId: null, api: api),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byKey(const Key('homework-title')), 'Will be refused');
      await tester.tap(find.byKey(const Key('homework-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('item 2: a positions item needs at least one position.'),
        findsOneWidget,
      );
      expect(find.text('Homework saved.'), findsNothing);
    });
  });
}
