import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';

import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

enum PuzzleGameState {
  idle,
  verifyingMove,
  waitingEngineMove,
  puzzleCompleted,
}

class VariationBranchPoint {
  final String fenPostUserMove;
  final String userMoveUci;
  final Map<String, dynamic> oppBranchMap;
  final List<String> pendingOpponentMoves;

  VariationBranchPoint({
    required this.fenPostUserMove,
    required this.userMoveUci,
    required this.oppBranchMap,
    required this.pendingOpponentMoves,
  });
}

class AiStudioScreen extends StatefulWidget {
  final UserSession userSession;

  const AiStudioScreen({super.key, required this.userSession});

  @override
  State<AiStudioScreen> createState() => _AiStudioScreenState();
}

class _AiStudioScreenState extends State<AiStudioScreen> {
  final ChessBoardController _puzzleBoardController = ChessBoardController();

  final StockfishService _stockfishService = StockfishService();

  // Engine Analysis State
  bool _isEngineEnabled = false;
  Map<int, AnalysisLine> _engineLinesMap = {};
  List<ChessArrow> _engineArrows = [];

  // Reorganization Category State
  String? _selectedCategory; // null = Selection Hub, 'mate_puzzle', 'basic_mate', 'winning_position'
  String _selectedMateDepth = '2'; // '1', '2', '3'
  String _selectedBasicMateType = 'easy'; // 'easy', 'medium', 'hard'

  // Board & Game State
  String? _activeFen;
  bool _showEvaluation = false;
  bool _showEvalBar = false; // Default OFF
  double _currentRawEval = 0.0;
  String _currentEvalString = '0.00';
  int _currentEvalDepth = 18;
  double? _lastPosEval;
  double? _lastUserAdvantage;

  Map<String, dynamic>? _currentPuzzle;
  Map<String, dynamic> _rootSolutionsTree = {};
  Map<String, dynamic>? _currentSolutionsNode;
  List<VariationBranchPoint> _activeBranchPoints = [];
  bool _isReplayingSolution = false;
  chess.Chess? _puzzleGame;
  int _userRating = 1500;
  List<String> _expectedMoves = [];
  int _moveIndex = 0;
  int _userMoveCount = 0;
  bool _isLoadingPuzzle = false;
  bool _puzzleSolved = false;
  bool _puzzleFailed = false;
  bool _isBackendConnected = true;
  int _consecutiveServerFailures = 0;
  Timer? _serverHealthTimer;
  int? _lastRatingChange;
  bool _isOpponentTurn = false;
  bool _isVerifyingUserMove = false;
  PuzzleGameState _gameState = PuzzleGameState.idle;
  Timer? _verificationTimeoutTimer;
  int _positionToken = 0;
  PlayerColor _puzzleOrientation = PlayerColor.white;
  bool _isProgrammaticMove = false;
  String? _lastMoveFrom;
  String? _lastMoveTo;
  String? _selectedSquare;
  MoveTree? _puzzleMoveTree;
  String? _initialPuzzleFen;

  final Map<String, String> _basicMatePresets = {
    'K+Q vs K': '4k3/8/8/8/8/8/8/Q3K3 w - - 0 1',
    'K+R vs K': '4k3/8/8/8/8/8/8/R3K3 w - - 0 1',
    'K+2R vs K': '4k3/8/8/8/8/8/8/R3K2R w - - 0 1',
    'K+2B vs K': '4k3/8/8/8/8/8/8/2B1KB2 w - - 0 1',
    'K+B+N vs K': '4k3/8/8/8/8/8/8/1NB1K3 w - - 0 1',
    'K+Q vs K+B': '2b1k3/8/8/8/8/8/8/Q3K3 w - - 0 1',
    'K+Q vs K+R': '2r1k3/8/8/8/8/8/8/Q3K3 w - - 0 1',
  };

  @override
  void initState() {
    super.initState();
    _initStockfish();
    _startServerHealthCheck();
  }

