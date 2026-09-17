// GATE — phase 5 of `docs/PLAN-DOMACI-ZADATAK.md`: what the student sees, and
// the gate drawn. Red on master while `lib/features/homework/` has no student
// screen. Copy this file into `chess_app/test/` **unchanged** and make it
// green. If you believe a test here is wrong, stop and say so in your report —
// do not work around it.
//
// The server half is already built and is not to be touched. What it sends,
// and what every assertion below is derived from:
//
//   GET /assignments/mine      one row per homework, children excluded
//                              (`parent_id IS NULL`), carrying `child_total`
//                              and `child_completed`.
//   GET /assignments/:id       a parent of `kind: 'homework'` carries
//                              `children`, in `position` order, each row as
//                              `homeworkService.childrenOf` selects it:
//                              snake_case, with `passed`, `locked` and
//                              `blocked_by`.
//   POST /assignments/:id/open-gate   the trainer unlocks one child. 404 for
//                              „not yours", „not an item" and „already open"
//                              alike.
//
// **`blocked_by` is an id, not a position and not a title** — the id of the
// item directly before this one (`homeworkService.blockedBySql`). The student
// must be told *which item* holds theirs shut, by name, so the screen resolves
// that id against the children it already has. Every id in the fixture below
// is far away from its position for exactly this reason: a lookup by index
// would find the wrong row, or none.
//
// The API this gate expects:
//
//   AssignmentApiService({required String authToken, http.Client? client})
//       — every request goes through that client, so a test can answer it.
//         Today the service calls the top-level `http.get`, which no test can
//         fake, and that is why none of this could be tested before.
//   Future<String?> AssignmentApiService.openGate(int assignmentId)
//       — null when it worked, the server's own sentence when it did not.
//
//   enum AssignmentKind { puzzles, lesson, homework, engineGame }
//   Assignment.trainerId, .childTotal, .childCompleted, .isHomework
//       — and `progress`, for a homework, counts children rather than items:
//         a parent has no `assignment_items` at all.
//   AssignmentDetail.children  →  List<HomeworkChild>, empty for anything
//         that is not a homework.
//
//   enum HomeworkChildState { done, open, locked }
//   HomeworkChild — `lib/features/homework/models/homework_child.dart`:
//       id, title, kind (the wire spelling), position, itemKey, lessonId,
//       gate, requireSolved, gateOpenedAt, completedAt, task,
//       totalItems, attemptedItems, solvedItems, passed, locked, blockedBy,
//       state, openedByTrainer; `fromJson` refuses a row it cannot read.
//
//   HomeworkAssignmentScreen({required UserSession session,
//                             required int assignmentId,
//                             AssignmentApiService? api})
//       — `lib/features/homework/screens/homework_assignment_screen.dart`,
//         routed at `AppRoutes.assignmentHomework`
//         (`/assignments/:id/homework`, built by `appRouteTable`) with
//         `AppRoutes.assignmentHomeworkPath(id)`.
//
//         Whether this reader is the trainer is read from the payload
//         (`trainer_id` against the session's id), never from a flag a caller
//         could get wrong.
//
//   Widget assignmentItemScreen({required UserSession session,
//                                required AssignmentDetail detail,
//                                AssignmentApiService? api})
//       — `lib/features/assignments/widgets/assignment_item_destination.dart`:
//         the **one** place that decides which screen an assignment item
//         opens. `appRouteTable`'s three assignment routes and this screen
//         both go through it; a second copy of that decision is the thing
//         this function exists to prevent.
//
// Widget keys:
//
//   Key('homework-progress')              „1 of 3 items"
//   Key('homework-child-<id>')            one item's row
//   Key('homework-child-state-<id>')      its state: Done / Open / Locked
//   Key('homework-child-unlock-<id>')     the trainer's unlock, on a locked row
//   Key('assignment-row-<id>')            one row of the student's own list

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/assignments/screens/my_assignments_screen.dart';
import 'package:chess_app/features/assignments/widgets/assignment_detail_gate.dart';
import 'package:chess_app/features/homework/models/homework_child.dart';
import 'package:chess_app/features/homework/screens/homework_assignment_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_router.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/theme/app_colors.dart';

