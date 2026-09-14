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

import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/game_facts.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_assembly.dart'
    show assembleSkeleton;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart'
    show skeletonMoments;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/words_request.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/facts_store.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/sleep_watch.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/uci_engine.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';

enum GameTutorialStage { engine, masters, analysis, words, assembly }

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

typedef FactsEngines = ({
  List<PositionAnalyzer> analyzers,
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
  return (analyzers: pool.analyzers, close: pool.close);
}

/// Every part of [tutorial] drawn from one side, with [black] deciding which.
///
/// **Not part of the skeleton port, and it cannot be.** `skeleton.py` writes a
/// part's position and line and has no board to face; which way round a board
/// stands is a property of the screen the trainer pressed the button on. So the
/// stamp happens here, on the assembled tutorial, and `stepsFor` stays byte for
/// byte what the harness makes.
///
/// Without it every part adopts `blackToMoveIn(fen)` — the fallback a stored
/// step gets when it says nothing — and a game tutorial says nothing, so the
/// board turned over on every part whose side to move had changed. One game
/// became ten diagrams facing four different ways.
///
/// The map is copied rather than written through: the caller's assembly is read
/// again by the report, and a tutorial that changed under it would be a second
/// fault to find.
Map<String, dynamic> facingOneWay(Map<String, dynamic> tutorial, bool black) =>
    {
      ...tutorial,
      'positionList': [
        for (final step in (tutorial['positionList'] as List? ?? const []))
          {...(step as Map).cast<String, dynamic>(), 'blackOrientation': black},
      ],
    };

class GameTutorialRunner {
  GameTutorialRunner({
    required String token,
    Future<String?> Function()? findEngine,
    Future<String> Function(String path)? identify,
    Future<FactsEngines> Function(String path, int workers)? startEngines,
    GameFactsStore? store,
    Future<MastersWalk> Function(List<String> fens)? walkMasters,
    Future<WordsOutcome> Function(Map<String, dynamic> request)? askWords,
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
        _workers = workers ?? defaultFactsWorkers(),
        _sleepWatch = sleepWatch ?? SleepWatch(),
        _now = now ?? DateTime.now;

  final Future<String?> Function() _findEngine;
  final Future<String> Function(String path) _identify;
  final Future<FactsEngines> Function(String path, int workers) _startEngines;
  final GameFactsStore _store;
  final Future<MastersWalk> Function(List<String> fens) _walkMasters;
  final Future<WordsOutcome> Function(Map<String, dynamic> request) _askWords;
  final int _workers;
  final SleepWatch _sleepWatch;
  final DateTime Function() _now;

  bool _cancelled = false;
  FactsEngines? _engines;

  static const _cancelledStop = GameTutorialStopped('cancelled',
      'Cancelled. The positions already searched are kept for next time.');

  /// Stops the run: the engines are closed now, not after the position they
  /// are searching.
  void cancel() {
    _cancelled = true;
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
    required bool blackOrientation,
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
    var searched = 0;
    final started = _now();
    try {
      _engines = await _startEngines(path, _workers);
    } catch (e) {
      throw GameTutorialStopped(
          'engine-failed', 'The chess engine could not be started ($e).');
    }
    _sleepWatch.start();
    try {
      _checkCancelled();
      facts = await GameFactsBuilder(
        analyzers: _engines!.analyzers,
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
    } on GameFactsCancelled {
      throw _cancelledStop;
    } on GameFactsException catch (e) {
      if (_cancelled) throw _cancelledStop;
      throw GameTutorialStopped('engine-failed', e.message);
    } finally {
      _sleepWatch.stop();
      _engines?.close();
      _engines = null;
      await recorder.flush();
    }

    final offered = skeletonMoments(facts);
    if (offered.length < 2) {
      throw GameTutorialStopped(
        'too-few-moments',
        offered.isEmpty
            ? 'No move in this game cost a pawn or more, so there is no mistake '
                'to teach from. Nothing was spent.'
            : 'Only one moment in this game is worth teaching, and a tutorial '
                'needs two. Nothing was spent.',
      );
    }
    _checkCancelled();

    say(const GameTutorialProgress(GameTutorialStage.words));
    final sans = [
      for (final r in rows)
        if (r['played'] != null) (r['played'] as Map)['move'] as String
    ];
    final outcome = await _askWords(
        wordsRequestOf(facts, movetext: movetextOf(startFen, sans)));
    final refusal = outcome.refusal;
    if (refusal != null) {
      throw GameTutorialStopped(refusal.reason, refusal.message,
          upgradeRequired: refusal.upgradeRequired);
    }

    say(const GameTutorialProgress(GameTutorialStage.assembly));
    final assembled = assembleSkeleton(facts, outcome.answerText!);
    if (assembled.tutorial == null || assembled.tutorialGame == null) {
      final problems =
          (assembled.report['problems'] as List? ?? const []).join('; ');
      throw GameTutorialStopped('bad-answer',
          'The words that came back did not fit this game ($problems).');
    }
    return GameTutorialResult(
      keyMoments: readTutorialJson(
          jsonEncode(facingOneWay(assembled.tutorial!, blackOrientation)),
          fileName: gameName),
      wholeGame: readTutorialJson(
          jsonEncode(facingOneWay(assembled.tutorialGame!, blackOrientation)),
          fileName: gameName),
      report: assembled.report,
      momentsOffered: offered.length,
      mastersNote: mastersNote,
      searched: searched,
      tokens: outcome.tokens,
    );
  }
}
