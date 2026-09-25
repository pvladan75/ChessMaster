// Phase 4 of `docs/PLAN-SKELET.md`: one press, one run — a game becomes two
// tutorials, with no engine and no server in the test.
//
// The engine answers from fixture g01's own candidates, the masters walk from
// its own book, and the words from the answer the harness's run returned. So
// the chain is held to the harness at both ends: the request the run sends is
// the fixture's `wordsRequest`, and both tutorials have the fixture's parts.
//
// Every test here is a whole run — five to fifteen seconds alone — and under
// the full suite on 14.9.2026 five of them ran past the 30 s default, on the
// unchanged `master` as much as on the change being measured. The limit is
// the file's, so the next test added here does not find it one at a time.
@Timeout(Duration(minutes: 3))
library;

import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/eval_cache.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/facts_store.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/game_tutorial_run.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/sleep_watch.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/models/analysis_models.dart';

import 'support/facts_engine.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

final _fixture = jsonDecode(
    File('test/fixtures/game_tutorial/g01_scandinavian-defense.json')
        .readAsStringSync()) as Map<String, dynamic>;

String _withoutEp(String fen) {
  final f = fen.split(' ');
  return [f[0], f[1], f[2], f[4], f[5]].join(' ');
}

AnalysisLine _line(int rank, String eval, String san) => AnalysisLine(
      multipv: rank,
      depth: 18,
      evaluation: eval,
      bestMoveLan: '',
      bestMoveSan: san.split(' ').first,
      continuationLan: '',
      continuationSan: san,
      sanMoveList: san.split(' '),
      fenList: const [],
      fromSquare: '',
      toSquare: '',
    );

String _appEval(String factsEval) {
  if (factsEval.startsWith('#')) {
    final m = int.parse(factsEval.substring(1));
    return m > 0 ? 'M$m' : '-M${m.abs()}';
  }
  final v = double.parse(factsEval);
  return v > 0 ? '+${v.toStringAsFixed(2)}' : v.toStringAsFixed(2);
}

List<String> _uci() {
  final read = readStepTree(fen: _start, pgn: _fixture['plainPgn'] as String);
  return [
    for (var n = read.root; n.children.isNotEmpty; n = n.children.first)
      n.children.first.moveUci!
  ];
}

/// The engine, answering from g01's facts — the whole position from its
/// stored lines, the played move alone (the review's judge asks it, phase 1b
/// of docs/PLAN-ZAGONETKE-IZ-PARTIJE.md) from the stored answer of the
/// position after it; [onCall] sees every search.
MoveAnalyzer _fixtureEngine(void Function(int call) onCall) =>
    factsEngine(_fixture['facts'] as Map<String, dynamic>, onCall: onCall);

/// A line of [sans] from [fen], with its UCI moves, as a real engine gives it
/// — the judge and the store read the moves, not only the words.
AnalysisLine _real(
        String fen, int rank, int depth, String eval, List<String> sans) =>
    AnalysisLine.fromPv(
      multipv: rank,
      depth: depth,
      eval: eval,
      pvString: uciOfLine(fen, sans).join(' '),
      startingFen: fen,
    );

/// Any position: its first legal moves, all equal — a game with nothing to teach.
Future<List<AnalysisLine>> _flatEngine(String fen,
    {required int depth,
    required int multiPV,
    List<String>? searchMoves,
    Duration timeout = const Duration(seconds: 1)}) async {
  if (searchMoves != null && searchMoves.isNotEmpty) {
    final san = _sans(fen)
        .firstWhere((m) => uciOfLine(fen, [m]).single == searchMoves.first);
    return [
      _real(fen, 1, depth, '+0.10', [san])
    ];
  }
  final moves = _sans(fen);
  return [
    for (var i = 0; i < moves.length && i < 4; i++)
      _real(fen, i + 1, depth, '+0.10', [moves[i]])
  ];
}

String _after(String fen, String san) =>
    (chess.Chess.fromFEN(fen)..move(san)).fen;

List<String> _sans(String fen) =>
    chess.Chess.fromFEN(fen).moves().cast<String>();

bool _matesInOne(String fen) =>
    _sans(fen).any((m) => (chess.Chess.fromFEN(fen)..move(m)).in_checkmate);

