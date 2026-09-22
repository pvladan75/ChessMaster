import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/opening_judge_service.dart';
import 'package:chess_app/features/repertoire/widgets/opening_banner.dart';
import 'package:chess_app/features/repertoire/screens/repertoire_build_screen.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/speakable_info.dart';
import 'package:chess_app/features/repertoire/services/repertoire_api_service.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

/// 1.e4 c5 2.d4 cxd4 3.c3 dxc3 4.Nxc3 — the Smith-Morra accepted, Black to
/// move. The position the whole design conversation was about.
const smithMorra = 'rnbqkbnr/pp1ppppp/8/8/4P3/2N5/PP3PPP/R1BQKBNR b KQkq - 0 4';

String keyOf(String fen) => fen.split(' ').take(4).join(' ');

/// The position after a line of SAN moves. Computed rather than pasted: a
/// hand-written FEN is a chance to assert against a board that does not exist.
String fenAfter(String from, List<String> sans) {
  final board = chess.Chess.fromFEN(from);
  for (final san in sans) {
    board.move(san);
  }
  return board.fen;
}

/// A repertoire service with no server behind it: it remembers what was kept
/// and entered, and hands it back, which is all the screen reads.
class _FakeApi extends RepertoireApiService {
  _FakeApi() : super(client: MockClient((_) async => http.Response('{}', 500)));

  final Map<String, List<RepertoireMove>> kept = {};
  final List<Map<String, Object?>> attempts = [];
  final List<({String fen, String uci, String? san})> entered = [];
  final List<String> removed = [];
  final List<List<String>> pruned = [];
  String? promoted;

  /// The book's top reply the server enters with a new move, by that move.
  final Map<String, ({String uci, String san})> topReplies = {};

  /// A server that refuses to keep a move.
  bool keepFails = false;

  /// What removing a move would strand.
  ({List<String> keys, int decisions})? orphans =
      (keys: const <String>[], decisions: 0);

  RepertoireFrontier? walk;
  int frontierCalls = 0;

  @override
  Future<RepertoireFrontier?> frontier({
    required String color,
    required String rootFen,
    List<String> rootPath = const [],
    String? gateUci,
  }) async {
    frontierCalls += 1;
    return walk;
  }

  @override
  Future<List<RepertoireMove>> movesAt({
    required String color,
    required String fen,
  }) async =>
      List.of(kept[keyOf(fen)] ?? const []);

  @override
  Future<({bool saved, ({String uci, String san, String fen})? topReply})>
      keepMove({
    required String color,
    required String fen,
    required String uci,
    required String san,
    String? verdict,
  }) async {
    if (keepFails) return (saved: false, topReply: null);
    final list = kept.putIfAbsent(keyOf(fen), () => []);
    list.add(RepertoireMove(
      uci: uci,
      san: san,
      // The first move kept in a position is the primary; the server holds this
      // rule for real, and the fake keeps it so the screen is tested against
      // the same shape.
      role: list.isEmpty ? 'primary' : 'alternate',
    ));
    final top = topReplies[uci];
    if (top == null) return (saved: true, topReply: null);
    final board = chess.Chess.fromFEN(fen)
      ..move({'from': uci.substring(0, 2), 'to': uci.substring(2, 4)});
    return (
      saved: true,
      topReply: (uci: top.uci, san: top.san, fen: board.fen),
    );
  }

  @override
  Future<bool> addOpponentMove({
    required String color,
    required String fen,
    required String uci,
    String? san,
  }) async {
    entered.add((fen: fen, uci: uci, san: san));
    return true;
  }

  @override
  Future<bool> makePrimary({
    required String color,
    required String fen,
    required String uci,
  }) async {
    promoted = uci;
    final list = kept[keyOf(fen)] ?? [];
    kept[keyOf(fen)] = [
      for (final move in list)
        RepertoireMove(
          uci: move.uci,
          san: move.san,
          role: move.uci == uci ? 'primary' : 'alternate',
        ),
    ];
    return true;
  }

