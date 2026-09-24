import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:chess/chess.dart' as chess;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:chess_app/features/analysis_studio/services/auto_tree_generator_service.dart'
    show PositionAnalyzer;
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/services/account_local_state.dart';
import 'package:chess_app/services/app_logger.dart';

/// The name of the engine that answers, or null when it has none the store
/// can trust — the online engine, whose depth and build are not ours to know.
/// A null name is remembered for this run only and never written to disk.
typedef EngineName = Future<String?> Function();

/// What one caller's questions cost: how many were answered without a search,
/// how many were searched, and how many of those searches came back short of
/// the depth asked (a timeout) or without every line asked for.
class EngineAnswerTally {
  int fromStore = 0;
  int searched = 0;
  int short = 0;
  int incomplete = 0;
}

/// The engine's answers, by position — kept so a position is not searched
/// twice, in one run or the next (`docs/PLAN-ZAGONETKE-IZ-PARTIJE.md` §3,
/// „The engine's answers are kept", phase 1.1).
///
/// Whole-game review, automatic tree generation and puzzle extraction all walk
/// the same board, and each of them asked the engine from scratch. It attaches
/// as a decorator around a [PositionAnalyzer], a plain function type, so none
/// of them needed changing to benefit.
///
/// What it holds, and why:
///
/// - **the key is the engine and the whole FEN**, move counters included: the
///   halfmove clock changes what the engine reports near the fifty-move rule,
///   and the saving is within a game, where the FENs are identical anyway. The
///   engine is named by [EngineName] — its binary, since the answers are a
///   function of exactly the binary — and two engines' answers never mix;
/// - **an answer serves a question at its depth or shallower, with at least
///   its lines**: a depth-24 answer with two lines serves a depth-20 question
///   with one. The deepest answer that serves is the one given;
/// - **an answer is kept at the depth it reached, never the depth asked.** A
///   search stopped by its timeout hands back what it had, from a shallower
///   depth — on the phone at depth 20 that is a normal day (phase 0, 24.9.2026)
///   — and the in-memory cache before this filed it under the depth asked, so
///   the next caller got a guess labelled 20. An answer without every line
///   asked for is not kept at all;
/// - **several depths are kept** — up to [maxAnswersPerPosition] a position,
///   the deepest — so the deepening's „two deepest depths agree" can be read
///   back rather than searched again;
/// - **the whole line is kept** and each reader cuts it;
/// - **it belongs to the account.** Which positions were searched names the
///   games that were, so it is wiped with the drafts
///   ([AccountLocalState.clear] → [forgetAccount]) and fenced by the same
///   [AccountLocalState.epoch]: a search begun before a sign-out keeps nothing
///   after it;
/// - **it is a cache and is treated as one**: a file that cannot be read is an
///   empty store, and a write that fails costs time, never a result.
///
/// On disk it is sharded by the position's hash — 256 files an engine, each
/// at most [maxPositionsPerShard] positions, the least recently used dropped —
/// and a shard is read the first time one of its positions is asked about.
/// The lines are kept as the engine gave them (value and moves) and turned
/// back into [AnalysisLine]s only when served.
class EvalCache {
  EvalCache({
    this.disk,
    this.maxPositionsPerShard = 200,
    this.maxAnswersPerPosition = 4,
    this.maxShardsInMemory = 64,
  });

  /// Shared by whole-game review, automatic tree generation and puzzle
  /// extraction, because the win is precisely that they see each other's work.
  static final EvalCache instance = EvalCache(disk: AnswerDisk.device());

  /// Where answers are written; null keeps them in memory only.
  final AnswerDisk? disk;

  final int maxPositionsPerShard;
  final int maxAnswersPerPosition;
  final int maxShardsInMemory;

  /// Loaded shards by `engine|shard`, least recently used first.
  final Map<String, _Shard> _shards = {};
  final Map<String, Future<_Shard>> _loading = {};