import 'support/landscape.dart';

const _studentId = 1;
const _trainerId = 9;

UserSession _session(int id) => UserSession(
      token: 'tok',
      id: id,
      email: 'a@example.com',
      name: id == _trainerId ? 'Trainer' : 'Student',
      role: id == _trainerId ? 'trener' : 'ucenik',
    );

/// One tutorial (done), two positions (open), one game (locked behind the
/// positions) — the shape §6 of the plan describes.
///
/// Ids are 501–503 against positions 0–2 on purpose: `blocked_by` is an id,
/// and a screen that read it as an index would name the wrong item.
Map<String, dynamic> _child({
  required int id,
  required String title,
  required String kind,
  required int position,
  required String itemKey,
  int? lessonId,
  bool gate = true,
  bool requireSolved = false,
  String? gateOpenedAt,
  String? completedAt,
  Map<String, dynamic>? task,
  int totalItems = 1,
  int attemptedItems = 0,
  int solvedItems = 0,
  bool passed = false,
  bool locked = false,
  int? blockedBy,
}) =>
    {
      'id': id,
      'title': title,
      'kind': kind,
      'position': position,
      'item_key': itemKey,
      'lesson_id': lessonId,
      'gate': gate,
      'require_solved': requireSolved,
      'gate_opened_at': gateOpenedAt,
      'completed_at': completedAt,
      'task': task,
      'total_items': totalItems,
      'attempted_items': attemptedItems,
      'solved_items': solvedItems,
      'passed': passed,
      'locked': locked,
      'blocked_by': blockedBy,
    };

const _gameTask = {
  'fen': '4k3/8/8/8/8/8/8/4K2R w - - 0 1',
  'side': 'w',
  'goal': 'win',
};

/// The parent as `GET /assignments/7` sends it. [gameOpen] is the state after
/// the trainer has used the escape hatch on the third item.
Map<String, dynamic> _parent({bool gameOpen = false}) => {
      'id': 7,
      'title': 'Thursday',
      'instructions': 'Read first, then solve.',
      'kind': 'homework',
      'trainer_id': _trainerId,
      'student_id': _studentId,
      'trainer_name': 'Trainer',
      'due_at': null,
      'completed_at': null,
      'total_items': 0,
      'attempted_items': 0,
      'solved_items': 0,
      'child_total': 3,
      'child_completed': 1,
      'children': [
        _child(
          id: 501,
          title: 'My Tutorial',
          kind: 'lesson',
          position: 0,
          itemKey: 'ia1b2c3d4',
          lessonId: 31,
          gate: false,
          completedAt: '2026-09-17T10:00:00.000Z',
          task: {'lessonId': 31},
          totalItems: 3,
          attemptedItems: 3,
          passed: true,
        ),
        _child(
          id: 502,
          title: 'Two positions',
          kind: 'puzzles',
          position: 1,
          itemKey: 'ie5f6a7b8',
          totalItems: 2,
        ),
        _child(
          id: 503,
          title: 'Play it out: win it',
          kind: 'engine_game',
          position: 2,
          itemKey: 'i90c1d2e3',
          task: _gameTask,
          gateOpenedAt: gameOpen ? '2026-09-17T11:00:00.000Z' : null,
          locked: !gameOpen,
          blockedBy: gameOpen ? null : 502,
        ),
      ],
    };

/// Answers the three addresses this screen uses and records every request, so
/// a wrong address is visible: a `MockClient` answers whatever it is asked.
class _Recorder {
  _Recorder({this.gameOpen = false});

  /// Flipped by the test after an unlock, so the refresh reads the new state.
  bool gameOpen;
  final List<http.Request> requests = [];

