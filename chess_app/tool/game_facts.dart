/// Phase 0 of `docs/PLAN-SKELET.md`: the facts of a game, built on Windows
/// through the app's own services, compared with the harness.
///
///     set FACTS_GAMES=g01_scandinavian-defense,g02_french-defense   (default: the ten)
///     set FACTS_DEPTH=18                                           (default 18)
///     set FACTS_WORKERS=8                                          (default 8)
///     set FACTS_OUT=<a folder>                                     (default build/game_facts)
///     flutter test tool/game_facts.dart
///
/// Two questions and nothing else. **Parity**: at the harness's depth, does
/// this produce the same moments and the same question answers as
/// `tools/game_annotate/input/<game>_facts.json`? **Time**: how many seconds a
/// game takes at 18, 20 and 22 with the workers this machine has, so the depth
/// choice can say how long each costs.
///
/// **It is a measurement, not the builder.** The arithmetic below — the row
/// walk, the cost, the rank, „stands out" — is `make_facts.py`'s `walk` and
/// `build`, copied here so the measurement can be taken before phase 2 decides
/// its shape. Phase 2 moves it into `lib/` behind a `PositionAnalyzer` and a
/// gate; until then nothing in the app imports this file.
///
/// **What comes from where.** The moves are read by `readStepTree`, the app's
/// one PGN reader. The motif sentences are `GameAnalysisWalkerService`'s, with
/// no engine, exactly as `review_game.dart REVIEW_COMMENTS_ONLY=1` wrote the
/// harness's reviewed PGNs. The engine is the downloaded Stockfish, one
/// single-threaded process a position, `ucinewgame` before each, as
/// `make_facts.analyse_all` does. **The masters statistics are copied from the
/// harness's facts file**, because the masters walk is the server's and phase
/// 2's; the rule that silences the detector in book is then applied here.
///
/// **A search that did not reach the asked depth with the asked lines is not a
/// fact** (`PLAN-SKELET.md`, rule 1): it is retried once and then the run fails
/// with a sentence. A measurement that quietly averaged in half-finished
/// searches would be timing something the product must never ship.
///
/// A test rather than a script for the reason `review_game.dart` gives, and in
/// `tool/` so the suite's count is untouched.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/tutorial_studio/services/game_tutorial/skeleton_moments.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/models/analysis_models.dart';

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

/// `make_facts.py`'s constants, named so a drift is visible.
const int _mate = 100000;
const int _multiPv = 4;
const int _hashMb = 128;
const double _marginPawns = 0.5;
const int _lineLength = 6;

const _standardFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