  /// Searches already running, so two callers asking for the same position at
  /// the same moment share one engine run instead of racing to compute it twice.
  final Map<String, Future<List<AnalysisLine>>> _inFlight = {};

  int _hits = 0;
  int _misses = 0;

  int get hits => _hits;
  int get misses => _misses;

  /// Positions held in memory, over every loaded shard.
  int get size => _shards.values.fold(0, (n, s) => n + s.positions.length);

  /// Forgets what is in memory and the counters. The disk is left alone:
  /// every answer on it names its engine.
  void clear() {
    _shards.clear();
    _loading.clear();
    _inFlight.clear();
    _hits = 0;
    _misses = 0;
  }

  /// Forgets everything this account's searches left, in memory at once and
  /// on disk when the returned future completes. [AccountLocalState.clear]
  /// raises the epoch first, so no write already on its way lands after this.
  Future<void> forgetAccount() {
    clear();
    return disk?.clear() ?? Future.value();
  }

  /// Waits until every answer kept so far is on disk.
  @visibleForTesting
  Future<void> flush() =>
      Future.wait([for (final s in _shards.values) s.chain]);

  /// Wraps [inner] so a position already answered deeply enough is not
  /// searched again. [engine] names who answers; [tally], when given, counts
  /// what this caller's questions cost.
  PositionAnalyzer wrap(
    PositionAnalyzer inner, {
    required EngineName engine,
    EngineAnswerTally? tally,
  }) {
    return (
      String fen, {
      required int depth,
      required int multiPV,
      Duration timeout = const Duration(seconds: 10),
    }) async {
      final epoch = AccountLocalState.epoch;
      final name = await engine() ?? '';

      final served =
          _serve(await _shard(name, fen), fen, depth: depth, multiPV: multiPV);
      if (served != null) {
        _hits++;
        tally?.fromStore++;
        return served;
      }

      final key = '$name|$fen|d$depth|pv$multiPV';
      final running = _inFlight[key];
      if (running != null) {
        _hits++;
        tally?.fromStore++;
        return running;
      }

      _misses++;
      tally?.searched++;
      final future =
          inner(fen, depth: depth, multiPV: multiPV, timeout: timeout);
      _inFlight[key] = future;
      try {
        final lines = await future;
        if (AccountLocalState.isCurrent(epoch)) {
          _keep(await _shard(name, fen), name, fen,
              depth: depth, multiPV: multiPV, lines: lines, tally: tally);
        }
        return lines;
      } finally {
        // Cleared whether the search succeeded or threw, so one failure does
        // not leave a permanently poisoned entry that every later caller awaits.
        _inFlight.remove(key);
      }
    };
  }

  void logStats(String context) {
    final total = _hits + _misses;
    if (total == 0) return;
    final percent = ((_hits / total) * 100).round();
    AppLogger.log(
        '[EvalCache] $context — $_hits/$total from cache ($percent%), $size positions.');
  }

  /// Which of the 256 shards holds [fen].
  static String shardOf(String fen) =>
      sha1.convert(utf8.encode(fen)).toString().substring(0, 2);

  Future<_Shard> _shard(String engine, String fen) {
    final id = shardOf(fen);
    final key = '$engine|$id';
    final loaded = _shards.remove(key);
    if (loaded != null) {
      _shards[key] = loaded; // most recently used last
      return Future.value(loaded);
    }
    return _loading[key] ??= _load(engine, id, key);
  }

  Future<_Shard> _load(String engine, String id, String key) async {
    final epoch = AccountLocalState.epoch;
    var positions = <String, List<_Answer>>{};
    final disk = this.disk;
    if (disk != null && engine.isNotEmpty) {
      positions = await disk._read(engine, id);
    }
    // Read before a wipe and finished after it: what it read is the last
    // account's, and nothing of it is installed.
    if (!AccountLocalState.isCurrent(epoch)) positions = {};
    _loading.remove(key);
    // A wipe in the middle lets a second load of the same shard start; the
    // first one installed wins, so nothing kept into it is dropped.
    final installed = _shards[key];
    if (installed != null) return installed;
    final shard = _Shard(engine, id, positions, AccountLocalState.epoch);
    _shards[key] = shard;
    while (_shards.length > maxShardsInMemory) {
      _shards.remove(_shards.keys.first);
    }
    return shard;
  }

