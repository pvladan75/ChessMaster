// Answering who is to move on Saved Positions — the owner, 23.9.2026: „zašto
// me vodi u Analysis kad odgovorim ko je na potezu?"
//
// The question was asked only on the way into Analysis, so answering it always
// opened Analysis. The row now has a door of its own that asks, keeps the
// answer and stays on the list; tapping the position still opens Analysis, and
// still asks first — the engine must not analyse a side nobody chose.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/position_scanner/screens/saved_positions_screen.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

const _fen = '4k3/8/8/8/8/8/8/R3K3 w - - 0 1';

class _Server {
  _Server({this.instruction});
  final String? instruction;
  final List<String> sides = [];
  final List<http.Request> sent = [];

  late final client = MockClient((req) async {
    sent.add(req);
    if (req.method == 'GET' && req.url.path == '/lessons') {
      return http.Response(
          jsonEncode([
            {'id': 7, 'title': 'Rook endings', 'position_list': []}
          ]),
          200);
    }
    if (req.method == 'GET' && req.url.path == '/scans/puzzles') {
      return http.Response(
          jsonEncode([
            {
              'puzzle_id': 'cust_1',
              'fen': _fen,
              'side_to_move': 'w',
              'source_title': 'Silman.pdf',
              'source_page': 100,
              'needs_review': true,
              if (instruction != null) 'instruction': instruction,
            }
          ]),
          200);
    }
    if (req.method == 'PATCH' && req.url.path == '/scans/puzzles/cust_1') {
      final side = (jsonDecode(req.body) as Map)['sideToMove'] as String;
      sides.add(side);
      return http.Response(
          jsonEncode({'fen': '4k3/8/8/8/8/8/8/R3K3 $side - - 0 1'}), 200);
    }
    return http.Response('[]', 200);
  });
}

Future<_Server> _open(WidgetTester tester, {String? instruction}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final server = _Server(instruction: instruction);
  final router = GoRouter(
    initialLocation: '/saved',
    routes: [
      GoRoute(
        path: '/saved',
        builder: (_, __) => SavedPositionsScreen(
          session:
              UserSession(id: 1, token: 't', email: 'e', name: 'N', role: 'x'),
          api: ScannerApiService(authToken: 't', client: server.client),
          library:
              PositionLibraryService(authToken: 't', client: server.client),
          lessons: LessonApiService(authToken: 't', client: server.client),
        ),
      ),
      GoRoute(
        path: AppRoutes.analysis,
        builder: (_, state) =>
            Scaffold(body: Text('ROUTE-ANALYSIS ${state.uri.queryParameters}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(MaterialApp.router(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    routerConfig: router,
  ));
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull, reason: 'the card overflowed');
  return server;
}

void main() {
  testWidgets('„set it" asks, keeps the answer and stays on the list',
      (tester) async {
    final server = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('saved-set-side-cust_1')));
    await tester.pumpAndSettle();
    expect(find.text('Who is to move?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Black'));
    await tester.pumpAndSettle();

    expect(server.sides, ['b']);
    expect(find.textContaining('ROUTE-ANALYSIS'), findsNothing,
        reason: 'answering who is to move opened Analysis');
    expect(find.byType(SavedPositionsScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('saved-set-side-cust_1')), findsNothing,
        reason: 'the position still says its side is not confirmed');
  });

  testWidgets('tapping the position still asks first, then opens Analysis',
      (tester) async {
    final server = await _open(tester);
    await tester.tap(find.byKey(const ValueKey('saved-card-cust_1')));
    await tester.pumpAndSettle();
    expect(find.text('Who is to move?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'White'));
    await tester.pumpAndSettle();
    expect(server.sides, ['w']);
    expect(find.textContaining('ROUTE-ANALYSIS'), findsOneWidget);
  });

  // The owner, 23.9.2026 („popravi ovu rupu"): a tutorial shows its steps to
  // students with the side the FEN says, and a side nobody set went in as
  // White to move.
  testWidgets('„Add to tutorial" asks first, and the step has the side chosen',
      (tester) async {
    final server = await _open(tester);
    await tester.longPress(find.byKey(const ValueKey('saved-card-cust_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Add to tutorial'));
    await tester.pumpAndSettle();
    expect(find.text('Who is to move?'), findsOneWidget,
        reason: 'added to a tutorial as White to move without asking');
    await tester.tap(find.widgetWithText(TextButton, 'Black'));
    await tester.pumpAndSettle();
    expect(server.sides, ['b']);
    await tester.tap(find.text('Rook endings'));
    await tester.pumpAndSettle();
    final step = server.sent.lastWhere(
        (r) => r.method == 'POST' && r.url.path == '/lessons/7/steps');
    expect(step.body, contains('4k3/8/8/8/8/8/8/R3K3 b - - 0 1'));
  });

  // Found by the first case: the card clipped its last note by 10 px, so
  // „side to move not confirmed" was cut off — and the tap meant for it landed
  // on the card. Clipping throws nothing, so the rectangles are measured.
  for (final instruction in [null, 'Find the win for White. ' * 6]) {
    testWidgets(
        'the note is on the card, and the board stays square '
        '(${instruction == null ? 'no task' : 'a two-line task'})',
        (tester) async {
      await _open(tester, instruction: instruction);
      final card =
          tester.getRect(find.byKey(const ValueKey('saved-card-cust_1')));
      final note =
          tester.getRect(find.byKey(const ValueKey('saved-set-side-cust_1')));
      expect(card.contains(note.topLeft) && card.contains(note.bottomRight),
          isTrue,
          reason: 'the note is outside its card: $note in $card');
      final board = tester.getRect(find.descendant(
          of: find.byKey(const ValueKey('saved-card-cust_1')),
          matching: find.byType(BoardThumbnail)));
      expect(board.width, board.height, reason: 'the board is not square');
      expect(board.width, greaterThanOrEqualTo(96),
          reason: 'the board shrank to nothing');
    });
  }
}
