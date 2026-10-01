// The actions on a puzzle in the list — docs/PLAN-NAPREDAK-VEZBI.md §7,
// phase 7: „Try again" and „Open in Analysis", from the pane beside the list
// and from the sheet on a phone.
//
// The gate the plan wrote for it: a try opens the puzzle's own drill on a
// queue of one, and the list moves after it; „Try again" is on no game blunder
// or basic mate (D2), and on an own exercise only if it can be answered with
// one move; „Open in Analysis" is on every row with a board — failed, skipped
// and solved alike (D3: everything opens, for every account) — on none
// without one, and opens the row's own board; and looking writes nothing, so
// a look followed by a solved try cannot raise the first-try figure (the
// server's fold reads the first row for that — puzzle_list.test.js).
//
// The rows are the server's own answer: `puzzleListOf` over a log with one
// puzzle of every kind, run on 1.10.2026, plus the deleted own exercise of
// the phase-6 fixture.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/features/assignments/screens/custom_puzzle_solver_screen.dart';
import 'package:chess_app/features/endgame_trainer/screens/endgame_trainer_screen.dart';
import 'package:chess_app/features/endgame_trainer/services/endgame_api_service.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/puzzle_history/screens/puzzle_history_screen.dart';
import 'package:chess_app/features/tactics_trainer/screens/tactics_trainer_screen.dart';
import 'package:chess_app/features/tactics_trainer/services/tactics_api_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_router.dart' show appRouteTable;
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/screens/ai_studio_screen.dart';
import 'package:chess_app/theme/app_colors.dart';

final _session =
    UserSession(token: 'tok', id: 5, email: 'e', name: 'N', role: 'korisnik');

// GET /api/puzzles/list, word for word (see the header).
const _served = r'''
{"puzzles":[
 {"source":"own","puzzleId":"ex_game","state":"failed","firstTry":false,"tries":1,"solvedOnTry":null,"solvedWithHint":false,"firstAt":"2026-09-29T09:10:00.000Z","latestAt":"2026-09-29T09:10:00.000Z","available":true,"fen":"8/8/4k3/8/3PK3/8/8/8 w - - 0 1","detail":{"instruction":"Win it.","sourceTitle":null,"findable":false}},
 {"source":"own","puzzleId":"ex_find","state":"failed","firstTry":false,"tries":1,"solvedOnTry":null,"solvedWithHint":false,"firstAt":"2026-09-29T09:00:00.000Z","latestAt":"2026-09-29T09:00:00.000Z","available":true,"fen":"6k1/5ppp/8/8/8/8/5PPP/1R4K1 w - - 0 1","detail":{"instruction":"White mates in one.","sourceTitle":null,"findable":true}},
 {"source":"basic_mate","puzzleId":"basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -","state":"solved","firstTry":true,"tries":1,"solvedOnTry":1,"solvedWithHint":false,"firstAt":"2026-09-29T08:50:00.000Z","latestAt":"2026-09-29T08:50:00.000Z","available":true,"fen":"4k3/8/4K3/8/8/8/8/7Q w - - 0 1","detail":{"preset":"easy"}},
 {"source":"blunder_game","puzzleId":"tw42:57","state":"failed","firstTry":false,"tries":1,"solvedOnTry":null,"solvedWithHint":false,"firstAt":"2026-09-29T08:40:00.000Z","latestAt":"2026-09-29T08:40:00.000Z","available":true,"fen":"8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55","detail":{"ply":57,"side":"black","white":"Chiburdanidze, Maia","black":"Gaprindashvili, Nona"}},
 {"source":"endgame","puzzleId":"eg_1","state":"failed","firstTry":false,"tries":1,"solvedOnTry":null,"solvedWithHint":false,"firstAt":"2026-09-29T08:30:00.000Z","latestAt":"2026-09-29T08:30:00.000Z","available":true,"fen":"8/8/4k3/8/3PK3/8/r7/7R w - - 0 1","detail":{"mode":"draw","type":"RookEndgame","material":"KRPvKR","materialLabel":"rook and pawn versus rook"}},
 {"source":"winning_position","puzzleId":"w1","state":"skipped","firstTry":false,"tries":0,"solvedOnTry":null,"solvedWithHint":false,"firstAt":"2026-09-29T08:25:00.000Z","latestAt":"2026-09-29T08:25:00.000Z","available":true,"fen":"r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 4 4","detail":{}},
 {"source":"mate_puzzle","puzzleId":"m1","state":"solved","firstTry":true,"tries":1,"solvedOnTry":1,"solvedWithHint":false,"firstAt":"2026-09-29T08:20:00.000Z","latestAt":"2026-09-29T08:20:00.000Z","available":true,"fen":"6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1","detail":{"mateDepth":1}},
 {"source":"lichess","puzzleId":"00008","state":"failed","firstTry":false,"tries":1,"solvedOnTry":null,"solvedWithHint":false,"firstAt":"2026-09-29T08:10:00.000Z","latestAt":"2026-09-29T08:10:00.000Z","available":true,"fen":"r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2b1/PqP3PP/7K w - - 0 25","detail":{"rating":1939,"themes":["hangingPiece"]}},
 {"source":"own","puzzleId":"ex_gone","state":"failed","firstTry":false,"tries":1,"solvedOnTry":null,"solvedWithHint":false,"firstAt":"2026-09-28T09:10:00.000Z","latestAt":"2026-09-28T09:10:00.000Z","available":false,"fen":null,"detail":{}}
],"next":null}
''';

