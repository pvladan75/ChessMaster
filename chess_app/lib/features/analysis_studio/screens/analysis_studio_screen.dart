import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/services/stockfish_service.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/features/analysis_studio/services/position_info_service.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/auto_analysis_dialog.dart';

class AnalysisStudioScreen extends StatefulWidget {
  final UserSession userSession;
  final String? initialFen;

  const AnalysisStudioScreen({
    super.key,
    required this.userSession,
    this.initialFen,
  });

  @override
  State<AnalysisStudioScreen> createState() => _AnalysisStudioScreenState();
}

class _AnalysisStudioScreenState extends State<AnalysisStudioScreen> {
  final ChessBoardController _boardController = ChessBoardController();
  final StockfishService _stockfishService = StockfishService();

  late AnalysisNode _rootNode;
  late AnalysisNode _currentNode;
  chess.Chess? _chessGame;

  PlayerColor _orientation = PlayerColor.white;

  // Engine evaluation state
  bool _showEvaluation = false;
  bool _showEvalBar = false;
  double _currentRawEval = 0.0;
  String _currentEvalString = '0.00';
  int _currentEvalDepth = 18;
  Map<int, AnalysisLine> _engineLinesMap = {};
  List<EngineArrow> _engineArrows = [];
  bool _showEngineOverlay = true;

  @override
  void initState() {
    super.initState();
    final startFen = widget.initialFen ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    _initAnalysisTree(startFen);
    _initEngine();
  }

  @override
  void dispose() {
    _stockfishService.dispose();
    super.dispose();
  }

  void _initAnalysisTree(String fen) {
    _rootNode = AnalysisNode(fen: fen);
    _currentNode = _rootNode;
    _chessGame = chess.Chess.fromFEN(fen);
    _boardController.loadFen(fen);
    final side = fen.split(' ')[1];
    _orientation = side == 'b' ? PlayerColor.black : PlayerColor.white;
  }

