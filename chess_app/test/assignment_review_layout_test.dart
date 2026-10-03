// The gate of phase 12 of docs/PLAN-EKRANI.md: the homework review as the
// owner chose from `docs/skice/ekrani/compare_review.png` — on a window the
// items as a list on the left and the chosen one large on the right (pattern
// B, rule R7): its board, its task, what was played, the solution and its
// comments; the first chosen on opening. Today every item is a 120 px
// thumbnail in a card the width of the window and five items are five
// screens. On a phone the list, and a tap shows the item.
//
// The app's own theme with real Roboto, as phase 1 taught.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/assignments/screens/assignment_review_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_theme.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import 'support/landscape.dart';
import 'support/render_look.dart';

const _window = Size(1536, 792);
const _phone = Size(360, 640);

const _backRank = '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1';
const _italian =
    'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/2N2N2/PPPP1PPP/R1BQK2R b KQkq - 5 4';
const _pin = '4r1k1/5ppp/8/8/8/4B3/5PPP/4R1K1 w - - 0 1';

UserSession _trainer() => UserSession(
    token: 'tok', id: 9, email: 't@example.com', name: 'T', role: 'trener');

Map<String, dynamic> _item(int id, int position, String title, String fen,
        {required bool solved,
        String played = 'Ra8#',
        String solution = 'Ra8#'}) =>
    {
      'itemId': id,
      'position': position,
      'kind': 'custom',
      'puzzleId': 'cust_$id',
      'title': title,
      'fen': fen,
      'instruction': 'Find the move.',
      'themes': <String>[],
      'attempted': true,
      'attemptedAt': '2026-10-01T10:00:00.000Z',
      'solved': solved,
      'msTaken': 21000,
      'playedSan': played,
      'solutionSan': solution,
    };

Map<String, dynamic> _review() => {
      'assignment': {
        'id': 7,
        'title': 'Thursday',
        'kind': 'homework',
        'instructions': 'Solve the positions, then play the ending out.',
        'trainerName': 'Marko Ilić',
        'studentName': 'Ana Petrović',
      },
      'viewer': {'isTrainer': true, 'isStudent': false},
      'items': [
        _item(11, 0, 'Back-rank mate', _backRank, solved: true),
        _item(12, 1, 'Italian Game fork', _italian,
            solved: false, played: 'Nxe4', solution: 'Nd4'),
        _item(13, 2, 'Pin on the e-file', _pin,
            solved: true, played: 'Bc5', solution: 'Bc5'),
      ],
      'notes': [
        {
          'id': 1,
          'itemId': 12,
          'body': 'I did not see the knight could go to d4.',
          'mine': false,
          'authorName': 'Ana Petrović',
          'createdAt': '2026-10-01T10:05:00.000Z',
        },
      ],
    };

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final client = MockClient((request) async {
    if (request.url.path == '/assignments/7/review') {
      return http.Response(jsonEncode(_review()), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    return http.Response('{"error":"not found"}', 404);
  });
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      theme: robotoTheme(AppTheme.dark),
      home: AssignmentReviewScreen(
        key: UniqueKey(),
        session: _trainer(),
        assignmentId: 7,
        title: 'Thursday',
        api: AssignmentApiService(authToken: 'tok', client: client),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// The board drawn largest: the chosen item's, in the pane.
BoardThumbnail _largest(WidgetTester tester) {
  final boards = tester.widgetList<BoardThumbnail>(find.byType(BoardThumbnail));
  expect(boards, isNotEmpty);
  return boards.reduce((a, b) => a.size >= b.size ? a : b);
}

void main() {
  setUpAll(loadRoboto);

  testWidgets(
      'on a window: the items listed on the left, the first one large on the '
      'right', (tester) async {
    await _pump(tester, _window);
    expect(tester.takeException(), isNull);
    final pane = _largest(tester);
    expect(pane.fen, _backRank, reason: 'the first item is chosen on opening');
    expect(pane.size, greaterThanOrEqualTo(320),
        reason: 'the chosen position large, not a 120 px thumbnail');
    final board = tester.getRect(find.byWidget(pane));
    final firstTitle = tester.getRect(find.text('Back-rank mate').first);
    expect(board.left, greaterThan(firstTitle.right),
        reason: 'the item stands beside the list (pattern B)');
    // Every item's title is in the list, on screen, without scrolling.
    for (final title in [
      'Back-rank mate',
      'Italian Game fork',
      'Pin on the e-file'
    ]) {
      expectOnScreen(tester, _window, find.text(title).first);
    }
  });

  testWidgets(
      'choosing another item draws it large, with what was played, the '
      'solution and its comment', (tester) async {
    await _pump(tester, _window);
    await tester.tap(find.text('Italian Game fork').first);
    await tester.pumpAndSettle();
    expect(_largest(tester).fen, _italian);
    expect(find.textContaining('Nxe4'), findsWidgets);
    expect(find.textContaining('Nd4'), findsWidgets);
    expectOnScreen(
        tester, _window, find.text('I did not see the knight could go to d4.'));
  });

  testWidgets('on a 360 dp phone: nothing overflows, a tap shows the item',
      (tester) async {
    await _pump(tester, _phone);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Italian Game fork').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(_largest(tester).fen, _italian);
  });
}
