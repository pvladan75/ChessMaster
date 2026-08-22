import 'package:chess_app/services/puzzle_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_app/widgets/board_flip_button.dart';
import 'package:chess_app/widgets/ai_studio/category_selection_hub.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart';
import 'package:chess_app/widgets/ai_studio/solution_tree_models.dart';
import 'package:chess_app/widgets/ai_studio/solution_graph_widget.dart';
import 'package:chess_app/widgets/ai_studio/pgn_solution_tree_widget.dart';
import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
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
import 'package:chess_app/widgets/engine_settings_dialog.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:go_router/go_router.dart';

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

class AiStudioScreen extends ConsumerStatefulWidget {
  final UserSession userSession;

  const AiStudioScreen({super.key, required this.userSession});

  @override
  ConsumerState<AiStudioScreen> createState() => _AiStudioScreenState();
}

class _AiStudioScreenState extends ConsumerState<AiStudioScreen> {
  final ChessBoardController _puzzleBoardController = ChessBoardController();

  final StockfishService _stockfishService = StockfishService();

  Future<void> _openEngineSettings() async {
    await showEngineSettingsDialog(
      context,
      stockfishService: _stockfishService,
      isEngineEnabled: _showEvaluation || _showEvalBar,
    );
    if (mounted) setState(() {});
  }

  /// Interrupts whatever the engine is doing and restarts a fresh evaluation
  /// of the current board position using the configured depth/MultiPV.
  void _restartEngineEvaluation() {
    _stockfishService.stopAnalysis();
    _stockfishService.setMultiPV(AppSettingsService.instance.defaultMultiPV);
    final targetDepth = AppSettingsService.instance.defaultEngineDepth;
    setState(() {
      _engineLinesMap.clear();
      _engineArrows.clear();
    });
    _stockfishService.analyzePosition(_puzzleBoardController.getFen(), depth: targetDepth);
  }

  // Engine Analysis State
  final bool _isEngineEnabled = false;
  Map<int, AnalysisLine> _engineLinesMap = {};
  List<ChessArrow> _engineArrows = [];

  // Reorganization Category State
  String? _selectedCategory; // null = Selection Hub, 'mate_puzzle', 'basic_mate', 'winning_position'
  String _selectedMateDepth = '2'; // '1', '2', '3'
  String _selectedBasicMateType = 'easy'; // 'easy', 'medium', 'hard'
  final Map<String, int> _selectedGroupedMoveIndices = {};

  // Board & Game State
  String? _activeFen;
  bool _showEvaluation = false;
  bool _showEvalBar = false; // Default OFF
  double _currentRawEval = 0.0;
  String _currentEvalString = '0.00';
  int _currentEvalDepth = AppSettingsService.instance.defaultEngineDepth;
  double? _lastPosEval;
  double? _lastUserAdvantage;