void main() {
  final env = Platform.environment;
  final games = (env['FACTS_GAMES'] ?? '').trim().isEmpty
      ? _tenGames
      : env['FACTS_GAMES']!.split(',').map((g) => g.trim()).toList();
  final depth = int.tryParse(env['FACTS_DEPTH'] ?? '') ?? 18;
  final workers = int.tryParse(env['FACTS_WORKERS'] ?? '') ?? 8;
  final outDir = env['FACTS_OUT'] ?? 'build/game_facts';
  final inputDir = _harnessInput();

  test('builds facts for ${games.length} games at depth $depth', () async {
    Directory(outDir).createSync(recursive: true);
    final pool = await _EnginePool.start(workers);
    final summary = <Map<String, dynamic>>[];
    try {
      stdout.writeln('engine: ${pool.path}, $workers workers, depth $depth, '
          '${Platform.numberOfProcessors} logical processors');
      for (final game in games) {
        final harness =
            jsonDecode(File('$inputDir/${game}_facts.json').readAsStringSync())
                as Map<String, dynamic>;
        final watch = Stopwatch()..start();
        final facts = await _build(
          game: game,
          plainPgn: File('$inputDir/${game}_plain.pgn').readAsStringSync(),
          harness: harness,
          pool: pool,
          depth: depth,
        );
        final seconds = watch.elapsedMilliseconds / 1000.0;
        facts['workers'] = workers;
        facts['seconds'] = seconds;
        File('$outDir/${game}_d${depth}_facts.json').writeAsStringSync(
            const JsonEncoder.withIndent(' ').convert(facts));

        final report =
            _compare(harness, facts, sameDepth: depth == harness['depth']);
        report['game'] = game;
        report['depth'] = depth;
        report['seconds'] = seconds;
        report['positions_searched'] = facts['positions_searched'];
        summary.add(report);
        stdout.writeln(_line(report));
      }
    } finally {
      await pool.stop();
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

// --- The build ---------------------------------------------------------------

Future<Map<String, dynamic>> _build({
  required String game,
  required String plainPgn,
  required Map<String, dynamic> harness,
  required _EnginePool pool,
  required int depth,
}) async {
  final read = readStepTree(fen: _standardFen, pgn: plainPgn);
  expect(read.rejectedMoves, 0, reason: '$game has moves that do not play');
  final chain = <AnalysisNode>[];
  for (var node = read.root;
      node.children.isNotEmpty;
      node = node.children.first) {
    chain.add(node.children.first);
  }

  final moments = await GameAnalysisWalkerService().analyzeGame(
    startingFen: read.root.fen,
    uciMoves: [for (final node in chain) node.moveUci ?? ''],
    analyzer: _noEngine,
  );
  expect(moments, hasLength(chain.length),
      reason: '$game: the walk stopped before the end of the main line');

  // `make_facts.walk`.
  final rows = <Map<String, dynamic>>[];
  var label = 'start';
  for (var index = 0; index <= chain.length; index++) {
    final fen = index == 0 ? read.root.fen : chain[index - 1].fen;
    final board = chess.Chess.fromFEN(fen);
    final white = board.turn == chess.Color.WHITE;
    final row = <String, dynamic>{
      'label': label,
      'fen': fen,
      'to_move': white ? 'White' : 'Black',
    };
    final over = _gameOver(board);
    if (over != null) {
      row['game_over'] = over;
      row['candidates'] = <Map<String, dynamic>>[];
    }
    if (index < chain.length) {
      final san = chain[index].moveSan!;
      final moveNumber = fen.split(' ')[5];
      final played = <String, dynamic>{
        'move': san,
        'label': white ? '$moveNumber. $san' : '$moveNumber... $san',
      };
      row['played'] = played;
      final comment = moments[index].combinedComment.trim();
      if (comment.isNotEmpty) row['motifs_after_played'] = comment;
      label = played['label'] as String;
    }
    rows.add(row);
  }

  // The masters statistics, copied by index (the walk is phase 2's), and the
  // silence rule of `make_facts.add_book` applied to this side's comments.
  final harnessRows = (harness['rows'] as List).cast<Map<String, dynamic>>();
  var inBook = 0;
  for (var i = 0; i < rows.length && i < harnessRows.length; i++) {
    final book = harnessRows[i]['book'] as Map<String, dynamic>?;
    if (book == null) break;
    inBook++;
    rows[i]['book'] = book;
    final played = rows[i]['played'] as Map<String, dynamic>?;
    if (played == null) continue;
    final harnessPlayed = harnessRows[i]['played'] as Map<String, dynamic>;
    if (harnessPlayed['left_book'] == true) played['left_book'] = true;
    final listed = (book['played'] as Map<String, dynamic>?)?['games'];
    if (listed is num && listed > 0) rows[i].remove('motifs_after_played');
  }

  // The engine, on every position that is not over.
  final todo = [
    for (var i = 0; i < rows.length; i++)
      if (!rows[i].containsKey('candidates')) i
  ];
  final answers = await pool.analyseAll(
    [for (final i in todo) rows[i]['fen'] as String],
    depth: depth,
    onDone: (done, total) {
      if (done % 20 == 0 || done == total) {
        stdout.writeln('  $game  $done / $total');
      }
    },
  );
  for (var k = 0; k < todo.length; k++) {
    rows[todo[k]]['candidates'] = answers[k];
  }

  // `make_facts.build`, the arithmetic.
  final margin = (_marginPawns * 100).round();
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final cands = (row['candidates'] as List).cast<Map<String, dynamic>>();
    if (cands.isNotEmpty) {
      final best = cands[0]['value_for_mover'] as int;
      if (cands.length == 1) {
        row['best_stands_out'] = false;
        row['why'] = 'only one legal move';
      } else {
        final second = cands[1]['value_for_mover'] as int;
        final bestMate = best.abs() > _mate / 2;
        final secondMate = second.abs() > _mate / 2;
        if (bestMate && best > 0 && !(secondMate && second > 0)) {
          row['best_stands_out'] = true;
          row['margin_pawns'] = 'mate';
        } else if (bestMate || secondMate) {
          row['best_stands_out'] = false;
          row['margin_pawns'] = 'mate';
        } else {
          row['margin_pawns'] = _pawns(best - second);
          row['best_stands_out'] = (best - second) >= margin;
        }
      }
    }

    final played = row['played'] as Map<String, dynamic>?;
    if (played != null && cands.isNotEmpty) {
      final after = rows[index + 1];
      final afterCands = (after['candidates'] as List);
      int value;
      if (afterCands.isNotEmpty) {
        final top = afterCands[0] as Map<String, dynamic>;
        value = -(top['value_for_mover'] as int);
        played['eval'] = top['eval'];
      } else if (after['game_over'] == '1-0' || after['game_over'] == '0-1') {
        value = _mate;
        played['eval'] = 'checkmate';
      } else {
        value = 0;
        played['eval'] = 'draw';
      }
      played['value_for_mover'] = value;
      final ranks = [for (final c in cands) c['move']];
      final at = ranks.indexOf(played['move']);
      played['rank'] = at < 0 ? null : at + 1;
      _setCost(played, cands[0]);
    }
  }

  return {
    'game': game,
    'depth': depth,
    'multipv': _multiPv,
    'margin_pawns': _marginPawns,
    'engine': 'stockfish.exe',
    'threads': 1,
    'hash_mb': _hashMb,
    'in_book': inBook,
    'positions_searched': todo.length,
    'rows': rows,
  };
}

Future<List<AnalysisLine>> _noEngine(
  String fen, {
  required int depth,
  required int multiPV,
  Duration timeout = const Duration(seconds: 1),
}) async =>
    const [];

/// python-chess's `is_game_over(claim_draw=False)`, as far as these games
/// reach: mate, stalemate, bare material. The 75-move rule and fivefold
/// repetition are not asked; a disagreement would show as a row difference.
String? _gameOver(chess.Chess board) {
  if (board.in_checkmate) {
    return board.turn == chess.Color.WHITE ? '0-1' : '1-0';
  }
  if (board.in_stalemate || board.insufficient_material) return '1/2-1/2';
  return null;
}

Object _pawns(int value) {
  if (value.abs() > _mate / 2) return 'mate';
  return value / 100.0;
}

/// `make_facts.set_cost`, line for line.
void _setCost(Map<String, dynamic> played, Map<String, dynamic> best) {
  final value = played['value_for_mover'] as int;
  final bestValue = best['value_for_mover'] as int;
  played.remove('cost_mate');
  if (played['move'] == best['move'] || bestValue <= value) {
    played['cost_pawns'] = 0;
    return;
  }
  int side(int v) => (v > _mate / 2 ? 1 : 0) - (v < -_mate / 2 ? 1 : 0);
  if (side(bestValue) == side(value)) {
    played['cost_pawns'] = side(value) == 0 ? _pawns(bestValue - value) : 0;
    return;
  }
  played['cost_pawns'] = 'mate';
  final gaveUp = bestValue > _mate / 2;
  final walkedIn = value < -_mate / 2;
  played['cost_mate'] = gaveUp && walkedIn
      ? 'gave up a forced mate and allowed one'
      : gaveUp
          ? 'gave up a forced mate'
          : walkedIn
              ? 'allowed a forced mate'
              : 'cost a forced mate';
}

// --- The comparison ----------------------------------------------------------

/// The FEN without its en passant field: python-chess writes that square only
/// when a capture there is legal, the `chess` package whenever a pawn moved
/// two squares, and neither changes what an engine searches.
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
  final report = <String, dynamic>{'rows': b.length, 'harness_rows': a.length};
  if (a.length != b.length) return report..['verdict'] = 'ROW COUNT DIFFERS';

  var fenOnlyEp = 0, fenDiffer = 0, labels = 0, motifs = 0;
  var candMoves = 0, candEvals = 0, candLines = 0, stands = 0, costs = 0;
  final examples = <String>[];
  for (var i = 0; i < a.length; i++) {
    final x = a[i], y = b[i];
    if (x['fen'] != y['fen']) {
      if (_position(x['fen']) == _position(y['fen'])) {
        fenOnlyEp++;
      } else {
        fenDiffer++;
      }
    }
    if (x['label'] != y['label']) labels++;
    if ((x['motifs_after_played'] ?? '') != (y['motifs_after_played'] ?? '')) {
      motifs++;
      if (examples.length < 6) examples.add('motif ${x['label']}');
    }
    final cx = (x['candidates'] as List? ?? const []);
    final cy = (y['candidates'] as List? ?? const []);
    String moves(List c) => c.map((e) => e['move']).join(' ');
    String evals(List c) => c.map((e) => e['eval']).join(' ');
    String lines(List c) => c.map((e) => e['line']).join(' | ');
    if (moves(cx) != moves(cy)) {
      candMoves++;
      if (examples.length < 6) {
        examples.add('moves ${x['label']}: [${moves(cx)}] vs [${moves(cy)}]');
      }
    }
    if (evals(cx) != evals(cy)) candEvals++;
    if (lines(cx) != lines(cy)) candLines++;
    if (x['best_stands_out'] != y['best_stands_out']) stands++;
    final px = x['played'] as Map?, py = y['played'] as Map?;
    if (px != null &&
        py != null &&
        '${px['cost_pawns']}' != '${py['cost_pawns']}') {
      // `0` from Python and `0` from Dart print alike; `1.0` and `1.0` too.
      if (!(px['cost_pawns'] is num &&
          py['cost_pawns'] is num &&
          (px['cost_pawns'] as num) == (py['cost_pawns'] as num))) {
        costs++;
      }
    }
  }

  // The bar: the same moments and the same question answers.
  List<String> momentsOf(Map<String, dynamic> facts) => [
        for (final m in skeletonMoments(
            jsonDecode(jsonEncode(facts)) as Map<String, dynamic>))
          '${m['label']} best=${m['best']} asks=${m['asks']} '
              'correct=${(m['correct'] as List).join(',')}'
      ];
  final mx = momentsOf(harness), my = momentsOf(device);
  final momentsEqual = mx.join('\n') == my.join('\n');

  report.addAll({
    'fen_differs_only_in_ep': fenOnlyEp,
    'fen_differs': fenDiffer,
    'labels_differ': labels,
    'motifs_differ': motifs,
    'candidate_moves_differ': candMoves,
    'candidate_evals_differ': candEvals,
    'candidate_lines_differ': candLines,
    'stands_out_differ': stands,
    'costs_differ': costs,
    'moments': my.length,
    'moments_equal': momentsEqual,
    if (!momentsEqual) 'moments_harness': mx,
    if (!momentsEqual) 'moments_device': my,
    'examples': examples,
    'verdict': !sameDepth
        ? 'TIMING ONLY (harness is depth ${harness['depth']})'
        : momentsEqual
            ? 'SAME MOMENTS'
            : 'MOMENTS DIFFER',
  });
  return report;
}

String _line(Map<String, dynamic> r) =>
    '${r['game']} d${r['depth']}: ${r['verdict']} — '
    '${(r['seconds'] as double).toStringAsFixed(1)} s, '
    '${r['positions_searched']} positions, ${r['moments']} moments; '
    'rows differ: moves ${r['candidate_moves_differ']}, '
    'evals ${r['candidate_evals_differ']}, lines ${r['candidate_lines_differ']}, '
    'stands-out ${r['stands_out_differ']}, costs ${r['costs_differ']}, '
    'motifs ${r['motifs_differ']}, labels ${r['labels_differ']}, '
    'fen ${r['fen_differs']} (+${r['fen_differs_only_in_ep']} ep only)'
    '${(r['examples'] as List).isEmpty ? '' : '\n    ${(r['examples'] as List).join('\n    ')}'}';

// --- The engines -------------------------------------------------------------

class _EnginePool {
  _EnginePool(this.path, this._engines);

  final String path;
  final List<_Engine> _engines;

  static const _guesses = [
    r'%APPDATA%\rs.pejovic\Mislisha\engine\stockfish.exe',
    r'%APPDATA%\com.example\chess_app\engine\stockfish.exe',
  ];

  static Future<_EnginePool> start(int workers) async {
    final path = _find();
    final engines = await Future.wait(
        [for (var i = 0; i < workers; i++) _Engine.start(path)]);
    return _EnginePool(path, engines);
  }

  Future<void> stop() => Future.wait([for (final e in _engines) e.stop()]);

  static String _find() {
    final given = Platform.environment['STOCKFISH_PATH'];
    for (final candidate in [given, ..._guesses]) {
      if (candidate == null) continue;
      final path = candidate.replaceAllMapped(
          RegExp(r'%(\w+)%'), (m) => Platform.environment[m.group(1)!] ?? '');
      if (File(path).existsSync()) return path;
    }
    throw StateError('Stockfish not found. Set STOCKFISH_PATH.');
  }

  /// Every FEN, each by whichever engine is free, answers in input order.
  Future<List<List<Map<String, dynamic>>>> analyseAll(
    List<String> fens, {
    required int depth,
    void Function(int done, int total)? onDone,
  }) async {
    final results = List<List<Map<String, dynamic>>?>.filled(fens.length, null);
    var next = 0, done = 0;
    Future<void> drain(_Engine engine) async {
      while (next < fens.length) {
        final index = next++;
        results[index] = await _searchChecked(engine, fens[index], depth);
        onDone?.call(++done, fens.length);
      }
    }

    await Future.wait([for (final e in _engines) drain(e)]);
    return [for (final r in results) r!];
  }

  /// Rule 1: the asked depth on every line, and as many lines as asked or as
  /// there are legal moves. Once more on a miss, then a loud failure.
  static Future<List<Map<String, dynamic>>> _searchChecked(
      _Engine engine, String fen, int depth) async {
    final legal = chess.Chess.fromFEN(fen).moves().length;
    final wanted = legal < _multiPv ? legal : _multiPv;
    String? why;
    for (var attempt = 1; attempt <= 2; attempt++) {
      final lines = await engine.search(fen, depth: depth, multiPv: _multiPv);
      if (lines == null) {
        why = 'the search did not finish in time';
      } else if (lines.length != wanted) {
        why = '${lines.length} lines where $wanted were asked';
      } else if (lines.any((l) => l.depth != depth)) {
        why = 'a line stopped at depth ${lines.map((l) => l.depth).join('/')}';
      } else {
        return [for (final l in lines) _candidate(fen, l)];
      }
      stdout.writeln('  retry ($attempt): $why — $fen');
    }
    throw StateError('Not a fact: $why, twice, at $fen');
  }
}

/// One line as the facts file keeps it: `make_facts.candidates_of`.
Map<String, dynamic> _candidate(String fen, _Line line) {
  final whiteToMove = fen.split(' ')[1] == 'w';
  final pv = AnalysisLine.fromPv(
    multipv: line.rank,
    depth: line.depth,
    eval: '',
    pvString: line.pv,
    startingFen: fen,
  );
  int valueForMover;
  String eval;
  if (line.mate != null) {
    final m = line.mate!; // from the side to move
    valueForMover = (_mate - m.abs()) * (m > 0 ? 1 : -1);
    eval = '#${whiteToMove ? m : -m}';
  } else {
    final cp = line.cp!;
    valueForMover = cp;
    final white = (whiteToMove ? cp : -cp) / 100.0;
    eval = '${white >= 0 ? '+' : ''}${white.toStringAsFixed(2)}';
  }
  return {
    'move': pv.sanMoveList.first,
    'eval': eval,
    'value_for_mover': valueForMover,
    'line': pv.sanMoveList.take(_lineLength).join(' '),
  };
}

typedef _Line = ({int rank, int depth, int? cp, int? mate, String pv});

class _Engine {
  _Engine(this._process, this._lines);

  final Process _process;
  final Stream<String> _lines;

  static Future<_Engine> start(String path) async {
    final process = await Process.start(path, const []);
    final lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream();
    final engine = _Engine(process, lines);
    engine._send('uci');
    await engine._waitFor('uciok');
    engine._send('setoption name Threads value 1');
    engine._send('setoption name Hash value $_hashMb');
    engine._send('isready');
    await engine._waitFor('readyok');
    return engine;
  }

  void _send(String command) => _process.stdin.writeln(command);

  Future<void> _waitFor(String token) =>
      _lines.firstWhere((l) => l.trim() == token).timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw StateError('the engine never said $token'),
          );

  /// The last exact line per rank, or null when `bestmove` never came.
  Future<List<_Line>?> search(String fen,
      {required int depth, required int multiPv}) async {
    _send('ucinewgame');
    _send('isready');
    await _waitFor('readyok');

    final best = <int, _Line>{};
    final done = Completer<void>();
    final sub = _lines.listen((line) {
      if (line.startsWith('bestmove')) {
        if (!done.isCompleted) done.complete();
        return;
      }
      if (!line.startsWith('info ') || !line.contains(' pv ')) return;
      if (line.contains(' lowerbound') || line.contains(' upperbound')) return;
      final reached = _intAfter(line, 'depth');
      if (reached == null) return;
      final rank = _intAfter(line, 'multipv') ?? 1;
      best[rank] = (
        rank: rank,
        depth: reached,
        cp: _intAfter(line, 'score cp'),
        mate: _intAfter(line, 'score mate'),
        pv: line.substring(line.indexOf(' pv ') + 4).trim(),
      );
    });

    _send('setoption name MultiPV value $multiPv');
    _send('position fen $fen');
    _send('go depth $depth');
    try {
      await done.future.timeout(const Duration(minutes: 15));
    } on TimeoutException {
      _send('stop');
      await sub.cancel();
      return null;
    }
    await sub.cancel();
    final ranks = best.keys.toList()..sort();
    return [for (final r in ranks) best[r]!];
  }

  static int? _intAfter(String line, String key) {
    final at = line.indexOf(' $key ');
    if (at < 0) return null;
    final rest = line.substring(at + key.length + 2).trim();
    return int.tryParse(rest.split(RegExp(r'\s+')).first);
  }

  Future<void> stop() async {
    _send('quit');
    await _process.exitCode.timeout(const Duration(seconds: 5), onTimeout: () {
      _process.kill();
      return -1;
    });
  }
}
