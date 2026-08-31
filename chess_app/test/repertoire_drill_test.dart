import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:chess_app/features/repertoire/screens/repertoire_drill_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// The Smith-Morra accepted, Black to move.
const smithMorra = 'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 0 4';

/// A drill server with no server: it hands back one question and grades the
/// answer against a fixed decision.
class _FakeApi extends RepertoireApiService {
  _FakeApi({
    this.outcomeFor,
    this.reply = 'g1f3',
    this.replyCovered = true,
    this.item = smithMorra,
    this.stats = const DrillStats(positions: 6, due: 2, known: 1, fresh: 3),
  }) : super(client: MockClient((_) async => http.Response('{}', 500)));

  /// What this student decided to play here: 4...Nc6 in the Smith-Morra.
  static const primaryUci = 'b8c6';
  static const primarySan = 'Nc6';

  final String? outcomeFor;
  final String? reply;
  final bool replyCovered;
  final String? item;
  final DrillStats stats;

  int loads = 0;
  int reveals = 0;
  bool? lastRevealedFlag;

  /// The line handed back, and null for a server that did not answer — which
  /// the screen must tell apart from a line with no question in it.
  DrillLine? line;

  /// What comes back when the caller asks to practise ahead of schedule. Null
  /// means the same line as always.
  DrillLine? aheadLine;
  int lineCalls = 0;
  String? lastFromFen;
  bool? lastAhead;

  /// How many answers were graded. The rehearsal must add nothing to this: a
  /// prefix is replayed many times a day, and grading it would push those
  /// positions out on repetitions nobody had to remember cold.
  int graded = 0;
  bool? lastPractice;

  @override
  Future<DrillLine?> drillLine({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? fromFen,
    bool ahead = false,
  }) async {
    lineCalls += 1;
    lastFromFen = fromFen;
    lastAhead = ahead;
    return aheadLine != null && ahead ? aheadLine : line;
  }

  @override
  Future<({DrillItem? item, DrillStats stats})> nextDrill(
      {required String color}) async {
    loads += 1;
    return (
      item: item == null
          ? null
          : DrillItem(fen: item!, fresh: false, repetitions: 3, moves: 2),
      stats: stats,
    );
  }

  @override
  Future<RepertoireMove?> revealDrill({
    required String color,
    required String fen,
  }) async {
    reveals += 1;
    return RepertoireMove(uci: primaryUci, san: primarySan, role: 'primary');
  }

