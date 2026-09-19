// What a trainer sees of a game a student played out — `docs/PLAN-EXERCISE.md`,
// phase 9. THE GATE: written by the lead before the work, and not to be edited
// by whoever builds against it. If a test here is wrong, stop and say so.
//
// The owner's live pass of 19.9.2026: two students, one who met every goal and
// one who met none, read the same to their trainer — a tick and „Done" on every
// row — and the review of a game was the puzzle review: „correct 0", „board
// not available", „viewed". Everything the trainer needed was already stored;
// the server now sends it (`chess_backend/services/assignmentReview.js`,
// kind `game`). The trainer's view is also the judge of last resort: where no
// tablebase answers, the moves and the position reached are on the screen and
// the trainer decides.
//
// THE WIRE — one item of `GET /assignments/:id/review`, for a game:
//   { itemId, position, kind: 'game', attempted, attemptedAt, solved,   // true | false | null
//     fen,                       // the position the student was given
//     task: { type: 'game', side: 'w'|'b', goal: 'win'|'hold'|'survive', surviveMoves: int|null },
//     moves: ['Ra8', 'Kd3', …],  // SAN, both sides, [] before it is played
//     finalFen,                  // where the moves lead, or null
//     ending,                    // a GameEnding name, or null
//     judgedBy,                  // 'rules' | 'tablebase' | 'device' | null
//     pending }                  // played, and nobody could judge it yet
//
// THE API this file asks for, and nothing more:
//   ReviewItemKind.game; ReviewItem gains `task` (Map<String, dynamic>?),
//     `moves` (List<String>, never null), `finalFen`, `ending`, `judgedBy`
//     (String?) and `pending` (bool), all read in `ReviewItem.fromJson`.
//   String gameMovesText(String fen, List<String> moves) — top level, in
//     `lib/features/assignments/models/assignment_review.dart`.
//   Keys: `review-game-<itemId>` (the card), `review-game-start-<itemId>` and
//     `review-game-final-<itemId>` (each ON a `BoardThumbnail`),
//     `review-summary-text` (the summary's first `Text`),
//     `homework-child-verdict-<childId>` (a `Text` in the homework row).

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/assignments/models/assignment_review.dart';
import 'package:chess_app/features/assignments/screens/assignment_review_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/homework/screens/homework_assignment_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import 'support/landscape.dart';

const _studentId = 1;
const _trainerId = 9;

const _krk = '8/8/8/8/8/4k3/8/R3K3 w - - 0 1';
const _krkReached = '8/8/8/8/8/R2k4/8/4K3 b - - 3 2';
const _kpk = '8/8/8/4k3/8/4K3/4P3/8 b - - 0 1';
const _kpkReached = '8/8/8/4k3/8/3K4/4P3/8 w - - 3 3';
const _ruy = 'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';
const _ruyReached =
    'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3';

UserSession _session(int id) => UserSession(
      token: 'tok',
      id: id,
      email: 'a@example.com',
      name: id == _trainerId ? 'Trainer' : 'Student',
      role: id == _trainerId ? 'trener' : 'ucenik',
    );

Widget _wrap(Widget home) => ProviderScope(
      child: MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: home,
      ),
    );

// ---------------------------------------------------------------- the review

Map<String, dynamic> _gameItem({
  int itemId = 7,
  String fen = _krk,
  String side = 'w',
  String goal = 'win',
  int? surviveMoves = 2,
  List<String> moves = const ['Ra8', 'Kd3', 'Ra3+'],
  String? finalFen = _krkReached,
  String? ending = 'moveTarget',
  String? judgedBy = 'rules',
  bool? solved = false,
  bool pending = false,
  bool attempted = true,
}) =>
    {
      'itemId': itemId,
      'position': 0,
      'puzzleId': null,
      'kind': 'game',
      'attempted': attempted,
      'attemptedAt': attempted ? '2026-09-19T14:00:00.000Z' : null,
      'solved': solved,
      'msTaken': null,
      'playedSan': null,
      'title': null,
      'instruction': null,
      'fen': fen,
      'task': {
        'type': 'game',
        'side': side,
        'goal': goal,
        'surviveMoves': surviveMoves,
      },
      'moves': moves,
      'finalFen': finalFen,
      'ending': ending,
      'judgedBy': judgedBy,
      'pending': pending,
    };