  void _startServerHealthCheck() {
    _serverHealthTimer?.cancel();
    _serverHealthTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkServerHealth());
  }

  Future<void> _checkServerHealth() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/api/health')).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        _consecutiveServerFailures = 0;
        if (!_isBackendConnected && mounted) {
          print('[HEALTH_CHECK_LOG] ✅ Server reconnected at ${DateTime.now()}');
          setState(() => _isBackendConnected = true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.teal,
              duration: Duration(seconds: 3),
              content: Row(
                children: [
                  Icon(Icons.wifi, color: Colors.white),
                  SizedBox(width: 8),
                  Text('✅ Veza sa backend serverom je ponovo uspostavljena.', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }
      } else {
        _consecutiveServerFailures++;
        print('[HEALTH_CHECK_LOG] ⚠️ Server check returned HTTP ${res.statusCode} (Consecutive failures: $_consecutiveServerFailures)');
        if (_consecutiveServerFailures >= 3) {
          _handleServerDisconnected();
        }
      }
    } catch (e) {
      _consecutiveServerFailures++;
      print('[HEALTH_CHECK_LOG] ❌ Server connection error: $e (Consecutive failures: $_consecutiveServerFailures)');
      if (_consecutiveServerFailures >= 3) {
        _handleServerDisconnected();
      }
    }
  }

  void _handleServerDisconnected() {
    if (_isBackendConnected && mounted) {
      print('[HEALTH_CHECK_LOG] 🚨 Server disconnected alert triggered at ${DateTime.now()}');
      setState(() => _isBackendConnected = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 5),
          content: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text('🚨 Izgubljena veza sa backend serverom! Backend je nedostupan.', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Centralized Universal Board State Reboot & Cleanup Function
  void resetBoardState({bool isNewPuzzle = false}) {
    final oldFen = _activeFen ?? _puzzleBoardController.getFen();
    _positionToken++;
    final int currentToken = _positionToken;
    print('[STATE RESET] Cleared arrows and stopped analysis for FEN: $oldFen (Token: $currentToken)');
    _sendBackendLog({
      'type': 'stateReset',
      'oldFen': oldFen,
      'token': currentToken,
    });

    _verificationTimeoutTimer?.cancel();

    // 1. Immediately HALT any active Stockfish analysis worker
    _stockfishService.stopAnalysis();

    // 2. CLEAR all drawn arrows & engine analysis line entries
    _engineLinesMap.clear();
    _engineArrows.clear();
    _lastPosEval = null;
    _lastUserAdvantage = null;

    // 3. RESET visual evaluation values
    _currentRawEval = 0.0;
    _currentEvalString = '0.00';
    _currentEvalDepth = 18;

    // 4. RESET Flags
    _isOpponentTurn = false;
    _isVerifyingUserMove = false;
    _gameState = PuzzleGameState.idle;
    _selectedSquare = null;

    // 5. IF loading a COMPLETELY NEW PUZZLE, reset evaluation toggles A/B to OFF!
    if (isNewPuzzle) {
      _showEvaluation = false;
      _showEvalBar = false;
      _userMoveCount = 0;
      _moveIndex = 0;
      _activeFen = null;
      _puzzleMoveTree = null;
      _initialPuzzleFen = null;
      _rootSolutionsTree.clear();
      _currentSolutionsNode = null;
      _activeBranchPoints.clear();
      _isReplayingSolution = false;
      _stockfishService.setMultiPV(3);
    }
  }

  void _resetEngineState() {
    resetBoardState(isNewPuzzle: true);
  }

  Future<void> _sendBackendLog(Map<String, dynamic> details) async {
    try {
      final uri = Uri.parse('$backendUrl/api/puzzles/log');
      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.userSession.token}',
        },
        body: jsonEncode({'details': details}),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        if (!_isBackendConnected && mounted) {
          setState(() => _isBackendConnected = true);
        }
      } else {
        print('[BACKEND_LOG_WARN] HTTP ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      print('[BACKEND_LOG_ERROR] $e');
      _handleServerDisconnected();
    }
  }

  Future<void> _initStockfish() async {
    await _stockfishService.initEngine();
    _stockfishService.onEvaluationChanged = (evaluation, bestMove, continuation, multipv, depth, isFinal, analyzedFen) async {
      if (!mounted) return;

      print('[ENGINE STREAM] Received eval for FEN: $analyzedFen | Depth: $depth | Best Move: $bestMove');
      _sendBackendLog({
        'type': 'engineStream',
        'fen': analyzedFen,
        'depth': depth,
        'bestMove': bestMove,
      });

      final currentBoardFen = (_puzzleGame?.fen ?? _activeFen ?? _puzzleBoardController.getFen()).split(' ')[0];
      final eventFen = analyzedFen.split(' ')[0];

      if (analyzedFen.isEmpty || eventFen != currentBoardFen) {
        print('[IGNORED EVENT] Discarding stale evaluation from old FEN: $analyzedFen (Current Board FEN: $currentBoardFen)');
        _sendBackendLog({
          'type': 'ignoredEvent',
          'oldFen': analyzedFen,
          'currentFen': currentBoardFen,
        });
        return; // Odbaci stari event i NEMOJ crtati strelice!
      }

      print('[UI RENDER] Attempting to draw arrows for FEN: $analyzedFen | Current Board FEN: $currentBoardFen');
      _sendBackendLog({
        'type': 'uiRender',
        'fen': analyzedFen,
        'currentFen': currentBoardFen,
      });

      double parsedEval = 0.0;
      final numVal = double.tryParse(evaluation);
      if (numVal != null) {
        parsedEval = numVal;
      } else if (evaluation.contains('M')) {
        final mateNum = int.tryParse(evaluation.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        parsedEval = evaluation.contains('-') ? (-10000.0 + mateNum) : (10000.0 - mateNum);
      }

      // Build top 3 engine arrows for display
      final List<ChessArrow> newArrows = [];
      final colors = ['G', 'B', 'O'];
      int colorIdx = 0;
      for (var line in _engineLinesMap.values) {
        if (colorIdx >= 3) break;
        if (line.fromSquare.isNotEmpty && line.toSquare.isNotEmpty) {
          newArrows.add(ChessArrow(
            from: line.fromSquare,
            to: line.toSquare,
            colorCode: colors[colorIdx],
          ));
          colorIdx++;
        }
      }

      // ONLY update main evaluation score & depth when multipv == 1 (top #1 best move)!
      if (multipv == 1) {
        setState(() {
          _currentRawEval = parsedEval;
          _currentEvalString = evaluation;
          _currentEvalDepth = depth;
          _engineArrows = newArrows;
        });
        _lastPosEval = parsedEval;
      } else {
        setState(() {
          _engineArrows = newArrows;
        });
      }

      // --- PHASE A: USER MOVE VERIFICATION (Depth 25 with Early Exit) ---
      if (_isVerifyingUserMove) {
        if (_selectedCategory == 'mate_puzzle') {
          final int reqN = int.tryParse(_selectedMateDepth) ?? 1;
          final int k = _userMoveCount;
          final int remainingNeeded = reqN - k;

          // Check if Stockfish output contains mate in M for active player
          int? userMateScore;
          if (evaluation.contains('M')) {
            final isNegative = evaluation.contains('-');
            final mateVal = int.tryParse(evaluation.replaceAll(RegExp(r'[^0-9]'), ''));
            if (mateVal != null) {
              if (_puzzleOrientation == PlayerColor.white && !isNegative) {
                userMateScore = mateVal;
              } else if (_puzzleOrientation == PlayerColor.black && isNegative) {
                userMateScore = mateVal;
              }
            }
          }

          // EARLY EXIT: Stockfish found mate M <= (N - k) -> ACCEPT USER MOVE!
          if (userMateScore != null && userMateScore <= remainingNeeded) {
            print('\n[MATE_VERIFICATION] ✅ EARLY EXIT (Depth $depth): Nađen mat M$userMateScore <= $remainingNeeded! Potez prihvaćen!\n');
            _verificationTimeoutTimer?.cancel();
            _isVerifyingUserMove = false;
            _stockfishService.stopAnalysis();
            _triggerOpponentBotResponse();
            return;
          }

          // FAST REJECTION (Depth >= 6): Stockfish shows no mate in remainingNeeded moves -> REJECT IMMEDIATELY!
          final bool isFastFail = (depth >= 6 && (userMateScore == null || userMateScore > remainingNeeded));

          // REJECTION: Stockfish reached Depth 25 or fast fail without finding M <= (N - k) -> REJECT USER MOVE!
          if (isFinal || depth >= 25 || isFastFail) {
            _verificationTimeoutTimer?.cancel();
            _isVerifyingUserMove = false;
            _stockfishService.stopAnalysis();

            // Undo ONLY that single incorrect move
            if (_puzzleGame != null && _puzzleGame!.history.isNotEmpty) {
              _puzzleGame!.undo();
              _puzzleBoardController.loadFen(_puzzleGame!.fen);
              _activeFen = _puzzleGame!.fen;
              if (_userMoveCount > 0) _userMoveCount--;
            }

            print('\n[MATE_VERIFICATION] ❌ POTEZ ODBIJEN! (Stockfish na dubini $depth nije pronašao mat u $remainingNeeded poteza). Potez vraćen, tabla otključana.\n');

            await _sendBackendLog({
              'mode': _categoryDisplayName,
              'dynamicFen': _puzzleGame?.fen,
              'status': 'REJECTED',
              'eval': evaluation,
              'reason': 'Stockfish na dubini $depth nije pronašao mat u $remainingNeeded poteza.',
            });

            _showSnackBar('Netačan potez! Pokušajte sa drugim potezom.');
            return;
          }
        }
        return;
      }

      // --- PHASE B: OPPONENT BOT TURN RESPONSE ---
      if (_isOpponentTurn) {
        if (multipv != 1) return; // GUARANTEE OPPONENT BOT ONLY PLAYS TOP #1 BEST MOVE!

        final targetDepth = AppSettingsService.instance.defaultEngineDepth;
        if (depth < targetDepth && !isFinal) return;

        if (bestMove.isNotEmpty && bestMove != '-' && bestMove.length >= 4) {
          print('\n[ENGINE_MOVE_DEBUG] 🎯 Stockfish je dostigao zadatu dubinu $depth (Cilj iz podešavanja: $targetDepth)! Odabran potez: $bestMove (Eval: $evaluation)\n');
          _stockfishService.stopAnalysis();
          _isOpponentTurn = false;
          _playOpponentMove(bestMove, evaluation);
        }
      }
    };

    _stockfishService.onMultiPVUpdated = (linesMap) {
      if (!mounted) return;
      if (linesMap.isEmpty) return;

      final lineFen = linesMap.values.first.startingFen.split(' ')[0];
      final currentBoardFen = (_puzzleGame?.fen ?? _activeFen ?? _puzzleBoardController.getFen()).split(' ')[0];

      if (lineFen != currentBoardFen) {
        print('[IGNORED EVENT] Discarding stale MultiPV lines from old FEN: $lineFen (Current Board FEN: $currentBoardFen)');
        return;
      }

      setState(() {
        _engineLinesMap = linesMap;
        _engineArrows = _buildArrowsFromEngineLines(linesMap.values.toList());
      });
    };
  }

  void _playOpponentMove(String bestMove, String evaluation) {
    String validMove = bestMove;
    if (_puzzleGame != null) {
      final legalMoves = _puzzleGame!.moves({'verbose': true});
      final isLegal = legalMoves.any((m) {
        final from = m['from'] ?? '';
        final to = m['to'] ?? '';
        final promo = m['promotion'] ?? '';
        final lan = '$from$to$promo';
        return lan.startsWith(validMove.substring(0, 4));
      });
      if (!isLegal && legalMoves.isNotEmpty) {
        final fallbackObj = legalMoves.first;
        final from = fallbackObj['from'] ?? '';
        final to = fallbackObj['to'] ?? '';
        final promo = fallbackObj['promotion'] ?? '';
        validMove = '$from$to$promo';
        print('\n[TRAINING_LOG] ⚠️ ENGINE JE VRATIO NELEGALAN POTEZ ($bestMove)! Zamenjen legalnim potezom: $validMove\n');
      }
    }

    final targetDepth = AppSettingsService.instance.defaultEngineDepth;

    print('\n--------------------------------------------------');
    print('[TRAINING_LOG] 1) MOD: $_categoryDisplayName');
    print('[TRAINING_LOG] 3) FEN POZICIJA KOJU ANALIZIRA ENGINE: ${_puzzleGame?.fen}');
    print('[TRAINING_LOG] 5) POTEZ ENGINE-A: $validMove');
    print('[TRAINING_LOG] 5) OSNOV ODABIRA: Stockfish kalkulacija najbolje linije');
    print('[TRAINING_LOG] 5) DUBINA ANALIZE (DEPTH): $targetDepth');
    print('[TRAINING_LOG] 5) EVALUACIJA POZICIJE: $evaluation (Best: $validMove)');
    print('--------------------------------------------------\n');

    _sendBackendLog({
      'mode': _categoryDisplayName,
      'dynamicFen': _puzzleGame?.fen,
      'engineMove': validMove,
      'decisionBasis': 'Stockfish kalkulacija najbolje linije',
      'depth': targetDepth,
      'eval': evaluation,
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      _playPuzzleMove(validMove);
      if (_puzzleGame != null) {
        _activeFen = _puzzleGame!.fen;
        resetBoardState(isNewPuzzle: false);

        if (_puzzleGame!.in_checkmate) {
          if (_selectedCategory == 'basic_mate') {
            _showSnackBar('❌ Stockfish vam je zadao mat.');
          } else {
            setState(() => _puzzleSolved = true);
            _showEndgameWinDialog();
          }
        } else if (_puzzleGame!.in_stalemate || _puzzleGame!.in_draw) {
          _showSnackBar('🤝 Pat / Remi u poziciji.');
        } else {
          if (_showEvaluation || _showEvalBar) {
            _stockfishService.setMultiPV(3);
            _stockfishService.analyzePosition(_puzzleGame!.fen, depth: 20);
          }
        }
      }
    });
  }

  void _triggerOpponentBotResponse() async {
    if (_puzzleGame == null || _puzzleGame!.in_checkmate) return;
    resetBoardState(isNewPuzzle: false);
    setState(() {
      _isVerifyingUserMove = false;
      _isOpponentTurn = true;
    });

    // If puzzle solution JSON has the predefined response move at _moveIndex, play it!
    if (_expectedMoves.length > _moveIndex && _expectedMoves[_moveIndex].isNotEmpty) {
      final jsonResponseMove = _expectedMoves[_moveIndex];
      _moveIndex++;
      print('\n[OPPONENT_BOT_DEBUG] 🎯 Pronađen spreman odgovor u JSON rešenju: $jsonResponseMove\n');
      _stockfishService.stopAnalysis();
      _isOpponentTurn = false;
      _playOpponentMove(jsonResponseMove, 'JSON');
      return;
    }

    await _stockfishService.initEngine();
    _stockfishService.setMultiPV(1);
    final targetDepth = AppSettingsService.instance.defaultEngineDepth;
    _stockfishService.analyzePosition(_puzzleGame!.fen, depth: targetDepth);
  }

  void _showBlunderAlert(double evalDiff, double currentEval) {
    if (!mounted) return;
    final isCritical = currentEval <= 0.5;
    final title = isCritical ? '🚨 TEŠKA GREŠKA (BLUNDER)!' : '⚠️ NEPRECIZNOST!';
    final msg = isCritical
        ? 'Ovim potezom ste izgubili dobitnu poziciju (Pad evaluacije: -${evalDiff.toStringAsFixed(1)}).'
        : 'Napravili ste neprecizan potez, ali ste i dalje u prednosti (Pad: -${evalDiff.toStringAsFixed(1)}).';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isCritical ? Colors.red.shade900 : Colors.amber.shade900,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(isCritical ? Icons.cancel : Icons.warning_amber, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(msg, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<EngineArrow> _buildEngineArrowsFromLines(List<AnalysisLine> lines) {
    final List<EngineArrow> engineArrowsList = [];
    if (_isOpponentTurn) {
      if (lines.isNotEmpty) {
        final line = lines.first;
        final moveStr = line.bestMoveLan;
        if (moveStr.length >= 4) {
          engineArrowsList.add(EngineArrow(
            from: moveStr.substring(0, 2),
            to: moveStr.substring(2, 4),
            evalText: line.evaluation,
            rank: 1,
          ));
        }
      }
      return engineArrowsList;
    }

    for (int i = 0; i < lines.length && i < 3; i++) {
      final line = lines[i];
      final moveStr = line.bestMoveLan;
      if (moveStr.length >= 4) {
        engineArrowsList.add(EngineArrow(
          from: moveStr.substring(0, 2),
          to: moveStr.substring(2, 4),
          evalText: line.evaluation,
          rank: i + 1,
        ));
      }
    }
    return engineArrowsList;
  }

  List<ChessArrow> _buildArrowsFromEngineLines(List<AnalysisLine> lines) {
    final List<ChessArrow> arrows = [];
    if (_isOpponentTurn) {
      if (lines.isNotEmpty) {
        final moveStr = lines.first.bestMoveLan;
        if (moveStr.length >= 4) {
          arrows.add(ChessArrow(
            from: moveStr.substring(0, 2),
            to: moveStr.substring(2, 4),
            colorCode: 'G',
          ));
        }
      }
      return arrows;
    }

    final colors = ['G', 'B', 'O'];
    for (int i = 0; i < lines.length && i < 3; i++) {
      final moveStr = lines[i].bestMoveLan;
      if (moveStr.length >= 4) {
        arrows.add(ChessArrow(
          from: moveStr.substring(0, 2),
          to: moveStr.substring(2, 4),
          colorCode: colors[i],
        ));
      }
    }
    return arrows;
  }

  @override
  void dispose() {
    _stockfishService.dispose();
    super.dispose();
  }

  // --- LAUNCH CATEGORIES ---

  void _launchCategory(String category) {
    _resetEngineState();
    setState(() {
      _selectedCategory = category;
    });

    if (category == 'basic_mate') {
      _loadBasicMatePreset(_selectedBasicMateType);
    } else {
      _fetchNextPuzzle();
    }
  }

  String get _categoryDisplayName {
    if (_selectedCategory == 'mate_puzzle') return 'Zagonetke: Mat u $_selectedMateDepth poteza';
    if (_selectedCategory == 'basic_mate') return 'Vežbajte osnovno matiranje ($_selectedBasicMateType)';
    if (_selectedCategory == 'winning_position') return 'Pronađite dobitni put';
    return _selectedCategory ?? 'Trening';
  }

  Future<void> _loadBasicMatePreset(String difficulty) async {
    _resetEngineState();
    String assetPath;
    if (difficulty == 'hard') {
      assetPath = 'assets/puzzles/hard_puzzles.json';
    } else if (difficulty == 'medium') {
      assetPath = 'assets/puzzles/medium_puzzles.json';
    } else {
      assetPath = 'assets/puzzles/easy_puzzles.json';
    }

    try {
      final jsonStr = await rootBundle.loadString(assetPath);
      final List<dynamic> list = jsonDecode(jsonStr);
      if (list.isNotEmpty) {
        list.shuffle();
        final item = list.first;
        final fen = item['fen'] ?? '4k3/8/8/8/8/8/8/Q3K3 w - - 0 1';
        final parts = fen.split(' ');
        final turnIsWhite = parts.length > 1 ? (parts[1] == 'w') : true;

        _puzzleGame = chess.Chess.fromFEN(fen);
        _activeFen = fen;
        _initialPuzzleFen = fen;
        _puzzleMoveTree = MoveTree(startingFen: fen);

        print('\n==================================================');
        print('[TRAINING_LOG] 1) MOD: $_categoryDisplayName');
        print('[TRAINING_LOG] 2) UČITANI FEN: $fen');
        print('==================================================\n');

        _sendBackendLog({
          'mode': _categoryDisplayName,
          'initialFen': fen,
        });

        setState(() {
          _selectedCategory = 'basic_mate';
          _selectedBasicMateType = difficulty;
          _isLoadingPuzzle = false;
          _puzzleSolved = false;
          _puzzleFailed = false;
          _expectedMoves = [];
          _moveIndex = 0;
          _lastMoveFrom = null;
          _lastMoveTo = null;
          _isOpponentTurn = false;
          _puzzleOrientation = turnIsWhite ? PlayerColor.white : PlayerColor.black;
          _showEvalBar = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _puzzleBoardController.loadFen(fen);
            } catch (_) {}
          }
        });

        _stockfishService.analyzePosition(fen, depth: 20);
      }
    } catch (e) {
      print('Error loading basic mate preset $difficulty: $e');
    }
  }

  Future<void> _fetchNextPuzzle() async {
    _resetEngineState();
    final String currentId = _currentPuzzle?['puzzle_id'] ?? '';
    setState(() {
      _isLoadingPuzzle = true;
      _puzzleSolved = false;
      _puzzleFailed = false;
      _lastRatingChange = null;
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _isOpponentTurn = false;
    });

    try {
      final categoryParam = _selectedCategory ?? 'mate_puzzle';
      final depthParam = (categoryParam == 'mate_puzzle') ? '&mate_depth=$_selectedMateDepth' : '';
      final excludeParam = currentId.isNotEmpty ? '&excludeId=$currentId' : '';
      final uri = Uri.parse('$backendUrl/api/puzzles/next?userId=${widget.userSession.id}&type=$categoryParam$depthParam$excludeParam');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.userSession.token}'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final p = data['puzzle'];
        final fen = p['fen'];
        final moves = List<String>.from(p['moves'] ?? []);

        _puzzleGame = chess.Chess.fromFEN(fen);
        _activeFen = fen;
        _initialPuzzleFen = fen;
        _puzzleMoveTree = MoveTree(startingFen: fen);

        setState(() {
          _currentPuzzle = p;
          _userRating = data['userRating'] ?? 1500;
          _expectedMoves = moves;
          _moveIndex = 0;
          _rootSolutionsTree = Map<String, dynamic>.from(p['solutions'] ?? {});
          _currentSolutionsNode = Map<String, dynamic>.from(_rootSolutionsTree);
          _activeBranchPoints.clear();
          _isReplayingSolution = false;
        });

        print('\n==================================================');
        print('[TRAINING_LOG] 1) MOD: $_categoryDisplayName');
        print('[TRAINING_LOG] 2) UČITANI FEN: $fen');
        print('[TRAINING_LOG] OČEKIVANI POTEZI (JSON): $moves');
        print('[TREE_VERIFICATION] 🌳 Stablo rešenja učitano (${_currentSolutionsNode?.keys.length ?? 0} grana)');
        print('==================================================\n');

        _sendBackendLog({
          'mode': _categoryDisplayName,
          'initialFen': fen,
        });

        final sideToMove = fen.split(' ')[1];
        setState(() {
          _puzzleOrientation = (sideToMove == 'b') ? PlayerColor.black : PlayerColor.white;
          _isOpponentTurn = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _puzzleBoardController.loadFen(fen);
            } catch (_) {}
          }
        });

        if (_selectedCategory != 'mate_puzzle' && (_showEvaluation || _showEvalBar)) {
          _stockfishService.analyzePosition(fen, depth: 20);
        }
      } else {
        _showSnackBar('Nije moguće učitati poziciju.');
      }
    } catch (e) {
      _showSnackBar('Greška pri učitavanju pozicije.');
    } finally {
      if (mounted) setState(() => _isLoadingPuzzle = false);
    }
  }

  void _recordMoveInTree(String from, String to, {String san = '', String promotion = ''}) {
    if (_puzzleGame == null || _puzzleMoveTree == null) return;
    final displaySan = san.isNotEmpty ? san : '$from$to';
    final fen = _puzzleGame!.fen;

    for (var child in _puzzleMoveTree!.current.children) {
      if (child.san == displaySan || (child.from == from && child.to == to)) {
        _puzzleMoveTree!.current = child;
        return;
      }
    }

    final newNode = MoveNode(
      san: displaySan,
      fen: fen,
      from: from,
      to: to,
      parent: _puzzleMoveTree!.current,
    );
    _puzzleMoveTree!.current.children.add(newNode);
    _puzzleMoveTree!.current = newNode;
  }

  void _restartCurrentPuzzle() {
    if (_initialPuzzleFen == null) return;
    resetBoardState(isNewPuzzle: false);
    _puzzleGame = chess.Chess.fromFEN(_initialPuzzleFen!);
    _activeFen = _initialPuzzleFen;
    _puzzleBoardController.loadFen(_initialPuzzleFen!);

    setState(() {
      _puzzleSolved = false;
      _puzzleFailed = false;
      _moveIndex = 0;
      _userMoveCount = 0;
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _puzzleMoveTree = MoveTree(startingFen: _initialPuzzleFen!);
    });

    if (_showEvaluation || _showEvalBar) {
      _stockfishService.setMultiPV(3);
      _stockfishService.analyzePosition(_initialPuzzleFen!, depth: 20);
    }

    _sendBackendLog({
      'mode': _categoryDisplayName,
      'action': 'RESTART_PUZZLE',
      'initialFen': _initialPuzzleFen,
    });

    _showSnackBar('🔄 Pozicija je vraćena na početno stanje.');
  }

  void _handleSquareTap(String square) {
    if (_isOpponentTurn || _puzzleSolved || _puzzleGame == null) return;

    final piece = _puzzleGame!.get(square);
    final isTurnWhite = _puzzleGame!.turn == chess.Color.WHITE;

    bool isFriendlyPiece = false;
    if (piece != null) {
      if (isTurnWhite && piece.color == chess.Color.WHITE) isFriendlyPiece = true;
      if (!isTurnWhite && piece.color == chess.Color.BLACK) isFriendlyPiece = true;
    }

    if (isFriendlyPiece) {
      setState(() {
        _selectedSquare = square;
      });
      return;
    }

    if (_selectedSquare != null && _selectedSquare != square) {
      final from = _selectedSquare!;
      final to = square;

      final testGame = chess.Chess.fromFEN(_puzzleGame!.fen);
      final moveRes = testGame.move({'from': from, 'to': to, 'promotion': 'q'});

      if (moveRes != null) {
        _puzzleGame!.move({'from': from, 'to': to, 'promotion': 'q'});
        _puzzleBoardController.loadFen(_puzzleGame!.fen);
        _activeFen = _puzzleGame!.fen;
        setState(() {
          _selectedSquare = null;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onUserPuzzleMoveMade();
        });
      } else {
        setState(() {
          _selectedSquare = null;
        });
      }
    }
  }

  void _playPuzzleMove(String lanMove) {
    if (lanMove.length < 4) return;
    final fromStr = lanMove.substring(0, 2);
    final toStr = lanMove.substring(2, 4);

    _isProgrammaticMove = true;
    try {
      if (_puzzleGame != null) {
        String san = '$fromStr$toStr';
        for (var m in _puzzleGame!.moves({'verbose': true})) {
          if (m['from'] == fromStr && m['to'] == toStr) {
            san = m['san'] ?? san;
            break;
          }
        }
        _puzzleGame!.move({'from': fromStr, 'to': toStr, 'promotion': lanMove.length > 4 ? lanMove[4] : 'q'});
        _puzzleBoardController.loadFen(_puzzleGame!.fen);
        _activeFen = _puzzleGame!.fen;
        _recordMoveInTree(fromStr, toStr, san: san);
      } else {
        _puzzleBoardController.makeMove(from: fromStr, to: toStr);
        _activeFen = _puzzleBoardController.getFen();
      }
      setState(() {
        _lastMoveFrom = fromStr;
        _lastMoveTo = toStr;
      });
    } catch (e) {
      print('Error playing move $lanMove: $e');
    } finally {
      _isProgrammaticMove = false;
    }
  }

  void _onUserPuzzleMoveMade() async {
    print('[MOVE_MADE_DEBUG] _onUserPuzzleMoveMade called! Prog: $_isProgrammaticMove | Solved: $_puzzleSolved | Failed: $_puzzleFailed | OpponentTurn: $_isOpponentTurn | GameState: $_gameState | GameNull: ${_puzzleGame == null}');

    if (_isProgrammaticMove || _puzzleSolved || _puzzleFailed || _isOpponentTurn || _gameState != PuzzleGameState.idle || _puzzleGame == null) return;

    setState(() {
      _gameState = PuzzleGameState.verifyingMove;
    });

    final currentFen = _puzzleBoardController.getFen();
    print('[MOVE_MADE_DEBUG] Board Controller FEN: $currentFen');
    print('[MOVE_MADE_DEBUG] Local Puzzle Game FEN: ${_puzzleGame!.fen}');

    if (currentFen == _puzzleGame!.fen) {
      print('[MOVE_MADE_DEBUG] FENs are identical, no move detected yet.');
      return;
    }

    final String startingFen = _puzzleGame!.fen;

    // Determine move played on board
    String? userLan;
    dynamic matchedMove;

    final currentBoardFen = currentFen.split(' ')[0];

    for (var m in _puzzleGame!.moves({'verbose': true})) {
      final testGame = chess.Chess.fromFEN(_puzzleGame!.fen);
      testGame.move(m);
      final testBoardFen = testGame.fen.split(' ')[0];

      if (currentBoardFen == testBoardFen) {
        matchedMove = m;
        final from = m['from'] ?? '';
        final to = m['to'] ?? '';
        final promo = m['promotion'] ?? '';
        userLan = '$from$to$promo';
        break;
      }
    }

    if (matchedMove == null) {
      for (var m in _puzzleGame!.moves({'verbose': true})) {
        final from = m['from'] ?? '';
        final to = m['to'] ?? '';
        final promo = m['promotion'] ?? '';
        if ((to.endsWith('8') || to.endsWith('1')) && promo.isNotEmpty) {
          matchedMove = m;
          userLan = '$from$to$promo';
          print('[MOVE_MADE_DEBUG] Fallback promotion match found: $userLan');
          break;
        }
      }
    }

    print('[MOVE_MADE_DEBUG] Matched move: $matchedMove | User LAN: $userLan');

    if (matchedMove == null || userLan == null) {
      print('[MOVE_MADE_DEBUG] Could not match move in chess.js legal moves!');
      return;
    }

    _puzzleGame!.move(matchedMove);
    _activeFen = _puzzleGame!.fen;

    // Universal reboot of board state for move execution (preserves toggles A/B if ON!)
    resetBoardState(isNewPuzzle: false);

    final fromStr = userLan.substring(0, 2);
    final toStr = userLan.substring(2, 4);
    final san = matchedMove['san'] ?? '$fromStr$toStr';
    _recordMoveInTree(fromStr, toStr, san: san);
    _userMoveCount++;
    final int reqN = int.tryParse(_selectedMateDepth) ?? 1;
    final int k = _userMoveCount;

    setState(() {
      _lastMoveFrom = fromStr;
      _lastMoveTo = toStr;
    });

    // --- STEP 0: IMMEDIATE CHECKMATE VICTORY ON BOARD ---
    if (_puzzleGame!.in_checkmate) {
      print('\n==================================================');
      print('[TRAINING_LOG] 🏆 MAT NA TABLI! Korisnik je uspešno zadao mat!');
      print('==================================================\n');

      await _sendBackendLog({
        'mode': _categoryDisplayName,
        'dynamicFen': currentFen,
        'userMove': userLan,
        'status': 'SOLVED',
        'reason': 'Korisnik je uspešno zadao mat na tabli!',
      });

      if (_selectedCategory == 'basic_mate' || _selectedCategory == 'winning_position') {
        setState(() => _puzzleSolved = true);
        _showEndgameWinDialog();
      } else {
        _submitPuzzleResult(true);
      }
      return;
    }

    // --- STEP 1: DIRECT LOCAL SOLUTION TREE VERIFICATION FOR MATE PUZZLES ---
    if (_selectedCategory == 'mate_puzzle') {
      _currentSolutionsNode ??= Map<String, dynamic>.from(_currentPuzzle?['solutions'] ?? {});
      final primaryJsonMove = _currentPuzzle?['winning_move_uci'] ?? (_expectedMoves.length > _moveIndex ? _expectedMoves[_moveIndex] : '');

      dynamic subBranch = _currentSolutionsNode?[userLan];
      // Fallback for single-move or legacy format where solutions tree might be empty or flat
      if (subBranch == null && primaryJsonMove.isNotEmpty && userLan == primaryJsonMove) {
        subBranch = "CHECKMATE";
      }

      print('\n==================================================');
      print('[TREE_VERIFICATION] 🌳 User move: $userLan | Primary JSON move: $primaryJsonMove');
      print('[TREE_VERIFICATION] 🌳 Sub-branch: $subBranch');
      print('==================================================\n');

      if (subBranch != null) {
        _isVerifyingUserMove = false;
        _moveIndex++;

        _sendBackendLog({
          'mode': _categoryDisplayName,
          'initialFen': _initialPuzzleFen,
          'dynamicFen': startingFen,
          'userMove': '$userLan ($san)',
          'status': 'ACCEPTED',
          'subBranch': subBranch == "CHECKMATE" ? "CHECKMATE (Matni kraj)" : (subBranch is Map ? "Grana sa odgovora: ${subBranch.keys.join(', ')}" : subBranch.toString()),
        });

        final bool isTerminalCheckmate = (subBranch == "CHECKMATE" || _puzzleGame!.in_checkmate);

        if (isTerminalCheckmate || (subBranch is Map && (subBranch as Map).isEmpty)) {
          // Check if there are any pending variation branch points with unvisited opponent moves!
          VariationBranchPoint? pendingBP;
          while (_activeBranchPoints.isNotEmpty) {
            final top = _activeBranchPoints.last;
            if (top.pendingOpponentMoves.isNotEmpty) {
              pendingBP = top;
              break;
            } else {
              _activeBranchPoints.removeLast(); // Clean up completed branch points
            }
          }

          if (pendingBP != null) {
            final String nextOppMove = pendingBP.pendingOpponentMoves.removeAt(0);
            print('[TREE_VERIFICATION] 🔁 Rešena linija do mata! Nastavak na drugu odbrambenu varijantu od tačke razgranjenja: $nextOppMove');
            
            _showSnackBar('Sjajno! Rešite i ostalu odbrambenu liniju protivnika.');

            // Reset board to the EXACT branching FEN (post-user-move position) and play next opponent variation
            Future.delayed(const Duration(milliseconds: 600), () {
              if (!mounted) return;
              try {
                _puzzleGame = chess.Chess.fromFEN(pendingBP!.fenPostUserMove);
                _puzzleBoardController.loadFen(pendingBP.fenPostUserMove);
                _activeFen = pendingBP.fenPostUserMove;

                final oppFrom = nextOppMove.substring(0, 2);
                final oppTo = nextOppMove.substring(2, 4);
                final oppPromo = nextOppMove.length > 4 ? nextOppMove[4] : null;

                _puzzleGame!.move({'from': oppFrom, 'to': oppTo, 'promotion': oppPromo});
                _puzzleBoardController.loadFen(_puzzleGame!.fen);
                _activeFen = _puzzleGame!.fen;
                _lastMoveFrom = oppFrom;
                _lastMoveTo = oppTo;

                final oppSubNode = pendingBP.oppBranchMap[nextOppMove];
                if (oppSubNode is Map) {
                  _currentSolutionsNode = Map<String, dynamic>.from(oppSubNode);
                } else if (oppSubNode is List) {
                  final Map<String, dynamic> listNode = {};
                  for (var m in oppSubNode) {
                    listNode[m.toString()] = "CHECKMATE";
                  }
                  _currentSolutionsNode = listNode;
                } else {
                  _currentSolutionsNode = {};
                }

                setState(() {
                  _gameState = PuzzleGameState.idle;
                  _isOpponentTurn = false;
                });
              } catch (e) {
                print('Greška pri prelasku na sledeću varijantu: $e');
              }
            });
            return;
          }

          // All variations completely solved!
          print('[TREE_VERIFICATION] 🎉 SVE VARIJANTE U POTPUNOSTI REŠENE! Zagonetka je uspešno rešena.');
          setState(() {
            _puzzleSolved = true;
            _gameState = PuzzleGameState.puzzleCompleted;
          });
          _submitPuzzleResult(true);
          _showSnackBar('Čestitamo! Zagonetka je uspešno rešena! 🎉');
          return;
        }

        if (subBranch is Map) {
          final Map<String, dynamic> oppTree = Map<String, dynamic>.from(subBranch as Map);
          
          // Check unicity: do all opponent replies require identical user responses?
          final bool isIdenticalUserMoves = _areUserMovesIdenticalForAllOpponentReplies(oppTree);

          String oppMoveLan;
          if (!isIdenticalUserMoves && oppTree.keys.length > 1) {
            // Find or record branch point for current user move
            VariationBranchPoint? existingBP;
            for (var bp in _activeBranchPoints) {
              if (bp.fenPostUserMove == _puzzleGame!.fen && bp.userMoveUci == userLan) {
                existingBP = bp;
                break;
              }
            }

            if (existingBP == null) {
              final allOppKeys = oppTree.keys.toList();
              oppMoveLan = allOppKeys.first;
              final pendingKeys = allOppKeys.sublist(1);

              _activeBranchPoints.add(VariationBranchPoint(
                fenPostUserMove: _puzzleGame!.fen,
                userMoveUci: userLan,
                oppBranchMap: oppTree,
                pendingOpponentMoves: pendingKeys,
              ));
            } else {
              if (existingBP.pendingOpponentMoves.isNotEmpty) {
                oppMoveLan = existingBP.pendingOpponentMoves.removeAt(0);
              } else {
                oppMoveLan = oppTree.keys.first;
              }
            }
          } else {
            oppMoveLan = oppTree.keys.first;
          }

          final dynamic nextSubTree = oppTree[oppMoveLan];

          setState(() => _gameState = PuzzleGameState.waitingEngineMove);

          // Opponent response after 300ms delay
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!mounted) return;
            try {
              final oppFrom = oppMoveLan.substring(0, 2);
              final oppTo = oppMoveLan.substring(2, 4);
              final oppPromo = oppMoveLan.length > 4 ? oppMoveLan[4] : null;

              final moveObj = _puzzleGame!.move({'from': oppFrom, 'to': oppTo, 'promotion': oppPromo});
              if (moveObj != null) {
                _puzzleBoardController.loadFen(_puzzleGame!.fen);
                _activeFen = _puzzleGame!.fen;
                _lastMoveFrom = oppFrom;
                _lastMoveTo = oppTo;
              }

              if (nextSubTree is Map) {
                _currentSolutionsNode = Map<String, dynamic>.from(nextSubTree);
              } else if (nextSubTree is List) {
                final Map<String, dynamic> listNode = {};
                for (var m in nextSubTree) {
                  listNode[m.toString()] = "CHECKMATE";
                }
                _currentSolutionsNode = listNode;
              } else {
                _currentSolutionsNode = {};
              }

              setState(() {
                _gameState = PuzzleGameState.idle;
                _isOpponentTurn = false;
              });

              if (_currentSolutionsNode!.isEmpty || nextSubTree == "CHECKMATE" || _puzzleGame!.in_checkmate) {
                bool hasPendingBP = false;
                for (var bp in _activeBranchPoints) {
                  if (bp.pendingOpponentMoves.isNotEmpty) {
                    hasPendingBP = true;
                    break;
                  }
                }

                if (!hasPendingBP && (_puzzleGame!.in_checkmate || nextSubTree == "CHECKMATE")) {
                  setState(() {
                    _puzzleSolved = true;
                    _gameState = PuzzleGameState.puzzleCompleted;
                  });
                  _submitPuzzleResult(true);
                  _showSnackBar('Čestitamo! Zagonetka je uspešno rešena! 🎉');
                }
              }
            } catch (e) {
              print('Greška pri odigravanju poteza protivnika: $e');
              setState(() {
                _gameState = PuzzleGameState.idle;
                _isOpponentTurn = false;
              });
            }
          });
          return;
        }

        // Fallback win
        setState(() {
          _puzzleSolved = true;
          _gameState = PuzzleGameState.puzzleCompleted;
        });
        _submitPuzzleResult(true);
        _showSnackBar('Čestitamo! Zagonetka je uspešno rešena! 🎉');
        return;
      } else {
        // Move NOT in solution tree -> Show failure modal dialog with 3 choices!
        print('[TREE_VERIFICATION] ❌ Potez $userLan nije u stablu rešenja! Prikazivanje dijaloga za grešku.');
        _sendBackendLog({
          'mode': _categoryDisplayName,
          'initialFen': _initialPuzzleFen,
          'dynamicFen': startingFen,
          'userMove': '$userLan ($san)',
          'status': 'REJECTED',
          'reason': 'Potez nije u ugnježđenom stablu rešenja zagonetke',
        });
        _showFailureDialog();
        return;
      }
    }

    await _stockfishService.initEngine();
    _stockfishService.setMultiPV(1);
    final targetDepth = AppSettingsService.instance.defaultEngineDepth;
    _stockfishService.analyzePosition(_puzzleGame!.fen, depth: targetDepth);
  }

  bool _areUserMovesIdenticalForAllOpponentReplies(Map<String, dynamic> oppBranchMap) {
    if (oppBranchMap.isEmpty) return true;
    String? firstUserMoveSet;

    for (var oppMove in oppBranchMap.keys) {
      final oppSub = oppBranchMap[oppMove];
      String moveSignature = '';
      if (oppSub is Map) {
        moveSignature = oppSub.keys.join(',');
      } else if (oppSub is List) {
        moveSignature = oppSub.join(',');
      } else if (oppSub is String) {
        moveSignature = oppSub;
      }

      if (firstUserMoveSet == null) {
        firstUserMoveSet = moveSignature;
      } else if (firstUserMoveSet != moveSignature) {
        return false;
      }
    }
    return true;
  }

  void _showFailureDialog() {
    if (!mounted) return;
    _sendBackendLog({
      'type': 'buttonClick',
      'button': 'Prikazan dijalog - Netačan Potez',
      'puzzleId': _currentPuzzle?['puzzle_id'],
      'fen': _puzzleGame?.fen,
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Netačan Potez!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Potez koji ste odigrali nije u stablu rešenja. Izaberite opciju:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Pokušaj Ponovo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _sendBackendLog({'type': 'buttonClick', 'button': 'Modal - Pokušaj Ponovo'});
                    _undoIncorrectUserMove();
                  },
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.lightbulb_outline),
                      label: const Text('Prikaži Rešenje'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendBackendLog({'type': 'buttonClick', 'button': 'Modal - Prikaži Rešenje'});
                        _playFullSolutionReplay();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Sledeća Zagonetka'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendBackendLog({'type': 'buttonClick', 'button': 'Modal - Sledeća Zagonetka'});
                        _fetchNextPuzzle();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _undoIncorrectUserMove() {
    if (_puzzleGame != null && _puzzleGame!.history.isNotEmpty) {
      _puzzleGame!.undo();
      _puzzleBoardController.loadFen(_puzzleGame!.fen);
      _activeFen = _puzzleGame!.fen;
      if (_userMoveCount > 0) _userMoveCount--;
    }
    resetBoardState(isNewPuzzle: false);
    setState(() {
      _gameState = PuzzleGameState.idle;
      _isOpponentTurn = false;
      _isVerifyingUserMove = false;
    });
  }

  Future<void> _playFullSolutionReplay() async {
    if (_initialPuzzleFen == null || _rootSolutionsTree.isEmpty) return;
    _sendBackendLog({
      'type': 'buttonClick',
      'button': 'Akcija - Prikaži Rešenje (Auto Replay)',
      'puzzleId': _currentPuzzle?['puzzle_id'],
      'fen': _initialPuzzleFen,
    });
    setState(() => _isReplayingSolution = true);

    _puzzleGame = chess.Chess.fromFEN(_initialPuzzleFen!);
    _puzzleBoardController.loadFen(_initialPuzzleFen!);
    _activeFen = _initialPuzzleFen!;

    Map<String, dynamic> current = Map<String, dynamic>.from(_rootSolutionsTree);

    while (current.isNotEmpty) {
      final userMove = current.keys.first;
      final from = userMove.substring(0, 2);
      final to = userMove.substring(2, 4);
      final promo = userMove.length > 4 ? userMove[4] : null;

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      _puzzleGame!.move({'from': from, 'to': to, 'promotion': promo});
      _puzzleBoardController.loadFen(_puzzleGame!.fen);
      _activeFen = _puzzleGame!.fen;
      setState(() {
        _lastMoveFrom = from;
        _lastMoveTo = to;
      });

      final oppBranch = current[userMove];
      if (oppBranch is Map && oppBranch.isNotEmpty) {
        final oppMove = (oppBranch as Map).keys.first.toString();
        final oppFrom = oppMove.substring(0, 2);
        final oppTo = oppMove.substring(2, 4);
        final oppPromo = oppMove.length > 4 ? oppMove[4] : null;

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        _puzzleGame!.move({'from': oppFrom, 'to': oppTo, 'promotion': oppPromo});
        _puzzleBoardController.loadFen(_puzzleGame!.fen);
        _activeFen = _puzzleGame!.fen;
        setState(() {
          _lastMoveFrom = oppFrom;
          _lastMoveTo = oppTo;
        });

        final nextLevel = oppBranch[oppMove];
        if (nextLevel is Map) {
          current = Map<String, dynamic>.from(nextLevel);
        } else {
          break;
        }
      } else {
        break;
      }
    }

    setState(() {
      _isReplayingSolution = false;
      _puzzleSolved = true;
      _gameState = PuzzleGameState.puzzleCompleted;
    });
  }

  void _showEndgameWinDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.emoji_events, color: Colors.amberAccent, size: 28),
            SizedBox(width: 8),
            Text('🎉 POBEDA!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text('Čestitamo! Uspešno ste zadali mat Stockfish-u!'),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Sledeća Pozicija'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              if (_selectedCategory == 'basic_mate') {
                _loadBasicMatePreset(_selectedBasicMateType);
              } else {
                _fetchNextPuzzle();
              }
            },
          ),
        ],
      ),
    );
  }

  void _resetCurrentPuzzle() {
    _resetEngineState();
    _sendBackendLog({
      'type': 'buttonClick',
      'button': 'Akcija - Probaj Ponovo',
      'puzzleId': _currentPuzzle?['puzzle_id'],
      'fen': _initialPuzzleFen,
    });
    if (_selectedCategory == 'basic_mate') {
      _loadBasicMatePreset(_selectedBasicMateType);
      return;
    }
    if (_currentPuzzle == null) return;
    final fen = _currentPuzzle!['fen'];
    final moves = List<String>.from(_currentPuzzle!['moves'] ?? []);

    _puzzleGame = chess.Chess.fromFEN(fen);
    _activeFen = fen;

    final sideToMove = fen.split(' ')[1];
    setState(() {
      _puzzleSolved = false;
      _puzzleFailed = false;
      _expectedMoves = moves;
      _moveIndex = 0;
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _isOpponentTurn = false;
      _puzzleOrientation = (sideToMove == 'b') ? PlayerColor.black : PlayerColor.white;
    });

    _puzzleBoardController.loadFen(fen);
    _stockfishService.analyzePosition(fen, depth: 20);
  }

  Future<void> _submitPuzzleResult(bool solved) async {
    setState(() {
      _puzzleSolved = solved;
      _puzzleFailed = !solved;
    });

    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/puzzles/submit'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.userSession.token}'
        },
        body: jsonEncode({
          'puzzleId': _currentPuzzle?['puzzle_id'],
          'solved': solved,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final change = data['ratingChange'] ?? 0;
        final newRating = data['newRating'] ?? 1500;
        setState(() {
          _lastRatingChange = change;
          _userRating = newRating;
        });

        if (solved && mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                  SizedBox(width: 8),
                  Text('Zagonetka Rešena!', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text('Bravo! Tačno ste odigrali sve poteze.\nNovi rejting: $newRating (${change >= 0 ? "+" : ""}$change)'),
              actions: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Naredna Zagonetka'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _fetchNextPuzzle();
                  },
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      // quiet fail
    }
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedCategory == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectedCategory != null) {
          _resetEngineState();
          setState(() {
            _selectedCategory = null;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              if (_selectedCategory != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    _resetEngineState();
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                ),
                const SizedBox(width: 4),
              ],
              const Icon(Icons.psychology, color: Colors.amberAccent),
              const SizedBox(width: 8),
              Text(_selectedCategory == null ? 'Šahovski trener i vežbe' : _getCategoryTitle()),
            ],
          ),
        ),
        body: _buildPuzzlesTab(),
      ),
    );
  }

  String _getCategoryTitle() {
    switch (_selectedCategory) {
      case 'mate_puzzle':
        return 'Mat u 1, 2 ili 3 poteza';
      case 'basic_mate':
        return 'Vežbanje osnovnog matiranja';
      case 'winning_position':
        return 'Pronađite dobitni put';
      default:
        return 'Šahovski trener i vežbe';
    }
  }

  // --- TAB 1: PUZZLES UI ---

  Widget _buildPuzzlesTab() {
    return Column(
      children: [
        if (!_isBackendConnected)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            color: Colors.red.shade900,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.wifi_off, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text(
                  '🚨 VEZA SA SERVEROM IZGUBLJENA! Backend server je nedostupan.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
        Expanded(
          child: _selectedCategory == null
              ? _buildCategorySelectionHub()
              : _buildActiveBoardScreen(),
        ),
      ],
    );
  }

  // --- 1. SELECTION HUB VIEW ---

  Widget _buildCategorySelectionHub() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.extension, size: 28, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Šahovski trener i vežbe',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Izaberite modul za vežbanje taktičkih zagonetki ili matnih završnica.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // CARD 1: Zagonetke: Mat u 1, 2 ili 3 poteza
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.teal, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.sports_esports, color: Colors.tealAccent, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Zagonetke: Mat u 1, 2 ili 3 poteza',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Rešavajte forsiranu matnu sekvencu u traženom broju poteza.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.looks_one),
                            label: const Text('Mat u 1'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
                            onPressed: () {
                              setState(() => _selectedMateDepth = '1');
                              _launchCategory('mate_puzzle');
                            },
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.looks_two),
                            label: const Text('Mat u 2'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
                            onPressed: () {
                              setState(() => _selectedMateDepth = '2');
                              _launchCategory('mate_puzzle');
                            },
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.looks_3),
                            label: const Text('Mat u 3'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade800, foregroundColor: Colors.white),
                            onPressed: () {
                              setState(() => _selectedMateDepth = '3');
                              _launchCategory('mate_puzzle');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // CARD 2: Vežbajte osnovno matiranje
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.purpleAccent, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.workspace_premium, color: Colors.purpleAccent, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Vežbajte osnovno matiranje',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Matirajte protivnika u klasičnim matnim pozicijama protiv Stockfish-a.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.sentiment_satisfied, size: 16),
                            label: const Text('Lako'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800, foregroundColor: Colors.white),
                            onPressed: () {
                              _selectedCategory = 'basic_mate';
                              _loadBasicMatePreset('easy');
                            },
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.sentiment_neutral, size: 16),
                            label: const Text('Srednje'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800, foregroundColor: Colors.white),
                            onPressed: () {
                              _selectedCategory = 'basic_mate';
                              _loadBasicMatePreset('medium');
                            },
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.sentiment_very_dissatisfied, size: 16),
                            label: const Text('Teško'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade800, foregroundColor: Colors.white),
                            onPressed: () {
                              _selectedCategory = 'basic_mate';
                              _loadBasicMatePreset('hard');
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // CARD 3: Pronađite dobitni put
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Colors.amber, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.emoji_events, color: Colors.amberAccent, size: 28),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pronađite dobitni put',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Igrajte dobitne pozicije do kraja protiv Stockfish-a uz opcioni Blunder Alert.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Započni vežbanje dobitnih pozicija'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () => _launchCategory('winning_position'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. ACTIVE BOARD GAME SCREEN ---

  Widget _buildActiveBoardScreen() {
    final String headerGoal = _selectedCategory == 'mate_puzzle'
        ? '${_puzzleOrientation == PlayerColor.white ? "⚪ Beli" : "⚫ Crni"} na potezu - Mat u $_selectedMateDepth ${_selectedMateDepth == '1' ? 'potez' : 'poteza'}'
        : (_selectedCategory == 'basic_mate'
            ? 'Vežbanje: $_selectedBasicMateType (Matirajte Stockfish-a)'
            : '${_puzzleOrientation == PlayerColor.white ? "⚪ Beli" : "⚫ Crni"} na potezu - Pronađite dobitni put');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            children: [
              // Navigation Back Bar & Controls Card
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.arrow_back, size: 16),
                        label: const Text('Nazad na izbor', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          _resetEngineState();
                          setState(() {
                            _selectedCategory = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Chessboard Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      if (_isLoadingPuzzle)
                        const SizedBox(
                          height: 320,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        // Turn & Goal Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: _puzzleOrientation == PlayerColor.white ? Colors.blueGrey.shade900 : Colors.teal.shade900,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _puzzleOrientation == PlayerColor.white ? Colors.white38 : Colors.tealAccent),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.flag,
                                size: 18,
                                color: _puzzleOrientation == PlayerColor.white ? Colors.white : Colors.tealAccent,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  headerGoal,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildBoardWithTapAndHighlights(320.0),
                        const SizedBox(height: 6),

                        // Horizontal Evaluation Bar Widget (Visible when _showEvalBar is enabled)
                        if (_showEvalBar) ...[
                          HorizontalEvalBarWidget(
                            eval: _currentRawEval,
                            evalString: _currentEvalString,
                            depth: _currentEvalDepth,
                            orientation: _puzzleOrientation,
                          ),
                          const SizedBox(height: 8),
                        ],

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Probaj Ponovo'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
                              onPressed: _restartCurrentPuzzle,
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Naredna Pozicija'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                              onPressed: () {
                                if (_selectedCategory == 'basic_mate') {
                                  _loadBasicMatePreset(_selectedBasicMateType);
                                } else {
                                  _fetchNextPuzzle();
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Stockfish Analysis Widget ("Prikaži evaluaciju") - Hawaian/Clean UI for Mat u N
                        if (!_isOpponentTurn && _selectedCategory != 'mate_puzzle')
                          StockfishAnalysisWidget(
                            isEngineEnabled: _showEvaluation,
                            isAllowedToUseEngine: true,
                            isOnline: _stockfishService.isOnline,
                            isCustomEngineActive: _stockfishService.isCustomEngineActive,
                            lines: _engineLinesMap.values.toList(),
                            orientation: _puzzleOrientation,
                            isShowEvalBarEnabled: _showEvalBar,
                            onToggleShowEvalBar: () {
                              setState(() {
                                _showEvalBar = !_showEvalBar;
                              });
                            },
                            onToggleEngine: () {
                              setState(() {
                                _showEvaluation = !_showEvaluation;
                                if (_showEvaluation) {
                                  _stockfishService.setMultiPV(3);
                                  _stockfishService.analyzePosition(_puzzleBoardController.getFen(), depth: 20);
                                } else {
                                  _engineLinesMap.clear();
                                  _engineArrows.clear();
                                }
                              });
                            },
                          ),
                        const SizedBox(height: 12),

                        // Interactive PGN Solution Tree Widget
                        _buildPgnSolutionTreeWidget(),
                        const SizedBox(height: 12),

                        // Move History & Variation Tree Navigation Bar (MOVED TO BOTTOM)
                        _buildMoveHistoryNavigationWidget(),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoardWithTapAndHighlights(double boardSize) {
    final squareSize = boardSize / 8.0;

    return GestureDetector(
      onTapUp: (details) {
        if (_isOpponentTurn || _puzzleSolved) return;
        final localOffset = details.localPosition;
        final x = localOffset.dx;
        final y = localOffset.dy;

        if (x < 0 || y < 0 || x >= boardSize || y >= boardSize) return;

        final col = (x / squareSize).floor().clamp(0, 7);
        final row = (y / squareSize).floor().clamp(0, 7);

        String square;
        if (_puzzleOrientation == PlayerColor.white) {
          final file = String.fromCharCode('a'.codeUnitAt(0) + col);
          final rank = 8 - row;
          square = '$file$rank';
        } else {
          final file = String.fromCharCode('h'.codeUnitAt(0) - col);
          final rank = 1 + row;
          square = '$file$rank';
        }

        _handleSquareTap(square);
      },
      child: Stack(
        children: [
          IgnorePointer(
            ignoring: _isOpponentTurn || _puzzleSolved || _puzzleFailed || _gameState != PuzzleGameState.idle,
            child: ChessBoard(
              controller: _puzzleBoardController,
              boardOrientation: _puzzleOrientation,
              onMove: () {
                _selectedSquare = null;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _onUserPuzzleMoveMade();
                });
              },
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: ChessBoardPainter(
                  arrows: (_showEvaluation && _selectedCategory != 'mate_puzzle') ? _engineArrows : [],
                  engineArrows: (_showEvaluation && _selectedCategory != 'mate_puzzle') ? _buildEngineArrowsFromLines(_engineLinesMap.values.toList()) : [],
                  boardSize: boardSize,
                  orientation: _puzzleOrientation,
                  lastMoveFrom: _lastMoveFrom,
                  lastMoveTo: _lastMoveTo,
                ),
              ),
            ),
          ),
          if (_selectedSquare != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: SelectedSquarePainter(
                    selectedSquare: _selectedSquare!,
                    boardSize: boardSize,
                    orientation: _puzzleOrientation,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoveHistoryNavigationWidget() {
    if (_puzzleMoveTree == null) return const SizedBox.shrink();

    final currentNode = _puzzleMoveTree!.current;
    final mainLineNodes = <MoveNode>[];
    MoveNode? curr = currentNode;
    while (curr != null && curr.parent != null) {
      mainLineNodes.insert(0, curr);
      curr = curr.parent;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade900.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.flag, size: 14, color: Colors.amberAccent),
                  label: const Text('Početak', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  backgroundColor: currentNode == _puzzleMoveTree!.root ? Colors.amber.shade900 : Colors.blueGrey.shade800,
                  onPressed: () => _navigateToNode(_puzzleMoveTree!.root),
                ),
                const SizedBox(width: 6),
                ...mainLineNodes.map((node) {
                  final isCurrent = (node == currentNode);
                  final labelText = _formatMoveWithNumber(node, _puzzleMoveTree!.root);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: ChoiceChip(
                      label: Text(labelText, style: TextStyle(fontSize: 11, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isCurrent ? Colors.white : Colors.white70)),
                      selected: isCurrent,
                      selectedColor: Colors.teal.shade700,
                      backgroundColor: Colors.blueGrey.shade800,
                      onSelected: (_) => _navigateToNode(node),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page, size: 20),
                tooltip: 'Početna pozicija',
                onPressed: () => _navigateToNode(_puzzleMoveTree!.root),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: 'Prethodni potez',
                onPressed: currentNode.parent != null ? () => _navigateToNode(currentNode.parent!) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'Naredni potez',
                onPressed: currentNode.children.isNotEmpty ? () => _navigateToNode(currentNode.children.first) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page, size: 20),
                tooltip: 'Poslednji potez',
                onPressed: () {
                  MoveNode target = currentNode;
                  while (target.children.isNotEmpty) {
                    target = target.children.first;
                  }
                  _navigateToNode(target);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatMoveWithNumber(MoveNode node, MoveNode rootNode) {
    if (node.parent == null) return 'Početak';

    final path = <MoveNode>[];
    MoveNode? curr = node;
    while (curr != null && curr.parent != null) {
      path.insert(0, curr);
      curr = curr.parent;
    }

    final rootFen = rootNode.fen;
    final rootParts = rootFen.split(' ');
    final rootIsWhite = rootParts.length > 1 ? (rootParts[1] == 'w') : true;
    final rootMoveNum = rootParts.length > 5 ? (int.tryParse(rootParts[5]) ?? 1) : 1;

    final moveIndex = path.indexOf(node);
    if (moveIndex < 0) return node.san;

    int currentMoveNum;
    bool isWhiteMove;

    if (rootIsWhite) {
      currentMoveNum = rootMoveNum + (moveIndex ~/ 2);
      isWhiteMove = (moveIndex % 2 == 0);
    } else {
      currentMoveNum = rootMoveNum + ((moveIndex + 1) ~/ 2);
      isWhiteMove = (moveIndex % 2 == 1);
    }

    if (isWhiteMove) {
      return '$currentMoveNum. ${node.san}';
    } else {
      if (moveIndex == 0 && !rootIsWhite) {
        return '$currentMoveNum... ${node.san}';
      } else {
        return node.san;
      }
    }
  }

  void _navigateToNode(MoveNode node) {
    if (_puzzleGame == null || _puzzleMoveTree == null) return;
    _puzzleMoveTree!.current = node;
    _puzzleGame = chess.Chess.fromFEN(node.fen);
    _puzzleBoardController.loadFen(node.fen);
    _activeFen = node.fen;
    setState(() {
      _selectedSquare = null;
      _puzzleFailed = false;
    });
    if (_showEvaluation) {
      _stockfishService.analyzePosition(node.fen, depth: 20);
    }
  }

  Widget _buildPgnSolutionTreeWidget() {
    if (_currentPuzzle == null || _currentPuzzle!['solutions'] == null) {
      return const SizedBox.shrink();
    }
    final solutions = Map<String, dynamic>.from(_currentPuzzle!['solutions'] ?? {});
    if (solutions.isEmpty) return const SizedBox.shrink();

    final List<Widget> chips = _buildPgnChipsFromSolutions(solutions);
    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade700, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.account_tree, color: Colors.tealAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Stablo Rešenja (PGN):',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPgnChipsFromSolutions(Map<String, dynamic> solutions) {
    final List<Widget> chips = [];
    if (_initialPuzzleFen == null) return chips;

    final tempBoard = chess.Chess.fromFEN(_initialPuzzleFen!);
    final fenParts = _initialPuzzleFen!.split(' ');
    int moveNum = fenParts.length > 5 ? (int.tryParse(fenParts[5]) ?? 1) : 1;
    bool isWhiteToMove = (tempBoard.turn == chess.Color.WHITE);

    void traverseNode(Map<String, dynamic> node, int num, bool isWhite, String prefix) {
      for (var uciMove in node.keys) {
        if (uciMove.length < 4) continue;
        final from = uciMove.substring(0, 2);
        final to = uciMove.substring(2, 4);
        final promo = uciMove.length > 4 ? uciMove[4] : null;

        final bool moveOk = tempBoard.move({'from': from, 'to': to, 'promotion': promo});
        String sanStr = uciMove;
        if (moveOk && tempBoard.history.isNotEmpty) {
          try {
            final dynamic lastHist = tempBoard.history.last;
            sanStr = lastHist.san ?? uciMove;
          } catch (_) {
            sanStr = uciMove;
          }
        }

        final targetFen = tempBoard.fen;
        final String labelStr = isWhite ? '$num. $sanStr' : '$num... $sanStr';
        final bool isCurrentPos = (_activeFen == targetFen);

        chips.add(
          InkWell(
            onTap: () {
              _sendBackendLog({
                'type': 'pgnChipClick',
                'moveSan': labelStr,
                'targetFen': targetFen,
              });
              setState(() {
                _puzzleGame = chess.Chess.fromFEN(targetFen);
                _puzzleBoardController.loadFen(targetFen);
                _activeFen = targetFen;
                _lastMoveFrom = from;
                _lastMoveTo = to;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCurrentPos ? Colors.amber.shade700 : Colors.teal.shade900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCurrentPos ? Colors.amberAccent : Colors.tealAccent.withOpacity(0.5),
                  width: isCurrentPos ? 2 : 1,
                ),
              ),
              child: Text(
                labelStr,
                style: TextStyle(
                  color: isCurrentPos ? Colors.white : Colors.tealAccent,
                  fontWeight: isCurrentPos ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        );

        final subVal = node[uciMove];
        if (subVal is Map && subVal.isNotEmpty) {
          final nextMap = Map<String, dynamic>.from(subVal);
          final nextIsWhite = !isWhite;
          final nextNum = nextIsWhite ? num + 1 : num;
          traverseNode(nextMap, nextNum, nextIsWhite, prefix);
        }

        tempBoard.undo();
      }
    }

    traverseNode(solutions, moveNum, isWhiteToMove, '');
    return chips;
  }
}

class SelectedSquarePainter extends CustomPainter {
  final String selectedSquare;
  final double boardSize;
  final PlayerColor orientation;

  SelectedSquarePainter({
    required this.selectedSquare,
    required this.boardSize,
    required this.orientation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selectedSquare.isEmpty) return;
    final squareSize = boardSize / 8.0;

    final file = selectedSquare[0];
    final rank = int.parse(selectedSquare[1]);

    int col, row;
    if (orientation == PlayerColor.white) {
      col = file.codeUnitAt(0) - 'a'.codeUnitAt(0);
      row = 8 - rank;
    } else {
      col = 'h'.codeUnitAt(0) - file.codeUnitAt(0);
      row = rank - 1;
    }

    final rect = Rect.fromLTWH(col * squareSize, row * squareSize, squareSize, squareSize);
    final borderPaint = Paint()
      ..color = Colors.amberAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
    canvas.drawRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant SelectedSquarePainter oldDelegate) {
    return oldDelegate.selectedSquare != selectedSquare ||
        oldDelegate.boardSize != boardSize ||
        oldDelegate.orientation != orientation;
  }
}

class HorizontalEvalBarWidget extends StatelessWidget {
  final double eval;
  final String evalString;
  final int depth;
  final PlayerColor orientation;

  const HorizontalEvalBarWidget({
    super.key,
    required this.eval,
    required this.evalString,
    required this.depth,
    required this.orientation,
  });

  @override
  Widget build(BuildContext context) {
    final double winPct = (eval.clamp(-10.0, 10.0) + 10.0) / 20.0;
    final String displayEvalText = evalString;

    return Container(
      height: 20,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  flex: (winPct * 1000).round(),
                  child: Container(color: Colors.grey.shade100),
                ),
                Expanded(
                  flex: ((1.0 - winPct) * 1000).round(),
                  child: Container(color: Colors.grey.shade900),
                ),
              ],
            ),
            Center(
              child: Stack(
                children: [
                  Text(
                    displayEvalText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 2.5
                        ..color = Colors.black,
                    ),
                  ),
                  Text(
                    displayEvalText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.amberAccent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
