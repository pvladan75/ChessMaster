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
  bool _isEngineEnabled = true;
  String _thinkingMode = 'fast';
  Map<int, AnalysisLine> _engineLinesMap = {};
  List<ChessArrow> _engineArrows = [];

  // Puzzle State
  Map<String, dynamic>? _currentPuzzle;
  int _userRating = 1500;
  List<String> _expectedMoves = [];
  int _moveIndex = 0;
  bool _isLoadingPuzzle = false;
  bool _puzzleSolved = false;
  bool _puzzleFailed = false;
  int? _lastRatingChange;
  String _selectedTheme = 'all';
  bool _isOpponentTurn = false;
  PlayerColor _puzzleOrientation = PlayerColor.white;

  // AI Coach Analysis State
  bool _isAnalyzingAi = false;
  Map<String, dynamic>? _aiAnalysisResult;
  List<ChessArrow> _aiArrows = [];
  Map<String, dynamic>? _stockfishEval;

  final List<Map<String, String>> _themeOptions = [
    {'id': 'all', 'label': 'Sve teme'},
    {'id': 'fork', 'label': 'Viljuška (Fork)'},
    {'id': 'pin', 'label': 'Vezivanje (Pin)'},
    {'id': 'discoveredAttack', 'label': 'Otkriveni napad'},
    {'id': 'mateIn1', 'label': 'Mat u 1'},
    {'id': 'mateIn2', 'label': 'Mat u 2'},
    {'id': 'endgame', 'label': 'Završnica'},
    {'id': 'skewer', 'label': 'Rendgen (Skewer)'},
    {'id': 'deflection', 'label': 'Odvlačenje'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchNextPuzzle();
    _initStockfish();
  }

  Future<void> _initStockfish() async {
    await _stockfishService.initEngine();
    _stockfishService.onEvaluationChanged = (evaluation, bestMove, continuation, multipv) {
      if (mounted) {
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
      }
    };

    _stockfishService.onMultiPVUpdated = (linesMap) {
      if (mounted) {
        setState(() {
          _engineLinesMap = linesMap;
          _engineArrows = _buildArrowsFromEngineLines(linesMap.values.toList());
        });
      }
    };
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

  // --- PUZZLE LOGIC ---

  Future<void> _fetchNextPuzzle() async {
    final String currentId = _currentPuzzle?['puzzle_id'] ?? '';
    setState(() {
      _isLoadingPuzzle = true;
      _puzzleSolved = false;
      _puzzleFailed = false;
      _lastRatingChange = null;
      _aiAnalysisResult = null;
      _aiArrows = [];
    });

    try {
      final themeParam = _selectedTheme != 'all' ? '&theme=$_selectedTheme' : '';
      final excludeParam = currentId.isNotEmpty ? '&excludeId=$currentId' : '';
      final uri = Uri.parse('$backendUrl/api/puzzles/next?userId=${widget.userSession.id}$themeParam$excludeParam');
      final res = await http.get(
        uri,
        headers: {'Authorization': 'Bearer ${widget.userSession.token}'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final p = data['puzzle'];
        final fen = p['fen'];
        final moves = List<String>.from(p['moves']);

        setState(() {
          _currentPuzzle = p;
          _userRating = data['userRating'] ?? 1500;
          _expectedMoves = moves;
          _moveIndex = 0;
        });

        _puzzleBoardController.loadFen(fen);

        // Play the setup move if the puzzle sequence starts with opponent move
        if (moves.isNotEmpty) {
          _playPuzzleMove(moves[0], isSetupMove: true);
          _moveIndex = 1;
        }

        // Calculate puzzle orientation from side to move AFTER setup move
        final currentFen = _puzzleBoardController.getFen();
        final sideToMove = currentFen.split(' ')[1];
        setState(() {
          _puzzleOrientation = (sideToMove == 'b') ? PlayerColor.black : PlayerColor.white;
        });

        if (_isEngineEnabled) {
          _stockfishService.analyzePosition(currentFen, depth: 16);
        }
      } else {
        _showSnackBar('Nije moguće učitati zagonetku.');
      }
    } catch (e) {
      _showSnackBar('Greška na mreži pri učitavanju zagonetke.');
    } finally {
      if (mounted) setState(() => _isLoadingPuzzle = false);
    }
  }

  void _playPuzzleMove(String lanMove, {bool isSetupMove = false}) {
    if (lanMove.length < 4) return;
    final fromStr = lanMove.substring(0, 2);
    final toStr = lanMove.substring(2, 4);

    try {
      _puzzleBoardController.makeMove(from: fromStr, to: toStr);
    } catch (e) {
      // Fallback
    }
  }

  void _onUserPuzzleMoveMade() {
    if (_puzzleSolved || _puzzleFailed || _expectedMoves.isEmpty) return;

    final currentFen = _puzzleBoardController.getFen();
    final game = chess.Chess.fromFEN(currentFen);
    final history = game.history;

    if (history.isEmpty) return;
    final lastMove = history.last.move;
    final userLan = '${lastMove.fromAlgebraic}${lastMove.toAlgebraic}';

    final expectedLan = _expectedMoves[_moveIndex];

    if (userLan == expectedLan) {
      _moveIndex++;
      if (_moveIndex >= _expectedMoves.length) {
        // Puzzle solved cleanly!
        _submitPuzzleResult(true);
      } else {
        // Opponent auto-reply
        setState(() => _isOpponentTurn = true);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          _playPuzzleMove(_expectedMoves[_moveIndex]);
          _moveIndex++;
          setState(() => _isOpponentTurn = false);

          if (_moveIndex >= _expectedMoves.length) {
            _submitPuzzleResult(true);
          }
        });
      }
    } else {
      // Wrong move played
      _submitPuzzleResult(false);
    }
  }

  void _resetCurrentPuzzle() {
    if (_currentPuzzle == null) return;
    final fen = _currentPuzzle!['fen'];
    final moves = List<String>.from(_currentPuzzle!['moves']);

    setState(() {
      _puzzleSolved = false;
      _puzzleFailed = false;
      _expectedMoves = moves;
      _moveIndex = 0;
    });

    _puzzleBoardController.loadFen(fen);

    if (moves.isNotEmpty) {
      _playPuzzleMove(moves[0], isSetupMove: true);
      _moveIndex = 1;
    }

    final currentFen = _puzzleBoardController.getFen();
    final sideToMove = currentFen.split(' ')[1];
    setState(() {
      _puzzleOrientation = (sideToMove == 'b') ? PlayerColor.black : PlayerColor.white;
    });

    if (_isEngineEnabled) {
      _stockfishService.analyzePosition(currentFen, depth: 16);
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
          'theme': _selectedTheme != 'all' ? _selectedTheme : null,
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
                  label: const Text('Sledeća Zagonetka'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _fetchNextPuzzle();
                  },
                ),
              ],
            ),
          );
        } else if (!solved && mounted) {
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
              content: Text('Potez koji ste odigrali nije tačan.\nNovi rejting: $newRating (${change >= 0 ? "+" : ""}$change)'),
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
                  label: const Text('Sledeća Zagonetka'),
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
      // Trigger Stockfish engine analysis if evaluation is empty
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.psychology, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text('AI Šahovski Trener & Vežbe'),
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
    );
  }

  // --- TAB 1: PUZZLES UI ---

  Widget _buildPuzzlesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Column(
            children: [
              // Rating Header & Theme Selector
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Vaš Rejting Zagonetki', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text('$_userRating', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.tealAccent)),
                              if (_lastRatingChange != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _lastRatingChange! >= 0 ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${_lastRatingChange! >= 0 ? "+" : ""}$_lastRatingChange',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: _lastRatingChange! >= 0 ? Colors.greenAccent : Colors.redAccent,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                      DropdownButton<String>(
                        value: _selectedTheme,
                        underline: const SizedBox(),
                        items: _themeOptions.map((t) {
                          return DropdownMenuItem<String>(
                            value: t['id'],
                            child: Text(t['label']!, style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedTheme = val);
                            _fetchNextPuzzle();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                                Icons.play_circle_fill,
                                size: 16,
                                color: _puzzleOrientation == PlayerColor.white ? Colors.white : Colors.tealAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _puzzleOrientation == PlayerColor.white ? '⚪ Vi igrate sa BELIM figurama (Na potezu ste)' : '⚫ Vi igrate sa CRNIM figurama (Na potezu ste)',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        Stack(
                          children: [
                            ChessBoard(
                              controller: _puzzleBoardController,
                              boardOrientation: _puzzleOrientation,
                              onMove: () {
                                _onUserPuzzleMoveMade();
                                if (_isEngineEnabled) {
                                  _stockfishService.analyzePosition(_puzzleBoardController.getFen(), depth: 16);
                                }
                              },
                            ),
                            Positioned.fill(
                              child: IgnorePointer(
                                child: CustomPaint(
                                  painter: ChessBoardPainter(
                                    arrows: [..._aiArrows, ...(_isEngineEnabled ? _engineArrows : [])],
                                    boardSize: 320,
                                    orientation: _puzzleOrientation,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Status & Buttons
                        if (_puzzleSolved)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: const [
                                Icon(Icons.check_circle, color: Colors.greenAccent),
                                SizedBox(width: 8),
                                Text('Bravo! Zagonetka je uspešno rešena!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                              ],
                            ),
                          )
                        else if (_puzzleFailed)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                            child: Row(
                              children: const [
                                Icon(Icons.cancel, color: Colors.redAccent),
                                SizedBox(width: 8),
                                Text('Potez nije tačan. Pokušajte ponovo ili pitajte AI Trenera.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
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
                              label: const Text('Sledeća Zagonetka'),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                              onPressed: _fetchNextPuzzle,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Stockfish 3-Line Analysis Widget for Puzzles
                        StockfishAnalysisWidget(
                          isEngineEnabled: _isEngineEnabled,
                          isAllowedToUseEngine: true,
                          isOnline: true,
                          isCustomEngineActive: true,
                          thinkingMode: _thinkingMode,
                          lines: _engineLinesMap.values.toList(),
                          orientation: PlayerColor.white,
                          onToggleEngine: () {
                            setState(() {
                              _isEngineEnabled = !_isEngineEnabled;
                              if (_isEngineEnabled) {
                                _stockfishService.analyzePosition(_puzzleBoardController.getFen(), depth: 16);
                              } else {
                                _stockfishService.stopAnalysis();
                                _engineLinesMap.clear();
                                _engineArrows.clear();
                              }
                            });
                          },
                          onChangeThinkingMode: (mode) {
                            setState(() => _thinkingMode = mode);
                            if (_isEngineEnabled) {
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
                              if (_isEngineEnabled) {
                                _stockfishService.analyzePosition(fen, depth: 16);
                              }
                            },
                          ),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: ChessBoardPainter(
                                  arrows: [..._aiArrows, ...(_isEngineEnabled ? _engineArrows : [])],
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
                        isEngineEnabled: _isEngineEnabled,
                        isAllowedToUseEngine: true,
                        isOnline: true,
                        isCustomEngineActive: true,
                        thinkingMode: _thinkingMode,
                        lines: _engineLinesMap.values.toList(),
                        orientation: PlayerColor.white,
                        onToggleEngine: () {
                          setState(() {
                            _isEngineEnabled = !_isEngineEnabled;
                            if (_isEngineEnabled) {
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
                          if (_isEngineEnabled) {
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
      margin: const EdgeInsets.only(top: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 24),
                const SizedBox(width: 8),
                Text(
                  aiData['keyMotif'] ?? 'AI Savet Trenera',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.amberAccent),
                ),
              ],
            ),
            const Divider(height: 24),
            const Text('Kratak Zaključak:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(aiData['summary'] ?? '', style: const TextStyle(fontSize: 13, height: 1.4)),
            const SizedBox(height: 14),
            const Text('Plan Igre Korak-po-Korak:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            Text(aiData['plan'] ?? '', style: const TextStyle(fontSize: 12, height: 1.4, color: Colors.white70)),
            const SizedBox(height: 14),
            if (aiData['recommendedMoves'] is List) ...[
              const Text('Preporučeni potezi (klikni za animaciju):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: (aiData['recommendedMoves'] as List).map<Widget>((m) {
                  return ActionChip(
                    avatar: const Icon(Icons.play_arrow, size: 14, color: Colors.tealAccent),
                    label: Text(m.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final str = m.toString().replaceAll(' ', '');
                      if (str.length >= 4) {
                        setState(() {
                          _aiArrows = [
                            ChessArrow(
                              from: str.substring(0, 2),
                              to: str.substring(2, 4),
                              colorCode: 'O',
                            )
                          ];
                        });
                      }
                    },
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
