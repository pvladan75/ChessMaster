import 'package:chess_app/core/services/eval_cache.dart';
import 'package:chess_app/services/app_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stockfish/stockfish.dart';

import 'package:chess_app/models/analysis_models.dart';

class StockfishService {
  // ─── SINGLETON ───
  static final StockfishService _instance = StockfishService._internal();
  factory StockfishService() => _instance;
  StockfishService._internal();

  Stockfish? _stockfish;
  StreamSubscription? _subscription;

  Process? _customProcess;
  StreamSubscription? _customSubscription;
  bool _isCustomActive = false;

  Function(String evaluation, String bestMove, String continuation, int multipv,
      int depth, bool isFinal, String analyzedFen)? onEvaluationChanged;
  Function(Map<int, AnalysisLine> lines)? onMultiPVUpdated;
  final Map<int, AnalysisLine> _engineLines = {};

  bool _isActive = false;
  int _requestId = 0;
  String _currentFen = '';

  // Track engine readiness
  bool _nativeReady = false;
  bool _initInProgress = false;

  // Pending position to analyze if engine is still initializing
  String? _pendingFen;
  int? _pendingDepth;
  int _currentMultiPV = 1;

  // Rapid re-navigation (e.g. clicking through the graphical move tree)
  // used to fire a fresh "stop"+"position"+"go depth N" at the engine on
  // every click. At high depths the native engine can take a while to
  // actually honor "stop" mid-search, so a burst of clicks could pile up
  // faster than the engine drained them and it would appear to freeze.
  // Debouncing coalesces a burst into a single request for the last position.
  Timer? _analyzeDebounceTimer;

  bool get isCustomEngineActive => _isCustomActive;

  bool get _useOnline {
    if (Platform.isWindows && _isCustomActive) return false;
    return Platform.isWindows || Platform.isLinux;
  }

  bool get isActive =>
      _useOnline ? _isActive : (_stockfish != null || _customProcess != null);
  bool get isSupported => true;
  bool get isOnline => _useOnline;

  /// Starts the Stockfish engine (or sets up online mode).
  /// Safe to call multiple times — if engine is already ready, returns immediately.
  Future<void> initEngine() async {
    _isActive = true;

    // If engine is already initialized and ready, nothing to do
    if (_nativeReady &&
        (_stockfish != null || _customProcess != null || _useOnline)) {
      AppLogger.log(
          '[StockfishService] ♻️ Engine already initialized and ready (singleton). Draining any pending queue...');
      _drainPendingQueue();
      return;
    }

    if (_initInProgress) {
      AppLogger.log(
          '[StockfishService] ⏳ initEngine already in progress, skipping duplicate call.');
      return;
    }
    _initInProgress = true;
    AppLogger.log(
        '[StockfishService] 🛠️ initEngine called | CustomActive: $_isCustomActive | UseOnline: $_useOnline');

    // Cached evaluations belong to whichever engine produced them, and the
    // engine's identity is not part of the cache key. Starting a different
    // binary — or switching between the local and online engine — must not
    // inherit the previous one's answers.
    EvalCache.instance.clear();

    // Check if custom engine path is set (Windows only)
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('custom_engine_path');

      if (customPath != null && customPath.isNotEmpty && Platform.isWindows) {
        if (_customProcess != null) {
          _nativeReady = true;
          _initInProgress = false;
          _drainPendingQueue();
          return;
        }
        AppLogger.log(
            '[StockfishService] 🚀 Starting custom engine at: $customPath');
        _customProcess = await Process.start(customPath, []);
        _isCustomActive = true;
        _nativeReady = true;

        _customSubscription = _customProcess!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          _parseStockfishLine(line);
        });

