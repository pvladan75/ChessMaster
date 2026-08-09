import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/constants.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';

import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

class AiStudioScreen extends StatefulWidget {
  final UserSession userSession;

  const AiStudioScreen({super.key, required this.userSession});

  @override
  State<AiStudioScreen> createState() => _AiStudioScreenState();
}

class _AiStudioScreenState extends State<AiStudioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ChessBoardController _puzzleBoardController = ChessBoardController();
  final ChessBoardController _analysisBoardController = ChessBoardController();

  final StockfishService _stockfishService = StockfishService();

  // Engine Analysis State
  bool _isEngineEnabled = false;
  String _thinkingMode = 'fast';
  Map<int, AnalysisLine> _engineLinesMap = {};
  List<ChessArrow> _engineArrows = [];

  // Reorganization Category State
  String? _selectedCategory; // null = Selection Hub, 'mate_puzzle', 'basic_mate', 'winning_position'
  String _selectedMateDepth = '2'; // '1', '2', '3'
  String _selectedBasicMateType = 'K+Q vs K';

  // Board & Game State
  String? _activeFen;
  bool _showEvaluation = false;
  bool _isBlindfold = false;
  bool _isBlunderAlertEnabled = false; // Default OFF as requested
  double? _lastPosEval;
  Map<String, dynamic>? _currentPuzzle;
  chess.Chess? _puzzleGame;
  int _userRating = 1500;
  List<String> _expectedMoves = [];
  int _moveIndex = 0;
  bool _isLoadingPuzzle = false;
  bool _puzzleSolved = false;
  bool _puzzleFailed = false;
  int? _lastRatingChange;
  bool _isOpponentTurn = false;
  PlayerColor _puzzleOrientation = PlayerColor.white;
  bool _isProgrammaticMove = false;
  String? _lastMoveFrom;
  String? _lastMoveTo;

  // AI Coach Analysis State
  bool _isAnalyzingAi = false;
  Map<String, dynamic>? _aiAnalysisResult;
  List<ChessArrow> _aiArrows = [];
  Map<String, dynamic>? _stockfishEval;

  final Map<String, String> _basicMatePresets = {
    'K+Q vs K': '4k3/8/8/8/8/8/8/Q3K3 w - - 0 1',
    'K+R vs K': '4k3/8/8/8/8/8/8/R3K3 w - - 0 1',
    'K+2B vs K': '4k3/8/8/8/8/8/8/2BBK3 w - - 0 1',
    'K+B+N vs K': '4k3/8/8/8/8/8/8/1NB1K3 w - - 0 1',
    'K+Q vs K+B': '2b1k3/8/8/8/8/8/8/Q3K3 w - - 0 1',
    'K+Q vs K+R': '2r1k3/8/8/8/8/8/8/Q3K3 w - - 0 1',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initStockfish();
  }

  void _resetEngineState() {
    _stockfishService.stopAnalysis();
    _engineLinesMap.clear();
    _engineArrows.clear();
    _lastPosEval = null;
    _activeFen = null;
    _showEvaluation = false;
  }

  void _sendBackendLog(Map<String, dynamic> details) async {
    try {
      final uri = Uri.parse('$backendUrl/api/puzzles/log');
      await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.userSession.token}',
        },
        body: jsonEncode({'details': details}),
      );
    } catch (_) {}
  }

  Future<void> _initStockfish() async {
    await _stockfishService.initEngine();
    _stockfishService.onEvaluationChanged = (evaluation, bestMove, continuation, multipv) {
      if (mounted) {
        final currentFen = _puzzleBoardController.getFen();
        if (_activeFen != null && _activeFen != currentFen) return;

        double parsedEval = 0.0;
        final numVal = double.tryParse(evaluation);
        if (numVal != null) {
          parsedEval = numVal;
        }

        setState(() {
          _stockfishEval = {
            'evaluation': evaluation,
            'bestMove': bestMove,
            'continuation': continuation,
            'cp': (parsedEval * 100).round()
          };
        });

        // 1. Blunder Alert Check (Eval drop > 1.5 pawns)
        if (_isBlunderAlertEnabled && _lastPosEval != null && numVal != null) {
          final evalDiff = _lastPosEval! - numVal;
          if (evalDiff > 1.5) {
            _showBlunderAlert(evalDiff, numVal);
          }
        }
        _lastPosEval = numVal;

        // 2. Opponent Bot Move Execution (When it is Stockfish's turn to play at kDefaultEngineTargetDepth)
        if (_isOpponentTurn) {
          if (bestMove.isNotEmpty && bestMove != '-' && bestMove.length >= 4) {
            _isOpponentTurn = false; // Prevent duplicate triggers

            print('\n--------------------------------------------------');
            print('[TRAINING_LOG] 1) MOD: $_categoryDisplayName');
            print('[TRAINING_LOG] 3) FEN POZICIJA KOJU ANALIZIRA ENGINE: ${_puzzleGame?.fen}');
            print('[TRAINING_LOG] 5) POTEZ ENGINE-A: $bestMove');
            print('[TRAINING_LOG] 5) OSNOV ODABIRA: Stockfish kalkulacija najbolje linije');
            print('[TRAINING_LOG] 5) DUBINA ANALIZE (DEPTH): $kDefaultEngineTargetDepth');
            print('[TRAINING_LOG] 5) EVALUACIJA POZICIJE: $evaluation (Best: $bestMove)');
            print('--------------------------------------------------\n');

            _sendBackendLog({
              'mode': _categoryDisplayName,
              'dynamicFen': _puzzleGame?.fen,
              'engineMove': bestMove,
              'decisionBasis': 'Stockfish kalkulacija najbolje linije',
              'depth': kDefaultEngineTargetDepth,
              'eval': evaluation,
            });

            Future.delayed(const Duration(milliseconds: 350), () {
              if (!mounted) return;
              _playPuzzleMove(bestMove);
              if (_puzzleGame != null) {
                if (_puzzleGame!.in_checkmate) {
                  if (_selectedCategory == 'basic_mate') {
                    _showSnackBar('❌ Stockfish vam je zadao mat.');
                  } else {
                    setState(() => _puzzleSolved = true);
                    _showEndgameWinDialog();
                  }
                } else if (_puzzleGame!.in_stalemate || _puzzleGame!.in_draw) {
                  _showSnackBar('🤝 Pat / Remi u poziciji.');
                }
              }
            });
          }
        }
      }
    };

    _stockfishService.onMultiPVUpdated = (linesMap) {
      if (mounted) {
        final currentFen = _puzzleBoardController.getFen();
        if (_activeFen != null && _activeFen != currentFen) return;
        setState(() {
          _engineLinesMap = linesMap;
          _engineArrows = _buildArrowsFromEngineLines(linesMap.values.toList());
        });
      }
    };
  }

  void _triggerOpponentBotResponse() async {
    if (_puzzleGame == null || _puzzleGame!.in_checkmate) return;
    setState(() => _isOpponentTurn = true);
    await _stockfishService.initEngine();
    _stockfishService.analyzePosition(_puzzleGame!.fen, depth: kDefaultEngineTargetDepth);
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

  List<ChessArrow> _buildArrowsFromEngineLines(List<AnalysisLine> lines) {
    final List<ChessArrow> arrows = [];
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
    _tabController.dispose();
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

  void _loadBasicMatePreset(String presetKey) {
    _resetEngineState();
    final fen = _basicMatePresets[presetKey] ?? '4k3/8/8/8/8/8/8/Q3K3 w - - 0 1';
    _puzzleGame = chess.Chess.fromFEN(fen);
    _activeFen = fen;

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
      _selectedBasicMateType = presetKey;
      _isLoadingPuzzle = false;
      _puzzleSolved = false;
      _puzzleFailed = false;
      _expectedMoves = [];
      _moveIndex = 0;
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _isOpponentTurn = false;
      _puzzleOrientation = PlayerColor.white;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        try {
          _puzzleBoardController.loadFen(fen);
        } catch (_) {}
      }
    });

    _stockfishService.analyzePosition(fen, depth: kDefaultEngineTargetDepth);
  }

  Future<void> _fetchNextPuzzle() async {
    _resetEngineState();
    final String currentId = _currentPuzzle?['puzzle_id'] ?? '';
    setState(() {
      _isLoadingPuzzle = true;
      _puzzleSolved = false;
      _puzzleFailed = false;
      _lastRatingChange = null;
      _aiAnalysisResult = null;
      _aiArrows = [];
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

        setState(() {
          _currentPuzzle = p;
          _userRating = data['userRating'] ?? 1500;
          _expectedMoves = moves;
          _moveIndex = 0;
        });

        print('\n==================================================');
        print('[TRAINING_LOG] 1) MOD: $_categoryDisplayName');
        print('[TRAINING_LOG] 2) UČITANI FEN: $fen');
        print('[TRAINING_LOG] OČEKIVANI POTEZI (JSON): $moves');
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

        _stockfishService.analyzePosition(fen, depth: kDefaultEngineTargetDepth);
      } else {
        _showSnackBar('Nije moguće učitati poziciju.');
      }
    } catch (e) {
      _showSnackBar('Greška pri učitavanju pozicije.');
    } finally {
      if (mounted) setState(() => _isLoadingPuzzle = false);
    }
  }

  void _playPuzzleMove(String lanMove) {
    if (lanMove.length < 4) return;
    final fromStr = lanMove.substring(0, 2);
    final toStr = lanMove.substring(2, 4);

    _isProgrammaticMove = true;
    try {
      if (_puzzleGame != null) {
        _puzzleGame!.move({'from': fromStr, 'to': toStr, 'promotion': lanMove.length > 4 ? lanMove[4] : 'q'});
        _puzzleBoardController.loadFen(_puzzleGame!.fen);
        _activeFen = _puzzleGame!.fen;
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
    if (_isProgrammaticMove || _puzzleSolved || _puzzleFailed || _isOpponentTurn || _puzzleGame == null) return;

    final currentFen = _puzzleBoardController.getFen();
    if (currentFen == _puzzleGame!.fen) return; // No move made yet

    final String startingFen = _puzzleGame!.fen;

    // Determine move played on board
    String? userLan;
    dynamic matchedMove;

    final currentBoardFen = currentFen.split(' ')[0];
    final currentTurn = currentFen.split(' ')[1];

    for (var m in _puzzleGame!.moves({'verbose': true})) {
      final testGame = chess.Chess.fromFEN(_puzzleGame!.fen);
      testGame.move(m);
      final testBoardFen = testGame.fen.split(' ')[0];
      final testTurn = testGame.fen.split(' ')[1];

      if (currentBoardFen == testBoardFen && currentTurn == testTurn) {
        matchedMove = m;
        final from = m['from'] ?? '';
        final to = m['to'] ?? '';
        final promo = m['promotion'] ?? '';
        userLan = '$from$to$promo';
        break;
      }
    }

    if (matchedMove == null || userLan == null) return;

    _puzzleGame!.move(matchedMove);
    _activeFen = currentFen;

    final fromStr = userLan.substring(0, 2);
    final toStr = userLan.substring(2, 4);
    setState(() {
      _lastMoveFrom = fromStr;
      _lastMoveTo = toStr;
    });

    // --- STEP 1: FAST-TRACK JSON CHECK ---
    final primaryJsonMove = _currentPuzzle?['winning_move_uci'] ?? (_expectedMoves.isNotEmpty ? _expectedMoves[0] : '');
    final bool isFastTrack = (primaryJsonMove.isNotEmpty && userLan == primaryJsonMove);

    print('\n--------------------------------------------------');
    print('[TRAINING_LOG] 1) MOD: $_categoryDisplayName');
    print('[TRAINING_LOG] 3) DINAMIČKA PROMENA FEN-A (PRE POTEZA): $startingFen');
    print('[TRAINING_LOG] 4) POTEZ KORISNIKA: $userLan');
    print('[TRAINING_LOG] 3) NOVI FEN NAKON POTEZA KORISNIKA: $currentFen');
    print('[TRAINING_LOG] FAST-TRACK PROVERA: ${isFastTrack ? "✅ Potez u JSON-u (ODMAH Prihvaćen)" : "⚡ Potez nije u JSON-u, šalje se na Stockfish analizu (depth $kDefaultEngineTargetDepth)"}');
    print('--------------------------------------------------\n');

    _sendBackendLog({
      'mode': _categoryDisplayName,
      'dynamicFen': currentFen,
      'userMove': userLan,
      'fastTrack': isFastTrack,
    });

    if (isFastTrack) {
      if (_selectedCategory == 'mate_puzzle') {
        _moveIndex = 1;
        if (_puzzleGame!.in_checkmate) {
          _submitPuzzleResult(true);
          return;
        }
      } else if (_selectedCategory == 'basic_mate' || _selectedCategory == 'winning_position') {
        if (_puzzleGame!.in_checkmate) {
          setState(() => _puzzleSolved = true);
          _showEndgameWinDialog();
          return;
        }
      }

      // Trigger Opponent Reaction Bot
      _triggerOpponentBotResponse();
      return;
    }

    // --- STEP 2: ENGINE EVALUATION AT kDefaultEngineTargetDepth (18) ---
    setState(() => _isOpponentTurn = true);
    await _stockfishService.initEngine();
    _stockfishService.analyzePosition(_puzzleGame!.fen, depth: kDefaultEngineTargetDepth);
  }

  void _handleMatePuzzleMove(String userLan) {
    if (_expectedMoves.isEmpty) return;
    final expectedLan = _expectedMoves[_moveIndex];

    if (userLan == expectedLan) {
      _moveIndex++;
      if (_puzzleGame!.in_checkmate) {
        _submitPuzzleResult(true);
      } else if (_moveIndex < _expectedMoves.length) {
        final engineResponseMove = _expectedMoves[_moveIndex];
        print('\n--------------------------------------------------');
        print('[TRAINING_LOG] 1) MOD: $_categoryDisplayName');
        print('[TRAINING_LOG] 3) FEN POZICIJA KOJU ANALIZIRA ENGINE: ${_puzzleGame?.fen}');
        print('[TRAINING_LOG] 5) POTEZ ENGINE-A: $engineResponseMove');
        print('[TRAINING_LOG] 5) OSNOV ODABIRA: Primarni sekvencijalni odgovor iz JSON zagonetke');
        print('[TRAINING_LOG] 5) DUBINA ANALIZE (DEPTH): Instant JSON sekvenca');
        print('--------------------------------------------------\n');

        _sendBackendLog({
          'mode': _categoryDisplayName,
          'dynamicFen': _puzzleGame?.fen,
          'engineMove': engineResponseMove,
          'decisionBasis': 'Primarni sekvencijalni odgovor iz JSON zagonetke',
          'depth': 'Instant JSON sekvenca',
        });

        setState(() => _isOpponentTurn = true);
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          _playPuzzleMove(engineResponseMove);
          _moveIndex++;
          setState(() => _isOpponentTurn = false);

          if (_puzzleGame!.in_checkmate) {
            _submitPuzzleResult(true);
          }
        });
      } else {
        if (_puzzleGame!.in_checkmate) {
          _submitPuzzleResult(true);
        } else {
          setState(() => _puzzleFailed = true);
          _showMatePuzzleFailedDialog();
        }
      }
    } else {
      setState(() => _puzzleFailed = true);
      _showMatePuzzleFailedDialog();
    }
  }

  void _handleBasicMateMove() async {
    if (_puzzleGame!.in_checkmate) {
      setState(() => _puzzleSolved = true);
      _showEndgameWinDialog();
      return;
    } else if (_puzzleGame!.in_stalemate || _puzzleGame!.in_draw) {
      _showSnackBar('🤝 Pat / Remi u poziciji.');
      return;
    }

    _triggerOpponentBotResponse();
  }

  void _handleWinningPositionMove() async {
    if (_puzzleGame!.in_checkmate) {
      setState(() => _puzzleSolved = true);
      _showEndgameWinDialog();
      return;
    }

    _triggerOpponentBotResponse();
  }

  void _showMatePuzzleFailedDialog() {
    if (!mounted) return;

    // Generate full SAN solution sequence
    String fullSolutionSan = '';
    if (_puzzleGame != null && _expectedMoves.isNotEmpty) {
      final tempGame = chess.Chess.fromFEN(_currentPuzzle?['fen'] ?? _puzzleGame!.fen);
      final List<String> sanList = [];
      int moveNum = tempGame.move_number;
      for (int i = 0; i < _expectedMoves.length; i++) {
        final uci = _expectedMoves[i];
        if (uci.length >= 4) {
          final moveObj = tempGame.move({
            'from': uci.substring(0, 2),
            'to': uci.substring(2, 4),
            'promotion': uci.length > 4 ? uci[4] : 'q'
          });
          if (moveObj != null) {
            dynamic lastHist = tempGame.history.last;
            final String san = (lastHist != null && lastHist.move != null)
                ? (lastHist.move.san ?? uci)
                : uci;
            if (i % 2 == 0) {
              sanList.add('$moveNum. $san');
            } else {
              sanList.add(san);
              moveNum++;
            }
          }
        }
      }
      fullSolutionSan = sanList.join(' ');
    }
    if (fullSolutionSan.isEmpty) {
      fullSolutionSan = _currentPuzzle?['winning_move_san'] ?? _expectedMoves.join(' ');
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.cancel, color: Colors.redAccent, size: 28),
            SizedBox(width: 8),
            Text('Netačan Potez!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Potez koji ste odigrali nije tačan.'),
            const SizedBox(height: 12),
            ExpansionTile(
              title: const Text('💡 Prikaži celokupno rešenje', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amberAccent, fontSize: 13)),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: SelectableText(
                    fullSolutionSan,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.tealAccent),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Pokušaj Ponovo'),
            onPressed: () {
              Navigator.pop(ctx);
              _resetCurrentPuzzle();
            },
          ),
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
    _stockfishService.analyzePosition(fen, depth: 16);
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

  // --- AI COACH EXPLANATION ---

  Future<void> _fetchAiExplanation(String fen, {Map<String, dynamic>? evals}) async {
    setState(() => _isAnalyzingAi = true);

    try {
      if (evals == null && (_stockfishEval == null || _stockfishEval!['bestMove'] == null)) {
        _stockfishService.analyzePosition(fen, depth: 16);
        await Future.delayed(const Duration(milliseconds: 2500));
      }

      final activeEval = evals ?? _stockfishEval ?? {};

      final res = await http.post(
        Uri.parse('$backendUrl/api/ai/explain-position'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.userSession.token}'
        },
        body: jsonEncode({
          'fen': fen,
          'evals': activeEval,
          'userLanguage': 'sr',
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _aiAnalysisResult = data;
          _aiArrows = _buildArrowsFromMoves(data['recommendedMoves']);
        });
      } else {
        _showSnackBar('Greška pri dobavljanju AI objašnjenja.');
      }
    } catch (e) {
      _showSnackBar('Greška na mreži pri komunikaciji sa AI Trenerom.');
    } finally {
      if (mounted) setState(() => _isAnalyzingAi = false);
    }
  }

  List<ChessArrow> _buildArrowsFromMoves(dynamic moves) {
    if (moves is! List) return [];
    final List<ChessArrow> arrows = [];
    for (var m in moves) {
      final str = m.toString().replaceAll(' ', '');
      if (str.length >= 4) {
        arrows.add(ChessArrow(
          from: str.substring(0, 2),
          to: str.substring(2, 4),
          colorCode: 'O',
        ));
      }
    }
    return arrows;
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
              Text(_selectedCategory == null ? 'AI Šahovski Trener & Vežbe' : _getCategoryTitle()),
            ],
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.extension), text: 'Vežbanje Zadataka'),
              Tab(icon: Icon(Icons.auto_awesome), text: 'AI Analiza Pozicije'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildPuzzlesTab(),
            _buildAiAnalysisTab(),
          ],
        ),
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
        return 'Vežbanje Zadataka';
    }
  }

  // --- TAB 1: PUZZLES UI ---

  Widget _buildPuzzlesTab() {
    if (_selectedCategory == null) {
      return _buildCategorySelectionHub();
    }
    return _buildActiveBoardScreen();
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
                              'Vežbanje Šahovskih Zadataka',
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
                        spacing: 8,
                        runSpacing: 8,
                        children: _basicMatePresets.keys.map((presetKey) {
                          return OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.purpleAccent),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onPressed: () {
                              _selectedCategory = 'basic_mate';
                              _loadBasicMatePreset(presetKey);
                            },
                            child: Text(presetKey, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          );
                        }).toList(),
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
                      Row(
                        children: [
                          FilterChip(
                            avatar: Icon(_isBlindfold ? Icons.visibility_off : Icons.visibility, size: 16, color: _isBlindfold ? Colors.amberAccent : Colors.grey),
                            label: Text(_isBlindfold ? '🙈 Slepo: ON' : '👁️ Slepo: OFF', style: const TextStyle(fontSize: 11)),
                            selected: _isBlindfold,
                            selectedColor: Colors.amber.shade900.withValues(alpha: 0.4),
                            onSelected: (val) => setState(() => _isBlindfold = val),
                          ),
                          if (_selectedCategory == 'winning_position') ...[
                            const SizedBox(width: 8),
                            FilterChip(
                              avatar: Icon(Icons.warning_amber_rounded, size: 16, color: _isBlunderAlertEnabled ? Colors.redAccent : Colors.grey),
                              label: Text(_isBlunderAlertEnabled ? '🚨 Blunder: ON' : '🚨 Blunder: OFF', style: const TextStyle(fontSize: 11)),
                              selected: _isBlunderAlertEnabled,
                              selectedColor: Colors.red.shade900.withValues(alpha: 0.4),
                              onSelected: (val) => setState(() => _isBlunderAlertEnabled = val),
                            ),
                          ],
                        ],
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
                        Stack(
                          children: [
                            IgnorePointer(
                              ignoring: _isOpponentTurn || _puzzleSolved || _puzzleFailed,
                              child: Opacity(
                                opacity: _isBlindfold ? 0.05 : 1.0,
                                child: ChessBoard(
                                  controller: _puzzleBoardController,
                                  boardOrientation: _puzzleOrientation,
                                  onMove: () {
                                    _onUserPuzzleMoveMade();
                                    _stockfishService.analyzePosition(_puzzleBoardController.getFen(), depth: 16);
                                  },
                                ),
                              ),
                            ),
                            if (_isBlindfold)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.visibility_off, size: 64, color: Colors.amberAccent),
                                          SizedBox(height: 8),
                                          Text('🙈 Šah Na Slepo', style: TextStyle(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                                          Text('Figure su skrivene radi vežbanja vizuelizacije', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: ChessBoardPainter(
                                    arrows: _aiArrows,
                                    boardSize: 320,
                                    orientation: _puzzleOrientation,
                                    lastMoveFrom: _lastMoveFrom,
                                    lastMoveTo: _lastMoveTo,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.psychology, color: Colors.amberAccent),
                              label: const Text('Pitaj AI Trenera'),
                              onPressed: () {
                                _fetchAiExplanation(_puzzleBoardController.getFen());
                              },
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
                        const SizedBox(height: 16),

                        // Stockfish Analysis Widget ("Prikaži evaluaciju") - Only visible when it's User's Turn
                        if (!_isOpponentTurn)
                          StockfishAnalysisWidget(
                            isEngineEnabled: _showEvaluation,
                            isAllowedToUseEngine: true,
                            isOnline: true,
                            isCustomEngineActive: true,
                            thinkingMode: _thinkingMode,
                            lines: _engineLinesMap.values.toList(),
                            orientation: _puzzleOrientation,
                          onToggleEngine: () {
                            setState(() {
                              _showEvaluation = !_showEvaluation;
                              if (_showEvaluation) {
                                _stockfishService.analyzePosition(_puzzleBoardController.getFen(), depth: 16);
                              } else {
                                _engineLinesMap.clear();
                                _engineArrows.clear();
                              }
                            });
                          },
                          onChangeThinkingMode: (mode) {
                            setState(() => _thinkingMode = mode);
                            if (_showEvaluation) {
                              _stockfishService.analyzePosition(_puzzleBoardController.getFen(), depth: mode == 'deep' ? 22 : 16);
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // AI Advice Card
              if (_isAnalyzingAi)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_aiAnalysisResult != null)
                _buildAiAdviceCard(_aiAnalysisResult!),
            ],
          ),
        ),
      ),
    );
  }

  // --- TAB 2: AI ANALYSIS TAB UI ---

  Widget _buildAiAnalysisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          ChessBoard(
                            controller: _analysisBoardController,
                            boardOrientation: PlayerColor.white,
                            onMove: () {
                              final fen = _analysisBoardController.getFen();
                              if (_showEvaluation) {
                                _stockfishService.analyzePosition(fen, depth: 16);
                              }
                            },
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: ChessBoardPainter(
                                  arrows: [..._aiArrows, ...(_showEvaluation ? _engineArrows : [])],
                                  boardSize: 320,
                                  orientation: PlayerColor.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
                        label: const Text('Analiziraj poziciju sa AI Trenerom'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onPressed: () {
                          final fen = _analysisBoardController.getFen();
                          _fetchAiExplanation(fen);
                        },
                      ),
                      const SizedBox(height: 16),
                      // Stockfish 3-Line Analysis Widget for Position Analysis
                      StockfishAnalysisWidget(
                        isEngineEnabled: _showEvaluation,
                        isAllowedToUseEngine: true,
                        isOnline: true,
                        isCustomEngineActive: true,
                        thinkingMode: _thinkingMode,
                        lines: _engineLinesMap.values.toList(),
                        orientation: PlayerColor.white,
                        onToggleEngine: () {
                          setState(() {
                            _showEvaluation = !_showEvaluation;
                            if (_showEvaluation) {
                              _stockfishService.analyzePosition(_analysisBoardController.getFen(), depth: 16);
                            } else {
                              _stockfishService.stopAnalysis();
                              _engineLinesMap.clear();
                              _engineArrows.clear();
                            }
                          });
                        },
                        onChangeThinkingMode: (mode) {
                          setState(() => _thinkingMode = mode);
                          if (_showEvaluation) {
                            _stockfishService.analyzePosition(_analysisBoardController.getFen(), depth: mode == 'deep' ? 22 : 16);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),

              if (_isAnalyzingAi)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_aiAnalysisResult != null)
                _buildAiAdviceCard(_aiAnalysisResult!),
            ],
          ),
        ),
      ),
    );
  }

  // --- AI ADVICE CARD WIDGET ---

  Widget _buildAiAdviceCard(Map<String, dynamic> aiData) {
    return Card(
      elevation: 4,
      color: Colors.deepPurple.shade900.withValues(alpha: 0.85),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome, color: Colors.amberAccent),
                SizedBox(width: 8),
                Text('AI Šahovski Trener - Savet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amberAccent)),
              ],
            ),
            const Divider(height: 20),
            if (aiData['explanation'] != null)
              Text(
                aiData['explanation'],
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            if (aiData['recommendedMoves'] != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: (aiData['recommendedMoves'] as List).map((m) {
                  return Chip(
                    backgroundColor: Colors.teal.shade800,
                    label: Text(m.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
