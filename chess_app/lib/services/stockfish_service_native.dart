import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:stockfish/stockfish.dart';

class StockfishService {
  Stockfish? _stockfish;
  StreamSubscription? _subscription;
  
  Process? _customProcess;
  StreamSubscription? _customSubscription;
  bool _isCustomActive = false;
  
  Function(String evaluation, String bestMove, String continuation, int multipv)? onEvaluationChanged;

  bool _isActive = false;
  int _requestId = 0;

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
    if (!_isActive) return;

    if (_useOnline) {
      final reqId = ++_requestId;
      try {
        final url = 'https://stockfish.online/api/s/v2.php?fen=${Uri.encodeComponent(fen)}&depth=$depth';
        final response = await http.get(Uri.parse(url));

        if (reqId != _requestId) return; // Ignore outdated responses

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            String eval = '0.00';
            if (data['mate'] != null) {
              final mate = data['mate'] as int;
              eval = mate > 0 ? 'M$mate' : '-M${mate.abs()}';
            } else if (data['evaluation'] != null) {
              final double score = (data['evaluation'] as num).toDouble();
              eval = score > 0 ? '+$score' : '$score';
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

            if (onEvaluationChanged != null) {
              onEvaluationChanged!(eval, bestMove, continuation, 1);
            }
          }
        }
      } catch (_) {
        // Ignore network errors gracefully
      }
    } else {
      if (_stockfish == null && _customProcess == null) return;
      // Stop the previous search if it is running
      _sendCommand('stop');
      // Set position based on FEN
      _sendCommand('position fen $fen');
      if (isInfinite) {
        _sendCommand('go infinite');
      } else {
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
      
      // Mate in N moves
      if (line.contains('score mate')) {
        final regExp = RegExp(r'score mate (-?\d+)');
        final match = regExp.firstMatch(line);
        if (match != null) {
          final mateIn = int.parse(match.group(1)!);
          eval = mateIn > 0 ? 'M$mateIn' : '-M${mateIn.abs()}';
        }
      } 
      // Centipawns score (cp)
      else if (line.contains('score cp')) {
        final regExp = RegExp(r'score cp (-?\d+)');
        final match = regExp.firstMatch(line);
        if (match != null) {
          final cp = int.parse(match.group(1)!);
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

      String bestMove = '';
      if (continuation.isNotEmpty) {
        final tokens = continuation.split(' ');
        if (tokens.isNotEmpty) {
          bestMove = tokens[0];
        }
      }

      if (onEvaluationChanged != null) {
        onEvaluationChanged!(eval, bestMove, continuation, multipv);
      }
    }

    // Best move found output (marks end of engine search iteration)
    if (line.startsWith('bestmove')) {
      final parts = line.split(' ');
      if (parts.length > 1) {
        final bestMove = parts[1]; // e.g. "e2e4"
        if (onEvaluationChanged != null) {
          onEvaluationChanged!('', bestMove, '', 1);
        }
      }
    }
  }
}