  List<AnalysisLine>? _serve(_Shard shard, String fen,
      {required int depth, required int multiPV}) {
    final answers = shard.positions[fen];
    if (answers == null) return null;
    _Answer? best;
    for (final a in answers) {
      if (a.depth < depth || a.asked < multiPV) continue;
      if (best == null ||
          a.depth > best.depth ||
          (a.depth == best.depth && a.asked > best.asked)) {
        best = a;
      }
    }
    if (best == null) return null;
    shard.positions
      ..remove(fen)
      ..[fen] = answers;
    return List.unmodifiable([
      for (final l in best.lines.take(multiPV))
        AnalysisLine.fromPv(
          multipv: l.multipv,
          depth: l.depth,
          eval: l.eval,
          pvString: l.pv,
          startingFen: fen,
        ),
    ]);
  }

  void _keep(_Shard shard, String engine, String fen,
      {required int depth,
      required int multiPV,
      required List<AnalysisLine> lines,
      EngineAnswerTally? tally}) {
    final answer = _Answer.of(fen, multiPV, lines);
    if (answer == null) {
      tally?.incomplete++;
      return;
    }
    if (answer.depth < depth) tally?.short++;

    final answers = shard.positions.remove(fen) ?? <_Answer>[];
    final dominated =
        answers.any((a) => a.depth >= answer.depth && a.asked >= answer.asked);
    if (!dominated) {
      answers
        ..removeWhere((a) => a.depth == answer.depth && a.asked <= answer.asked)
        ..add(answer)
        ..sort((a, b) => b.depth.compareTo(a.depth));
      if (answers.length > maxAnswersPerPosition) {
        answers.removeRange(maxAnswersPerPosition, answers.length);
      }
    }
    shard.positions[fen] = answers;
    while (shard.positions.length > maxPositionsPerShard) {
      shard.positions.remove(shard.positions.keys.first);
    }
    if (!dominated) _schedule(shard);
  }

  /// Writes [shard] after whatever write is running; answers that arrive in
  /// the meantime are carried by the next one.
  void _schedule(_Shard shard) {
    final disk = this.disk;
    if (disk == null || shard.engine.isEmpty || shard.queued) return;
    shard.queued = true;
    shard.chain = shard.chain.then((_) async {
      shard.queued = false;
      try {
        await disk._write(shard.engine, shard.id, shard.positions,
            epoch: shard.epoch);
      } catch (e) {
        AppLogger.log('[EvalCache] ⚠️ shard ${shard.id} not written: $e');
      }
    });
  }
}

class _Shard {
  _Shard(this.engine, this.id, this.positions, this.epoch);

  final String engine;
  final String id;

  /// By FEN, least recently used first.
  final Map<String, List<_Answer>> positions;

  /// The account this shard was read for: it writes nothing after a wipe.
  final int epoch;

  Future<void> chain = Future.value();
  bool queued = false;
}

class _Line {
  const _Line(this.multipv, this.depth, this.eval, this.pv);

  final int multipv;
  final int depth;
  final String eval;
  final String pv;

  Map<String, Object> toJson() =>
      {'multipv': multipv, 'depth': depth, 'eval': eval, 'pv': pv};

  static _Line fromJson(Map<String, dynamic> j) => _Line(j['multipv'] as int,
      j['depth'] as int, j['eval'] as String, j['pv'] as String);
}

/// One search's answer: the depth every line reached, and how many lines
/// were asked for.
class _Answer {
  _Answer(this.depth, this.asked, this.lines);

  final int depth;
  final int asked;
  final List<_Line> lines;

