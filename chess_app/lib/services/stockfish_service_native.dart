import 'package:chess_app/services/app_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stockfish/stockfish.dart';

import 'package:chess_app/models/analysis_models.dart';

class StockfishService {
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

  // We fall back to online API on Windows and Linux if no custom engine is run
  bool get _useOnline {
    if (Platform.isWindows && _isCustomActive) return false;
    return Platform.isWindows || Platform.isLinux;
  }

  bool get isActive => _useOnline ? _isActive : (_stockfish != null || _customProcess != null);
  bool get isSupported => true;
  bool get isOnline => _useOnline;

  /// Starts the Stockfish engine (or sets up online mode)
  Future<void> initEngine() async {
    if (_initInProgress) {
      AppLogger.log('[StockfishService] ⏳ initEngine already in progress, skipping duplicate call.');
      return;
    }
    _initInProgress = true;
    _isActive = true;
    AppLogger.log('[StockfishService] 🛠️ initEngine called | CustomActive: $_isCustomActive | UseOnline: $_useOnline');
    
    // Check if custom engine path is set (Windows only)
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('custom_engine_path');
      
      if (customPath != null && customPath.isNotEmpty && Platform.isWindows) {
        if (_customProcess != null) {
          _initInProgress = false;
          return;
        }
        AppLogger.log('[StockfishService] 🚀 Starting custom engine executable at: $customPath');
        _customProcess = await Process.start(customPath, []);
        _isCustomActive = true;
        _nativeReady = true; // Custom process is ready immediately after start
        
        _customSubscription = _customProcess!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          _parseStockfishLine(line);
        });

        // For custom process, we can send directly — no state gating
        _sendCommandForce('uci');
        _sendCommandForce('setoption name MultiPV value 3');
        _sendCommandForce('isready');

