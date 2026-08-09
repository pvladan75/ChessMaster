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
    
    // Check if custom engine path is set
    try {
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('custom_engine_path');
      
      if (customPath != null && customPath.isNotEmpty && Platform.isWindows) {
        if (_customProcess != null) return;
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
        return;
      }
    } catch (e) {
      print("Failed to start custom engine: $e");
      _isCustomActive = false;
      _customProcess = null;
    }

    _isCustomActive = false;
    if (_useOnline) {
      return;
    }

    if (_stockfish != null) return;
    
    _stockfish = Stockfish();
    
    // Listen to output messages from Stockfish stdout
    _subscription = _stockfish!.stdout.listen((line) {
      _parseStockfishLine(line);
    });

    void sendInitCommands() {
      _sendCommand('uci');
      _sendCommand('setoption name MultiPV value 3');
      _sendCommand('isready');
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
  Future<void> analyzePosition(String fen, {int depth = 10, bool isInfinite = false}) async {
    _currentFen = fen;
    _engineLines.clear();
    if (!_isActive) return;

    print('[STOCKFISH_ENGINE_LOG] 🎯 Pokrenuta analiza | Dubina: $depth | Mode: ${_useOnline ? "Online API Fallback" : "Nativni Lokalni Engine"} | FEN: $fen');

    if (_useOnline) {
      final reqId = ++_requestId;
      final effectiveDepth = depth > 15 ? 15 : depth;

      // Try Lichess Cloud Eval API first for instant Grandmaster depth 25-50 analysis
      try {
        final cloudUrl = 'https://lichess.org/api/cloud-eval?fen=${Uri.encodeComponent(fen)}';
        final cloudRes = await http.get(Uri.parse(cloudUrl));
        if (reqId == _requestId && cloudRes.statusCode == 200) {
          final cloudData = jsonDecode(cloudRes.body);
          if (cloudData['pvs'] != null && (cloudData['pvs'] as List).isNotEmpty) {
            final pv = cloudData['pvs'][0];
            final movesStr = (pv['moves'] as String? ?? '').trim();
            final depthVal = (cloudData['depth'] as int?) ?? 20;

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

              final line = AnalysisLine.fromPv(
                multipv: 1,
                depth: depthVal,
                eval: eval,
                pvString: movesStr,
                startingFen: fen,
              );

              if (onEvaluationChanged != null) {
                onEvaluationChanged!(eval, bestMove, movesStr, 1, depthVal, true, fen);
              }
              if (onMultiPVUpdated != null) {
                onMultiPVUpdated!({1: line});
              }
              return;
            }
          }
        }
      } catch (_) {}

      // Fallback to stockfish.online API v2 (max depth 15)
      try {
        final url = 'https://stockfish.online/api/s/v2.php?fen=${Uri.encodeComponent(fen)}&depth=$effectiveDepth';
        final response = await http.get(Uri.parse(url));

        if (reqId != _requestId) return; // Ignore outdated responses

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            bool isBlackToMove = fen.contains(' b ');

            String eval = '0.00';
            if (data['mate'] != null) {
              int mate = data['mate'] as int;
              if (isBlackToMove) {
                mate = -mate;
              }
              eval = mate > 0 ? 'M$mate' : '-M${mate.abs()}';
            } else if (data['evaluation'] != null) {
              double score = (data['evaluation'] as num).toDouble();
              if (isBlackToMove) {
                score = -score;
              }
              eval = score > 0 ? '+${score.toStringAsFixed(2)}' : score.toStringAsFixed(2);
            }

            String bestMove = '-';
            if (data['bestmove'] != null) {
              final bestStr = data['bestmove'] as String;
              final match = RegExp(r'bestmove\s+(\S+)').firstMatch(bestStr);
              if (match != null) {
                bestMove = match.group(1)!;
              }
            }

            String continuation = '';
            if (data['continuation'] != null) {
              continuation = data['continuation'] as String;
            }

            final line = AnalysisLine.fromPv(
              multipv: 1,
              depth: effectiveDepth,
              eval: eval,
              pvString: continuation.isNotEmpty ? continuation : bestMove,
              startingFen: fen,
            );

            if (onEvaluationChanged != null) {
              onEvaluationChanged!(eval, bestMove, continuation, 1, effectiveDepth, true, fen);
            }
            if (onMultiPVUpdated != null) {
              onMultiPVUpdated!({1: line});
            }
          }
        }
      } catch (_) {}
    } else {
      if (_stockfish == null && _customProcess == null) return;
      _sendCommand('stop');
      _sendCommand('position fen $fen');
      if (depth >= 99) {
        print('[STOCKFISH_NATIVE_LOG] 🚀 Pokrenuta neograničena analiza (go infinite)...');
        _sendCommand('go infinite');
      } else {
        print('[STOCKFISH_NATIVE_LOG] 🎯 Pokrenuta analiza na dubini (go depth $depth)...');
        _sendCommand('go depth $depth');
      }
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
    _sendCommand('stop');
  }

  /// Sets MultiPV option on engine
  void setMultiPV(int count) {
    _sendCommand('setoption name MultiPV value $count');
  }

  /// Internal helper to send a command to Stockfish stdin
  void _sendCommand(String command) {
    if (_customProcess != null) {
      _customProcess!.stdin.writeln(command);
    } else if (_stockfish != null && _stockfish!.state.value == StockfishState.ready) {
      _stockfish!.stdin = command;
    }
  }

  /// Parses textual lines returned by Stockfish stdout
  void _parseStockfishLine(String line) {
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
        if (onEvaluationChanged != null) {
          onEvaluationChanged!('', bestMove, '', 1, 18, true, _currentFen);
        }
      }
    }
  }
}
