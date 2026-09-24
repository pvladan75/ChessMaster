// A review holds the engine — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md, phase 1.2b.
//
// The phone has one engine, in the app's own process, shared by every screen.
// Leaving Analysis calls `detach`, which calls `stopAnalysis()` whoever is
// searching; a screen's MultiPV dial sends `stop`; and a screen that attaches
// or detaches swaps its callbacks into the very fields a review's search is
// listening on. Any of the three would cut a running review's search short —
// and a search stopped early returns what it had, which the review then
// refuses as unanswered (1.2a). So a review *holds* the engine for its whole
// run: while held, a screen's stop, MultiPV and live search do not reach the
// engine, its callbacks are not swapped in, a refused live search is said,
// and Analysis says the engine is busy rather than showing nothing. When the
// hold ends, the screen on top gets the engine back as it left it.
//
// On Windows and Linux (and so in this test and in CI) the service is the
// online engine, where `stopAnalysis` drops a search by raising the request
// id; that id is what these cases read.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/eval_cache.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_draft_service.dart';
import 'package:chess_app/features/analysis_studio/services/game_from_moves.dart';
import 'package:chess_app/features/analysis_studio/services/game_review_runner.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/review_notice.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _scholar = ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6', 'h5f7'];

/// Answers every position level except the one after 3...Nf6, where White
/// mates in one: Black's move there is a mistake by any rule. The position
/// after 4.Qxf7# is mate on the board and is never asked about.
class _Engine implements StockfishService {
  static final List<String> _fens = () {
    final fens = <String>[];
    AnalysisNode? node = analysisTreeFromMoves(_start, _scholar).root;
    while (node != null) {
      fens.add(node.fen);
      node = node.children.isEmpty ? null : node.children.first;
    }
    return fens;
  }();

  @override
  Future<List<AnalysisLine>> analyzePositionSync(
    String fen, {
    required int depth,
    required int multiPV,
    List<String>? searchMoves,
    Duration timeout = const Duration(seconds: 10),
    void Function(List<AnalysisLine> partial)? onProgress,
  }) async {
    final i = _fens.indexOf(fen);
    if (i < 0 || i >= _scholar.length) {
      throw StateError('asked about position $i');
    }
    AnalysisLine line(int pv, String evaluation, String uci) =>
        AnalysisLine.fromPv(
            multipv: pv,
            depth: depth,
            eval: evaluation,
            pvString: uci,
            startingFen: fen);
    // 3...Nf6 searched alone: White mates in one after it.
    if (searchMoves != null) return [line(1, 'M1', searchMoves.first)];
    if (i == 5) {
      // Black to move: 3...Qe7 or 3...g6 holds.
      return [
        line(1, '0.00', 'd8e7'),
        if (multiPV >= 2) line(2, '0.00', 'g7g6'),
      ];
    }
    return [line(1, i == 6 ? 'M1' : '0.00', _scholar[i])];
  }

  @override
  Future<String?> answerStoreName() async => null;

  @override
  void hold(Object owner) {}

  @override
  void release(Object owner) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<MastersWalk> _noBook(List<String> fens) async =>
    (known: const <String, Map<String, dynamic>>{}, unavailable: null);

UserSession _session() =>
    UserSession(token: 't', id: 1, email: 'a@b.c', name: 'N', role: 'korisnik');

StockfishAnalysisWidget _panel(WidgetTester tester) =>
    tester.widget<StockfishAnalysisWidget>(
        find.byType(StockfishAnalysisWidget, skipOffstage: false));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final engine = StockfishService();

