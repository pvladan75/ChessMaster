import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/widgets/opening_banner.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// 1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3 — the Smith-Morra accepted, Black to
/// move. The position the whole design conversation was about.
const smithMorra = 'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 0 4';

/// A repertoire service with no server behind it: it remembers what was kept
/// and hands it back, which is all the screen reads.
class _FakeApi extends RepertoireApiService {
  _FakeApi() : super(client: MockClient((_) async => http.Response('{}', 500)));

  final Map<String, List<RepertoireMove>> kept = {};
  final List<Map<String, Object?>> attempts = [];
  String? promoted;

  /// The branches cut, and the ones put back, keyed the way the server keys
  /// them.
  final List<String> cut = [];
  final List<String> restored = [];

  /// A server that refuses the cut. The screen must say so rather than showing
  /// a branch as gone when it is not.
  bool cutFails = false;

  /// The generated moves that were confirmed.
  final List<String> confirmed = [];

  /// What a spine run answers with, and how deep it was asked for.
  SpineResult? spine;
  int? spineDepth;

  /// The stored book, and how many times it was read. Null stands for a server
  /// that did not answer.
  StoredBook? book;
  int bookReads = 0;

  /// What removing a move would strand, and what the sweep was asked to take.
  ({List<String> keys, int drafts, int decisions})? orphans;
  final List<bool> pruned = [];

  /// The opponent's moves added to the preparation from past the covered wave.
  final List<String> prepared = [];
  bool prepareFails = false;

  /// What the walk answers with. Null is the honest default here and stands for
  /// a server that did not answer — which is what the fake's MockClient does,
  /// and the path most of these tests happen to take.
  RepertoireFrontier? walk;
  int frontierCalls = 0;

  String _key(String fen) => fen.split(' ').take(4).join(' ');

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    int? minRating,
    String? gateUci,
    String? breadth,
  }) async {
    frontierCalls += 1;
    return walk;
  }

  @override
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async =>
      kept[_key(fen)] ?? const [];

  @override
  Future<bool> keepMove({
    required String color,
    required String fen,
    required String uci,
    required String san,
    String? verdict,
  }) async {
    final list = kept.putIfAbsent(_key(fen), () => []);
    list.add(RepertoireMove(
      uci: uci,
      san: san,
      // The first move kept in a position is the primary; the server holds this
      // rule for real, and the fake keeps it so the screen is tested against
      // the same shape.
      role: list.isEmpty ? 'primary' : 'alternate',
      verdict: verdict,
    ));
    return true;
  }

  @override
  Future<bool> makePrimary({
    required String color,
    required String fen,
    required String uci,
  }) async {
    promoted = uci;
    final list = kept[_key(fen)] ?? [];
    kept[_key(fen)] = [
      for (final move in list)
        RepertoireMove(
          uci: move.uci,
          san: move.san,
          role: move.uci == uci ? 'primary' : 'alternate',
          verdict: move.verdict,
        ),
    ];
    return true;
  }

  @override
  Future<bool> skipNode({required String color, required String fen}) async {
    if (cutFails) return false;
    cut.add(_key(fen));
    return true;
  }

  @override
  Future<StoredBook?> storedBook({
    required String color,
    required String fen,
    int? minRating,
  }) async {
    bookReads += 1;
    return book;
  }

  @override
  Future<({List<String> keys, int drafts, int decisions})?> orphansOfRemoving({
    required String color,
    required String fen,
    required String uci,
    int? minRating,
  }) async =>
      orphans;

  @override
  Future<int> prune({
    required String color,
    required List<String> keys,
    bool includeDecisions = false,
    int? minRating,
  }) async {
    pruned.add(includeDecisions);
    return keys.length;
  }

  @override
  Future<({SpineResult? result, String? error})> buildSpine({
    required String color,
    required String rootFen,
    int depth = 8,
    int? minRating,
    int? minGames,
  }) async {
    spineDepth = depth;
    final out = spine;
    if (out == null) return (result: null, error: 'Server nije odgovorio.');
    return (result: out, error: null);
  }

  @override
  Future<bool> confirmNode({
    required String color,
    required String fen,
    String? uci,
  }) async {
    confirmed.add(uci ?? '*');
    final list = kept[_key(fen)] ?? [];
    kept[_key(fen)] = [
      for (final move in list)
        RepertoireMove(
          uci: move.uci,
          san: move.san,
          role: move.role,
          verdict: move.verdict,
          source: (uci == null || move.uci == uci) ? 'chosen' : move.source,
        ),
    ];
    return true;
  }

  @override
  Future<bool> prepareReply({
    required String color,
    required String fen,
    required String uci,
    String? san,
  }) async {
    if (prepareFails) return false;
    prepared.add(uci);
    return true;
  }

  @override
  Future<bool> unskipNode({required String color, required String fen}) async {
    restored.add(_key(fen));
    cut.remove(_key(fen));
    return true;
  }

  @override
  Future<void> recordAttempt({
    required String color,
    required String fen,
    required String uci,
    String? san,
    String? verdict,
    bool kept = false,
    bool lookedUp = false,
  }) async {
    attempts.add({
      'fen': _key(fen),
      'uci': uci,
      'san': san,
      'verdict': verdict,
      'kept': kept,
      'lookedUp': lookedUp,
    });
  }
}

/// A judge that answers from a table instead of from Lichess, and counts how
/// many questions the screen asked.
class _FakeJudge implements OpeningJudgeService {
  _FakeJudge({
    this.verdict = OpeningVerdict.theory,
    this.hasToken = true,
  });

  final OpeningVerdict verdict;
  final bool hasToken;

  /// A move White can really play after 4...Nc6. An illegal one would be
  /// dropped by the screen and the wave would come out empty — a fault in the
  /// fake rather than in what is being tested, and one that cost a debugging
  /// round the first time.
  static const replyList = ['g1f3'];

  int judged = 0;
  int asked = 0;

  @override
  bool get hasPersonalToken => hasToken;

  @override
  Future<OpeningJudgeLookup> judge(String fen, String move,
      {int? minRating}) async {
    judged += 1;
    if (!hasToken) return const OpeningJudgeLookup.unavailable('no-token');
    final board = chess.Chess.fromFEN(fen);
    board.move({'from': move.substring(0, 2), 'to': move.substring(2, 4)});
    return OpeningJudgeLookup.ok(OpeningJudgement(
      verdict: verdict,
      fen: fen,
      san: board.getHistory().last.toString(),
      uci: move,
      moverIsWhite: false,
      mastersGames: 900,
      mastersTotal: 4000,
      bandGames: 40,
      bandTotal: 500,
    ));
  }

