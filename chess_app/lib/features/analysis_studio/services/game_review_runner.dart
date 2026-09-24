/// The review's home — `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1.2b.
///
/// Until this phase the whole-game review lived inside its dialog: closing
/// the dialog lost the walk, and the marks were written straight onto the
/// nodes of the screen that opened it. The review takes some fifteen minutes
/// on a phone (phase 0), so it now runs in the background — started from the
/// dialog, it belongs to the app from then on. The result lands on the
/// *game*: whichever live board holds it when the run ends, else the
/// one-slot draft if that still holds it — found by its moves, never by the
/// identity of the nodes it was started on, since the screen that started it
/// may be long gone by the time it finishes. A sign-out in the middle stops
/// it. The engine is held from the first search to the last, so a screen's
/// stop, its MultiPV dial or its own callbacks cannot cut the review short.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:chess_app/core/services/eval_cache.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/core/services/game_review_judge.dart';
import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_draft_service.dart';
import 'package:chess_app/features/analysis_studio/services/review_words.dart';
import 'package:chess_app/features/analysis_studio/services/review_words_client.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/services/account_local_state.dart';
import 'package:chess_app/services/session_service.dart';
import 'package:chess_app/services/stockfish_service.dart';

/// What a review is asked to do; the pawn slider is gone (the mistake rule
/// decides, not a number the reader picks).
class ReviewOptions {
  const ReviewOptions({
    required this.depth,
    this.markMistakes = false,
    this.side = BlunderAlertSide.both,
    this.insertBetterLine = true,
    this.findPuzzles = false,
    this.maxPuzzles = 5,
    this.aiWords = false,
  });

  final int depth;
  final bool markMistakes;
  final BlunderAlertSide side;
  final bool insertBetterLine;
  final bool findPuzzles;
  final int maxPuzzles;

  /// „Comment key moments with AI" (phase 3): one request to the server for
  /// the whole review, never made without this tick. Words go into the PGN
  /// only with [markMistakes]; kept puzzles take theirs whenever it is set.
  final bool aiWords;
}

/// The game a run was started on, by its moves rather than by the identity of
/// the nodes it saw: the root's FEN, the UCI path from the root to the start
/// node, and the UCI main line (first children) from the start node.
class ReviewedGame {
  const ReviewedGame({
    required this.rootFen,
    required this.pathUci,
    required this.mainLineUci,
    required this.startFen,
    this.clocks = const [],
    this.timeControl,
  });

  final String rootFen;
  final List<String> pathUci;
  final List<String> mainLineUci;
  final String startFen;

  /// Every move's clock from the game's start — the path, then the main line
  /// — null where a move carried none (`docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`,
  /// phase 3). Move `i` of [mainLineUci] is `clocks[pathUci.length + i]`.
  final List<double?> clocks;

  /// The root's `TimeControl` header, when the game had one.
  final String? timeControl;

  /// Walks [root] to the start node ([pathUci]), then along [mainLineUci] —
  /// matching every step by `moveUci`, never by child index — and answers the
  /// nodes of those moves in *that* tree. Null when the tree does not hold
  /// them all: a different root FEN, or a move missing.
  List<AnalysisNode>? chainIn(AnalysisNode root) {
    if (root.fen != rootFen) return null;
    var node = root;
    for (final uci in pathUci) {
      final next = _childWithUci(node, uci);
      if (next == null) return null;
      node = next;
    }
    final chain = <AnalysisNode>[];
    for (final uci in mainLineUci) {
      final next = _childWithUci(node, uci);
      if (next == null) return null;
      chain.add(next);
      node = next;
    }
    return chain;
  }

  static AnalysisNode? _childWithUci(AnalysisNode node, String uci) {
    for (final c in node.children) {
      if (c.moveUci == uci) return c;
    }
    return null;
  }

