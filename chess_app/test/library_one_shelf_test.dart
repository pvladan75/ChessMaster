// The Library is the one shelf — docs/PLAN-MATERIJAL.md, phase 3.
//
// - A scanned position becomes an exercise **in place**: „Make exercise" on a
//   scan saves by `PUT /exercises/<its id>` and never `POST`s a copy, so the
//   row keeps its book, page and number.
// - The Library absorbs what Saved Positions had and it lacked: a **Source**
//   choice and **Needs attention (n)** under Exercises and Positions, and a
//   search that reads the book, the printed number and the task as well as
//   the title and labels.
// - „Assign to student" is drawn only for an account with an accepted
//   student — and kept when that cannot be asked.
// - Saved Positions is gone: the router has no `/scan/saved`, and the
//   scanner's „View" opens the Library on the book just saved.
//
// One fake server behind every seam, recording each request (rule 7).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/puzzle_set_api_service.dart';
import 'package:chess_app/core/services/puzzle_set_repository.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/features/position_scanner/screens/image_scan_screen.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_router.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';

const _fen = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';

Map<String, Object?> _scan(String id, String title,
        {required bool exercise,
        String? book,
        String? label,
        List<String> themes = const [],
        String? instruction,
        bool needsReview = false}) =>
    {
      'kind': 'scan',
      'id': id,
      'title': title,
      'fen': _fen,
      'origin': 'book',
      'hasSolution': exercise,
      'isExercise': exercise,
      'assignable': exercise && !needsReview,
      'needsReview': needsReview,
      'sourceTitle': book,
      'sourcePage': 12,
      'sourceLabel': label,
      'themes': themes,
      'instruction': instruction,
    };

/// Two books whose exercises share a label („pin"), so the label cannot do
/// the source filter's job (rule 6). No title names its book, its number or
/// its task, so a search that finds one found it by those fields.
List<Map<String, Object?>> _shelf({bool bareMadeExercise = false}) => [
      _scan('cust_bare', 'Diagram 12',
          exercise: bareMadeExercise, book: 'Mat u 333', label: '97'),
      _scan('cust_a1', 'Diagram A1',
          exercise: true, book: 'Endgames.pdf', label: 'xq7', themes: ['pin']),
      _scan('cust_b1', 'Diagram B1',
          exercise: true,
          book: 'Tactics.pdf',
          themes: ['pin'],
          instruction: 'White saves the rook.',
          needsReview: true),
      _scan('cust_b2', 'Diagram B2',
          exercise: true, book: 'Tactics.pdf', themes: ['fork']),
    ];

class _Server {
  _Server({this.students});

  /// `/trainer/students` — null answers 500, a server that cannot be asked.
  final List<Map<String, Object?>>? students;
  final List<http.Request> requests = [];
  bool _made = false;

  http.Client get client => MockClient((req) async {
        requests.add(req);
        final path = req.url.path;
        if (path.endsWith('/library/positions')) {
          return http.Response(
              jsonEncode({'items': _shelf(bareMadeExercise: _made)}), 200);
        }
        if (req.method == 'PUT' && path == '/exercises/cust_bare') {
          _made = true;
          final sent = jsonDecode(req.body) as Map<String, dynamic>;
          return http.Response(
              jsonEncode({
                'exercise': {
                  'id': 'cust_bare',
                  'fen': _fen,
                  'sideToMove': 'w',
                  'name': sent['name'],
                  'themes': <String>[],
                  'origin': 'book',
                  'sourceTitle': 'Mat u 333',
                  'task': sent['task'],
                  'solution': null,
                  'needsReview': false,
                  'assignable': true,
                },
              }),
              200);
        }
        if (path.endsWith('/trainer/students')) {
          final s = students;
          return s == null
              ? http.Response('{"error":"down"}', 500)
              : http.Response(jsonEncode({'students': s}), 200);
        }
        if (path.endsWith('/puzzle-sets')) {
          return http.Response(jsonEncode({'items': []}), 200);
        }
        if (path.endsWith('/lessons/labels')) return http.Response('[]', 200);
        if (path.endsWith('/lessons')) return http.Response('[]', 200);
        return http.Response('{}', 404);
      });

