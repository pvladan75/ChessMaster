// Phase 2 of `docs/PLAN-SKELET.md`: the engine half of building a game's facts.
//
// The engine here is a script that answers UCI commands the way Stockfish
// does. What these tests hold is the protocol and the reading — an empty hash
// before every search, the White-relative spelling the rest of the app reads,
// the last exact line per rank, a stop that is waited for — and the sleep
// watch. Whether the facts built this way match the harness is not asked here:
// `tool/game_facts.dart` asks that of the real binary.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/sleep_watch.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/uci_engine.dart';

const _open =
    'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';
const _blackToMove =
    'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3';

/// Stockfish, as far as these tests need it: [onGo] decides what a search
/// prints, and nothing is printed until [answerStop] allows it.
class _Script {
  _Script({required this.onGo, this.answerStop = true});

  /// Not final: a test may change what the next search prints.
  List<String> Function(String go) onGo;
  final bool answerStop;
  final sent = <String>[];
  final _out = StreamController<String>.broadcast();
  bool killed = false;
  bool _holding = false;

  late final engine = UciEngine.fromStreams(_out.stream, _receive,
      kill: () => killed = true,
      stopTimeout: const Duration(milliseconds: 200));

  void _emit(List<String> lines) =>
      scheduleMicrotask(() => lines.forEach(_out.add));

  void _receive(String command) {
    for (final c in command.split('\n')) {
      sent.add(c);
      if (c == 'uci') _emit(['id name Script', 'uciok']);
      if (c == 'isready') _emit(['readyok']);
      if (c.startsWith('go ')) {
        final lines = onGo(c);
        _holding = lines.isEmpty || !lines.last.startsWith('bestmove');
        _emit(lines);
      }
      if (c == 'stop' && _holding && answerStop) {
        _holding = false;
        _emit(['bestmove e2e4']);
      }
    }
  }
}