  static ReviewedGame of({
    required AnalysisNode root,
    required AnalysisNode start,
  }) {
    final path = <String>[];
    final pathClocks = <double?>[];
    var up = start;
    while (!identical(up, root) && up.parent != null) {
      final uci = up.moveUci;
      if (uci != null) {
        path.insert(0, uci);
        pathClocks.insert(0, up.clockSeconds);
      }
      up = up.parent!;
    }
    final mainLine = <String>[];
    final mainClocks = <double?>[];
    var down = start;
    while (down.children.isNotEmpty) {
      down = down.children.first;
      final uci = down.moveUci;
      if (uci != null) {
        mainLine.add(uci);
        mainClocks.add(down.clockSeconds);
      }
    }
    return ReviewedGame(
      rootFen: root.fen,
      pathUci: path,
      mainLineUci: mainLine,
      startFen: start.fen,
      clocks: [...pathClocks, ...mainClocks],
      timeControl: root.timeControl,
    );
  }
}

/// A live screen that can take a review's result.
abstract interface class ReviewBoard {
  AnalysisNode get reviewRoot;
  void reviewLanded();
}

enum ReviewRunStatus { running, done, cancelled, failed }

/// Where a finished run's marks ended up. Null when nothing was asked to
/// land ([ReviewOptions.markMistakes] was false).
enum ReviewLanding { onBoard, inDraft, notLanded }

/// One review, from start to end — a [ChangeNotifier] so a dialog or a board
/// can watch it without polling.
class GameReviewRun extends ChangeNotifier {
  GameReviewRun({required this.game, required this.options, this.gameTitle});

  final ReviewedGame game;
  final ReviewOptions options;
  final String? gameTitle;

  ReviewRunStatus _status = ReviewRunStatus.running;
  ReviewRunStatus get status => _status;

  ReviewProgress? _progress;
  ReviewProgress? get progress => _progress;

  GameReviewResult? _result;
  GameReviewResult? get result => _result;

  final EngineAnswerTally tally = EngineAnswerTally();

  int _marked = 0;
  int get marked => _marked;

  List<LocalPuzzle> _puzzles = const [];
  List<LocalPuzzle> get puzzles => _puzzles;

  int _puzzlesUnplayable = 0;
  int get puzzlesUnplayable => _puzzlesUnplayable;

  ReviewLanding? _landing;
  ReviewLanding? get landing => _landing;

  String? _failure;
  String? get failure => _failure;

  /// The review's words, judged — null when none were asked for, none were
  /// needed, or the server wrote none ([wordsFailure] then says why).
  ReviewWordsVerdict? _words;
  ReviewWordsVerdict? get words => _words;

  /// Why no words were written, in the reader's terms; null otherwise.
  String? _wordsFailure;
  String? get wordsFailure => _wordsFailure;

  /// Words were asked for and no moment of the review needed any.
  bool _wordsNotNeeded = false;
  bool get wordsNotNeeded => _wordsNotNeeded;

  final Completer<void> _finished = Completer<void>();

  /// Completes however the run ends — done, cancelled or failed.
  Future<void> get finished => _finished.future;

  void _setProgress(ReviewProgress progress) {
    _progress = progress;
    notifyListeners();
  }

  void _end(ReviewRunStatus status) {
    _status = status;
    if (!_finished.isCompleted) _finished.complete();
    notifyListeners();
  }
}

/// The one place a review runs. Started from a dialog; it then belongs to
/// the app, not to whatever screen started it.
class GameReviewRunner extends ChangeNotifier {
  GameReviewRunner({
    BookLookup? book,
    TablebaseLookup? tablebase,
    http.Client? wordsClient,
    String Function()? sessionToken,
  })  : _book = book ?? _defaultBook,
        _tablebase = tablebase ?? SyzygyTablebaseService.instance.lookup,
        _wordsClient = wordsClient,
        _sessionToken =
            sessionToken ?? (() => SessionService.instance.current.token);

  static final GameReviewRunner instance = GameReviewRunner();

  /// As `game_tutorial_run.dart` asks the book, with the session's own token
  /// (`walkMastersBook`'s default) and the app's ECO names.
  static Future<MastersWalk> _defaultBook(List<String> fens) async =>
      walkMastersBook(fens, openingNameOf: await ecoOpeningNames());

  final BookLookup _book;
  final TablebaseLookup _tablebase;

  /// The seam `POST /review-words` goes through; null uses a fresh client.
  final http.Client? _wordsClient;
  final String Function() _sessionToken;
  final GameAnalysisWalkerService _walker = GameAnalysisWalkerService();

  GameReviewRun? _current;
  GameReviewRun? get current => _current;
  bool get isRunning => _current?.status == ReviewRunStatus.running;

