// The engine's answers, by position — docs/PLAN-ZAGONETKE-IZ-PARTIJE.md §3,
// „The engine's answers are kept", phase 1.1.
//
// Until 24.9.2026 `EvalCache` held answers in memory, for the exact depth and
// number of lines asked, cleared with every engine start — and filed a search
// stopped by its timeout under the depth asked, which on the phone at depth 20
// is a normal day. Now it keeps what the engine reached, on disk, by engine
// and by account, and a deeper answer serves a shallower question.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/core/services/eval_cache.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/account_local_state.dart';

const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _afterE4 = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';

/// White to move with one legal move: Kb1 is the only one (a1 king, rook on
/// the second rank, bishop's diagonal covered).
const _oneMove = '8/8/8/8/8/8/1r6/K5k1 w - - 0 1';

/// Sixteen plies from the start — longer than any reader's cut.
const _longLine =
    'e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7 f1e1 b7b5 a4b3 d7d6 c2c3 e8g8';

Future<String?> _a() async => 'engine-a';
Future<String?> _b() async => 'engine-b';
Future<String?> _unnamed() async => null;

/// An engine that answers each question with [depthReached] (the depth asked
/// when null) and [lines] lines, and records every question.
class FakeEngine {
  final List<String> calls = [];
  final Map<String, Completer<List<AnalysisLine>>> pending = {};
  bool failNext = false;
  int? depthReached;
  int? lines;
  bool empty = false;

