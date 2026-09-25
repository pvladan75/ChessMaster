/// The facts of a game, built on Windows by the app's own builder and compared
/// with the harness — phases 0 and 2 of `docs/PLAN-SKELET.md`.
///
///     set FACTS_GAMES=g01_scandinavian-defense,g02_french-defense   (default: the ten)
///     set FACTS_DEPTH=18                                           (default 18)
///     set FACTS_WORKERS=8                                          (default: defaultFactsWorkers)
///     set FACTS_OUT=<a folder>                                     (default build/game_facts)
///     flutter test tool/game_facts.dart
///
/// Phase 0 wrote this file with the builder's arithmetic and its engine copied
/// inside it, and measured that copy identical to the harness on all ten games.
/// **Phase 2 moved both into `lib/`, and this file is now only the entry
/// point**: `UciEnginePool` starts the downloaded binary, `GameFactsBuilder`
/// builds the rows, `SleepWatch` does what it does in the app. So the same comparison is now a comparison of the app's own code with
/// the harness, on the real engine — which is the one thing the unit tests
/// cannot ask.
///
/// (`FACTS_STORE` kept and reused the answers through `GameFactsStore` until
/// 25.9.2026; the app keeps them in `EvalCache` now, and this tool searches
/// every position, which is what a comparison with the harness wants.)
///
/// The masters statistics are rebuilt from the harness's own facts, which came
/// from the Lichess masters explorer. That is deliberate: this compares the
/// builder with the reference, and the app's own walk goes to the local
/// database (D5) — whose agreement with Lichess is measured in the plan, not
/// here.
///
/// A test rather than a script for the reason `review_game.dart` gives, and in
/// `tool/` so the suite's count is untouched.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/engine_identity.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/game_facts.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/sleep_watch.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial_io/uci_engine.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';

const _tenGames = [
  'g01_scandinavian-defense',
  'g02_french-defense',
  'g03_scandinavian-defense',
  'g04_saragossa-opening',
  'g05_french-defense',
  'g06_zukertort-opening',
  'g07_english-opening',
  'g08_nimzowitsch-defense',
  'g09_caro-kann-defense',
  'g10_english-opening',
];

const _standardFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

const _guesses = [
  r'%APPDATA%\rs.pejovic\Mislisha\engine\stockfish.exe',
  r'%APPDATA%\com.example\chess_app\engine\stockfish.exe',
];

void main() {
  final env = Platform.environment;
  final games = (env['FACTS_GAMES'] ?? '').trim().isEmpty
      ? _tenGames
      : env['FACTS_GAMES']!.split(',').map((g) => g.trim()).toList();
  final depth = int.tryParse(env['FACTS_DEPTH'] ?? '') ?? 18;
  final workers =
      int.tryParse(env['FACTS_WORKERS'] ?? '') ?? defaultFactsWorkers();
  final outDir = env['FACTS_OUT'] ?? 'build/game_facts';
  final inputDir = _harnessInput();

  test('builds facts for ${games.length} games at depth $depth', () async {
    Directory(outDir).createSync(recursive: true);
    final enginePath = _findEngine();
    final engine = await engineIdentity(enginePath);
    final pool = await UciEnginePool.start(enginePath, workers: workers);
    final sleeps = SleepWatch()..start();
    final summary = <Map<String, dynamic>>[];
    try {
      stdout.writeln('engine: $enginePath ($engine), $workers workers, '
          'depth $depth, ${Platform.numberOfProcessors} logical processors');
      for (final game in games) {
        final harness =
            jsonDecode(File('$inputDir/${game}_facts.json').readAsStringSync())
                as Map<String, dynamic>;
        final uci =
            _uciOf(File('$inputDir/${game}_plain.pgn').readAsStringSync());
        var searched = 0;

        final watch = Stopwatch()..start();
        final facts = await GameFactsBuilder(
          analyzers: pool.analyzers,
          depth: depth,
          sleeps: () => sleeps.sleeps,
        ).build(
          game: game,
          startFen: _standardFen,
          uciMoves: uci,
          masters: await _mastersFrom(harness, uci),
          engine: engine,
          onAnswer: (fen, candidates) => searched++,
          onProgress: (done, total) {
            if (done % 20 == 0 || done == total) {
              stdout.writeln('  $game  $done / $total');
            }
          },
        );
        final seconds = watch.elapsedMilliseconds / 1000.0;
        File('$outDir/${game}_d${depth}_facts.json').writeAsStringSync(
            const JsonEncoder.withIndent(' ').convert(facts));

        final report =
            _compare(harness, facts, sameDepth: depth == harness['depth']);
        report
          ..['game'] = game
          ..['depth'] = depth
          ..['seconds'] = seconds
          ..['searched'] = searched
          ..['sleeps'] = sleeps.sleeps;
        summary.add(report);
        stdout.writeln(_line(report));
      }
    } finally {
      sleeps.stop();
      pool.close();
    }
    File('$outDir/summary_d$depth.json')
        .writeAsStringSync(const JsonEncoder.withIndent(' ').convert(summary));
    stdout.writeln('written: $outDir/summary_d$depth.json');
  }, timeout: const Timeout(Duration(hours: 6)));
}

String _harnessInput() {
  for (final candidate in [
    '../tools/game_annotate/input',
    'tools/game_annotate/input',
  ]) {
    if (Directory(candidate).existsSync()) return candidate;
  }
  throw StateError(
      'tools/game_annotate/input not found — run from chess_app/.');
}