void main() {
  group('reading UCI', () {
    test('an exact line with a pv is read; bounds and bare lines are not', () {
      expect(
          parseUciInfo('info depth 18 seldepth 25 multipv 2 score cp -35 '
              'nodes 1 pv e7e5 g1f3'),
          (rank: 2, depth: 18, cp: -35, mate: null, pv: 'e7e5 g1f3'));
      expect(
          parseUciInfo(
              'info depth 18 multipv 1 score cp 12 lowerbound pv e2e4'),
          isNull);
      expect(
          parseUciInfo(
              'info depth 18 multipv 1 score cp 12 upperbound pv e2e4'),
          isNull);
      expect(
          parseUciInfo('info depth 18 currmove e2e4 currmovenumber 1'), isNull);
      expect(parseUciInfo('info string NNUE evaluation enabled'), isNull);
      expect(parseUciInfo('info depth 9 score mate -3 pv h7h6')?.mate, -3);
      expect(parseUciInfo('info depth 9 score mate -3 pv h7h6')?.rank, 1,
          reason: 'a single-line search does not say multipv');
    });

    test('seldepth is not read as the depth', () {
      expect(
          parseUciInfo('info seldepth 30 depth 18 score cp 1 pv e2e4')?.depth,
          18);
    });

    test('scores are written from White\'s side, as the app writes them', () {
      String eval(String fen, {int? cp, int? mate}) => analysisLineOf(
          fen, (rank: 1, depth: 18, cp: cp, mate: mate, pv: 'e2e4')).evaluation;
      // Only the evaluation is asked here. `fromPv` stops quietly at a move it
      // cannot play, so `e2e4` in Black's position leaves an empty line, which
      // the builder's own check refuses elsewhere.
      expect(eval(_open, cp: 35), '+0.35');
      expect(eval(_open, cp: 0), '0.00');
      expect(eval(_open, cp: -120), '-1.20');
      expect(eval(_blackToMove, cp: 35), '-0.35');
      expect(eval(_blackToMove, cp: -35), '+0.35');
      expect(eval(_open, mate: 3), 'M3');
      expect(eval(_blackToMove, mate: 2), '-M2');
      expect(eval(_blackToMove, mate: -2), 'M2');
    });

    test('the line is written in SAN from the position searched', () {
      final line = analysisLineOf(_open,
          (rank: 3, depth: 18, cp: 10, mate: null, pv: 'f1b5 a7a6 b5a4'));
      expect(line.sanMoveList, ['Bb5', 'a6', 'Ba4']);
      expect(line.multipv, 3);
      expect(line.depth, 18);
    });
  });

  group('one engine', () {
    test('the handshake asks for one thread and the hash', () async {
      final s = _Script(onGo: (_) => const []);
      await s.engine.handshake(hashMb: 64);
      expect(s.sent, [
        'uci',
        'setoption name Threads value 1',
        'setoption name Hash value 64',
        'isready',
      ]);
    });

    test('every search starts from an empty hash, then asks its question',
        () async {
      final s = _Script(
          onGo: (_) =>
              ['info depth 18 multipv 1 score cp 40 pv f1b5', 'bestmove f1b5']);
      await s.engine.analyze(_open, depth: 18, multiPV: 1);
      expect(s.sent, [
        'ucinewgame',
        'isready',
        'setoption name MultiPV value 1',
        'position fen $_open',
        'go depth 18',
      ]);
    });

    test('searchmoves narrows the search when given, and is left out otherwise',
        () async {
      final s = _Script(
          onGo: (_) =>
              ['info depth 18 multipv 1 score cp 40 pv f1b5', 'bestmove f1b5']);
      await s.engine
          .analyze(_open, depth: 18, multiPV: 1, searchMoves: ['e2e4', 'd2d4']);
      expect(s.sent.last, 'go depth 18 searchmoves e2e4 d2d4');

      final s2 = _Script(
          onGo: (_) =>
              ['info depth 18 multipv 1 score cp 40 pv f1b5', 'bestmove f1b5']);
      await s2.engine.analyze(_open, depth: 18, multiPV: 1);
      expect(s2.sent.last, 'go depth 18');
    });

    test('the last exact line of each rank is the answer, ranked', () async {
      final s = _Script(
          onGo: (_) => [
                'info depth 17 multipv 1 score cp 20 pv d2d4',
                'info depth 17 multipv 2 score cp 10 pv f1c4',
                'info depth 18 multipv 2 score cp 30 pv f1c4 g8f6',
                'info depth 18 multipv 1 score cp 45 lowerbound pv b1c3',
                'info depth 18 multipv 1 score cp 40 pv f1b5 a7a6',
                'bestmove f1b5',
              ]);
      final lines = await s.engine.analyze(_open, depth: 18, multiPV: 2);
      expect([for (final l in lines) l.multipv], [1, 2]);
      expect([for (final l in lines) l.bestMoveSan], ['Bb5', 'Bc4']);
      expect([for (final l in lines) l.evaluation], ['+0.40', '+0.30']);
      expect([for (final l in lines) l.depth], [18, 18]);
    });

    test('a search out of time is stopped, waited for, and returns what it had',
        () async {
      final s =
          _Script(onGo: (_) => ['info depth 11 multipv 1 score cp 5 pv f1b5']);
      final lines = await s.engine.analyze(_open,
          depth: 30, multiPV: 1, timeout: const Duration(milliseconds: 50));
      expect(s.sent.last, 'stop');
      expect(lines.single.depth, 11);
      // And the same engine answers the next search with that search's lines,
      // none of the stopped one's.
      s.onGo = (_) => [
            'info depth 5 multipv 1 score cp 1 pv f1c4',
            'bestmove f1c4',
          ];
      final next = await s.engine.analyze(_open, depth: 5, multiPV: 1);
      expect(next.single.bestMoveSan, 'Bc4');
      expect(next.single.depth, 5);
    });

    test('an engine that will not stop is closed and the search fails',
        () async {
      final s = _Script(onGo: (_) => const [], answerStop: false);
      await expectLater(
        s.engine.analyze(_open,
            depth: 30, multiPV: 1, timeout: const Duration(milliseconds: 20)),
        throwsA(isA<StateError>()),
      );
      expect(s.killed, isTrue);
      expect(s.sent, contains('quit'));
    });

    test('closing during a search ends it with an error at once', () async {
      final s = _Script(onGo: (_) => const []);
      final search = s.engine.analyze(_open, depth: 30, multiPV: 1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      s.engine.close();
      await expectLater(search, throwsA(isA<StateError>()));
      expect(s.killed, isTrue);
      await expectLater(s.engine.analyze(_open, depth: 1, multiPV: 1),
          throwsA(isA<StateError>()));
    });
  });

  test('workers are half the logical processors, at least one, at most eight',
      () {
    expect(defaultFactsWorkers(16), 8);
    expect(defaultFactsWorkers(12), 6);
    expect(defaultFactsWorkers(32), 8);
    expect(defaultFactsWorkers(1), 1);
  });

  group('the sleep watch', () {
    test('a tick on time is not a sleep; a jump of the wall clock is', () {
      var now = DateTime(2026, 9, 14, 8);
      final w = SleepWatch(now: () => now);
      w.start();
      now = now.add(const Duration(seconds: 1));
      w.check();
      now = now.add(const Duration(seconds: 30));
      w.check();
      expect(w.sleeps, 0, reason: 'exactly the threshold is not a sleep');
      now = now.add(const Duration(minutes: 40));
      w.check();
      expect(w.sleeps, 1);
      w.stop();
    });

    test('the heartbeat is a real timer', () async {
      // Real time, short beats: the wall clock is the machine's own plus an
      // offset the test moves, which is what a sleep looks like from inside.
      var skipped = Duration.zero;
      final w = SleepWatch(
        now: () => DateTime.now().add(skipped),
        tick: const Duration(milliseconds: 10),
        threshold: const Duration(milliseconds: 500),
      );
      w.start();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(w.sleeps, 0);
      skipped = const Duration(hours: 3);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(w.sleeps, 1, reason: 'one sleep is counted once');
      w.stop();
      skipped = const Duration(hours: 9);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(w.sleeps, 1, reason: 'a stopped watch does not tick');
    });
  });
}