  @override
  Future<OpponentRepliesLookup> replies(String fen, {int? minRating}) async {
    asked += 1;
    if (!hasToken) return const OpponentRepliesLookup.unavailable('no-token');
    // Whose book this is. Asked about the position on the board it is Black's
    // moves; asked about the position after Black has moved it is White's — and
    // the fake has to keep that straight, because the screen plays these moves
    // on that board. It did not, once, and the tail row offered a black move in
    // a white-to-move position.
    final whiteToMove = fen.split(' ').length > 1 && fen.split(' ')[1] == 'w';
    return OpponentRepliesLookup.ok(OpponentReplies(
      total: 1000,
      replies: [
        for (final uci in replyList)
          OpponentReply(uci: uci, san: uci, games: 500, share: 0.5),
      ],
      // What the student reads when choosing: more than the covered few, with
      // how those games went.
      all: whiteToMove
          ? const [
              OpponentReply(
                  uci: 'g1f3',
                  san: 'g1f3',
                  games: 500,
                  share: 0.5,
                  white: 250,
                  draws: 100,
                  black: 150,
                  covered: true),
              // The tail: legal in this position, uncovered, and the thing
              // "Spremi" is for. Legal matters — in the Smith-Morra accepted
              // White has no d-pawn, and a tail move that cannot be played
              // would silently never join the queue.
              OpponentReply(uci: 'f1c4', san: 'Bc4', games: 90, share: 0.09),
              OpponentReply(uci: 'c1f4', san: 'Bf4', games: 60, share: 0.06),
            ]
          : const [
              OpponentReply(
                  uci: 'b8c6',
                  san: 'Nc6',
                  games: 600,
                  share: 0.6,
                  white: 200,
                  draws: 100,
                  black: 300,
                  covered: true),
              OpponentReply(
                  uci: 'd7d6',
                  san: 'd6',
                  games: 300,
                  share: 0.3,
                  white: 150,
                  draws: 60,
                  black: 90,
                  covered: true),
              OpponentReply(
                  uci: 'a7a6',
                  san: 'a6',
                  games: 100,
                  share: 0.1,
                  white: 60,
                  draws: 10,
                  black: 30),
            ],
      coveredShare: 0.85,
      tailMoves: 3,
      tailShare: 0.15,
    ));
  }

  @override
  void clearCache() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The depth and line-count dials write to the app's settings, which are
  // SharedPreferences underneath.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _FakeApi api;
  late _FakeJudge judge;
  ({int depth, int multiPV})? engineAsked;

