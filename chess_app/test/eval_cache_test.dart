import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:chess_app/core/services/eval_cache.dart';
import 'package:chess_app/models/analysis_models.dart';

const _fenA = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
const _fenB = 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1';

List<AnalysisLine> lines(String move) => [
      AnalysisLine(
        multipv: 1,
        depth: 14,
        evaluation: '+0.3',
        bestMoveLan: move,
        bestMoveSan: move,
        continuationLan: move,
        continuationSan: move,
        sanMoveList: [move],
        fenList: const [],
        fromSquare: move.substring(0, 2),
        toSquare: move.substring(2, 4),
      ),
    ];

/// Records every call so the tests can prove the engine was not asked twice.
class FakeEngine {
  final List<String> calls = [];
  final Map<String, Completer<List<AnalysisLine>>> pending = {};
  bool failNext = false;

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
    return Future.value(lines('e2e4'));
  }
}

void main() {
  group('caching', () {
    test('the same position is only searched once', () async {
      final engine = FakeEngine();
      final cache = EvalCache();
      final analyze = cache.wrap(engine.analyze);

      await analyze(_fenA, depth: 14, multiPV: 3);
      await analyze(_fenA, depth: 14, multiPV: 3);
      await analyze(_fenA, depth: 14, multiPV: 3);

      expect(engine.calls.length, 1,
          reason: 'the whole point is not paying twice');
      expect(cache.hits, 2);
      expect(cache.misses, 1);
    });

    test('different positions are searched separately', () async {
      final engine = FakeEngine();
      final analyze = EvalCache().wrap(engine.analyze);

      await analyze(_fenA, depth: 14, multiPV: 3);
      await analyze(_fenB, depth: 14, multiPV: 3);

      expect(engine.calls.length, 2);
    });

    test('a deeper search is not answered from a shallower one', () async {
      final engine = FakeEngine();
      final analyze = EvalCache().wrap(engine.analyze);

      await analyze(_fenA, depth: 14, multiPV: 3);
      await analyze(_fenA, depth: 22, multiPV: 3);

      // Serving depth 14 to someone who asked for 22 would silently downgrade
      // their analysis without anything looking wrong.
      expect(engine.calls.length, 2);
    });

    test('a wider search is not answered from a narrower one', () async {
      final engine = FakeEngine();
      final analyze = EvalCache().wrap(engine.analyze);

      await analyze(_fenA, depth: 14, multiPV: 1);
      await analyze(_fenA, depth: 14, multiPV: 3);

      expect(engine.calls.length, 2);
    });

    test('move counters are part of the key', () {
      // The halfmove clock changes what the engine reports near the fifty-move
      // rule, so positions that differ only there must not share a result.
      expect(
        EvalCache.keyFor('8/8/8/8/8/8/8/K6k w - - 0 1', 14, 3),
        isNot(EvalCache.keyFor('8/8/8/8/8/8/8/K6k w - - 99 60', 14, 3)),
      );
    });
  });

  group('concurrent requests', () {
    test('two callers asking at once share one engine run', () async {
      final engine = FakeEngine();
      final completer = Completer<List<AnalysisLine>>();
      engine.pending[_fenA] = completer;

      final analyze = EvalCache().wrap(engine.analyze);

      final first = analyze(_fenA, depth: 14, multiPV: 3);
      final second = analyze(_fenA, depth: 14, multiPV: 3);

      completer.complete(lines('e2e4'));
      final results = await Future.wait([first, second]);

      expect(engine.calls.length, 1,
          reason: 'a race must not start two searches');
      expect(results[0].first.bestMoveLan, results[1].first.bestMoveLan);
    });

    test('a failed search does not poison the entry', () async {
      final engine = FakeEngine()..failNext = true;
      final cache = EvalCache();
      final analyze = cache.wrap(engine.analyze);

      await expectLater(
        analyze(_fenA, depth: 14, multiPV: 3),
        throwsA(isA<StateError>()),
      );

      // A retry must reach the engine again rather than await a dead future.
      final retry = await analyze(_fenA, depth: 14, multiPV: 3);
      expect(retry, isNotEmpty);
      expect(engine.calls.length, 2);
    });
  });

  group('storing', () {
    test('an empty result is not cached', () async {
      final cache = EvalCache();
      cache.store(_fenA, 14, 3, const []);

      // An empty list means the engine gave nothing, which is a failure to
      // retry, not an answer to remember.
      expect(cache.peek(_fenA, 14, 3), isNull);
      expect(cache.size, 0);
    });

    test('the cache stays within its bound', () {
      final cache = EvalCache(maxEntries: 3);
      for (var i = 0; i < 10; i++) {
        cache.store('fen$i', 14, 3, lines('e2e4'));
      }
      expect(cache.size, 3);
    });

    test('eviction drops the least recently used entry', () {
      final cache = EvalCache(maxEntries: 2);
      cache.store('a', 14, 3, lines('a1a2'));
      cache.store('b', 14, 3, lines('b1b2'));

      // Touching 'a' should make 'b' the oldest.
      cache.store('a', 14, 3, lines('a3a4'));
      cache.store('c', 14, 3, lines('c1c2'));

      expect(cache.peek('a', 14, 3), isNotNull);
      expect(cache.peek('c', 14, 3), isNotNull);
      expect(cache.peek('b', 14, 3), isNull);
    });

    test('a stored result cannot be mutated by its caller', () {
      final cache = EvalCache();
      cache.store(_fenA, 14, 3, lines('e2e4'));

      expect(
        () => cache.peek(_fenA, 14, 3)!.add(lines('d2d4').first),
        throwsUnsupportedError,
      );
    });

    test('clear empties everything including the counters', () async {
      final engine = FakeEngine();
      final cache = EvalCache();
      final analyze = cache.wrap(engine.analyze);

      await analyze(_fenA, depth: 14, multiPV: 3);
      await analyze(_fenA, depth: 14, multiPV: 3);
      cache.clear();

      expect(cache.size, 0);
      expect(cache.hits, 0);
      expect(cache.misses, 0);
    });
  });
}
