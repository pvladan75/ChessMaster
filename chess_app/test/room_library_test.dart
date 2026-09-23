// The room's left column reads the shared library — phase 3b of
// docs/PLAN-REORGANIZACIJA.md (S3).
//
// Until 17.9.2026 the column kept its own list: a search field of its own,
// a label matrix of its own, three category chips of its own and a row
// widget of its own, over `GET /lessons`. The Library screen (3a) drew the
// same things from `LibraryList` over `GET /library/positions`. Rule 12 —
// one rule, one home. Written red on master at de1966e.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/screens/chess_game_screen.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/course_step_bar.dart';

import 'support/dart_source.dart';

const _fen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Every request the room made, for the cases that read them.
final List<http.Request> _sent = [];

/// One client answering for the shelf, the labels and one row.
http.Client _server() => MockClient((req) async {
      _sent.add(req);
      final path = req.url.path;
      if (req.method == 'PATCH' && path == '/scans/puzzles/u1') {
        final side = (jsonDecode(req.body) as Map)['sideToMove'];
        return http.Response(
            jsonEncode({'fen': '4k3/8/8/8/8/8/8/R3K3 $side - - 0 1'}), 200);
      }
      if (path.endsWith('/library/positions')) {
        return http.Response(
          jsonEncode({
            'items': [
              {
                'kind': 'tutorial',
                'id': '14',
                'title': 'Vezani top',
                'fen': _fen,
                'partsCount': 1,
                'fromTrainer': false,
              },
              {
                'kind': 'position',
                'id': '12',
                'title': 'Lucena',
                'fen': _fen,
                'themes': ['endgame'],
                'fromTrainer': false,
              },
              {
                'kind': 'tutorial',
                'id': '15',
                'title': 'Trenerov tutorijal',
                'fen': _fen,
                'partsCount': 1,
                'fromTrainer': true,
              },
              // A diagram whose side nobody set (side_to_move_gate.dart).
              {
                'kind': 'scan',
                'id': 'u1',
                'title': 'Strana nije postavljena',
                'fen': '4k3/8/8/8/8/8/8/R3K3 w - - 0 1',
                'needsReview': true,
                'fromTrainer': false,
              },
              // On the shelf, not on this column: nothing here can go on a
              // board by a tap.
              {
                'kind': 'recording',
                'id': '3',
                'title': 'Snimak od utorka',
                'fen': '',
              },
            ],
          }),
          200,
        );
      }
      if (path.endsWith('/lessons/labels')) {
        return http.Response(jsonEncode(['endgame']), 200);
      }
      if (path.endsWith('/lessons/14')) {
        return http.Response(
          jsonEncode({
            'id': 14,
            'title': 'Vezani top',
            'position_list': [
              {'id': 'step0001', 'fen': _fen, 'title': 'Prvi deo'},
            ],
          }),
          200,
        );
      }
      return http.Response('{}', 404);
    });

Future<void> _openRoom(WidgetTester tester) async {
  final client = _server();
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    // The room's feedback reads the colour tokens; without them the helper
    // swallows the lookup and no message is shown to assert on.
    theme: ThemeData.light().copyWith(extensions: const [AppColorTokens.light]),
    home: ChessGamePage(
      userSession: UserSession(
          id: 1, token: 'tok', email: 'e', name: 'N', role: 'trener'),
      roomCode: 'STUDIO',
      initialRole: 'trener',
      lessonApi: LessonApiService(authToken: 'tok', client: client),
      positionLibrary: PositionLibraryService(authToken: 'tok', client: client),
      scannerApi: ScannerApiService(authToken: 'tok', client: client),
    ),
  ));
  await tester.pumpAndSettle();
}

const _screen = 'lib/screens/chess_game_screen.dart';