  @override
  Future<({List<String> keys, int decisions})?> orphansOfRemoving({
    required String color,
    required String fen,
    required String uci,
  }) async =>
      orphans;

  @override
  Future<bool> removeMove({
    required String color,
    required String fen,
    required String uci,
  }) async {
    removed.add(uci);
    kept[keyOf(fen)]?.removeWhere((move) => move.uci == uci);
    return true;
  }

  @override
  Future<int> prune({
    required String color,
    required List<String> keys,
  }) async {
    pruned.add(keys);
    return keys.length;
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
      'fen': keyOf(fen),
      'uci': uci,
      'san': san,
      'verdict': verdict,
      'kept': kept,
    });
  }
}

/// A judge that answers from a table, and counts how often it was asked.
class _FakeJudge implements OpeningJudgeService {
  _FakeJudge({this.bookAvailable = true});

  final bool bookAvailable;
  int judged = 0;

  @override
  Future<OpeningJudgeLookup> judge(String fen, String move) async {
    judged += 1;
    if (!bookAvailable) {
      return const OpeningJudgeLookup.unavailable('not-configured');
    }
    final board = chess.Chess.fromFEN(fen);
    board.move({'from': move.substring(0, 2), 'to': move.substring(2, 4)});
    return OpeningJudgeLookup.ok(OpeningJudgement(
      verdict: OpeningVerdict.theory,
      fen: fen,
      san: board.getHistory().last.toString(),
      uci: move,
      moverIsWhite: false,
      mastersGames: 900,
      mastersTotal: 4000,
    ));
  }

  @override
  Future<OpponentRepliesLookup> replies(String fen) async =>
      const OpponentRepliesLookup.unavailable('not-configured');

  @override
  void clearCache() {}
}

OpeningExplorerMove _move(String uci, String san, int games) =>
    OpeningExplorerMove(
        uci: uci,
        san: san,
        white: games ~/ 3,
        draws: games ~/ 3,
        black: games - 2 * (games ~/ 3));

/// The book: Black's moves in the Smith-Morra, White's after 4...Nc6.
OpeningExplorerLookup _book(String fen) {
  final blackToMove = fen.split(' ')[1] == 'b';
  if (blackToMove) {
    return OpeningExplorerLookup.ok(OpeningExplorerResult(
      fen: fen,
      white: 334,
      draws: 333,
      black: 333,
      moves: [_move('b8c6', 'Nc6', 600), _move('d7d6', 'd6', 300)],
    ));
  }
  return OpeningExplorerLookup.ok(OpeningExplorerResult(
    fen: fen,
    white: 167,
    draws: 167,
    black: 166,
    moves: [_move('g1f3', 'Nf3', 500)],
  ));
}