  http.Client client() => MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path == '/assignments/7' && request.method == 'GET') {
          return http.Response(jsonEncode(_parent(gameOpen: gameOpen)), 200);
        }
        if (path == '/assignments/mine' && request.method == 'GET') {
          return http.Response(
              jsonEncode({
                'assignments': [
                  {
                    'id': 7,
                    'title': 'Thursday',
                    'kind': 'homework',
                    'instructions': 'Read first, then solve.',
                    'trainer_id': _trainerId,
                    'student_id': _studentId,
                    'trainer_name': 'Trainer',
                    'total_items': 0,
                    'attempted_items': 0,
                    'solved_items': 0,
                    'child_total': 3,
                    'child_completed': 1,
                  },
                ],
              }),
              200);
        }
        if (path.startsWith('/assignments/progress/')) {
          return http.Response(jsonEncode({'hasData': false}), 200);
        }
        if (path == '/assignments/502' && request.method == 'GET') {
          // The child's own detail, for the screen its row opens.
          return http.Response(
              jsonEncode({
                'id': 502,
                'title': 'Two positions',
                'kind': 'puzzles',
                'total_items': 2,
                'attempted_items': 0,
                'solved_items': 0,
                'items': [
                  {'puzzle_id': 'cust_1', 'position': 0},
                  {'puzzle_id': 'cust_2', 'position': 1},
                ],
                'customPositions': [
                  {
                    'puzzle_id': 'cust_1',
                    'fen': '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
                    'side_to_move': 'w',
                    'instruction': 'White to play and win.',
                    'source_title': 'Mate in 2',
                  },
                  {
                    'puzzle_id': 'cust_2',
                    'fen': '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
                    'side_to_move': 'w',
                    'instruction': 'And again.',
                    'source_title': 'The other one',
                  },
                ],
              }),
              200);
        }
        if (path == '/assignments/503/open-gate' && request.method == 'POST') {
          return http.Response(jsonEncode({'success': true}), 200);
        }
        return http.Response('{"error":"not found"}', 404);
      });

  List<http.Request> to(String path, {String? method}) => requests
      .where(
          (r) => r.url.path == path && (method == null || r.method == method))
      .toList();
}

/// The state one row shows, whether the key sits on the label or on
/// something holding it.
String _stateOf(WidgetTester tester, int id) {
  final row = find.byKey(Key('homework-child-state-$id'));
  final widget = tester.widget(row);
  if (widget is Text) return widget.data!;
  return tester
      .widget<Text>(find.descendant(of: row, matching: find.byType(Text)))
      .data!;
}

Widget _wrap(Widget home) => ProviderScope(
      child: MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: home,
      ),
    );

/// Pumps the student's homework screen for [sessionId] and returns its
/// recorder.
Future<_Recorder> _openHomework(
  WidgetTester tester, {
  int sessionId = _studentId,
  bool gameOpen = false,
}) async {
  final recorder = _Recorder(gameOpen: gameOpen);
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_wrap(HomeworkAssignmentScreen(
    session: _session(sessionId),
    assignmentId: 7,
    api: AssignmentApiService(authToken: 'tok', client: recorder.client()),
  )));
  await tester.pumpAndSettle();
  return recorder;
}