  Future<void> _initEngine() async {
    await _stockfishService.initEngine();
    _stockfishService.onEvaluationChanged = (evaluation, bestMove, continuation, multipv, depth, isFinal, analyzedFen) {
      if (!mounted) return;
      if (!_showEvaluation && !_showEvalBar) return;

      double parsedEval = 0.0;
      final numVal = double.tryParse(evaluation);
      if (numVal != null) {
        parsedEval = numVal;
      } else if (evaluation.contains('M')) {
        final mateNum = int.tryParse(evaluation.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        parsedEval = evaluation.contains('-') ? (-10000.0 + mateNum) : (10000.0 - mateNum);
      }

      if (multipv == 1) {
        setState(() {
          _currentRawEval = parsedEval;
          _currentEvalString = evaluation;
          _currentEvalDepth = depth;
          _currentNode.eval = parsedEval;
        });
      }
    };

    _stockfishService.onMultiPVUpdated = (linesMap) {
      if (!mounted) return;
      setState(() {
        _engineLinesMap = linesMap;
        _engineArrows = _buildArrowsFromEngineLines(linesMap.values.toList());
      });
    };
  }

  void _triggerEngineAnalysis() {
    if (_showEvaluation || _showEvalBar) {
      final depth = AppSettingsService.instance.defaultEngineDepth;
      _stockfishService.setMultiPV(AppSettingsService.instance.defaultMultiPV);
      _stockfishService.analyzePosition(_currentNode.fen, depth: depth);
    } else {
      _stockfishService.stopAnalysis();
      setState(() {
        _engineLinesMap.clear();
      });
    }
  }

  List<EngineArrow> _buildArrowsFromEngineLines(List<AnalysisLine> lines) {
    if (!_showEngineOverlay || lines.isEmpty) return [];
    final List<EngineArrow> arrows = [];
    for (var line in lines) {
      if (line.bestMoveLan.length >= 4) {
        final from = line.bestMoveLan.substring(0, 2);
        final to = line.bestMoveLan.substring(2, 4);
        arrows.add(EngineArrow(
          from: from,
          to: to,
          evalText: line.evaluation,
          rank: line.multipv,
        ));
      }
    }
    return arrows;
  }

  void _jumpToNode(AnalysisNode node) {
    setState(() {
      _currentNode = node;
      _chessGame = chess.Chess.fromFEN(node.fen);
      _boardController.loadFen(node.fen);
    });
    _triggerEngineAnalysis();
  }

  void _handleUserMove(String from, String to, String promotion) {
    if (_chessGame == null) return;

    final moveMap = {
      'from': from,
      'to': to,
      if (promotion.isNotEmpty) 'promotion': promotion,
    };

    final success = _chessGame!.move(moveMap);
    if (success) {
      String san = '$from$to';
      try {
        final dynamic lastHist = _chessGame!.history.last;
        san = (lastHist.san as String?) ?? '$from$to';
      } catch (_) {}
      final uci = '$from$to${promotion.toLowerCase()}';
      final newFen = _chessGame!.fen;

      final childNode = _currentNode.addChild(
        childFen: newFen,
        san: san,
        uci: uci,
      );

      setState(() {
        _currentNode = childNode;
        _boardController.loadFen(newFen);
      });

      _triggerEngineAnalysis();
    }
  }

  void _goFirst() {
    _jumpToNode(_rootNode);
  }

  void _goPrevious() {
    if (_currentNode.parent != null) {
      _jumpToNode(_currentNode.parent!);
    }
  }

  void _goNext() {
    if (_currentNode.children.isNotEmpty) {
      _jumpToNode(_currentNode.children.first);
    }
  }

  void _goLast() {
    var curr = _currentNode;
    while (curr.children.isNotEmpty) {
      curr = curr.children.first;
    }
    _jumpToNode(curr);
  }

  void _showCommentDialog() {
    final controller = TextEditingController(text: _currentNode.comment);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Dodaj / Izmeni Komentar', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Unesite zabelešku ili analitički komentar...',
            hintStyle: TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.black45,
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Otkaži'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            child: const Text('Sačuvaj'),
            onPressed: () {
              setState(() {
                _currentNode.comment = controller.text.trim();
              });
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showNagSelector() {
    final nags = ['!!', '!', '?', '??', '!?', '!□', 'clear'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8,
              children: nags.map((n) {
                return ActionChip(
                  label: Text(n == 'clear' ? 'Ukloni NAG' : n, style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: n == 'clear' ? Colors.red.shade900 : Colors.teal.shade900,
                  labelStyle: const TextStyle(color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _currentNode.nag = n == 'clear' ? null : n;
                    });
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _showAutoAnalysisDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AutoAnalysisDialog(
        startNode: _currentNode,
        stockfishService: _stockfishService,
        onAnalysisCompleted: () {
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚡ Automatska analiza uspešno završena i sačuvana u stablo!'), backgroundColor: Colors.amber),
          );
        },
      ),
    );
  }

  void _exportPgn() async {
    final pgnText = PgnExporterService.exportToPgn(_rootNode);
    await PgnExporterService.copyToClipboard(pgnText);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Row(
          children: [
            Icon(Icons.file_download, color: Colors.lightBlueAccent),
            SizedBox(width: 8),
            Text('Izvezeni PGN Tekst', style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: SelectableText(
              pgnText,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Zatvori'),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Kopirano u Klipbord!'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showSetupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AnalysisBoardSetupDialog(
        initialFen: _currentNode.fen,
        onPositionSet: (newFen) {
          setState(() {
            _initAnalysisTree(newFen);
          });
          _triggerEngineAnalysis();
        },
        onPgnLoaded: (pgn) {
          _importPgn(pgn);
        },
      ),
    );
  }

  void _importPgn(String pgn) {
    try {
      final tempGame = chess.Chess();
      if (tempGame.load_pgn(pgn)) {
        final newFen = tempGame.fen;
        _initAnalysisTree(newFen);
        _triggerEngineAnalysis();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PGN partija uspešno učitana!'), backgroundColor: Colors.teal),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Neispravan PGN format.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Greška pri uvozu PGN-a: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final double boardSize = isLandscape
        ? math.min(screenSize.height - 120.0, 360.0)
        : math.min(screenSize.width - 32.0, 380.0);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.biotech, color: Colors.tealAccent),
            SizedBox(width: 8),
            Text('Tabla za Analizu (Analysis Studio)'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: Colors.amberAccent),
            tooltip: 'Automatska Analiza ⚡',
            onPressed: _showAutoAnalysisDialog,
          ),
          IconButton(
            icon: const Icon(Icons.share, color: Colors.lightBlueAccent),
            tooltip: 'Izvezi PGN',
            onPressed: _exportPgn,
          ),
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.tealAccent),
            tooltip: 'Unos Pozicije / PGN',
            onPressed: _showSetupDialog,
          ),
          IconButton(
            icon: Icon(
              _orientation == PlayerColor.white ? Icons.rotate_right : Icons.rotate_left,
              color: Colors.amberAccent,
            ),
            tooltip: 'Okreni Tablu',
            onPressed: () {
              setState(() {
                _orientation = _orientation == PlayerColor.white ? PlayerColor.black : PlayerColor.white;
              });
            },
          ),
        ],
      ),
      body: isLandscape ? _buildLandscapeLayout(boardSize) : _buildPortraitLayout(boardSize),
    );
  }

  Widget _buildPortraitLayout(double boardSize) {
    return Column(
      children: [
        // Static Fixed Board at top
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
                  child: _buildBoardWidget(boardSize - 16.0),
                ),
              ),
            ),
          ),
        ),

        // Navigation Toolbar
        _buildNavigationToolbar(),

        // Scrollable Controls Below Board
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                if (_showEvalBar) ...[
                  HorizontalEvalBarWidget(
                    eval: _currentRawEval,
                    evalString: _currentEvalString,
                    depth: _currentEvalDepth,
                    orientation: _orientation,
                  ),
                  const SizedBox(height: 8),
                ],
                                // Position Phase & Syzygy Card
                Builder(
                  builder: (ctx) {
                    final phaseInfo = PositionInfoService.analyzeFen(_currentNode.fen);
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: phaseInfo.isEndgame ? Colors.indigo.shade900 : Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: phaseInfo.isEndgame ? Colors.cyanAccent : Colors.tealAccent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            phaseInfo.isEndgame ? Icons.auto_awesome : Icons.menu_book,
                            color: phaseInfo.isEndgame ? Colors.cyanAccent : Colors.tealAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              phaseInfo.openingName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          if (phaseInfo.isSyzygyReady)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Syzygy Ready',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                AnalysisMoveTreeWidget(
                  rootNode: _rootNode,
                  activeNode: _currentNode,
                  onSelectNode: _jumpToNode,
                  onPromoteNode: (node) {
                    setState(() {
                      node.parent?.promoteToMainLine(node);
                    });
                  },
                  onDeleteNode: (node) {
                    setState(() {
                      node.parent?.removeChild(node);
                      if (_currentNode.id == node.id && node.parent != null) {
                        _jumpToNode(node.parent!);
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                StockfishAnalysisWidget(
                  isEngineEnabled: _showEvaluation,
                  isAllowedToUseEngine: true,
                  isOnline: _stockfishService.isOnline,
                  isCustomEngineActive: _stockfishService.isCustomEngineActive,
                  lines: _engineLinesMap.values.toList(),
                  orientation: _orientation,
                  isShowEvalBarEnabled: _showEvalBar,
                  onToggleShowEvalBar: () {
                    setState(() {
                      _showEvalBar = !_showEvalBar;
                    });
                    _triggerEngineAnalysis();
                  },
                  onToggleEngine: () {
                    setState(() {
                      _showEvaluation = !_showEvaluation;
                    });
                    _triggerEngineAnalysis();
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(double boardSize) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Side: Board & Eval Bar
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: boardSize,
                height: boardSize,
                child: Card(
                  elevation: 4,
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: _buildBoardWidget(boardSize - 12.0),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (_showEvalBar) ...[
                SizedBox(
                  width: boardSize,
                  child: HorizontalEvalBarWidget(
                    eval: _currentRawEval,
                    evalString: _currentEvalString,
                    depth: _currentEvalDepth,
                    orientation: _orientation,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              SizedBox(
                width: boardSize,
                child: _buildNavigationToolbar(),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // Right Side: Tree & Engine Analysis
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                                  // Position Phase & Syzygy Card
                Builder(
                  builder: (ctx) {
                    final phaseInfo = PositionInfoService.analyzeFen(_currentNode.fen);
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: phaseInfo.isEndgame ? Colors.indigo.shade900 : Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: phaseInfo.isEndgame ? Colors.cyanAccent : Colors.tealAccent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            phaseInfo.isEndgame ? Icons.auto_awesome : Icons.menu_book,
                            color: phaseInfo.isEndgame ? Colors.cyanAccent : Colors.tealAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              phaseInfo.openingName,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          if (phaseInfo.isSyzygyReady)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.cyanAccent.shade700,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Syzygy Ready',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                AnalysisMoveTreeWidget(
                    rootNode: _rootNode,
                    activeNode: _currentNode,
                    onSelectNode: _jumpToNode,
                    onPromoteNode: (node) {
                      setState(() {
                        node.parent?.promoteToMainLine(node);
                      });
                    },
                    onDeleteNode: (node) {
                      setState(() {
                        node.parent?.removeChild(node);
                        if (_currentNode.id == node.id && node.parent != null) {
                          _jumpToNode(node.parent!);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  StockfishAnalysisWidget(
                    isEngineEnabled: _showEvaluation,
                    isAllowedToUseEngine: true,
                    isOnline: _stockfishService.isOnline,
                    isCustomEngineActive: _stockfishService.isCustomEngineActive,
                    lines: _engineLinesMap.values.toList(),
                    orientation: _orientation,
                    isShowEvalBarEnabled: _showEvalBar,
                    onToggleShowEvalBar: () {
                      setState(() {
                        _showEvalBar = !_showEvalBar;
                      });
                      _triggerEngineAnalysis();
                    },
                    onToggleEngine: () {
                      setState(() {
                        _showEvaluation = !_showEvaluation;
                      });
                      _triggerEngineAnalysis();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardWidget(double size) {
    return Stack(
      children: [
        ChessBoard(
          controller: _boardController,
          boardOrientation: _orientation,
          onMove: () {
            final history = _boardController.game.history;
            if (history.isNotEmpty) {
              final lastMove = history.last;
              final from = lastMove.move.fromAlgebraic;
              final to = lastMove.move.toAlgebraic;
              final promo = lastMove.move.promotion?.name ?? '';
              _handleUserMove(from, to, promo);
            }
          },
        ),
        if (_showEngineOverlay && _engineArrows.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                size: Size(size, size),
                painter: ChessBoardPainter(
                  arrows: const [],
                  engineArrows: _engineArrows,
                  boardSize: size,
                  orientation: _orientation,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNavigationToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page, size: 20),
            tooltip: 'Početak (<<)',
            onPressed: _currentNode.isRoot ? null : _goFirst,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            tooltip: 'Prethodni Potez (<)',
            onPressed: _currentNode.isRoot ? null : _goPrevious,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            tooltip: 'Sledeći Potez (>)',
            onPressed: _currentNode.children.isEmpty ? null : _goNext,
          ),
          IconButton(
            icon: const Icon(Icons.last_page, size: 20),
            tooltip: 'Kraj Glavne Linije (>>)',
            onPressed: _currentNode.children.isEmpty ? null : _goLast,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.comment, size: 18, color: Colors.lightBlueAccent),
            tooltip: 'Dodaj Komentar',
            onPressed: _showCommentDialog,
          ),
          IconButton(
            icon: const Icon(Icons.style, size: 18, color: Colors.amberAccent),
            tooltip: 'NAG Simboli (!, ?)',
            onPressed: _showNagSelector,
          ),
        ],
      ),
    );
  }
}