  GameReviewJudge? _judge;

  final List<ReviewBoard> _boards = [];

  void attachBoard(ReviewBoard board) => _boards.add(board);
  void detachBoard(ReviewBoard board) => _boards.remove(board);

  int _watchers = 0;

  /// A dialog open on the runner watches it; the end is then said only in the
  /// dialog, never as a message.
  bool get watched => _watchers > 0;
  void watch() => _watchers++;
  void unwatch() {
    if (_watchers > 0) _watchers--;
  }

  /// Starts a review; throws [StateError] while one is already under way.
  /// Returns at once — the run goes on without any widget.
  GameReviewRun start({
    required AnalysisNode root,
    required AnalysisNode start,
    required ReviewOptions options,
    required StockfishService engine,
    String? gameTitle,
  }) {
    if (isRunning) {
      throw StateError('a review is already running');
    }
    final game = ReviewedGame.of(root: root, start: start);
    final run = GameReviewRun(
      game: game,
      options: options,
      gameTitle: gameTitle,
    );
    _current = run;
    notifyListeners();
    unawaited(_run(run, engine));
    return run;
  }

  /// Stops the run under way; the search in flight finishes (at most its own
  /// timeout) and the run ends cancelled, with nothing marked. The engine's
  /// search itself is never stopped from here.
  void cancel() => _judge?.cancel();

  /// Drops the finished run so [current] answers null and a new one may
  /// start.
  void dismiss() {
    _current = null;
    notifyListeners();
  }

  Future<void> _run(GameReviewRun run, StockfishService engine) async {
    final epoch = AccountLocalState.epoch;
    engine.hold(run);
    try {
      final analyzer = EvalCache.instance.wrapMoves(
        engine.analyzePositionSync,
        engine: engine.answerStoreName,
        tally: run.tally,
      );
      final judge = GameReviewJudge(
        analyzer: analyzer,
        book: _book,
        tablebase: _tablebase,
      );
      _judge = judge;

      GameReviewResult? result;
      try {
        result = await judge.review(
          startingFen: run.game.startFen,
          uciMoves: run.game.mainLineUci,
          depth: run.options.depth,
          puzzles: run.options.findPuzzles ? run.options.side : null,
          onProgress: (progress) {
            run._setProgress(progress);
            if (!AccountLocalState.isCurrent(epoch)) judge.cancel();
          },
        );
      } catch (e) {
        run._failure = e.toString();
        run._end(ReviewRunStatus.failed);
        return;
      }

      if (result == null || !AccountLocalState.isCurrent(epoch)) {
        run._end(ReviewRunStatus.cancelled);
        return;
      }

      run._result = result;

      if (run.options.findPuzzles) {
        final puzzles = LocalPuzzleExtractorService().buildPuzzlesFromReview(
          result,
          maxPuzzles: run.options.maxPuzzles,
          side: run.options.side,
        );
        run._puzzles = puzzles.all;
        run._puzzlesUnplayable = puzzles.unplayable;
      }

      if (run.options.aiWords &&
          (run.options.markMistakes || run.options.findPuzzles)) {
        await _askWords(run, result);
        if (!AccountLocalState.isCurrent(epoch)) {
          run._end(ReviewRunStatus.cancelled);
          return;
        }
      }

      if (run.options.markMistakes) {
        await _land(run, result, epoch);
      }

      run._end(ReviewRunStatus.done);
    } finally {
      _judge = null;
      engine.release(run);
    }
  }