/// Any position: equal moves, except that a mate in one is found and a move
/// allowing one is never offered — so a game's one blunder is its one moment.
/// Asked about one move alone, it says what that move allows.
Future<List<AnalysisLine>> _mateInOneEngine(String fen,
    {required int depth,
    required int multiPV,
    List<String>? searchMoves,
    Duration timeout = const Duration(seconds: 1)}) async {
  final whiteToMove = fen.split(' ')[1] == 'w';
  String mateFor(bool white) => white ? 'M1' : '-M1';
  if (searchMoves != null && searchMoves.isNotEmpty) {
    final san = _sans(fen)
        .firstWhere((m) => uciOfLine(fen, [m]).single == searchMoves.first);
    final after = _after(fen, san);
    final eval = chess.Chess.fromFEN(after).in_checkmate
        ? mateFor(whiteToMove)
        : _matesInOne(after)
            ? mateFor(!whiteToMove)
            : '+0.10';
    return [
      _real(fen, 1, depth, eval, [san])
    ];
  }
  final sans = _sans(fen);
  final mate =
      sans.where((m) => (chess.Chess.fromFEN(fen)..move(m)).in_checkmate);
  final safe = sans.where((m) => !_matesInOne(_after(fen, m)));
  final ordered = [...mate, ...safe.where((m) => !mate.contains(m))];
  if (ordered.length < 4) {
    ordered.addAll(sans.where((m) => !ordered.contains(m)));
  }
  return [
    for (var i = 0; i < ordered.length && i < 4; i++)
      _real(
          fen,
          i + 1,
          depth,
          i == 0 && mate.isNotEmpty ? mateFor(whiteToMove) : '+0.10',
          [ordered[i]])
  ];
}

/// The masters answers g01's facts were built from, keyed by the app's FENs.
Future<MastersWalk> _fixtureMasters(List<String> fens) async {
  final rows = (_fixture['facts']['rows'] as List).cast<Map<String, dynamic>>();
  final known = <String, Map<String, dynamic>>{};
  for (var i = 0; i < rows.length; i++) {
    final book = rows[i]['book'] as Map<String, dynamic>?;
    if (book == null) break;
    final played = book['played'] as Map<String, dynamic>?;
    known[fens[i]] = {
      'white': book['games'],
      'draws': 0,
      'black': 0,
      if (book.containsKey('opening')) 'opening': {'name': book['opening']},
      'moves': [
        if (played != null && (played['games'] as num) > 0)
          {'san': played['move'], 'white': played['games']},
        for (final alt in book['alternatives'] as List)
          {'san': alt['move'], 'white': alt['games']},
      ],
    };
  }
  return (known: known, unavailable: null);
}

class _Rig {
  _Rig({
    MoveAnalyzer? engine,
    Future<MastersWalk> Function(List<String>)? masters,
    WordsOutcome? words,
    String? enginePath = 'C:/engine/stockfish.exe',
    Directory? storeDir,
    EvalCache? answers,
  })  : dir = storeDir ??
            Directory.systemTemp.createTempSync('game_tutorial_run_'),
        answers = answers ?? EvalCache() {
    runner = GameTutorialRunner(
      token: 'jwt',
      findEngine: () async => enginePath,
      identify: (path) async => 'engine-under-test',
      startEngines: (path, workers) async {
        started++;
        return (
          analyzers: [engine ?? _fixtureEngine((_) => searches++)],
          close: () => closed++,
        );
      },
      store: GameFactsStore(() async => dir),
      walkMasters: (fens) {
        walked++;
        return (masters ?? _fixtureMasters)(fens);
      },
      askWords: (request) async {
        requests.add(request);
        return words ??
            WordsOutcome.written(_fixture['answer'] as String, tokens: 9000);
      },
      // The engine's answers in memory, one store a rig, and no tablebase:
      // the judge then judges the endings on the engine, as when the
      // tablebase does not answer.
      answers: this.answers,
      tablebase: (_) async => null,
      workers: 1,
      sleepWatch: SleepWatch(now: () => DateTime(2026, 9, 14)),
    );
  }

  final Directory dir;
  final EvalCache answers;
  late final GameTutorialRunner runner;
  final requests = <Map<String, dynamic>>[];
  final stages = <GameTutorialStage>[];
  final progress = <GameTutorialProgress>[];
  int started = 0, closed = 0, walked = 0, searches = 0;

