/// One press, one run: a game becomes two tutorials — phase 4 of
/// `docs/PLAN-SKELET.md`, „One button, one run".
///
/// The chain is the plan's: the local engine, the masters walk, the facts, the
/// moments, the words, and both tutorials assembled and read through the same
/// pre-flight a file import goes through. Every step that talks to the world is
/// a seam, so the whole chain runs in a test with no engine and no server.
///
/// **It stops by itself in exactly two places before anything is spent**: when
/// there is no local engine, and when the facts offer fewer than two moments.
/// Every other stop is a refusal from somewhere, said in a sentence
/// ([GameTutorialStopped]), and a cancel closes the engines at once and keeps
/// every position already searched.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/eval_cache.dart';
import 'package:chess_app/core/services/game_analysis_walker_service.dart'
    show BlunderAlertSide;
import 'package:chess_app/core/services/game_review_judge.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/game_facts.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/review_verdicts.dart'
    show applyReviewVerdicts;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart'
    show assembleSkeleton;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart'
    show momentCounts, skeletonMoments;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/words_request.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/facts_store.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/sleep_watch.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/uci_engine.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';

/// [review] is the review's own judge deciding which moves are mistakes
/// (`docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 1b), after the analysis.
enum GameTutorialStage { engine, masters, analysis, review, words, assembly }

/// Where the run is. [secondsLeft] is null for „no estimate", never zero: it is
/// a rate measured over this run's own searches, and there is none until two
/// positions have been searched.
class GameTutorialProgress {
  const GameTutorialProgress(this.stage,
      {this.done = 0, this.total = 0, this.secondsLeft});

  final GameTutorialStage stage;
  final int done;
  final int total;
  final int? secondsLeft;
}

/// A run that ended without tutorials, and what to tell the trainer.
class GameTutorialStopped implements Exception {
  const GameTutorialStopped(
    this.kind,
    this.message, {
    this.offerEngineDownload = false,
    this.upgradeRequired = false,
  });

  /// `no-engine`, `bad-game`, `engine-failed`, `cancelled`, `too-few-moments`,
  /// `bad-answer`, or the words route's own reason.
  final String kind;
  final String message;
  final bool offerEngineDownload;
  final bool upgradeRequired;

  @override
  String toString() => message;
}

/// Both tutorials, and what the run found on the way.
class GameTutorialResult {
  const GameTutorialResult({
    required this.keyMoments,
    required this.wholeGame,
    required this.report,
    required this.momentsOffered,
    this.mastersNote,
    this.searched = 0,
    this.tokens = 0,
  });

  final ImportedTutorial keyMoments;
  final ImportedTutorial wholeGame;

  /// `assembleSkeleton`'s report: chosen moments, missing and unused slots, and
  /// the claims the facts do not bear — reported, never patched.
  final Map<String, dynamic> report;
  final int momentsOffered;

  /// Why the tutorial says nothing about the opening, when it says nothing.
  final String? mastersNote;

  /// Positions the engine searched in this run; the rest came from the store.
  final int searched;
  final int tokens;

  List<String> _list(String key) =>
      [for (final v in (report[key] as List? ?? const [])) v.toString()];
  List<String> get claims => _list('claims');
  List<String> get missingSlots => _list('missing_slots');
}

/// The engines of one run. Each answers `searchmoves` too ([MoveAnalyzer]),
/// because the review's judge asks the played move alone; a [MoveAnalyzer] is
/// what the facts builder asks as well.
typedef FactsEngines = ({
  List<MoveAnalyzer> analyzers,
  void Function() close,
});

/// The downloaded engine's path, when there is one on disk.
Future<String?> localEnginePath() async {
  final prefs = await SharedPreferences.getInstance();
  final path = prefs.getString('custom_engine_path');
  if (path == null || path.isEmpty) return null;
  return File(path).existsSync() ? path : null;
}

Future<FactsEngines> startFactsEngines(String path, int workers) async {
  final pool = await UciEnginePool.start(path, workers: workers);
  return (analyzers: pool.moveAnalyzers, close: pool.close);
}