  Future<List<AnalysisLine>> analyze(
    String fen, {
    required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 10),
  }) {
    calls.add('$fen|$depth|$multiPV');
    if (failNext) {
      failNext = false;
      return Future.error(StateError('engine died'));
    }
    final completer = pending[fen];
    if (completer != null) return completer.future;
    if (empty) return Future.value(const []);
    final d = depthReached ?? depth;
    return Future.value([
      for (var k = 1; k <= (lines ?? multiPV); k++)
        AnalysisLine.fromPv(
          multipv: k,
          depth: d,
          eval: '+0.${k}0',
          pvString: fen == _start
              ? (k == 1 ? _longLine : 'd2d4 d7d5')
              : fen == _oneMove
                  ? 'a1b1'
                  : 'e7e5 g1f3',
          startingFen: fen,
        ),
    ]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory folder;
  AnswerDisk diskIn(Directory d) => AnswerDisk(() async => d);

  setUp(() {
    folder = Directory.systemTemp.createTempSync('engine_answers_');
    addTearDown(() {
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    });
  });

  group('what serves a question', () {
    test('the same position is only searched once', () async {
      final engine = FakeEngine();
      final cache = EvalCache();
      final analyze = cache.wrap(engine.analyze, engine: _a);

      await analyze(_start, depth: 14, multiPV: 3);
      await analyze(_start, depth: 14, multiPV: 3);
      await analyze(_start, depth: 14, multiPV: 3);

      expect(engine.calls, hasLength(1));
      expect(cache.hits, 2);
      expect(cache.misses, 1);
    });

    test('different positions are searched separately', () async {
      final engine = FakeEngine();
      final analyze = EvalCache().wrap(engine.analyze, engine: _a);
      await analyze(_start, depth: 14, multiPV: 3);
      await analyze(_afterE4, depth: 14, multiPV: 3);
      expect(engine.calls, hasLength(2));
    });

    test('a deeper question is not answered from a shallower answer', () async {
      final engine = FakeEngine();
      final analyze = EvalCache().wrap(engine.analyze, engine: _a);
      await analyze(_start, depth: 14, multiPV: 3);
      await analyze(_start, depth: 22, multiPV: 3);
      expect(engine.calls, hasLength(2));
    });

    test('a wider question is not answered from a narrower answer', () async {
      final engine = FakeEngine();
      final analyze = EvalCache().wrap(engine.analyze, engine: _a);
      await analyze(_start, depth: 14, multiPV: 1);
      await analyze(_start, depth: 14, multiPV: 2);
      expect(engine.calls, hasLength(2));
    });

    test(
        'a deeper and wider answer serves a shallower, narrower question, '
        'cut to the lines asked', () async {
      final engine = FakeEngine();
      final tally = EngineAnswerTally();
      final analyze =
          EvalCache().wrap(engine.analyze, engine: _a, tally: tally);

      await analyze(_start, depth: 24, multiPV: 2);
      final served = await analyze(_start, depth: 20, multiPV: 1);

      expect(engine.calls, hasLength(1));
      expect(served, hasLength(1));
      expect(served.single.depth, 24,
          reason: 'the answer says the depth it has, not the one asked');
      expect(tally.fromStore, 1);
      expect(tally.searched, 1);
    });

    test('of several answers the deepest that serves is given', () async {
      final engine = FakeEngine();
      final analyze = EvalCache().wrap(engine.analyze, engine: _a);
      await analyze(_start, depth: 20, multiPV: 1);
      await analyze(_start, depth: 26, multiPV: 1);
      final served = await analyze(_start, depth: 18, multiPV: 1);
      expect(served.single.depth, 26);
    });

    test('positions that differ only in the move counters are apart', () async {
      // The halfmove clock changes what the engine reports near the
      // fifty-move rule, so a draw score must not travel between them.
      final engine = FakeEngine();
      final analyze = EvalCache().wrap(engine.analyze, engine: _a);
      await analyze('8/8/8/8/8/8/8/K6k w - - 0 1', depth: 14, multiPV: 1);
      await analyze('8/8/8/8/8/8/8/K6k w - - 99 60', depth: 14, multiPV: 1);
      expect(engine.calls, hasLength(2));
    });

    test('two engines never answer for each other', () async {
      final engine = FakeEngine();
      final cache = EvalCache();
      await cache.wrap(engine.analyze, engine: _a)(_start,
          depth: 20, multiPV: 1);
      await cache.wrap(engine.analyze, engine: _b)(_start,
          depth: 20, multiPV: 1);
      expect(engine.calls, hasLength(2));
    });
  });

  group('what is kept', () {
    test(
        'a search stopped short of the depth asked is kept at the depth it '
        'reached, and counted', () async {
      final engine = FakeEngine()..depthReached = 17;
      final tally = EngineAnswerTally();
      final analyze =
          EvalCache().wrap(engine.analyze, engine: _a, tally: tally);

      final first = await analyze(_start, depth: 20, multiPV: 1);
      expect(first.single.depth, 17,
          reason: 'the caller is handed what the engine gave');
      expect(tally.short, 1);

      await analyze(_start, depth: 20, multiPV: 1);
      expect(engine.calls, hasLength(2),
          reason: 'a depth-17 answer filed under 20 is a guess labelled 20');

      await analyze(_start, depth: 17, multiPV: 1);
      expect(engine.calls, hasLength(2), reason: 'it does answer 17');
    });

    test('lines of different depths are kept at the shallowest', () async {
      final engine = FakeEngine();
      final cache = EvalCache();
      final analyze = cache.wrap(
          (fen, {required depth, required multiPV, timeout = Duration.zero}) =>
              Future.value([
                AnalysisLine.fromPv(
                    multipv: 1,
                    depth: 20,
                    eval: '+0.3',
                    pvString: 'e2e4',
                    startingFen: fen),
                AnalysisLine.fromPv(
                    multipv: 2,
                    depth: 18,
                    eval: '+0.2',
                    pvString: 'd2d4',
                    startingFen: fen),
              ]),
          engine: _a);
      await analyze(_start, depth: 20, multiPV: 2);
      final again =
          cache.wrap(engine.analyze, engine: _a); // the same store, a new door
      await again(_start, depth: 19, multiPV: 2);
      expect(engine.calls, hasLength(1), reason: '18 does not answer 19');
      await again(_start, depth: 18, multiPV: 2);
      expect(engine.calls, hasLength(1), reason: '18 answers 18');
    });

    test('an answer missing a line asked for is not kept', () async {
      final engine = FakeEngine()..lines = 1;
      final tally = EngineAnswerTally();
      final analyze =
          EvalCache().wrap(engine.analyze, engine: _a, tally: tally);
      await analyze(_start, depth: 20, multiPV: 2);
      await analyze(_start, depth: 20, multiPV: 1);
      expect(engine.calls, hasLength(2),
          reason: 'one line of two is not the answer to either question');
      expect(tally.incomplete, 1);
    });

    test(
        'where there are fewer legal moves than lines asked, every legal '
        'move is a whole answer', () async {
      final engine = FakeEngine()..lines = 1;
      final tally = EngineAnswerTally();
      final analyze =
          EvalCache().wrap(engine.analyze, engine: _a, tally: tally);
      await analyze(_oneMove, depth: 20, multiPV: 2);
      await analyze(_oneMove, depth: 20, multiPV: 2);
      expect(engine.calls, hasLength(1));
      expect(tally.incomplete, 0);
    });

    test('an empty answer is a failure to retry, not an answer', () async {
      final engine = FakeEngine()..empty = true;
      final analyze = EvalCache().wrap(engine.analyze, engine: _a);
      await analyze(_start, depth: 14, multiPV: 1);
      await analyze(_start, depth: 14, multiPV: 1);
      expect(engine.calls, hasLength(2));
    });

    test('the whole line is kept', () async {
      final engine = FakeEngine();
      final disk = diskIn(folder);
      final cache = EvalCache(disk: disk);
      await cache.wrap(engine.analyze, engine: _a)(_start,
          depth: 20, multiPV: 1);
      await cache.flush();

      final next = EvalCache(disk: disk);
      final served = await next.wrap(engine.analyze, engine: _a)(_start,
          depth: 20, multiPV: 1);
      expect(served.single.continuationLan, _longLine);
      expect(served.single.sanMoveList, hasLength(16));
    });

    test('several depths are kept, the deepest first, up to the limit',
        () async {
      final engine = FakeEngine();
      final disk = diskIn(folder);
      final cache = EvalCache(disk: disk, maxAnswersPerPosition: 2);
      final analyze = cache.wrap(engine.analyze, engine: _a);
      for (final d in [16, 20, 24]) {
        await analyze(_start, depth: d, multiPV: 1);
      }
      await cache.flush();

      final file = folder
          .listSync(recursive: true)
          .whereType<File>()
          .singleWhere((f) => f.path.endsWith('.json'));
      final data = jsonDecode(file.readAsStringSync()) as Map;
      final answers = (data['positions'] as Map)[_start] as List;
      expect([for (final a in answers) (a as Map)['depth']], [24, 20]);
    });
  });

  group('on disk', () {
    test('a second run is answered from what the first one kept', () async {
      final engine = FakeEngine();
      final disk = diskIn(folder);
      final first = EvalCache(disk: disk);
      await first.wrap(engine.analyze, engine: _a)(_start,
          depth: 20, multiPV: 2);
      await first.flush();

      final tally = EngineAnswerTally();
      final second = EvalCache(disk: disk);
      final served = await second.wrap(engine.analyze,
          engine: _a, tally: tally)(_start, depth: 20, multiPV: 2);
      expect(engine.calls, hasLength(1));
      expect(tally.fromStore, 1);
      expect(served.map((l) => l.bestMoveLan), ['e2e4', 'd2d4']);
      expect(served.first.evaluation, '+0.10');
    });

    test('an engine with no name is remembered for the run, never written',
        () async {
      final engine = FakeEngine();
      final cache = EvalCache(disk: diskIn(folder));
      final analyze = cache.wrap(engine.analyze, engine: _unnamed);
      await analyze(_start, depth: 20, multiPV: 1);
      await analyze(_start, depth: 20, multiPV: 1);
      await cache.flush();
      expect(engine.calls, hasLength(1));
      expect(folder.listSync(recursive: true).whereType<File>(), isEmpty);
    });

    test('a file that cannot be read is an empty store', () async {
      final engine = FakeEngine();
      final disk = diskIn(folder);
      final first = EvalCache(disk: disk);
      await first.wrap(engine.analyze, engine: _a)(_start,
          depth: 20, multiPV: 1);
      await first.flush();
      for (final f in folder.listSync(recursive: true).whereType<File>()) {
        f.writeAsStringSync('{"version": 1, "engine": "engine-a", "posi');
      }

      final second = EvalCache(disk: disk);
      await second.wrap(engine.analyze, engine: _a)(_start,
          depth: 20, multiPV: 1);
      expect(engine.calls, hasLength(2));
    });

    test('a shard keeps at most its limit, the least recently used dropped',
        () async {
      // Three positions of one shard, told apart by the move counter.
      final byShard = <String, List<String>>{};
      for (var n = 1; byShard.values.every((l) => l.length < 3); n++) {
        final fen = '8/8/8/8/8/8/8/K6k w - - 0 $n';
        byShard.putIfAbsent(EvalCache.shardOf(fen), () => []).add(fen);
      }
      final [p, q, r] = byShard.values.firstWhere((l) => l.length == 3);

      final engine = FakeEngine();
      final cache = EvalCache(maxPositionsPerShard: 2);
      final analyze = cache.wrap(engine.analyze, engine: _a);
      await analyze(p, depth: 10, multiPV: 1);
      await analyze(q, depth: 10, multiPV: 1);
      await analyze(p, depth: 10, multiPV: 1); // p is used again
      await analyze(r, depth: 10, multiPV: 1); // q is the oldest now
      expect(engine.calls, hasLength(3));

      await analyze(p, depth: 10, multiPV: 1);
      await analyze(r, depth: 10, multiPV: 1);
      expect(engine.calls, hasLength(3));
      await analyze(q, depth: 10, multiPV: 1);
      expect(engine.calls, hasLength(4));
    });
  });

  group('concurrent requests', () {
    test('two callers asking at once share one engine run', () async {
      final engine = FakeEngine();
      final completer = Completer<List<AnalysisLine>>();
      engine.pending[_start] = completer;
      final analyze = EvalCache().wrap(engine.analyze, engine: _a);

      final first = analyze(_start, depth: 14, multiPV: 1);
      final second = analyze(_start, depth: 14, multiPV: 1);
      // Both callers are past the shard's read before the answer comes.
      await Future<void>.delayed(Duration.zero);
      completer.complete([
        AnalysisLine.fromPv(
            multipv: 1,
            depth: 14,
            eval: '+0.3',
            pvString: 'e2e4',
            startingFen: _start)
      ]);
      final results = await Future.wait([first, second]);

      expect(engine.calls, hasLength(1));
      expect(results[0].first.bestMoveLan, results[1].first.bestMoveLan);
    });

    test('a failed search does not poison the entry', () async {
      final engine = FakeEngine()..failNext = true;
      final analyze = EvalCache().wrap(engine.analyze, engine: _a);
      await expectLater(
          analyze(_start, depth: 14, multiPV: 1), throwsA(isA<StateError>()));
      final retry = await analyze(_start, depth: 14, multiPV: 1);
      expect(retry, isNotEmpty);
      expect(engine.calls, hasLength(2));
    });
  });

  group('the account', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      // The tutorial's store is wiped beside this one and asks the platform
      // for its folder.
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async => folder.path);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    });

    test('forgetting the account empties memory and disk', () async {
      final engine = FakeEngine();
      final disk = diskIn(folder);
      final cache = EvalCache(disk: disk);
      final analyze = cache.wrap(engine.analyze, engine: _a);
      await analyze(_start, depth: 20, multiPV: 1);
      await cache.flush();

      await cache.forgetAccount();
      expect(cache.size, 0);
      expect(
          await EvalCache(disk: disk).wrap(engine.analyze, engine: _a)(_start,
              depth: 20, multiPV: 1),
          isNotEmpty);
      expect(engine.calls, hasLength(2),
          reason: 'the disk still answered for the last account');
    });

    test('a search begun before a sign-out keeps nothing after it', () async {
      final engine = FakeEngine();
      final completer = Completer<List<AnalysisLine>>();
      engine.pending[_start] = completer;
      final disk = diskIn(folder);
      final cache = EvalCache(disk: disk);
      final analyze = cache.wrap(engine.analyze, engine: _a);

      final running = analyze(_start, depth: 20, multiPV: 1);
      await Future<void>.delayed(Duration.zero);
      await AccountLocalState.clear();
      completer.complete([
        AnalysisLine.fromPv(
            multipv: 1,
            depth: 20,
            eval: '+0.3',
            pvString: 'e2e4',
            startingFen: _start)
      ]);
      await running;
      await cache.flush();
      expect(
          folder
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.json')),
          isEmpty,
          reason: 'the last account\'s answer was written after the wipe');

      engine.pending.clear();
      await analyze(_start, depth: 20, multiPV: 1);
      expect(engine.calls, hasLength(2),
          reason: 'the last account\'s answer was kept for the next one');
    });

    test('a write already under way at a sign-out lands nothing after it',
        () async {
      // The shard is read at once; the write is held after it began and
      // before its file lands, until the test lets it through.
      final release = Completer<void>();
      var asked = 0;
      final disk = AnswerDisk(() async {
        if (asked++ > 0) await release.future;
        return folder;
      });
      final engine = FakeEngine();
      final cache = EvalCache(disk: disk);
      await cache.wrap(engine.analyze, engine: _a)(_start,
          depth: 20, multiPV: 1);
      await Future<void>.delayed(Duration.zero);
      expect(asked, 2, reason: 'the write has not started');
      await AccountLocalState.clear();
      release.complete();
      await cache.flush();
      expect(
          folder
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => f.path.endsWith('.json')),
          isEmpty,
          reason: 'the last account\'s answer landed after the wipe');
    });

    test('a sign-out forgets the shared store', () async {
      final engine = FakeEngine();
      final analyze = EvalCache.instance.wrap(engine.analyze, engine: _unnamed);
      await analyze(_start, depth: 20, multiPV: 1);
      await AccountLocalState.clear();
      await AccountLocalState.engineAnswersWiped;
      await analyze(_start, depth: 20, multiPV: 1);
      expect(engine.calls, hasLength(2));
    });
  });
}