  List<http.Request> to(String method, String pathPart) => requests
      .where((r) => r.method == method && r.url.path.contains(pathPart))
      .toList();
}

Future<_Server> _open(WidgetTester tester,
    {Size size = const Size(1200, 800),
    List<Map<String, Object?>>? students = const []}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final server = _Server(students: students);
  final client = server.client;
  AnalysisPersistenceService.setInstance(
      AnalysisPersistenceService.withClient(client));
  addTearDown(AnalysisPersistenceService.resetInstance);

  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: LibraryScreen(
      session: UserSession(
          token: 'tok', id: 1, email: 'e', name: 'N', role: 'korisnik'),
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
      lessonApi: LessonApiService(authToken: 'tok', client: client),
      exerciseApi: ExerciseApiService(authToken: 'tok', client: client),
      homeworkApi: HomeworkApiService(authToken: 'tok', client: client),
      groupApi: GroupApiService(client: client),
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

Future<void> _chip(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(ChoiceChip, label));
  await tester.pumpAndSettle();
}

List<String> _shown(WidgetTester tester) => [
      for (final id in ['cust_bare', 'cust_a1', 'cust_b1', 'cust_b2'])
        if (find.byKey(ValueKey('library-row-scan-$id')).evaluate().isNotEmpty)
          id,
    ];

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(
      find.widgetWithText(TextField, LibraryList.searchHint), text);
  await tester.pumpAndSettle();
}