/// Every part of [tutorial] with White at the bottom, said on each part.
///
/// **Not part of the skeleton port, and it cannot be.** `skeleton.py` writes a
/// part's position and line and has no board to face. So the stamp happens
/// here, on the assembled tutorial, and `stepsFor` stays byte for byte what the
/// harness makes.
///
/// Without it every part adopts `blackToMoveIn(fen)` — the fallback a stored
/// step gets when it says nothing — and a game tutorial says nothing, so the
/// board turned over on every part whose side to move had changed. One game
/// became ten diagrams facing four different ways.
///
/// White, and not the orientation of the Analysis board the button was pressed
/// on: the owner's rule of 14.9.2026 is that a new tutorial opens with White at
/// the bottom everywhere, and that the trainer turns a part in „Preview
/// tutorial" or every part at once with the studio's flip. The orientation
/// Analysis happened to be left in was the one decision nobody made on purpose.
///
/// The map is copied rather than written through: the caller's assembly is read
/// again by the report, and a tutorial that changed under it would be a second
/// fault to find.
Map<String, dynamic> facingWhite(Map<String, dynamic> tutorial) => {
      ...tutorial,
      'positionList': [
        for (final step in (tutorial['positionList'] as List? ?? const []))
          {...(step as Map).cast<String, dynamic>(), 'blackOrientation': false},
      ],
    };

/// [tutorial] as a film is made of it: the parts that ask something are left
/// out, and everything that shows stays where it was.
///
/// The owner's rule of 14.9.2026 — „zbog videa se ne prave `ask_move` i
/// `ask_choice` delovi, već samo show". A question in a film is a board that
/// waits for an answer nobody can give. Asked in the last dialog rather than
/// before the run, because both versions come from the same words: choosing
/// costs nothing, and a trainer can open the other one afterwards.
///
/// Read back through [readTutorialJson] rather than filtered in place, so a
/// problem the pre-flight reports names the part by the number it has in
/// *this* tutorial.
ImportedTutorial showOnly(ImportedTutorial tutorial) => readTutorialJson(
      jsonEncode({
        'title': tutorial.title,
        if (tutorial.description != null) 'description': tutorial.description,
        'tags': tutorial.tags,
        if (tutorial.language != null) 'language': tutorial.language,
        'positionList': [
          for (final step in tutorial.positionList)
            if ((step['kind'] ?? 'show') == 'show') step,
        ],
      }),
      fileName: tutorial.fileName,
    );

/// What the trainer is shown once the engine and the judge are done and before
/// the words are paid for — point 6 of the owner's live pass, 14.9.2026.
///
/// **No threshold since phase 1b** (`docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, the
/// owner's word of 25.9.2026): the review's judge has decided which moves are
/// mistakes, and the only moves the player found are moments too. What is
/// left to show is how many there are, how many become parts, and — when the
/// game has too few — that it is clean at this depth rather than a threshold
/// to move.
class GameTutorialSlice {
  const GameTutorialSlice({
    required this.facts,
    required this.parameters,
    this.depth,
    this.unsettled = 0,
    this.unjudged = 0,
  });

  /// The engine's answers for the whole game, with the judge's verdicts.
  final Map<String, dynamic> facts;
  final SkeletonParameters parameters;

  /// The depth the verdicts stand on; null when it was not recorded.
  final int? depth;

  /// Moves the judge could not settle, and moves it could not judge — never
  /// mistakes, and never „clean".
  final int unsettled;
  final int unjudged;

  ({int mistakes, int onlyMoves}) get counts => momentCounts(facts);

  /// Every moment found, before the cap.
  int get found => counts.mistakes + counts.onlyMoves;

  /// How many of those become parts: the rest are over the cap.
  int get parts =>
      found < parameters.maxMoments ? found : parameters.maxMoments;
}

class GameTutorialRunner {
  GameTutorialRunner({
    required String token,
    Future<String?> Function()? findEngine,
    Future<String> Function(String path)? identify,
    Future<FactsEngines> Function(String path, int workers)? startEngines,
    GameFactsStore? store,
    Future<MastersWalk> Function(List<String> fens)? walkMasters,
    Future<WordsOutcome> Function(Map<String, dynamic> request)? askWords,
    EvalCache? answers,
    TablebaseLookup? tablebase,
    int? workers,
    SleepWatch? sleepWatch,
    DateTime Function()? now,
  })  : _findEngine = findEngine ?? localEnginePath,
        _identify = identify ?? engineIdentity,
        _startEngines = startEngines ?? startFactsEngines,
        _store = store ?? deviceFactsStore(),
        _walkMasters = walkMasters ??
            ((fens) async => walkMastersBook(fens,
                sessionToken: token, openingNameOf: await ecoOpeningNames())),
        _askWords = askWords ??
            ((request) => requestTutorialWords(request, token: token)),
        _answers = answers ?? EvalCache.instance,
        _tablebase = tablebase ?? SyzygyTablebaseService.instance.lookup,
        _workers = workers ?? defaultFactsWorkers(),
        _sleepWatch = sleepWatch ?? SleepWatch(),
        _now = now ?? DateTime.now;

