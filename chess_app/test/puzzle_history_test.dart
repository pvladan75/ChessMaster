// The list of which puzzles an account met — docs/PLAN-NAPREDAK-VEZBI.md §7,
// phase 6: `PuzzleHistoryScreen`, its rows, filters, pane and sheet, and the
// door on the Practise cards.
//
// The gate the plan wrote for it: widget tests at 360 x 640, 900 x 700 and
// 1536 x 792; the state in words on every row (the owner is colour-blind);
// filters that compose, on a fixture where each cuts something the other
// does not; boards square on both platforms' densities; an absence check that
// stands where the row would be drawn; the request carries the filters the
// chips show; and the door is on the card for an account with no trainer and
// no students (the owner's D3: roles play no part).
//
// The server is faked at the client (rule 7), and its rows are the server's
// own: `puzzleListOf` run over a small log on 1.10.2026, one row per case — an
// own exercise since deleted, a basic mate solved with a hint, a skipped game
// blunder, an endgame failed twice, a mate solved at once, a tactic solved on
// its second try. One row is added by hand, a second endgame that was solved,
// so that the source and the state each cut something the other would not.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/features/puzzle_history/puzzle_history_words.dart';
import 'package:chess_app/features/puzzle_history/screens/puzzle_history_screen.dart';
import 'package:chess_app/features/training/screens/training_hub_screen.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/ai_studio/category_selection_hub.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import 'support/landscape.dart';

/// An account with no trainer and no students: the door must not care.
final _session =
    UserSession(token: 'tok', id: 5, email: 'e', name: 'N', role: 'korisnik');

// What GET /api/puzzles/list answered, word for word (see the header).
const _served = r'''
{"puzzles":[
 {"source":"own","puzzleId":"ex_gone","state":"failed","firstTry":false,"tries":1,"solvedOnTry":null,"solvedWithHint":false,"firstAt":"2026-09-28T09:10:00.000Z","latestAt":"2026-09-28T09:10:00.000Z","available":false,"fen":null,"detail":{}},
 {"source":"basic_mate","puzzleId":"basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -","state":"solved","firstTry":false,"tries":1,"solvedOnTry":1,"solvedWithHint":true,"firstAt":"2026-09-28T09:00:00.000Z","latestAt":"2026-09-28T09:00:00.000Z","available":true,"fen":"4k3/8/4K3/8/8/8/8/7Q w - - 0 1","detail":{"preset":"easy"}},
 {"source":"blunder_game","puzzleId":"tw42:57","state":"skipped","firstTry":false,"tries":0,"solvedOnTry":null,"solvedWithHint":false,"firstAt":"2026-09-28T08:50:00.000Z","latestAt":"2026-09-28T08:50:00.000Z","available":true,"fen":"8/5pk1/8/8/8/8/5PK1/r7 b - - 0 55","detail":{"ply":57,"side":"black","white":"Chiburdanidze, Maia","black":"Gaprindashvili, Nona"}},
 {"source":"endgame","puzzleId":"eg_1","state":"failed","firstTry":false,"tries":2,"solvedOnTry":null,"solvedWithHint":false,"firstAt":"2026-09-28T08:40:00.000Z","latestAt":"2026-09-28T08:41:00.000Z","available":true,"fen":"8/8/4k3/8/3PK3/8/r7/7R w - - 0 1","detail":{"mode":"draw","type":"RookEndgame","material":"KRPvKR","materialLabel":"rook and pawn versus rook"}},
 {"source":"mate_puzzle","puzzleId":"m1","state":"solved","firstTry":true,"tries":1,"solvedOnTry":1,"solvedWithHint":false,"firstAt":"2026-09-28T08:30:00.000Z","latestAt":"2026-09-28T08:30:00.000Z","available":true,"fen":"6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1","detail":{"mateDepth":1}},
 {"source":"lichess","puzzleId":"00008","state":"solved","firstTry":false,"tries":2,"solvedOnTry":2,"solvedWithHint":false,"firstAt":"2026-09-28T08:10:00.000Z","latestAt":"2026-09-28T08:20:00.000Z","available":true,"fen":"r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2b1/PqP3PP/7K w - - 0 25","detail":{"rating":1939,"themes":["hangingPiece"]}}
],"next":null}
''';