  /// The review's words — `docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 3. One
  /// request for the whole review. The moments are the mistakes Blunder Alert
  /// marks and the only moves found when it is on, else the kept puzzles'
  /// own; whatever the server answers, the engine's analysis lands as before
  /// and [GameReviewRun.wordsFailure] says that no words were written.
  Future<void> _askWords(GameReviewRun run, GameReviewResult result) async {
    final options = run.options;
    bool sideMatches(bool whiteMoved) => switch (options.side) {
          BlunderAlertSide.both => true,
          BlunderAlertSide.white => whiteMoved,
          BlunderAlertSide.black => !whiteMoved,
        };
    final Iterable<int> mistakes;
    final Iterable<int> found;
    if (options.markMistakes) {
      mistakes = [
        for (final m in result.moves)
          if (m.isMistake && sideMatches(m.whiteMoved)) m.ply,
      ];
      found = [
        for (final p in LocalPuzzleExtractorService()
            .buildPuzzlesFromReview(
              result,
              maxPuzzles: kReviewWordsMoments,
              side: options.side,
            )
            .onlyMoves)
          p.sourcePlyIndex,
      ];
    } else {
      mistakes = [
        for (final p in run._puzzles)
          if (p.kind == PuzzleKind.mistake) p.sourcePlyIndex,
      ];
      found = [
        for (final p in run._puzzles)
          if (p.kind == PuzzleKind.onlyMove) p.sourcePlyIndex,
      ];
    }
    final request = reviewWordsRequest(
      result: result,
      mistakePlies: mistakes,
      foundPlies: found,
      clocks: run.game.clocks,
      clockOffset: run.game.pathUci.length,
      timeControl: run.game.timeControl,
    );
    if (request == null) {
      run._wordsNotNeeded = true;
      return;
    }
    run._setProgress(const ReviewProgress(ReviewStage.words, 0, 1));
    final outcome = await requestReviewWords(
      request.toJson(),
      token: _sessionToken(),
      client: _wordsClient,
    );
    final slots = outcome.slots;
    if (slots == null) {
      run._wordsFailure = outcome.refusal?.message ?? 'no answer';
      return;
    }
    final verdict = judgeReviewWords(request, slots);
    run._words = verdict;
    run._puzzles = [
      for (final p in run._puzzles)
        p.withWords(puzzleWordsOf(
          verdict.byPly[p.sourcePlyIndex],
          p.kind == PuzzleKind.mistake
              ? ReviewMomentKind.mistake
              : ReviewMomentKind.found,
        )),
    ];
    run._setProgress(const ReviewProgress(ReviewStage.words, 1, 1));
  }

  /// Where the result lands: the most recently attached board that still
  /// holds the game, else — only when no board at all is attached — the
  /// one-slot draft, else nowhere. A board attached and not matching still
  /// keeps the draft untouched: the board's own debounced save would
  /// overwrite marks written there and call them landed when they were lost.
  ///
  /// [epoch] is the run's own, taken when it started — never the one current
  /// at the write, which is always current (the bug the epoch exists for). It
  /// is asked again after the draft is read, and handed to the draft's write,
  /// so a sign-out during either lands nothing (1.1: a fence against „after"
  /// stands at the last step).
  Future<void> _land(
    GameReviewRun run,
    GameReviewResult result,
    int epoch,
  ) async {
    for (var i = _boards.length - 1; i >= 0; i--) {
      final board = _boards[i];
      final chain = run.game.chainIn(board.reviewRoot);
      if (chain == null) continue;
      run._marked = _walker.markMistakes(
        chain: chain,
        result: result,
        side: run.options.side,
        insertAlternativeLine: run.options.insertBetterLine,
        words: run.words?.byPly ?? const {},
        insertRefutation: run.options.aiWords && run.options.insertBetterLine,
      );
      board.reviewLanded();
      run._landing = ReviewLanding.onBoard;
      return;
    }
    if (_boards.isNotEmpty) {
      run._landing = ReviewLanding.notLanded;
      return;
    }
    final loaded = await AnalysisDraftService.instance.load();
    if (loaded == null) {
      run._landing = ReviewLanding.notLanded;
      return;
    }
    final draft = loaded;
    final chain = run.game.chainIn(draft.rootNode);
    if (chain == null || !AccountLocalState.isCurrent(epoch)) {
      run._landing = ReviewLanding.notLanded;
      return;
    }
    run._marked = _walker.markMistakes(
      chain: chain,
      result: result,
      side: run.options.side,
      insertAlternativeLine: run.options.insertBetterLine,
      words: run.words?.byPly ?? const {},
      insertRefutation: run.options.aiWords && run.options.insertBetterLine,
    );
    await AnalysisDraftService.instance.flush(
      rootNode: draft.rootNode,
      currentNode: draft.resolveCurrentNode(),
      blackOrientation: draft.blackOrientation,
      epoch: epoch,
    );
    run._landing = ReviewLanding.inDraft;
  }
}