  final Future<String?> Function() _findEngine;
  final Future<String> Function(String path) _identify;
  final Future<FactsEngines> Function(String path, int workers) _startEngines;
  final GameFactsStore _store;
  final Future<MastersWalk> Function(List<String> fens) _walkMasters;
  final Future<WordsOutcome> Function(Map<String, dynamic> request) _askWords;

  /// The engine's answers by position — the store the review keeps too
  /// (`EvalCache`, phase 1.1), so a game reviewed first costs the tutorial only
  /// what the review did not ask, and the reverse.
  final EvalCache _answers;
  final TablebaseLookup _tablebase;
  final int _workers;
  final SleepWatch _sleepWatch;
  final DateTime Function() _now;

  bool _cancelled = false;
  FactsEngines? _engines;
  GameReviewJudge? _judge;

  static const _cancelledStop = GameTutorialStopped('cancelled',
      'Cancelled. The positions already searched are kept for next time.');

  /// Stops the run: the engines are closed now, not after the position they
  /// are searching.
  void cancel() {
    _cancelled = true;
    _judge?.cancel();
    _engines?.close();
  }

  void _checkCancelled() {
    if (_cancelled) throw _cancelledStop;
  }

  Future<GameTutorialResult> run({
    required String gameName,
    required String startFen,
    required List<String> uciMoves,
    required int depth,
    SkeletonParameters parameters = const SkeletonParameters(),
    Future<SkeletonParameters?> Function(GameTutorialSlice slice)? chooseSlice,
    void Function(GameTutorialProgress progress)? onProgress,
  }) async {
    void say(GameTutorialProgress p) => onProgress?.call(p);

    say(const GameTutorialProgress(GameTutorialStage.engine));
    final path = await _findEngine();
    if (path == null) {
      throw const GameTutorialStopped(
        'no-engine',
        'Making a tutorial needs the chess engine on this computer. Download '
            'it in the engine settings, then try again.',
        offerEngineDownload: true,
      );
    }
    final List<Map<String, dynamic>> rows;
    try {
      rows = await gameRows(startFen: startFen, uciMoves: uciMoves);
    } on GameFactsException catch (e) {
      throw GameTutorialStopped('bad-game', e.message);
    }
    _checkCancelled();

    say(const GameTutorialProgress(GameTutorialStage.masters));
    final walk = await _walkMasters([for (final r in rows) r['fen'] as String]);
    final mastersNote = walk.unavailable == null
        ? null
        : 'The masters database could not be asked (${walk.unavailable}), so '
            'the tutorial says nothing about which moves masters play.';
    _checkCancelled();

    final identity = await _identify(path);
    final key = factsKey(
        startFen: startFen, uciMoves: uciMoves, depth: depth, engine: identity);
    final known = await _store.load(key);
    final recorder = _store.recorder(key, initial: known);

    final Map<String, dynamic> facts;
    GameReviewResult? reviewed;
    var searched = 0;
    final started = _now();
    // Named as the desktop engine names its answers (`answerStoreName`), so
    // the review and the tutorial on this computer share them.
    final storeName = 'exe:$identity';
    final tally = EngineAnswerTally();
    try {
      _engines = await _startEngines(path, _workers);
    } catch (e) {
      throw GameTutorialStopped(
          'engine-failed', 'The chess engine could not be started ($e).');
    }
    _sleepWatch.start();
    try {
      _checkCancelled();
      final asked = [
        for (final a in _engines!.analyzers)
          _answers.wrapMoves(a, engine: () async => storeName, tally: tally),
      ];
      facts = await GameFactsBuilder(
        analyzers: asked,
        depth: depth,
        sleeps: () => _sleepWatch.sleeps,
      ).build(
        game: gameName,
        startFen: startFen,
        uciMoves: uciMoves,
        masters: walk.known,
        known: known,
        engine: identity,
        cancelled: () => _cancelled,
        now: _now,
        onAnswer: (fen, candidates) {
          searched++;
          recorder.add(fen, candidates);
        },
        onProgress: (done, total) {
          final seconds = _now().difference(started).inMilliseconds / 1000.0;
          final left = searched >= 2 && done < total
              ? (seconds / searched * (total - done)).round()
              : null;
          say(GameTutorialProgress(GameTutorialStage.analysis,
              done: done, total: total, secondsLeft: left));
        },
      );

      // The review's own judge decides which moves are mistakes (phase 1b):
      // its walk and its two-line looks are served by the answers just
      // stored, so what it adds is only the played move alone and the
      // deepening where two looks disagree.
      _checkCancelled();
      say(const GameTutorialProgress(GameTutorialStage.review));
      final judge = GameReviewJudge(
        analyzer: asked.first,
        book: (_) async => walk,
        tablebase: _tablebase,
      );
      _judge = judge;
      reviewed = await judge.review(
        startingFen: startFen,
        uciMoves: uciMoves,
        depth: depth,
        puzzles: BlunderAlertSide.both,
        onProgress: (p) => say(GameTutorialProgress(GameTutorialStage.review,
            done: p.done, total: p.total)),
      );
      if (reviewed == null || _cancelled) throw _cancelledStop;
      applyReviewVerdicts(
          (facts['rows'] as List).cast<Map<String, dynamic>>(), reviewed);
    } on GameFactsCancelled {
      throw _cancelledStop;
    } on GameFactsException catch (e) {
      if (_cancelled) throw _cancelledStop;
      throw GameTutorialStopped('engine-failed', e.message);
    } finally {
      _judge = null;
      _sleepWatch.stop();
      _engines?.close();
      _engines = null;
      await recorder.flush();
    }

    // Asked before the words, because the words are what costs. A trainer who
    // wants a different slice gets it for nothing; one who cancels here has
    // spent nothing either.
    var sliced = parameters;
    if (chooseSlice != null) {
      _checkCancelled();
      final chosen = await chooseSlice(GameTutorialSlice(
        facts: facts,
        parameters: sliced,
        depth: depth,
        unsettled: reviewed.unsettled,
        unjudged: reviewed.unjudged,
      ));
      if (chosen == null) throw _cancelledStop;
      sliced = chosen;
    }

    final offered = skeletonMoments(facts, parameters: sliced);
    if (offered.length < 2) {
      throw GameTutorialStopped(
        'too-few-moments',
        offered.isEmpty
            ? 'No mistake found at depth $depth, and no move where only one '
                'held — nothing to teach from in this game.'
                '${_unsure(reviewed)} Nothing was spent.'
            : 'Only one moment in this game is worth teaching, and a tutorial '
                'needs two.${_unsure(reviewed)} Nothing was spent.',
      );
    }
    _checkCancelled();

    say(const GameTutorialProgress(GameTutorialStage.words));
    final sans = [
      for (final r in rows)
        if (r['played'] != null) (r['played'] as Map)['move'] as String
    ];
    final outcome = await _askWords(wordsRequestOf(facts,
        movetext: movetextOf(startFen, sans), parameters: sliced));
    final refusal = outcome.refusal;
    if (refusal != null) {
      throw GameTutorialStopped(refusal.reason, refusal.message,
          upgradeRequired: refusal.upgradeRequired);
    }

    say(const GameTutorialProgress(GameTutorialStage.assembly));
    final assembled =
        assembleSkeleton(facts, outcome.answerText!, parameters: sliced);
    if (assembled.tutorial == null || assembled.tutorialGame == null) {
      final problems =
          (assembled.report['problems'] as List? ?? const []).join('; ');
      throw GameTutorialStopped('bad-answer',
          'The words that came back did not fit this game ($problems).');
    }
    return GameTutorialResult(
      keyMoments: readTutorialJson(jsonEncode(facingWhite(assembled.tutorial!)),
          fileName: gameName),
      wholeGame: readTutorialJson(
          jsonEncode(facingWhite(assembled.tutorialGame!)),
          fileName: gameName),
      report: assembled.report,
      momentsOffered: offered.length,
      mastersNote: mastersNote,
      searched: searched,
      tokens: outcome.tokens,
    );
  }

  /// What keeps a game from being called clean: moves the looks still
  /// disagreed on, and moves the engine did not answer (the review's own rule,
  /// §3 — a game with either is never said to be clean).
  static String _unsure(GameReviewResult r) {
    final said = [
      if (r.unsettled > 0)
        ' The looks still disagreed on ${r.unsettled} move(s).',
      if (r.unjudged > 0)
        ' The engine did not answer on ${r.unjudged} move(s).',
    ];
    return said.join();
  }
}