List<Map<String, dynamic>> _items() {
  final rows =
      ((jsonDecode(_served) as Map<String, dynamic>)['puzzles'] as List)
          .cast<Map<String, dynamic>>()
          .toList();
  // The hand-made row: a second endgame, solved, a minute before the first.
  rows.insert(4, {
    ...rows[3],
    'puzzleId': 'eg_2',
    'state': 'solved',
    'firstTry': true,
    'tries': 1,
    'solvedOnTry': 1,
    'firstAt': '2026-09-28T08:35:00.000Z',
    'latestAt': '2026-09-28T08:35:00.000Z',
  });
  return rows;
}

/// GET /api/puzzles/list, answered as the server would: filtered by source
/// and state, a page at a time. Its cursor is its own; the client only hands
/// back what it was given.
class _Server {
  _Server({this.pageSize = 30, this.items});

  final int pageSize;
  List<Map<String, dynamic>>? items;
  bool down = false;
  final List<Uri> asked = [];

  http.Client get client => MockClient((request) async {
        if (request.url.path != '/api/puzzles/list') {
          return http.Response('{"error":"not here"}', 404);
        }
        asked.add(request.url);
        if (down) return http.Response('{"error":"down"}', 500);
        final q = request.url.queryParameters;
        final rows = (items ?? _items())
            .where((i) => q['source'] == null || i['source'] == q['source'])
            .where((i) => q['state'] == null || i['state'] == q['state'])
            .toList();
        final start =
            q['before'] == null ? 0 : int.parse(q['before']!.substring(1));
        final page = rows.skip(start).take(pageSize).toList();
        final next = start + page.length < rows.length
            ? 'c${start + page.length}'
            : null;
        return http.Response(jsonEncode({'puzzles': page, 'next': next}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      });
}

Future<void> _pump(WidgetTester tester, _Server server, Size size,
    {String? initialSource}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
    home: PuzzleHistoryScreen(
      session: _session,
      api: PuzzleAttemptApi(authToken: 'tok', client: server.client),
      initialSource: initialSource,
    ),
  ));
  await tester.pumpAndSettle();
}

Finder _row(String source, String id) =>
    find.byKey(ValueKey('puzzle-row-$source:$id'));

Finder _inRow(String source, String id, Finder what) =>
    find.descendant(of: _row(source, id), matching: what);

/// The list's own scroll view — the chip row scrolls too, so „the" scrollable
/// has to be named.
Finder _listScroll() => find
    .descendant(
        of: find.byKey(const ValueKey('puzzle-list')),
        matching: find.byType(Scrollable))
    .first;

List<String> _rowIds(WidgetTester tester) => tester
    .widgetList(find.byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('puzzle-row-')))
    .map((w) =>
        (w.key as ValueKey<String>).value.substring('puzzle-row-'.length))
    .toList();

