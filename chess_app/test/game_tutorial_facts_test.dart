// Phase 2 of `docs/PLAN-SKELET.md`: the facts of a game, built by the app.
//
// Every expectation here was written by the harness. The ten games are
// rebuilt from their own candidates and must give back the harness's rows —
// labels, motif sentences, the masters statistics, stands-out, every cost — and
// `facts_cases.json` holds what no game reaches, answered by `make_facts.py`
// itself through `export_fixtures.py`.
//
// One difference is allowed, and only one: the en passant field of a FEN.
// python-chess writes that square only when a capture there is legal, the
// `chess` package whenever a pawn moved two squares, and no rule reads it.

import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/game_facts.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/models/analysis_models.dart';

const _fixtures = 'test/fixtures/game_tutorial';
const _start = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<Map<String, dynamic>> _games() {
  final files = Directory(_fixtures)
      .listSync()
      .whereType<File>()
      .where((f) => RegExp(r'g\d\d_[a-z-]+\.json$').hasMatch(f.path))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [for (final f in files) _read(f.path)];
}

/// The synthetic cases name their positions `x` or `fen 0` — neither `finish`
/// nor the masters arithmetic reads a position — so only a real FEN is trimmed.
String _withoutEp(String fen) {
  final f = fen.split(' ');
  if (f.length != 6) return fen;
  return [f[0], f[1], f[2], f[4], f[5]].join(' ');
}

/// Where two JSON values part, or null. Numbers compare by value **and by
/// kind**: Python writes a cost of nothing as the integer `0` and a cost in
/// pawns as a float, JSON keeps the difference, and a port that writes `0.0`
/// where the harness wrote `0` has taken the wrong branch to get there.
String? _difference(Object? a, Object? b, [String path = r'$']) {
  if (a is num && b is num) {
    if (a is int != b is int) {
      return '$path: $a (${a.runtimeType}) against $b (${b.runtimeType})';
    }
    return a == b ? null : '$path: $a against $b';
  }
  if (a is Map && b is Map) {
    for (final key in {...a.keys, ...b.keys}) {
      if (!a.containsKey(key) || !b.containsKey(key)) {
        return '$path.$key: present on one side only';
      }
      final found = key == 'fen'
          ? (_withoutEp(a[key] as String) == _withoutEp(b[key] as String)
              ? null
              : '$path.fen: ${a[key]} against ${b[key]}')
          : _difference(a[key], b[key], '$path.$key');
      if (found != null) return found;
    }
    return null;
  }
  if (a is List && b is List) {
    if (a.length != b.length) {
      return '$path: ${a.length} items against ${b.length}';
    }
    for (var i = 0; i < a.length; i++) {
      final found = _difference(a[i], b[i], '$path[$i]');
      if (found != null) return found;
    }
    return null;
  }
  return a == b ? null : '$path: $a against $b';
}

/// The app's own spelling of an evaluation, as the engine service writes it.
String _appEval(String factsEval) {
  if (factsEval.startsWith('#')) {
    final m = int.parse(factsEval.substring(1));
    return m > 0 ? 'M$m' : '-M${m.abs()}';
  }
  final v = double.parse(factsEval);
  return v > 0 ? '+${v.toStringAsFixed(2)}' : v.toStringAsFixed(2);
}

AnalysisLine _line(
        {required int rank,
        required int depth,
        required String eval,
        required String sanLine}) =>
    AnalysisLine(
      multipv: rank,
      depth: depth,
      evaluation: eval,
      bestMoveLan: '',
      bestMoveSan: sanLine.split(' ').first,
      continuationLan: '',
      continuationSan: sanLine,
      sanMoveList: sanLine.isEmpty ? const [] : sanLine.split(' '),
      fenList: const [],
      fromSquare: '',
      toSquare: '',
    );

List<String> _uciOf(String plainPgn) {
  final read = readStepTree(fen: _start, pgn: plainPgn);
  expect(read.rejectedMoves, 0);
  final moves = <String>[];
  for (var node = read.root;
      node.children.isNotEmpty;
      node = node.children.first) {
    moves.add(node.children.first.moveUci!);
  }
  return moves;
}

/// The explorer's answer that `make_facts.add_book` would have turned into
/// [book]: the move played first when masters played it, then the
/// alternatives in their order, and every game counted as a White win — only
/// the totals are ever read.
Map<String, dynamic> _explorerFrom(Map<String, dynamic> book) {
  final moves = <Map<String, dynamic>>[];
  final mine = book['played'] as Map<String, dynamic>?;
  if (mine != null && (mine['games'] as num) > 0) {
    moves.add({'san': mine['move'], 'white': mine['games']});
  }
  for (final alt in (book['alternatives'] as List)) {
    moves.add({'san': alt['move'], 'white': alt['games']});
  }
  return {
    'white': book['games'],
    'draws': 0,
    'black': 0,
    if (book.containsKey('opening')) 'opening': {'name': book['opening']},
    'moves': moves,
  };
}

