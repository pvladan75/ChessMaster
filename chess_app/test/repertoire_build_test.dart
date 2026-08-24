import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/models/analysis_models.dart';
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

  String _key(String fen) => fen.split(' ').take(4).join(' ');

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
    return OpponentRepliesLookup.ok(OpponentReplies(
      total: 1000,
      replies: [
        for (final uci in replyList)
          OpponentReply(uci: uci, san: uci, games: 500, share: 0.5),
      ],
      // What the student reads when choosing: more than the covered few, with
      // how those games went.
      all: const [
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
    Future<List<AnalysisLine>> Function(String fen, int depth, int multiPV)?
        analyse,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    api = _FakeApi();
    judge = _FakeJudge(verdict: verdict, hasToken: hasToken);
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'Smit-Mora, crni',
        color: 'b',
        rootFen: smithMorra,
        api: api,
        judge: judge,
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
    // Two: the verdict, and the book that follows it. Their allowance, so the
    // count is on screen rather than guessed at.
    expect(find.textContaining('upita: 2'), findsOneWidget);
  });

  testWidgets('the book arrives once the move is played, without being asked',
      (tester) async {
    // Hidden while the student is deciding, free the moment they commit. A
    // verdict on one move says whether that move is sound; it does not say
    // whether something better was sitting next to it, and choosing between
    // candidates is the actual work.
    await pump(tester);

    expect(find.text('Šta se ovde igra'), findsNothing);

    await play(tester, 'b8', 'c6');

    expect(find.text('Šta se ovde igra'), findsOneWidget);
    expect(find.text('d6'), findsOneWidget);
    expect(find.text('a6'), findsOneWidget);
    // Popularity and how those games went, side by side.
    expect(find.text('60%'), findsOneWidget);
    expect(find.textContaining('za crnog'), findsWidgets);
  });

  testWidgets('reading the book after a move is not counted as looking it up',
      (tester) async {
    await pump(tester);

    await play(tester, 'b8', 'c6');
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();

    expect(api.attempts.single['lookedUp'], false,
        reason: 'pogledao je tek pošto se opredelio — to nije zavirivanje');
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

  testWidgets('"Ne znam" opens the same book, and that one is written down',
      (tester) async {
    await pump(tester);

    await tester.tap(find.text('Ne znam'));
    await tester.pumpAndSettle();
    expect(find.text('Šta se ovde igra'), findsOneWidget);
    expect(judge.asked, 1);

    await play(tester, 'b8', 'c6');
    await tester.tap(find.text('Uzmi Nc6'));
    await tester.pumpAndSettle();

    expect(api.attempts.single['lookedUp'], true,
        reason: 'pozicija rešena gledanjem nije isto što i rešena mišljenjem');
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
    expect(judge.asked, 2);
    expect(find.textContaining('Pokriveno 85%'), findsOneWidget);
    expect(find.textContaining('van toga još 3'), findsOneWidget);
    // And the board has moved on to a position where it is Black to move again.
    expect(find.text('Šta igrate crnim?'), findsOneWidget);
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
  });
}