void main() {
  final source = File(_screen).readAsStringSync();
  final code = codeOf(source);
  final literals = literalsIn(source);

  test('the column draws the shared list, not a list of its own', () {
    expect(code, contains('LibraryList('),
        reason: 'the room must draw LibraryList');
    expect(code, isNot(contains('MatrixFilterPanel(')),
        reason: 'the label filter has its home in LibraryList now');
    for (final gone in [
      'Search tutorials',
      'Search by title or tag...',
      'Category: ',
      'No saved tutorials in this category.',
      'Saved tutorial from trainer',
    ]) {
      expect(literals, isNot(contains(gone)), reason: '„$gone" survives');
    }
  });

  test('the column reads the shelf through the one service', () {
    expect(code, contains('PositionLibraryService'),
        reason: 'the room reads GET /library/positions like the Library does');
  });

  testWidgets('the column is the shared list, narrowed to the board',
      (tester) async {
    await _openRoom(tester);

    final column = find.byType(LibraryList);
    expect(column, findsOneWidget);
    // Exercises added `docs/PLAN-EXERCISE.md` phase 4, 18.9.2026: without it
    // a scan is unreachable from the room's board (CLAUDE.md rule 10), now
    // that „Positions" no longer holds one.
    for (final chip in ['All', 'Tutorials', 'Exercises', 'Positions']) {
      expect(find.descendant(of: column, matching: find.text(chip)),
          findsOneWidget,
          reason: chip);
    }
    for (final chip in ['Analyses', 'Recordings', 'Puzzle sets']) {
      expect(find.text(chip), findsNothing, reason: chip);
    }
    expect(find.text(LibraryList.mine), findsOneWidget);
    expect(find.text(LibraryList.fromTrainer), findsOneWidget);
    expect(find.text('Label Filter Matrix'), findsOneWidget,
        reason: 'the labels the trainer has used are offered as a filter');

    expect(find.text('Vezani top'), findsOneWidget);
    expect(find.text('Lucena'), findsOneWidget);
    expect(find.text('Trenerov tutorijal'), findsOneWidget);
    expect(find.text('Snimak od utorka'), findsNothing,
        reason: 'a recording is not on this column\'s All');
  });

  testWidgets('a tap puts a tutorial on the board from its first part',
      (tester) async {
    await _openRoom(tester);

    // The Exercises chip added by phase 4 of `docs/PLAN-EXERCISE.md` makes
    // the header one line taller, so the row this test taps can start below
    // the fold — the column is a `SingleChildScrollView`, scrolled here the
    // same way a trainer's own scroll would reach it.
    await tester.ensureVisible(find.text('Vezani top'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vezani top'));
    await tester.pumpAndSettle();

    // The bar over the board, not the snackbar: „Loaded step 1/1" queues
    // behind the room's own „Position loaded and synchronized!" and a test
    // that waits for it is a test of the messenger's timer.
    expect(find.byType(CourseStepBar), findsOneWidget,
        reason: 'the tutorial is walked from its first part');
  });

  // The owner, 23.9.2026: a side nobody set went on the shared board as
  // White to move, for everybody in the room.
  testWidgets('a position whose side nobody set asks before the board takes it',
      (tester) async {
    _sent.clear();
    await _openRoom(tester);
    await tester.ensureVisible(find.text('Strana nije postavljena'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Strana nije postavljena'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('side-to-move-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('side-to-move-black')));
    await tester.pumpAndSettle();
    final patch = _sent.where((r) => r.method == 'PATCH').toList();
    expect(patch, hasLength(1));
    expect(patch.single.body, contains('"sideToMove":"b"'));
    // And the board holds the side answered, not the White nobody chose.
    final room = tester.state(find.byType(ChessGamePage)) as dynamic;
    expect(
        room.moveTree.current.fen as String, '4k3/8/8/8/8/8/8/R3K3 b - - 0 1');
  });

  testWidgets('the trainer\'s material has no edit or delete on its row',
      (tester) async {
    await _openRoom(tester);

    // Mine: the tutorial's menu and two deletes (tutorial, position).
    expect(find.byTooltip('Options'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilterChip, LibraryList.fromTrainer));
    await tester.pumpAndSettle();
    expect(find.text('Trenerov tutorijal'), findsOneWidget);
    expect(find.text('Vezani top'), findsNothing);
    expect(find.byTooltip('Options'), findsNothing);
    expect(find.byTooltip('Delete'), findsNothing);
  });
}