typedef _Script = Future<List<AnalysisLine>> Function(String fen, int call);

PositionAnalyzer _scripted(_Script answer, List<String> calls) => (String fen,
        {required int depth,
        required int multiPV,
        Duration timeout = const Duration(seconds: 1)}) {
      calls.add(fen);
      return answer(fen, calls.length);
    };

/// After 1. e4 e5 2. Nf3 Nc6: both sides have far more than four legal moves,
/// so a full answer is exactly four lines.
const _openPosition =
    'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3';

List<AnalysisLine> _four({int depth = 18}) => [
      _line(rank: 1, depth: depth, eval: '+0.40', sanLine: 'Bb5 a6 Ba4 Nf6'),
      _line(rank: 2, depth: depth, eval: '+0.30', sanLine: 'Bc4 Nf6 d3 Bc5'),
      _line(rank: 3, depth: depth, eval: '+0.20', sanLine: 'd4 exd4 Nxd4 Nf6'),
      _line(rank: 4, depth: depth, eval: '+0.10', sanLine: 'Nc3 Nf6 Bb5 Bb4'),
    ];

void main() {
  group('the ten games, rebuilt from their own candidates', () {
    for (final fixture in _games()) {
      final facts = fixture['facts'] as Map<String, dynamic>;
      test(fixture['game'], () async {
        final rows = (facts['rows'] as List).cast<Map<String, dynamic>>();
        final byPosition = {
          for (final r in rows)
            if ((r['candidates'] as List).isNotEmpty)
              _withoutEp(r['fen'] as String): r['candidates'] as List
        };
        final uci = _uciOf(fixture['plainPgn'] as String);

        // The walk's positions in the app's own spelling, so the masters
        // answers are keyed the way the builder will look them up.
        final board = chess.Chess.fromFEN(_start);
        final fens = [board.fen];
        for (final m in uci) {
          board.move({
            'from': m.substring(0, 2),
            'to': m.substring(2, 4),
            if (m.length > 4) 'promotion': m.substring(4),
          });
          fens.add(board.fen);
        }
        final masters = <String, Map<String, dynamic>>{
          for (var i = 0; i < rows.length; i++)
            if (rows[i]['book'] != null)
              fens[i]: _explorerFrom(rows[i]['book'] as Map<String, dynamic>)
        };

        final calls = <String>[];
        final analyzer = _scripted((fen, _) async {
          final cands = byPosition[_withoutEp(fen)]!;
          return [
            for (var i = 0; i < cands.length; i++)
              _line(
                rank: i + 1,
                depth: 18,
                eval: _appEval(cands[i]['eval'] as String),
                sanLine: cands[i]['line'] as String,
              )
          ];
        }, calls);

        final built =
            await GameFactsBuilder(analyzers: [analyzer, analyzer]).build(
          game: fixture['game'] as String,
          startFen: _start,
          uciMoves: uci,
          masters: masters,
        );

        expect(_difference(facts['rows'], built['rows']), isNull);
        expect(built['in_book'], facts['in_book']);
        expect(
            calls,
            hasLength(
                rows.where((r) => (r['candidates'] as List).isNotEmpty).length),
            reason: 'every unfinished position searched once, a finished game '
                'never');
      });
    }
  });

  group('facts_cases.json', () {
    final cases = _read('$_fixtures/facts_cases.json');

    test('an engine score becomes the eval text and the value for the mover',
        () {
      for (final c in (cases['scores'] as List).cast<Map<String, dynamic>>()) {
        final n = c['fromSideToMove'] as int;
        final whiteToMove = c['whiteToMove'] as bool;
        // Spelled the way the engine service spells it: White's side.
        final String app;
        if (c['kind'] == 'mate') {
          final white = whiteToMove ? n : -n;
          app = white > 0 ? 'M$white' : '-M${white.abs()}';
        } else {
          final white = (whiteToMove ? n : -n) / 100.0;
          app = white > 0
              ? '+${white.toStringAsFixed(2)}'
              : white.toStringAsFixed(2);
        }
        final made = candidateOf(
            _line(rank: 1, depth: 18, eval: app, sanLine: 'e4'),
            whiteToMove: whiteToMove);
        expect([made['eval'], made['value_for_mover']],
            [c['eval'], c['valueForMover']],
            reason: '${c['kind']} ${c['fromSideToMove']}, '
                '${whiteToMove ? 'White' : 'Black'} to move');
      }
    });

    for (final c in (cases['finish'] as List).cast<Map<String, dynamic>>()) {
      test('finish: ${c['name']}', () {
        final rows = (jsonDecode(jsonEncode(c['rows'])) as List)
            .cast<Map<String, dynamic>>();
        finishFacts(rows, marginPawns: cases['marginPawns'] as double);
        expect(_difference(c['expected'], rows), isNull);
      });
    }

    for (final c in (cases['book'] as List).cast<Map<String, dynamic>>()) {
      test('masters: ${c['name']}', () {
        final rows = (jsonDecode(jsonEncode(c['rows'])) as List)
            .cast<Map<String, dynamic>>();
        final known = (c['known'] as Map).map((k, v) =>
            MapEntry(k as String, (v as Map).cast<String, dynamic>()));
        final count = applyMastersBook(rows, known);
        expect(_difference(c['expected'], rows), isNull);
        expect(count, c['inBook']);
      });
    }
  });

  group('a search that did not finish is not a fact', () {
    GameFactsBuilder builder(PositionAnalyzer a, {int Function()? sleeps}) =>
        GameFactsBuilder(analyzers: [a], sleeps: sleeps);

    Future<Map<String, dynamic>> oneMove(GameFactsBuilder b) => b.build(
          game: 'test',
          startFen: _openPosition,
          uciMoves: const ['f1b5'],
        );

    List<AnalysisLine> reply({int depth = 18}) => [
          _line(rank: 1, depth: depth, eval: '+0.35', sanLine: 'a6 Ba4 Nf6'),
          _line(rank: 2, depth: depth, eval: '+0.45', sanLine: 'Nf6 O-O Nxe4'),
          _line(rank: 3, depth: depth, eval: '+0.55', sanLine: 'd6 d4 Bd7'),
          _line(rank: 4, depth: depth, eval: '+0.60', sanLine: 'Nge7 O-O g6'),
        ];

    List<AnalysisLine> good(String fen) =>
        fen.contains(' w ') ? _four() : reply();

    test('a candidate keeps six moves of its line, however long the engine\'s',
        () async {
      final built = await oneMove(builder(_scripted((fen, _) async {
        final lines = good(fen);
        if (!fen.contains(' w ')) return lines;
        return [
          _line(
              rank: 1,
              depth: 18,
              eval: '+0.40',
              sanLine: 'Bb5 a6 Ba4 Nf6 O-O Be7 Re1 b5'),
          ...lines.skip(1),
        ];
      }, <String>[])));
      final first = ((built['rows'] as List).first['candidates'] as List).first;
      expect(first['line'], 'Bb5 a6 Ba4 Nf6 O-O Be7');
    });

    test('lines that arrive out of order are kept in rank order', () async {
      final built = await oneMove(builder(_scripted(
          (fen, _) async => good(fen).reversed.toList(), <String>[])));
      final first = (built['rows'] as List).first['candidates'] as List;
      expect([for (final c in first) c['move']], ['Bb5', 'Bc4', 'd4', 'Nc3']);
    });

    test('two lines of the same rank are not an answer', () async {
      final b = builder(_scripted((fen, _) async {
        final lines = good(fen);
        return [lines[0], lines[0], lines[1], lines[2]];
      }, <String>[]));
      await expectLater(
          oneMove(b),
          throwsA(isA<GameFactsException>()
              .having((e) => e.message, 'message', contains('not ranked'))));
    });

    test('a game that ends in bare kings is over, and not searched', () async {
      // King against king and pawn is still a game; taking the pawn ends it.
      // (King and knight against king would already be over before the move.)
      // The king on e1 has two legal moves: Kxe2 and Kd2.
      final calls = <String>[];
      final b = builder(_scripted(
          (fen, _) async => [
                _line(rank: 1, depth: 18, eval: '0.00', sanLine: 'Kxe2'),
                _line(rank: 2, depth: 18, eval: '-3.00', sanLine: 'Kd2'),
              ],
          calls));
      final built = await b.build(
        game: 'test',
        startFen: '8/8/8/8/8/6k1/4p3/4K3 w - - 0 1',
        uciMoves: const ['e1e2'],
      );
      final rows = (built['rows'] as List).cast<Map<String, dynamic>>();
      expect(rows[1]['game_over'], '1/2-1/2');
      expect(rows[0]['played']['eval'], 'draw');
      expect(calls, hasLength(1));
    });

    test('a shallow answer is searched once more, and the second is used',
        () async {
      final calls = <String>[];
      final built = await oneMove(builder(_scripted((fen, call) async {
        return call == 1 ? _four(depth: 17) : good(fen);
      }, calls)));
      expect(calls, hasLength(3));
      expect((built['rows'] as List).first['candidates'], hasLength(4));
    });

    test('two shallow answers fail the build with a sentence', () async {
      final calls = <String>[];
      final b = builder(_scripted((fen, _) async => _four(depth: 16), calls));
      await expectLater(
          oneMove(b),
          throwsA(isA<GameFactsException>().having((e) => e.message, 'message',
              allOf(contains('the starting position'), contains('depth 16')))));
      expect(calls, hasLength(2));
    });

    test('too few lines is not an answer', () async {
      final calls = <String>[];
      final b =
          builder(_scripted((fen, _) async => _four().take(3).toList(), calls));
      await expectLater(
          oneMove(b),
          throwsA(isA<GameFactsException>().having(
              (e) => e.message, 'message', contains('3 lines where 4'))));
    });

    test('an engine that throws is a miss, not a crash', () async {
      final calls = <String>[];
      final b = builder(_scripted((fen, call) async {
        if (call == 1) throw StateError('the process died');
        return good(fen);
      }, calls));
      final built = await oneMove(b);
      expect(calls, hasLength(3));
      expect(built['rows'], hasLength(2));
    });

    test('a miss while the computer slept does not use up the retry', () async {
      var sleeps = 0;
      final calls = <String>[];
      final b = builder(
          _scripted((fen, call) async {
            if (call <= 3) {
              sleeps++;
              return _four(depth: 9);
            }
            if (call == 4) return _four(depth: 17); // one real miss, then fine
            return good(fen);
          }, calls),
          sleeps: () => sleeps);
      final built = await oneMove(b);
      expect(calls, hasLength(6));
      expect((built['rows'] as List).first['candidates'], hasLength(4));
    });

    test('sleeping through every attempt says so, not that the engine failed',
        () async {
      var sleeps = 0;
      final b = builder(
          _scripted((fen, _) async {
            sleeps++;
            return const <AnalysisLine>[];
          }, <String>[]),
          sleeps: () => sleeps);
      await expectLater(
          oneMove(b),
          throwsA(isA<GameFactsException>()
              .having((e) => e.message, 'message', contains('went to sleep'))));
    });

    test('a known answer is not searched again, and a new one is reported',
        () async {
      final calls = <String>[];
      final told = <String>[];
      final b = builder(_scripted((fen, _) async => good(fen), calls));
      final first = await b.build(
        game: 'test',
        startFen: _openPosition,
        uciMoves: const ['f1b5'],
        onAnswer: (fen, _) => told.add(fen),
      );
      expect(told, hasLength(2));
      final rows = (first['rows'] as List).cast<Map<String, dynamic>>();
      final again = await b.build(
        game: 'test',
        startFen: _openPosition,
        uciMoves: const ['f1b5'],
        known: {
          for (final r in rows)
            r['fen'] as String:
                (r['candidates'] as List).cast<Map<String, dynamic>>()
        },
      );
      expect(calls, hasLength(2), reason: 'the second build searched nothing');
      expect(_difference(first['rows'], again['rows']), isNull);
    });

    test('a search ended by cancelling is a cancel, not an engine failure',
        () async {
      var stop = false;
      final calls = <String>[];
      final b = builder(_scripted((fen, _) async {
        // The trainer pressed cancel, and closing the engines failed the
        // search that was running.
        stop = true;
        throw StateError('the engine has been closed');
      }, calls));
      await expectLater(
        b.build(
          game: 'test',
          startFen: _openPosition,
          uciMoves: const ['f1b5'],
          cancelled: () => stop,
        ),
        throwsA(isA<GameFactsCancelled>()),
      );
      expect(calls, hasLength(1), reason: 'a cancelled search is not retried');
    });

    test('cancel stops before the next search', () async {
      final calls = <String>[];
      var stop = false;
      final b = builder(_scripted((fen, _) async {
        stop = true;
        return good(fen);
      }, calls));
      await expectLater(
        b.build(
          game: 'test',
          startFen: _openPosition,
          uciMoves: const ['f1b5'],
          cancelled: () => stop,
        ),
        throwsA(isA<GameFactsCancelled>()),
      );
      expect(calls, hasLength(1));
    });

    test('a move that cannot be played is refused before any search', () async {
      final calls = <String>[];
      final b = builder(_scripted((fen, _) async => good(fen), calls));
      await expectLater(
        b.build(
            game: 'test', startFen: _openPosition, uciMoves: const ['a1a5']),
        throwsA(isA<GameFactsException>()
            .having((e) => e.message, 'message', contains('a1a5'))),
      );
      expect(calls, isEmpty);
    });
  });
}
