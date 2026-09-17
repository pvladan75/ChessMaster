import 'package:chess_app/services/puzzle_api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chess_app/widgets/ai_studio/category_selection_hub.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart';
import 'package:chess_app/widgets/ai_studio/solution_tree_models.dart';
import 'package:chess_app/widgets/ai_studio/solution_graph_widget.dart';
import 'package:chess_app/widgets/ai_studio/pgn_solution_tree_widget.dart';
import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/constants.dart';
import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/core/models/drill_outcome.dart';
import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/engine_opponent_sheet.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/promotion_picker.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';

import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';
import 'package:chess_app/widgets/engine_settings_dialog.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';

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

/// The working screen for the exercises that share a board and a verdict.
///
/// It used to be the crossroads as well, and that is why three of the choices
/// there navigated by route and three by setting a field here. Now the choice
/// arrives as [initialCategory] and this screen only does the exercise. Its
/// name is scaffolding from when it did something else; what the reader sees is
/// the title, and that names the exercise.
class AiStudioScreen extends ConsumerStatefulWidget {
  final UserSession userSession;

  /// Which exercise to open: mate_puzzle, basic_mate or winning_position.
  /// Null keeps the old behaviour - the crossroads inside this screen - which
  /// nothing reaches any more and which goes with its last caller.
  final String? initialCategory;

  /// How many moves the mate is in, for `mate_puzzle`.
  final String? mateDepth;

  /// Which preset to load, for `basic_mate`.
  final String? basicMateLevel;

  /// Walks `PuzzleAttemptApi.retryIds(initialCategory)` and serves each by id
  /// instead of asking `/puzzles/next` — the hub's „Retry failed" button on
  /// the mates and winning-position cards (docs/PLAN-NAPREDAK-VEZBI.md §4).
  /// Not meaningful for `basic_mate`, which has no by-id route.
  final bool retry;

  /// The task, for `initialCategory == 'engine_game'` — a homework item's
  /// „play it out" (docs/PLAN-DOMACI-ZADATAK.md §3, phase 2). The strength
  /// travels on the task, not on Settings: the student does not choose the
  /// opponent the trainer chose, so [EngineOpponentButton] is not offered on
  /// this game.
  final EngineGameTask? engineGameTask;

  /// The assignment [engineGameTask] belongs to, so the finished game can be
  /// posted to `POST /assignments/:id/game-result`. Null only when there is
  /// nothing to post to (a task with no assignment cannot be graded).
  final int? assignmentId;

  const AiStudioScreen({
    super.key,
    required this.userSession,
    this.initialCategory,
    this.mateDepth,
    this.basicMateLevel,
    this.retry = false,
    this.engineGameTask,
    this.assignmentId,
  });

  @override
  ConsumerState<AiStudioScreen> createState() => _AiStudioScreenState();
}

class _AiStudioScreenState extends ConsumerState<AiStudioScreen> {
  final ChessBoardController _puzzleBoardController = ChessBoardController();

  final StockfishService _stockfishService = StockfishService();

  /// Every wait this screen is in the middle of, so leaving can end them.
  ///
  /// `Future.delayed` cannot be called off, and a screen that is gone still
  /// finishes waiting: the test framework fails a test the moment one of these
  /// outlives the widget tree, which is why one route had to be left out of the
  /// navigation tests. Whoever is waiting checks `mounted` afterwards anyway,
  /// so nothing wrong was happening - it was simply still running.
  final Map<Timer, Completer<void>> _pending = {};

  /// A pause that ends early when the screen does.
  ///
  /// Both halves have to be kept: completing the future lets whoever is waiting
  /// carry on and stop at its own `mounted` check, and cancelling the timer is
  /// what actually takes it off the clock. Doing only the first leaves the
  /// timer pending, which is the thing the test framework objects to.
  Future<void> _pause(Duration duration) {
    final completer = Completer<void>();
    late final Timer timer;
    timer = Timer(duration, () {
      _pending.remove(timer);
      if (!completer.isCompleted) completer.complete();
    });
    _pending[timer] = completer;
    return completer.future;
  }

  /// The pause before the engine answers, kept so that leaving can cancel it.
  Timer? _engineMoveDelay;

  /// Which side the reader is playing.
  ///
  /// There used to be no such thing. The engine was defined purely by
  /// reaction — after the human moves, the engine answers — which holds right
  /// up until the reader steps back through the move tree to a position where
  /// the engine was to move and plays that move themselves. From there the
  /// engine answers *them*, and the sides have changed hands without anybody
  /// saying so.
  ///
  /// The swap is allowed and stays allowed: watching the engine play your own
  /// side is a real reason to do it. What could not stay is deciding the
  /// outcome from who moved last, because that reads a mate the engine has
  /// just delivered as one the reader delivered.
  chess.Color? _userColor;

  /// Read the reader's side off the position a drill starts from.
  ///
  /// The side to move in the starting FEN is the side the drill is set for —
  /// these positions are handed over with the reader to move.
  void _adoptUserColorFromFen(String fen) => _userColor = sideToMoveOf(fen);

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
  /// A dial moved: remember it, tell the engine, and ask again about the
  /// position now on the board. Leaving the old lines up under a new depth
  /// reads as an engine that stopped working.
  void _applyAnalysisDials({int? depth, int? lines}) {
    setState(() {
      if (depth != null) _analysisDepth = depth;
      if (lines != null) _analysisLines = lines;
    });
    if (depth != null) AppSettingsService.instance.setAnalysisDepth(depth);
    if (lines != null) AppSettingsService.instance.setAnalysisLines(lines);
    _restartEngineEvaluation();
  }

  void _restartEngineEvaluation() {
    _stockfishService.stopAnalysis();
    _stockfishService.setMultiPV(_analysisLines);
    final targetDepth = _analysisDepth;
    setState(() {
      _engineLinesMap.clear();
      _engineArrows.clear();
    });
    _stockfishService.analyzePosition(_puzzleBoardController.getFen(),
        depth: targetDepth);
  }

  // Engine Analysis State
  final bool _isEngineEnabled = false;
  Map<int, AnalysisLine> _engineLinesMap = {};
  List<ChessArrow> _engineArrows = [];

  // Reorganization Category State
  String?
      _selectedCategory; // null = Selection Hub, 'mate_puzzle', 'basic_mate', 'winning_position'
  String _selectedMateDepth = '2'; // '1', '2', '3'
  String _selectedBasicMateType = 'easy'; // 'easy', 'medium', 'hard'
  final Map<String, int> _selectedGroupedMoveIndices = {};

  // Board & Game State
  String? _activeFen;
  bool _showEvaluation = false;
  bool _showEvalBar = false; // Default OFF

  /// This board's own analysis dials.
  ///
  /// Started from what was last chosen anywhere (AppSettingsService) and
  /// changed on the board itself, because "how deep do I want to see" is a
  /// question about the position in front of you. It is **not** the engine's
  /// playing strength: that is the level in Settings, and until 27.8.2026 both
  /// were the same number, so an easier opponent also meant a shallower
  /// evaluation everywhere in the app.
  int _analysisDepth = AppSettingsService.instance.analysisDepth;
  int _analysisLines = AppSettingsService.instance.analysisLines;

  double _currentRawEval = 0.0;
  String _currentEvalString = '0.00';
  int _currentEvalDepth = 0;
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

  /// The failed-puzzle ids, fetched once, when [AiStudioScreen.retry] is set.
  /// Null until asked for; empty is a real answer, not "not yet asked".
  List<String>? _retryQueue;
  int _retryIndex = 0;
  bool _retryQueueEmpty = false;

  /// The task an `engine_game` assignment plays. Set once, when the category
  /// launches, from [AiStudioScreen.engineGameTask] — never rebuilt from
  /// screen state, because the task the screen plays must be the task the
  /// server judges (docs/PLAN-DOMACI-ZADATAK.md §3, "one node answers for
  /// both").
  EngineGameTask? _engineGameTask;

  /// Every move played in an `engine_game`, the student's and the engine's,
  /// in SAN — the whole payload `POST /assignments/:id/game-result` needs.
  /// The server judges the moves again from the task; the app never sends a
  /// verdict.
  final List<String> _engineGameMoves = [];

  /// Guards against posting (and dialoguing) twice for one game — the server
  /// itself refuses a second attempt with 409, but the guard here is what
  /// keeps the engine's own reply from racing a resignation that just ended
  /// the same game.
  bool _engineGameFinished = false;

  /// The engine's strength for an `engine_game`, read from the task rather
  /// than from Settings — the mutation this guards against is „let the
  /// strength come from settings", which the trainer's own choice must win
  /// over.
  int get _engineGameDepth {
    final level =
        _engineGameTask?.level ?? AppSettingsService.instance.enginePlayLevel;
    return AppSettingsService.kEnginePlayDepths[level] ??
        AppSettingsService.instance.enginePlayDepth;
  }