String _findEngine() {
  final given = Platform.environment['STOCKFISH_PATH'];
  for (final candidate in [given, ..._guesses]) {
    if (candidate == null) continue;
    final path = candidate.replaceAllMapped(
        RegExp(r'%(\w+)%'), (m) => Platform.environment[m.group(1)!] ?? '');
    if (File(path).existsSync()) return path;
  }
  throw StateError('Stockfish not found. Set STOCKFISH_PATH.');
}

List<String> _uciOf(String plainPgn) {
  final read = readStepTree(fen: _standardFen, pgn: plainPgn);
  expect(read.rejectedMoves, 0, reason: 'the game has moves that do not play');
  return [
    for (var node = read.root;
        node.children.isNotEmpty;
        node = node.children.first)
      node.children.first.moveUci!
  ];
}

/// The explorer's answers the harness's `book` entries were made from, keyed
/// by the positions the builder will look up. Only totals are ever read, so
/// every game is counted as a White win.
Future<Map<String, Map<String, dynamic>>> _mastersFrom(
    Map<String, dynamic> harness, List<String> uci) async {
  final rows = (harness['rows'] as List).cast<Map<String, dynamic>>();
  final known = <String, Map<String, dynamic>>{};
  // The builder looks positions up by its own FEN, and the harness's differs
  // in the en passant field, so rows are matched by index — against the
  // builder's own walk, which is where its FENs come from.
  final fens = [
    for (final r in await gameRows(startFen: _standardFen, uciMoves: uci))
      r['fen'] as String
  ];
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
  return known;
}

/// The FEN without its en passant field, which python-chess and the `chess`
/// package write differently and no rule reads.
String _position(String fen) {
  final f = fen.split(' ');
  return [f[0], f[1], f[2], f[4], f[5]].join(' ');
}

Map<String, dynamic> _compare(
  Map<String, dynamic> harness,
  Map<String, dynamic> device, {
  required bool sameDepth,
}) {
  final a = (harness['rows'] as List).cast<Map<String, dynamic>>();
  final b = (device['rows'] as List).cast<Map<String, dynamic>>();
  final report = <String, dynamic>{'rows': b.length};
  if (a.length != b.length) return report..['verdict'] = 'ROW COUNT DIFFERS';

  var fens = 0, motifs = 0, books = 0, moves = 0, evals = 0, lines = 0;
  var costs = 0;
  final examples = <String>[];
  String join(List c, String k) => c.map((e) => e[k]).join(' | ');
  for (var i = 0; i < a.length; i++) {
    final x = a[i], y = b[i];
    if (_position(x['fen']) != _position(y['fen'])) fens++;
    if ((x['motifs_after_played'] ?? '') != (y['motifs_after_played'] ?? '')) {
      motifs++;
    }
    if (jsonEncode(x['book']) != jsonEncode(y['book'])) books++;
    final cx = x['candidates'] as List, cy = y['candidates'] as List;
    if (join(cx, 'move') != join(cy, 'move')) {
      moves++;
      if (examples.length < 6) {
        examples.add('${x['label']}: [${join(cx, 'move')}] vs '
            '[${join(cy, 'move')}]');
      }
    }
    if (join(cx, 'eval') != join(cy, 'eval')) evals++;
    if (join(cx, 'line') != join(cy, 'line')) lines++;
    final px = x['played'] as Map?, py = y['played'] as Map?;
    if (px != null &&
        py != null &&
        '${px['cost_pawns']}' != '${py['cost_pawns']}') {
      final both = px['cost_pawns'] is num && py['cost_pawns'] is num;
      if (!both || (px['cost_pawns'] as num) != (py['cost_pawns'] as num)) {
        costs++;
      }
    }
  }

  List<String> momentsOf(Map<String, dynamic> facts) => [
        for (final m in skeletonMoments(
            jsonDecode(jsonEncode(facts)) as Map<String, dynamic>))
          '${m['label']} best=${m['best']}'
      ];
  final mx = momentsOf(harness), my = momentsOf(device);
  final same = mx.join('\n') == my.join('\n');
  return report
    ..addAll({
      'fens_differ': fens,
      'motifs_differ': motifs,
      'books_differ': books,
      'candidate_moves_differ': moves,
      'candidate_evals_differ': evals,
      'candidate_lines_differ': lines,
      'costs_differ': costs,
      'moments': my.length,
      'moments_equal': same,
      if (!same) 'moments_harness': mx,
      if (!same) 'moments_device': my,
      'examples': examples,
      'verdict': !sameDepth
          ? 'TIMING ONLY (harness is depth ${harness['depth']})'
          : same
              ? 'SAME MOMENTS'
              : 'MOMENTS DIFFER',
    });
}

String _line(Map<String, dynamic> r) =>
    '${r['game']} d${r['depth']}: ${r['verdict']} — '
    '${(r['seconds'] as double).toStringAsFixed(1)} s, searched ${r['searched']}'
    ', ${r['moments']} moments, '
    '${r['sleeps']} sleeps; rows differ: moves ${r['candidate_moves_differ']}, '
    'evals ${r['candidate_evals_differ']}, lines ${r['candidate_lines_differ']}, '
    'costs ${r['costs_differ']}, '
    'motifs ${r['motifs_differ']}, books ${r['books_differ']}, '
    'fens ${r['fens_differ']}'
    '${(r['examples'] as List).isEmpty ? '' : '\n    ${(r['examples'] as List).join('\n    ')}'}';