Map<String, dynamic> _review(Map<String, dynamic> item,
        {bool isTrainer = true}) =>
    {
      'assignment': {
        'id': 603,
        'title': 'Play it out: checkmate in 2 moves',
        'kind': 'engine_game',
        'instructions': null,
        'dueAt': null,
        'completedAt': '2026-09-19T14:00:00.000Z',
        'createdAt': '2026-09-19T13:00:00.000Z',
        'trainerName': 'Trainer',
        'studentName': 'Ana',
      },
      'viewer': {'isTrainer': isTrainer, 'isStudent': !isTrainer},
      'items': [item],
      'notes': <dynamic>[],
    };

Future<void> _pumpReview(
  WidgetTester tester,
  Map<String, dynamic> review, {
  Size size = const Size(900, 1400),
  int viewer = _trainerId,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final client = MockClient((request) async {
    if (request.url.path == '/assignments/603/review') {
      return http.Response(jsonEncode(review), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }
    return http.Response('{"error":"not found"}', 404);
  });
  await tester.pumpWidget(_wrap(AssignmentReviewScreen(
    session: _session(viewer),
    assignmentId: 603,
    title: 'Play it out: checkmate in 2 moves',
    api: AssignmentApiService(authToken: 'tok', client: client),
  )));
  await tester.pumpAndSettle();
}

Finder _inCard(int itemId, Finder what) =>
    find.descendant(of: find.byKey(Key('review-game-$itemId')), matching: what);

// ---------------------------------------------------------- the homework row

Map<String, dynamic> _child({
  required int id,
  required String title,
  required String kind,
  required int position,
  int total = 1,
  int attempted = 1,
  int solved = 1,
  int pending = 0,
  Map<String, dynamic>? task,
}) =>
    {
      'id': id,
      'title': title,
      'kind': kind,
      'position': position,
      'item_key': 'i$id',
      'lesson_id': null,
      'gate': false,
      'gate_opened_at': null,
      'completed_at': attempted > 0 ? '2026-09-19T14:00:00.000Z' : null,
      'task': task,
      'total_items': total,
      'attempted_items': attempted,
      'solved_items': solved,
      'pending_items': pending,
      'passed': attempted > 0,
      'locked': false,
      'blocked_by': null,
    };

const _gameTask = {
  'fen': _krk,
  'side': 'w',
  'goal': 'win',
  'surviveMoves': 2,
  'level': 'lako',
};

Map<String, dynamic> _parent() => {
      'id': 7,
      'title': 'Thursday',
      'instructions': null,
      'kind': 'homework',
      'trainer_id': _trainerId,
      'student_id': _studentId,
      'trainer_name': 'Trainer',
      'student_name': 'Ana',
      'due_at': null,
      'completed_at': null,
      'total_items': 0,
      'attempted_items': 0,
      'solved_items': 0,
      'child_total': 6,
      'child_completed': 5,
      'children': [
        _child(id: 601, title: 'Read it', kind: 'lesson', position: 0),
        _child(
            id: 602,
            title: '3 positions',
            kind: 'puzzles',
            position: 1,
            total: 3,
            attempted: 3,
            solved: 2),
        _child(
            id: 603,
            title: 'Play it out: checkmate in 2 moves',
            kind: 'engine_game',
            position: 2,
            solved: 0,
            task: _gameTask),
        _child(
            id: 604,
            title: 'Play it out: win it',
            kind: 'engine_game',
            position: 3,
            solved: 1,
            task: _gameTask),
        _child(
            id: 605,
            title: 'Play it out: do not lose for 2 moves',
            kind: 'engine_game',
            position: 4,
            solved: 0,
            pending: 1,
            task: _gameTask),
        _child(
            id: 606,
            title: 'Play it out: hold the draw',
            kind: 'engine_game',
            position: 5,
            attempted: 0,
            solved: 0,
            task: _gameTask),
      ],
    };

Future<List<String>> _pumpHomework(WidgetTester tester, int viewer) async {
  tester.view.physicalSize = const Size(500, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final asked = <String>[];
  final client = MockClient((request) async {
    asked.add('${request.method} ${request.url.path}');
    if (request.url.path == '/assignments/7') {
      return http.Response(jsonEncode(_parent()), 200);
    }
    if (request.url.path == '/assignments/603/review') {
      return http.Response(jsonEncode(_review(_gameItem())), 200);
    }
    if (request.url.path == '/assignments/602') {
      return http.Response(
          jsonEncode({
            'id': 602,
            'title': '3 positions',
            'kind': 'puzzles',
            'total_items': 3,
            'attempted_items': 3,
            'solved_items': 2,
            'items': [
              {'puzzle_id': 'p1', 'position': 0}
            ],
          }),
          200);
    }
    return http.Response('{"error":"not found"}', 404);
  });
  await tester.pumpWidget(_wrap(HomeworkAssignmentScreen(
    session: _session(viewer),
    assignmentId: 7,
    api: AssignmentApiService(authToken: 'tok', client: client),
  )));
  await tester.pumpAndSettle();
  return asked;
}

Finder _inRow(int childId, Finder what) => find.descendant(
    of: find.byKey(Key('homework-child-$childId')), matching: what);

String? _verdictOf(WidgetTester tester, int childId) {
  final f = find.byKey(Key('homework-child-verdict-$childId'));
  if (f.evaluate().isEmpty) return null;
  return tester.widget<Text>(f).data;
}

void main() {
  setUpAll(loadRoboto);

  group('the wire', () {
    test('a game item is read as a game, with everything the server sends', () {
      final item = ReviewItem.fromJson(_gameItem());
      expect(item.kind, ReviewItemKind.game);
      expect(item.fen, _krk);
      expect(item.task, {
        'type': 'game',
        'side': 'w',
        'goal': 'win',
        'surviveMoves': 2,
      });
      expect(item.moves, ['Ra8', 'Kd3', 'Ra3+']);
      expect(item.finalFen, _krkReached);
      expect(item.ending, 'moveTarget');
      expect(item.judgedBy, 'rules');
      expect(item.solved, isFalse);
      expect(item.pending, isFalse);
    });

    test('what the server does not say is absent, never invented', () {
      final item = ReviewItem.fromJson({
        'itemId': 1,
        'position': 0,
        'kind': 'custom',
        'attempted': false,
      });
      expect(item.moves, isEmpty);
      expect(item.task, isNull);
      expect(item.finalFen, isNull);
      expect(item.pending, isFalse);
    });

    test('the moves are numbered from the position they start in', () {
      expect(gameMovesText(_krk, ['Ra8', 'Kd3', 'Ra3+']), '1. Ra8 Kd3 2. Ra3+');
      // Black to move first: the first number carries the dots.
      expect(gameMovesText(_kpk, ['Kd5', 'Kd3', 'Ke5']), '1... Kd5 2. Kd3 Ke5');
      // The FEN's own move number, not always 1.
      expect(gameMovesText(_ruy, ['Bb5', 'a6']), '3. Bb5 a6');
      expect(gameMovesText(_krk, const []), '');
    });
  });

  group('the review of a game, to its trainer', () {
    testWidgets(
        'checkmate in two, not given: the task, the verdict, the moves, both '
        'boards and how it ended', (tester) async {
      await _pumpReview(tester, _review(_gameItem()));

      expect(find.byKey(const Key('review-game-7')), findsOneWidget);
      expect(_inCard(7, find.text('Checkmate in 2 moves as White')),
          findsOneWidget);
      expect(_inCard(7, find.text('Goal not met')), findsOneWidget);
      expect(_inCard(7, find.text('1. Ra8 Kd3 2. Ra3+')), findsOneWidget);
      expect(_inCard(7, find.text('Ended: no checkmate in 2 moves')),
          findsOneWidget);
      expect(_inCard(7, find.text('Judged by the rules')), findsOneWidget);

      final start = tester
          .widget<BoardThumbnail>(find.byKey(const Key('review-game-start-7')));
      final reached = tester
          .widget<BoardThumbnail>(find.byKey(const Key('review-game-final-7')));
      expect(start.fen, _krk);
      expect(reached.fen, _krkReached);
      // Turned to the side the student played — White here, Black below.
      expect(start.isWhiteBottom, isTrue);
      expect(reached.isWhiteBottom, isTrue);
      expect(_inCard(7, find.text('Start')), findsOneWidget);
      expect(_inCard(7, find.text('Position reached')), findsOneWidget);

      // Nothing of the puzzle review is left on this screen.
      expect(find.text('board not available'), findsNothing);
      expect(find.text('viewed'), findsNothing);
      expect(find.text('not opened'), findsNothing);
      expect(find.textContaining('correct'), findsNothing);
      expect(
          tester
              .widget<Text>(find.byKey(const Key('review-summary-text')))
              .data,
          'Played');
    });

    testWidgets('a mate given reads „Goal met", and names the mate',
        (tester) async {
      await _pumpReview(
          tester,
          _review(_gameItem(
            fen: '6k1/5ppp/8/8/8/8/8/3R2K1 w - - 0 1',
            surviveMoves: 1,
            moves: const ['Rd8#'],
            finalFen: '3R2k1/5ppp/8/8/8/8/8/6K1 b - - 1 1',
            ending: 'checkmate',
            solved: true,
          )));
      expect(_inCard(7, find.text('Goal met')), findsOneWidget);
      expect(_inCard(7, find.text('Goal not met')), findsNothing);
      expect(_inCard(7, find.text('Checkmate in 1 move as White')),
          findsOneWidget);
      expect(_inCard(7, find.text('Ended: checkmate')), findsOneWidget);
      expect(_inCard(7, find.text('1. Rd8#')), findsOneWidget);
    });

    testWidgets(
        'played and not judged: „Not judged yet", never a failure, and the '
        'trainer is pointed at the position', (tester) async {
      await _pumpReview(
          tester,
          _review(_gameItem(
            fen: _kpk,
            side: 'b',
            goal: 'hold',
            moves: const ['Kd5', 'Kd3', 'Ke5'],
            finalFen: _kpkReached,
            judgedBy: null,
            solved: null,
            pending: true,
          )));
      expect(_inCard(7, find.text('Not judged yet')), findsOneWidget);
      expect(_inCard(7, find.text('Goal not met')), findsNothing);
      expect(_inCard(7, find.text('Goal met')), findsNothing);
      expect(_inCard(7, find.textContaining('Judged by')), findsNothing);
      expect(
          _inCard(
              7,
              find.text('No tablebase answer yet — the position reached is '
                  'yours to judge.')),
          findsOneWidget);
      expect(_inCard(7, find.text('Draw or better as Black, for 2 moves')),
          findsOneWidget);
      expect(_inCard(7, find.text('1... Kd5 2. Kd3 Ke5')), findsOneWidget);
      for (final key in ['review-game-start-7', 'review-game-final-7']) {
        expect(
            tester.widget<BoardThumbnail>(find.byKey(Key(key))).isWhiteBottom,
            isFalse,
            reason: 'the student played Black, so $key is turned that way');
      }
      expect(_inCard(7, find.text('Ended: you were not beaten in 2 moves')),
          findsOneWidget);
    });

    testWidgets(
        'more than seven pieces, held for N moves: met by the rules, and the '
        'screen says how little that checks', (tester) async {
      await _pumpReview(
          tester,
          _review(_gameItem(
            fen: _ruy,
            goal: 'hold',
            surviveMoves: 1,
            moves: const ['Bb5'],
            finalFen: _ruyReached,
            solved: true,
          )));
      expect(_inCard(7, find.text('Goal met')), findsOneWidget);
      expect(_inCard(7, find.text('Judged by the rules')), findsOneWidget);
      expect(
          _inCard(
              7,
              find.text('Only "not checkmated" could be checked — the '
                  'position reached is yours to judge.')),
          findsOneWidget);
      expect(_inCard(7, find.text('3. Bb5')), findsOneWidget);
    });

    testWidgets('…and that sentence is not said of a tablebase verdict',
        (tester) async {
      await _pumpReview(
          tester,
          _review(_gameItem(
            fen: _kpk,
            side: 'b',
            goal: 'hold',
            moves: const ['Kd5', 'Kd3', 'Ke5'],
            finalFen: _kpkReached,
            judgedBy: 'tablebase',
            solved: true,
          )));
      expect(_inCard(7, find.text('Judged by the tablebase')), findsOneWidget);
      expect(find.textContaining('could be checked'), findsNothing);
      expect(find.textContaining('yours to judge'), findsNothing);
    });

    testWidgets('not played yet: the board given, and no moves',
        (tester) async {
      await _pumpReview(
          tester,
          _review(_gameItem(
            moves: const [],
            finalFen: null,
            ending: null,
            judgedBy: null,
            solved: null,
            attempted: false,
          )));
      expect(
          tester
              .widget<Text>(find.byKey(const Key('review-summary-text')))
              .data,
          'Not played yet');
      expect(find.byKey(const Key('review-game-start-7')), findsOneWidget);
      expect(find.byKey(const Key('review-game-final-7')), findsNothing);
      expect(_inCard(7, find.text('Goal not met')), findsNothing);
      expect(_inCard(7, find.textContaining('Ended:')), findsNothing);
    });

    testWidgets('moves that did not replay: the moves, and no invented board',
        (tester) async {
      await _pumpReview(tester,
          _review(_gameItem(moves: const ['Ra8', 'Qd3'], finalFen: null)));
      expect(_inCard(7, find.text('1. Ra8 Qd3')), findsOneWidget);
      expect(find.byKey(const Key('review-game-final-7')), findsNothing);
    });

    for (final size in [const Size(360, 640), const Size(640, 360)]) {
      testWidgets(
          'fits a phone at ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        await _pumpReview(
            tester,
            _review(_gameItem(
              moves: const [
                'Ra8', 'Kd3', 'Ra3+', 'Kc4', 'Kd2', 'Kb4', 'Rh3', 'Kc4', //
                'Rh4+', 'Kd5', 'Kd3', 'Ke5', 'Rg4', 'Kf5', 'Ra4', 'Ke5',
              ],
              surviveMoves: 8,
            )),
            size: size);
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('review-game-7')), findsOneWidget);
      });
    }

    testWidgets('the student reads the same review of their own game',
        (tester) async {
      await _pumpReview(tester, _review(_gameItem(), isTrainer: false),
          viewer: _studentId);
      expect(_inCard(7, find.text('Goal not met')), findsOneWidget);
      expect(_inCard(7, find.text('1. Ra8 Kd3 2. Ra3+')), findsOneWidget);
    });
  });

  group('the homework, to its trainer', () {
    testWidgets(
        'each row says how it went, in words: met, not met, N of M correct — '
        'and nothing for a lesson or an item not started', (tester) async {
      await _pumpHomework(tester, _trainerId);

      expect(_verdictOf(tester, 603), 'Goal not met');
      expect(_verdictOf(tester, 604), 'Goal met');
      expect(_verdictOf(tester, 602), '2 of 3 correct');
      expect(_verdictOf(tester, 601), isNull, reason: 'a lesson is read');
      expect(_verdictOf(tester, 606), isNull, reason: 'not played yet');

      // Played and not judged keeps its own words, and is never a failure.
      expect(_verdictOf(tester, 605), isNull);
      expect(_inRow(605, find.text('Played — not judged yet')), findsOneWidget);
      expect(_inRow(605, find.text('Goal not met')), findsNothing);

      // Never by hue alone: met and not met are different shapes.
      expect(_inRow(604, find.byIcon(Icons.emoji_events)), findsOneWidget);
      expect(_inRow(603, find.byIcon(Icons.flag)), findsOneWidget);
      expect(_inRow(603, find.byIcon(Icons.emoji_events)), findsNothing);
    });

    testWidgets('the student reads the same verdicts on their own homework',
        (tester) async {
      await _pumpHomework(tester, _studentId);
      expect(_verdictOf(tester, 603), 'Goal not met');
      expect(_verdictOf(tester, 602), '2 of 3 correct');
    });

    testWidgets(
        'tapping a played game opens what the student did, not a board to '
        'play on', (tester) async {
      final asked = await _pumpHomework(tester, _trainerId);
      await tester.tap(find.text('Play it out: checkmate in 2 moves'));
      await tester.pumpAndSettle();

      expect(find.byType(AssignmentReviewScreen), findsOneWidget);
      expect(asked, contains('GET /assignments/603/review'));
      expect(find.byKey(const Key('review-game-7')), findsOneWidget);
    });

    testWidgets('…and the student\'s tap still opens the item itself',
        (tester) async {
      final asked = await _pumpHomework(tester, _studentId);
      await tester.tap(find.text('3 positions'));
      await tester.pumpAndSettle();

      expect(find.byType(AssignmentReviewScreen), findsNothing);
      expect(asked, contains('GET /assignments/602'));
      expect(asked, isNot(contains('GET /assignments/602/review')));
    });
  });
}