/// The same book, except that it runs out the moment White is to move — the
/// state the owner reported the engine missing from. An empty result and not an
/// unavailable one: the book answered, and the answer is that it knows nothing
/// about this position.
Future<OpeningExplorerLookup> _dryForWhite(String fen) async {
  if (fen.split(' ')[1] == 'b') return _book(fen);
  return OpeningExplorerLookup.ok(OpeningExplorerResult(
    fen: fen,
    white: 0,
    draws: 0,
    black: 0,
    moves: const [],
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late _FakeApi api;
  late _FakeJudge judge;
  late List<String> bookAsked;
  ({int depth, int multiPV})? engineAsked;

  Future<void> pump(
    WidgetTester tester, {
    bool bookAvailable = true,
    Size size = const Size(500, 1000),
    List<String> rootPath = const [],
    RepertoireFrontier? walk,
    Map<String, List<RepertoireMove>> seed = const {},
    Future<List<AnalysisLine>> Function(String fen, int depth, int multiPV)?
        analyse,
    OpeningBookEntry? Function(String fen)? openingLookup,
    Future<OpeningExplorerLookup> Function(String fen)? explore,
    // A held lookup keeps its spinner turning, and a turning spinner never
    // settles.
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    api = _FakeApi()..walk = walk;
    for (final entry in seed.entries) {
      api.kept[entry.key] = List.of(entry.value);
    }
    judge = _FakeJudge(bookAvailable: bookAvailable);
    bookAsked = [];
    await tester.pumpWidget(MaterialApp(
      home: RepertoireBuildScreen(
        name: 'Smith-Morra, Black',
        color: 'b',
        rootFen: smithMorra,
        rootPath: rootPath,
        api: api,
        judge: judge,
        openingLookup: openingLookup,
        explore: (fen) async {
          bookAsked.add(fen);
          return explore == null ? _book(fen) : await explore(fen);
        },
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
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

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

  List<EngineArrow> arrows(WidgetTester tester) => tester
      .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
      .engineArrows;

  final seedNc6 = {
    keyOf(smithMorra): const [
      RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
    ],
  };

  group('a move played on the board is kept', () {
    testWidgets('the screen asks for the student\'s own move', (tester) async {
      await pump(tester);

      expect(find.text('What do you play with Black?'), findsOneWidget);
      expect(
        tester
            .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
            .boardOrientation,
        PlayerColor.black,
      );
    });

    testWidgets('at once, with no button to take it', (tester) async {
      await pump(tester);

      await play(tester, 'b8', 'c6');

      final stored = api.kept[keyOf(smithMorra)]!;
      expect(stored.single.san, 'Nc6');
      expect(stored.single.role, 'primary');
      expect(find.textContaining('Take'), findsNothing);
      expect(find.text('Discard'), findsNothing);
    });

    testWidgets('and the board goes past the reply the book added with it',
        (tester) async {
      await pump(tester);
      api.topReplies['b8c6'] = (uci: 'g1f3', san: 'Nf3');

      await play(tester, 'b8', 'c6');

      // After 4...Nc6 5.Nf3, Black to move again.
      expect(find.text('What do you play with Black?'), findsOneWidget);
      expect(find.text('4...Nc6 5.Nf3'), findsOneWidget);
      expect(
          find.textContaining(
              'Nc6 is in your repertoire, with the most played reply, Nf3.'),
          findsOneWidget);
    });

    testWidgets('with no reply in the book, the board waits after the move',
        (tester) async {
      await pump(tester);

      await play(tester, 'b8', 'c6');

      expect(find.text('After Nc6 — which opponent moves do you prepare?'),
          findsOneWidget);
      expect(find.textContaining('The book has no reply here'), findsOneWidget);
    });

    testWidgets('the judge says what it is worth, after the move is kept',
        (tester) async {
      await pump(tester);

      await play(tester, 'b8', 'c6');

      expect(judge.judged, 1);
      expect(find.text('Nc6 · Mainline theory'), findsOneWidget);
      // One attempt row, written with the verdict once it arrived.
      final attempt = api.attempts.single;
      expect(attempt['uci'], 'b8c6');
      expect(attempt['kept'], true);
      expect(attempt['verdict'], 'theory');
    });

    testWidgets('without the book the move is still kept, and it says so',
        (tester) async {
      await pump(tester, bookAvailable: false);

      await play(tester, 'b8', 'c6');

      expect(api.kept[keyOf(smithMorra)]!.single.san, 'Nc6');
      expect(
          find.textContaining('opening book is not available'), findsWidgets);
    });

    testWidgets('a move the server refused is not shown as kept',
        (tester) async {
      await pump(tester);
      api.keepFails = true;

      await play(tester, 'b8', 'c6');

      expect(find.textContaining('Move was not saved'), findsOneWidget);
      expect(find.text('What do you play with Black?'), findsOneWidget);
      expect(api.attempts, isEmpty);
    });

    testWidgets('a move already kept is not kept again', (tester) async {
      await pump(tester, seed: seedNc6);

      await play(tester, 'b8', 'c6');

      expect(api.kept[keyOf(smithMorra)]!.length, 1);
      expect(judge.judged, 0,
          reason: 'a decision that exists is not re-judged');
      expect(find.text('After Nc6 — which opponent moves do you prepare?'),
          findsOneWidget);
    });
  });

  group('the opponent\'s moves are played on the board too', () {
    testWidgets('an opponent move is entered and the board goes on',
        (tester) async {
      await pump(tester, seed: seedNc6);
      await play(tester, 'b8', 'c6');

      expect(
        tester
            .widget<ChessBoardWithOverlay>(find.byType(ChessBoardWithOverlay))
            .isAllowedToMove,
        isTrue,
      );
      await play(tester, 'g1', 'f3');

      expect(api.entered.single.uci, 'g1f3');
      expect(
          keyOf(api.entered.single.fen), keyOf(fenAfter(smithMorra, ['Nc6'])));
      expect(find.text('What do you play with Black?'), findsOneWidget);
      expect(find.text('4...Nc6 5.Nf3'), findsOneWidget);
    });

    testWidgets('including a move the book does not know', (tester) async {
      await pump(tester, seed: seedNc6);
      await play(tester, 'b8', 'c6');

      await play(tester, 'h2', 'h3');

      expect(api.entered.single.uci, 'h2h3');
      expect(find.text('4...Nc6 5.h3'), findsOneWidget);
    });
  });

  group('the book beside the board', () {
    testWidgets('is simply there, as chips, with nothing to open',
        (tester) async {
      await pump(tester);

      expect(bookAsked, [smithMorra]);
      expect(find.textContaining('Nc6 (60%)'), findsOneWidget);
      expect(find.textContaining('d6 (30%)'), findsOneWidget);
      expect(find.textContaining('Open book'), findsNothing);
      expect(find.textContaining('query'), findsNothing);
      expect(find.text('Play'), findsNothing);
    });

    testWidgets('each chip says how many games played the move',
        (tester) async {
      await pump(tester);

      expect(find.text('Nc6 (60%) · 600'), findsOneWidget);
    });

    testWidgets('a chip played is a move kept', (tester) async {
      await pump(tester);

      await tester.tap(find.textContaining('Nc6 (60%)'));
      await tester.pumpAndSettle();

      expect(api.kept[keyOf(smithMorra)]!.single.uci, 'b8c6');
    });

    testWidgets('marks the move already kept', (tester) async {
      await pump(tester, seed: seedNc6);

      expect(find.textContaining('Nc6 ★ (60%)'), findsOneWidget);
    });

    testWidgets('follows the board to the opponent\'s side', (tester) async {
      await pump(tester, seed: seedNc6);

      await play(tester, 'b8', 'c6');

      expect(keyOf(bookAsked.last), keyOf(fenAfter(smithMorra, ['Nc6'])));
      expect(find.textContaining('Nf3 (100%)'), findsOneWidget);
    });

    testWidgets('an answer for the old position never lands on the new one',
        (tester) async {
      final held = Completer<OpeningExplorerLookup>();
      await pump(tester,
          seed: seedNc6,
          settle: false,
          explore: (fen) => keyOf(fen) == keyOf(smithMorra)
              ? held.future
              : Future.value(_book(fen)));

      // Frame by frame rather than pumpAndSettle: the held lookup keeps the
      // screen busy, and a busy screen never settles.
      Future<void> pumpFrames() async {
        for (var i = 0; i < 20; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
      }

      await tester.tapAt(squareAt(tester, 'b8'));
      await pumpFrames();
      await tester.tapAt(squareAt(tester, 'c6'));
      await pumpFrames();
      expect(find.textContaining('Nf3 (100%)'), findsOneWidget);

      held.complete(_book(smithMorra));
      await pumpFrames();

      expect(find.textContaining('Nf3 (100%)'), findsOneWidget);
      expect(find.textContaining('d6 (30%)'), findsNothing);
    });
  });

  group('what is on screen', () {
    testWidgets('the principle and the advice are in view', (tester) async {
      await pump(tester);

      expect(find.textContaining(repertoireBuildPrinciple), findsOneWidget);
      expect(find.textContaining(repertoireBuildAdvice), findsOneWidget);
    });

    testWidgets('nothing retired is offered', (tester) async {
      await pump(tester, seed: seedNc6);

      for (final gone in const [
        'Suggest main line',
        'Review unconfirmed',
        'Do not prepare this',
        'Restore this branch',
        'Next',
        'Skip',
      ]) {
        expect(find.text(gone), findsNothing, reason: gone);
      }
      expect(find.textContaining('queries'), findsNothing);

      await play(tester, 'b8', 'c6');
      expect(find.textContaining('Back to'), findsNothing);
    });

    testWidgets('what is counted is work done, not work owed', (tester) async {
      // Reported live 16.9.2026: the number of unanswered positions was read
      // out at every position, and since 15.9.2026 it describes a model this
      // screen no longer works by — a line is carried further because you
      // choose to, not because something is outstanding. Both places it was
      // written went together: the sentence under the question, and „open" in
      // the progress line, which is the same number in shorter words.
      await pump(tester,
          walk: RepertoireFrontier(
            decided: 3,
            open: [
              FrontierNode(
                  fen: fenAfter(smithMorra, ['Nc6', 'Nf3']),
                  path: const ['Nc6', 'Nf3']),
            ],
          ));

      expect(find.text('decided 3'), findsOneWidget);
      expect(find.textContaining('%'), findsWidgets); // the book's chips only
      expect(find.textContaining('unanswered'), findsNothing);
      expect(find.textContaining('open 1'), findsNothing);
    });

    testWidgets('the spoken sentence is the question and nothing else',
        (tester) async {
      // Asserted on the widget rather than on a fake engine: this file has no
      // speech service in it, and what `SpeakableInfo` is handed is what gets
      // spoken — `govor_na_panelima_test.dart` holds that end.
      await pump(tester,
          walk: RepertoireFrontier(
            decided: 3,
            open: [
              FrontierNode(
                  fen: fenAfter(smithMorra, ['Nc6', 'Nf3']),
                  path: const ['Nc6', 'Nf3']),
            ],
          ));

      final asked = find.text('What do you play with Black?');
      final panel =
          find.ancestor(of: asked, matching: find.byType(SpeakableInfo));
      expect(panel, findsOneWidget);
      expect(tester.widget<SpeakableInfo>(panel).text,
          'What do you play with Black?');
    });
  });

  group('the main move', () {
    testWidgets('can be chosen, and the screen says how', (tester) async {
      await pump(tester, seed: {
        keyOf(smithMorra): const [
          RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
          RepertoireMove(uci: 'd7d6', san: 'd6', role: 'alternate'),
        ],
      });

      expect(find.text('Your moves here'), findsOneWidget);
      expect(find.text('main'), findsOneWidget);
      await tester.tap(find.text('tap for main'));
      await tester.pumpAndSettle();

      expect(api.promoted, 'd7d6');
    });

    testWidgets('is drawn with its star, beside its share', (tester) async {
      await pump(tester, seed: {
        keyOf(smithMorra): const [
          RepertoireMove(uci: 'b8c6', san: 'Nc6', role: 'primary'),
          RepertoireMove(uci: 'd7d6', san: 'd6', role: 'alternate'),
        ],
      });

      final drawn = arrows(tester);
      expect(drawn.length, 2);
      expect(drawn.first.evalText, '★ 60%');
      expect(drawn.first.rank, 1);
      expect(drawn.last.to, 'd6');
      expect(drawn.last.evalText, '30%');
      expect(drawn.last.rank, 2);
    });
  });

  group('deleting a move', () {
    testWidgets('that strands nothing goes without a question', (tester) async {
      await pump(tester, seed: seedNc6);

      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();

      expect(api.removed, ['b8c6']);
      // No note that it was removed: the tree shows it, and a deletion says
      // nothing on success (the owner, 22.9.2026) — this line asserted the
      // opposite until then.
      expect(find.textContaining('Nc6 was removed'), findsNothing);
    });

    testWidgets('that would take moves of yours with it asks first',
        (tester) async {
      await pump(tester, seed: seedNc6);
      api.orphans = (keys: const ['k1', 'k2'], decisions: 2);

      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Nc6?'), findsOneWidget);
      expect(find.textContaining('2 moves'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(api.removed, isEmpty);
      expect(api.pruned, isEmpty);

      await tester.tap(find.byTooltip('Remove'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(api.removed, ['b8c6']);
      expect(api.pruned, [
        ['k1', 'k2']
      ]);
    });
  });

  group('the engine', () {
    testWidgets('answers on request, at the depth that was set',
        (tester) async {
      engineAsked = null;
      await pump(tester);

      expect(find.text('Engine'), findsNothing);
      await tester.tap(find.text('Ask engine'));
      await tester.pumpAndSettle();

      expect(find.text('Engine'), findsOneWidget);
      expect(engineAsked, isNotNull);
      expect(find.text('+0.20'), findsOneWidget);
    });

    testWidgets('a line tapped is a move kept, like any other', (tester) async {
      await pump(tester, size: const Size(500, 1400));

      await tester.tap(find.text('Ask engine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('+0.20'));
      await tester.pumpAndSettle();

      expect(api.kept[keyOf(smithMorra)]!.single.uci, 'b8c6');
    });

    testWidgets('an answer for the old position never lands on the new one',
        (tester) async {
      final gate = Completer<List<AnalysisLine>>();
      await pump(tester, analyse: (fen, depth, multiPV) => gate.future);
      api.topReplies['b8c6'] = (uci: 'g1f3', san: 'Nf3');

      await tester.tap(find.text('Ask engine'));
      await tester.pump();

      Future<void> until(Finder finder) async {
        for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 20));
        }
        expect(finder, findsWidgets);
      }

      await tester.tapAt(squareAt(tester, 'b8'));
      await tester.pump();
      await tester.tapAt(squareAt(tester, 'c6'));
      await until(find.text('4...Nc6 5.Nf3'));

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
          reason: 'the answer belongs to the position it was asked about');
      expect(find.text('-0.03'), findsNothing);
    });

    testWidgets(
        'can be asked after a move of your own, where the book has '
        'nothing to say', (tester) async {
      // Reported live 16.9.2026. With no reply in the book the board waits
      // after your own move with the opponent to move — and that was the one
      // state where „Ask engine" was not drawn at all, so the engine went
      // missing at exactly the position there was nothing else to go on.
      await pump(tester, size: const Size(500, 1400), explore: _dryForWhite);

      await play(tester, 'b8', 'c6');
      expect(find.text('After Nc6 — which opponent moves do you prepare?'),
          findsOneWidget);

      await tester.ensureVisible(find.text('Ask engine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask engine'));
      await tester.pumpAndSettle();

      expect(find.text('Engine'), findsOneWidget);
      expect(find.text('+0.20'), findsOneWidget,
          reason: 'the lines belong to the board, not to the position behind '
              'it');
    });

    testWidgets('its arrow is drawn where the book left the board bare',
        (tester) async {
      await pump(tester, size: const Size(500, 1400), explore: _dryForWhite);

      await play(tester, 'b8', 'c6');
      expect(arrows(tester), isEmpty, reason: 'the book knows nothing here');

      await tester.ensureVisible(find.text('Ask engine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask engine'));
      await tester.pumpAndSettle();

      expect(arrows(tester).first.evalText, '+0.20');
    });

    testWidgets('changing the depth asks again instead of looking stopped',
        (tester) async {
      var calls = 0;
      final depths = <int>[];
      await pump(tester, analyse: (fen, depth, multiPV) async {
        calls += 1;
        depths.add(depth);
        return const <AnalysisLine>[];
      });

      await tester.tap(find.text('Ask engine'));
      await tester.pumpAndSettle();
      expect(calls, 1);

      await tester.tap(find.text('${depths.first}').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('24').last);
      await tester.pumpAndSettle();

      expect(calls, 2);
      expect(depths.last, 24);
    });
  });

  group('the walk', () {
    testWidgets('says which line the board belongs to', (tester) async {
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

    testWidgets(
        'without a stored root path the line is numbered from the board',
        (tester) async {
      await pump(tester,
          walk: RepertoireFrontier(
            decided: 1,
            open: [
              FrontierNode(
                fen: fenAfter(smithMorra, ['Nc6', 'Nf3']),
                path: const ['Nc6', 'Nf3'],
              ),
            ],
          ));

      expect(find.text('4...Nc6 5.Nf3'), findsOneWidget);
    });

    testWidgets('a walk that could not be read falls back to the root',
        (tester) async {
      await pump(tester);

      expect(api.frontierCalls, 1);
      expect(find.text('What do you play with Black?'), findsOneWidget);
      expect(find.textContaining('starting from'), findsOneWidget);
    });

    testWidgets(
        'open positions come shallower first, and Next position walks them',
        (tester) async {
      await pump(tester,
          walk: RepertoireFrontier(
            open: [
              FrontierNode(
                fen: fenAfter(smithMorra, ['Nc6', 'Nf3', 'e6', 'Bc4']),
                path: const ['Nc6', 'Nf3', 'e6', 'Bc4'],
              ),
              FrontierNode(
                fen: fenAfter(smithMorra, ['d6', 'Bc4']),
                path: const ['d6', 'Bc4'],
              ),
            ],
          ));

      expect(find.text('4...d6 5.Bc4'), findsOneWidget);

      await tester.ensureVisible(find.text('Next position'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next position'));
      await tester.pumpAndSettle();

      expect(find.text('4...Nc6 5.Nf3 e6 6.Bc4'), findsOneWidget);
    });

    testWidgets('Next position waits when nothing else is open',
        (tester) async {
      await pump(tester);

      final next = find.widgetWithText(OutlinedButton, 'Next position');
      expect(tester.widget<OutlinedButton>(next).onPressed, isNull);
    });

    testWidgets('an empty queue is not a dead end', (tester) async {
      await pump(tester, walk: const RepertoireFrontier(decided: 4, open: []));

      expect(
          find.text('You have answered all positions reachable by this '
              'repertoire.'),
          findsOneWidget);
      await tester.tap(find.text('Open repertoire'));
      await tester.pumpAndSettle();

      expect(find.byType(BoardWithCoordinates), findsOneWidget);
    });
  });

  testWidgets('the loop fits a 360 dp phone', (tester) async {
    // A release build paints no overflow stripes; in a test build it throws.
    await pump(tester, size: const Size(360, 640));
    expect(tester.takeException(), isNull);

    api.topReplies['b8c6'] = (uci: 'g1f3', san: 'Nf3');
    await play(tester, 'b8', 'c6');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the opening banner is never keyed on anything that moves',
      (tester) async {
    // The banner carries the last opening it was able to name in its State, so
    // a key that changes as the walk advances throws that name away. A
    // `GlobalKey` held in the State is made once and never changes.
    await tester.runAsync(() async {});
    await pump(tester,
        openingLookup: (fen) => OpeningBookEntry(
              eco: 'B21',
              name: 'Sicilian, Smith-Morra',
              pgn: '1. e4 c5 2. d4',
            ));

    final banner = tester.widget<OpeningBanner>(find.byType(OpeningBanner));
    expect(banner.key, isA<GlobalKey>());
    expect(banner.key, isNot(isA<ValueKey>()));
    expect(find.text('B21 · Sicilian, Smith-Morra'), findsOneWidget);
  });
}