        _drainPendingQueue();
        _initInProgress = false;
        return;
      }
    } catch (e) {
      AppLogger.log('[StockfishService ERROR] ❌ Failed to start custom engine: $e');
      _isCustomActive = false;
      _customProcess = null;
    }

    _isCustomActive = false;
    if (_useOnline) {
      AppLogger.log('[StockfishService] 🌐 Using Online Stockfish Cloud API Fallback (Windows/Linux)');
      _nativeReady = true; // Online mode is always "ready"
      _initInProgress = false;
      return;
    }

    // Native Stockfish (Android/iOS)
    if (_stockfish != null && _nativeReady) {
      AppLogger.log('[StockfishService] ♻️ Stockfish already initialized and ready.');
      _initInProgress = false;
      return;
    }

    // Kill old broken instance if it exists but never became ready
    if (_stockfish != null && !_nativeReady) {
      AppLogger.log('[StockfishService] 🔄 Disposing stale Stockfish instance that never became ready...');
      _subscription?.cancel();
      _subscription = null;
      try { _stockfish?.dispose(); } catch (_) {}
      _stockfish = null;
    }

    AppLogger.log('[StockfishService] ⚙️ Creating new Native Stockfish instance...');
    _stockfish = Stockfish();
    
    // Listen to output messages from Stockfish stdout
    _subscription = _stockfish!.stdout.listen((line) {
      _parseStockfishLine(line);
    });

    // Wait for the Stockfish FFI process to become ready with a timeout
    final ready = await _waitForReady(timeout: const Duration(seconds: 5));
    
    if (ready) {
      AppLogger.log('[StockfishService] ✅ Native Stockfish is READY! Sending UCI init commands...');
      _nativeReady = true;
      // These MUST use _sendCommandForce since the stockfish package's
      // stdin setter writes directly to the process without state checks
      _sendCommandForce('uci');
      _sendCommandForce('setoption name MultiPV value 3');
      _sendCommandForce('isready');
      _drainPendingQueue();
    } else {
      AppLogger.log('[StockfishService ERROR] ❌ Stockfish did not become ready within timeout! State: ${_stockfish?.state.value}');
      // Try one more time with a fresh instance
      _subscription?.cancel();
      try { _stockfish?.dispose(); } catch (_) {}
      _stockfish = null;
      
      AppLogger.log('[StockfishService] 🔄 Retrying with a fresh Stockfish instance...');
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
        AppLogger.log('[StockfishService ERROR] ❌ Stockfish failed to initialize after retry. Falling back to material eval.');
        // If there's a pending FEN, give it a material-only fallback
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
        AppLogger.log('[StockfishService] ⏰ Timeout waiting for Stockfish ready state.');
        completer.complete(false);
      }
    });

    final result = await completer.future;
    _stockfish?.state.removeListener(listener);
    return result;
  }

  /// Drains the pending FEN queue: if there's a queued position, analyze it now.
  void _drainPendingQueue() {
    if (_pendingFen != null) {
      final fen = _pendingFen!;
      final depth = _pendingDepth ?? 18;
      _pendingFen = null;
      _pendingDepth = null;
      AppLogger.log('[StockfishService] 🎯 Draining pending queue → analyzing FEN: $fen');
      analyzePosition(fen, depth: depth);
    }
  }

  /// Sends a FEN position for analysis
  Future<void> analyzePosition(String fen, {int depth = 18, bool isInfinite = false}) async {
    _currentFen = fen;
    _engineLines.clear();
    _isActive = true;

    AppLogger.log('[STOCKFISH_ENGINE_LOG] 🎯 Pokrenuta analiza | Dubina: $depth | Mode: ${_useOnline ? "Online API Fallback" : "Nativni Lokalni Engine"} | FEN: $fen');

    if (_useOnline) {
      final reqId = ++_requestId;
      final effectiveDepth = depth.clamp(5, 50);

      // Try Lichess Cloud Eval API first
      try {
        final cloudUrl = 'https://lichess.org/api/cloud-eval?fen=${Uri.encodeComponent(fen)}';
        AppLogger.log('[Stockfish API] 🔍 Querying Lichess Cloud: $cloudUrl');
        final cloudRes = await http.get(Uri.parse(cloudUrl)).timeout(const Duration(seconds: 4));
        AppLogger.log('[Stockfish API] 📩 Lichess Cloud response status: ${cloudRes.statusCode}');

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

              AppLogger.log('[Stockfish API] ✅ Lichess Cloud Eval: eval=$eval, bestMove=$bestMove, depth=$depthVal');

              for (int d = 1; d <= depthVal; d += 2) {
                if (reqId != _requestId) return;
                if (onEvaluationChanged != null) {
                  onEvaluationChanged!(eval, bestMove, movesStr, 1, d, d >= depthVal, fen);
                }
                final line = AnalysisLine.fromPv(
                  multipv: 1,
                  depth: d,
                  eval: eval,
                  pvString: movesStr,
                  startingFen: fen,
                );
                if (onMultiPVUpdated != null) {
                  onMultiPVUpdated!({1: line});
                }
                await Future.delayed(const Duration(milliseconds: 25));
              }

              if (onEvaluationChanged != null) {
                onEvaluationChanged!(eval, bestMove, movesStr, 1, depthVal, true, fen);
              }
              return;
            }
          }
        }
      } catch (e) {
        AppLogger.log('[Stockfish API WARNING] ⚠️ Lichess Cloud failed: $e');
      }

      // Fallback to stockfish.online API v2
      try {
        final onlineDepth = effectiveDepth > 20 ? 20 : effectiveDepth;
        final url = 'https://stockfish.online/api/s/v2.php?fen=${Uri.encodeComponent(fen)}&depth=$onlineDepth';
        AppLogger.log('[Stockfish API] 🔍 Querying Stockfish Online: $url');
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        AppLogger.log('[Stockfish API] 📩 Stockfish Online response: ${response.statusCode}');

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
            AppLogger.log('[Stockfish API] ✅ Stockfish Online Eval: eval=$eval, bestMove=$bestMove');

            for (int d = 1; d <= onlineDepth; d += 2) {
              if (reqId != _requestId) return;
              if (onEvaluationChanged != null) {
                onEvaluationChanged!(eval, bestMove, continuation, 1, d, d >= onlineDepth, fen);
              }
              final line = AnalysisLine.fromPv(
                multipv: 1,
                depth: d,
                eval: eval,
                pvString: continuation.isNotEmpty ? continuation : bestMove,
                startingFen: fen,
              );
              if (onMultiPVUpdated != null) {
                onMultiPVUpdated!({1: line});
              }
              await Future.delayed(const Duration(milliseconds: 25));
            }

            if (onEvaluationChanged != null) {
              onEvaluationChanged!(eval, bestMove, continuation, 1, onlineDepth, true, fen);
            }
            return;
          }
        }
      } catch (e) {
        AppLogger.log('[Stockfish API ERROR] ❌ Stockfish Online error: $e');
      }

      // Final fallback: basic material evaluation
      _fallbackBasicEvaluation(fen, effectiveDepth);

    } else {
      // ── Native engine path ──
      if (!_nativeReady) {
        AppLogger.log('[StockfishService] ⏳ Engine not ready yet. Queuing FEN and triggering initEngine...');
        _pendingFen = fen;
        _pendingDepth = depth;
        // Kick off initEngine if not already running — it will drain the queue when ready
        if (!_initInProgress) {
          initEngine();
        }
        return;
      }

      _sendCommandForce('stop');
      _sendCommandForce('ucinewgame');
      _sendCommandForce('position fen $fen');
      final effectiveDepth = depth.clamp(5, 50);
      AppLogger.log('[STOCKFISH_NATIVE_LOG] 🎯 go depth $effectiveDepth for FEN: $fen');
      _sendCommandForce('go depth $effectiveDepth');
    }
  }

  void _fallbackBasicEvaluation(String fen, int depth) {
    AppLogger.log('[StockfishService] 💡 Fallback material evaluation for FEN...');
    double evalScore = 0.0;
    try {
      final fenBoard = fen.split(' ')[0];
      final isBlackToMove = fen.contains(' b ');

      int whiteVal = 0;
      int blackVal = 0;
      for (int i = 0; i < fenBoard.length; i++) {
        final char = fenBoard[i];
        if (char == 'P') whiteVal += 1;
        if (char == 'N' || char == 'B') whiteVal += 3;
        if (char == 'R') whiteVal += 5;
        if (char == 'Q') whiteVal += 9;
        if (char == 'p') blackVal += 1;
        if (char == 'n' || char == 'b') blackVal += 3;
        if (char == 'r') blackVal += 5;
        if (char == 'q') blackVal += 9;
      }

      int diff = whiteVal - blackVal;
      if (isBlackToMove) diff = -diff;
      evalScore = diff.toDouble();
    } catch (_) {}

    final evalStr = evalScore > 0 ? '+${evalScore.toStringAsFixed(2)}' : evalScore.toStringAsFixed(2);
    if (onEvaluationChanged != null) {
      onEvaluationChanged!(evalStr, '-', '', 1, depth, true, fen);
    }
    final line = AnalysisLine.fromPv(
      multipv: 1,
      depth: depth,
      eval: evalStr,
      pvString: '',
      startingFen: fen,
    );
    if (onMultiPVUpdated != null) {
      onMultiPVUpdated!({1: line});
    }
  }

  /// Stops analysis and quits the engine process
  void dispose() {
    _isActive = false;
    _isCustomActive = false;
    _nativeReady = false;

    if (_nativeReady || _customProcess != null) {
      _sendCommandForce('stop');
      _sendCommandForce('quit');
    }

    _subscription?.cancel();
    _subscription = null;
    try { _stockfish?.dispose(); } catch (_) {}
    _stockfish = null;

    _customSubscription?.cancel();
    _customProcess?.kill();
    _customProcess = null;
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

  /// Sends a command to the engine, FORCING it through even if state isn't "ready" yet.
  /// This is required for UCI init handshake commands (uci, isready) that must be sent
  /// before the engine transitions to ready state.
  void _sendCommandForce(String command) {
    AppLogger.log('[Stockfish STDIN] ➡️ $command');
    if (_customProcess != null) {
      try {
        _customProcess!.stdin.writeln(command);
      } catch (e) {
        AppLogger.log('[Stockfish STDIN ERROR] ❌ Failed to write to custom process: $e');
      }
    } else if (_stockfish != null) {
      try {
        _stockfish!.stdin = command;
      } catch (e) {
        AppLogger.log('[Stockfish STDIN ERROR] ❌ Failed to write to stockfish: $e');
      }
    } else {
      AppLogger.log('[Stockfish STDIN WARNING] ⚠️ No engine instance available for "$command"');
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

      // Mate in N moves
      if (line.contains('score mate')) {
        final regExp = RegExp(r'score mate (-?\d+)');
        final match = regExp.firstMatch(line);
        if (match != null) {
          int mateIn = int.parse(match.group(1)!);
          if (isBlackToMove) {
            mateIn = -mateIn;
          }
          eval = mateIn > 0 ? 'M$mateIn' : '-M${mateIn.abs()}';
        }
      } 
      // Centipawns score (cp)
      else if (line.contains('score cp')) {
        final regExp = RegExp(r'score cp (-?\d+)');
        final match = regExp.firstMatch(line);
        if (match != null) {
          int cp = int.parse(match.group(1)!);
          if (isBlackToMove) {
            cp = -cp;
          }
          final scoreValue = cp / 100.0;
          eval = scoreValue > 0 ? '+${scoreValue.toStringAsFixed(2)}' : scoreValue.toStringAsFixed(2);
        }
      }

      String continuation = '';
      if (line.contains(' pv ')) {
        final pvIndex = line.indexOf(' pv ');
        continuation = line.substring(pvIndex + 4).trim();
      }

      int multipv = 1;
      if (line.contains(' multipv ')) {
        final mvMatch = RegExp(r'multipv\s+(\d+)').firstMatch(line);
        if (mvMatch != null) {
          multipv = int.parse(mvMatch.group(1)!);
        }
      }

      int currentDepth = 1;
      if (line.contains(' depth ')) {
        final dMatch = RegExp(r'depth\s+(\d+)').firstMatch(line);
        if (dMatch != null) {
          currentDepth = int.parse(dMatch.group(1)!);
        }
      }

      String bestMove = '';
      if (continuation.isNotEmpty) {
        final tokens = continuation.split(' ');
        if (tokens.isNotEmpty) {
          bestMove = tokens[0];
        }
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

    // Best move found output
    if (line.startsWith('bestmove')) {
      // Engine finished its search iteration
    }
  }
}