/// The list's server, and every request any screen sends — a write among
/// them would be a look that counted.
class _Server {
  final List<http.Request> requests = [];

  /// Rows that changed since the first read, as a drill would have left them.
  final Map<String, Map<String, dynamic>> changed = {};

  List<Map<String, dynamic>> _rows() =>
      ((jsonDecode(_served) as Map<String, dynamic>)['puzzles'] as List)
          .cast<Map<String, dynamic>>()
          .map((r) => changed['${r['source']}:${r['puzzleId']}'] ?? r)
          .toList();

  int get listReads =>
      requests.where((r) => r.url.path == '/api/puzzles/list').length;

  Iterable<http.Request> get writes => requests.where((r) => r.method != 'GET');

  http.Client get client => MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/puzzles/list') {
          return http.Response(
              jsonEncode({'puzzles': _rows(), 'next': null}), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }
        return http.Response('{"error":"not here"}', 404);
      });
}

/// Where the actions lead, recorded rather than built: each stands in for its
/// drill, with a way back.
class _Router {
  final List<Uri> opened = [];

  GoRouter build(_Server server, {ExerciseApiService? exerciseApi}) {
    // Recorded once, when the page is made: a route's builder may run again
    // on a rebuild, and one visit must not read as two.
    Widget stand(GoRouterState state) =>
        _StandIn(uri: state.uri, onCreated: opened.add);

    return GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => PuzzleHistoryScreen(
            session: _session,
            api: PuzzleAttemptApi(authToken: 'tok', client: server.client),
            exerciseApi: exerciseApi ??
                ExerciseApiService(authToken: 'tok', client: server.client),
          ),
        ),
        for (final path in [
          AppRoutes.tactics,
          AppRoutes.trainingDrill,
          AppRoutes.endgames,
          AppRoutes.analysis,
        ])
          GoRoute(path: path, builder: (_, state) => stand(state)),
      ],
    );
  }
}

Future<(_Server, _Router)> _open(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final server = _Server();
  final router = _Router();
  final goRouter = router.build(server);
  addTearDown(goRouter.dispose);
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp.router(
      routerConfig: goRouter,
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    ),
  ));
  await tester.pumpAndSettle();
  return (server, router);
}

Finder _row(String key) => find.byKey(ValueKey('puzzle-row-$key'));
Finder _pane() => find.byKey(const ValueKey('puzzle-pane'));
Finder _inPane(Finder what) => find.descendant(of: _pane(), matching: what);

