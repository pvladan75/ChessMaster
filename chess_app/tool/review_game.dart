/// „Review entire game", without the app open.
///
///     set REVIEW_IN=<a .pgn with one game in it>
///     set REVIEW_OUT=<where the annotated .pgn goes>
///     set REVIEW_DEPTH=18
///     set REVIEW_THRESHOLD=0.8
///     flutter test tool/review_game.dart
///
/// Written for the language-model experiment in `tools/game_annotate/`, whose
/// arm B is fed „the game after the app's own review pass". Until now that
/// input could only be made by a person opening Analysis, pressing the button
/// and copying the result out — so a second game meant a manual step, and the
/// experiment could not be re-run on a hundred games by anybody.
///
/// **It is an entry point, not a second implementation.** Every sentence, every
/// `??` and every „Better move" branch is written by
/// `GameAnalysisWalkerService`, which is the same code the dialog drives;
/// `annotateNodeChain` and `tagBlunders` take an analyzer as an argument, and
/// all this file supplies is one that speaks UCI to a Stockfish binary instead
/// of to the app's plugin. The defaults below are the dialog's defaults, and
/// they are named here so a difference is visible rather than silent.
///
/// **Why a test and not a script.** `dart run` cannot load it: the walker
/// imports `auto_tree_generator_service.dart` for the `PositionAnalyzer`
/// typedef, which reaches `app_settings_service` and the Stockfish plugin, and
/// `PgnExporterService` imports `package:flutter/services.dart` for the
/// clipboard. `flutter test` gives those imports a home. It lives in `tool/`
/// rather than `test/`, so `flutter test` on its own never picks it up and the
/// suite's count is untouched.
///
/// **The tags are not identical to a run made inside the app**, and the reason
/// is not known well enough to claim otherwise: on the game in
/// `tools/game_annotate/input/`, this tags seven moves where the trainer's own
/// run tagged ten, at 0.8 pawns and depth 14. Every one of the seven is in
/// their ten, and every motif sentence matches theirs character for character —
/// that half is the shared services doing their job. What differs is the
/// engine underneath: their run used the trainer's own depth setting, the app's
/// plugin build and its eval cache, none of which is recorded in the PGN it
/// wrote. Say which settings a file was made with rather than assuming it
/// matches one made in the app.
///
/// It fails, loudly, when `REVIEW_IN` is not set.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/core/services/game_analysis_walker_service.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/move_tree.dart';

/// The dialog's own defaults, quoted so a drift between the two is visible.
/// `game_review_dialog.dart`: threshold 2.0 pawns, both sides, the engine's
/// line inserted, four plies of it. The depth there comes from the trainer's
/// settings; 14 is `GameAnalysisWalkerService`'s own default.
const int _defaultDepth = 14;
const double _defaultThreshold = 2.0;