  group('held, the engine is the review\'s', () {
    test('a screen\'s stop, or its leaving, does not cut the review\'s search',
        () {
      final review = Object();
      final screen = Object();
      engine.hold(review);
      addTearDown(() => engine.release(review));

      final before = engine.debugRequestId;
      engine.stopAnalysis();
      engine.attach(screen, getFen: () => _start, isEnabled: () => false);
      engine.detach(screen);
      expect(engine.debugRequestId, before);

      engine.release(review);
      engine.stopAnalysis();
      expect(engine.debugRequestId, isNot(before),
          reason: 'the fixture cannot see a stop at all');
    });

    test('a screen\'s MultiPV waits for the hold to end', () {
      final review = Object();
      engine.setMultiPV(1);
      engine.hold(review);
      addTearDown(() => engine.release(review));

      engine.setMultiPV(4);
      expect(engine.debugMultiPV, 1);
      engine.release(review);
      expect(engine.debugMultiPV, 4);
      engine.setMultiPV(1);
    });

    test(
        'a screen\'s callbacks are not swapped in under the review\'s search, '
        'and are its again when the hold ends', () {
      final review = Object();
      final screen = Object();
      // Two distinct listeners; a local function's tear-offs compare equal.
      void reviews(Map<int, AnalysisLine> _) {}
      void screens(Map<int, AnalysisLine> _) {}

      engine.hold(review);
      addTearDown(() => engine.release(review));
      // What `analyzePositionSync` does for the review's search.
      engine.onMultiPVUpdated = reviews;

      engine.attach(screen, onMultiPV: screens, isEnabled: () => false);
      expect(engine.onMultiPVUpdated == reviews, isTrue,
          reason: 'attaching took the review\'s answer away');
      engine.detach(screen);
      expect(engine.onMultiPVUpdated == reviews, isTrue,
          reason: 'detaching took the review\'s answer away');

      engine.attach(screen, onMultiPV: screens, isEnabled: () => false);
      engine.release(review);
      expect(engine.onMultiPVUpdated == screens, isTrue);
      engine.detach(screen);
    });

    test('a live search is refused and counted, and never reaches the engine',
        () async {
      final review = Object();
      engine.hold(review);
      addTearDown(() => engine.release(review));

      final before = engine.debugRequestId;
      final refused = engine.refusedWhileHeld.value;
      // Not awaited: a live search that got through would wait out its
      // debounce and a request before answering.
      unawaited(engine.analyzePosition(_start));
      // Past the 180 ms the live search waits before it is sent.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(engine.debugRequestId, before);
      expect(engine.refusedWhileHeld.value, refused + 1);
    });

    // Added by the lead on grading: a live search asked for just before the
    // hold waits out its debounce, and then went straight to the engine,
    // past every check the hold puts on the public doors.
    test('a live search asked for just before the hold never fires into it',
        () async {
      final review = Object();
      unawaited(engine.analyzePosition(_start));
      engine.hold(review);
      addTearDown(() => engine.release(review));
      final before = engine.debugRequestId;
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(engine.debugRequestId, before);
    });

    test('only the one who holds it lets it go', () {
      final review = Object();
      engine.hold(review);
      addTearDown(() => engine.release(review));
      expect(engine.held.value, isTrue);
      engine.release(Object());
      expect(engine.held.value, isTrue);
      engine.release(review);
      expect(engine.held.value, isFalse);
    });
  });

  testWidgets(
      'a live search refused while held is said, wherever the reader is',
      (tester) async {
    final review = Object();
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      builder: (context, child) => ReviewNotice(
          runner: GameReviewRunner(book: _noBook, tablebase: (_) async => null),
          child: child!),
      home: const Scaffold(body: Text('a screen with an engine')),
    ));
    engine.hold(review);
    addTearDown(() => engine.release(review));
    unawaited(engine.analyzePosition(_start));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('busy with the game review'), findsOneWidget);
    engine.release(review);
  });

  testWidgets('Analysis says the engine is busy while a review holds it',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AnalysisStudioScreen(userSession: _session()),
    ));
    await tester.pumpAndSettle();

    final review = Object();
    engine.hold(review);
    addTearDown(() => engine.release(review));
    await tester.pump();
    expect(find.byKey(const Key('analysis-engine-busy'), skipOffstage: false),
        findsNothing,
        reason: 'with the engine switched off there is nothing to say');

    _panel(tester).onToggleEngine();
    await tester.pump();
    expect(find.byKey(const Key('analysis-engine-busy'), skipOffstage: false),
        findsOneWidget);

    engine.release(review);
    // The screen on top gets the engine back, and asks it again.
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('analysis-engine-busy'), skipOffstage: false),
        findsNothing);
    _panel(tester).onToggleEngine();
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets(
      'a review lands on the live Analysis screen that holds the game, and '
      'goes into its draft', (tester) async {
    SharedPreferences.setMockInitialValues({});
    EvalCache.instance.clear();
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final runner =
        GameReviewRunner(book: _noBook, tablebase: (_) async => null);
    final shown = analysisTreeFromMoves(_start, _scholar).root;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: const [AppColorTokens.dark]),
      home: AnalysisStudioScreen(
          userSession: _session(), initialTree: shown, reviewRunner: runner),
    ));
    await tester.pumpAndSettle();

    // Started elsewhere, on a copy of the game — as a dialog on a screen
    // that has since gone would have.
    final copy = analysisTreeFromMoves(_start, _scholar).root;
    final run = runner.start(
      root: copy,
      start: copy,
      options: const ReviewOptions(depth: 20, markMistakes: true),
      engine: _Engine(),
    );
    await run.finished;
    await tester.pump(const Duration(seconds: 1));

    expect(run.landing, ReviewLanding.onBoard);
    AnalysisNode node = shown;
    for (var i = 0; i < 6; i++) {
      node = node.children.first;
    }
    expect(node.nag, '??', reason: '3...Nf6 allows mate in one');

    final draft = await AnalysisDraftService.instance.load();
    AnalysisNode saved = draft!.rootNode;
    for (var i = 0; i < 6; i++) {
      saved = saved.children.first;
    }
    expect(saved.nag, '??', reason: 'the marks did not reach the draft');
  });
}
