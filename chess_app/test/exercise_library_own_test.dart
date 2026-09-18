// exercise_library_own_test.dart — the implementer's own tests for phase 4
// of `docs/PLAN-EXERCISE.md`, beyond what `exercise_library_test.dart` (the
// gate, copied unchanged from `docs/gates/`) already covers.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/homework/screens/homework_editor_screen.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/features/library/widgets/position_picker_dialog.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import 'support/landscape.dart';

const _fen = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';
const _winTask = {'type': 'game', 'fen': _fen, 'side': 'w', 'goal': 'win'};

Widget _light(Widget child) => MaterialApp(
      theme:
          ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
      home: Scaffold(body: child),
    );

void main() {
  setUpAll(loadRoboto);

  group('1. the Exercises chip\'s two filter rows', () {
    final entries = [
      const LibraryEntry(
        kind: LibraryKind.scan,
        id: 'find1',
        title: 'Find one',
        fen: _fen,
        assignable: true,
      ),
      const LibraryEntry(
        kind: LibraryKind.scan,
        id: 'win1',
        title: 'Win it',
        fen: _fen,
        assignable: true,
        origin: 'manual',
        task: _winTask,
      ),
      const LibraryEntry(
        kind: LibraryKind.position,
        id: 'p1',
        title: 'A position',
        fen: _fen,
        assignable: false,
      ),
    ];

    Future<void> pumpAt(WidgetTester tester, Size size,
        {LibraryChip chip = LibraryChip.exercises}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_light(LibraryList(
        entries: entries,
        onOpen: (_) {},
        initialChip: chip,
      )));
      await tester.pumpAndSettle();
    }

    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets(
          'both rows are present and nothing overflows at '
          '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        await pumpAt(tester, size);
        expect(tester.takeException(), isNull);

        final list = find.byType(LibraryList);
        for (final label in ['Find the move', 'Win', 'Draw or better']) {
          expect(
            find.descendant(
                of: list, matching: find.widgetWithText(ChoiceChip, label)),
            findsOneWidget,
            reason: label,
          );
        }
        for (final label in ['From a book', 'Made by me', 'From mistakes']) {
          expect(
            find.descendant(
                of: list, matching: find.widgetWithText(ChoiceChip, label)),
            findsOneWidget,
            reason: label,
          );
        }
      });
    }

    testWidgets('selecting Win leaves only the win exercise\'s row',
        (tester) async {
      await pumpAt(tester, const Size(360, 640));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Win'));
      await tester.pumpAndSettle();

      expect(find.text('Find one'), findsNothing);
      expect(find.text('Win it'), findsOneWidget);
    });

    testWidgets('under the Positions chip the filter rows are absent',
        (tester) async {
      await pumpAt(tester, const Size(360, 640), chip: LibraryChip.positions);
      final list = find.byType(LibraryList);
      for (final label in [
        'Find the move',
        'Win',
        'Draw or better',
        'From a book',
        'Made by me',
        'From mistakes',
      ]) {
        expect(
          find.descendant(
              of: list, matching: find.widgetWithText(ChoiceChip, label)),
          findsNothing,
          reason: label,
        );
      }
    });
  });

  group('2. PositionPickerDialog by purpose', () {
    Future<List<LibraryEntry>?> fixture(
            {LibraryKind? kind, String? search}) async =>
        [
          const LibraryEntry(
            kind: LibraryKind.scan,
            id: 'cust_1',
            title: 'An exercise',
            fen: _fen,
            assignable: true,
          ),
          const LibraryEntry(
            kind: LibraryKind.position,
            id: 'pos_1',
            title: 'A position',
            fen: _fen,
            assignable: true,
          ),
        ];

    Future<void> pump(WidgetTester tester, PickerPurpose purpose) async {
      await tester.pumpWidget(_light(Builder(
        builder: (context) => PositionPickerDialog(
          service: PositionLibraryService(authToken: 't'),
          purpose: purpose,
          loader: fixture,
        ),
      )));
      await tester.pumpAndSettle();
    }

    testWidgets('a position row is not offered for homework', (tester) async {
      await pump(tester, PickerPurpose.homework);
      expect(find.text('An exercise'), findsOneWidget);
      expect(find.text('A position'), findsNothing);
    });

    testWidgets('a position row is still offered for a lesson', (tester) async {
      await pump(tester, PickerPurpose.lesson);
      expect(find.text('An exercise'), findsOneWidget);
      expect(find.text('A position'), findsOneWidget);
      // The same boards in this dialog's rows (brief item 5).
      expect(find.byType(BoardThumbnail), findsNWidgets(2));
    });
  });

  group('3. the homework editor\'s Add sheet', () {
    testWidgets(
        'shows three choices, no Play it out, and two exercises add two rows',
        (tester) async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path == '/library/positions' && request.method == 'GET') {
          return http.Response(
              jsonEncode({
                'items': [
                  {
                    'kind': 'scan',
                    'id': 'find_9',
                    'title': 'Mate in 1',
                    'fen': _fen,
                    'assignable': true,
                  },
                  {
                    'kind': 'scan',
                    'id': 'game_9',
                    'title': 'Win it',
                    'fen': _fen,
                    'assignable': true,
                    'origin': 'manual',
                    'task': _winTask,
                  },
                ],
              }),
              200);
        }
        if (path == '/homeworks' && request.method == 'POST') {
          return http.Response(
              jsonEncode({'id': 1, 'title': 'X', 'items': <dynamic>[]}), 201);
        }
        return http.Response('{"error":"not found"}', 404);
      });
      final api = HomeworkApiService(authToken: 'tok', client: client);

      tester.view.physicalSize = const Size(400, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: HomeworkEditorScreen(homeworkId: null, api: api),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('homework-add')));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNWidgets(3));
      expect(find.text('A tutorial'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);
      expect(find.text('A puzzle set'), findsOneWidget);
      expect(find.text('Play it out'), findsNothing);

      await tester.tap(find.text('Exercises'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mate in 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Win it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add (2)'));
      await tester.pumpAndSettle();

      // Two rows, not one: a find exercise and a game exercise.
      expect(find.byKey(const Key('homework-remove-new-1')), findsOneWidget);
      expect(find.byKey(const Key('homework-remove-new-2')), findsOneWidget);
      expect(find.byKey(const Key('homework-remove-new-3')), findsNothing);

      await tester.enterText(
          find.byKey(const Key('homework-title')), 'Two exercises');
      await tester.tap(find.byKey(const Key('homework-save')));
      await tester.pumpAndSettle();

      final saved = requests
          .where((r) => r.method == 'POST' && r.url.path == '/homeworks')
          .toList();
      expect(saved, hasLength(1));
      final body = jsonDecode(saved.single.body) as Map<String, dynamic>;
      final items = (body['items'] as List).cast<Map<String, dynamic>>();
      expect(items.map((i) => i['kind']), ['positions', 'engine_game']);
      expect(items[0]['task'], {
        'puzzleIds': ['find_9']
      });
      expect(items[1]['task']['fen'], _fen);
      expect(items[1]['task']['side'], 'w');
      expect(items[1]['task']['goal'], 'win');
    });
  });

  group('4. an engine_game item already saved', () {
    testWidgets('opens, shows it, and saves it back unchanged', (tester) async {
      const task = {'fen': _fen, 'side': 'w', 'goal': 'win'};
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/homeworks/9') {
          return http.Response(
              jsonEncode({
                'id': 9,
                'title': 'Existing',
                'items': [
                  {
                    'item_key': 'k1',
                    'kind': 'engine_game',
                    'task': task,
                    'gate': false,
                  },
                ],
              }),
              200);
        }
        if (request.method == 'PUT' && request.url.path == '/homeworks/9') {
          return http.Response(
              jsonEncode({
                'id': 9,
                'title': 'Existing',
                'items': [
                  {
                    'item_key': 'k1',
                    'kind': 'engine_game',
                    'task': task,
                    'gate': false,
                  },
                ],
              }),
              200);
        }
        return http.Response('{"error":"not found"}', 404);
      });
      final api = HomeworkApiService(authToken: 'tok', client: client);

      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: HomeworkEditorScreen(homeworkId: 9, api: api),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Play it out'), findsOneWidget);

      await tester.tap(find.byKey(const Key('homework-save')));
      await tester.pumpAndSettle();

      final saved = requests.where((r) => r.method == 'PUT').toList();
      expect(saved, hasLength(1));
      final body = jsonDecode(saved.single.body) as Map<String, dynamic>;
      final items = (body['items'] as List).cast<Map<String, dynamic>>();
      expect(items, hasLength(1));
      expect(items.single['kind'], 'engine_game');
      expect(items.single['itemKey'], 'k1');
      expect(items.single['task'], task);
    });
  });

  group('5. the room\'s column', () {
    testWidgets('offers the Exercises chip', (tester) async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/library/positions')) {
          return http.Response(jsonEncode({'items': <dynamic>[]}), 200);
        }
        if (req.url.path.endsWith('/lessons/labels')) {
          return http.Response(jsonEncode(<String>[]), 200);
        }
        return http.Response('{}', 404);
      });

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData.light()
            .copyWith(extensions: const [AppColorTokens.light]),
        home: ChessGamePage(
          userSession: UserSession(
              id: 1, token: 'tok', email: 'e', name: 'N', role: 'trener'),
          roomCode: 'STUDIO',
          initialRole: 'trener',
          lessonApi: LessonApiService(authToken: 'tok', client: client),
          positionLibrary:
              PositionLibraryService(authToken: 'tok', client: client),
        ),
      ));
      await tester.pumpAndSettle();

      final column = find.byType(LibraryList);
      expect(column, findsOneWidget);
      expect(find.descendant(of: column, matching: find.text('Exercises')),
          findsOneWidget);
    });
  });

  group('6. New exercise', () {
    testWidgets('present under Exercises, absent under other chips',
        (tester) async {
      await tester.pumpWidget(_light(LibraryList(
        entries: const [],
        onOpen: (_) {},
        initialChip: LibraryChip.exercises,
        onNewExercise: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-new-exercise')), findsOneWidget);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Positions'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-new-exercise')), findsNothing);
    });

    testWidgets('absent when no door was given, even under Exercises',
        (tester) async {
      await tester.pumpWidget(_light(LibraryList(
        entries: const [],
        onOpen: (_) {},
        initialChip: LibraryChip.exercises,
      )));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('library-new-exercise')), findsNothing);
    });
  });
}
