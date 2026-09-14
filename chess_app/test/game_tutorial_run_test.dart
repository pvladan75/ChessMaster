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

import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/facts_store.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_parameters.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/game_tutorial_run.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/masters_walk.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/sleep_watch.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/words_client.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/models/analysis_models.dart';

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

/// The engine, answering from g01's facts; [onCall] sees every search.
PositionAnalyzer _fixtureEngine(void Function(int call) onCall) {
  final rows = (_fixture['facts']['rows'] as List).cast<Map<String, dynamic>>();
  final byPosition = {
    for (final r in rows)
      if ((r['candidates'] as List).isNotEmpty)
        _withoutEp(r['fen'] as String): r['candidates'] as List
  };
  var calls = 0;
  return (String fen,
      {required int depth,
      required int multiPV,
      Duration timeout = const Duration(seconds: 1)}) async {
    onCall(++calls);
    final cands = byPosition[_withoutEp(fen)]!;
    return [
      for (var i = 0; i < cands.length; i++)
        _line(i + 1, _appEval(cands[i]['eval'] as String),
            cands[i]['line'] as String)
    ];
  };
}

/// Any position: its first legal moves, all equal — a game with nothing to teach.
Future<List<AnalysisLine>> _flatEngine(String fen,
    {required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 1)}) async {
  final moves = chess.Chess.fromFEN(fen).moves();
  return [
    for (var i = 0; i < moves.length && i < 4; i++)
      _line(i + 1, '+0.10', moves[i] as String)
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
Future<List<AnalysisLine>> _mateInOneEngine(String fen,
    {required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 1)}) async {
  final sans = _sans(fen);
  final whiteToMove = fen.split(' ')[1] == 'w';
  final mate =
      sans.where((m) => (chess.Chess.fromFEN(fen)..move(m)).in_checkmate);
  final safe = sans.where((m) => !_matesInOne(_after(fen, m)));
  final ordered = [...mate, ...safe.where((m) => !mate.contains(m))];
  if (ordered.length < 4) {
    ordered.addAll(sans.where((m) => !ordered.contains(m)));
  }
  return [
    for (var i = 0; i < ordered.length && i < 4; i++)
      _line(
          i + 1,
          i == 0 && mate.isNotEmpty ? (whiteToMove ? 'M1' : '-M1') : '+0.10',
          ordered[i])
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
    PositionAnalyzer? engine,
    Future<MastersWalk> Function(List<String>)? masters,
    WordsOutcome? words,
    String? enginePath = 'C:/engine/stockfish.exe',
    Directory? storeDir,
  }) : dir = storeDir ??
            Directory.systemTemp.createTempSync('game_tutorial_run_') {
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
      workers: 1,
      sleepWatch: SleepWatch(now: () => DateTime(2026, 9, 14)),
    );
  }

  final Directory dir;
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

  // Points 1 and 6 of the owner's live pass, 14.9.2026. The threshold was a
  // constant nobody could reach; these say it reaches the words and the parts.
  test('the threshold the trainer chose decides what is taught', () async {
    final rig = _Rig();
    addTearDown(() => rig.dir.deleteSync(recursive: true));

    GameTutorialSlice? seen;
    final result = await rig.run(
      chooseSlice: (slice) async {
        seen = slice;
        // Two pawns is a coarser tutorial than one: on g01 six moments become
        // four. Not three pawns - that leaves one, and a tutorial of one is
        // refused before the words, so the run would stop and prove nothing.
        return slice.parameters.withMinCost(2.0);
      },
    );

    expect(seen, isNotNull, reason: 'the trainer is asked before the words');
    expect(seen!.countAt(1.0), 6);
    expect(seen!.countAt(2.0), 4,
        reason: 'the fixture must have moments between the two, or this test '
            'cannot tell the threshold being used from it being ignored');

    // The request is the proof: `momentsOffered` could be counted anywhere,
    // but what is sent is what the model is paid to write about.
    expect(rig.requests.single['moments'] as List, hasLength(4));
    expect(result.momentsOffered, 4);
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
    expect(seen!.countAt(2.0), 4);
    expect(seen!.partsAt(2.0), 4);

    // Above it they must not: „23 found" over a tutorial of eight parts reads
    // as a fault in the tutorial, so the dialog says both numbers and this
    // says they are two.
    expect(seen!.countAt(0.2), 23);
    expect(seen!.partsAt(0.2), const SkeletonParameters().maxMoments);
    expect(seen!.partsAt(0.2), lessThan(seen!.countAt(0.2)));
  });

  test('the second run of the same game searches nothing', () async {
    final first = _Rig();
    addTearDown(() => first.dir.deleteSync(recursive: true));
    await first.run();
    final again = _Rig(storeDir: first.dir);
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
        Duration timeout = const Duration(seconds: 1)}) async {
      calls++;
      if (calls == 3) {
        rig.runner.cancel();
        closedAtCancel = rig.closed;
        throw StateError('the engine has been closed');
      }
      return base(fen, depth: depth, multiPV: multiPV, timeout: timeout);
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
