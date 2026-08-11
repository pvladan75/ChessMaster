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
  
  Function(String evaluation, String bestMove, String continuation, int multipv, int depth, bool isFinal, String analyzedFen)? onEvaluationChanged;
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

  bool get isCustomEngineActive => _isCustomActive;

  bool get _useOnline {
    if (Platform.isWindows && _isCustomActive) return false;
    return Platform.isWindows || Platform.isLinux;
  }

  bool get isActive => _useOnline ? _isActive : (_stockfish != null || _customProcess != null);
  bool get isSupported => true;
  bool get isOnline => _useOnline;

  /// Starts the Stockfish engine (or sets up online mode).
  /// Safe to call multiple times — if engine is already ready, returns immediately.
  Future<void> initEngine() async {
    _isActive = true;

    // If engine is already initialized and ready, nothing to do
    if (_nativeReady && (_stockfish != null || _customProcess != null || _useOnline)) {
      AppLogger.log('[StockfishService] ♻️ Engine already initialized and ready (singleton). Draining any pending queue...');
      _drainPendingQueue();
      return;
    }

    if (_initInProgress) {
      AppLogger.log('[StockfishService] ⏳ initEngine already in progress, skipping duplicate call.');
      return;
    }
    _initInProgress = true;
    AppLogger.log('[StockfishService] 🛠️ initEngine called | CustomActive: $_isCustomActive | UseOnline: $_useOnline');
    
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
        AppLogger.log('[StockfishService] 🚀 Starting custom engine at: $customPath');
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
      AppLogger.log('[StockfishService] 🌐 Using Online Stockfish Cloud API Fallback');
      _nativeReady = true;
      _initInProgress = false;
      _drainPendingQueue();
      return;
    }

    // ── Native Stockfish (Android/iOS) ──
    // Reuse existing instance if it's still alive and ready
    if (_stockfish != null && _nativeReady) {
      AppLogger.log('[StockfishService] ♻️ Reusing existing native Stockfish instance.');
      _initInProgress = false;
      _drainPendingQueue();
      return;
    }

    // Kill old broken instance if it exists but never became ready
    if (_stockfish != null && !_nativeReady) {
      AppLogger.log('[StockfishService] 🔄 Disposing stale Stockfish instance...');
      _subscription?.cancel();
      _subscription = null;
      try { _stockfish?.dispose(); } catch (_) {}
      _stockfish = null;
      // Small delay to let the FFI process fully terminate
      await Future.delayed(const Duration(milliseconds: 300));
    }

    AppLogger.log('[StockfishService] ⚙️ Creating new Native Stockfish instance...');
    _stockfish = Stockfish();
    
    _subscription = _stockfish!.stdout.listen((line) {
      _parseStockfishLine(line);
    });

    // Wait for the Stockfish FFI process to become ready
    final ready = await _waitForReady(timeout: const Duration(seconds: 5));
    
    if (ready) {
      AppLogger.log('[StockfishService] ✅ Native Stockfish is READY! Sending UCI init commands...');
      _nativeReady = true;
      _sendCommandForce('uci');
      _sendCommandForce('setoption name MultiPV value 3');
      _sendCommandForce('isready');
      _drainPendingQueue();
    } else {
      AppLogger.log('[StockfishService ERROR] ❌ Stockfish not ready within 5s. Retrying...');
      _subscription?.cancel();
      try { _stockfish?.dispose(); } catch (_) {}
      _stockfish = null;
      await Future.delayed(const Duration(milliseconds: 300));
      
      _stockfish = Stockfish();
      _subscription = _stockfish!.stdout.listen((line) {
        _parseStockfishLine(line);
      });
      
      final retryReady = await _waitForReady(timeout: const Duration(seconds: 8));
      if (retryReady) {
        AppLogger.log('[StockfishService] ✅ Stockfish READY on retry!');
        _nativeReady = true;
        _sendCommandForce('uci');
        _sendCommandForce('setoption name MultiPV value 3');
        _sendCommandForce('isready');
        _drainPendingQueue();
      } else {
        AppLogger.log('[StockfishService ERROR] ❌ Stockfish failed after retry. Using material fallback.');
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
      AppLogger.log('[StockfishService] 🎯 Draining queue → analyzing FEN: $fen');
      analyzePosition(fen, depth: depth);
    }
  }

  /// Clears callbacks (call when a screen disposes to avoid stale references)
  void clearCallbacks() {
    onEvaluationChanged = null;
    onMultiPVUpdated = null;
  }

  /// Sends a FEN position for analysis
  Future<void> analyzePosition(String fen, {int depth = 18, bool isInfinite = false}) async {
    _currentFen = fen;
    _engineLines.clear();
    _isActive = true;

    AppLogger.log('[STOCKFISH_ENGINE_LOG] 🎯 Analiza | Dubina: $depth | Mode: ${_useOnline ? "Online API" : "Nativni Engine"} | FEN: $fen');

    if (_useOnline) {
      final reqId = ++_requestId;
      final effectiveDepth = depth.clamp(5, 50);

      // Try Lichess Cloud Eval API first
      try {
        final cloudUrl = 'https://lichess.org/api/cloud-eval?fen=${Uri.encodeComponent(fen)}';
        final cloudRes = await http.get(Uri.parse(cloudUrl)).timeout(const Duration(seconds: 4));

        if (reqId == _requestId && cloudRes.statusCode == 200) {
          final cloudData = jsonDecode(cloudRes.body);
          if (cloudData['pvs'] != null && (cloudData['pvs'] as List).isNotEmpty) {
            final pv = cloudData['pvs'][0];
            final movesStr = (pv['moves'] as String? ?? '').trim();
            final depthVal = ((cloudData['depth'] as int?) ?? effectiveDepth).clamp(5, 50);

            if (movesStr.isNotEmpty) {
              final movesList = movesStr.split(RegExp(r'\s+'));
              final bestMove = movesList.first;
              bool isBlackToMove = fen.contains(' b ');

              String eval = '0.00';
              if (pv['cp'] != null) {
                double score = (pv['cp'] as num) / 100.0;
                if (isBlackToMove) score = -score;
                eval = score > 0 ? '+${score.toStringAsFixed(2)}' : score.toStringAsFixed(2);
              } else if (pv['mate'] != null) {
                int mate = pv['mate'] as int;
                if (isBlackToMove) mate = -mate;
                eval = mate > 0 ? 'M$mate' : '-M${mate.abs()}';
              }

              for (int d = 1; d <= depthVal; d += 2) {
                if (reqId != _requestId) return;
                if (onEvaluationChanged != null) {
                  onEvaluationChanged!(eval, bestMove, movesStr, 1, d, d >= depthVal, fen);
                }
                final line = AnalysisLine.fromPv(multipv: 1, depth: d, eval: eval, pvString: movesStr, startingFen: fen);
                if (onMultiPVUpdated != null) onMultiPVUpdated!({1: line});
                await Future.delayed(const Duration(milliseconds: 25));
              }
              if (onEvaluationChanged != null) {
                onEvaluationChanged!(eval, bestMove, movesStr, 1, depthVal, true, fen);
              }
              return;
            }
          }
        }
      } catch (_) {}

      // Fallback to stockfish.online API v2
      try {
        final onlineDepth = effectiveDepth > 20 ? 20 : effectiveDepth;
        final url = 'https://stockfish.online/api/s/v2.php?fen=${Uri.encodeComponent(fen)}&depth=$onlineDepth';
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

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
              eval = score > 0 ? '+${score.toStringAsFixed(2)}' : score.toStringAsFixed(2);
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
                onEvaluationChanged!(eval, bestMove, continuation, 1, d, d >= onlineDepth, fen);
              }
              final line = AnalysisLine.fromPv(multipv: 1, depth: d, eval: eval, pvString: continuation.isNotEmpty ? continuation : bestMove, startingFen: fen);
              if (onMultiPVUpdated != null) onMultiPVUpdated!({1: line});
              await Future.delayed(const Duration(milliseconds: 25));
            }
            if (onEvaluationChanged != null) {
              onEvaluationChanged!(eval, bestMove, continuation, 1, onlineDepth, true, fen);
            }
            return;
          }
        }
      } catch (_) {}

      _fallbackBasicEvaluation(fen, effectiveDepth);

    } else {
      // ── Native engine path ──
      if (!_nativeReady) {
        AppLogger.log('[StockfishService] ⏳ Engine not ready. Queuing FEN and triggering initEngine...');
        _pendingFen = fen;
        _pendingDepth = depth;
        if (!_initInProgress) {
          initEngine();
        }
        return;
      }

      _sendCommandForce('stop');
      _sendCommandForce('ucinewgame');
      _sendCommandForce('position fen $fen');
      final effectiveDepth = depth.clamp(5, 50);
      AppLogger.log('[STOCKFISH_NATIVE] 🎯 go depth $effectiveDepth');
      _sendCommandForce('go depth $effectiveDepth');
    }
  }

  void _fallbackBasicEvaluation(String fen, int depth) {
    double evalScore = 0.0;
    try {
      final fenBoard = fen.split(' ')[0];
      final isBlackToMove = fen.contains(' b ');
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
      int diff = whiteVal - blackVal;
      if (isBlackToMove) diff = -diff;
      evalScore = diff.toDouble();
    } catch (_) {}

    final evalStr = evalScore > 0 ? '+${evalScore.toStringAsFixed(2)}' : evalScore.toStringAsFixed(2);
    if (onEvaluationChanged != null) {
      onEvaluationChanged!(evalStr, '-', '', 1, depth, true, fen);
    }
    final line = AnalysisLine.fromPv(multipv: 1, depth: depth, eval: evalStr, pvString: '', startingFen: fen);
    if (onMultiPVUpdated != null) onMultiPVUpdated!({1: line});
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
    try { _stockfish?.dispose(); } catch (_) {}
    _stockfish = null;

    _customSubscription?.cancel();
    _customProcess?.kill();
    _customProcess = null;

    onEvaluationChanged = null;
    onMultiPVUpdated = null;
  }

  /// Screen-level dispose: stops current analysis but keeps engine alive.
  void dispose() {
    AppLogger.log('[StockfishService] 🧹 dispose() — stopping analysis, keeping engine alive (singleton).');
    stopAnalysis();
    clearCallbacks();
  }

  /// Stops ongoing search without quitting engine
  void stopAnalysis() {
    _requestId++;
    _currentFen = '';
    _engineLines.clear();
    AppLogger.log('[StockfishService] 🛑 stopAnalysis (requestId=$_requestId)');
    if (_nativeReady) {
      _sendCommandForce('stop');
      _sendCommandForce('ucinewgame');
    }
  }

  /// Sets MultiPV option on engine
  void setMultiPV(int count) {
    if (_nativeReady) {
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
        AppLogger.log('[Stockfish STDIN ERROR] ❌ Custom process write failed: $e');
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
    AppLogger.log('[Stockfish STDOUT] ⬅️ $line');

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
          eval = scoreValue > 0 ? '+${scoreValue.toStringAsFixed(2)}' : scoreValue.toStringAsFixed(2);
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
        onEvaluationChanged!(eval, bestMove, continuation, multipv, currentDepth, false, _currentFen);
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

    if (line.startsWith('bestmove')) {
      // Engine finished search
    }
  }
}