  Future<GameTutorialResult> run(
          {List<String>? moves,
          String startFen = _start,
          SkeletonParameters parameters = const SkeletonParameters(),
          Future<SkeletonParameters?> Function(GameTutorialSlice)?
              chooseSlice}) =>
      runner.run(
        gameName: 'g01',
        startFen: startFen,
        uciMoves: moves ?? _uci(),
        depth: 18,
        parameters: parameters,
        chooseSlice: chooseSlice,
        onProgress: (p) {
          progress.add(p);
          if (stages.isEmpty || stages.last != p.stage) stages.add(p.stage);
        },
      );
}

void main() {
  test('a game becomes both tutorials, through the harness\'s own request',
      () async {
    final rig = _Rig();
    addTearDown(() => rig.dir.deleteSync(recursive: true));
    final result = await rig.run();

    expect(rig.stages, [
      GameTutorialStage.engine,
      GameTutorialStage.masters,
      GameTutorialStage.analysis,
      GameTutorialStage.review,
      GameTutorialStage.words,
      GameTutorialStage.assembly,
    ]);
    final expected = _fixture['expected'] as Map<String, dynamic>;
    expect(jsonEncode(rig.requests.single['moments']),
        jsonEncode(expected['wordsRequest']['moments']));
    expect(rig.requests.single['game'], isNot(contains('[')));
    expect(result.keyMoments.partCount,
        (expected['tutorial']['positionList'] as List).length);
    expect(result.wholeGame.partCount,
        (expected['tutorialGame']['positionList'] as List).length);
    expect(result.keyMoments.title, expected['tutorial']['title']);
    expect(result.momentsOffered, (expected['moments'] as List).length);
    expect(result.searched, greaterThan(0));
    expect(result.tokens, 9000);
    expect(result.mastersNote, isNull);
    expect(rig.closed, 1,
        reason: 'the engines are closed when the facts are in');
    final analysis = rig.progress
        .where((p) => p.stage == GameTutorialStage.analysis)
        .toList();
    expect(analysis.first.secondsLeft, isNull,
        reason: 'no estimate before two positions have been searched');
  });

  // Point 3 of the owner's live pass, 14.9.2026. Every part used to adopt
  // `blackToMoveIn(fen)` — the fallback for a stored step that says nothing —
  // so a game tutorial turned the board over on every part whose side to move
  // had changed. Lesson 54 was saved with parts facing white, white, white,
  // white, black, black, black, white, white, white.
  //
  // And White, not the Analysis board's orientation: the owner's rule of the
  // same evening, after a tutorial whose first part alone had been turned.
  test('every part of both tutorials says White is at the bottom', () async {
    final rig = _Rig();
    addTearDown(() => rig.dir.deleteSync(recursive: true));
    final result = await rig.run();

    for (final tutorial in [result.keyMoments, result.wholeGame]) {
      expect(tutorial.positionList, isNotEmpty);
      for (var i = 0; i < tutorial.positionList.length; i++) {
        expect(tutorial.positionList[i]['blackOrientation'], isFalse,
            reason: 'part ${i + 1} of ${tutorial.title}');
      }
    }
  });

  // The fault this replaced was invisible to a test that only asked whether
  // the field was there: the fallback writes a bool on every part too. What
  // says the stamp happened is that the parts disagree with their own FENs.
  test('the orientation is one answer, not the side to move', () async {
    final rig = _Rig();
    addTearDown(() => rig.dir.deleteSync(recursive: true));
    final result = await rig.run();

    final sides = {
      for (final step in result.wholeGame.positionList)
        (step['fen'] as String).split(' ')[1]
    };
    expect(sides, containsAll(['w', 'b']),
        reason: 'the fixture game must have parts of both sides, or this '
            'test cannot tell a stamp from the fallback');
  });

  // Points 1 and 6 of the owner's live pass, 14.9.2026, as phase 1b of
  // docs/PLAN-ZAGONETKE-IZ-PARTIJE.md left them: no threshold, and what the
  // trainer hands back is what is taught. Rewritten openly on 25.9.2026 — it
  // held the pawn slider before (six moments at one pawn, four at two).
  test(
      "the count is the judge's, and the parameters handed back decide "
      'what is taught', () async {
    final rig = _Rig();
    addTearDown(() => rig.dir.deleteSync(recursive: true));

    GameTutorialSlice? seen;
    final expected = (_fixture['expected']['moments'] as List).length;
    final result = await rig.run(
      chooseSlice: (slice) async {
        seen = slice;
        return const SkeletonParameters(maxMoments: 2);
      },
    );

    expect(seen, isNotNull, reason: 'the trainer is asked before the words');
    expect(seen!.found, expected,
        reason: 'the count is the moments the fixture offers');
    expect(seen!.depth, 18);
    expect(expected, greaterThan(2),
        reason: 'the fixture must have more moments than the cap handed '
            'back, or this cannot tell the cap being used from it ignored');

    // The request is the proof: `momentsOffered` could be counted anywhere,
    // but what is sent is what the model is paid to write about.
    expect(rig.requests.single['moments'] as List, hasLength(2));
    expect(result.momentsOffered, 2);
  });

  // Phase 1b: the run asks the judge for the only moves too — g01 has none,
  // so without this nothing would see them dropped. g08 holds three, and the
  // run must reproduce its fixture's whole request, only moves and all.
  test('the only moves a player found reach the words, as the fixture has them',
      () async {
    final g08 = jsonDecode(
        File('test/fixtures/game_tutorial/g08_nimzowitsch-defense.json')
            .readAsStringSync()) as Map<String, dynamic>;
    final facts = g08['facts'] as Map<String, dynamic>;
    final read = readStepTree(fen: _start, pgn: g08['plainPgn'] as String);
    final moves = [
      for (var n = read.root; n.children.isNotEmpty; n = n.children.first)
        n.children.first.moveUci!
    ];
    final rig = _Rig(
      engine: factsEngine(facts),
      masters: (fens) => factsMasters(facts, fens),
      words: WordsOutcome.written(g08['answer'] as String, tokens: 1),
    );
    addTearDown(() => rig.dir.deleteSync(recursive: true));

    GameTutorialSlice? seen;
    await rig.run(
      moves: moves,
      chooseSlice: (slice) async {
        seen = slice;
        return slice.parameters;
      },
    );

    expect(seen!.counts, (mistakes: 2, onlyMoves: 3));
    expect(jsonEncode(rig.requests.single['moments']),
        jsonEncode(g08['expected']['wordsRequest']['moments']));
  });

  test('a trainer who stops at the count is charged nothing', () async {
    final rig = _Rig();
    addTearDown(() => rig.dir.deleteSync(recursive: true));

    await expectLater(
      rig.run(chooseSlice: (slice) async => null),
      throwsA(isA<GameTutorialStopped>()),
    );
    expect(rig.requests, isEmpty, reason: 'the words are what costs');
    expect(rig.searches, greaterThan(0),
        reason: 'the engine had already run, and its answers are kept');
  });

  test('the count is said whole, and the cap is said separately', () async {
    final rig = _Rig();
    addTearDown(() => rig.dir.deleteSync(recursive: true));

    GameTutorialSlice? seen;
    await rig.run(chooseSlice: (slice) async {
      seen = slice;
      return slice.parameters;
    });

    // Below the cap the two numbers agree.
    expect(seen!.parts, seen!.found);

    // Above it they must not: „23 found" over a tutorial of eight parts reads
    // as a fault in the tutorial, so the dialog says both numbers and this
    // says they are two.
    final capped = GameTutorialSlice(
        facts: seen!.facts,
        parameters: const SkeletonParameters(maxMoments: 2));
    expect(capped.parts, 2);
    expect(capped.parts, lessThan(capped.found));
  });

  test('the second run of the same game searches nothing', () async {
    final first = _Rig();
    addTearDown(() => first.dir.deleteSync(recursive: true));
    await first.run();
    // The same store of answers, as on one computer: the judge's own
    // questions are kept there as well as the facts' (phase 1b).
    final again = _Rig(storeDir: first.dir, answers: first.answers);
    final result = await again.run();
    expect(again.searches, 0);
    expect(result.searched, 0);
    expect(result.keyMoments.partCount, greaterThan(0));
  });

  test('no local engine stops at once, offering the download, and asks nothing',
      () async {
    final rig = _Rig(enginePath: null);
    addTearDown(() => rig.dir.deleteSync(recursive: true));
    await expectLater(
      rig.run(),
      throwsA(isA<GameTutorialStopped>()
          .having((s) => s.kind, 'kind', 'no-engine')
          .having((s) => s.offerEngineDownload, 'offer', isTrue)),
    );
    expect(rig.walked, 0);
    expect(rig.started, 0);
    expect(rig.requests, isEmpty);
  });

  test('the masters database unreachable is a note, not a stop', () async {
    final rig = _Rig(
        masters: (fens) async => (
              known: const <String, Map<String, dynamic>>{},
              unavailable: 'network'
            ));
    addTearDown(() => rig.dir.deleteSync(recursive: true));
    final result = await rig.run();
    expect(result.mastersNote, contains('network'));
    expect(result.keyMoments.openable, isTrue);
  });

  test('fewer than two moments stops before the words, and spends nothing',
      () async {
    // Its own masters answer: g01's book has more positions than this game.
    final rig = _Rig(
        engine: _flatEngine,
        masters: (fens) async =>
            (known: const <String, Map<String, dynamic>>{}, unavailable: null));
    addTearDown(() => rig.dir.deleteSync(recursive: true));
    await expectLater(
      rig.run(moves: const ['e2e4', 'e7e5', 'g1f3', 'b8c6']),
      throwsA(isA<GameTutorialStopped>()
          .having((s) => s.kind, 'kind', 'too-few-moments')
          .having((s) => s.message, 'message', contains('Nothing was spent'))),
    );
    expect(rig.requests, isEmpty);
    expect(rig.closed, 1);
  });

  test('one moment is not enough for a tutorial, and spends nothing', () async {
    // 1. e4 e5 2. Qh5 Nc6 3. Bc4 Nf6?? — the one move that allows mate.
    final rig = _Rig(
        engine: _mateInOneEngine,
        masters: (fens) async =>
            (known: const <String, Map<String, dynamic>>{}, unavailable: null));
    addTearDown(() => rig.dir.deleteSync(recursive: true));
    await expectLater(
      rig.run(moves: const ['e2e4', 'e7e5', 'd1h5', 'b8c6', 'f1c4', 'g8f6']),
      throwsA(isA<GameTutorialStopped>()
          .having((s) => s.kind, 'kind', 'too-few-moments')
          .having((s) => s.message, 'message', contains('Only one moment'))),
    );
    expect(rig.requests, isEmpty);
  });

  test('a refusal from the words route is its sentence, with the upgrade flag',
      () async {
    final rig = _Rig(
        words: const WordsOutcome.refused(WordsRefusal('upgrade-required',
            'Making a tutorial from a game is part of a Premium account.')));
    addTearDown(() => rig.dir.deleteSync(recursive: true));
    await expectLater(
      rig.run(),
      throwsA(isA<GameTutorialStopped>()
          .having((s) => s.kind, 'kind', 'upgrade-required')
          .having((s) => s.upgradeRequired, 'upgrade', isTrue)),
    );
  });

  test('a cancel mid-search closes the engines and keeps what was searched',
      () async {
    late _Rig rig;
    var calls = 0;
    var closedAtCancel = -1;
    final base = _fixtureEngine((_) {});
    rig = _Rig(engine: (String fen,
        {required int depth,
        required int multiPV,
        List<String>? searchMoves,
        Duration timeout = const Duration(seconds: 1)}) async {
      calls++;
      if (calls == 3) {
        rig.runner.cancel();
        closedAtCancel = rig.closed;
        throw StateError('the engine has been closed');
      }
      return base(fen,
          depth: depth,
          multiPV: multiPV,
          searchMoves: searchMoves,
          timeout: timeout);
    });
    addTearDown(() => rig.dir.deleteSync(recursive: true));
    await expectLater(
      rig.run(),
      throwsA(isA<GameTutorialStopped>()
          .having((s) => s.kind, 'kind', 'cancelled')),
    );
    expect(closedAtCancel, 1,
        reason: 'cancel closes the engines at once, not after the search');
    expect(rig.requests, isEmpty);
    final key = factsKey(
        startFen: _start,
        uciMoves: _uci(),
        depth: 18,
        engine: 'engine-under-test');
    expect(await GameFactsStore(() async => rig.dir).load(key), hasLength(2),
        reason: 'the two positions searched before the cancel are kept');
  });

  test('a game that cannot be played is said, before the engine starts',
      () async {
    final rig = _Rig();
    addTearDown(() => rig.dir.deleteSync(recursive: true));
    await expectLater(
      rig.run(moves: const ['e2e4', 'e2e4']),
      throwsA(
          isA<GameTutorialStopped>().having((s) => s.kind, 'kind', 'bad-game')),
    );
    expect(rig.started, 0);
  });
}