  int get _engineGameThinkSeconds =>
      _engineGameTask?.thinkSeconds ??
      AppSettingsService.instance.defaultEngineMoveTimeSeconds;

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
    // Opened at an exercise rather than at the list of them. After the first
    // frame, because loading a puzzle talks to the network and sets state.
    final opening = widget.initialCategory;
    if (opening != null) {
      if (widget.mateDepth != null) _selectedMateDepth = widget.mateDepth!;
      if (widget.basicMateLevel != null)
        _selectedBasicMateType = widget.basicMateLevel!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _launchCategory(opening);
      });
    }
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
    _serverHealthTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _checkServerHealth());
  }

  Future<void> _checkServerHealth() async {
    try {
      final res = await http
          .get(Uri.parse('$backendUrl/api/health'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        _consecutiveServerFailures = 0;
        if (!_isBackendConnected && mounted) {
          print('[HEALTH_CHECK_LOG] ✅ Server reconnected at ${DateTime.now()}');
          setState(() => _isBackendConnected = true);
          AppFeedback.show(
            context,
            () => SnackBar(
              backgroundColor: context.colors.accent,
              duration: Duration(seconds: 3),
              content: Row(
                children: [
                  Icon(Icons.wifi, color: context.colors.canvas),
                  SizedBox(width: AppSpacing.sm),
                  Text('✅ Connection to the backend server has been restored.',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }
      } else {
        _consecutiveServerFailures++;
        print(
            '[HEALTH_CHECK_LOG] ⚠️ Server check returned HTTP ${res.statusCode} (Consecutive failures: $_consecutiveServerFailures)');
        if (_consecutiveServerFailures >= 3) {
          _handleServerDisconnected();
        }
      }
    } catch (e) {
      _consecutiveServerFailures++;
      print(
          '[HEALTH_CHECK_LOG] ❌ Server connection error: $e (Consecutive failures: $_consecutiveServerFailures)');
      if (_consecutiveServerFailures >= 3) {
        _handleServerDisconnected();
      }
    }
  }

  void _handleServerDisconnected() {
    if (_isBackendConnected && mounted) {
      print(
          '[HEALTH_CHECK_LOG] ℹ️ Backend server is offline or unreachable. Switching silently to offline mode.');
      setState(() => _isBackendConnected = false);
    }
  }

  /// Centralized Universal Board State Reboot & Cleanup Function
  void resetBoardState({bool isNewPuzzle = false}) {
    final oldFen = _activeFen ?? _puzzleBoardController.getFen();
    _positionToken++;
    final int currentToken = _positionToken;
    print(
        '[STATE RESET] Cleared arrows and stopped analysis for FEN: $oldFen (Token: $currentToken)');
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
    _currentEvalDepth = 0;

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
      _stockfishService.setMultiPV(_analysisLines);
    }
  }

  void _resetEngineState() {
    resetBoardState(isNewPuzzle: true);
  }

  Future<void> _sendBackendLog(Map<String, dynamic> details) async {
    try {
      final uri = Uri.parse('$backendUrl/api/puzzles/log');
      final res = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${widget.userSession.token}',
            },
            body: jsonEncode({'details': details}),
          )
          .timeout(const Duration(seconds: 4));

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
    _stockfishService.onEvaluationChanged = (evaluation, bestMove, continuation,
        multipv, depth, isFinal, analyzedFen) async {
      if (!mounted) return;
      if (_selectedCategory == 'mate_puzzle') return;

      print(
          '[ENGINE STREAM] Received eval for FEN: $analyzedFen | Depth: $depth | Best Move: $bestMove');
      _sendBackendLog({
        'type': 'engineStream',
        'fen': analyzedFen,
        'depth': depth,
        'bestMove': bestMove,
      });

      final currentBoardFen =
          (_puzzleGame?.fen ?? _activeFen ?? _puzzleBoardController.getFen())
              .split(' ')[0];
      final eventFen = analyzedFen.split(' ')[0];

      if (analyzedFen.isEmpty || eventFen != currentBoardFen) {
        print(
            '[IGNORED EVENT] Discarding stale evaluation from old FEN: $analyzedFen (Current Board FEN: $currentBoardFen)');
        _sendBackendLog({
          'type': 'ignoredEvent',
          'oldFen': analyzedFen,
          'currentFen': currentBoardFen,
        });
        return; // Odbaci stari event i NEMOJ crtati strelice!
      }

      print(
          '[UI RENDER] Attempting to draw arrows for FEN: $analyzedFen | Current Board FEN: $currentBoardFen');
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
        final mateNum =
            int.tryParse(evaluation.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        parsedEval = evaluation.contains('-')
            ? (-10000.0 + mateNum)
            : (10000.0 - mateNum);
      }

      // Build top 1-5 engine arrows for display matching user MultiPV setting
      final List<ChessArrow> newArrows = [];
      final maxArrows = _analysisLines;
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
      // An empty evaluation is not a score of zero: it is a search saying
      // nothing, and writing it in drew a won position as equal.
      if (multipv == 1 && evaluation.isNotEmpty) {
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
            final mateVal =
                int.tryParse(evaluation.replaceAll(RegExp(r'[^0-9]'), ''));
            if (mateVal != null) {
              if (_puzzleOrientation == PlayerColor.white && !isNegative) {
                userMateScore = mateVal;
              } else if (_puzzleOrientation == PlayerColor.black &&
                  isNegative) {
                userMateScore = mateVal;
              }
            }
          }

          // EARLY EXIT: Stockfish found mate M <= (N - k) -> ACCEPT USER MOVE!
          if (userMateScore != null && userMateScore <= remainingNeeded) {
            print(
                '\n[MATE_VERIFICATION] ✅ EARLY EXIT (Depth $depth): Found mate M$userMateScore <= $remainingNeeded! Move accepted!\n');
            _verificationTimeoutTimer?.cancel();
            _isVerifyingUserMove = false;
            _stockfishService.stopAnalysis();
            _triggerOpponentBotResponse();
            return;
          }

          // FAST REJECTION (Depth >= 6): Stockfish shows no mate in remainingNeeded moves -> REJECT IMMEDIATELY!
          final bool isFastFail = (depth >= 6 &&
              (userMateScore == null || userMateScore > remainingNeeded));

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

            print(
                '\n[MATE_VERIFICATION] ❌ MOVE REJECTED! (Stockfish at depth $depth did not find mate in $remainingNeeded moves). Move reverted, board unlocked.\n');

            await _sendBackendLog({
              'mode': _categoryDisplayName,
              'dynamicFen': _puzzleGame?.fen,
              'status': 'REJECTED',
              'eval': evaluation,
              'reason':
                  'Stockfish at depth $depth did not find mate in $remainingNeeded moves.',
            });

            _showSnackBar('Incorrect move! Try another move.');
            return;
          }
        }
        return;
      }

      // --- PHASE B: OPPONENT BOT TURN RESPONSE ---
      if (_isOpponentTurn) {
        if (multipv == 1 &&
            bestMove.isNotEmpty &&
            bestMove != '-' &&
            bestMove.length >= 4) {
          _latestEngineBestMove = bestMove;
          _latestEngineEval = evaluation;
          // The opponent's strength, from Settings — not the depth this
          // board happens to be showing its evaluation at. On an assigned
          // game the strength is the task's, not the reader's.
          final targetDepth = _selectedCategory == 'engine_game'
              ? _engineGameDepth
              : AppSettingsService.instance.enginePlayDepth;
          if (depth >= targetDepth || isFinal) {
            _executeOpponentEngineMoveDueToTimeoutOrDepth(
                'Zadata dubina dostignuta ($depth >= $targetDepth)');
          }
        }
      }
    };

    _stockfishService.onMultiPVUpdated = (linesMap) {
      if (!mounted) return;
      if (linesMap.isEmpty) return;

      final lineFen = linesMap.values.first.startingFen.split(' ')[0];
      final currentBoardFen =
          (_puzzleGame?.fen ?? _activeFen ?? _puzzleBoardController.getFen())
              .split(' ')[0];

      if (lineFen != currentBoardFen) {
        print(
            '[IGNORED EVENT] Discarding stale MultiPV lines from old FEN: $lineFen (Current Board FEN: $currentBoardFen)');
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
      // A position that is not a possible game never reaches the engine, and
      // the reader is told why rather than left with a board that quietly
      // never evaluates. Reported live 30.8.2026 as a crash.
      onRefused: (reason) {
        if (!mounted) return;
        AppFeedback.show(
            context,
            () => SnackBar(
                  content: Text('Engine cannot calculate: $reason'),
                  backgroundColor: context.colors.danger,
                ));
      },
    );
  }

  /// How many times the engine has been asked again for this same reply.
  ///
  /// One retry, then the board is handed back. Without a limit, a position the
  /// engine will not answer for becomes an endless loop of asking.
  int _opponentMoveRetries = 0;

  void _executeOpponentEngineMoveDueToTimeoutOrDepth(String reason) {
    if (!_isOpponentTurn) return;
    _opponentMoveTimer?.cancel();

    final move = _latestEngineBestMove ??
        (_engineLinesMap.isNotEmpty
            ? _engineLinesMap.values.first.bestMoveLan
            : '');
    final eval = _latestEngineEval ??
        (_engineLinesMap.isNotEmpty
            ? _engineLinesMap.values.first.evaluation
            : '0.00');

    if (move.isNotEmpty && move != '-' && move.length >= 4) {
      print(
          '\n[ENGINE_MOVE_TRIGGER] Playing the engine move: $reason! Chosen move: $move (Eval: $eval)\n');
      // `_isOpponentTurn` deliberately stays true here. It used to be cleared
      // on this line, a full second before the move it announces is actually
      // played - and the board is only inert while it is set. In that second
      // the reader could move a piece of the side the engine was about to move
      // with; the queued move then landed on a position it no longer belonged
      // to, and the drill stopped answering. `resetBoardState` clears the flag
      // once the move is on the board, which is the moment it stops being the
      // opponent's turn.
      _opponentMoveRetries = 0;
      _stockfishService.stopAnalysis();
      _playOpponentMove(move, eval);
      return;
    }

    // Nothing to play. This is what happens when every evaluation that came
    // back was for a position no longer on the board: all of it was discarded
    // as stale, and nothing was ever recorded to play.
    if (_opponentMoveRetries < 1 && _puzzleGame != null && mounted) {
      _opponentMoveRetries++;
      // Ask again, for the position that is on the board now. The flag stays
      // set: it is still the engine's turn, and the board stays inert until it
      // has answered.
      _triggerOpponentBotResponse();
      return;
    }

    // Give the board back rather than leaving it locked. A drill that will not
    // move is bad; one that will not move *and* will not let the reader touch
    // anything is worse, and the two look identical from the outside.
    _opponentMoveRetries = 0;
    setState(() => _isOpponentTurn = false);
    _showSnackBar('Engine did not respond. Play your move again.');
  }

  void _playOpponentMove(String bestMove, String evaluation) {
    String validMove = bestMove;
    if (_puzzleGame != null) {
      final moves = legalMoves(_puzzleGame!);
      final isLegal = moves.any((m) {
        final from = m['from'] ?? '';
        final to = m['to'] ?? '';
        final promo = m['promotion'] ?? '';
        final lan = '$from$to$promo';
        return lan.startsWith(validMove.substring(0, 4));
      });
      if (!isLegal && moves.isNotEmpty) {
        final fallbackObj = moves.first;
        final from = fallbackObj['from'] ?? '';
        final to = fallbackObj['to'] ?? '';
        final promo = fallbackObj['promotion'] ?? '';
        validMove = '$from$to$promo';
        print(
            '\n[TRAINING_LOG] ⚠️ THE ENGINE RETURNED AN ILLEGAL MOVE ($bestMove)! Replaced with a legal one: $validMove\n');
      }
    }

    final targetDepth = _selectedCategory == 'engine_game'
        ? _engineGameDepth
        : AppSettingsService.instance.enginePlayDepth;

    print('\n--------------------------------------------------');
    print('[TRAINING_LOG] 1) MOD: $_categoryDisplayName');
    print(
        '[TRAINING_LOG] 3) FEN POSITION THE ENGINE IS ANALYSING: ${_puzzleGame?.fen}');
    print('[TRAINING_LOG] 5) ENGINE MOVE: $validMove');
    print(
        '[TRAINING_LOG] 5) OSNOV ODABIRA: Stockfish kalkulacija najbolje linije');
    print('[TRAINING_LOG] 5) DUBINA ANALIZE (DEPTH): $targetDepth');
    print(
        '[TRAINING_LOG] 5) POSITION EVALUATION: $evaluation (Best: $validMove)');
    print('--------------------------------------------------\n');

    _sendBackendLog({
      'mode': _categoryDisplayName,
      'dynamicFen': _puzzleGame?.fen,
      'engineMove': validMove,
      'decisionBasis': 'Stockfish kalkulacija najbolje linije',
      'depth': targetDepth,
      'eval': evaluation,
    });

    // A Timer rather than Future.delayed, because a Future cannot be called
    // off. The second's pause keeps the engine's reply from landing on top of
    // the reader's own move - and if they leave inside it, it goes with them.
    _engineMoveDelay?.cancel();
    _engineMoveDelay = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;

      // Checked again here, against the board this move is about to land on
      // rather than the one it was chosen for. The check above runs a second
      // earlier, and a second is long enough for the position to have moved on
      // - which is exactly how a queued reply used to be played into a
      // position it did not belong to, leaving the drill unable to continue.
      if (_puzzleGame != null) {
        final stillLegal = legalMoves(_puzzleGame!).any((m) =>
            '${m['from']}${m['to']}${m['promotion']}'
                .startsWith(validMove.substring(0, 4)));
        if (!stillLegal) {
          print(
              '[ENGINE_MOVE_TRIGGER] Move $validMove is no longer legal - position changed. Seeking new response.');
          _triggerOpponentBotResponse();
          return;
        }
      }

      _playPuzzleMove(validMove);
      if (_puzzleGame != null) {
        _activeFen = _puzzleGame!.fen;
        resetBoardState(isNewPuzzle: false);

        if (_selectedCategory == 'engine_game') {
          final gameVerdict = engineGameVerdict(
            task: _engineGameTask!,
            game: _puzzleGame!,
            ownMoves: _userMoveCount,
          );
          if (gameVerdict.ending != null) _finishEngineGame(gameVerdict);
          // Still running: wait for the student's next move.
          return;
        }

        // Read off the board and the reader's side, never off the category.
        // This used to branch on which drill it was, and everything that was
        // not `basic_mate` fell through to the victory dialog — so in
        // `winning_position` a mate delivered *by* Stockfish congratulated the
        // reader on delivering it and marked the drill solved.
        // The engine has just moved, so the side to move is the reader's —
        // that is the fallback if a drill somehow loaded without a side.
        final verdict =
            verdictFor(_puzzleGame!, _userColor ?? _puzzleGame!.turn);
        if (verdict.outcome == DrillOutcome.readerLost) {
          _showEndgameLossDialog();
        } else if (verdict.outcome == DrillOutcome.readerWon) {
          setState(() => _puzzleSolved = true);
          _showEndgameWinDialog();
        } else if (verdict.outcome == DrillOutcome.drawn) {
          _showEndgameDrawDialog(verdict.ending!);
        } else {
          if (_selectedCategory != 'mate_puzzle' &&
              (_showEvaluation || _showEvalBar)) {
            _selectedGroupedMoveIndices.clear();
            _stockfishService.setMultiPV(_analysisLines);
            _stockfishService.analyzePosition(_puzzleGame!.fen,
                depth: _analysisDepth);
          }
        }
      }
    });
  }

  void _triggerOpponentBotResponse() async {
    if (_selectedCategory == 'mate_puzzle') return;
    // Any ending, not only mate: a reader who stalemates the engine used to
    // leave it here asked for a move in a finished game.
    if (_puzzleGame == null ||
        verdictFor(_puzzleGame!, _userColor ?? _puzzleGame!.turn).isOver) {
      return;
    }
    resetBoardState(isNewPuzzle: false);
    setState(() {
      _isVerifyingUserMove = false;
      _isOpponentTurn = true;
    });

    // If puzzle solution JSON has the predefined response move at _moveIndex, play it!
    if (_expectedMoves.length > _moveIndex &&
        _expectedMoves[_moveIndex].isNotEmpty) {
      final jsonResponseMove = _expectedMoves[_moveIndex];
      _moveIndex++;
      print(
          '\n[OPPONENT_BOT_DEBUG] 🎯 Found prepared response in JSON solution: $jsonResponseMove\n');
      _stockfishService.stopAnalysis();
      // Not `_isOpponentTurn = false` here: the move below is played a
      // second later, and the board is inert only while this is set. See
      // _executeOpponentEngineMoveDueToTimeoutOrDepth for what slipped
      // through that second. `resetBoardState` clears it once the move is
      // actually on the board.
      _playOpponentMove(jsonResponseMove, 'JSON');
      return;
    }

    _opponentMoveTimer?.cancel();
    _latestEngineBestMove = null;
    _latestEngineEval = null;
    // On an assigned game the think time is the task's, not the reader's —
    // the student does not choose the opponent the trainer chose.
    final moveTimeSec = _selectedCategory == 'engine_game'
        ? _engineGameThinkSeconds
        : AppSettingsService.instance.defaultEngineMoveTimeSeconds;
    _opponentMoveTimer = Timer(Duration(seconds: moveTimeSec), () {
      if (_isOpponentTurn && mounted) {
        _executeOpponentEngineMoveDueToTimeoutOrDepth(
            'Thinking time expired ($moveTimeSec s)');
      }
    });

    await _stockfishService.initEngine();
    _stockfishService.setMultiPV(_analysisLines);
    // The engine is *playing* here, so how deep it thinks is the opponent's
    // strength and not the depth this board shows its evaluation at. One
    // number used to answer both, so an easier opponent quietly made every
    // evaluation in the app shallower. On an assigned game that strength is
    // the task's.
    final targetDepth = _selectedCategory == 'engine_game'
        ? _engineGameDepth
        : AppSettingsService.instance.enginePlayDepth;
    _stockfishService.analyzePosition(_puzzleGame!.fen, depth: targetDepth);
  }

  void _showBlunderAlert(double evalDiff, double currentEval) {
    if (!mounted) return;
    final isCritical = currentEval <= 0.5;
    final title = isCritical ? '🚨 BLUNDER!' : '⚠️ INACCURACY!';
    final msg = isCritical
        ? 'This move lost the winning position (Eval drop: -${evalDiff.toStringAsFixed(1)}).'
        : 'You made an inaccurate move, but still hold the advantage (Drop: -${evalDiff.toStringAsFixed(1)}).';

    AppFeedback.show(
      context,
      () => SnackBar(
        backgroundColor: isCritical
            ? context.colors.dangerContainer
            : context.colors.warning,
        duration: const Duration(seconds: 4),
        content: Row(
          children: [
            Icon(isCritical ? Icons.cancel : Icons.warning_amber,
                color: isCritical
                    ? context.colors.onDangerContainer
                    : context.colors.canvas),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isCritical
                              ? context.colors.onDangerContainer
                              : context.colors.canvas)),
                  Text(msg,
                      style: AppText.caption.copyWith(
                          color: isCritical
                              ? context.colors.onDangerContainer
                                  .withValues(alpha: 0.85)
                              : context.colors.canvas.withValues(alpha: 0.7))),
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

    // As many arrows as this board asked for lines. It was three, fixed, so
    // asking for five lines drew four of them and left the fifth in the list
    // underneath with nothing on the board.
    for (int i = 0; i < lines.length && i < _analysisLines; i++) {
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

    final maxArrows = _analysisLines;
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
    // Both of these outlived the screen. Harmless-looking, since the callbacks
    // check `mounted` - but they are timers running with nothing to fire into,
    // and a navigation test trips over them at once: "a Timer is still pending
    // even after the widget tree was disposed".
    _opponentMoveTimer?.cancel();
    _engineMoveDelay?.cancel();
    // Whatever the screen was in the middle of waiting for ends here. The
    // waiters all check `mounted` and stop; what matters is that nothing is
    // still counting after the tree is gone.
    for (final entry in _pending.entries) {
      entry.key.cancel();
      if (!entry.value.isCompleted) entry.value.complete();
    }
    _pending.clear();
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
    } else if (category == 'engine_game') {
      _loadEngineGameTask();
    } else {
      _fetchNextPuzzle();
    }
  }

  /// Sets the board up for the task the trainer sent, rather than fetching
  /// anything from the puzzle server. The task is read once, from
  /// [AiStudioScreen.engineGameTask] — never rebuilt from screen state,
  /// because the position the screen plays must be the position the server
  /// judges (docs/PLAN-DOMACI-ZADATAK.md §3).
  void _loadEngineGameTask() {
    final task = widget.engineGameTask;
    if (task == null) {
      _showSnackBar('This game could not be opened.');
      return;
    }
    _engineGameTask = task;
    _engineGameMoves.clear();
    _engineGameFinished = false;

    _puzzleGame = chess.Chess.fromFEN(task.fen);
    _activeFen = task.fen;
    _initialPuzzleFen = task.fen;
    _userColor = task.side;
    _puzzleMoveTree = MoveTree(startingFen: task.fen);

    setState(() {
      _selectedCategory = 'engine_game';
      _puzzleOrientation = task.side == chess.Color.WHITE
          ? PlayerColor.white
          : PlayerColor.black;
      _isLoadingPuzzle = false;
      _puzzleSolved = false;
      _puzzleFailed = false;
      _expectedMoves = [];
      _moveIndex = 0;
      _userMoveCount = 0;
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _isOpponentTurn = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          _puzzleBoardController.loadFen(task.fen);
        } catch (_) {}
      }
    });

    // Either side may be asked to play (docs/PLAN-DOMACI-ZADATAK.md §3, "any
    // position, either side"). When the position hands the first move to the
    // engine rather than the student, it has to be told to move before the
    // board waits on the student for a turn that is not theirs.
    if (_puzzleGame!.turn != task.side) {
      _triggerOpponentBotResponse();
    }
  }

  String get _categoryDisplayName {
    if (_selectedCategory == 'mate_puzzle')
      return 'Puzzles: Mate in $_selectedMateDepth';
    if (_selectedCategory == 'basic_mate')
      return 'Practice basic checkmate ($_selectedBasicMateType)';
    if (_selectedCategory == 'winning_position') return 'Find the winning path';
    return _selectedCategory ?? 'Training';
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
        _adoptUserColorFromFen(fen);
        _puzzleMoveTree = MoveTree(startingFen: fen);

        print('\n==================================================');
        print('[TRAINING_LOG] 1) MOD: $_categoryDisplayName');
        print('[TRAINING_LOG] 2) LOADED FEN: $fen');
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
          _puzzleOrientation =
              turnIsWhite ? PlayerColor.white : PlayerColor.black;
          _showEvalBar = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _puzzleBoardController.loadFen(fen);
            } catch (_) {}
          }
        });

        _stockfishService.analyzePosition(fen, depth: _analysisDepth);
      }
    } catch (e) {
      print('Error loading basic mate preset $difficulty: $e');
    }
  }

  /// The retry queue is fetched once and then walked in order; an id already
  /// served does not come back even if a later request is slow, because
  /// [_retryIndex] moves before the request goes out.
  Future<Map<String, dynamic>?> _fetchNextRetryPuzzle() async {
    final category = _selectedCategory ?? PuzzleSource.matePuzzle;
    if (_retryQueue == null) {
      final ids = await PuzzleAttemptApi(authToken: widget.userSession.token)
          .retryIds(category);
      _retryQueue = ids ?? [];
      _retryIndex = 0;
    }
    if (_retryIndex >= _retryQueue!.length) {
      if (mounted) setState(() => _retryQueueEmpty = true);
      return null;
    }
    final id = _retryQueue![_retryIndex];
    _retryIndex++;
    return PuzzleApiService.instance.fetchPuzzleById(
      id: id,
      source: category,
      userToken: widget.userSession.token,
    );
  }

  /// „Next Position" pressed before the puzzle is solved is a skip, recorded
  /// so it does not read as "never seen" on the hub card
  /// (docs/PLAN-NAPREDAK-VEZBI.md §4). Solved puzzles reach this only through
  /// the win/loss dialogs, which already recorded the attempt themselves.
  void _goToNextPuzzle() {
    if (!_puzzleSolved && !_puzzleFailed) {
      if (_selectedCategory == 'basic_mate') {
        _recordBasicMateAttempt(solved: false, skipped: true);
      } else {
        _submitPuzzleResult(false, skipped: true, showResultDialog: false);
      }
    }
    if (_selectedCategory == 'basic_mate') {
      _loadBasicMatePreset(_selectedBasicMateType);
    } else {
      _fetchNextPuzzle();
    }
  }

  /// Basic mates have no server row and no rating — `PuzzleAttemptApi.record`
  /// writes straight to `/attempt`, id'd by the preset and the FEN it started
  /// from (before any move), the key the repertoire's own nodes already use.
  /// Fired, not awaited: recording must never hold up the board.
  void _recordBasicMateAttempt({required bool solved, bool skipped = false}) {
    final startFen = _initialPuzzleFen;
    if (startFen == null) return;
    unawaited(PuzzleAttemptApi(authToken: widget.userSession.token).record(
      source: PuzzleSource.basicMate,
      puzzleId: PuzzleSource.basicMateId(_selectedBasicMateType, startFen),
      solved: solved,
      skipped: skipped,
    ));
  }

  Future<void> _fetchNextPuzzle() async {
    _resetEngineState();
    final String currentId =
        _currentPuzzle?['puzzle_id'] ?? _currentPuzzle?['id'] ?? '';
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
      final resData = widget.retry
          ? await _fetchNextRetryPuzzle()
          : await PuzzleApiService.instance.fetchNextPuzzle(
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
        _adoptUserColorFromFen(fen);
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
        print('[TRAINING_LOG] 2) LOADED FEN: $fen');
        print('[TRAINING_LOG] EXPECTED MOVES (JSON): $moves');
        print(
            '[TREE_VERIFICATION] 🌳 Solution tree loaded (${_currentSolutionsNode?.keys.length ?? 0} branches)');
        print('==================================================\n');

        _sendBackendLog({
          'mode': _categoryDisplayName,
          'initialFen': fen,
        });

        final sideToMove = fen.split(' ')[1];
        setState(() {
          _puzzleOrientation =
              (sideToMove == 'b') ? PlayerColor.black : PlayerColor.white;
          _isOpponentTurn = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            try {
              _puzzleBoardController.loadFen(fen);
            } catch (_) {}
          }
        });

        if (_selectedCategory != 'mate_puzzle' &&
            (_showEvaluation || _showEvalBar)) {
          _stockfishService.analyzePosition(fen, depth: _analysisDepth);
        }
      } else if (!_retryQueueEmpty) {
        // An empty retry queue is a real answer, not a failed fetch — its own
        // screen, not a snackbar (docs/PLAN-NAPREDAK-VEZBI.md §4).
        _showSnackBar('Unable to load position.');
      }
    } catch (e) {
      _showSnackBar('Error loading position.');
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

    if (_selectedCategory != 'mate_puzzle' &&
        (_showEvaluation || _showEvalBar)) {
      _selectedGroupedMoveIndices.clear();
      _stockfishService.setMultiPV(_analysisLines);
      _stockfishService.analyzePosition(_initialPuzzleFen!,
          depth: _analysisDepth);
    }

    _sendBackendLog({
      'mode': _categoryDisplayName,
      'action': 'RESTART_PUZZLE',
      'initialFen': _initialPuzzleFen,
    });

    _showSnackBar('🔄 Position reset to initial state.');
  }

  Future<void> _handleSquareTap(String square) async {
    if (_isOpponentTurn || _puzzleSolved || _puzzleGame == null) return;

    final piece = _puzzleGame!.get(square);
    final isTurnWhite = _puzzleGame!.turn == chess.Color.WHITE;

    bool isFriendlyPiece = false;
    if (piece != null) {
      if (isTurnWhite && piece.color == chess.Color.WHITE)
        isFriendlyPiece = true;
      if (!isTurnWhite && piece.color == chess.Color.BLACK)
        isFriendlyPiece = true;
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

        if (isPromotionMove(_puzzleGame!, from, to)) {
          // The reader picks. This used to read the solution tree and quietly
          // promote to whatever the answer needed — so a puzzle whose point is
          // that only a knight works was solved by playing a queen, and the
          // one thing it was teaching never came up.
          final chosen = await askPromotionPiece(
            context,
            isWhite: _puzzleGame!.turn == chess.Color.WHITE,
          );
          if (chosen == null || !mounted) return;
          promoPiece = chosen;
        }

        final movingPiece = _puzzleGame!.get(from);
        if (movingPiece != null) _triggerMoveAnimation(from, to, movingPiece);
        _onUserPuzzleMoveMade(
            manualFrom: from, manualTo: to, manualPromo: promoPiece);
      }
    }
  }

  void _triggerMoveAnimation(String from, String to, chess.Piece movingPiece) {
    final durationMs = AppSettingsService.instance.moveAnimationDurationMs;
    if (durationMs <= 0) return;
    setState(() {
      _pendingAnimations
          .add(PendingMoveAnimation(from: from, to: to, piece: movingPiece));
    });
  }

  void _playPuzzleMove(String lanMove) {
    if (lanMove.length < 4) return;
    final fromStr = lanMove.substring(0, 2);
    final toStr = lanMove.substring(2, 4);

    _isProgrammaticMove = true;
    try {
      if (_puzzleGame != null) {
        // The opponent's own promotion, named: without the piece the SAN would
        // come out as "d7d8" and the move list would not say what appeared on
        // the board.
        final promo = lanMove.length > 4 ? lanMove[4].toLowerCase() : '';
        String san = '$fromStr$toStr';
        for (var m in legalMoves(_puzzleGame!)) {
          if (m['from'] == fromStr &&
              m['to'] == toStr &&
              (promo.isEmpty || m['promotion'] == promo)) {
            san = m['san'] ?? san;
            break;
          }
        }
        _puzzleGame!.move({
          'from': fromStr,
          'to': toStr,
          'promotion': promo.isEmpty ? 'q' : promo,
        });
        final animatedPiece = _puzzleGame!.get(toStr);
        if (animatedPiece != null)
          _triggerMoveAnimation(fromStr, toStr, animatedPiece);
        _puzzleBoardController.loadFen(_puzzleGame!.fen);
        _activeFen = _puzzleGame!.fen;
        _recordMoveInTree(fromStr, toStr, san: san);
        if (_selectedCategory == 'engine_game') _engineGameMoves.add(san);
      } else {
        _puzzleBoardController.makeMove(from: fromStr, to: toStr);
        final animatedPiece = _puzzleBoardController.game.get(toStr);
        if (animatedPiece != null)
          _triggerMoveAnimation(fromStr, toStr, animatedPiece);
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

  Future<void> _onUserPuzzleMoveMade(
      {String? manualFrom, String? manualTo, String? manualPromo}) async {
    if (_isOpponentTurn ||
        _puzzleGame == null ||
        _isVerifyingUserMove ||
        _puzzleSolved) return;
    _isVerifyingUserMove = true;
    setState(() {
      _gameState = PuzzleGameState.verifyingMove;
    });

    final currentFen = _puzzleBoardController.getFen();
    final String startingFen = _puzzleGame!.fen;
    // Repaired list: the package's own verbose maps carry no promotion at all,
    // so every promotion below would be matched as an ordinary move and then
    // refused by `move()` — which is precisely how a pawn on the seventh rank
    // stopped being able to promote. See core/services/legal_moves.dart.
    final allLegalMoves = legalMoves(_puzzleGame!);

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
        playMove(testGame, m);
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

      // What used to be here: a "promotion handling refinement" that looked the
      // move up in the solution tree and swapped the reader's piece for the one
      // the answer wanted. It existed because the promotion could not be read
      // off the move at all; now that it can, the piece on the board is the
      // piece the reader chose, and a queen where the answer is a knight is a
      // wrong answer rather than a silently corrected one.
    }

    if (matchedMove == null || userLan == null) {
      print('[MOVE_MADE_DEBUG] Could not match move in chess.js legal moves!');
      _isVerifyingUserMove = false;
      setState(() => _gameState = PuzzleGameState.idle);
      return;
    }

    // Read before the move is played, because afterwards the turn has already
    // flipped. If the reader is moving for the side that is not theirs, they
    // have stepped back to a position the engine was to play and taken it
    // over — so from the next reply onwards the engine is playing what used to
    // be their side.
    final chess.Color movingColor = _puzzleGame!.turn;
    final bool sidesSwapped = isSideSwap(_userColor, movingColor);
    if (sidesSwapped) _userColor = movingColor;

    playMove(_puzzleGame!, matchedMove);
    _activeFen = _puzzleGame!.fen;
    _puzzleBoardController.loadFen(_puzzleGame!.fen);

    // Universal reboot of board state for move execution (preserves toggles A/B if ON!)
    resetBoardState(isNewPuzzle: false);

    // Do the thing, then say it. The board is already updated above; this only
    // reports it, and it reports it because a side change that happens in
    // silence is indistinguishable from the engine having gone wrong.
    if (sidesSwapped) {
      _showSnackBar(_userColor == chess.Color.WHITE
          ? '↔ From this position you play White, Stockfish plays Black.'
          : '↔ From this position you play Black, Stockfish plays White.');
    }

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

    // An assigned game reads its own verdict — including „survive", which
    // no board rule knows about — and never falls into the puzzle-specific
    // steps below, which read a solution tree this task does not have.
    if (_selectedCategory == 'engine_game') {
      _engineGameMoves.add(san);
      final gameVerdict = engineGameVerdict(
        task: _engineGameTask!,
        game: _puzzleGame!,
        ownMoves: _userMoveCount,
      );
      if (gameVerdict.ending != null) {
        await _finishEngineGame(gameVerdict);
      } else {
        _triggerOpponentBotResponse();
      }
      return;
    }

    // --- STEP 0: IMMEDIATE CHECKMATE VICTORY ON BOARD (FOR BASIC MATES & WINNING POSITIONS) ---
    // Same reading as the engine's branch, through the same function: the
    // reader has just moved, so a mate here is theirs. Written this way rather
    // than as a bare `in_checkmate` so that both verdicts in this screen come
    // from one rule instead of two that can drift apart — which is how they
    // drifted apart in the first place.
    final verdict = verdictFor(_puzzleGame!, _userColor ?? movingColor);
    if (verdict.outcome == DrillOutcome.drawn &&
        _selectedCategory != 'mate_puzzle') {
      // The reader's own move drew the game — a stalemate, or a capture that
      // left too little to mate with. Until 17.9.2026 this fell through to
      // the engine's turn, and the engine was asked to move in a finished
      // game; the reader saw nothing happen.
      await _sendBackendLog({
        'mode': _categoryDisplayName,
        'dynamicFen': currentFen,
        'userMove': userLan,
        'status': 'DRAWN',
        'reason': endingLabel(verdict.ending!),
      });
      _showEndgameDrawDialog(verdict.ending!);
      return;
    }
    if (verdict.outcome == DrillOutcome.readerWon &&
        _selectedCategory != 'mate_puzzle') {
      print('\n==================================================');
      print(
          '[TRAINING_LOG] 🏆 CHECKMATE ON BOARD! User successfully delivered mate!');
      print('==================================================\n');

      await _sendBackendLog({
        'mode': _categoryDisplayName,
        'dynamicFen': currentFen,
        'userMove': userLan,
        'status': 'SOLVED',
        'reason': 'User successfully delivered checkmate on the board!',
      });

      if (_selectedCategory == 'basic_mate') {
        setState(() => _puzzleSolved = true);
        _recordBasicMateAttempt(solved: true);
        _showEndgameWinDialog();
      } else if (_selectedCategory == 'winning_position') {
        setState(() => _puzzleSolved = true);
        // Records and moves the rating without opening a second dialog —
        // `_showEndgameWinDialog` already tells the player they won.
        _submitPuzzleResult(true, showResultDialog: false);
        _showEndgameWinDialog();
      } else {
        _submitPuzzleResult(true);
      }
      return;
    }

    // --- STEP 1: DIRECT LOCAL SOLUTION TREE VERIFICATION FOR MATE PUZZLES ---
    if (_selectedCategory == 'mate_puzzle') {
      _currentSolutionsNode ??=
          Map<String, dynamic>.from(_currentPuzzle?['solutions'] ?? {});
      final primaryJsonMove = _currentPuzzle?['winning_move_uci'] ??
          (_expectedMoves.length > _moveIndex
              ? _expectedMoves[_moveIndex]
              : '');

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
      if (subBranch == null &&
          primaryJsonMove.isNotEmpty &&
          userLan == primaryJsonMove) {
        final reqN = int.tryParse(_selectedMateDepth) ?? 1;
        if (reqN == 1 || _puzzleGame!.in_checkmate) {
          subBranch = "CHECKMATE";
        }
      }

      print('\n==================================================');
      print(
          '[TREE_VERIFICATION] 🌳 User move: $userLan | Primary JSON move: $primaryJsonMove');
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
          'subBranch': subBranch == "CHECKMATE"
              ? "CHECKMATE"
              : (subBranch is Map
                  ? "Response branch: ${subBranch.keys.join(', ')}"
                  : subBranch.toString()),
        });

        final bool isTerminalCheckmate =
            (subBranch == "CHECKMATE" || _puzzleGame!.in_checkmate);

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
              _activeBranchPoints
                  .removeLast(); // Clean up completed branch points
            }
          }

          if (pendingBP != null) {
            final String nextOppMove =
                pendingBP.pendingOpponentMoves.removeAt(0);
            print(
                '[TREE_VERIFICATION] 🔁 Line solved to checkmate! Continuing to another defensive variation from branch point: $nextOppMove');

            _sendBackendLog({
              'type': 'branchReset',
              'mode': _categoryDisplayName,
              'nextOpponentMove': nextOppMove,
              'remainingBranches': pendingBP.pendingOpponentMoves.length,
            });

            _showSnackBar('Great! Now solve the opponent\'s other defense.');

            // Reset board to the EXACT branching FEN (post-user-move position) and play next opponent variation
            _pause(const Duration(milliseconds: 600)).then((_) {
              if (!mounted) return;
              try {
                _puzzleGame = chess.Chess.fromFEN(pendingBP!.fenPostUserMove);
                _puzzleBoardController.loadFen(pendingBP.fenPostUserMove);
                _activeFen = pendingBP.fenPostUserMove;

                final oppFrom = nextOppMove.substring(0, 2);
                final oppTo = nextOppMove.substring(2, 4);
                final oppPromo = nextOppMove.length > 4 ? nextOppMove[4] : null;

                _puzzleGame!.move(
                    {'from': oppFrom, 'to': oppTo, 'promotion': oppPromo});
                final animatedPiece = _puzzleGame!.get(oppTo);
                if (animatedPiece != null)
                  _triggerMoveAnimation(oppFrom, oppTo, animatedPiece);
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
                print('Error switching to next variation: $e');
              }
            });
            return;
          }

          // All variations completely solved!
          print(
              '[TREE_VERIFICATION] 🎉 ALL VARIATIONS FULLY SOLVED! Puzzle successfully solved.');
          setState(() {
            _puzzleSolved = true;
            _gameState = PuzzleGameState.puzzleCompleted;
          });
          _submitPuzzleResult(true);
          _showSnackBar('Congratulations! Puzzle solved! 🎉');
          return;
        }

        if (subBranch is Map) {
          final Map<String, dynamic> oppTree =
              Map<String, dynamic>.from(subBranch);

          // Check unicity: do all opponent replies require identical user responses?
          final bool isIdenticalUserMoves =
              _areUserMovesIdenticalForAllOpponentReplies(oppTree);

          String oppMoveLan;
          if (!isIdenticalUserMoves && oppTree.keys.length > 1) {
            // Find or record branch point for current user move
            VariationBranchPoint? existingBP;
            for (var bp in _activeBranchPoints) {
              if (bp.fenPostUserMove == _puzzleGame!.fen &&
                  bp.userMoveUci == userLan) {
                existingBP = bp;
                break;
              }
            }

            if (existingBP == null) {
              final uniqueOppKeys =
                  _getUniqueOpponentRepresentativeMoves(oppTree);
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
          _pause(const Duration(milliseconds: 300)).then((_) {
            if (!mounted) return;
            try {
              final oppFrom = oppMoveLan.substring(0, 2);
              final oppTo = oppMoveLan.substring(2, 4);
              final oppPromo = oppMoveLan.length > 4 ? oppMoveLan[4] : null;

              final moveObj = _puzzleGame!
                  .move({'from': oppFrom, 'to': oppTo, 'promotion': oppPromo});
              if (moveObj) {
                final animatedPiece = _puzzleGame!.get(oppTo);
                if (animatedPiece != null)
                  _triggerMoveAnimation(oppFrom, oppTo, animatedPiece);
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

              if (_currentSolutionsNode!.isEmpty ||
                  nextSubTree == "CHECKMATE" ||
                  _puzzleGame!.in_checkmate) {
                bool hasPendingBP = false;
                for (var bp in _activeBranchPoints) {
                  if (bp.pendingOpponentMoves.isNotEmpty) {
                    hasPendingBP = true;
                    break;
                  }
                }

                if (!hasPendingBP &&
                    (_puzzleGame!.in_checkmate || nextSubTree == "CHECKMATE")) {
                  setState(() {
                    _puzzleSolved = true;
                    _gameState = PuzzleGameState.puzzleCompleted;
                  });
                  _submitPuzzleResult(true);
                  _showSnackBar('Congratulations! Puzzle solved! 🎉');
                }
              }
            } catch (e) {
              print('Error playing opponent move: $e');
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
        _showSnackBar('Congratulations! Puzzle solved! 🎉');
        return;
      } else {
        // Move NOT in solution tree -> Show failure modal dialog with 3 choices!
        print(
            '[TREE_VERIFICATION] ❌ Move $userLan is not in the solution tree! Showing error dialog.');
        _sendBackendLog({
          'mode': _categoryDisplayName,
          'initialFen': _initialPuzzleFen,
          'dynamicFen': startingFen,
          'userMove': '$userLan ($san)',
          'status': 'REJECTED',
          'validTreeKeys': _currentSolutionsNode?.keys.join(', '),
          'reason': 'Move is not in the puzzle solution tree',
        });
        _showFailureDialog();
        return;
      }
    }

    if (_selectedCategory == 'mate_puzzle') return;
    _triggerOpponentBotResponse();
  }

  List<String> _getUniqueOpponentRepresentativeMoves(
      Map<String, dynamic> oppBranchMap) {
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

    return uniqueOpponentMoves.isNotEmpty
        ? uniqueOpponentMoves
        : oppBranchMap.keys.map((k) => k.toString()).toList();
  }

  bool _areUserMovesIdenticalForAllOpponentReplies(
      Map<String, dynamic> oppBranchMap) {
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
      'button': 'Dialog Shown - Incorrect Move',
      'puzzleId': _currentPuzzle?['puzzle_id'],
      'fen': _puzzleGame?.fen,
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
      ),
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).padding.bottom;
        final isLandscape =
            MediaQuery.of(ctx).orientation == Orientation.landscape;
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.88,
            ),
            padding: EdgeInsets.only(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              top: AppSpacing.lg,
              bottom: bottomPadding + AppSpacing.xl,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel_outlined,
                      color: context.colors.danger,
                      size: isLandscape ? 36 : 48),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Incorrect Move!',
                    style: AppText.headline
                        .copyWith(color: context.colors.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The move you played is not in the solution tree. Choose an option:',
                    textAlign: TextAlign.center,
                    style: AppText.bodyLarge
                        .copyWith(color: context.colors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.warning,
                        foregroundColor: context.colors.canvas,
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _sendBackendLog({
                          'type': 'buttonClick',
                          'button': 'Modal - Try Again'
                        });
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
                          label: const Text('Show Solution'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.accentAlt,
                            foregroundColor: context.colors.canvas,
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _sendBackendLog({
                              'type': 'buttonClick',
                              'button': 'Modal - Show Solution'
                            });
                            // A wrong move was already made and rejected —
                            // this is a failure, not a skip; recorded once,
                            // here, since the replay itself never was.
                            _submitPuzzleResult(false, showResultDialog: false);
                            _playFullSolutionReplay();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Next Puzzle'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.colors.accent,
                            foregroundColor: context.colors.canvas,
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _sendBackendLog({
                              'type': 'buttonClick',
                              'button': 'Modal - Next Puzzle'
                            });
                            // Same reasoning as "Show Solution" above: a wrong
                            // move already happened, so giving up here is a
                            // failure, not a skip.
                            _submitPuzzleResult(false, showResultDialog: false);
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
      _rootSolutionsTree =
          Map<String, dynamic>.from(_currentPuzzle!['solutions']);
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
      'button': 'Action - Show Solution (Auto Replay)',
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
      _rootSolutionsTree =
          Map<String, dynamic>.from(_currentPuzzle!['solutions']);
      _currentSolutionsNode = Map<String, dynamic>.from(_rootSolutionsTree);
    }
    _activeBranchPoints.clear();

    Map<String, dynamic> current =
        Map<String, dynamic>.from(_rootSolutionsTree);

    while (current.isNotEmpty) {
      final userMove = current.keys.first;
      final from = userMove.substring(0, 2);
      final to = userMove.substring(2, 4);
      final promo = userMove.length > 4 ? userMove[4] : null;

      await _pause(const Duration(milliseconds: 800));
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

        await _pause(const Duration(milliseconds: 800));
        if (!mounted) return;

        _puzzleGame!
            .move({'from': oppFrom, 'to': oppTo, 'promotion': oppPromo});
        final replayOppPiece = _puzzleGame!.get(oppTo);
        if (replayOppPiece != null)
          _triggerMoveAnimation(oppFrom, oppTo, replayOppPiece);
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

  /// The counterpart to [_showEndgameWinDialog], which had none.
  ///
  /// Losing used to be a snackbar in one drill and a victory dialog in the
  /// others. A child who has just been mated deserves the same weight of answer
  /// as one who has just mated — and, more plainly, needs to be told which of
  /// the two happened.
  void _showEndgameLossDialog() => _showDrillEndedDialog(
        icon: Icons.flag,
        color: context.colors.danger,
        title: 'Checkmate',
        body: 'Stockfish delivered checkmate. Try again.',
      );

  /// A draw ends the drill the way a loss does — it is not the mate the drill
  /// asked for — and says which rule ended it, in the words of [endingLabel].
  void _showEndgameDrawDialog(GameEnding ending) => _showDrillEndedDialog(
        icon: Icons.handshake,
        color: context.colors.warning,
        title: 'Draw',
        body: 'The game is drawn: ${endingLabel(ending)}. Try again.',
      );

  void _showDrillEndedDialog({
    required IconData icon,
    required ui.Color color,
    required String title,
    required String body,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
            onPressed: () {
              Navigator.pop(ctx);
              _resetCurrentPuzzle();
            },
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next Position'),
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

  void _showEndgameWinDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: context.colors.warning, size: 28),
            SizedBox(width: AppSpacing.sm),
            Text('🎉 VICTORY!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
            'Congratulations! You successfully checkmated Stockfish!'),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next Position'),
            style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accentAlt,
                foregroundColor: context.colors.canvas),
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

  /// Ends an assigned game: posts the moves, then says what happened.
  ///
  /// **Do the thing, then say it** (`CLAUDE.md`, "the recurring bug"): the
  /// post is sent — and awaited — before the dialog opens, and a failed post
  /// is reported through [_showSnackBar] (`AppFeedback`, which cannot throw)
  /// rather than left to take the dialog down with it. The verdict shown is
  /// the one this screen read off its own board; the server judges the same
  /// moves again and answers with its own, which this screen does not need
  /// back to tell the student what just happened.
  Future<void> _finishEngineGame(EngineGameVerdict verdict) async {
    if (_engineGameFinished) return;
    _engineGameFinished = true;
    if (mounted) setState(() {});

    final assignmentId = widget.assignmentId;
    if (assignmentId != null) {
      try {
        final res = await http.post(
          Uri.parse('$backendUrl/api/assignments/$assignmentId/game-result'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${widget.userSession.token}',
          },
          body: jsonEncode({
            'moves': List<String>.from(_engineGameMoves),
            if (verdict.ending == GameEnding.resignation) 'resigned': true,
          }),
        );
        if (res.statusCode != 200) {
          _showSnackBar(
              'This result could not be recorded (HTTP ${res.statusCode}).');
        }
      } catch (e) {
        _showSnackBar('This result could not be recorded.');
      }
    }

    _showEngineGameEndedDialog(verdict);
  }

  /// The Resign button: ends the game with `resigned: true`, whatever the
  /// board says (the same rule `verdictFor` already applies to a drill).
  void _resignEngineGame() {
    if (_selectedCategory != 'engine_game' ||
        _engineGameTask == null ||
        _engineGameFinished ||
        _puzzleGame == null) {
      return;
    }
    final verdict = engineGameVerdict(
      task: _engineGameTask!,
      game: _puzzleGame!,
      ownMoves: _userMoveCount,
      resigned: true,
    );
    _finishEngineGame(verdict);
  }

  /// Names the ending and says whether the goal was met — the two things the
  /// gate asks this dialog to say (`docs/briefs/BRIEF-DOMACI-FAZA2-APP.md`).
  void _showEngineGameEndedDialog(EngineGameVerdict verdict) {
    if (!mounted) return;
    final ending = verdict.ending!;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              verdict.goalMet ? Icons.emoji_events : Icons.flag,
              color: verdict.goalMet
                  ? context.colors.warning
                  : context.colors.danger,
              size: 28,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(verdict.goalMet ? 'Goal met' : 'Goal not met',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text('The game ended: ${endingLabel(ending)}.'),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back'),
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.initialCategory != null) {
                context.pop();
              } else {
                setState(() => _selectedCategory = null);
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
      'button': 'Action - Try Again',
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

    _rootSolutionsTree =
        Map<String, dynamic>.from(_currentPuzzle!['solutions'] ?? {});
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
      _puzzleOrientation =
          (sideToMove == 'b') ? PlayerColor.black : PlayerColor.white;
    });

    _puzzleBoardController.loadFen(fen);
    if (_selectedCategory != 'mate_puzzle' &&
        (_showEvaluation || _showEvalBar)) {
      _stockfishService.analyzePosition(fen, depth: _analysisDepth);
    }
  }

  /// Posts to `/submit`, which both moves the mate/winning-position rating and
  /// — since the merge of docs/PLAN-NAPREDAK-VEZBI.md phase 1 — writes the
  /// attempt row the hub's progress cards read. Kept as a raw post rather than
  /// `PuzzleAttemptApi.record` so `newRating`/`ratingChange` come back on the
  /// same request that records the attempt.
  ///
  /// [showResultDialog] is false when the caller already shows its own
  /// victory dialog (`_showEndgameWinDialog`, for `winning_position`) — this
  /// still records and updates the rating either way.
  Future<void> _submitPuzzleResult(bool solved,
      {bool skipped = false, bool showResultDialog = true}) async {
    // A skip is neither a solve nor a failure to show on this puzzle — the
    // caller is about to move on and reset both anyway.
    if (!skipped) {
      setState(() {
        _puzzleSolved = solved;
        _puzzleFailed = !solved;
      });
    }

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
          'skipped': skipped,
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

        if (solved && showResultDialog && mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.emoji_events,
                      color: context.colors.warning, size: 28),
                  SizedBox(width: AppSpacing.sm),
                  Text('Puzzle Solved!',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                  'Well done! You played all the moves correctly.\nNew rating: $newRating (${change >= 0 ? "+" : ""}$change)'),
              actions: [
                OutlinedButton.icon(
                  icon: Icon(Icons.account_tree_outlined,
                      color: context.colors.accent, size: 18),
                  label: Text('Show Solution',
                      style: AppText.bodyLarge
                          .copyWith(color: context.colors.accent)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _showSolutionTree = true;
                    });
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: const Text('Next Puzzle', style: AppText.bodyLarge),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.accent,
                      foregroundColor: context.colors.canvas),
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
    AppFeedback.show(context, () => SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    // Opened as its own destination, back leaves it; opened as the old
    // all-in-one screen, back returns to the list inside it. The second is what
    // is left of the crossroads, and it goes with its last caller.
    final ownRoute = widget.initialCategory != null;
    return PopScope(
      canPop: ownRoute || _selectedCategory == null,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!ownRoute && _selectedCategory != null) {
          _resetEngineState();
          setState(() {
            _selectedCategory = null;
          });
        }
      },
      child: Scaffold(
        // No bar in landscape: that layout is a deliberate square board sized
        // off the window's height, and a bar costs it 38 pixels. The way out
        // there is the arrow in the landscape header, which knows the same
        // thing this one does - see `ownRoute` in _buildPuzzlesTab.
        appBar: isLandscape
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(38.0),
                child: AppBar(
                  toolbarHeight: 38.0,
                  // One arrow, not two. The bar puts its own back button in
                  // when the screen is a pushed route, and this screen already
                  // carries one in its title row.
                  automaticallyImplyLeading: false,
                  title: Row(
                    children: [
                      if (ownRoute || _selectedCategory != null) ...[
                        IconButton(
                          icon: const Icon(Icons.arrow_back, size: 18),
                          padding: EdgeInsets.zero,
                          // The 38px toolbar has just enough room for a tap
                          // target a bit past the bare 18px icon — better
                          // than nothing, though still short of the 48dp
                          // Material guideline (no room for that here).
                          constraints:
                              const BoxConstraints(minWidth: 34, minHeight: 34),
                          // Leaving means leaving. Setting the category back to
                          // null showed the crossroads that still lives inside
                          // this screen - on top of the shell, so the side tabs
                          // were gone and the way out was a screen that no
                          // longer belongs to anybody.
                          onPressed: ownRoute
                              ? () => context.pop()
                              : () {
                                  _resetEngineState();
                                  setState(() {
                                    _selectedCategory = null;
                                  });
                                },
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Icon(Icons.psychology,
                          color: context.colors.warning, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      // Flexible, because the bar now carries two actions:
                      // the title is the part that may give way, and a title
                      // that does not yield clips the controls instead — in a
                      // release build, silently.
                      Flexible(
                        child: Text(
                          _selectedCategory == null
                              ? 'Chess trainer and exercises'
                              : _getCategoryTitle(),
                          style: AppText.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  actions: _selectedCategory == null
                      ? null
                      : [
                          // Reachable in portrait at last: both of these change
                          // how the board is read, and both were built into a
                          // card nothing drew. Sized for a 38 px bar.
                          if (_selectedCategory != 'engine_game')
                            EngineOpponentButton(
                                size: 18, color: context.colors.textMuted),
                          const BoardViewMenu(
                              size: 18, arrows: true, boardSize: true),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                ),
              ),
        // Arrow keys drive the same cursor the strip's buttons do. With no line
        // on the board there is nothing to walk, and the strip is hidden for
        // that same reason.
        body: SafeArea(child: _withMoveKeys(_buildPuzzlesTab())),
      ),
    );
  }

  /// Wraps [child] in the arrow keys when there is a line to walk with them.
  Widget _withMoveKeys(Widget child) {
    final cursor = _moveCursor();
    if (cursor == null) return child;
    // _navigateToNode does its own setState.
    return MoveKeyboardShortcuts(
        cursor: cursor, onChanged: () {}, child: child);
  }

  String _getCategoryTitle() {
    final base = _categoryTitleBase();
    return widget.retry ? '$base — retry' : base;
  }

  String _categoryTitleBase() {
    switch (_selectedCategory) {
      case 'mate_puzzle':
        return 'Mate in 1, 2, or 3';
      case 'basic_mate':
        return 'Basic checkmate practice';
      case 'winning_position':
        return 'Find the winning path';
      case 'engine_game':
        return 'Play it out';
      default:
        return 'Chess trainer and exercises';
    }
  }

  /// The banner's sentence: the goal in words, and for „survive" how many of
  /// the student's own moves are left (`docs/briefs/BRIEF-DOMACI-FAZA2-APP.md`).
  String _engineGameGoalSentence() {
    final task = _engineGameTask;
    if (task == null) return 'Play it out';
    final sideWord = task.side == chess.Color.WHITE ? 'White' : 'Black';
    switch (task.goal) {
      case EngineGameGoal.win:
        return '$sideWord to move — win the game';
      case EngineGameGoal.hold:
        return '$sideWord to move — hold a draw';
      case EngineGameGoal.survive:
        final total = task.surviveMoves ?? 0;
        final remaining = (total - _userMoveCount).clamp(0, total);
        return '$sideWord to move — survive $remaining more of your moves';
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
      onSelectEndgameWin: () =>
          context.push('${AppRoutes.endgamePicker}?mode=win'),
      onSelectEndgameDraw: () =>
          context.push('${AppRoutes.endgamePicker}?mode=draw'),
      onSelectBlunderGames: () => context.push(AppRoutes.blunderGames),
      onSelectRepertoire: () => context.push(AppRoutes.repertoire),
      onSelectMyGames: () => context.push(AppRoutes.archiveHome),
      onSelectMistakesDrill: () => context.push(AppRoutes.archiveMistakes),
    );
  }

  // --- 2. ACTIVE BOARD GAME SCREEN ---

  /// The retry queue's own empty screen — a real answer ("nothing failed"),
  /// not the network failure the ordinary board-loading path would show
  /// (docs/PLAN-NAPREDAK-VEZBI.md §4).
  Widget _buildRetryEmptyState() {
    final ownRoute = widget.initialCategory != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 56, color: context.colors.success),
            const SizedBox(height: 14),
            Text('Nothing to retry.',
                textAlign: TextAlign.center, style: AppText.headline),
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              onPressed: ownRoute
                  ? () => context.pop()
                  : () => setState(() => _selectedCategory = null),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveBoardScreen() {
    if (widget.retry && _retryQueueEmpty) {
      return _buildRetryEmptyState();
    }

    final screenSize = MediaQuery.of(context).size;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final String headerGoal = _selectedCategory == 'mate_puzzle'
        ? '${_puzzleOrientation == PlayerColor.white ? "⚪ White" : "⚫ Black"} to move - Mate in $_selectedMateDepth'
        : (_selectedCategory == 'basic_mate'
            ? 'Practice: $_selectedBasicMateType (Checkmate Stockfish)'
            : (_selectedCategory == 'engine_game'
                ? _engineGameGoalSentence()
                : '${_puzzleOrientation == PlayerColor.white ? "⚪ White" : "⚫ Black"} to move - Find the winning path'));

    // What used to be a „back to selection" card lived here and was never
    // placed in the portrait tree — so its board menu and its opponent button
    // were unreachable on a phone held upright, while the landscape header
    // carried both. The way out is the app bar's arrow; the two controls are
    // now the app bar's actions, and the goal banner is above the board.

    final goalBanner = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.colors.infoContainer,
        borderRadius: AppRadii.roundedLg,
        border: Border.all(
            color: _puzzleOrientation == PlayerColor.white
                ? context.colors.info
                : context.colors.accent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flag,
            size: 18,
            color: _puzzleOrientation == PlayerColor.white
                ? context.colors.onInfoContainer
                : context.colors.accent,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              headerGoal,
              style: AppText.bodyLargeBold
                  .copyWith(color: context.colors.onInfoContainer),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    // Wrap, not Row. Three buttons with words on them outgrow a narrow column,
    // and the navigation test is the first thing that ever rendered this screen
    // at a size nobody had tried. In a release build the overflow paints no
    // warning - the third button is simply not there.
    final actionButtonsRow = Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          icon: const Icon(Icons.biotech, size: 16),
          label: const Text('Analysis 🔬'),
          style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.accentAlt,
              foregroundColor: context.colors.canvas),
          onPressed: _exportToAnalysisStudio,
        ),
        // An assigned game is one attempt, judged by the server: „Try Again"
        // and „Next Position" belong to a drill that can be repeated freely,
        // not to a game a second play of would just be refused (409).
        if (_selectedCategory == 'engine_game') ...[
          if (!_engineGameFinished)
            ElevatedButton.icon(
              icon: const Icon(Icons.flag, size: 16),
              label: const Text('Resign'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.colors.danger,
                  foregroundColor: context.colors.canvas),
              onPressed: _resignEngineGame,
            ),
        ] else ...[
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.warning,
                foregroundColor: context.colors.canvas),
            onPressed: _restartCurrentPuzzle,
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Next Position'),
            style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.accent,
                foregroundColor: context.colors.canvas),
            onPressed: _goToNextPuzzle,
          ),
        ],
      ],
    );

    if (isLandscape) {
      // No app bar in landscape; the one-line header below carries the way
      // out and the actions, and the board takes the rest of the height.
      final landscapeTopHeader = SizedBox(
        height: 24,
        child: Row(
          children: [
            // Landscape hides the AppBar, so without this there is no way out at
            // all on a desktop window - the shell's rail used to be beside this
            // screen and no longer is, because it opens as its own route now.
            if (_selectedCategory != null) ...[
              IconButton(
                icon: Icon(Icons.arrow_back,
                    size: 18, color: context.colors.textPrimary),
                tooltip: widget.initialCategory != null
                    ? 'Back to training'
                    : 'Back to category selection',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                // Reported from the desktop build: this arrow set the category
                // back to null, which drew the crossroads that still lives
                // inside this screen - on top of the shell, so the side tabs
                // were gone. Opened as a route, leaving means leaving.
                onPressed: widget.initialCategory != null
                    ? () => context.pop()
                    : () {
                        _resetEngineState();
                        setState(() {
                          _selectedCategory = null;
                        });
                      },
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                headerGoal,
                style: AppText.captionBold
                    .copyWith(color: context.colors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_selectedCategory != 'engine_game') ...[
              EngineOpponentButton(
                  size: 18, color: context.colors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
            ],
            BoardViewMenu(
                size: 18,
                color: context.colors.textSecondary,
                arrows: true,
                boardSize: true),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: Icon(Icons.biotech,
                  size: 18, color: context.colors.accentAlt),
              tooltip: 'Analyze in Analysis Board 🔬',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _exportToAnalysisStudio,
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon:
                  Icon(Icons.refresh, size: 16, color: context.colors.warning),
              tooltip: 'Try Again',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _restartCurrentPuzzle,
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: Icon(Icons.arrow_forward,
                  size: 16, color: context.colors.accent),
              tooltip: 'Next Position',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: _goToNextPuzzle,
            ),
          ],
        ),
      );

      return Padding(
        padding: const EdgeInsets.only(
            left: AppSpacing.xs, top: AppSpacing.xs, right: AppSpacing.xs),
        child: Column(
          children: [
            landscapeTopHeader,
            Expanded(
              child: LandscapeBoardLayout(
                boardScale: AppSettingsService.instance.boardSizeScale,
                board: (side) => BoardWithCoordinates(
                  size: side,
                  orientation: _puzzleOrientation,
                  builder: _buildBoardWithTapAndHighlights,
                ),
                boardAside: _showEvalBar
                    ? (height) => VerticalEvalBarWidget(
                          eval: _currentRawEval,
                          evalString: _currentEvalString,
                          depth: _currentEvalDepth,
                          height: height,
                          orientation: _puzzleOrientation,
                        )
                    : null,
                panels: Column(
                  children: [
                    // PROMINENT LANDSCAPE CONTROL BUTTONS ON THE RIGHT SIDE PANEL
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.biotech, size: 16),
                            label: const Text('Analysis 🔬',
                                style: AppText.captionBold),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.colors.accentAlt,
                              foregroundColor: context.colors.canvas,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: AppSpacing.xs),
                            ),
                            onPressed: _exportToAnalysisStudio,
                          ),
                        ),
                        if (_selectedCategory == 'engine_game') ...[
                          if (!_engineGameFinished) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.flag, size: 16),
                                label: const Text('Resign',
                                    style: AppText.captionBold),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.colors.danger,
                                  foregroundColor: context.colors.canvas,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: AppSpacing.xs),
                                ),
                                onPressed: _resignEngineGame,
                              ),
                            ),
                          ],
                        ] else ...[
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.refresh, size: 16),
                              label: const Text('Try again',
                                  style: AppText.captionBold),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.colors.warning,
                                foregroundColor: context.colors.canvas,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: AppSpacing.xs),
                              ),
                              onPressed: _restartCurrentPuzzle,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.arrow_forward, size: 16),
                              label: const Text('Next position',
                                  style: AppText.captionBold),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.colors.accent,
                                foregroundColor: context.colors.canvas,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: AppSpacing.xs),
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
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildSolutionTreeSection(),
                    const SizedBox(height: AppSpacing.sm),
                    if (_selectedCategory != 'mate_puzzle')
                      StockfishAnalysisWidget(
                        analysisDepth: _analysisDepth,
                        analysisLines: _analysisLines,
                        onAnalysisDepthChanged: (value) =>
                            _applyAnalysisDials(depth: value),
                        onAnalysisLinesChanged: (value) =>
                            _applyAnalysisDials(lines: value),
                        isEngineEnabled: _showEvaluation,
                        isAllowedToUseEngine: true,
                        isOnline: _stockfishService.isOnline,
                        isCustomEngineActive:
                            _stockfishService.isCustomEngineActive,
                        onOpenSettings: isCustomEngineSupported
                            ? _openEngineSettings
                            : null,
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
                              _stockfishService.setMultiPV(_analysisLines);
                              _stockfishService.analyzePosition(
                                  _puzzleBoardController.getFen(),
                                  depth: _analysisDepth);
                            } else {
                              _engineLinesMap.clear();
                              _engineArrows.clear();
                            }
                          });
                        },
                      ),
                  ],
                ),
                footer: [
                  if (_puzzleMoveTree != null)
                    MoveNavigationControls(cursor: _moveCursor()!),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // PORTRAIT LAYOUT: Static Board & Scrollable Controls Below
    final double boardSize = math.min(screenSize.width - 32.0, 700.0) *
        AppSettingsService.instance.boardSizeScale;

    return Column(
      children: [
        // The sentence naming whose move it is and what is being asked. Built
        // and then dropped when the landscape header took it over; the phone
        // held upright had no goal on screen at all.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: goalBanner,
        ),

        // STATIC NON-SCROLLABLE CHESS BOARD AT TOP
        Padding(
          padding:
              const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
          child: Center(
            child: SizedBox(
              width: boardSize,
              height: boardSize,
              child: Card(
                elevation: 4,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: _isLoadingPuzzle
                      ? const Center(child: CircularProgressIndicator())
                      : BoardWithCoordinates(
                          size: boardSize - 16.0,
                          orientation: _puzzleOrientation,
                          builder: _buildBoardWithTapAndHighlights,
                        ),
                ),
              ),
            ),
          ),
        ),

        // SCROLLABLE CONTROLS & BUTTONS BELOW THE BOARD
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
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
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    actionButtonsRow,
                    const SizedBox(height: AppSpacing.md),
                    if (_selectedCategory != 'mate_puzzle')
                      StockfishAnalysisWidget(
                        analysisDepth: _analysisDepth,
                        analysisLines: _analysisLines,
                        onAnalysisDepthChanged: (value) =>
                            _applyAnalysisDials(depth: value),
                        onAnalysisLinesChanged: (value) =>
                            _applyAnalysisDials(lines: value),
                        isEngineEnabled: _showEvaluation,
                        isAllowedToUseEngine: true,
                        isOnline: _stockfishService.isOnline,
                        isCustomEngineActive:
                            _stockfishService.isCustomEngineActive,
                        onOpenSettings: isCustomEngineSupported
                            ? _openEngineSettings
                            : null,
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
                              _stockfishService.setMultiPV(_analysisLines);
                              _stockfishService.analyzePosition(
                                  _puzzleBoardController.getFen(),
                                  depth: _analysisDepth);
                            } else {
                              _engineLinesMap.clear();
                              _engineArrows.clear();
                            }
                          });
                        },
                      ),
                    const SizedBox(height: AppSpacing.md),
                    _buildSolutionTreeSection(),
                    const SizedBox(height: AppSpacing.md),
                    if (_puzzleMoveTree != null)
                      MoveNavigationControls(
                        cursor: _moveCursor()!,
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
              ignoring: _isOpponentTurn ||
                  _puzzleSolved ||
                  _puzzleFailed ||
                  _gameState != PuzzleGameState.idle,
              child: SkinnedChessBoard(
                controller: _puzzleBoardController,
                boardOrientation: _puzzleOrientation,
                lastMoveFrom: _lastMoveFrom,
                lastMoveTo: _lastMoveTo,
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
                    drawingModeColor: context.colors.accent,
                    badgeBorderColor: context.colors.canvas,
                    // Both lists here come from the engine, so both answer to
                    // the engine switch. This screen drew them unconditionally
                    // until 3.9.2026: the arrows were on the board and the
                    // board menu offered no way to turn them off, which is the
                    // one state a switch must never leave a reader in.
                    arrows: (_showEvaluation &&
                            _selectedCategory != 'mate_puzzle' &&
                            AppSettingsService.instance.showEngineArrows)
                        ? _engineArrows
                        : [],
                    engineArrows: (_showEvaluation &&
                            _selectedCategory != 'mate_puzzle' &&
                            AppSettingsService.instance.showEngineArrows)
                        ? _buildEngineArrowsFromLines(
                            _engineLinesMap.values.toList())
                        : [],
                    boardSize: boardSize,
                    orientation: _puzzleOrientation,
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
                duration: Duration(
                    milliseconds:
                        AppSettingsService.instance.moveAnimationDurationMs),
                onCompleted: () {
                  if (mounted)
                    setState(() => _pendingAnimations.remove(pendingAnim));
                },
              ),
          ],
        ),
      ),
    );
  }

  /// The one cursor this screen is walked by, or null while there is no line to
  /// walk. The strip appears in two layouts here and the arrow keys read the
  /// same thing both times, rather than three copies drifting apart.
  MoveCursor? _moveCursor() {
    final tree = _puzzleMoveTree;
    if (tree == null) return null;
    return MoveTreeCursor(
        moveTree: tree, currentNode: tree.current, onSelect: _navigateToNode);
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
      _stockfishService.analyzePosition(node.fen, depth: _analysisDepth);
    }
  }

  /// The mate-puzzle graph view and the plain-puzzle PGN chip view are
  /// mutually exclusive renderings of the same solutions map; see
  /// [SolutionGraphWidget] and [PgnSolutionTreeWidget].
  Widget _buildSolutionTreeSection() {
    final visible = _showSolutionTree ||
        _puzzleSolved ||
        _puzzleFailed ||
        _isReplayingSolution;
    final solutions = Map<String, dynamic>.from(
      (_currentPuzzle?['solutions'] as Map?)?.cast<String, dynamic>() ?? {},
    );

    if (_selectedCategory == 'mate_puzzle') {
      return SolutionGraphWidget(
        visible: visible,
        initialFen: _initialPuzzleFen,
        solutions: solutions,
        mateDepthLabel: 'Mate in ${int.tryParse(_selectedMateDepth) ?? 1}',
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

  void _onPgnChipSelected(
      String from, String to, String targetFen, String labelSan) {
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
      String? lastFrom = targetNode.moveUci.length >= 4
          ? targetNode.moveUci.substring(0, 2)
          : null;
      String? lastTo = targetNode.moveUci.length >= 4
          ? targetNode.moveUci.substring(2, 4)
          : null;

      if (_initialPuzzleFen != null && _selectedCategory == 'mate_puzzle') {
        final List<SolutionGraphNode> path =
            findPathToGraphNode(_solutionGraphNodesCache, targetNode);
        if (path.isNotEmpty) {
          try {
            final game = chess.Chess.fromFEN(_initialPuzzleFen!);
            for (var n in path) {
              String uciToPlay = n.moveUci;
              if (n.isGrouped && n.groupedOpponentMovesUci.isNotEmpty) {
                final idx = (_selectedGroupedMoveIndices[n.id] ??
                        n.selectedGroupedIndex)
                    .clamp(0, n.groupedOpponentMovesUci.length - 1);
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

    final selectedUci = node.groupedOpponentMovesUci[
        moveIndex.clamp(0, node.groupedOpponentMovesUci.length - 1)];
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

    final String sanLabel =
        (moveIndex >= 0 && moveIndex < node.groupedOpponentMoves.length)
            ? node.groupedOpponentMoves[moveIndex]
            : selectedUci;
    _showSnackBar('Displayed position for opponent move: $sanLabel');
  }
} // end _AiStudioScreenState