        _sendCommandForce('uci');
        _sendCommandForce('setoption name MultiPV value 3');
        _sendCommandForce('isready');
        _drainPendingQueue();
        _initInProgress = false;
        return;
      }
    } catch (e) {
      AppLogger.log('[StockfishService ERROR] ❌ Custom engine failed: $e');
      _isCustomActive = false;
      _customProcess = null;
    }

    _isCustomActive = false;
    if (_useOnline) {
      AppLogger.log(
          '[StockfishService] 🌐 Using Online Stockfish Cloud API Fallback');
      _nativeReady = true;
      _initInProgress = false;
      _drainPendingQueue();
      return;
    }

    // ── Native Stockfish (Android/iOS) ──
    // Reuse existing instance if it's still alive and ready
    if (_stockfish != null && _nativeReady) {
      AppLogger.log(
          '[StockfishService] ♻️ Reusing existing native Stockfish instance.');
      _initInProgress = false;
      _drainPendingQueue();
      return;
    }

    // Kill old broken instance if it exists but never became ready
    if (_stockfish != null && !_nativeReady) {
      AppLogger.log(
          '[StockfishService] 🔄 Disposing stale Stockfish instance...');
      _subscription?.cancel();
      _subscription = null;
      try {
        _stockfish?.dispose();
      } catch (_) {}
      _stockfish = null;
      // Small delay to let the FFI process fully terminate
      await Future.delayed(const Duration(milliseconds: 300));
    }

    AppLogger.log(
        '[StockfishService] ⚙️ Creating new Native Stockfish instance...');
    _stockfish = Stockfish();

    _subscription = _stockfish!.stdout.listen((line) {
      _parseStockfishLine(line);
    });

    // Wait for the Stockfish FFI process to become ready
    final ready = await _waitForReady(timeout: const Duration(seconds: 5));

    if (ready) {
      AppLogger.log(
          '[StockfishService] ✅ Native Stockfish is READY! Sending UCI init commands...');
      _nativeReady = true;
      _sendCommandForce('uci');
      _sendCommandForce('setoption name MultiPV value 3');
      _sendCommandForce('isready');
      _drainPendingQueue();
    } else {
      AppLogger.log(
          '[StockfishService ERROR] ❌ Stockfish not ready within 5s. Retrying...');
      _subscription?.cancel();
      try {
        _stockfish?.dispose();
      } catch (_) {}
      _stockfish = null;
      await Future.delayed(const Duration(milliseconds: 300));

      _stockfish = Stockfish();
      _subscription = _stockfish!.stdout.listen((line) {
        _parseStockfishLine(line);
      });

      final retryReady =
          await _waitForReady(timeout: const Duration(seconds: 8));
      if (retryReady) {
        AppLogger.log('[StockfishService] ✅ Stockfish READY on retry!');
        _nativeReady = true;
        _sendCommandForce('uci');
        _sendCommandForce('setoption name MultiPV value 3');
        _sendCommandForce('isready');
        _drainPendingQueue();
      } else {
        AppLogger.log(
            '[StockfishService ERROR] ❌ Stockfish failed after retry. Using material fallback.');
        if (_pendingFen != null) {
          _fallbackBasicEvaluation(_pendingFen!, _pendingDepth ?? 18);
          _pendingFen = null;
          _pendingDepth = null;
        }
      }
    }
    _initInProgress = false;
  }

  /// Waits for the Stockfish state to become ready, with a timeout.
  Future<bool> _waitForReady({required Duration timeout}) async {
    if (_stockfish == null) return false;
    if (_stockfish!.state.value == StockfishState.ready) return true;

    final completer = Completer<bool>();
    Timer? timer;

    void listener() {
      if (_stockfish?.state.value == StockfishState.ready) {
        if (!completer.isCompleted) {
          timer?.cancel();
          completer.complete(true);
        }
      } else if (_stockfish?.state.value == StockfishState.error ||
          _stockfish?.state.value == StockfishState.disposed) {
        if (!completer.isCompleted) {
          timer?.cancel();
          completer.complete(false);
        }
      }
    }

    _stockfish!.state.addListener(listener);

    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        AppLogger.log('[StockfishService] ⏰ Timeout waiting for ready state.');
        completer.complete(false);
      }
    });

    final result = await completer.future;
    _stockfish?.state.removeListener(listener);
    return result;
  }

  /// Drains the pending FEN queue
  void _drainPendingQueue() {
    if (_pendingFen != null) {
      final fen = _pendingFen!;
      final depth = _pendingDepth ?? 18;
      _pendingFen = null;
      _pendingDepth = null;
      AppLogger.log(
          '[StockfishService] 🎯 Draining queue → analyzing FEN: $fen');
      analyzePosition(fen, depth: depth);
    }
  }

  /// Clears callbacks (call when a screen disposes to avoid stale references)
  void clearCallbacks() {
    onEvaluationChanged = null;
    onMultiPVUpdated = null;
  }

  // ─── SUBSCRIBER STACK ───
  // Every screen shares this one engine instance. A screen attaches while it is
  // on top of the navigation stack and detaches when it pops. Because detaching
  // reactivates whichever screen is underneath, returning from a pushed screen
  // no longer leaves the screen below with null callbacks and a silently dead
  // engine.
  final List<_EngineSubscriber> _subscribers = [];

  /// Registers [owner]'s callbacks and makes them the active ones.
  /// Re-attaching the same owner replaces its previous registration.
  void attach(
    Object owner, {
    Function(String evaluation, String bestMove, String continuation,
            int multipv, int depth, bool isFinal, String analyzedFen)?
        onEvaluation,
    Function(Map<int, AnalysisLine> lines)? onMultiPV,
    String Function()? getFen,
    bool Function()? isEnabled,
  }) {
    _subscribers.removeWhere((s) => identical(s.owner, owner));
    _subscribers.add(_EngineSubscriber(
      owner,
      onEvaluation,
      onMultiPV,
      getFen: getFen,
      isEnabled: isEnabled,
    ));
    AppLogger.log(
        '[StockfishService] 🔗 attach(${owner.runtimeType}) — ${_subscribers.length} subscriber(s)');
    _activateTopSubscriber();
  }

  /// Removes [owner] and hands the engine back to the screen underneath.
  void detach(Object owner) {
    final removed = _subscribers.any((s) => identical(s.owner, owner));
    _subscribers.removeWhere((s) => identical(s.owner, owner));
    if (removed) {
      AppLogger.log(
          '[StockfishService] 🔓 detach(${owner.runtimeType}) — ${_subscribers.length} subscriber(s) left');
    }
    stopAnalysis();
    _activateTopSubscriber();
  }

  /// Manually triggers re-analysis for the active top subscriber (e.g. after settings dialog closes or route resumes)
  void reactivateTopSubscriber() {
    stopAnalysis();
    _activateTopSubscriber();
  }

  void _activateTopSubscriber() {
    if (_subscribers.isEmpty) {
      onEvaluationChanged = null;
      onMultiPVUpdated = null;
      return;
    }
    final top = _subscribers.last;
    onEvaluationChanged = top.onEvaluation;
    onMultiPVUpdated = top.onMultiPV;

    // Automatically trigger analysis for current visible board position if engine is ON
    final active = top.isEnabled?.call() ?? true;
    final currentFen = top.getFen?.call();

    if (active &&
        currentFen != null &&
        currentFen.isNotEmpty &&
        _currentFen != currentFen) {
      AppLogger.log(
          '[StockfishService] 🔄 Auto-triggering evaluation for top subscriber (${top.owner.runtimeType}) | FEN: $currentFen');
      analyzePosition(currentFen);
    }
  }

  /// Sends a FEN position for analysis. Debounced: a burst of calls (e.g.
  /// clicking through several tree nodes quickly) only actually reaches the
  /// engine for the last one, instead of piling up "stop"+"go" commands
  /// faster than the engine can honor them.
  Future<void> analyzePosition(String fen,
      {int depth = 18, bool isInfinite = false}) async {
    _analyzeDebounceTimer?.cancel();
    final completer = Completer<void>();
    _analyzeDebounceTimer = Timer(const Duration(milliseconds: 180), () async {
      await _runAnalyzePosition(fen, depth: depth, isInfinite: isInfinite);
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  Future<void> _runAnalyzePosition(String fen,
      {int depth = 18, bool isInfinite = false}) async {
    _currentFen = fen;
    _engineLines.clear();
    _isActive = true;

    AppLogger.log(
        '[STOCKFISH_ENGINE_LOG] 🎯 Analiza | Dubina: $depth | Mode: ${_useOnline ? "Online API" : "Nativni Engine"} | FEN: $fen');

    if (_useOnline) {
      final reqId = ++_requestId;
      final effectiveDepth = depth.clamp(5, 50);

      // Try Lichess Cloud Eval API first
      try {
        final cloudUrl =
            'https://lichess.org/api/cloud-eval?fen=${Uri.encodeComponent(fen)}';
        final cloudRes = await http
            .get(Uri.parse(cloudUrl))
            .timeout(const Duration(seconds: 4));

        if (reqId == _requestId && cloudRes.statusCode == 200) {
          final cloudData = jsonDecode(cloudRes.body);
          final pvsRaw = cloudData['pvs'] as List?;
          if (pvsRaw != null && pvsRaw.isNotEmpty) {
            final depthVal =
                ((cloudData['depth'] as int?) ?? effectiveDepth).clamp(5, 50);
            final bool isBlackToMove = fen.contains(' b ');
            // Lichess returns up to 5 PVs when the position is in its DB;
            // surface as many as the user asked for instead of only the top one.
            final pvsToUse = pvsRaw.take(_currentMultiPV).toList();

            String evalFor(dynamic pv) {
              if (pv['cp'] != null) {
                double score = (pv['cp'] as num) / 100.0;
                if (isBlackToMove) score = -score;
                return score > 0
                    ? '+${score.toStringAsFixed(2)}'
                    : score.toStringAsFixed(2);
              } else if (pv['mate'] != null) {
                int mate = pv['mate'] as int;
                if (isBlackToMove) mate = -mate;
                return mate > 0 ? 'M$mate' : '-M${mate.abs()}';
              }
              return '0.00';
            }

            final topMoves = pvsToUse
                .map((pv) => (pv['moves'] as String? ?? '').trim())
                .toList();
            if (topMoves.isNotEmpty && topMoves.first.isNotEmpty) {
              final bestMove = topMoves.first.split(RegExp(r'\s+')).first;
              final bestEval = evalFor(pvsToUse.first);

              for (int d = 1; d <= depthVal; d += 2) {
                if (reqId != _requestId) return;
                if (onEvaluationChanged != null) {
                  onEvaluationChanged!(bestEval, bestMove, topMoves.first, 1, d,
                      d >= depthVal, fen);
                }
                final linesMap = <int, AnalysisLine>{};
                for (int i = 0; i < pvsToUse.length; i++) {
                  final movesStr = topMoves[i];
                  if (movesStr.isEmpty) continue;
                  linesMap[i + 1] = AnalysisLine.fromPv(
                    multipv: i + 1,
                    depth: d,
                    eval: evalFor(pvsToUse[i]),
                    pvString: movesStr,
                    startingFen: fen,
                  );
                }
                if (onMultiPVUpdated != null) onMultiPVUpdated!(linesMap);
                await Future.delayed(const Duration(milliseconds: 25));
              }
              if (onEvaluationChanged != null) {
                onEvaluationChanged!(
                    bestEval, bestMove, topMoves.first, 1, depthVal, true, fen);
              }
              return;
            }
          }
        }
      } catch (_) {}

      // Fallback to stockfish.online API v2
      try {
        final onlineDepth = effectiveDepth > 20 ? 20 : effectiveDepth;
        final url =
            'https://stockfish.online/api/s/v2.php?fen=${Uri.encodeComponent(fen)}&depth=$onlineDepth';
        final response =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

        if (reqId != _requestId) return;

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            bool isBlackToMove = fen.contains(' b ');
            String eval = '0.00';
            if (data['mate'] != null) {
              int mate = data['mate'] as int;
              if (isBlackToMove) mate = -mate;
              eval = mate > 0 ? 'M$mate' : '-M${mate.abs()}';
            } else if (data['evaluation'] != null) {
              double score = (data['evaluation'] as num).toDouble();
              if (isBlackToMove) score = -score;
              eval = score > 0
                  ? '+${score.toStringAsFixed(2)}'
                  : score.toStringAsFixed(2);
            }

            String bestMove = '-';
            if (data['bestmove'] != null) {
              final bestStr = data['bestmove'] as String;
              final match = RegExp(r'bestmove\s+(\S+)').firstMatch(bestStr);
              if (match != null) bestMove = match.group(1)!;
            }

            String continuation = data['continuation'] as String? ?? '';

            for (int d = 1; d <= onlineDepth; d += 2) {
              if (reqId != _requestId) return;
              if (onEvaluationChanged != null) {
                onEvaluationChanged!(
                    eval, bestMove, continuation, 1, d, d >= onlineDepth, fen);
              }
              final line = AnalysisLine.fromPv(
                  multipv: 1,
                  depth: d,
                  eval: eval,
                  pvString: continuation.isNotEmpty ? continuation : bestMove,
                  startingFen: fen);
              if (onMultiPVUpdated != null) onMultiPVUpdated!({1: line});
              await Future.delayed(const Duration(milliseconds: 25));
            }
            if (onEvaluationChanged != null) {
              onEvaluationChanged!(
                  eval, bestMove, continuation, 1, onlineDepth, true, fen);
            }
            return;
          }
        }
      } catch (_) {}

      _fallbackBasicEvaluation(fen, effectiveDepth);
    } else {
      // ── Native engine path ──
      if (!_nativeReady) {
        AppLogger.log(
            '[StockfishService] ⏳ Engine not ready. Queuing FEN and triggering initEngine...');
        _pendingFen = fen;
        _pendingDepth = depth;
        if (!_initInProgress) {
          initEngine();
        }
        return;
      }

      await _stopAndDrain();
      _sendCommandForce('position fen $fen');
      final effectiveDepth = depth.clamp(5, 50);
      AppLogger.log('[STOCKFISH_NATIVE] 🎯 go depth $effectiveDepth');
      _sendCommandForce('go depth $effectiveDepth');
      _searchInFlight = true;
    }
  }

  /// Whether we're currently waiting out a previous search's trailing output
  /// (see [_stopAndDrain]). While true, [_parseStockfishLine] discards
  /// "info"/"bestmove" lines instead of routing them to the active callback.
  bool _awaitingStopDrain = false;

  /// Whether a "go" has been sent whose "bestmove" hasn't arrived yet.
  bool _searchInFlight = false;

  Completer<void>? _readyOkCompleter;
  Completer<void>? _bestMoveCompleter;

  /// Stops the current search and waits for the engine to fully drain it
  /// before the caller sends a new "position"/"go".
  ///
  /// Two things had to be true before a new query was safe to send, and
  /// getting only one of them wasn't enough in practice:
  ///
  /// 1. Wait for "bestmove" — UCI guarantees a "go" is always terminated by
  ///    exactly one "bestmove", stop included, so that line is the hard
  ///    proof the old search has nothing left to say.
  /// 2. *Also* wait for "isready"/"readyok" afterwards — this specific
  ///    engine was observed sending "readyok" while an "info" line for the
  ///    old search was still in flight around it (arriving on either side,
  ///    not strictly before), so "readyok" alone isn't a reliable boundary.
  ///
  /// Without both, a deep in-flight search (e.g. depth 30 from a screen's
  /// live evaluation) keeps emitting "info"/"bestmove" lines for the OLD
  /// position for a little while after "stop" is sent. Those stray lines
  /// would otherwise be parsed and handed to whichever callback is
  /// currently attached — which, for a sequence of quick recursive queries
  /// (the auto-analysis tree generator), is the NEXT query, not the one
  /// that just finished. That leaked stale moves in as phantom candidates
  /// (occasionally outright illegal ones), which then failed to parse or
  /// got pruned, leaving that branch of the tree with zero children.
  Future<void> _stopAndDrain(
      {Duration timeout = const Duration(seconds: 3)}) async {
    _awaitingStopDrain = true;

    if (_searchInFlight) {
      final bestMoveCompleter = Completer<void>();
      _bestMoveCompleter = bestMoveCompleter;
      _sendCommandForce('stop');
      await bestMoveCompleter.future.timeout(timeout, onTimeout: () {
        AppLogger.log(
            '[StockfishService] ⚠️ bestmove timeout while draining previous search — proceeding anyway.');
      });
      _bestMoveCompleter = null;
    } else {
      _sendCommandForce('stop');
    }

    final readyCompleter = Completer<void>();
    _readyOkCompleter = readyCompleter;
    _sendCommandForce('isready');
    await readyCompleter.future.timeout(timeout, onTimeout: () {
      AppLogger.log(
          '[StockfishService] ⚠️ isready timeout while draining previous search — proceeding anyway.');
    });
    _readyOkCompleter = null;

    _awaitingStopDrain = false;
  }

  /// Crude material count, from White's perspective — the same convention every
  /// other evaluation in this file uses.
  ///
  /// It used to negate the result when black was to move, which is what the
  /// engine paths do to Stockfish's score: Stockfish reports from the side to
  /// move, so it has to be flipped. `whiteVal - blackVal` is *already* from
  /// White's side, and flipping it a second time inverted the answer. A
  /// position where black was a pawn up therefore displayed as `+1.00`, and a
  /// trainer had no way to tell it apart from an engine result saying white was
  /// better.
  static double materialEvaluation(String fen) {
    final fenBoard = fen.split(' ')[0];
    int whiteVal = 0, blackVal = 0;
    for (int i = 0; i < fenBoard.length; i++) {
      final c = fenBoard[i];
      if (c == 'P') whiteVal += 1;
      if (c == 'N' || c == 'B') whiteVal += 3;
      if (c == 'R') whiteVal += 5;
      if (c == 'Q') whiteVal += 9;
      if (c == 'p') blackVal += 1;
      if (c == 'n' || c == 'b') blackVal += 3;
      if (c == 'r') blackVal += 5;
      if (c == 'q') blackVal += 9;
    }
    return (whiteVal - blackVal).toDouble();
  }

  /// Last resort when the engine will not answer.
  ///
  /// Counting material is not analysis and must not look like it. Reporting it
  /// at the depth that was *asked for* produced "Eval: +1.00 (depth: 18)" for a
  /// number no search ever computed — a fallback that reports success, which is
  /// the failure this codebase keeps meeting. Depth is therefore 0, and the
  /// reason goes to the log where it can be found.
  void _fallbackBasicEvaluation(String fen, int depth) {
    double evalScore = 0.0;
    try {
      evalScore = materialEvaluation(fen);
    } catch (_) {}

    AppLogger.log(
      '[StockfishService] ⚠️ Motor nije odgovorio za $fen (tražena dubina $depth). '
      'Prikazuje se gruba procena po materijalu, bez pretrage i bez poteza.',
    );

    final evalStr = evalScore > 0
        ? '+${evalScore.toStringAsFixed(2)}'
        : evalScore.toStringAsFixed(2);
    if (onEvaluationChanged != null) {
      onEvaluationChanged!(evalStr, '-', '', 1, 0, true, fen);
    }
    final line = AnalysisLine.fromPv(
        multipv: 1, depth: 0, eval: evalStr, pvString: '', startingFen: fen);
    if (onMultiPVUpdated != null) onMultiPVUpdated!({1: line});
  }

  /// Synchronously awaits MultiPV analysis for a position up to target depth
  /// or timeout — used by callers that need one accurate, isolated answer
  /// for exactly [fen] (whole-game review, puzzle extraction, auto-tree
  /// generation), as opposed to the live/streaming eval bar.
  ///
  /// Two defenses against cross-talk with whatever else is using this shared
  /// singleton engine at the same time (e.g. a screen's live eval bar still
  /// attached behind a modal dialog that's running this):
  ///
  /// 1. Goes straight to [_runAnalyzePosition] instead of the public
  ///    [analyzePosition], which debounces via a single shared `Timer` — a
  ///    concurrent unrelated call to [analyzePosition] within that debounce
  ///    window cancels *this* call's pending timer too (it's the same
  ///    field), silently orphaning it. This method's call pattern is always
  ///    one deliberate, already-awaited-by-its-caller request, so it never
  ///    needed debouncing in the first place.
  /// 2. Verifies every callback invocation actually reports on [fen] before
  ///    accepting it. `onEvaluationChanged`/`onMultiPVUpdated` are shared
  ///    singleton fields; while this method has them hijacked, only a
  ///    genuine answer for [fen] should be able to resolve it — otherwise a
  ///    stray result meant for whatever the live screen is showing gets
  ///    silently accepted as this position's eval (this was observed to
  ///    falsely tag a game's opening move as a blunder).
  Future<List<AnalysisLine>> analyzePositionSync(
    String fen, {
    required int depth,
    required int multiPV,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final completer = Completer<List<AnalysisLine>>();
    final Map<int, AnalysisLine> capturedLines = {};

    final prevEvalCallback = onEvaluationChanged;
    final prevMultiPVCallback = onMultiPVUpdated;

    Timer? timer;

    void finish(List<AnalysisLine> lines) {
      if (!completer.isCompleted) {
        timer?.cancel();
        onEvaluationChanged = prevEvalCallback;
        onMultiPVUpdated = prevMultiPVCallback;
        completer.complete(lines);
      }
    }

    timer = Timer(timeout, () {
      AppLogger.log(
          '[StockfishSync] ⏰ Timeout reached for depth $depth. Returning captured lines (${capturedLines.length}).');
      finish(capturedLines.values.toList());
    });

    onMultiPVUpdated = (linesMap) {
      final forThisFen = linesMap.values
          .every((line) => line.startingFen.isEmpty || line.startingFen == fen);
      if (!forThisFen) return;
      capturedLines.addAll(linesMap);
      bool allReachedDepth = linesMap.length >= multiPV &&
          linesMap.values.every((line) => line.depth >= depth);
      if (allReachedDepth) {
        finish(linesMap.values.toList());
      }
    };

    onEvaluationChanged = (eval, bestMove, continuation, multipv, currentDepth,
        isFinal, analyzedFen) {
      if (analyzedFen != fen) return;
      if (isFinal) {
        finish(capturedLines.values.toList());
      }
    };

    setMultiPV(multiPV);
    await _runAnalyzePosition(fen, depth: depth);

    return completer.future;
  }

  /// Fully shuts down the engine process. Call only when app exits.
  void shutdown() {
    AppLogger.log('[StockfishService] 🔌 shutdown() — killing engine process.');
    _isActive = false;
    _isCustomActive = false;

    if (_nativeReady) {
      _sendCommandForce('stop');
      _sendCommandForce('quit');
    }
    _nativeReady = false;

    _subscription?.cancel();
    _subscription = null;
    try {
      _stockfish?.dispose();
    } catch (_) {}
    _stockfish = null;

    _customSubscription?.cancel();
    _customProcess?.kill();
    _customProcess = null;

    onEvaluationChanged = null;
    onMultiPVUpdated = null;
  }

  /// Screen-level dispose: stops current analysis but keeps engine alive.
  ///
  /// Deliberately does NOT clear callbacks. This is a singleton, so clearing them
  /// here would silence whichever screen is still listening. Screens should call
  /// [detach] when they pop and [stopAnalysis] when they merely switch the engine
  /// off; this remains only so a stray call degrades to a harmless stop.
  void dispose() {
    AppLogger.log(
        '[StockfishService] 🧹 dispose() — stopping analysis, keeping engine and subscribers alive.');
    stopAnalysis();
  }

  /// Stops ongoing search without quitting engine
  void stopAnalysis() {
    _requestId++;
    _currentFen = '';
    _engineLines.clear();
    AppLogger.log('[StockfishService] 🛑 stopAnalysis (requestId=$_requestId)');
    if (_nativeReady) {
      _sendCommandForce('stop');
    }
  }

  /// Sets MultiPV option on engine
  void setMultiPV(int count) {
    if (_currentMultiPV == count) return;
    _currentMultiPV = count;
    if (_nativeReady) {
      _sendCommandForce('stop');
      _sendCommandForce('setoption name MultiPV value $count');
    }
  }

  /// Sends a command directly to the engine stdin, bypassing state checks.
  void _sendCommandForce(String command) {
    AppLogger.log('[Stockfish STDIN] ➡️ $command');
    if (_customProcess != null) {
      try {
        _customProcess!.stdin.writeln(command);
      } catch (e) {
        AppLogger.log(
            '[Stockfish STDIN ERROR] ❌ Custom process write failed: $e');
      }
    } else if (_stockfish != null) {
      try {
        _stockfish!.stdin = command;
      } catch (e) {
        AppLogger.log('[Stockfish STDIN ERROR] ❌ Stockfish write failed: $e');
      }
    } else {
      AppLogger.log('[Stockfish STDIN WARNING] ⚠️ No engine for "$command"');
    }
  }

  /// Parses textual lines returned by Stockfish stdout
  void _parseStockfishLine(String line) {
    // "currmove" progress lines carry no score/pv — dozens fire per depth
    // iteration and would otherwise dominate the (size-capped) log buffer,
    // pushing out the diagnostic lines actually needed to debug anything.
    final bool isCurrmoveNoise =
        line.contains('currmove') && !line.contains(' pv ');
    if (!isCurrmoveNoise) {
      AppLogger.log('[Stockfish STDOUT] ⬅️ $line');
    }

    if (line.trim() == 'readyok') {
      _readyOkCompleter?.complete();
      _readyOkCompleter = null;
      return;
    }

    if (line.startsWith('bestmove')) {
      _searchInFlight = false;
      if (_awaitingStopDrain) {
        // The forced end of the search we just told the engine to stop.
        // UCI guarantees this is the last line that search will ever
        // produce, so _stopAndDrain can stop waiting once it sees this.
        _bestMoveCompleter?.complete();
        _bestMoveCompleter = null;
        return;
      }
      final parts = line.split(' ');
      final bestMove = parts.length > 1 ? parts[1] : '';
      if (onEvaluationChanged != null) {
        onEvaluationChanged!('', bestMove, '', 1, 0, true, _currentFen);
      }
      return;
    }

    if (_awaitingStopDrain) {
      // Trailing "info" output from the search we just told the engine to
      // stop — the new position hasn't been sent yet, so this can only be
      // stale. See _stopAndDrain for why letting it through corrupts the
      // next query.
      return;
    }

    if (line.startsWith('info') && line.contains('score')) {
      String eval = '0.00';

      bool isBlackToMove = false;
      if (_currentFen.isNotEmpty) {
        final parts = _currentFen.split(' ');
        if (parts.length > 1 && parts[1] == 'b') {
          isBlackToMove = true;
        }
      }

      if (line.contains('score mate')) {
        final match = RegExp(r'score mate (-?\d+)').firstMatch(line);
        if (match != null) {
          int mateIn = int.parse(match.group(1)!);
          if (isBlackToMove) mateIn = -mateIn;
          eval = mateIn > 0 ? 'M$mateIn' : '-M${mateIn.abs()}';
        }
      } else if (line.contains('score cp')) {
        final match = RegExp(r'score cp (-?\d+)').firstMatch(line);
        if (match != null) {
          int cp = int.parse(match.group(1)!);
          if (isBlackToMove) cp = -cp;
          final scoreValue = cp / 100.0;
          eval = scoreValue > 0
              ? '+${scoreValue.toStringAsFixed(2)}'
              : scoreValue.toStringAsFixed(2);
        }
      }

      String continuation = '';
      if (line.contains(' pv ')) {
        continuation = line.substring(line.indexOf(' pv ') + 4).trim();
      }

      int multipv = 1;
      if (line.contains(' multipv ')) {
        final m = RegExp(r'multipv\s+(\d+)').firstMatch(line);
        if (m != null) multipv = int.parse(m.group(1)!);
      }

      int currentDepth = 1;
      if (line.contains(' depth ')) {
        final m = RegExp(r'depth\s+(\d+)').firstMatch(line);
        if (m != null) currentDepth = int.parse(m.group(1)!);
      }

      String bestMove = '';
      if (continuation.isNotEmpty) {
        bestMove = continuation.split(' ').first;
      }

      if (onEvaluationChanged != null) {
        onEvaluationChanged!(eval, bestMove, continuation, multipv,
            currentDepth, false, _currentFen);
      }

      _engineLines[multipv] = AnalysisLine.fromPv(
        multipv: multipv,
        depth: currentDepth,
        eval: eval,
        pvString: continuation.isNotEmpty ? continuation : bestMove,
        startingFen: _currentFen,
      );
      if (onMultiPVUpdated != null) {
        onMultiPVUpdated!(_engineLines);
      }
    }
  }
}

/// One screen's registration with the shared engine.
class _EngineSubscriber {
  final Object owner;
  final Function(String evaluation, String bestMove, String continuation,
      int multipv, int depth, bool isFinal, String analyzedFen)? onEvaluation;
  final Function(Map<int, AnalysisLine> lines)? onMultiPV;
  final String Function()? getFen;
  final bool Function()? isEnabled;

  _EngineSubscriber(
    this.owner,
    this.onEvaluation,
    this.onMultiPV, {
    this.getFen,
    this.isEnabled,
  });
}