  /// The answer [lines] give to a question for [multiPV] lines, or null when
  /// they are not a whole answer: lines 1 to n, each with a move, n being the
  /// lines asked or every legal move where there are fewer, at a depth the
  /// engine actually reported. The depth is the shallowest line's.
  static _Answer? of(String fen, int multiPV, List<AnalysisLine> lines) {
    final sorted = [...lines]..sort((a, b) => a.multipv.compareTo(b.multipv));
    final kept = sorted.take(multiPV).toList();
    if (kept.isEmpty) return null;
    for (var i = 0; i < kept.length; i++) {
      if (kept[i].multipv != i + 1 || kept[i].bestMoveLan.isEmpty) return null;
    }
    if (kept.length < multiPV) {
      final int legal;
      try {
        legal = chess.Chess.fromFEN(fen).moves().length;
      } catch (_) {
        return null;
      }
      if (kept.length < legal) return null;
    }
    final depth = kept.map((l) => l.depth).reduce((a, b) => a < b ? a : b);
    if (depth < 1) return null;
    return _Answer(depth, multiPV, [
      for (final l in kept)
        _Line(l.multipv, l.depth, l.evaluation, l.continuationLan.trim()),
    ]);
  }

  Map<String, Object> toJson() => {
        'depth': depth,
        'asked': asked,
        'lines': [for (final l in lines) l.toJson()],
      };

  static _Answer fromJson(Map<String, dynamic> j) => _Answer(
        j['depth'] as int,
        j['asked'] as int,
        [
          for (final l in j['lines'] as List)
            _Line.fromJson(Map<String, dynamic>.from(l as Map))
        ],
      );
}

/// The store's files: a folder per engine, a file per shard.
class AnswerDisk {
  AnswerDisk(this._root);

  /// Under the app's support directory, beside the tutorial's answers.
  factory AnswerDisk.device() => AnswerDisk(() async {
        final support = await getApplicationSupportDirectory();
        return Directory(
            '${support.path}${Platform.pathSeparator}engine_answers');
      });

  static const int version = 1;

  final Future<Directory> Function() _root;

  Future<File> _file(String engine, String shard) async {
    final root = await _root();
    final folder =
        sha1.convert(utf8.encode(engine)).toString().substring(0, 16);
    return File(
        [root.path, folder, '$shard.json'].join(Platform.pathSeparator));
  }

  /// A shard's answers by FEN, in the order they were last used; empty when
  /// there are none or the file cannot be trusted.
  Future<Map<String, List<_Answer>>> _read(String engine, String shard) async {
    try {
      final file = await _file(engine, shard);
      if (!await file.exists()) return {};
      final data = jsonDecode(await file.readAsString());
      if (data is! Map ||
          data['version'] != version ||
          data['engine'] != engine ||
          data['positions'] is! Map) {
        return {};
      }
      return {
        for (final e in (data['positions'] as Map).entries)
          e.key as String: [
            for (final a in e.value as List)
              _Answer.fromJson(Map<String, dynamic>.from(a as Map))
          ]
      };
    } catch (_) {
      return {};
    }
  }

  /// Writes [positions] unless the account of [epoch] has gone by the time
  /// the file would land. Asked at the last step, not the first: a sign-out
  /// that comes while the file is being written must still find nothing of
  /// the last account on disk afterwards.
  Future<void> _write(
      String engine, String shard, Map<String, List<_Answer>> positions,
      {required int epoch}) async {
    final file = await _file(engine, shard);
    await file.parent.create(recursive: true);
    // Written beside the file and renamed onto it: a crash in the middle
    // leaves the previous version whole, never half of this one.
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode({
      'version': version,
      'engine': engine,
      'positions': {
        for (final e in positions.entries)
          e.key: [for (final a in e.value) a.toJson()]
      },
    }));
    if (!AccountLocalState.isCurrent(epoch)) {
      await temporary.delete();
      return;
    }
    await temporary.rename(file.path);
  }

  Future<void> clear() async {
    final root = await _root();
    if (await root.exists()) await root.delete(recursive: true);
  }
}