void main() {
  group('a scanned position becomes an exercise in place', () {
    testWidgets('Make exercise sends PUT /exercises/<its id> and no POST',
        (tester) async {
      final server = await _open(tester);
      await _chip(tester, 'Positions');
      expect(_shown(tester), ['cust_bare']);

      await tester.tap(find.descendant(
          of: find.byKey(const ValueKey('library-row-scan-cust_bare')),
          matching: find.byTooltip('Make exercise')));
      await tester.pumpAndSettle();
      // The name starts as the entry's own.
      expect(
          tester
              .widget<TextField>(find.byKey(const Key('exercise-name-field')))
              .controller!
              .text,
          'Diagram 12');
      await tester.tap(find.byKey(const Key('exercise-ask-win')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('exercise-side-w')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
      await tester.pumpAndSettle();

      expect(server.to('POST', '/exercises'), isEmpty,
          reason: 'a copy was made instead of the row itself');
      final put = server.to('PUT', '/exercises/cust_bare');
      expect(put, hasLength(1));
      final body = jsonDecode(put.single.body) as Map<String, dynamic>;
      expect(body.containsKey('fen'), isFalse,
          reason: 'an edit in place says nothing about the position');
      expect(body['name'], 'Diagram 12');

      // And it now stands with the exercises, from its book.
      await _chip(tester, 'Exercises');
      await _chip(tester, 'From a book');
      expect(_shown(tester), contains('cust_bare'));
    });
  });

  group('what Saved Positions had', () {
    testWidgets('the source narrows to one book, which a label could not',
        (tester) async {
      await _open(tester);
      await _chip(tester, 'Exercises');
      expect(_shown(tester), ['cust_a1', 'cust_b1', 'cust_b2']);

      await tester.tap(find.byKey(const Key('library-source')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tactics.pdf').last);
      await tester.pumpAndSettle();
      expect(_shown(tester), ['cust_b1', 'cust_b2']);
    });

    testWidgets('Needs attention shows only what needs it', (tester) async {
      await _open(tester);
      await _chip(tester, 'Exercises');
      final chip = find.byKey(const Key('library-needs-attention'));
      expect(find.text('Needs attention (1)'), findsOneWidget);
      await tester.tap(chip);
      await tester.pumpAndSettle();
      expect(_shown(tester), ['cust_b1']);
    });

    testWidgets('neither filter is drawn outside Exercises and Positions',
        (tester) async {
      await _open(tester);
      expect(find.byKey(const Key('library-source')), findsNothing);
      expect(find.byKey(const Key('library-needs-attention')), findsNothing);
    });
  });

  group('the search reads the book, the number and the task', () {
    for (final (query, expected) in [
      ('Tactics', ['cust_b1', 'cust_b2']),
      ('xq7', ['cust_a1']),
      ('saves the rook', ['cust_b1']),
      ('fork', ['cust_b2']),
    ]) {
      testWidgets('„$query" finds $expected', (tester) async {
        await _open(tester);
        await _search(tester, query);
        expect(_shown(tester), expected);
      });
    }
  });

  group('Assign is drawn for an account with students', () {
    Finder assignOn(String id) => find.descendant(
        of: find.byKey(ValueKey('library-row-scan-$id')),
        matching: find.byTooltip('Assign to student'));

    testWidgets('none accepted: no Assign', (tester) async {
      await _open(tester, students: [
        {'id': 6, 'name': 'Boris', 'status': 'pending'},
      ]);
      expect(find.byKey(const ValueKey('library-row-scan-cust_a1')),
          findsOneWidget);
      expect(assignOn('cust_a1'), findsNothing);
      // The exercise still has its other doors.
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('library-row-scan-cust_a1')),
              matching: find.byTooltip('Solve')),
          findsOneWidget);
    });

    testWidgets('one accepted: Assign', (tester) async {
      await _open(tester, students: [
        {'id': 5, 'name': 'Ana', 'status': 'accepted'},
      ]);
      expect(assignOn('cust_a1'), findsOneWidget);
    });

    testWidgets('the server could not be asked: Assign stays', (tester) async {
      await _open(tester, students: null);
      expect(assignOn('cust_a1'), findsOneWidget);
    });
  });

  group('Saved Positions is gone', () {
    Iterable<String> paths(List<RouteBase> routes) sync* {
      for (final r in routes) {
        if (r is GoRoute) yield r.path;
        yield* paths(r.routes);
      }
    }

    test('the router has no /scan/saved', () {
      expect(paths(appRouteTable), isNot(contains('/scan/saved')));
      expect(paths(appRouteTable), contains(AppRoutes.library));
    });

    test('View after a save goes to the book, under the chip holding most', () {
      expect(savedViewPath(source: 'Mat u 333', withAnswer: 3, total: 4),
          '/library?chip=exercises&source=Mat%20u%20333');
      expect(savedViewPath(source: 'Silman.pdf', withAnswer: 1, total: 4),
          '/library?chip=positions&source=Silman.pdf');
    });

    testWidgets('the Library route opens on that chip and that book',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'remember_me': true,
        'user_token': 'test-token',
        'user_id': 1,
        'user_email': 'test@example.com',
        'user_name': 'Test',
        'user_role': 'korisnik',
      });
      await SessionService.instance.init();
      final router = GoRouter(
        initialLocation:
            AppRoutes.libraryPath(chip: 'positions', source: 'Mat u 333'),
        routes: appRouteTable,
        errorBuilder: appRouteErrorBuilder,
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump(const Duration(milliseconds: 100));
      final screen = tester.widget<LibraryScreen>(find.byType(LibraryScreen));
      expect(screen.initialChip, LibraryChip.positions);
      expect(screen.initialSource, 'Mat u 333');
    });
  });

  for (final size in [const Size(360, 640), const Size(1200, 800)]) {
    testWidgets('the filters fit at $size', (tester) async {
      await _open(tester, size: size);
      await _chip(tester, 'Exercises');
      expect(find.byKey(const Key('library-source')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
