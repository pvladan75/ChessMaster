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
    _isActive = true;
    AppLogger.log('[StockfishService] 🛠️ initEngine called | CustomActive: $_isCustomActive | UseOnline: $_useOnline');
    
    // Check if custom engine path is set
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('custom_engine_path');
      
      if (customPath != null && customPath.isNotEmpty && Platform.isWindows) {
        if (_customProcess != null) return;
        AppLogger.log('[StockfishService] 🚀 Starting custom engine executable at: $customPath');
        _customProcess = await Process.start(customPath, []);
        _isCustomActive = true;
        
        _customSubscription = _customProcess!.stdout
            .transform(utf8.decoder)
            .transform(const LineSplitter())
            .listen((line) {
          _parseStockfishLine(line);
        });

        _sendCommand('uci');
        _sendCommand('setoption name MultiPV value 3');
        _sendCommand('isready');

        if (_pendingFen != null) {
          final fen = _pendingFen!;
          final depth = _pendingDepth ?? 18;
          _pendingFen = null;
          _pendingDepth = null;
          analyzePosition(fen, depth: depth);
        }
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
      return;
    }

    if (_stockfish != null) return;
    
    AppLogger.log('[StockfishService] ⚙️ Initializing Native Stockfish Engine...');
    _stockfish = Stockfish();
    
    // Listen to output messages from Stockfish stdout
    _subscription = _stockfish!.stdout.listen((line) {
      _parseStockfishLine(line);
    });

    void sendInitCommands() {
      AppLogger.log('[StockfishService] ✅ Native Stockfish is READY!');
      _sendCommand('uci');
      _sendCommand('setoption name MultiPV value 3');
      _sendCommand('isready');

      if (_pendingFen != null) {
        final fen = _pendingFen!;
        final depth = _pendingDepth ?? 18;
        _pendingFen = null;
        _pendingDepth = null;
        AppLogger.log('[StockfishService] 🎯 Executing pending analysis for FEN: $fen');
        analyzePosition(fen, depth: depth);
      }
    }

    if (_stockfish!.state.value == StockfishState.ready) {
      sendInitCommands();
    } else {
      _stockfish!.state.addListener(() {
        if (_stockfish?.state.value == StockfishState.ready) {
          sendInitCommands();
        }
      });
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

      // Try Lichess Cloud Eval API first for instant Grandmaster depth 25-50 analysis
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

              AppLogger.log('[Stockfish API] ✅ Lichess Cloud Eval Success: eval=$eval, bestMove=$bestMove, depth=$depthVal');

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
        AppLogger.log('[Stockfish API WARNING] ⚠️ Lichess Cloud Eval failed/timed out: $e');
      }

      // Fallback to stockfish.online API v2
      try {
        final onlineDepth = effectiveDepth > 20 ? 20 : effectiveDepth;
        final url = 'https://stockfish.online/api/s/v2.php?fen=${Uri.encodeComponent(fen)}&depth=$onlineDepth';
        AppLogger.log('[Stockfish API] 🔍 Querying Stockfish Online API: $url');
        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        AppLogger.log('[Stockfish API] 📩 Stockfish Online response status: ${response.statusCode}');

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
            AppLogger.log('[Stockfish API] ✅ Stockfish Online Eval Success: eval=$eval, bestMove=$bestMove');

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
        AppLogger.log('[Stockfish API ERROR] ❌ Stockfish Online API error: $e');
      }

      // Offline / API Fallback: Generate basic material evaluation so UI never gets stuck
      _fallbackBasicEvaluation(fen, effectiveDepth);
    } else {
      if (_stockfish == null && _customProcess == null) {
        AppLogger.log('[StockfishService WARNING] ⏳ Engine not ready yet. Queuing FEN analysis...');
        _pendingFen = fen;
        _pendingDepth = depth;
        return;
      }

      if (_stockfish != null && _stockfish!.state.value != StockfishState.ready) {
        AppLogger.log('[StockfishService WARNING] ⏳ Stockfish state is ${_stockfish!.state.value}. Queuing FEN analysis...');
        _pendingFen = fen;
        _pendingDepth = depth;
        return;
      }

      _sendCommand('stop');
      _sendCommand('ucinewgame');
      _sendCommand('position fen $fen');
      final effectiveDepth = depth.clamp(5, 50);
      AppLogger.log('[STOCKFISH_NATIVE_LOG] 🎯 Pokrenuta analiza na dubini (go depth $effectiveDepth)...');
      _sendCommand('go depth $effectiveDepth');
    }
  }

  void _fallbackBasicEvaluation(String fen, int depth) {
    AppLogger.log('[StockfishService] 💡 Calculating basic positional fallback evaluation for FEN...');
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

    _sendCommand('stop');
    _sendCommand('quit');

    _subscription?.cancel();
    _stockfish = null;

    _customSubscription?.cancel();
    _customProcess?.kill();
    _customProcess = null;
  }

  /// Stops ongoing search without quitting engine
  void stopAnalysis() {
    _requestId++; // Cancel any pending online API requests
    _currentFen = '';
    _engineLines.clear();
    AppLogger.log('[StockfishService] 🛑 stopAnalysis called (requestId incremented to $_requestId)');
    _sendCommand('stop');
    _sendCommand('ucinewgame');
  }

  /// Sets MultiPV option on engine
  void setMultiPV(int count) {
    _sendCommand('setoption name MultiPV value $count');
  }

  /// Internal helper to send a command to Stockfish stdin
  void _sendCommand(String command) {
    AppLogger.log('[Stockfish STDIN] ➡️ $command');
    if (_customProcess != null) {
      _customProcess!.stdin.writeln(command);
    } else if (_stockfish != null && _stockfish!.state.value == StockfishState.ready) {
      _stockfish!.stdin = command;
    } else {
      AppLogger.log('[Stockfish STDIN WARNING] ⚠️ Could not send "$command" - engine process/instance is not ready.');
    }
  }

  /// Parses textual lines returned by Stockfish stdout
  void _parseStockfishLine(String line) {
    AppLogger.log('[Stockfish STDOUT] ⬅️ $line');

    // Look for evaluation scores and bestmove outputs
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

    // Best move found output (marks end of engine search iteration)
    if (line.startsWith('bestmove')) {
      final parts = line.split(' ');
      if (parts.length > 1) {
        final bestMove = parts[1]; // e.g. "e2e4"
      }
    }
  }
}