void main() {
  setUpAll(loadRoboto);

  // ── the wire ───────────────────────────────────────────────────────────

  group('PuzzleAttemptApi.list', () {
    test('asks for what it is given, and nothing it is not', () async {
      final asked = <Uri>[];
      final api = PuzzleAttemptApi(
        authToken: 'tok',
        client: MockClient((r) async {
          asked.add(r.url);
          expect(r.headers['Authorization'], 'Bearer tok');
          return http.Response(_served, 200);
        }),
      );
      await api.list();
      await api.list(
          source: 'endgame', state: 'failed', before: 'abc', limit: 10);
      expect(asked[0].path, '/api/puzzles/list');
      expect(asked[0].queryParameters, isEmpty);
      expect(asked[1].queryParameters, {
        'source': 'endgame',
        'state': 'failed',
        'before': 'abc',
        'limit': '10'
      });
    });

    test("reads the server's rows as it wrote them", () async {
      final api = PuzzleAttemptApi(
          authToken: 'tok',
          client: MockClient((_) async => http.Response(_served, 200)));
      final page = (await api.list())!;
      expect(page.next, isNull);
      expect(page.puzzles.map((p) => p.key), [
        'own:ex_gone',
        'basic_mate:basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -',
        'blunder_game:tw42:57',
        'endgame:eg_1',
        'mate_puzzle:m1',
        'lichess:00008',
      ]);
      final lichess = page.puzzles.last;
      expect(lichess.state, PuzzleState.solved);
      expect(lichess.firstTry, isFalse);
      expect(lichess.tries, 2);
      expect(lichess.solvedOnTry, 2);
      expect(lichess.latestAt, DateTime.utc(2026, 9, 28, 8, 20));
      expect(
          lichess.fen, 'r6k/pp2r2p/4Rp1Q/3p4/8/1N1P2b1/PqP3PP/7K w - - 0 25');
      expect(page.puzzles.first.available, isFalse);
      expect(page.puzzles.first.fen, isNull);
    });

    test('a server that cannot be reached is no list, not an empty one',
        () async {
      final api = PuzzleAttemptApi(
          authToken: 'tok',
          client: MockClient((_) async => http.Response('{}', 500)));
      expect(await api.list(), isNull);
    });
  });

  // ── the words ──────────────────────────────────────────────────────────

  test('every row says what it is and where it stands, in words', () {
    final page =
        PuzzleListPage.fromJson(jsonDecode(_served) as Map<String, dynamic>);
    final by = {for (final p in page.puzzles) p.puzzleId: p};

    expect(
        puzzleKindWords(by['ex_gone']!), 'My exercise · no longer available');
    expect(puzzleKindWords(by['basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -']!),
        'Basic checkmate · easy');
    expect(puzzleKindWords(by['tw42:57']!), 'Game blunder · move 55');
    expect(puzzleKindWords(by['eg_1']!),
        'Rook and pawn versus rook · Hold a draw');
    expect(puzzleKindWords(by['m1']!), 'Mate in 1');
    // The server sends motifs only (`trainableThemes`, its one rule); the
    // app names what it is sent and filters nothing itself.
    expect(puzzleKindWords(by['00008']!), 'Tactics · hanging piece');

    expect(puzzleStateWords(by['ex_gone']!), 'Failed');
    expect(puzzleStateWords(by['basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -']!),
        'Solved with a hint');
    expect(puzzleStateWords(by['tw42:57']!), 'Skipped');
    expect(puzzleStateWords(by['eg_1']!), 'Failed');
    expect(puzzleStateWords(by['m1']!), 'Solved first try');
    expect(puzzleStateWords(by['00008']!), 'Solved on try 2');

    // Solved, not a first-try solve, on the first answer: a hint or a skip
    // came first, and the server says which. Until 1.10.2026 the words
    // guessed „with a hint" for both.
    PuzzleListItem solved({required int on, required bool hint}) =>
        PuzzleListItem.fromJson({
          'source': 'lichess',
          'puzzleId': 'x',
          'state': 'solved',
          'firstTry': false,
          'tries': on,
          'solvedOnTry': on,
          'solvedWithHint': hint,
          'firstAt': '2026-09-28T08:00:00.000Z',
          'latestAt': '2026-09-28T08:00:00.000Z',
          'available': true,
          'fen': null,
          'detail': <String, dynamic>{},
        });
    expect(puzzleStateWords(solved(on: 1, hint: true)), 'Solved with a hint');
    expect(puzzleStateWords(solved(on: 1, hint: false)), 'Solved after a skip');
    expect(puzzleStateWords(solved(on: 3, hint: true)),
        'Solved on try 3, with a hint');
    expect(puzzleStateWords(solved(on: 3, hint: false)), 'Solved on try 3');

    expect(puzzleTriesWords(by['eg_1']!), '2 tries');
    // A row's second line. A solved puzzle's state already names its try;
    // „Solved on try 2 · 2 tries" said it twice (seen rendered, 1.10.2026).
    expect(puzzleSummaryWords(by['eg_1']!), 'Failed · 2 tries · 28.9.2026');
    expect(puzzleSummaryWords(by['00008']!), 'Solved on try 2 · 28.9.2026');
    expect(puzzleSummaryWords(by['tw42:57']!), 'Skipped · 28.9.2026');
    expect(puzzleTriesWords(by['m1']!), '1 try');
    expect(puzzleTriesWords(by['tw42:57']!), isNull,
        reason: 'a skip is not a try');
  });

  // ── the screen ─────────────────────────────────────────────────────────

  testWidgets(
      'on a phone every row is drawn, says its state in words, and nothing overflows',
      (tester) async {
    final server = _Server();
    await _pump(tester, server, const Size(360, 640));

    expect(server.asked.single.queryParameters, isEmpty,
        reason: 'the whole list first');
    expect(_inRow('own', 'ex_gone', find.textContaining('Failed')),
        findsOneWidget);
    expect(
        _inRow('basic_mate', 'basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -',
            find.textContaining('Solved with a hint')),
        findsOneWidget);
    await tester.scrollUntilVisible(_row('lichess', '00008'), 200,
        scrollable: _listScroll());
    expect(_inRow('lichess', '00008', find.text('Tactics · hanging piece')),
        findsOneWidget);
    expect(_inRow('lichess', '00008', find.textContaining('Solved on try 2')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets("a row's board is square on $platform", (tester) async {
      // `ListTile`'s leading slot is 48 high on a desktop's compact density
      // and 56 on a phone's (measured 21.9.2026, library_grid_3b_test): a
      // board asked for more than 48 draws its eighth rank outside itself on
      // Windows only. Restored inside the body, as that test explains.
      debugDefaultTargetPlatformOverride = platform;
      try {
        await _pump(tester, _Server(), const Size(1536, 792));
        final board = tester.getSize(_inRow(
            'basic_mate',
            'basic:easy:4k3/8/4K3/8/8/8/8/7Q w - -',
            find.byType(BoardThumbnail)));
        expect(board.width, board.height, reason: 'on $platform: $board');
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  }

  testWidgets(
      'a puzzle that is gone has no board — where its board would be — while the others do',
      (tester) async {
    await _pump(tester, _Server(), const Size(1536, 792));
    // The absence is read inside the row that is drawn, beside rows that do
    // have boards: an empty screen would pass a bare „no board" check.
    expect(_row('own', 'ex_gone'), findsOneWidget);
    expect(_inRow('own', 'ex_gone', find.byType(BoardThumbnail)), findsNothing);
    expect(
        _inRow(
            'own', 'ex_gone', find.text('My exercise · no longer available')),
        findsOneWidget);
    expect(_inRow('blunder_game', 'tw42:57', find.byType(BoardThumbnail)),
        findsOneWidget);
  });

  testWidgets(
      'the state chips and the source menu each cut, and together cut what neither does',
      (tester) async {
    final server = _Server();
    await _pump(tester, server, const Size(900, 700));

    await tester.tap(find.byKey(const ValueKey('puzzle-state-failed')));
    await tester.pumpAndSettle();
    expect(server.asked.last.queryParameters, {'state': 'failed'});
    expect(_rowIds(tester), ['own:ex_gone', 'endgame:eg_1']);

    await tester.tap(find.byKey(const ValueKey('puzzle-source-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Endgames').last);
    await tester.pumpAndSettle();
    expect(server.asked.last.queryParameters,
        {'source': 'endgame', 'state': 'failed'});
    expect(_rowIds(tester), ['endgame:eg_1']);

    await tester.tap(find.byKey(const ValueKey('puzzle-state-all')));
    await tester.pumpAndSettle();
    expect(server.asked.last.queryParameters, {'source': 'endgame'});
    expect(_rowIds(tester), ['endgame:eg_1', 'endgame:eg_2']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'opened from a card, the list asks for that card\'s source and says so',
      (tester) async {
    final server = _Server();
    await _pump(tester, server, const Size(900, 700), initialSource: 'endgame');
    expect(server.asked.single.queryParameters, {'source': 'endgame'});
    // The menu's value, not a text inside it: a DropdownButton keeps every
    // item's text in its tree to size itself, so „Endgames" is found there
    // whichever source is chosen.
    expect(
        tester
            .widget<DropdownButton<String>>(
                find.byKey(const ValueKey('puzzle-source-menu')))
            .value,
        'endgame');
    expect(_rowIds(tester), ['endgame:eg_1', 'endgame:eg_2']);
  });

  testWidgets(
      '„Show more" asks for the next page and adds it; the last page has no button',
      (tester) async {
    final server = _Server(pageSize: 4);
    await _pump(tester, server, const Size(1536, 792));
    expect(_rowIds(tester).length, 4);

    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('puzzle-list-more')), 200,
        scrollable: _listScroll());
    await tester.tap(find.byKey(const ValueKey('puzzle-list-more')));
    await tester.pumpAndSettle();
    expect(server.asked.last.queryParameters, {'before': 'c4'});
    expect(_rowIds(tester).length, 7);
    expect(find.byKey(const ValueKey('puzzle-list-more')), findsNothing);
  });

  testWidgets('a wide window shows the chosen puzzle beside the list',
      (tester) async {
    await _pump(tester, _Server(), const Size(1536, 792));
    expect(find.text('Tap a puzzle to see it here.'), findsOneWidget);

    await tester.tap(_row('endgame', 'eg_1'));
    await tester.pumpAndSettle();
    final pane = find.byKey(const ValueKey('puzzle-pane'));
    expect(
        find.descendant(
            of: pane,
            matching: find.byWidgetPredicate((w) =>
                w is BoardThumbnail &&
                w.fen == '8/8/4k3/8/3PK3/8/r7/7R w - - 0 1' &&
                w.size > 48)),
        findsOneWidget);
    expect(
        find.descendant(
            of: pane,
            matching: find.text('Rook and pawn versus rook · Hold a draw')),
        findsOneWidget);
    expect(find.descendant(of: pane, matching: find.textContaining('Failed')),
        findsOneWidget);
    expect(find.text('Tap a puzzle to see it here.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a chosen puzzle the filter leaves out leaves the pane too',
      (tester) async {
    // A surviving mutation (1.10.2026) asked for this: the rule was written,
    // and nothing held it. A pane showing a puzzle the list no longer shows
    // describes nothing on the screen.
    await _pump(tester, _Server(), const Size(1536, 792));
    await tester.tap(_row('endgame', 'eg_1'));
    await tester.pumpAndSettle();
    expect(find.text('Tap a puzzle to see it here.'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('puzzle-state-solved')));
    await tester.pumpAndSettle();
    expect(_row('endgame', 'eg_1'), findsNothing);
    expect(find.text('Tap a puzzle to see it here.'), findsOneWidget);
  });

  testWidgets('an answer to a filter the reader has since changed is not drawn',
      (tester) async {
    // Two chips tapped quickly are two questions; the server may answer the
    // first one last. A surviving mutation (1.10.2026) showed that nothing
    // held the guard that drops it: here the whole list — the first question
    // — arrives after „Failed" has been answered.
    final firstAnswer = Completer<void>();
    var asked = 0;
    final client = MockClient((request) async {
      asked += 1;
      if (asked == 1) await firstAnswer.future;
      final q = request.url.queryParameters;
      final rows = _items()
          .where((i) => q['state'] == null || i['state'] == q['state'])
          .toList();
      return http.Response(jsonEncode({'puzzles': rows, 'next': null}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: PuzzleHistoryScreen(
        session: _session,
        api: PuzzleAttemptApi(authToken: 'tok', client: client),
      ),
    ));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('puzzle-state-failed')));
    await tester.pump();
    await tester.pump();
    expect(_rowIds(tester), ['own:ex_gone', 'endgame:eg_1']);

    firstAnswer.complete();
    await tester.pumpAndSettle();
    expect(_rowIds(tester), ['own:ex_gone', 'endgame:eg_1'],
        reason:
            'the late answer to „All" must not replace the answer to „Failed"');
  });

  testWidgets('900 wide is wide: the pane is there and nothing overflows',
      (tester) async {
    await _pump(tester, _Server(), const Size(900, 700));
    expect(find.byKey(const ValueKey('puzzle-pane')), findsOneWidget);
    await tester.tap(_row('mate_puzzle', 'm1'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('on a phone a tap opens the same panel as a sheet',
      (tester) async {
    await _pump(tester, _Server(), const Size(360, 640));
    expect(find.byKey(const ValueKey('puzzle-pane')), findsNothing);
    expect(find.text('Tap a puzzle to see it here.'), findsNothing);

    await tester.tap(_row('mate_puzzle', 'm1'));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(sheet, findsOneWidget);
    expect(
        find.descendant(
            of: sheet,
            matching: find.byWidgetPredicate((w) =>
                w is BoardThumbnail &&
                w.fen == '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1' &&
                w.size > 48)),
        findsOneWidget);
    expect(
        find.descendant(
            of: sheet, matching: find.textContaining('Solved first try')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no puzzles at all, and none for a filter, are said differently',
      (tester) async {
    final server = _Server(items: []);
    await _pump(tester, server, const Size(900, 700));
    expect(find.textContaining('No puzzles yet'), findsOneWidget);

    server.items = _items();
    await tester.tap(find.byKey(const ValueKey('puzzle-state-skipped')));
    await tester.pumpAndSettle();
    expect(_rowIds(tester), ['blunder_game:tw42:57']);
    server.items = [];
    await tester.tap(find.byKey(const ValueKey('puzzle-state-solved')));
    await tester.pumpAndSettle();
    expect(find.textContaining('No puzzles match'), findsOneWidget);
    expect(find.textContaining('No puzzles yet'), findsNothing);
  });

  testWidgets('a list that could not be read says so, and asks again on a tap',
      (tester) async {
    final server = _Server()..down = true;
    await _pump(tester, server, const Size(900, 700));
    expect(find.text('The list could not be loaded.'), findsOneWidget);
    server.down = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(server.asked.length, 2);
    expect(_rowIds(tester).length, 7);
  });

  // ── the door ───────────────────────────────────────────────────────────

  group('the door on the Practise cards', () {
    SourceProgress p({int seen = 3, int solved = 1, int toRetry = 2}) =>
        SourceProgress(
            seen: seen,
            solved: solved,
            firstTry: solved,
            failed: seen - solved,
            skipped: 0,
            toRetry: toRetry);

    Future<void> pumpHub(WidgetTester tester,
        {void Function(String)? onOpenList}) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CategorySelectionHubWidget(
              onSelectMatePuzzle: (_) {},
              onSelectBasicMate: (_) {},
              onSelectWinningPosition: () {},
              onSelectTactics: () {},
              onSelectEndgameWin: () {},
              onSelectEndgameDraw: () {},
              onSelectBlunderGames: () {},
              onSelectRepertoire: () {},
              onSelectMyGames: () {},
              onSelectMistakesDrill: () {},
              progress: {
                PuzzleSource.endgame: p(),
                PuzzleSource.blunderGame: p(seen: 1, solved: 1, toRetry: 0),
              },
              onOpenList: onOpenList,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('each progress line opens its own source', (tester) async {
      final opened = <String>[];
      await pumpHub(tester, onOpenList: opened.add);
      await tester.tap(find.text('Endgames: Solved 1 · 2 to retry'));
      await tester.tap(find.text('Game blunders: Solved 1'));
      expect(opened, [PuzzleSource.endgame, PuzzleSource.blunderGame]);
    });

    testWidgets('with no door given, a line is only words', (tester) async {
      // Rule 15: a widget that takes an optional callback draws only what it
      // was given — a line that looks like a door and opens nothing is worse
      // than a line.
      await pumpHub(tester);
      expect(find.text('Endgames: Solved 1 · 2 to retry'), findsOneWidget);
      expect(
          find.ancestor(
              of: find.text('Endgames: Solved 1 · 2 to retry'),
              matching: find.byType(InkWell)),
          findsNothing);
    });

    testWidgets(
        'the Practise tab opens the list for an account with no trainer and no students',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final opened = <Uri>[];
      final api = PuzzleAttemptApi(
        authToken: 'tok',
        client: MockClient((r) async {
          if (r.url.path == '/api/puzzles/progress') {
            return http.Response(
                jsonEncode({
                  'endgame': {
                    'seen': 3,
                    'solved': 1,
                    'firstTry': 1,
                    'failed': 2,
                    'skipped': 0,
                    'toRetry': 2
                  },
                }),
                200);
          }
          return http.Response('{}', 404);
        }),
      );
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
              path: '/',
              builder: (_, __) =>
                  TrainingHubScreen(session: _session, attemptApi: api)),
          GoRoute(
            path: AppRoutes.puzzleHistory,
            builder: (_, state) {
              opened.add(state.uri);
              return const Scaffold(body: Text('the list'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        theme:
            ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Endgames: Solved 1 · 2 to retry'));
      await tester.pumpAndSettle();
      expect(find.text('the list'), findsOneWidget);
      expect(opened.single.path, AppRoutes.puzzleHistory);
      expect(opened.single.queryParameters, {'source': 'endgame'});
    });
  });
}