  @override
  Future<DrillAnswer?> answerDrill({
    required String color,
    required String fen,
    required String uci,
    bool revealed = false,
    int? minRating,
    bool practice = false,
  }) async {
    graded += 1;
    lastPractice = practice;
    lastRevealedFlag = revealed;
    final outcome = outcomeFor ?? (uci == primaryUci ? 'primary' : 'unknown');
    return DrillAnswer(
      outcome: outcome,
      primary: outcome == 'unprepared'
          ? null
          : RepertoireMove(uci: primaryUci, san: primarySan, role: 'primary'),
      intervalDays: practice ? null : (outcome == 'primary' ? 6 : 0),
      reply: outcome == 'unprepared' ? null : reply,
      replyCovered: replyCovered,
      practice: practice,
    );
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    _FakeApi api, {
    void Function(String fen)? onBuildHere,
    Size size = const Size(500, 1000),
    Key? key,
    String? rootFen,
    List<String> rootPath = const [],
    String? fromFen,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: RepertoireDrillScreen(
        key: key,
        name: 'Smit-Mora, crni',
        color: 'b',
        rootFen: rootFen,
        rootPath: rootPath,
        fromFen: fromFen,
        api: api,
        onBuildHere: onBuildHere,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> play(WidgetTester tester, String from, String to) async {
    final finder = find.byType(ChessBoardWithOverlay);
    final widget = tester.widget<ChessBoardWithOverlay>(finder);
    final rect = tester.getRect(finder);
    final square = widget.boardSize / 8;
    Offset at(String name) {
      final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
      final col =
          widget.boardOrientation == PlayerColor.black ? 7 - file : file;
      final row =
          widget.boardOrientation == PlayerColor.black ? rank : 7 - rank;
      return rect.topLeft + Offset((col + 0.5) * square, (row + 0.5) * square);
    }

    await tester.tapAt(at(from));
    await tester.pumpAndSettle();
    await tester.tapAt(at(to));
    await tester.pumpAndSettle();
  }

  testWidgets('the question comes without its answer', (tester) async {
    final api = _FakeApi();
    await pump(tester, api);

    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    // The move the student decided on is nowhere on the screen until they ask
    // for it or play something.
    expect(find.textContaining('Nc6'), findsNothing);
    expect(find.textContaining('na redu: 2'), findsOneWidget);
  });

  testWidgets('the move they decided on is a pass, and says when it returns',
      (tester) async {
    final api = _FakeApi();
    await pump(tester, api);

    await play(tester, 'b8', 'c6');

    expect(find.textContaining('Tačno'), findsOneWidget);
    expect(find.textContaining('Vraća se za 6 dana'), findsOneWidget);
    expect(api.lastRevealedFlag, false);
  });

  testWidgets('good chess that is not their decision is still a miss',
      (tester) async {
    // The drill asks about a decision. Accepting anything sound would make the
    // schedule meaningless, because everything would always be a pass.
    final api = _FakeApi();
    await pump(tester, api);

    await play(tester, 'g8', 'f6');

    expect(find.textContaining('Nije to'), findsOneWidget);
    expect(find.textContaining('Vaš potez je Nc6'), findsOneWidget);
  });

  testWidgets('asking to be shown marks the answer as recognised',
      (tester) async {
    final api = _FakeApi();
    await pump(tester, api);

    await tester.tap(find.text('Pokaži'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Vaš potez je Nc6'), findsOneWidget);
    expect(api.reveals, 1);

    await play(tester, 'b8', 'c6');
    expect(api.lastRevealedFlag, true,
        reason: 'prepoznato nije isto što i zapamćeno');
  });

  testWidgets('the opponent answers, and an unprepared reply is named as such',
      (tester) async {
    final api = _FakeApi(reply: 'a2a3', replyCovered: false);
    await pump(tester, api);

    await play(tester, 'b8', 'c6');

    expect(find.textContaining('Protivnik je odgovorio a3'), findsOneWidget);
    expect(find.textContaining('to niste pokrili'), findsOneWidget);
  });

  testWidgets('a position that was never built offers to build it',
      (tester) async {
    String? asked;
    final api = _FakeApi(outcomeFor: 'unprepared');
    await pump(tester, api, onBuildHere: (fen) => asked = fen);

    await play(tester, 'b8', 'c6');
    expect(find.textContaining('niste pokrili'), findsOneWidget);

    await tester.tap(find.text('Izgradi ovu poziciju'));
    await tester.pumpAndSettle();
    expect(asked, smithMorra,
        reason: 'gradi se pozicija u kojoj je stao, ne neka druga');
  });

  testWidgets('an empty schedule is told apart from an empty repertoire',
      (tester) async {
    final nothingBuilt = _FakeApi(
      item: null,
      stats: const DrillStats(positions: 0, due: 0, known: 0, fresh: 0),
    );
    // A key per case: without one Flutter reuses the same State across the two
    // pumps, initState never runs again, and the second case quietly asserts
    // against the first one's data.
    await pump(tester, nothingBuilt, key: const ValueKey('nista-izgradjeno'));
    expect(find.text('Još nema šta da se vežba.'), findsOneWidget);

    final nothingDue = _FakeApi(
      item: null,
      stats: const DrillStats(positions: 20, due: 0, known: 9, fresh: 0),
    );
    await pump(tester, nothingDue, key: const ValueKey('nista-na-redu'));
    expect(find.text('Ništa nije na redu.'), findsOneWidget);
    expect(find.textContaining('znate 9 od 20'), findsOneWidget);
  });

  testWidgets('the drill fits a 360 dp phone', (tester) async {
    final api = _FakeApi();
    await pump(tester, api, size: const Size(360, 640));
    expect(tester.takeException(), isNull);

    await play(tester, 'b8', 'c6');
    expect(tester.takeException(), isNull);
  });

  /// The position after a line of SAN moves from the start of a game.
  ///
  /// Computed rather than pasted, like the frontier's tests: a hand-written FEN
  /// is a chance to assert against a position that does not exist, and the
  /// screen would then be right while the test was wrong.
  String fenAfter(List<String> sans) {
    final board = chess.Chess();
    for (final san in sans) {
      board.move(san);
    }
    return board.fen;
  }

  /// 1.e4 c5 2.d4 cxd4 3.c3 — the Smith-Morra, with Black to move at every
  /// point the student is asked anything. The question is what to do about
  /// 3.c3, and everything before it is rehearsal.
  DrillLine morraLine({bool startKnown = false, List<String>? startPath}) =>
      DrillLine(
        rootPath: const ['e4'],
        startFen: fenAfter(['e4']),
        startPath: startPath ?? const [],
        startKnown: startKnown,
        prefix: const [
          LineMove(uci: 'c7c5', san: 'c5', mine: true),
          LineMove(uci: 'd2d4', san: 'd4', mine: false),
          LineMove(uci: 'c5d4', san: 'cxd4', mine: true),
          LineMove(uci: 'c2c3', san: 'c3', mine: false),
        ],
        question: DrillItem(
          fen: fenAfter(['e4', 'c5', 'd4', 'cxd4', 'c3']),
          fresh: true,
          repetitions: 0,
          moves: 1,
          path: const ['c5', 'd4', 'cxd4', 'c3'],
        ),
        stats: const DrillStats(positions: 6, due: 1, known: 2, fresh: 3),
      );

  testWidgets('the question arrives at the end of the line that leads to it',
      (tester) async {
    // The drill used to put up a bare board four moves into something with no
    // way to tell how it arose. A repertoire is played forwards, and this is
    // the difference between remembering a line and recognising a photograph
    // of its end.
    final api = _FakeApi()..line = morraLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    expect(api.lineCalls, 1);
    expect(find.text('Ponovite liniju'), findsOneWidget);
    expect(find.text('1.e4'), findsOneWidget);
    expect(find.textContaining('potez 1 od 2'), findsOneWidget);

    await play(tester, 'c7', 'c5');

    // The student's move and the opponent's answer, both on the board and both
    // in the line above it.
    expect(find.text('1.e4 c5 2.d4'), findsOneWidget);
    expect(find.textContaining('potez 2 od 2'), findsOneWidget);

    await play(tester, 'c5', 'd4');

    // And now the question, at the end of the line rather than on its own.
    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    expect(find.text('1.e4 c5 2.d4 cxd4 3.c3'), findsOneWidget);
    // Nothing along the way was graded.
    expect(api.graded, 0, reason: 'ponavljanje je ocenjeno');
  });

  testWidgets('a wrong move in the rehearsal is named, not marked',
      (tester) async {
    // The rule the whole line drill rests on. A prefix is replayed many times a
    // day on the way to whatever is due below it, so grading it would push
    // those positions' intervals out on rehearsals nobody had to remember cold.
    final api = _FakeApi()..line = morraLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    await play(tester, 'e7', 'e5');

    expect(find.textContaining('U ovoj liniji ide c5'), findsOneWidget);
    expect(api.graded, 0, reason: 'ponavljanje je ocenjeno');
    // The line's own move went on the board anyway: carrying on from a move
    // that is not in the line would be rehearsing a different line.
    expect(find.text('1.e4 c5 2.d4'), findsOneWidget);
  });

  testWidgets('the rehearsal can be skipped', (tester) async {
    // Worth having and not a toll gate.
    final api = _FakeApi()..line = morraLine();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    await tester.tap(find.text('Preskoči ponavljanje'));
    await tester.pumpAndSettle();

    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    expect(find.text('1.e4 c5 2.d4 cxd4 3.c3'), findsOneWidget);
  });

  testWidgets('a rehearsal that starts where the student knows says so',
      (tester) async {
    // Twelve plies of rehearsal to reach one question is how a drill stops
    // being opened — and a short one is something the student earned, so it is
    // a different sentence from "we start at the beginning".
    final api = _FakeApi()
      ..line = morraLine(startKnown: true, startPath: const ['c5', 'd4']);
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    expect(find.textContaining('dokle znate napamet'), findsOneWidget);
  });

  testWidgets('a line that could not be read falls back, and says so',
      (tester) async {
    // "We could not work out the line" must not be shown as "here is your
    // question, cold" with nothing said. The drill still works; the sentence is
    // there so a broken walk is noticed rather than lived with.
    final api = _FakeApi();
    await pump(tester, api, rootFen: fenAfter(['e4']), rootPath: const ['e4']);

    expect(api.lineCalls, 1);
    expect(api.loads, 1);
    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    expect(find.textContaining('bez ponavljanja'), findsOneWidget);
  });

  testWidgets('an empty branch says it is the branch that is empty',
      (tester) async {
    // The block. "Nothing here" about one branch and "nothing at all" are
    // different sentences, and the student asked about a branch.
    final api = _FakeApi()
      ..line = const DrillLine(
        reason: 'nothing-built',
        stats: DrillStats(positions: 0, due: 0, known: 0, fresh: 0),
      );
    await pump(tester, api,
        rootFen: fenAfter(['e4']),
        rootPath: const ['e4'],
        fromFen: fenAfter(['e4', 'c5', 'd4']));

    expect(api.lastFromFen, fenAfter(['e4', 'c5', 'd4']));
    expect(find.text('U ovoj grani nema šta da se vežba.'), findsOneWidget);
  });

  testWidgets('the rehearsal fits a 360 dp phone', (tester) async {
    // A release build paints no overflow stripes; in a test build it throws.
    final api = _FakeApi()..line = morraLine();
    await pump(tester, api,
        size: const Size(360, 640),
        rootFen: fenAfter(['e4']),
        rootPath: const ['e4']);
    expect(tester.takeException(), isNull);

    await play(tester, 'c7', 'c5');
    expect(tester.takeException(), isNull);
  });

  testWidgets('nothing due in a branch says when it comes back',
      (tester) async {
    // One position, drilled once, scheduled for tomorrow. The screen used to
    // say only that nothing was due, which reads as "this branch cannot be
    // practised" — and that is exactly how it was read the first time.
    final api = _FakeApi()
      ..line = DrillLine(
        reason: 'nothing-due',
        stats: DrillStats(
          positions: 1,
          due: 0,
          known: 0,
          fresh: 0,
          nextDueAt: DateTime.now().add(const Duration(days: 1)),
        ),
      );
    await pump(tester, api, rootFen: smithMorra, fromFen: smithMorra);

    expect(find.text('U ovoj grani ništa nije na redu.'), findsOneWidget);
    expect(find.textContaining('Sledeća se vraća sutra'), findsOneWidget);
    expect(find.text('Vežbaj ipak'), findsOneWidget);
  });

  testWidgets('an empty branch is not offered a practice run', (tester) async {
    // Nothing was ever built there, so there is nothing to run early either.
    final api = _FakeApi()
      ..line = const DrillLine(
        reason: 'nothing-built',
        stats: DrillStats(positions: 0, due: 0, known: 0, fresh: 0),
      );
    await pump(tester, api, rootFen: smithMorra, fromFen: smithMorra);

    expect(find.text('Vežbaj ipak'), findsNothing);
  });

  testWidgets('practising ahead is judged and not written down',
      (tester) async {
    // What makes the button safe to offer. A position run through five times in
    // one evening must not come back in a month on the strength of it.
    final api = _FakeApi()
      ..line = const DrillLine(
        reason: 'nothing-due',
        stats: DrillStats(positions: 1, due: 0, known: 0, fresh: 0),
      )
      ..aheadLine = DrillLine(
        question: const DrillItem(
            fen: smithMorra, fresh: false, repetitions: 2, moves: 1),
        ahead: true,
        stats: const DrillStats(positions: 1, due: 0, known: 0, fresh: 0),
      );
    await pump(tester, api, rootFen: smithMorra, fromFen: smithMorra);

    await tester.tap(find.text('Vežbaj ipak'));
    await tester.pumpAndSettle();
    expect(api.lastAhead, true);
    expect(find.text('Šta igrate crnim?'), findsOneWidget);

    await play(tester, 'b8', 'c6');

    expect(api.lastPractice, true);
    expect(find.textContaining('ocena se ne upisuje'), findsOneWidget);
    // And no promise of a return date, because nothing was stored.
    expect(find.textContaining('Vraća se za'), findsNothing);
  });
}