  Map<String, dynamic>? _currentPuzzle;
  Map<String, dynamic> _rootSolutionsTree = {};
  Map<String, dynamic>? _currentSolutionsNode;
  final List<VariationBranchPoint> _activeBranchPoints = [];
  bool _isReplayingSolution = false;
  bool _showSolutionTree = false;
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
  Timer? _opponentMoveTimer;
  String? _latestEngineBestMove;
  String? _latestEngineEval;
  int _positionToken = 0;
  PlayerColor _puzzleOrientation = PlayerColor.white;
  bool _isProgrammaticMove = false;
  String? _lastMoveFrom;
  String? _lastMoveTo;
  String? _selectedSquare;
  // A list rather than a single nullable slot: two moves made back-to-back
  // faster than the animation duration would otherwise have the second
  // move's trigger tear down the first's AnimatedMovePiece mid-flight, so
  // the piece snaps into place instead of visibly sliding there.
  final List<PendingMoveAnimation> _pendingAnimations = [];
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
    // Settings is reached through a shared shell here (no local push/pop to
    // hang a setState off), so listen directly for live updates like the
    // move-input-mode toggle.
    AppSettingsService.instance.addListener(_onAppSettingsChanged);
  }

  void _onAppSettingsChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _startServerHealthCheck() {
    final bindingStr = WidgetsBinding.instance.runtimeType.toString();
    if (bindingStr.contains('Test') || bindingStr.contains('test')) return;
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
      print('[HEALTH_CHECK_LOG] ℹ️ Backend server is offline or unreachable. Switching silently to offline mode.');
      setState(() => _isBackendConnected = false);
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
    _currentEvalDepth = AppSettingsService.instance.defaultEngineDepth;

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
      _showSolutionTree = false;
      _selectedGroupedMoveIndices.clear();
      _stockfishService.setMultiPV(AppSettingsService.instance.defaultMultiPV);
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
      if (_selectedCategory == 'mate_puzzle') return;

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

      // Build top 1-5 engine arrows for display matching user MultiPV setting
      final List<ChessArrow> newArrows = [];
      final maxArrows = AppSettingsService.instance.defaultMultiPV;
      final colors = ['G', 'B', 'O', 'P', 'R'];
      int colorIdx = 0;
      for (var line in _engineLinesMap.values) {
        if (colorIdx >= maxArrows) break;
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
        if (multipv == 1 && bestMove.isNotEmpty && bestMove != '-' && bestMove.length >= 4) {
          _latestEngineBestMove = bestMove;
          _latestEngineEval = evaluation;
          final targetDepth = AppSettingsService.instance.defaultEngineDepth;
          if (depth >= targetDepth || isFinal) {
            _executeOpponentEngineMoveDueToTimeoutOrDepth('Zadata dubina dostignuta ($depth >= $targetDepth)');
          }
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

    // Register with the shared engine's subscriber stack. Without this, pushing
    // the Analysis Studio and popping back would leave this screen's callbacks
    // cleared and the engine silently dead.
    _stockfishService.attach(
      this,
      onEvaluation: _stockfishService.onEvaluationChanged,
      onMultiPV: _stockfishService.onMultiPVUpdated,
    );
  }

  void _executeOpponentEngineMoveDueToTimeoutOrDepth(String reason) {
    if (!_isOpponentTurn) return;
    _opponentMoveTimer?.cancel();
    _isOpponentTurn = false;

    final move = _latestEngineBestMove ?? (_engineLinesMap.isNotEmpty ? _engineLinesMap.values.first.bestMoveLan : '');
    final eval = _latestEngineEval ?? (_engineLinesMap.isNotEmpty ? _engineLinesMap.values.first.evaluation : '0.00');

    if (move.isNotEmpty && move != '-' && move.length >= 4) {
      print('\n[ENGINE_MOVE_TRIGGER] ⚡ Odigravanje poteza engine-a: $reason! Odabran potez: $move (Eval: $eval)\n');
      _stockfishService.stopAnalysis();
      _playOpponentMove(move, eval);
    }
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
          if (_selectedCategory != 'mate_puzzle' && (_showEvaluation || _showEvalBar)) {
            _selectedGroupedMoveIndices.clear();
      _stockfishService.setMultiPV(AppSettingsService.instance.defaultMultiPV);
            _stockfishService.analyzePosition(_puzzleGame!.fen, depth: AppSettingsService.instance.defaultEngineDepth);
          }
        }
      }
    });
  }

  void _triggerOpponentBotResponse() async {
    if (_selectedCategory == 'mate_puzzle') return;
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

    _opponentMoveTimer?.cancel();
    _latestEngineBestMove = null;
    _latestEngineEval = null;
    final moveTimeSec = AppSettingsService.instance.defaultEngineMoveTimeSeconds;
    _opponentMoveTimer = Timer(Duration(seconds: moveTimeSec), () {
      if (_isOpponentTurn && mounted) {
        _executeOpponentEngineMoveDueToTimeoutOrDepth('Vreme razmišljanja isteka ($moveTimeSec s)');
      }
    });

    await _stockfishService.initEngine();
    _stockfishService.setMultiPV(AppSettingsService.instance.defaultMultiPV);
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

    final maxArrows = AppSettingsService.instance.defaultMultiPV;
    final colors = ['G', 'B', 'O', 'P', 'R'];
    for (int i = 0; i < lines.length && i < maxArrows; i++) {
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
    _serverHealthTimer?.cancel();
    _verificationTimeoutTimer?.cancel();
    AppSettingsService.instance.removeListener(_onAppSettingsChanged);
    _stockfishService.detach(this);
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

        _stockfishService.analyzePosition(fen, depth: AppSettingsService.instance.defaultEngineDepth);
      }
    } catch (e) {
      print('Error loading basic mate preset $difficulty: $e');
    }
  }

  Future<void> _fetchNextPuzzle() async {
    _resetEngineState();
    final String currentId = _currentPuzzle?['puzzle_id'] ?? _currentPuzzle?['id'] ?? '';
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
      final resData = await PuzzleApiService.instance.fetchNextPuzzle(
        type: categoryParam,
        mateDepth: _selectedMateDepth.toString(),
        excludeId: currentId,
        userToken: widget.userSession.token,
      );

      if (resData != null) {
        final p = resData['puzzle'] ?? resData;
        final fen = p['fen'];
        final moves = List<String>.from(p['moves'] ?? []);

        _puzzleGame = chess.Chess.fromFEN(fen);
        _activeFen = fen;
        _initialPuzzleFen = fen;
        _puzzleMoveTree = MoveTree(startingFen: fen);

        setState(() {
          _currentPuzzle = p;
          _userRating = resData['userRating'] ?? 1500;
          _expectedMoves = moves;
          _moveIndex = 0;
          _rootSolutionsTree = Map<String, dynamic>.from(p['solutions'] ?? {});
          _currentSolutionsNode = Map<String, dynamic>.from(_rootSolutionsTree);
          _activeBranchPoints.clear();
          _isReplayingSolution = false;
          _showSolutionTree = false;
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
          _stockfishService.analyzePosition(fen, depth: AppSettingsService.instance.defaultEngineDepth);
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

  void _recordMoveInTree(String from, String to, {String san = ''}) {
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

    if (_selectedCategory != 'mate_puzzle' && (_showEvaluation || _showEvalBar)) {
      _selectedGroupedMoveIndices.clear();
      _stockfishService.setMultiPV(AppSettingsService.instance.defaultMultiPV);
      _stockfishService.analyzePosition(_initialPuzzleFen!, depth: AppSettingsService.instance.defaultEngineDepth);
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

      setState(() {
        _selectedSquare = null;
      });

      final testGame = chess.Chess.fromFEN(_puzzleGame!.fen);
      final moveRes = testGame.move({'from': from, 'to': to, 'promotion': 'q'});

      if (moveRes) {
        // Must stay null for a non-promoting move: _onUserPuzzleMoveMade
        // matches candidates by requiring promo == manualPromo exactly, and
        // an ordinary move's candidate has promo == '' — passing 'q'
        // unconditionally here made every non-promotion tap-move silently
        // fail to match (no candidate has 'q' when none is a promotion).
        String? promoPiece;
        final promoMoves = _puzzleGame!.moves({'verbose': true}).where(
          (m) => m['from'] == from && m['to'] == to && m['promotion'] != null && m['promotion'].toString().isNotEmpty,
        );

        if (promoMoves.isNotEmpty) {
          promoPiece = 'q';
          _currentSolutionsNode ??= Map<String, dynamic>.from(_currentPuzzle?['solutions'] ?? {});
          if (_currentSolutionsNode != null) {
            for (var pm in promoMoves) {
              final candUci = '$from$to${pm['promotion']}';
              if (_currentSolutionsNode!.containsKey(candUci)) {
                promoPiece = pm['promotion'].toString();
                break;
              }
            }
          }
        }

        final movingPiece = _puzzleGame!.get(from);
        if (movingPiece != null) _triggerMoveAnimation(from, to, movingPiece);
        _onUserPuzzleMoveMade(manualFrom: from, manualTo: to, manualPromo: promoPiece);
      }
    }
  }

  void _triggerMoveAnimation(String from, String to, chess.Piece movingPiece) {
    final durationMs = AppSettingsService.instance.moveAnimationDurationMs;
    if (durationMs <= 0) return;
    setState(() {
      _pendingAnimations.add(PendingMoveAnimation(from: from, to: to, piece: movingPiece));
    });
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
        final animatedPiece = _puzzleGame!.get(toStr);
        if (animatedPiece != null) _triggerMoveAnimation(fromStr, toStr, animatedPiece);
        _puzzleBoardController.loadFen(_puzzleGame!.fen);
        _activeFen = _puzzleGame!.fen;
        _recordMoveInTree(fromStr, toStr, san: san);
      } else {
        _puzzleBoardController.makeMove(from: fromStr, to: toStr);
        final animatedPiece = _puzzleBoardController.game.get(toStr);
        if (animatedPiece != null) _triggerMoveAnimation(fromStr, toStr, animatedPiece);
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

  Future<void> _onUserPuzzleMoveMade({String? manualFrom, String? manualTo, String? manualPromo}) async {
    if (_isOpponentTurn || _puzzleGame == null || _isVerifyingUserMove || _puzzleSolved) return;
    _isVerifyingUserMove = true;
    setState(() {
      _gameState = PuzzleGameState.verifyingMove;
    });

    final currentFen = _puzzleBoardController.getFen();
    final String startingFen = _puzzleGame!.fen;
    final allLegalMoves = _puzzleGame!.moves({'verbose': true});

    String? userLan;
    dynamic matchedMove;

    if (manualFrom != null && manualTo != null) {
      for (var m in allLegalMoves) {
        if (m['from'] == manualFrom && m['to'] == manualTo) {
          final promo = m['promotion']?.toString() ?? '';
          if (manualPromo != null && manualPromo.isNotEmpty) {
            if (promo == manualPromo) {
              matchedMove = m;
              userLan = '$manualFrom$manualTo$manualPromo';
              break;
            }
          } else {
            matchedMove = m;
            userLan = '$manualFrom$manualTo$promo';
            break;
          }
        }
      }
    }

    if (matchedMove == null) {
      if (currentFen == _puzzleGame!.fen) {
        print('[MOVE_MADE_DEBUG] FENs are identical, no move detected yet.');
        _isVerifyingUserMove = false;
        setState(() => _gameState = PuzzleGameState.idle);
        return;
      }

      final currentBoardFen = currentFen.split(' ')[0];

      for (var m in allLegalMoves) {
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

      // Promotion handling refinement:
      if (matchedMove != null && matchedMove['promotion'] != null && matchedMove['promotion'].toString().isNotEmpty) {
        final from = matchedMove['from'] ?? '';
        final to = matchedMove['to'] ?? '';
        _currentSolutionsNode ??= Map<String, dynamic>.from(_currentPuzzle?['solutions'] ?? {});

        if (_currentSolutionsNode != null) {
          for (var candidate in allLegalMoves) {
            final cFrom = candidate['from'] ?? '';
            final cTo = candidate['to'] ?? '';
            final cPromo = candidate['promotion'] ?? '';
            if (cFrom == from && cTo == to && cPromo.toString().isNotEmpty) {
              final candUci = '$cFrom$cTo$cPromo';
              if (_currentSolutionsNode!.containsKey(candUci)) {
                matchedMove = candidate;
                userLan = candUci;
                print('[MOVE_MADE_DEBUG] 🎯 Solution tree expects promotion move: $userLan');
                break;
              }
            }
          }
        }
      }
    }

    if (matchedMove == null || userLan == null) {
      print('[MOVE_MADE_DEBUG] Could not match move in chess.js legal moves!');
      _isVerifyingUserMove = false;
      setState(() => _gameState = PuzzleGameState.idle);
      return;
    }

    _puzzleGame!.move(matchedMove);
    _activeFen = _puzzleGame!.fen;
    _puzzleBoardController.loadFen(_puzzleGame!.fen);

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

    // --- STEP 0: IMMEDIATE CHECKMATE VICTORY ON BOARD (FOR BASIC MATES & WINNING POSITIONS) ---
    if (_puzzleGame!.in_checkmate && _selectedCategory != 'mate_puzzle') {
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
      // Case-insensitive fallback for promotion moves (e.g. h7h8q vs h7h8Q)
      if (subBranch == null) {
        final lower = userLan.toLowerCase();
        for (var k in _currentSolutionsNode!.keys) {
          if (k.toString().toLowerCase() == lower) {
            subBranch = _currentSolutionsNode![k];
            userLan = k.toString();
            break;
          }
        }
      }

      // Fallback for single-move puzzles (Mate in 1) or when position is in checkmate
      if (subBranch == null && primaryJsonMove.isNotEmpty && userLan == primaryJsonMove) {
        final reqN = int.tryParse(_selectedMateDepth) ?? 1;
        if (reqN == 1 || _puzzleGame!.in_checkmate) {
          subBranch = "CHECKMATE";
        }
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
          'validTreeKeys': _currentSolutionsNode?.keys.join(', '),
          'subBranch': subBranch == "CHECKMATE" ? "CHECKMATE (Matni kraj)" : (subBranch is Map ? "Grana sa odgovora: ${subBranch.keys.join(', ')}" : subBranch.toString()),
        });

        final bool isTerminalCheckmate = (subBranch == "CHECKMATE" || _puzzleGame!.in_checkmate);

        if (isTerminalCheckmate || (subBranch is Map && subBranch.isEmpty)) {
          // DEDUPLICATION: Clean up any pending opponent moves in active branch points that are ALSO satisfied by userLan!
          if (userLan != null) {
            final String lowerUserLan = userLan.toLowerCase();
            for (var bp in _activeBranchPoints) {
              bp.pendingOpponentMoves.removeWhere((pendingOppMove) {
                final subForPending = bp.oppBranchMap[pendingOppMove];
                if (subForPending == "CHECKMATE") return true;
                if (subForPending is Map) {
                  final Map subMap = subForPending;
                  for (var k in subMap.keys) {
                    if (k.toString().toLowerCase() == lowerUserLan) {
                      return true; // This pending opponent branch is ALSO satisfied by userLan!
                    }
                  }
                }
                return false;
              });
            }
          }

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
            
            _sendBackendLog({
              'type': 'branchReset',
              'mode': _categoryDisplayName,
              'nextOpponentMove': nextOppMove,
              'remainingBranches': pendingBP.pendingOpponentMoves.length,
            });

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
                final animatedPiece = _puzzleGame!.get(oppTo);
                if (animatedPiece != null) _triggerMoveAnimation(oppFrom, oppTo, animatedPiece);
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
          final Map<String, dynamic> oppTree = Map<String, dynamic>.from(subBranch);
          
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
              final uniqueOppKeys = _getUniqueOpponentRepresentativeMoves(oppTree);
              oppMoveLan = uniqueOppKeys.first;
              final pendingKeys = uniqueOppKeys.sublist(1);

              _activeBranchPoints.add(VariationBranchPoint(
                fenPostUserMove: _puzzleGame!.fen,
                userMoveUci: userLan!,
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
              if (moveObj) {
                final animatedPiece = _puzzleGame!.get(oppTo);
                if (animatedPiece != null) _triggerMoveAnimation(oppFrom, oppTo, animatedPiece);
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
          'validTreeKeys': _currentSolutionsNode?.keys.join(', '),
          'reason': 'Potez nije u ugnježđenom stablu rešenja zagonetke',
        });
        _showFailureDialog();
        return;
      }
    }

    if (_selectedCategory == 'mate_puzzle') return;
    _triggerOpponentBotResponse();
  }

  List<String> _getUniqueOpponentRepresentativeMoves(Map<String, dynamic> oppBranchMap) {
    final List<String> uniqueOpponentMoves = [];
    final Set<String> seenUserSignatures = {};

    for (var oppMove in oppBranchMap.keys) {
      final oppSub = oppBranchMap[oppMove];
      String moveSignature = '';
      if (oppSub is Map) {
        moveSignature = oppSub.keys.join(',');
      } else if (oppSub is List) {
        moveSignature = oppSub.join(',');
      } else if (oppSub is String) {
        moveSignature = oppSub.toString();
      }

      if (!seenUserSignatures.contains(moveSignature)) {
        seenUserSignatures.add(moveSignature);
        uniqueOpponentMoves.add(oppMove.toString());
      }
    }

    return uniqueOpponentMoves.isNotEmpty ? uniqueOpponentMoves : oppBranchMap.keys.map((k) => k.toString()).toList();
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).padding.bottom;
        final isLandscape = MediaQuery.of(ctx).orientation == Orientation.landscape;
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 16,
              bottom: bottomPadding + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel_outlined, color: Colors.redAccent, size: isLandscape ? 36 : 48),
                  const SizedBox(height: 8),
                  const Text(
                    'Netačan Potez!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Potez koji ste odigrali nije u stablu rešenja. Izaberite opciju:',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
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
            ),
          ),
        );
      },
    );
  }

  void _undoIncorrectUserMove() {
    _stockfishService.stopAnalysis();
    if (_currentPuzzle != null && _currentPuzzle!['solutions'] != null) {
      _rootSolutionsTree = Map<String, dynamic>.from(_currentPuzzle!['solutions']);
      _currentSolutionsNode = Map<String, dynamic>.from(_rootSolutionsTree);
    }
    _activeBranchPoints.clear();

    if (_selectedCategory == 'mate_puzzle') {
      _resetCurrentPuzzle();
      return;
    }
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
    setState(() {
      _isReplayingSolution = true;
      _showSolutionTree = true;
    });

    _puzzleGame = chess.Chess.fromFEN(_initialPuzzleFen!);
    _puzzleBoardController.loadFen(_initialPuzzleFen!);
    _activeFen = _initialPuzzleFen!;
    if (_currentPuzzle != null && _currentPuzzle!['solutions'] != null) {
      _rootSolutionsTree = Map<String, dynamic>.from(_currentPuzzle!['solutions']);
      _currentSolutionsNode = Map<String, dynamic>.from(_rootSolutionsTree);
    }
    _activeBranchPoints.clear();

    Map<String, dynamic> current = Map<String, dynamic>.from(_rootSolutionsTree);

    while (current.isNotEmpty) {
      final userMove = current.keys.first;
      final from = userMove.substring(0, 2);
      final to = userMove.substring(2, 4);
      final promo = userMove.length > 4 ? userMove[4] : null;

      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      _puzzleGame!.move({'from': from, 'to': to, 'promotion': promo});
      final replayPiece = _puzzleGame!.get(to);
      if (replayPiece != null) _triggerMoveAnimation(from, to, replayPiece);
      _puzzleBoardController.loadFen(_puzzleGame!.fen);
      _activeFen = _puzzleGame!.fen;
      setState(() {
        _lastMoveFrom = from;
        _lastMoveTo = to;
      });

      final oppBranch = current[userMove];
      if (oppBranch is Map && oppBranch.isNotEmpty) {
        final oppMove = oppBranch.keys.first.toString();
        final oppFrom = oppMove.substring(0, 2);
        final oppTo = oppMove.substring(2, 4);
        final oppPromo = oppMove.length > 4 ? oppMove[4] : null;

        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;

        _puzzleGame!.move({'from': oppFrom, 'to': oppTo, 'promotion': oppPromo});
        final replayOppPiece = _puzzleGame!.get(oppTo);
        if (replayOppPiece != null) _triggerMoveAnimation(oppFrom, oppTo, replayOppPiece);
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
      _currentSolutionsNode = Map<String, dynamic>.from(_rootSolutionsTree);
      _activeBranchPoints.clear();
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

    _rootSolutionsTree = Map<String, dynamic>.from(_currentPuzzle!['solutions'] ?? {});
    _currentSolutionsNode = Map<String, dynamic>.from(_rootSolutionsTree);
    _activeBranchPoints.clear();

    final sideToMove = fen.split(' ')[1];
    setState(() {
      _puzzleSolved = false;
      _puzzleFailed = false;
      _expectedMoves = moves;
      _moveIndex = 0;
      _userMoveCount = 0;
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _isOpponentTurn = false;
      _isVerifyingUserMove = false;
      _gameState = PuzzleGameState.idle;
      _puzzleOrientation = (sideToMove == 'b') ? PlayerColor.black : PlayerColor.white;
    });

    _puzzleBoardController.loadFen(fen);
    if (_selectedCategory != 'mate_puzzle' && (_showEvaluation || _showEvalBar)) {
      _stockfishService.analyzePosition(fen, depth: AppSettingsService.instance.defaultEngineDepth);
    }
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
                OutlinedButton.icon(
                  icon: const Icon(Icons.account_tree_outlined, color: Colors.tealAccent, size: 18),
                  label: const Text('Prikaži Rešenje', style: TextStyle(color: Colors.tealAccent, fontSize: 13)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _showSolutionTree = true;
                    });
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Naredna Zagonetka', style: TextStyle(fontSize: 13)),
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

  void _exportToAnalysisStudio() {
    final currentFen = _puzzleBoardController.getFen();
    context.push(AppRoutes.analysisPath(fen: currentFen));
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// The board defaults to the solver's side each time a new puzzle loads
  /// (see the `_puzzleOrientation = turnIsWhite ? ... ` assignments), but
  /// the user should still be able to flip it manually — e.g. to study the
  /// position from the opponent's perspective — without that being undone
  /// until the next puzzle.
  void _toggleOrientation() {
    setState(() {
      _puzzleOrientation = _puzzleOrientation == PlayerColor.white ? PlayerColor.black : PlayerColor.white;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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
        appBar: isLandscape
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(38.0),
                child: AppBar(
                  toolbarHeight: 38.0,
                  title: Row(
                    children: [
                      if (_selectedCategory != null) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back, size: 18),
                          padding: EdgeInsets.zero,
                          // The 38px toolbar has just enough room for a tap
                          // target a bit past the bare 18px icon — better
                          // than nothing, though still short of the 48dp
                          // Material guideline (no room for that here).
                          constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                          onPressed: () {
                            _resetEngineState();
                            setState(() {
                              _selectedCategory = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Icon(Icons.psychology, color: Colors.amberAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _selectedCategory == null ? 'Šahovski trener i vežbe' : _getCategoryTitle(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
        body: SafeArea(child: _buildPuzzlesTab()),
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
    return _selectedCategory == null
        ? _buildCategorySelectionHub()
        : _buildActiveBoardScreen();
  }

  // --- 1. SELECTION HUB VIEW ---

  Widget _buildCategorySelectionHub() {
    return CategorySelectionHubWidget(
      onSelectMatePuzzle: (depth) {
        setState(() => _selectedMateDepth = depth);
        _launchCategory('mate_puzzle');
      },
      onSelectBasicMate: (presetDifficulty) {
        _selectedCategory = 'basic_mate';
        _loadBasicMatePreset(presetDifficulty);
      },
      onSelectWinningPosition: () => _launchCategory('winning_position'),
      onSelectTactics: () => context.push(AppRoutes.tactics),
      onSelectEndgameWin: () => context.push('${AppRoutes.endgames}?mode=win'),
      onSelectEndgameDraw: () => context.push('${AppRoutes.endgames}?mode=draw'),
    );
  }

  // --- 2. ACTIVE BOARD GAME SCREEN ---

  Widget _buildActiveBoardScreen() {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final String headerGoal = _selectedCategory == 'mate_puzzle'
        ? '${_puzzleOrientation == PlayerColor.white ? "⚪ Beli" : "⚫ Crni"} na potezu - Mat u $_selectedMateDepth ${_selectedMateDepth == '1' ? 'potez' : 'poteza'}'
        : (_selectedCategory == 'basic_mate'
            ? 'Vežbanje: $_selectedBasicMateType (Matirajte Stockfish-a)'
            : '${_puzzleOrientation == PlayerColor.white ? "⚪ Beli" : "⚫ Crni"} na potezu - Pronađite dobitni put');

    final backButtonCard = Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
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
            BoardFlipButton(size: 20, onPressed: _toggleOrientation),
          ],
        ),
      ),
    );

    final goalBanner = Container(
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
    );

    final actionButtonsRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.biotech, size: 16),
          label: const Text('Analiza 🔬'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade800, foregroundColor: Colors.white),
          onPressed: _exportToAnalysisStudio,
        ),
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
    );

    if (isLandscape) {
      // STRICT 1:1 SQUARE LANDSCAPE LAYOUT with SafeArea & 3-side margins (Left, Top, Bottom)
      final padding = MediaQuery.of(context).padding;
      final double safeHeight = screenSize.height - padding.top - padding.bottom;
      final double availableVerticalHeight = safeHeight - (28.0 + (_showEvalBar ? 20.0 : 0.0));
      final double boardSize = math.max(160.0, availableVerticalHeight - 16.0) * AppSettingsService.instance.boardSizeScale;

      final landscapeTopHeader = SizedBox(
        height: 24,
        child: Row(
          children: [
            // Landscape hides the AppBar, so without this there is no way back
            // to the category hub on platforms with no hardware back button.
            if (_selectedCategory != null) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                tooltip: 'Nazad na izbor kategorije',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  _resetEngineState();
                  setState(() {
                    _selectedCategory = null;
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                headerGoal,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            BoardFlipButton(size: 18, color: Colors.white70, onPressed: _toggleOrientation),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.biotech, size: 18, color: Colors.indigoAccent),
              tooltip: 'Analiziraj u Tabli za Analizu 🔬',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _exportToAnalysisStudio,
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh, size: 16, color: Colors.amberAccent),
              tooltip: 'Probaj Ponovo',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _restartCurrentPuzzle,
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.tealAccent),
              tooltip: 'Naredna Pozicija',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
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
      );

      return Padding(
        padding: const EdgeInsets.only(left: 12.0, top: 4.0, bottom: 8.0, right: 8.0),
        child: Column(
          children: [
            landscapeTopHeader,
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LEFT SIDE (Board & Eval Bar)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: boardSize,
                          height: boardSize,
                          child: _buildBoardWithTapAndHighlights(boardSize),
                        ),
                        if (_showEvalBar) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            width: boardSize,
                            child: HorizontalEvalBarWidget(
                              eval: _currentRawEval,
                              evalString: _currentEvalString,
                              depth: _currentEvalDepth,
                              orientation: _puzzleOrientation,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 4),

                  // RIGHT SIDE (Controls, Tree & Stockfish Analysis & History)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // PROMINENT LANDSCAPE CONTROL BUTTONS ON THE RIGHT SIDE PANEL
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.biotech, size: 16),
                                  label: const Text('Analiza 🔬', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo.shade800,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                  ),
                                  onPressed: _exportToAnalysisStudio,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Probaj ponovo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade900,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                  ),
                                  onPressed: _restartCurrentPuzzle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.arrow_forward, size: 16),
                                  label: const Text('Naredna pozicija', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal.shade800,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                                  ),
                                  onPressed: () {
                                    if (_selectedCategory == 'basic_mate') {
                                      _loadBasicMatePreset(_selectedBasicMateType);
                                    } else {
                                      _fetchNextPuzzle();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildSolutionTreeSection(),
                          const SizedBox(height: 8),
                          if (_selectedCategory != 'mate_puzzle')
                            StockfishAnalysisWidget(
                              isEngineEnabled: _showEvaluation,
                              isAllowedToUseEngine: true,
                              isOnline: _stockfishService.isOnline,
                              isCustomEngineActive: _stockfishService.isCustomEngineActive,
                              onOpenSettings: isCustomEngineSupported ? _openEngineSettings : null,
                              onForceRestart: _restartEngineEvaluation,
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
                                    _selectedGroupedMoveIndices.clear();
      _stockfishService.setMultiPV(AppSettingsService.instance.defaultMultiPV);
                                    final targetDepth = AppSettingsService.instance.defaultEngineDepth;
                              _stockfishService.analyzePosition(_puzzleBoardController.getFen(), depth: targetDepth);
                                  } else {
                                    _engineLinesMap.clear();
                                    _engineArrows.clear();
                                  }
                                });
                              },
                            ),
                          const SizedBox(height: 8),
                          if (_puzzleMoveTree != null)
                            MoveNavigationControls(
                              cursor: MoveTreeCursor(
                                moveTree: _puzzleMoveTree!,
                                currentNode: _puzzleMoveTree!.current,
                                onSelect: _navigateToNode,
                              ),
                              showMoveChips: true,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // PORTRAIT LAYOUT: Static Board & Scrollable Controls Below
    final double boardSize = math.min(screenSize.width - 32.0, 700.0) * AppSettingsService.instance.boardSizeScale;

    return Column(
      children: [
        // STATIC NON-SCROLLABLE CHESS BOARD AT TOP
        Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Center(
            child: SizedBox(
              width: boardSize,
              height: boardSize,
              child: Card(
                elevation: 4,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: _isLoadingPuzzle
                      ? const Center(child: CircularProgressIndicator())
                      : _buildBoardWithTapAndHighlights(boardSize - 16.0),
                ),
              ),
            ),
          ),
        ),

        // SCROLLABLE CONTROLS & BUTTONS BELOW THE BOARD
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 650),
                child: Column(
                  children: [
                    if (_showEvalBar) ...[
                      HorizontalEvalBarWidget(
                        eval: _currentRawEval,
                        evalString: _currentEvalString,
                        depth: _currentEvalDepth,
                        orientation: _puzzleOrientation,
                      ),
                      const SizedBox(height: 8),
                    ],
                    actionButtonsRow,
                    const SizedBox(height: 12),
                    if (_selectedCategory != 'mate_puzzle')
                      StockfishAnalysisWidget(
                        isEngineEnabled: _showEvaluation,
                        isAllowedToUseEngine: true,
                        isOnline: _stockfishService.isOnline,
                        isCustomEngineActive: _stockfishService.isCustomEngineActive,
                        onOpenSettings: isCustomEngineSupported ? _openEngineSettings : null,
                        onForceRestart: _restartEngineEvaluation,
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
                              _selectedGroupedMoveIndices.clear();
                              _stockfishService.setMultiPV(AppSettingsService.instance.defaultMultiPV);
                              final targetDepth = AppSettingsService.instance.defaultEngineDepth;
                              _stockfishService.analyzePosition(_puzzleBoardController.getFen(), depth: targetDepth);
                            } else {
                              _engineLinesMap.clear();
                              _engineArrows.clear();
                            }
                          });
                        },
                      ),
                    const SizedBox(height: 12),
                    _buildSolutionTreeSection(),
                    const SizedBox(height: 12),
                    if (_puzzleMoveTree != null)
                      MoveNavigationControls(
                        cursor: MoveTreeCursor(
                          moveTree: _puzzleMoveTree!,
                          currentNode: _puzzleMoveTree!.current,
                          onSelect: _navigateToNode,
                        ),
                        showMoveChips: true,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoardWithTapAndHighlights(double boardSize) {
    final squareSize = boardSize / 8.0;

    return SizedBox(
      width: boardSize,
      height: boardSize,
      child: GestureDetector(
      // Opaque so this detector is always in the hit-test path, including
      // over the arrow/selection overlays that never report a hit themselves.
      // It does not shut the board out: children are hit-tested first, so a
      // drag still reaches the board and wins the arena, while a stationary
      // tap is claimed here. Tap is an addition to dragging, not a swap.
      behavior: HitTestBehavior.opaque,
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
                // Deliberately not animated: the piece has already travelled
                // to its destination under the user's pointer, so replaying
                // the slide shows the same move a second time.
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
          for (final pendingAnim in _pendingAnimations)
            AnimatedMovePiece(
              key: ValueKey(pendingAnim),
              pending: pendingAnim,
              boardSize: boardSize,
              orientation: _puzzleOrientation,
              duration: Duration(milliseconds: AppSettingsService.instance.moveAnimationDurationMs),
              onCompleted: () {
                if (mounted) setState(() => _pendingAnimations.remove(pendingAnim));
              },
            ),
        ],
      ),
    ),
  );
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
      _stockfishService.analyzePosition(node.fen, depth: AppSettingsService.instance.defaultEngineDepth);
    }
  }
  /// The mate-puzzle graph view and the plain-puzzle PGN chip view are
  /// mutually exclusive renderings of the same solutions map; see
  /// [SolutionGraphWidget] and [PgnSolutionTreeWidget].
  Widget _buildSolutionTreeSection() {
    final visible = _showSolutionTree || _puzzleSolved || _puzzleFailed || _isReplayingSolution;
    final solutions = Map<String, dynamic>.from(
      (_currentPuzzle?['solutions'] as Map?)?.cast<String, dynamic>() ?? {},
    );

    if (_selectedCategory == 'mate_puzzle') {
      return SolutionGraphWidget(
        visible: visible,
        initialFen: _initialPuzzleFen,
        solutions: solutions,
        mateDepthLabel: 'Mat u ${int.tryParse(_selectedMateDepth) ?? 1}',
        activeFen: _activeFen,
        selectedGroupedMoveIndices: _selectedGroupedMoveIndices,
        onNodesBuilt: (nodes) => _solutionGraphNodesCache = nodes,
        onNodeTap: _jumpToGraphNodePosition,
        onGroupedMoveSelected: _jumpToGroupedOpponentMove,
      );
    }
    return PgnSolutionTreeWidget(
      visible: visible,
      initialFen: _initialPuzzleFen,
      solutions: solutions,
      activeFen: _activeFen,
      onMoveSelected: _onPgnChipSelected,
    );
  }

  void _onPgnChipSelected(String from, String to, String targetFen, String labelSan) {
    _sendBackendLog({
      'type': 'pgnChipClick',
      'moveSan': labelSan,
      'targetFen': targetFen,
    });
    setState(() {
      _puzzleGame = chess.Chess.fromFEN(targetFen);
      _puzzleBoardController.loadFen(targetFen);
      _activeFen = targetFen;
      _lastMoveFrom = from;
      _lastMoveTo = to;
    });
  }

  List<SolutionGraphNode> _solutionGraphNodesCache = [];

  void _jumpToGraphNodePosition(SolutionGraphNode targetNode) {
    if (_puzzleGame == null) return;
    try {
      String computedFen = targetNode.fen;
      String? lastFrom = targetNode.moveUci.length >= 4 ? targetNode.moveUci.substring(0, 2) : null;
      String? lastTo = targetNode.moveUci.length >= 4 ? targetNode.moveUci.substring(2, 4) : null;

      if (_initialPuzzleFen != null && _selectedCategory == 'mate_puzzle') {
        final List<SolutionGraphNode> path = findPathToGraphNode(_solutionGraphNodesCache, targetNode);
        if (path.isNotEmpty) {
          try {
            final game = chess.Chess.fromFEN(_initialPuzzleFen!);
            for (var n in path) {
              String uciToPlay = n.moveUci;
              if (n.isGrouped && n.groupedOpponentMovesUci.isNotEmpty) {
                final idx = (_selectedGroupedMoveIndices[n.id] ?? n.selectedGroupedIndex).clamp(0, n.groupedOpponentMovesUci.length - 1);
                uciToPlay = n.groupedOpponentMovesUci[idx];
              }
              if (uciToPlay.length >= 4) {
                final from = uciToPlay.substring(0, 2);
                final to = uciToPlay.substring(2, 4);
                final promo = uciToPlay.length > 4 ? uciToPlay[4] : null;
                game.move({'from': from, 'to': to, 'promotion': promo});
                lastFrom = from;
                lastTo = to;
              }
            }
            computedFen = game.fen;
          } catch (_) {
            computedFen = targetNode.fen;
          }
        }
      }

      _puzzleGame = chess.Chess.fromFEN(computedFen);
      _puzzleBoardController.loadFen(computedFen);
      _activeFen = computedFen;

      setState(() {
        _lastMoveFrom = lastFrom;
        _lastMoveTo = lastTo;
      });

      _sendBackendLog({
        'type': 'graphNodeClick',
        'moveSan': targetNode.moveSan,
        'targetFen': computedFen,
      });
    } catch (e) {
      print('Error jumping to graph node position: $e');
    }
  }

  void _jumpToGroupedOpponentMove(SolutionGraphNode node, int moveIndex) {
    _selectedGroupedMoveIndices[node.id] = moveIndex;
    node.selectedGroupedIndex = moveIndex;
    if (node.parentFen == null || node.groupedOpponentMovesUci.isEmpty) {
      _jumpToGraphNodePosition(node);
      return;
    }

    final selectedUci = node.groupedOpponentMovesUci[moveIndex.clamp(0, node.groupedOpponentMovesUci.length - 1)];
    final game = chess.Chess.fromFEN(node.parentFen!);
    final from = selectedUci.substring(0, 2);
    final to = selectedUci.substring(2, 4);
    final promo = selectedUci.length > 4 ? selectedUci[4] : null;

    game.move({'from': from, 'to': to, 'promotion': promo});
    final targetFen = game.fen;

    _puzzleGame = chess.Chess.fromFEN(targetFen);
    _puzzleBoardController.loadFen(targetFen);
    _activeFen = targetFen;
    setState(() {
      _selectedSquare = null;
      _lastMoveFrom = from;
      _lastMoveTo = to;
    });

    final String sanLabel = (moveIndex >= 0 && moveIndex < node.groupedOpponentMoves.length)
        ? node.groupedOpponentMoves[moveIndex]
        : selectedUci;
    _showSnackBar('Prikazana pozicija za potez protivnika: $sanLabel');
  }

} // end _AiStudioScreenState