void main() {
  final input = Platform.environment['REVIEW_IN'];
  final output = Platform.environment['REVIEW_OUT'];
  final depth =
      int.tryParse(Platform.environment['REVIEW_DEPTH'] ?? '') ?? _defaultDepth;
  final threshold =
      double.tryParse(Platform.environment['REVIEW_THRESHOLD'] ?? '') ??
          _defaultThreshold;

  test('reviews a game and writes the annotated PGN', () async {
    if (input == null || output == null) {
      fail('Set REVIEW_IN and REVIEW_OUT. See the comment at the top of '
          'tool/review_game.dart.');
    }

    final text = File(input).readAsStringSync();
    // No `[FEN]` header means the standard opening position — the same rule
    // the app applies to a pasted game.
    final fen = MoveTree.fenHeaderOf(text) ??
        'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    final read = readStepTree(fen: fen, pgn: text);
    final root = read.root;

    var moves = 0;
    for (var node = root;
        node.children.isNotEmpty;
        node = node.children.first) {
      moves++;
    }
    stdout.writeln('$moves moves read from ${File(input).uri.pathSegments.last}'
        '${read.rejectedMoves > 0 ? ', ${read.rejectedMoves} refused' : ''}');
    expect(moves, greaterThan(0), reason: 'the PGN holds no playable moves');

    final engine = await _Engine.start();
    try {
      final walker = GameAnalysisWalkerService();
      final result = await walker.annotateNodeChain(
        startNode: root,
        analyzer: engine.analyse,
        depth: depth,
        onProgress: (done, total) {
          if (done % 10 == 0 || done == total) {
            stdout.writeln('  $done / $total positions');
          }
        },
      );
      final tagged = walker.tagBlunders(
        chain: result.chain,
        moments: result.moments,
        threshold: threshold,
      );
      stdout
          .writeln('$tagged blunders tagged at $threshold pawns, depth $depth');

      File(output).writeAsStringSync(PgnExporterService.exportToPgn(root));
      stdout.writeln('written: $output');
    } finally {
      engine.stop();
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}

/// One Stockfish process, spoken to in UCI.
///
/// One process for the whole game rather than one per position: a review asks
/// about eighty positions, and the hash it keeps between them is most of what
/// makes the later ones quick.
class _Engine {
  _Engine(this._process, this._lines);

  final Process _process;
  final Stream<String> _lines;

  static const _guesses = [
    r'%APPDATA%\rs.pejovic\Mislisha\engine\stockfish.exe',
    r'%APPDATA%\com.example\chess_app\engine\stockfish.exe',
  ];

  static Future<_Engine> start() async {
    final path = _find();
    final process = await Process.start(path, const []);
    final lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .asBroadcastStream();
    final engine = _Engine(process, lines);
    engine._send('uci');
    await engine._waitFor('uciok');
    engine._send('setoption name Threads value 1');
    engine._send('setoption name Hash value 128');
    engine._send('isready');
    await engine._waitFor('readyok');
    stdout.writeln('engine: $path');
    return engine;
  }

  static String _find() {
    final given = Platform.environment['STOCKFISH_PATH'];
    for (final candidate in [given, ..._guesses]) {
      if (candidate == null) continue;
      final path = candidate.replaceAllMapped(
          RegExp(r'%(\w+)%'), (m) => Platform.environment[m.group(1)!] ?? '');
      if (File(path).existsSync()) return path;
    }
    // Loud, because a review that quietly analysed nothing looks exactly like
    // a review that analysed everything.
    throw StateError('Stockfish not found. Set STOCKFISH_PATH.');
  }

  void _send(String command) => _process.stdin.writeln(command);

  Future<void> _waitFor(String token) =>
      _lines.firstWhere((l) => l.trim() == token).timeout(
            const Duration(seconds: 20),
            onTimeout: () => throw StateError('the engine never said $token'),
          );

  /// The shape `PositionAnalyzer` asks for. Structural typing, so this file
  /// does not have to import the typedef's home.
  Future<List<AnalysisLine>> analyse(
    String fen, {
    required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final whiteToMove = fen.split(' ').length > 1 && fen.split(' ')[1] == 'w';
    final best = <int, ({int depth, String eval, String pv})>{};
    final done = Completer<void>();

    final sub = _lines.listen((line) {
      if (line.startsWith('bestmove')) {
        if (!done.isCompleted) done.complete();
        return;
      }
      if (!line.startsWith('info ') || !line.contains(' pv ')) return;

      final reached = _intAfter(line, 'depth');
      final pv = line.substring(line.indexOf(' pv ') + 4).trim();
      final rank = _intAfter(line, 'multipv') ?? 1;
      if (reached == null || pv.isEmpty) return;

      final mate = _intAfter(line, 'score mate');
      final cp = _intAfter(line, 'score cp');
      String? eval;
      if (mate != null) {
        // UCI reports from the side to move; the app's strings are always
        // White-relative, and `parseWhiteRelativeEval` reads `M4` / `-M4`.
        final signed = whiteToMove ? mate : -mate;
        eval = '${signed < 0 ? '-' : ''}M${signed.abs()}';
      } else if (cp != null) {
        final signed = (whiteToMove ? cp : -cp) / 100.0;
        eval = signed.toStringAsFixed(2);
      }
      if (eval == null) return;

      final held = best[rank];
      if (held == null || reached >= held.depth) {
        best[rank] = (depth: reached, eval: eval, pv: pv);
      }
    });

    _send('ucinewgame');
    _send('setoption name MultiPV value $multiPV');
    _send('position fen $fen');
    _send('go depth $depth');

    try {
      await done.future.timeout(timeout);
    } on TimeoutException {
      _send('stop');
    } finally {
      await sub.cancel();
    }

    final ranks = best.keys.toList()..sort();
    return [
      for (final rank in ranks)
        AnalysisLine.fromPv(
          multipv: rank,
          depth: best[rank]!.depth,
          eval: best[rank]!.eval,
          pvString: best[rank]!.pv,
          startingFen: fen,
        ),
    ];
  }

  static int? _intAfter(String line, String key) {
    final at = line.indexOf('$key ');
    if (at < 0) return null;
    final rest = line.substring(at + key.length + 1).trim();
    final token = rest.split(RegExp(r'\s+')).first;
    return int.tryParse(token);
  }

  void stop() {
    _send('quit');
    _process.kill();
  }
}