  Future<void> pump(
    WidgetTester tester, {
    OpeningVerdict verdict = OpeningVerdict.theory,
    bool hasToken = true,
    Size size = const Size(500, 1000),
    List<String> rootPath = const [],
    RepertoireFrontier? walk,
    bool cutFails = false,
    bool prepareFails = false,
    StoredBook? book,

    /// Moves already in the repertoire, keyed the way the server keys them.
    /// Stands for a position the student built in an earlier session.
    Map<String, List<RepertoireMove>> seed = const {},
    Future<List<AnalysisLine>> Function(String fen, int depth, int multiPV)?
        analyse,
    OpeningBookEntry? Function(String fen)? openingLookup,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    api = _FakeApi()
      ..walk = walk
      ..cutFails = cutFails
      ..prepareFails = prepareFails
      ..book = book
      ..kept.addAll(seed);
    judge = _FakeJudge(verdict: verdict, hasToken: hasToken);
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'Smit-Mora, crni',
        color: 'b',
        rootFen: smithMorra,
        rootPath: rootPath,
        api: api,
        judge: judge,
        openingLookup: openingLookup,
        // No engine binary in a test, and no ten-second wait for one.
        analyse: analyse ??
            (fen, depth, multiPV) async {
              engineAsked = (depth: depth, multiPV: multiPV);
              return [
                for (var i = 0; i < multiPV; i++)
                  AnalysisLine(
                    multipv: i + 1,
                    depth: depth,
                    evaluation: i == 0 ? '+0.20' : '+0.10',
                    bestMoveLan: i == 0 ? 'b8c6' : 'd7d6',
                    bestMoveSan: i == 0 ? 'Nc6' : 'd6',
                    continuationLan: '',
                    continuationSan: i == 0 ? 'Nc6 Nf3' : 'd6 Bc4',
                    sanMoveList: const [],
                    fenList: const [],
                    fromSquare: i == 0 ? 'b8' : 'd7',
                    toSquare: i == 0 ? 'c6' : 'd6',
                  ),
              ];
            },
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Plays a move on the board by tapping the two squares.
  Offset squareAt(WidgetTester tester, String name) {
    final finder = find.byType(ChessBoardWithOverlay);
    final widget = tester.widget<ChessBoardWithOverlay>(finder);
    final rect = tester.getRect(finder);
    final size = widget.boardSize / 8;
    final file = name.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = name.codeUnitAt(1) - '1'.codeUnitAt(0);
    final col = widget.boardOrientation == PlayerColor.black ? 7 - file : file;
    final row = widget.boardOrientation == PlayerColor.black ? rank : 7 - rank;
    return rect.topLeft + Offset((col + 0.5) * size, (row + 0.5) * size);
  }

  Future<void> play(WidgetTester tester, String from, String to) async {
    await tester.tapAt(squareAt(tester, from));
    await tester.pumpAndSettle();
    await tester.tapAt(squareAt(tester, to));
    await tester.pumpAndSettle();
  }

  testWidgets('the screen asks for the student\'s own move', (tester) async {
    await pump(tester);

    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    // Built for Black, so the board is turned that way — the student sees what
    // they would see over the board.
    expect(
      tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
          .boardOrientation,
      PlayerColor.black,
    );
  });

  testWidgets('a move is judged as soon as it is played', (tester) async {
    await pump(tester);

    await play(tester, 'b8', 'c6');

    expect(judge.judged, 1, reason: 'suđenje je poenta ovog režima');
    expect(find.text('Nc6 · Glavna teorija'), findsOneWidget);
    expect(find.text('Uzmi Nc6'), findsOneWidget);
    // One: the verdict, and nothing else. A second book used to be fetched the
    // moment a move was played — a request per move, for a list that has been
    // on screen since the position opened. Their allowance, so the count is on
    // screen rather than guessed at.
    expect(find.textContaining('upita: 1'), findsOneWidget);
  });

  testWidgets('playing a move fetches no second list', (tester) async {
    // There used to be one: the moment a move was played, the judge was asked
    // for the whole book so the reader could see how those games ended. It cost
    // a Lichess request per move against a token that serves every child using
    // this app, and it printed a second panel under the one that had been on
    // screen since the position opened. What it carried that the stored list
    // cannot — how the games *ended* — is worth having, and is worth having as
    // a column fetched once for everybody rather than a request per move.
    await pump(
      tester,
      book: const StoredBook(
        fen: 'x',
        opened: true,
        replies: [
          StoredReply(
              uci: 'b8c6', san: 'Nc6', games: 900, share: 0.6, covered: true),
        ],
      ),
    );

    expect(find.text('Šta se ovde igra'), findsOneWidget);
    await play(tester, 'b8', 'c6');

    // Still one panel, and only the verdict was paid for.
    expect(find.text('Šta se ovde igra'), findsOneWidget);
    expect(judge.asked, 0);
    expect(find.textContaining('upita: 1'), findsOneWidget);
  });

  testWidgets('a move already kept is not offered for keeping again',
      (tester) async {
    // The owner played his own second move on the board and was asked whether
    // to accept it — a move that was already in the repertoire. Playing a kept
    // move is the same act as picking it in the tree: go and look at what comes
    // after it.
    await pump(
      tester,
      seed: {
        smithMorra.split(' ').take(4).join(' '): const [
          RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
        ],
      },
      book: const StoredBook(fen: 'x', opened: true, replies: []),
    );

    await play(tester, 'b8', 'c6');

    expect(find.text('Uzmi Nc6'), findsNothing);
    expect(judge.judged, 0, reason: 'odluka koja postoji se ne sudi ponovo');
    // Standing after it, looking at what comes back.
    expect(find.text('Nazad na Nc6'), findsOneWidget);
  });

  testWidgets('a kept move is stored, and the first one is the primary',
      (tester) async {
    await pump(tester);

    await play(tester, 'b8', 'c6');
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();

    final stored = api.kept.values.single;
    expect(stored.single.san, 'Nc6');
    expect(stored.single.role, 'primary');
    expect(stored.single.verdict, 'theory');
    // And the chip for it is on the screen, with the star that says which one
    // the drill will ask for.
    expect(find.text('Nc6'), findsWidgets);
  });

  testWidgets('the main move can be chosen, and the screen says how',
      (tester) async {
    // The choice was always here — tapping a chip promoted it — but nothing
    // said so, and a control nobody can see is a control that does not exist.
    await pump(tester);

    await play(tester, 'b8', 'c6');
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();

    expect(find.text('Vaši potezi ovde'), findsOneWidget);
    expect(find.textContaining('Zvezdica je glavni potez'), findsOneWidget);
    expect(find.text('glavni'), findsOneWidget);

    await play(tester, 'd7', 'd6');
    await tester.tap(find.text('Uzmi d6'));
    await tester.pumpAndSettle();

    expect(find.text('dodirnite za glavni'), findsOneWidget);
    await tester.tap(find.text('dodirnite za glavni'));
    await tester.pumpAndSettle();

    expect(api.promoted, 'd7d6');
  });

  testWidgets('the engine answers on request, at the depth that was set',
      (tester) async {
    // The local engine, so this costs no Lichess allowance — and it is asked
    // by hand, because a screen that keeps an engine running is warming a phone
    // to answer a question nobody put yet.
    engineAsked = null;
    await pump(tester);

    expect(find.text('Motor'), findsNothing);

    await tester.tap(find.text('Pitaj motor'));
    await tester.pumpAndSettle();

    expect(find.text('Motor'), findsOneWidget);
    expect(engineAsked, isNotNull);
    expect(find.text('+0.20'), findsOneWidget);
    expect(find.textContaining('ne troši Lichess kvotu'), findsOneWidget);
  });

  testWidgets('the engine line can be played, and is judged like any move',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Pitaj motor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nc6'));
    await tester.pumpAndSettle();

    // A suggestion is not a decision: it goes through the same verdict and the
    // same keep-or-discard as a move played by hand.
    expect(judge.judged, 1);
    expect(find.text('Uzmi Nc6'), findsOneWidget);
  });

  testWidgets(
      'an engine answer for the old position never lands on the new one',
      (tester) async {
    // Reported from the desktop build, with a screenshot: the engine offered
    // `Bxb2` in a position with no capture on b2, because that move had been
    // legal one position earlier. A deep search takes seconds, the reader walks
    // on while it runs, and the answer arrives for a board nobody is looking at.
    final gate = Completer<List<AnalysisLine>>();
    await pump(tester, analyse: (fen, depth, multiPV) => gate.future);

    await tester.tap(find.text('Pitaj motor'));
    await tester.pump();
    expect(find.text('Motor'), findsOneWidget, reason: 'razmišlja');

    // Plain pumps from here: the panel draws a spinner while the engine is
    // thinking, and pumpAndSettle waits on a spinner forever. So each step
    // pumps until the thing it is waiting for is actually on screen.
    Future<void> until(Finder finder) async {
      for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(finder, findsWidgets);
    }

    // On to the next position while the engine is still thinking.
    await tester.tapAt(squareAt(tester, 'b8'));
    await tester.pump();
    await tester.tapAt(squareAt(tester, 'c6'));
    await until(find.text('Uzmi Nc6'));

    // The engine panel pushes the buttons below the fold, and a tap that lands
    // on nothing is a tap that proves nothing.
    Future<void> press(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 20));
    }

    await press(find.text('Uzmi Nc6'));
    await until(find.text('Vaši potezi ovde'));
    await press(find.text('Dalje'));
    await until(find.textContaining('Pokriveno'));

    // Only now does the engine answer — about the board that was left behind.
    gate.complete([
      AnalysisLine(
        multipv: 1,
        depth: 28,
        evaluation: '-0.03',
        bestMoveLan: 'c1b2',
        bestMoveSan: 'Bxb2',
        continuationLan: '',
        continuationSan: 'Bxb2 Bb4+',
        sanMoveList: const [],
        fenList: const [],
        fromSquare: 'c1',
        toSquare: 'b2',
      ),
    ]);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(find.text('Bxb2'), findsNothing,
        reason: 'odgovor pripada poziciji za koju je tražen, ne ovoj');
    expect(find.text('-0.03'), findsNothing);
  });

  testWidgets('changing the depth asks again instead of looking stopped',
      (tester) async {
    // Also reported: after moving the depth the engine "stopped working". It
    // had not — nothing re-ran, so the old answer stayed on screen under a new
    // number, which is the same thing from the reader's chair.
    var calls = 0;
    final depths = <int>[];
    await pump(tester, analyse: (fen, depth, multiPV) async {
      calls += 1;
      depths.add(depth);
      return const <AnalysisLine>[];
    });

    await tester.tap(find.text('Pitaj motor'));
    await tester.pumpAndSettle();
    expect(calls, 1);

    await tester.tap(find.text('${depths.first}').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('24').last);
    await tester.pumpAndSettle();

    expect(calls, 2, reason: 'promena dubine je novo pitanje');
    expect(depths.last, 24);
  });

  testWidgets('a discarded move is written down too', (tester) async {
    // The whole reason the attempts table exists: this is where the first
    // instinct was wrong, and it is what the drill should ask about first.
    await pump(tester, verdict: OpeningVerdict.mistake);

    await play(tester, 'd8', 'a5');
    await tester.tap(find.text('Odbaci'));
    await tester.pumpAndSettle();

    final attempt = api.attempts.single;
    expect(attempt['san'], 'Qa5');
    expect(attempt['verdict'], 'mistake');
    expect(attempt['kept'], false);
    expect(api.kept, isEmpty, reason: 'odbijen potez ne ulazi u repertoar');
  });

  testWidgets('the statistics stand there without being asked for',
      (tester) async {
    // The loop stopped being a quiz. A repertoire is built from the statistics,
    // the evaluation and the builder's own will, so the book is not behind an
    // admission that they do not know — and it costs nothing, because it is
    // read from what somebody's session already paid for.
    await pump(
      tester,
      book: const StoredBook(
        fen: 'x',
        opened: true,
        replies: [
          StoredReply(
              uci: 'b8c6', san: 'Nc6', games: 900, share: 0.6, covered: true),
        ],
      ),
    );

    expect(find.text('Šta se ovde igra'), findsOneWidget);
    expect(find.text('Ne znam'), findsNothing);
    expect(judge.asked, 0, reason: 'lista koja se sama pojavi ne sme da košta');

    await play(tester, 'b8', 'c6');
    // Scrolled to first: the list adds a panel above the controls, so the
    // button that was on screen before it is now below the fold.
    await tester.ensureVisible(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();

    // And nothing is written down as a confession any more: with the list on
    // screen from the start, "answered by looking" cannot be told from
    // "answered by thinking", so claiming to know the difference would be a
    // number that means nothing.
    expect(api.attempts.single['lookedUp'], false);
  });

  testWidgets('a move can be played straight out of the statistics',
      (tester) async {
    // Choosing from the list is building, not a shortcut past anything: it goes
    // through the same judging and the same decision as a move dragged on the
    // board.
    await pump(
      tester,
      book: const StoredBook(
        fen: 'x',
        opened: true,
        replies: [
          StoredReply(
              uci: 'b8c6', san: 'Nc6', games: 900, share: 0.6, covered: true),
        ],
      ),
    );

    await tester.ensureVisible(find.text('Igraj').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Igraj').first);
    await tester.pumpAndSettle();

    expect(find.text('Uzmi Nc6'), findsOneWidget);
    await tester.ensureVisible(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();
    expect(api.kept.values.single.single.san, 'Nc6');
  });

  testWidgets('going on opens the opponent\'s replies and says what is covered',
      (tester) async {
    await pump(tester);

    await play(tester, 'b8', 'c6');
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dalje'));
    await tester.pumpAndSettle();

    // Two book lookups: this position's, which came with the verdict, and the
    // one after the kept move, which is the next wave.
    expect(judge.asked, 1);
    expect(find.textContaining('Pokriveno 85%'), findsOneWidget);
    expect(find.textContaining('van toga još 3'), findsOneWidget);

    // A stop, not a step. These answers cost a request and they decide what the
    // whole next wave looks like; they used to be counted and thrown away
    // without ever being shown to the person who paid for them.
    expect(find.text('Odgovori protivnika'), findsOneWidget);
    expect(find.textContaining('Posle Nc6'), findsOneWidget);

    await tester.tap(find.text('Sledeća pozicija'));
    await tester.pumpAndSettle();

    // And now the board has moved on to a position where it is Black to move.
    expect(find.text('Šta igrate crnim?'), findsOneWidget);
  });

  /// The arrows currently on the board.
  List<EngineArrow> arrows(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
      .engineArrows;

  testWidgets(
      'the opponent\'s answers are drawn on the board, with how often '
      'each is played', (tester) async {
    await pump(tester);

    await play(tester, 'b8', 'c6');
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalje'));
    await tester.pumpAndSettle();

    final drawn = arrows(tester);
    expect(drawn.length, 1);
    expect(drawn.single.from, 'g1');
    expect(drawn.single.to, 'f3');
    // Share, not the result percentage. Share is what decides whether a move
    // has to be prepared for; putting "how those games went" on an arrow
    // invites picking the biggest number, which is the wrong lesson.
    expect(drawn.single.evalText, '50%');

    // The line on screen includes the student's own move, because the board is
    // standing one move further on than the position they were asked about.
    expect(find.textContaining('Nc6'), findsWidgets);
  });

  testWidgets('the moves already chosen are drawn, and the main one is starred',
      (tester) async {
    await pump(tester);

    await play(tester, 'b8', 'c6');
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();

    final first = arrows(tester);
    expect(first.length, 1);
    expect(first.single.from, 'b8');
    expect(first.single.to, 'c6');
    // The star, not a colour. Which move is the main one must never rest on
    // hue alone — rank already carries stroke width, and this is a third
    // channel again. No share beside it here: this fake serves no stored book,
    // and an arrow is never worth a request of its own.
    expect(first.single.evalText, '★');
    expect(first.single.rank, 1);

    // A second move kept here is an alternate: thinner, unstarred, and still
    // carrying its own share.
    await play(tester, 'd7', 'd6');
    await tester.tap(find.text('Uzmi d6'));
    await tester.pumpAndSettle();

    final both = arrows(tester);
    expect(both.length, 2);
    expect(both.first.evalText, '★', reason: 'glavni ostaje glavni');
    expect(both.last.to, 'd6');
    expect(both.last.evalText, '');
    expect(both.last.rank, 2);
  });

  testWidgets('a kept move without an open book is still drawn, with its star',
      (tester) async {
    // The resumed case: a position comes back with a move already in it and no
    // book behind it. An arrow is not worth a Lichess request nobody asked for,
    // and the star says the thing that matters without one.
    await pump(tester, seed: {
      smithMorra.split(' ').take(4).join(' '): const [
        RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
      ],
    });

    final drawn = arrows(tester);
    expect(drawn.length, 1);
    expect(drawn.single.evalText, '★');
  });

  testWidgets('nothing can be played onto the board while the answers are up',
      (tester) async {
    await pump(tester);

    await play(tester, 'b8', 'c6');
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalje'));
    await tester.pumpAndSettle();

    // The board is showing a position it is White's turn in. A move dragged
    // there would be judged as the student's own, in a position that is not the
    // one they were asked about.
    expect(
      tester
          .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
          .isAllowedToMove,
      isFalse,
    );
  });

  testWidgets('nothing is asked for until a move has been kept',
      (tester) async {
    await pump(tester);

    final dalje = find.widgetWithText(FilledButton, 'Dalje');
    expect(tester.widget<FilledButton>(dalje).onPressed, isNull,
        reason: 'nema šta da se otvori dok pozicija nema nijedan odgovor');
  });

  testWidgets('without a token the screen says so instead of judging',
      (tester) async {
    await pump(tester, hasToken: false);

    await play(tester, 'b8', 'c6');

    expect(find.textContaining('traži vaš Lichess token'), findsOneWidget);
    expect(find.text('Uzmi Nc6'), findsOneWidget,
        reason: 'izbor je i dalje korisnikov — sud je pomoć, ne dozvola');
  });

  testWidgets('the loop fits a 360 dp phone', (tester) async {
    // A release build paints no overflow stripes; in a test build it throws.
    await pump(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);

    await play(tester, 'b8', 'c6');
    expect(tester.takeException(), isNull);

    // And so does the answers view, which is where the long sentences are: a
    // paragraph about what the numbers mean, a row per reply, and a warning
    // about the tail.
    //
    // Scrolled to rather than tapped blind. On a 640 px screen the controls sit
    // below the board and are genuinely off screen — which is a fact about the
    // layout worth knowing, not something to work around by widening the test.
    await tester.ensureVisible(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Dalje'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalje'));
    await tester.pumpAndSettle();
    expect(find.text('Odgovori protivnika'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  /// The position after a line of SAN moves. Computed rather than pasted: a
  /// hand-written FEN is a chance to assert against a board that does not
  /// exist, and the screen would then be right while the test was wrong.
  String fenAfter(String from, List<String> sans) {
    final board = chess.Chess.fromFEN(from);
    for (final san in sans) {
      board.move(san);
    }
    return board.fen;
  }

  testWidgets('the screen says which line the board belongs to',
      (tester) async {
    // The moves that led to the repertoire's own root, so the line reads from
    // move one. Without them a Smith-Morra repertoire would open on `4...` and
    // name nothing before it — which is the confusion this screen was built
    // with: a position, no history, and a count of an invisible list.
    await pump(tester, rootPath: const [
      'e4',
      'c5',
      'd4',
      'cxd4',
      'c3',
      'dxc3',
      'Nxc3',
    ]);

    expect(find.text('1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3'), findsOneWidget);
  });

  testWidgets('without a stored root path the line is numbered from the board',
      (tester) async {
    // A repertoire built from a pasted position has no opening to tell, so the
    // numbering comes from the FEN — Black to move, move four. Guessing move
    // one instead would put moves on screen that nobody played.
    await pump(tester,
        walk: RepertoireFrontier(
          decided: 1,
          open: [
            FrontierNode(
              fen: fenAfter(smithMorra, ['Nc6', 'Nf3']),
              path: const ['Nc6', 'Nf3'],
              reach: 0.4,
              kind: 'undecided',
            ),
          ],
        ));

    expect(find.text('4...Nc6 5.Nf3'), findsOneWidget);
  });

  testWidgets('a walk is picked up where it stopped, not at the root',
      (tester) async {
    // The queue is not stored anywhere: the server rebuilds it from the moves
    // already kept and the books already fetched. Closing the screen used to
    // throw the walk away and start again at the root, re-spending the Lichess
    // allowance on replies that had already been paid for.
    await pump(tester,
        rootPath: const ['e4', 'c5', 'd4', 'cxd4', 'c3', 'dxc3', 'Nxc3'],
        walk: RepertoireFrontier(
          decided: 3,
          openReach: 0.55,
          open: [
            FrontierNode(
              fen: fenAfter(smithMorra, ['Nc6', 'Nf3']),
              path: const ['Nc6', 'Nf3'],
              reach: 0.4,
              kind: 'undecided',
            ),
            FrontierNode(
              fen: fenAfter(smithMorra, ['d6', 'Bc4']),
              path: const ['d6', 'Bc4'],
              reach: 0.15,
              kind: 'undecided',
            ),
          ],
        ));

    expect(api.frontierCalls, 1);
    // Most-reached first: the screen opens on the line the student will meet
    // most often, and the other one is waiting behind it.
    expect(find.text('1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3 Nc6 5.Nf3'),
        findsOneWidget);
    expect(find.text('Posle ove u redu je još 1 pozicija.'), findsOneWidget);
    expect(find.textContaining('bez odgovora 55%'), findsOneWidget);
  });

  testWidgets('a line that was decided and then left says what it needs',
      (tester) async {
    await pump(tester,
        walk: RepertoireFrontier(
          decided: 2,
          unopened: 1,
          open: [
            FrontierNode(
              fen: fenAfter(smithMorra, ['Nc6', 'Nf3']),
              path: const ['Nc6', 'Nf3'],
              reach: 0.4,
              kind: 'unopened',
            ),
          ],
        ));

    // Coming back to a position that already has a move in it reads as a
    // mistake unless the screen says why it is here.
    expect(find.textContaining('ostalo je samo da uzmete odgovore'),
        findsOneWidget);
  });

  testWidgets(
      'a walk that could not be read falls back to the root, and says so',
      (tester) async {
    // "We could not find out where you were" must never be shown as "there is
    // nothing left to do". The root is a real question, so the screen works;
    // the sentence is there so nobody reads a restart as progress.
    await pump(tester);

    expect(api.frontierCalls, 1);
    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    expect(
        find.textContaining('počinjete od početne pozicije'), findsOneWidget);
  });

  testWidgets('a line opened deep goes in front of a shallow one queued first',
      (tester) async {
    // The order is `reach` and nothing else — how often a game actually
    // arrives at a position. New positions used to be appended, so the main
    // line opened halfway through a session waited behind every sideline
    // enqueued before it, and the same walk resumed tomorrow came back in the
    // server's order instead. Two orders for one walk is the worse half: what
    // gets learned is the shape of a session, not the shape of the tree.
    await pump(tester,
        walk: RepertoireFrontier(
          open: [
            FrontierNode(
              fen: smithMorra,
              path: const [],
              reach: 1,
              kind: 'undecided',
            ),
            FrontierNode(
              fen: fenAfter(smithMorra, ['d6', 'Bc4']),
              path: const ['d6', 'Bc4'],
              reach: 0.2,
              kind: 'undecided',
            ),
          ],
        ));

    await play(tester, 'b8', 'c6');
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalje'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sledeća pozicija'));
    await tester.pumpAndSettle();

    // 5.Nf3 is played in half the games from a position reached in all of
    // them: 0.50, against the sideline's 0.20. It was queued second and it is
    // asked first. (The fake book names its moves in UCI, which is why the
    // line reads `5.g1f3`.)
    expect(find.text('4...Nc6 5.g1f3'), findsOneWidget);
    expect(find.text('Posle ove u redu je još 1 pozicija.'), findsOneWidget);
  });

  testWidgets('a cut branch takes everything under it out of the queue',
      (tester) async {
    // The one control in this loop that makes the tree smaller. If what is
    // under the cut stayed in the queue, the tree would be exactly as big as
    // before — which is how a control teaches people not to press it.
    await pump(tester,
        // On a phone, because this adds a fifth button to a row of Serbian
        // labels and a release build clips an overflow without drawing a
        // stripe. In a test build it throws, which is the point of the size.
        size: const Size(360, 640),
        walk: RepertoireFrontier(
          open: [
            FrontierNode(
              fen: fenAfter(smithMorra, ['Nc6', 'Nf3']),
              path: const ['Nc6', 'Nf3'],
              reach: 0.6,
              kind: 'undecided',
            ),
            FrontierNode(
              fen: fenAfter(smithMorra, ['Nc6', 'Nf3', 'e6', 'Bc4']),
              path: const ['Nc6', 'Nf3', 'e6', 'Bc4'],
              reach: 0.3,
              kind: 'undecided',
            ),
            FrontierNode(
              fen: fenAfter(smithMorra, ['d6', 'Bc4']),
              path: const ['d6', 'Bc4'],
              reach: 0.2,
              kind: 'undecided',
            ),
          ],
        ));

    expect(find.text('Posle ove u redu su još 2 pozicije.'), findsOneWidget);
    // Scrolled to rather than tapped blind: on a 640 px screen the controls sit
    // below the board and are genuinely off screen.
    await tester.ensureVisible(find.text('Ne spremam ovo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ne spremam ovo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(api.cut.single,
        fenAfter(smithMorra, ['Nc6', 'Nf3']).split(' ').take(4).join(' '));
    // The line below it went with it; the unrelated one did not. „Izašla",
    // feminine singular, because one position agrees with its verb — the three
    // forms went through `serbianCount` on 3.9.2026, and this assertion is
    // what noticed.
    expect(
        find.textContaining('iz reda izašla još 1 pozicija'), findsOneWidget);
    expect(
        find.text(
            'Poslednja neodgovorena pozicija koju ovaj repertoar dohvata.'),
        findsOneWidget);
    expect(find.textContaining('4...d6 5.Bc4'), findsOneWidget);
    // Counted apart from "bez odgovora", and never taken off it: cutting is
    // work refused, not work done, and those games are still going to be
    // played.
    expect(find.textContaining('odsečeno 1 (60%)'), findsOneWidget);
  });

  testWidgets('a cut branch can be put back', (tester) async {
    // Cutting has to be as cheap to undo as to do. A prune nobody can reverse
    // is not a decision, it is a risk, and people do not take it.
    await pump(tester,
        walk: RepertoireFrontier(
          open: [
            FrontierNode(
              fen: fenAfter(smithMorra, ['Nc6', 'Nf3']),
              path: const ['Nc6', 'Nf3'],
              reach: 0.6,
              kind: 'undecided',
            ),
            FrontierNode(
              fen: fenAfter(smithMorra, ['d6', 'Bc4']),
              path: const ['d6', 'Bc4'],
              reach: 0.2,
              kind: 'undecided',
            ),
          ],
        ));

    await tester.tap(find.text('Ne spremam ovo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vrati odsečenu granu'));
    await tester.pumpAndSettle();

    expect(api.restored.single,
        fenAfter(smithMorra, ['Nc6', 'Nf3']).split(' ').take(4).join(' '));
    expect(find.textContaining('Grana je vraćena'), findsOneWidget);
    // Back in the queue, in its own place — not shoved in front of the
    // position the student is in the middle of answering.
    expect(find.text('Posle ove u redu je još 1 pozicija.'), findsOneWidget);
    expect(find.textContaining('odsečeno'), findsNothing);
  });

  testWidgets('the repertoire root is never offered as a branch to cut',
      (tester) async {
    // Cutting the root is not pruning, it is deleting the repertoire from
    // inside the screen that builds it — and it is the one cut that leaves no
    // way back in.
    await pump(tester);

    expect(find.text('Šta igrate crnim?'), findsOneWidget);
    expect(find.text('Ne spremam ovo'), findsNothing);
  });

  testWidgets('a cut the server refused is not shown as done', (tester) async {
    // The oldest bug in this codebase, in its usual shape: a step that fails
    // quietly and reports success. A branch that looks gone and comes back
    // tomorrow is worse than one that was never cut.
    await pump(tester,
        cutFails: true,
        walk: RepertoireFrontier(
          open: [
            FrontierNode(
              fen: fenAfter(smithMorra, ['Nc6', 'Nf3']),
              path: const ['Nc6', 'Nf3'],
              reach: 0.6,
              kind: 'undecided',
            ),
          ],
        ));

    await tester.tap(find.text('Ne spremam ovo'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Grana nije odsečena'), findsOneWidget);
    expect(find.textContaining('odsečeno'), findsNothing);
    // Still the position that was there: nothing moved on.
    expect(find.text('4...Nc6 5.Nf3'), findsOneWidget);
  });

  testWidgets('a move past the covered wave can be prepared by hand',
      (tester) async {
    // The wall. The wave covers 80% of what is played, up to four moves, and
    // names the remainder — which was countable and unreachable: twenty-eight
    // moves carrying a sixth of the games, and no way to say "that one too".
    await pump(tester);

    await play(tester, 'b8', 'c6');
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalje'));
    await tester.pumpAndSettle();

    // Folded away by default: ten moves at one per cent each under every
    // position would bury the answers that decide the next wave.
    expect(find.text('Bc4'), findsNothing);
    await tester.tap(find.text('Spremi i neki od njih'));
    await tester.pumpAndSettle();

    expect(find.text('Bc4'), findsOneWidget);
    await tester.tap(find.text('Spremi').first);
    await tester.pumpAndSettle();

    // Written down on the server, not only queued here: the frontier follows
    // covered replies only, so a hand-picked one that was not stored would be
    // lost the moment the screen closed.
    expect(api.prepared, ['f1c4']);
    expect(find.textContaining('U pripremi je i Bc4'), findsOneWidget);
    expect(find.text('u pripremi'), findsOneWidget);
  });

  testWidgets('a prepared move joins the queue in its own place',
      (tester) async {
    // Choosing it deliberately says it must be prepared, not that it has
    // suddenly become common. It waits behind the lines that are.
    await pump(tester);

    await play(tester, 'b8', 'c6');
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalje'));
    await tester.pumpAndSettle();
    // One position came out of the covered wave.
    expect(find.text('Posle ove u redu je još 1 pozicija.'), findsOneWidget);

    await tester.tap(find.text('Spremi i neki od njih'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spremi').first);
    await tester.pumpAndSettle();

    expect(find.text('Posle ove u redu su još 2 pozicije.'), findsOneWidget);
  });

  testWidgets('a preparation the server refused is not shown as done',
      (tester) async {
    // The oldest shape of bug here: a step that fails quietly and reports
    // success. A move that looks prepared and is gone tomorrow is worse than
    // one that was never offered.
    await pump(tester, prepareFails: true);

    await play(tester, 'b8', 'c6');
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dalje'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spremi i neki od njih'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spremi').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('nije dodat u pripremu'), findsOneWidget);
    expect(find.text('u pripremi'), findsNothing);
    expect(find.text('Posle ove u redu je još 1 pozicija.'), findsOneWidget);
  });

  testWidgets('a generated move is marked as a draft and can be confirmed',
      (tester) async {
    // The act the whole draft idea rests on. Until somebody says yes, a move
    // nobody chose is scaffolding — drawn and walked through, never drilled.
    // The archive seed had no such act, which is exactly why it was deleted.
    await pump(tester, seed: {
      smithMorra.split(' ').take(4).join(' '): const [
        RepertoireMove(
            uci: 'b8c6', san: 'Nc6', role: 'primary', source: 'auto'),
      ],
    });

    expect(find.textContaining('nije još vaš izbor'), findsOneWidget);
    await tester.tap(find.text('Potvrdi'));
    await tester.pumpAndSettle();

    expect(api.confirmed, ['b8c6']);
    expect(find.textContaining('nije još vaš izbor'), findsNothing);
    expect(find.text('glavni'), findsOneWidget);
  });

  testWidgets('a move the student chose is not offered for confirmation',
      (tester) async {
    await pump(tester, seed: {
      smithMorra.split(' ').take(4).join(' '): const [
        RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
      ],
    });

    expect(find.text('Potvrdi'), findsNothing);
    expect(find.text('glavni'), findsOneWidget);
  });

  testWidgets('the spine writes a trunk and says it is only a draft',
      (tester) async {
    // The answer to "thirty questions before it looks like an opening". What it
    // writes must never read as something the student decided.
    await pump(tester);
    api.spine = const SpineResult(
      written: 2,
      path: ['Nc6', 'Nf3', 'e6', 'd4'],
    );

    await tester.tap(find.text('Napravi kičmu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 poteza'));
    await tester.pumpAndSettle();

    expect(api.spineDepth, 6);
    expect(find.textContaining('Upisano 2 predloga'), findsOneWidget);
    expect(
        find.textContaining('Potvrdite ono sa čim se slažete'), findsOneWidget);
  });

  testWidgets('a spine that stopped early says where and why', (tester) async {
    // Top-1 at ply twenty is sometimes forty games. A spine that came back
    // short without a word would be every silent truncation this codebase has
    // had to fix.
    await pump(tester);
    api.spine = const SpineResult(
      written: 1,
      path: ['Nc6', 'Nf3'],
      reason: 'thin',
      games: 40,
      minGames: 100,
    );

    await tester.tap(find.text('Napravi kičmu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4 poteza'));
    await tester.pumpAndSettle();

    expect(find.textContaining('stalo jer je dalje pretanko'), findsOneWidget);
    expect(find.textContaining('40 partija'), findsOneWidget);
  });

  testWidgets('a spine that wrote nothing does not claim a line',
      (tester) async {
    await pump(tester);
    api.spine = const SpineResult(reason: 'thin', minGames: 100);

    await tester.tap(find.text('Napravi kičmu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4 poteza'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Ništa nije upisano'), findsOneWidget);
  });

  testWidgets('a spine the server refused says so', (tester) async {
    await pump(tester);
    // `spine` left null: the fake answers the way a server that did not reply
    // does.
    await tester.tap(find.text('Napravi kičmu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('4 poteza'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Server nije odgovorio'), findsOneWidget);
    expect(find.textContaining('Upisano'), findsNothing);
  });

  testWidgets('removing a move sweeps the drafts it stranded, silently',
      (tester) async {
    // Drafts go without a word; there is nothing to ask about a move nobody
    // chose.
    await pump(tester, seed: {
      smithMorra.split(' ').take(4).join(' '): const [
        RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
      ],
    });
    api.orphans = (keys: ['k1', 'k2'], drafts: 2, decisions: 0);

    await tester.tap(find.byTooltip('Ukloni'));
    await tester.pumpAndSettle();

    // One sweep, and it was not allowed to touch decisions.
    expect(api.pruned, [false]);
    expect(find.textContaining('Uklonjeno i 2 poteza'), findsOneWidget);
  });

  testWidgets('a decision that would be stranded is asked about, not taken',
      (tester) async {
    // Losing an evening's work to a changed second move, with no sentence about
    // it, is the kind of thing that happens once and ends trust in a feature.
    await pump(tester, seed: {
      smithMorra.split(' ').take(4).join(' '): const [
        RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
      ],
    });
    api.orphans = (keys: ['k1'], drafts: 0, decisions: 3);

    await tester.tap(find.byTooltip('Ukloni'));
    await tester.pumpAndSettle();

    expect(find.text('Ostalo je bez veze'), findsOneWidget);
    expect(find.textContaining('3 vaših poteza'), findsOneWidget);
    await tester.tap(find.text('Ostavi'));
    await tester.pumpAndSettle();

    // Nothing swept: the drafts count was zero and the decisions were kept.
    expect(api.pruned, isEmpty);
  });

  testWidgets('saying yes is what lets decisions go', (tester) async {
    await pump(tester, seed: {
      smithMorra.split(' ').take(4).join(' '): const [
        RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
      ],
    });
    api.orphans = (keys: ['k1'], drafts: 0, decisions: 1);

    await tester.tap(find.byTooltip('Ukloni'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Obriši i njih'));
    await tester.pumpAndSettle();

    expect(api.pruned, [true]);
  });

  testWidgets('a removal that stranded nothing says nothing', (tester) async {
    await pump(tester, seed: {
      smithMorra.split(' ').take(4).join(' '): const [
        RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
      ],
    });
    api.orphans = (keys: const [], drafts: 0, decisions: 0);

    await tester.tap(find.byTooltip('Ukloni'));
    await tester.pumpAndSettle();

    expect(api.pruned, isEmpty);
    expect(find.textContaining('Uklonjeno i'), findsNothing);
  });

  testWidgets('one list beside the board, for the side to move',
      (tester) async {
    // Two of them were on screen at once — what is played here, and what the
    // opponent answers the main move with — which is two lists about two
    // different positions stacked under one board. The second one now lives on
    // the position it is about, one step forward. And it costs nothing: one
    // token serves every child using this app.
    await pump(
      tester,
      seed: {
        smithMorra.split(' ').take(4).join(' '): const [
          RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
        ],
      },
      book: const StoredBook(
        fen: 'x',
        opened: true,
        replies: [
          StoredReply(
              uci: 'g1f3', san: 'Nf3', games: 500, share: 0.5, covered: true),
          StoredReply(uci: 'f1c4', san: 'Bc4', games: 90, share: 0.09),
        ],
      ),
    );

    // The board's own position, and only that.
    expect(find.text('Šta se ovde igra'), findsOneWidget);
    expect(find.textContaining('Posle Nc6'), findsNothing);
    expect(find.text('Nf3'), findsWidgets);
    // And the judge was never asked anything for this.
    expect(judge.asked, 0);
  });

  testWidgets('a position nobody has opened offers to open it, once',
      (tester) async {
    // Two different empties. "Nobody has looked" is an invitation; "the
    // opponent plays nothing" would be a lie.
    await pump(
      tester,
      seed: {
        smithMorra.split(' ').take(4).join(' '): const [
          RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
        ],
      },
      book: const StoredBook(fen: 'x'),
    );

    expect(find.textContaining('Ovu poziciju još niko nije otvarao'),
        findsOneWidget);
    expect(judge.asked, 0);

    await tester.tap(find.text('Otvori knjigu (1 upit)'));
    await tester.pumpAndSettle();

    // Exactly one, and only because it was asked for.
    expect(judge.asked, 1);
    expect(find.textContaining('upita: 1'), findsOneWidget);
  });

  testWidgets('the opening banner is never keyed on anything that moves',
      (tester) async {
    // The banner carries the last opening it was able to name, because the ECO
    // dataset names openings and not every position in them: walk four moves
    // into a real line and the lookup returns null, and a banner that rendered
    // whatever it was just handed would go blank exactly where the student is
    // working hardest.
    //
    // That carried name lives in the widget's State, so **a key that changes
    // as the walk advances throws it away**. This shipped once: both screens
    // mounted the banner as `key: ValueKey(_boardJumpCount)` with the counter
    // incremented on every advance, so the name reset on every question. The
    // widget's own test passed the whole time — it pumps the banner directly
    // and never sees the key the screen supplies.
    //
    // Hence a composition assertion rather than a behavioural one. There is no
    // key this screen could legitimately need: opening another repertoire
    // pushes a whole new screen.
    await tester.runAsync(() async {});
    await pump(tester,
        openingLookup: (fen) => OpeningBookEntry(
              eco: 'B21',
              name: 'Sicilijanka, Smit-Mora',
              pgn: '1. e4 c5 2. d4',
            ));

    final banner = tester.widget<OpeningBanner>(find.byType(OpeningBanner));
    expect(banner.key, isNull,
        reason: 'a changing key resets the carried opening name');
    expect(find.text('B21 · Sicilijanka, Smit-Mora'), findsOneWidget);
  });
  testWidgets('an empty queue is not a dead end', (tester) async {
    // The finished screen tells the reader to go back to a position and take
    // more replies. It offered „Nazad" and nothing else, so a repertoire with
    // a hundred moves in it had no door: no board, no tree, no actions.
    await pump(tester, walk: const RepertoireFrontier(decided: 4, open: []));

    expect(
        find.text('Odgovorili ste na sve pozicije do kojih ovaj repertoar '
            'stiže.'),
        findsOneWidget);
    expect(find.text('Otvori repertoar'), findsOneWidget);

    await tester.tap(find.text('Otvori repertoar'));
    await tester.pumpAndSettle();

    // The board is back, on the repertoire's own root: the question under it
    // is the one this screen exists to ask.
    expect(
        find.text('Odgovorili ste na sve pozicije do kojih ovaj repertoar '
            'stiže.'),
        findsNothing);
    expect(find.byType(BoardWithCoordinates), findsOneWidget);
  });
}