void main() {
  setUpAll(loadRoboto);

  group('the model reads what the server sends', () {
    test('a kind is the wire spelling, and an unknown one is not a homework',
        () {
      AssignmentKind kindOf(String wire) =>
          Assignment.fromJson({'id': 1, 'title': 't', 'kind': wire}).kind;

      expect(kindOf('homework'), AssignmentKind.homework);
      expect(kindOf('engine_game'), AssignmentKind.engineGame);
      expect(kindOf('lesson'), AssignmentKind.lesson);
      expect(kindOf('puzzles'), AssignmentKind.puzzles);
      expect(kindOf('something-new'), AssignmentKind.puzzles,
          reason: 'an unknown kind stays the ordinary one, not a homework '
              'whose children would never load');
    });

    test('a homework counts its children, not its items', () {
      final homework = Assignment.fromJson(_parent());

      expect(homework.isHomework, isTrue);
      expect(homework.childTotal, 3);
      expect(homework.childCompleted, 1);
      // A parent has no assignment_items at all, so items would read 0 of 0.
      expect(homework.totalItems, 0);
      expect(homework.progress, closeTo(1 / 3, 0.001));
      expect(homework.trainerId, _trainerId);
    });

    test('an ordinary assignment still counts its items', () {
      final puzzles = Assignment.fromJson({
        'id': 8,
        'title': 'Five positions',
        'kind': 'puzzles',
        'total_items': 5,
        'attempted_items': 2,
        'solved_items': 1,
      });

      expect(puzzles.isHomework, isFalse);
      expect(puzzles.progress, closeTo(2 / 5, 0.001));
    });

    test('a child is done, open or locked, and done wins', () {
      final children = AssignmentDetail.fromJson(_parent()).children;
      expect(children.map((c) => c.id), [501, 502, 503]);
      expect(children.map((c) => c.state), [
        HomeworkChildState.done,
        HomeworkChildState.open,
        HomeworkChildState.locked,
      ]);
      expect(children.last.blockedBy, 502);
      expect(children.first.kind, 'lesson');
      expect(children.last.task?['fen'], _gameTask['fen']);

      // The server cannot send this — `childLockedSql` requires
      // `completed_at IS NULL` — and that is the point: if it ever did, a
      // finished item must not be drawn as a locked one. The same ordering
      // mistake already survived a mutation once, in the server's own tests.
      final finished = HomeworkChild.fromJson(_child(
        id: 504,
        title: 'Finished',
        kind: 'puzzles',
        position: 3,
        itemKey: 'i5a6b7c8',
        completedAt: '2026-09-17T12:00:00.000Z',
        passed: true,
        locked: true,
        blockedBy: 503,
      ));
      expect(finished!.state, HomeworkChildState.done);
    });

    test('a row it cannot read is refused rather than guessed', () {
      expect(HomeworkChild.fromJson({'title': 'no id'}), isNull);
      expect(
        HomeworkChild.fromJson({'id': 5, 'title': 'no kind'}),
        isNull,
        reason: 'the kind decides which screen the row opens',
      );
    });

    test('nothing that is not a homework carries children', () {
      final detail = AssignmentDetail.fromJson({
        'id': 8,
        'title': 'Five positions',
        'kind': 'puzzles',
        'items': <dynamic>[],
      });
      expect(detail.children, isEmpty);
    });
  });

  group("the student's homework screen", () {
    testWidgets('lists the items in the trainer\'s order, with their state',
        (tester) async {
      await _openHomework(tester);

      expect(find.byKey(const Key('homework-progress')), findsOneWidget);
      expect(find.text('1 of 3 items'), findsOneWidget);

      final first = tester.getRect(find.byKey(const Key('homework-child-501')));
      final second =
          tester.getRect(find.byKey(const Key('homework-child-502')));
      final third = tester.getRect(find.byKey(const Key('homework-child-503')));
      expect(first.top, lessThan(second.top));
      expect(second.top, lessThan(third.top));

      expect(_stateOf(tester, 501), 'Done');
      expect(_stateOf(tester, 502), 'Open');
      expect(_stateOf(tester, 503), 'Locked');

      expect(find.text('Thursday'), findsWidgets);
      expect(find.text('Read first, then solve.'), findsOneWidget);
    });

    testWidgets('names the item that holds a locked one shut', (tester) async {
      await _openHomework(tester);

      expect(
        find.descendant(
          of: find.byKey(const Key('homework-child-503')),
          matching: find.textContaining('Two positions'),
        ),
        findsOneWidget,
        reason: 'blocked_by is 502, whose title is „Two positions" — an id '
            'read as an index would name „My Tutorial" or nothing at all',
      );
    });

    testWidgets('does not open a locked item, and asks the server nothing',
        (tester) async {
      final recorder = await _openHomework(tester);

      await tester.tap(find.byKey(const Key('homework-child-503')));
      await tester.pumpAndSettle();

      expect(find.byType(AiStudioScreen), findsNothing);
      expect(find.byType(AssignmentDetailGate), findsNothing);
      expect(recorder.to('/assignments/503'), isEmpty);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens an open item on the screen for its kind',
        (tester) async {
      await _openHomework(tester);

      await tester.tap(find.byKey(const Key('homework-child-502')));
      await tester.pumpAndSettle();

      final gate = tester.widget<AssignmentDetailGate>(
          find.byType(AssignmentDetailGate));
      expect(gate.assignmentId, 502,
          reason: 'the child is the assignment that is opened, not its parent');
    });

    testWidgets('opens „play it out" on the assigned game, with its task',
        (tester) async {
      // The trainer has opened the third item, so it is the student's to play.
      await _openHomework(tester, gameOpen: true);

      expect(
        find.descendant(
          of: find.byKey(const Key('homework-child-503')),
          matching: find.textContaining('trainer'),
        ),
        findsOneWidget,
        reason: 'an item the trainer opened says so',
      );

      await tester.tap(find.byKey(const Key('homework-child-503')));
      await tester.pumpAndSettle();

      final studio = tester.widget<AiStudioScreen>(find.byType(AiStudioScreen));
      expect(studio.assignmentId, 503);
      expect(studio.engineGameTask, isNotNull);
      expect(studio.engineGameTask!.fen, _gameTask['fen']);
      expect(studio.initialCategory, 'engine_game');
    });

    testWidgets('offers the student no unlock', (tester) async {
      await _openHomework(tester);

      expect(find.byKey(const Key('homework-child-unlock-503')), findsNothing,
          reason: 'the escape hatch is the trainer\'s; the session here is '
              'the student the homework was sent to');
    });
  });

  group('the trainer, on the same screen', () {
    testWidgets('unlocks one item for this student and re-reads it',
        (tester) async {
      final recorder = await _openHomework(tester, sessionId: _trainerId);

      expect(find.byKey(const Key('homework-child-unlock-503')), findsOneWidget);

      // What the server will answer with after the unlock.
      recorder.gameOpen = true;
      await tester.tap(find.byKey(const Key('homework-child-unlock-503')));
      await tester.pumpAndSettle();

      expect(recorder.to('/assignments/503/open-gate', method: 'POST'),
          hasLength(1),
          reason: 'the address carries the item — a MockClient answers any URL');
      expect(recorder.to('/assignments/7', method: 'GET'), hasLength(2),
          reason: 'the screen reads the homework again rather than guessing '
              'what the unlock did');

      expect(_stateOf(tester, 503), 'Open');
    });
  });

  group('the door from the student\'s own list', () {
    testWidgets('a homework is one row, and it opens the homework screen',
        (tester) async {
      final recorder = _Recorder();
      tester.view.physicalSize = const Size(400, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final api =
          AssignmentApiService(authToken: 'tok', client: recorder.client());
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => MyAssignmentsScreen(
              session: _session(_studentId),
              api: api,
            ),
          ),
          GoRoute(
            path: AppRoutes.assignmentHomework,
            builder: (_, state) => HomeworkAssignmentScreen(
              session: _session(_studentId),
              assignmentId:
                  int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
              api: api,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppColorTokens.dark]),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('assignment-row-7')), findsOneWidget);
      expect(find.text('1 of 3 items'), findsOneWidget,
          reason: 'a homework row counts its items, not its (zero) puzzles');

      await tester.tap(find.byKey(const Key('assignment-row-7')));
      await tester.pumpAndSettle();

      expect(find.byType(HomeworkAssignmentScreen), findsOneWidget);
      expect(router.state.uri.toString(),
          AppRoutes.assignmentHomeworkPath(7));
    });

    testWidgets('and the app\'s own route table builds that screen',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'remember_me': true,
        'user_token': 'test-token',
        'user_id': _studentId,
        'user_email': 'a@example.com',
        'user_name': 'Student',
        'user_role': 'ucenik',
      });
      await SessionService.instance.init();

      final router = GoRouter(
        initialLocation: AppRoutes.assignmentHomeworkPath(7),
        routes: appRouteTable,
        errorBuilder: appRouteErrorBuilder,
      );
      addTearDown(router.dispose);

      await tester
          .pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
      // Not settled: with no server the screen holds its spinner, which is
      // enough to prove which screen the path built.
      await tester.pump();

      expect(find.byType(HomeworkAssignmentScreen), findsOneWidget);
    });
  });
}