Future<void> _choose(WidgetTester tester, String key) async {
  // Dragged until the row's middle can be hit. A lazily built list only
  // estimates its length until every row is laid out, so `ensureVisible` on
  // a row near the end can stop a few pixels short of the edge — measured
  // 1.10.2026, a tap at y = 796 in a 792 window — and the tap then hits
  // nothing.
  await tester.dragUntilVisible(
    _row(key).hitTestable(),
    find
        .descendant(
            of: find.byKey(const ValueKey('puzzle-list')),
            matching: find.byType(Scrollable))
        .first,
    const Offset(0, -60),
  );
  await tester.pumpAndSettle();
  await tester.tap(_row(key));
  await tester.pumpAndSettle();
}

void main() {
  // ── where a try leads ──────────────────────────────────────────────────

  test(
      'every source has one way back into its drill, with or without a puzzle named',
      () {
    // One home for „which drill retries this source": the hub's „Retry failed"
    // (no id) and the list's „Try again" (one id) both read it.
    expect(AppRoutes.retryPath('lichess'), '/tactics?retry=1');
    expect(AppRoutes.retryPath('lichess', id: '00008'),
        '/tactics?retry=1&id=00008');
    expect(AppRoutes.retryPath('mate_puzzle'),
        '/training/drill?category=mate_puzzle&retry=1');
    expect(AppRoutes.retryPath('mate_puzzle', id: 'm1'),
        '/training/drill?category=mate_puzzle&retry=1&id=m1');
    expect(AppRoutes.retryPath('winning_position', id: 'w1'),
        '/training/drill?category=winning_position&retry=1&id=w1');
    expect(AppRoutes.retryPath('endgame'), '/endgames?retry=1');
    expect(AppRoutes.retryPath('endgame', id: 'eg_1'),
        '/endgames?retry=1&id=eg_1');
    expect(AppRoutes.retryPath('own'), '/exercises/solve?retry=1');
    // One own exercise is solved on the shared solver, as the Library does it,
    // not through a route; game blunders and basic mates have no retry (D2).
    expect(AppRoutes.retryPath('own', id: 'ex_find'), isNull);
    expect(AppRoutes.retryPath('blunder_game'), isNull);
    expect(AppRoutes.retryPath('basic_mate', id: 'basic:easy:x'), isNull);
    // An id is a value in the query, whatever it holds.
    expect(
        Uri.parse(AppRoutes.retryPath('endgame', id: 'a b&c')!)
            .queryParameters['id'],
        'a b&c');
  });

  group('the real routes hand the drill its one puzzle', () {
    Future<Widget> screenAt(WidgetTester tester, String location) async {
      final router = GoRouter(initialLocation: location, routes: appRouteTable);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppColorTokens.dark]),
        ),
      ));
      await tester.pump();
      return tester.widget(find.byWidgetPredicate((w) =>
          w is TacticsTrainerScreen ||
          w is EndgameTrainerScreen ||
          w is AiStudioScreen));
    }

    testWidgets('tactics', (tester) async {
      final screen = await screenAt(tester, '/tactics?retry=1&id=00008')
          as TacticsTrainerScreen;
      expect(screen.retry, isTrue);
      expect(screen.retryIds, ['00008']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('mates and winning positions', (tester) async {
      final screen =
          await screenAt(tester, AppRoutes.retryPath('mate_puzzle', id: 'm1')!)
              as AiStudioScreen;
      expect(screen.retry, isTrue);
      expect(screen.retryIds, ['m1']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('endgames', (tester) async {
      final screen = await screenAt(tester, '/endgames?retry=1&id=eg_1')
          as EndgameTrainerScreen;
      expect(screen.retry, isTrue);
      expect(screen.retryIds, ['eg_1']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('without an id, the queue is the server\'s, as before',
        (tester) async {
      final screen =
          await screenAt(tester, '/tactics?retry=1') as TacticsTrainerScreen;
      expect(screen.retryIds, isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });

  // ── the drills walk the queue they are given ──────────────────────────

  group('a drill given its queue asks for that puzzle, not for the retry list',
      () {
    late List<Uri> asked;
    http.Client client() => MockClient((request) async {
          asked.add(request.url);
          return http.Response('{"error":"not in this test"}', 404);
        });
    setUp(() => asked = []);

    testWidgets('tactics', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: TacticsTrainerScreen(
          session: _session,
          retry: true,
          retryIds: const ['00008'],
          api: TacticsApiService(authToken: 'tok', client: client()),
          attemptApi: PuzzleAttemptApi(authToken: 'tok', client: client()),
        ),
      ));
      await tester.pumpAndSettle();
      expect(asked.map((u) => u.path), contains('/api/puzzles/by-id/00008'));
      expect(asked.where((u) => u.path == '/api/puzzles/retry'), isEmpty);
    });

    testWidgets('endgames', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: EndgameTrainerScreen(
          session: _session,
          retry: true,
          retryIds: const ['eg_1'],
          api: EndgameApiService(authToken: 'tok', client: client()),
          attemptApi: PuzzleAttemptApi(authToken: 'tok', client: client()),
        ),
      ));
      await tester.pumpAndSettle();
      expect(asked.map((u) => u.path), contains('/api/puzzles/by-id/eg_1'));
      expect(asked.where((u) => u.path == '/api/puzzles/retry'), isEmpty);
    });
  });

  // ── the pane ───────────────────────────────────────────────────────────

  // Each puzzle as a real try would leave it, from where it stood: a failed
  // tactic and a failed ending solved on the second answer, a mate solved at
  // once failed on the second, a winning position skipped and then solved on
  // its first answer.
  for (final (key, path, query, now, says) in [
    (
      'lichess:00008',
      AppRoutes.tactics,
      {'retry': '1', 'id': '00008'},
      {'state': 'solved', 'tries': 2, 'solvedOnTry': 2},
      'Solved on try 2',
    ),
    (
      'mate_puzzle:m1',
      AppRoutes.trainingDrill,
      {'category': 'mate_puzzle', 'retry': '1', 'id': 'm1'},
      {'state': 'failed', 'tries': 2},
      'Failed · 2 tries',
    ),
    (
      'winning_position:w1',
      AppRoutes.trainingDrill,
      {'category': 'winning_position', 'retry': '1', 'id': 'w1'},
      {'state': 'solved', 'tries': 1, 'solvedOnTry': 1},
      'Solved after a skip',
    ),
    (
      'endgame:eg_1',
      AppRoutes.endgames,
      {'retry': '1', 'id': 'eg_1'},
      {'state': 'solved', 'tries': 2, 'solvedOnTry': 2},
      'Solved on try 2',
    ),
  ]) {
    testWidgets(
        '„Try again" on $key opens its drill on that one puzzle, and the list moves after it',
        (tester) async {
      final (server, router) = await _open(tester, const Size(1536, 792));
      await _choose(tester, key);
      final reads = server.listReads;

      server.changed[key] = {
        ...(((jsonDecode(_served) as Map)['puzzles'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhere((r) => '${r['source']}:${r['puzzleId']}' == key)),
        ...now,
      };
      await tester.tap(_inPane(find.text('Try again')));
      await tester.pumpAndSettle();
      expect(router.opened.single.path, path);
      expect(router.opened.single.queryParameters, query);

      await tester.tap(find.textContaining('stand-in for'));
      await tester.pumpAndSettle();
      expect(server.listReads, reads + 1,
          reason: 'the list is read again on the way back');
      expect(
          find.descendant(of: _row(key), matching: find.textContaining(says)),
          findsOneWidget);
      // And the pane, which still shows the chosen puzzle, shows it as it is
      // now.
      expect(_inPane(find.textContaining(says.split(' · ').first)),
          findsOneWidget);
    });
  }

  testWidgets(
      'an own find exercise is tried again on the shared solver, on that one position',
      (tester) async {
    final (server, router) = await _open(tester, const Size(1536, 792));
    await _choose(tester, 'own:ex_find');
    final reads = server.listReads;
    await tester.tap(_inPane(find.text('Try again')));
    await tester.pumpAndSettle();

    final solver = tester.widget<CustomPuzzleSolverScreen>(
        find.byType(CustomPuzzleSolverScreen));
    expect(solver.positions.map((p) => p.puzzleId), ['ex_find']);
    expect(
        solver.positions.single.fen, '6k1/5ppp/8/8/8/8/5PPP/1R4K1 w - - 0 1');
    expect(solver.positions.single.instruction, 'White mates in one.');
    expect(router.opened, isEmpty, reason: 'not a route: the Library\'s way');

    Navigator.of(tester.element(find.byType(CustomPuzzleSolverScreen))).pop();
    await tester.pumpAndSettle();
    expect(server.listReads, reads + 1);
  });

  for (final key in [
    'blunder_game:tw42:57',
    'basic_mate:basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -',
    'own:ex_game'
  ]) {
    testWidgets(
        'no „Try again" on $key — where it would be drawn — but it opens',
        (tester) async {
      // The absence is read in the pane of that puzzle, beside the action it
      // does have: an empty pane would pass a bare „no Try again" check.
      await _open(tester, const Size(1536, 792));
      await _choose(tester, key);
      expect(_inPane(find.text('Open in Analysis')), findsOneWidget);
      expect(_inPane(find.text('Try again')), findsNothing);
    });
  }

  testWidgets('a puzzle that is gone offers neither', (tester) async {
    await _open(tester, const Size(1536, 792));
    await _choose(tester, 'own:ex_gone');
    expect(_inPane(find.text('This puzzle is no longer available.')),
        findsOneWidget);
    expect(_inPane(find.text('Open in Analysis')), findsNothing);
    expect(_inPane(find.text('Try again')), findsNothing);
  });

  for (final (key, fen) in [
    (
      'lichess:00008',
      'r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2b1/PqP3PP/7K w - - 0 25'
    ), // failed
    (
      'winning_position:w1',
      'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5Q2/PPPP1PPP/RNB1K1NR w KQkq - 4 4'
    ), // skipped
    ('mate_puzzle:m1', '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1'), // solved
  ]) {
    testWidgets(
        '„Open in Analysis" on $key opens its own board, and writes nothing',
        (tester) async {
      final (server, router) = await _open(tester, const Size(1536, 792));
      await _choose(tester, key);
      await tester.tap(_inPane(find.text('Open in Analysis')));
      await tester.pumpAndSettle();
      expect(router.opened.single.path, AppRoutes.analysis);
      expect(router.opened.single.queryParameters, {'fen': fen});
      // A look is not an attempt: nothing is written, so it cannot count.
      expect(server.writes, isEmpty);
    });
  }

  // ── the sheet ──────────────────────────────────────────────────────────

  testWidgets(
      'on a phone the sheet carries the same actions, and closes behind them',
      (tester) async {
    final (_, router) = await _open(tester, const Size(360, 640));
    await _choose(tester, 'own:ex_find');
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text('Try again')),
        findsOneWidget);

    await tester.tap(
        find.descendant(of: sheet, matching: find.text('Open in Analysis')));
    await tester.pumpAndSettle();
    expect(router.opened.single.path, AppRoutes.analysis);
    expect(router.opened.single.queryParameters,
        {'fen': '6k1/5ppp/8/8/8/8/5PPP/1R4K1 w - - 0 1'});
    // Back from Analysis, the list is all there is. A sheet left open under
    // Analysis is not found while Analysis covers it — a finder skips what an
    // opaque page hides — so the case comes back to look (a surviving
    // mutation, 1.10.2026).
    await tester.tap(find.textContaining('stand-in for'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing,
        reason: 'the sheet is not left open under what it opened');
    expect(tester.takeException(), isNull);
  });
}

class _StandIn extends StatefulWidget {
  const _StandIn({required this.uri, required this.onCreated});

  final Uri uri;
  final void Function(Uri) onCreated;

  @override
  State<_StandIn> createState() => _StandInState();
}

class _StandInState extends State<_StandIn> {
  @override
  void initState() {
    super.initState();
    widget.onCreated(widget.uri);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => context.pop(),
          child: Text('stand-in for ${widget.uri.path}'),
        ),
      );
}
