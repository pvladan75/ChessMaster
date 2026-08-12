import 'package:chess_app/services/app_logger.dart';
import 'package:flutter/services.dart';
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
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/syzygy_panel_widget.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/widgets/opening_explorer_panel_widget.dart';
import 'package:chess_app/features/analysis_studio/services/opening_book_service.dart';
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
  bool _showEvaluation = true;
  bool _showEvalBar = true;
  double _currentRawEval = 0.0;
  String _currentEvalString = '0.00';
  int _currentEvalDepth = 18;
  Map<int, AnalysisLine> _engineLinesMap = {};
  List<EngineArrow> _engineArrows = [];
  bool _showEngineOverlay = true;

  // Syzygy tablebase state
  final SyzygyTablebaseService _syzygyService = SyzygyTablebaseService.instance;
  SyzygyResult? _syzygyResult;
  bool _syzygyLoading = false;
  int _syzygyRequestId = 0;

  // Lichess Opening Explorer state
  final OpeningExplorerService _openingExplorerService = OpeningExplorerService.instance;
  OpeningExplorerResult? _openingExplorerResult;
  bool _openingExplorerLoading = false;
  int _openingExplorerRequestId = 0;
  int? _openingExplorerMinRating;

  @override
  void initState() {
    super.initState();
    final startFen = widget.initialFen ?? 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
    AppLogger.log('[AnalysisStudio] 🎬 initState initialized with FEN: $startFen');
    _initAnalysisTree(startFen);
    _initEngine();
    OpeningBookService.instance.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    // Hands the shared engine back to the screen that pushed this one.
    _stockfishService.detach(this);
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
    _stockfishService.attach(
      this,
      getFen: () => _currentNode.fen,
      isEnabled: () => _showEvaluation || _showEvalBar,
      onEvaluation: (evaluation, bestMove, continuation, multipv, depth, isFinal, analyzedFen) {
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
      },
      onMultiPV: (linesMap) {
        if (!mounted) return;
        setState(() {
          _engineLinesMap = linesMap;
        });
        // Stored candidates take precedence over live lines, so route through
        // the same chooser the navigation path uses.
        _refreshArrows();
      },
    );

    _triggerEngineAnalysis();
  }

  Future<void> _fetchSyzygyIfEligible() async {
    final fen = _currentNode.fen;
    final phaseInfo = PositionInfoService.analyzeFen(fen);
    final reqId = ++_syzygyRequestId;

    if (!phaseInfo.isSyzygyReady) {
      if (_syzygyResult != null || _syzygyLoading) {
        setState(() {
          _syzygyResult = null;
          _syzygyLoading = false;
        });
      }
      return;
    }

    setState(() {
      _syzygyLoading = true;
      _syzygyResult = null;
    });

    final result = await _syzygyService.lookup(fen);
    if (!mounted || reqId != _syzygyRequestId) return;

    setState(() {
      _syzygyResult = result;
      _syzygyLoading = false;
    });
  }

  Future<void> _fetchOpeningExplorerIfEligible() async {
    final token = AppSettingsService.instance.lichessApiToken;
    final reqId = ++_openingExplorerRequestId;
    final hasToken = OpeningExplorerService.hasTokenFor(token);

    AppLogger.log('[OpeningExplorer] 🔍 hasToken=$hasToken | FEN: ${_currentNode.fen}');

    if (!hasToken) {
      AppLogger.log('[OpeningExplorer] ⛔ Nema tokena — preskačem lookup');
      if (_openingExplorerResult != null || _openingExplorerLoading) {
        setState(() {
          _openingExplorerResult = null;
          _openingExplorerLoading = false;
        });
      }
      return;
    }

    setState(() {
      _openingExplorerLoading = true;
      _openingExplorerResult = null;
    });

    final result = await _openingExplorerService.lookup(
      _currentNode.fen,
      token: token,
      minRating: _openingExplorerMinRating,
    );
    if (!mounted || reqId != _openingExplorerRequestId) return;

    AppLogger.log('[OpeningExplorer] 📊 Rezultat: ${result == null ? "null" : "${result.moves.length} poteza, ${result.total} partija"}');

    setState(() {
      _openingExplorerResult = result;
      _openingExplorerLoading = false;
    });
  }

  void _onOpeningExplorerMinRatingChanged(int? minRating) {
    setState(() => _openingExplorerMinRating = minRating);
    _fetchOpeningExplorerIfEligible();
  }

  void _playUciMove(String uci) {
    if (uci.length < 4) return;
    final from = uci.substring(0, 2);
    final to = uci.substring(2, 4);
    final promotion = uci.length > 4 ? uci.substring(4, 5) : '';
    _handleUserMove(from, to, promotion);
  }

  void _triggerEngineAnalysis() {
    AppLogger.log('[AnalysisStudio] ⚡ _triggerEngineAnalysis fired | showEval: $_showEvaluation | showEvalBar: $_showEvalBar | Current FEN: ${_currentNode.fen}');
    _fetchSyzygyIfEligible();
    _fetchOpeningExplorerIfEligible();
    if (_showEvaluation || _showEvalBar) {
      // Validate FEN before sending to engine
      try {
        final testGame = chess.Chess.fromFEN(_currentNode.fen);
        AppLogger.log('[AnalysisStudio] ✅ FEN is valid for chess game: ${_currentNode.fen}');
      } catch (e) {
        AppLogger.log('[AnalysisStudio ERROR] ❌ Invalid FEN string: ${_currentNode.fen} | Error: $e');
      }

      final depth = AppSettingsService.instance.defaultEngineDepth;
      _stockfishService.stopAnalysis();
      _stockfishService.setMultiPV(AppSettingsService.instance.defaultMultiPV);
      _stockfishService.analyzePosition(_currentNode.fen, depth: depth);
    } else {
      AppLogger.log('[AnalysisStudio] ⏸️ Engine evaluation disabled by user switch. Stopping analysis.');
      _stockfishService.stopAnalysis();
      setState(() {
        _engineLinesMap.clear();
        _engineArrows.clear();
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

  /// Builds arrows from the candidate moves already stored under [node].
  ///
  /// After an automatic analysis every node carries its n best replies as
  /// children with their evaluations, so walking the generated tree shows the
  /// candidates at each intermediate step without waiting for the engine to
  /// re-analyze the position.
  List<EngineArrow> _buildArrowsFromChildren(AnalysisNode node) {
    if (!_showEngineOverlay || node.children.isEmpty) return [];

    final isWhiteToMove = node.fen.split(' ').length > 1 && node.fen.split(' ')[1] == 'w';

    // Rank by how good the reply is for the side to move.
    final ranked = node.children.where((c) => c.moveUci != null && c.moveUci!.length >= 4).toList()
      ..sort((a, b) {
        final ea = a.eval;
        final eb = b.eval;
        if (ea == null && eb == null) return 0;
        if (ea == null) return 1;
        if (eb == null) return -1;
        return isWhiteToMove ? eb.compareTo(ea) : ea.compareTo(eb);
      });

    final arrows = <EngineArrow>[];
    for (var i = 0; i < ranked.length; i++) {
      final child = ranked[i];
      final uci = child.moveUci!;
      arrows.add(EngineArrow(
        from: uci.substring(0, 2),
        to: uci.substring(2, 4),
        evalText: child.eval != null
            ? (child.eval! > 0 ? '+${child.eval!.toStringAsFixed(2)}' : child.eval!.toStringAsFixed(2))
            : (child.moveSan ?? ''),
        rank: i + 1,
      ));
    }
    return arrows;
  }

  /// Chooses which candidate arrows to draw for the current node.
  ///
  /// Stored children win when they exist: they are the result the user asked
  /// for after an automatic analysis, and they stay stable while navigating.
  /// Live engine lines cover nodes that have not been expanded yet.
  void _refreshArrows() {
    final stored = _buildArrowsFromChildren(_currentNode);
    setState(() {
      _engineArrows = stored.isNotEmpty
          ? stored
          : _buildArrowsFromEngineLines(_engineLinesMap.values.toList());
    });
  }

  void _jumpToNode(AnalysisNode node) {
    setState(() {
      _currentNode = node;
      _chessGame = chess.Chess.fromFEN(node.fen);
      _boardController.loadFen(node.fen);
      _engineLinesMap.clear();
    });
    // Show this node's stored candidates immediately; the engine may still be
    // several seconds away from producing lines for the new position.
    _refreshArrows();
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
        _engineLinesMap.clear();
      });

      _refreshArrows();
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

  void _showLogsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.terminal, color: Colors.amberAccent),
                SizedBox(width: 8),
                Text('Logovi Engine-a 📜', style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
              tooltip: 'Očisti logove',
              onPressed: () {
                AppLogger.clear();
                (ctx as Element).markNeedsBuild();
              },
            ),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 400,
          child: ValueListenableBuilder<int>(
            valueListenable: AppLogger.logUpdateNotifier,
            builder: (context, _, __) {
              final logs = AppLogger.logs;
              if (logs.isEmpty) {
                return const Center(
                  child: Text('Nema zabeleženih logova.', style: TextStyle(color: Colors.grey)),
                );
              }
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: SingleChildScrollView(
                  reverse: true,
                  child: SelectableText(
                    logs.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Kopiraj Logove'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: AppLogger.formattedLogs));
              if (ctx.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Logovi kopirani u klipbord!'), backgroundColor: Colors.teal),
                );
              }
            },
          ),
          TextButton(
            child: const Text('Zatvori'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showAutoAnalysisDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AutoAnalysisDialog(
        startNode: _currentNode,
        stockfishService: _stockfishService,
        onAnalysisCompleted: () {
          // The start node now has candidate children — surface them as arrows.
          _refreshArrows();
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

  /// Imports a PGN game as a full move tree.
  ///
  /// Replays the game's SAN history onto the analysis tree rather than keeping
  /// only the final position, so the imported game is navigable and can carry
  /// variations, comments and NAGs like any hand-played line.
  void _importPgn(String pgn) {
    try {
      final tempGame = chess.Chess();
      if (!tempGame.load_pgn(pgn)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Neispravan PGN format.'), backgroundColor: Colors.red),
        );
        return;
      }

      // A PGN may start from a custom position via the SetUp/FEN headers.
      final headerFen = tempGame.header['FEN'] as String?;
      final startFen = (headerFen != null && headerFen.trim().isNotEmpty)
          ? headerFen.trim()
          : 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

      // SAN encodes promotions, so replaying by SAN reproduces the game exactly.
      final sanHistory = tempGame.getHistory().cast<String>();

      _initAnalysisTree(startFen);

      final replay = chess.Chess.fromFEN(startFen);
      var node = _rootNode;
      var imported = 0;

      for (final san in sanHistory) {
        if (!replay.move(san)) {
          AppLogger.log('[AnalysisStudio] ⚠️ PGN uvoz zaustavljen na nelegalnom potezu: $san');
          break;
        }
        final moveObj = replay.history.last.move;
        final uci = moveObj.fromAlgebraic +
            moveObj.toAlgebraic +
            (moveObj.promotion?.name ?? '');
        node = node.addChild(childFen: replay.fen, san: san, uci: uci);
        imported++;
      }

      // Land on the final position; the tree is there to walk back through.
      setState(() {
        _currentNode = node;
        _chessGame = chess.Chess.fromFEN(node.fen);
        _boardController.loadFen(node.fen);
      });
      _triggerEngineAnalysis();

      AppLogger.log('[AnalysisStudio] 📥 PGN uvezen: $imported poteza od ${sanHistory.length}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ PGN učitan — $imported poteza u stablu.'),
          backgroundColor: Colors.teal,
        ),
      );
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
        titleSpacing: 8.0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.biotech, color: Colors.tealAccent, size: 20),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Tabla za Analizu',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.terminal, color: Colors.amberAccent),
            tooltip: 'Logovi Engine-a 📜',
            onPressed: _showLogsDialog,
          ),
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
                    final bookEntry = OpeningBookService.instance.lookupByFen(_currentNode.fen);
                    final displayOpeningName = (!phaseInfo.isEndgame && bookEntry != null)
                        ? '${bookEntry.eco} · ${bookEntry.name}'
                        : phaseInfo.openingName;
                    return Column(
                      children: [
                        Container(
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
                                  displayOpeningName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SyzygyPanelWidget(
                          isEligible: phaseInfo.isSyzygyReady,
                          isLoading: _syzygyLoading,
                          result: _syzygyResult,
                          onMoveSelected: _playUciMove,
                        ),
                        OpeningExplorerPanelWidget(
                          hasToken: OpeningExplorerService.hasTokenFor(AppSettingsService.instance.lichessApiToken),
                          isLoading: _openingExplorerLoading,
                          result: _openingExplorerResult,
                          minRating: _openingExplorerMinRating,
                          onMoveSelected: _playUciMove,
                          onMinRatingChanged: _onOpeningExplorerMinRatingChanged,
                        ),
                      ],
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
                    final bookEntry = OpeningBookService.instance.lookupByFen(_currentNode.fen);
                    final displayOpeningName = (!phaseInfo.isEndgame && bookEntry != null)
                        ? '${bookEntry.eco} · ${bookEntry.name}'
                        : phaseInfo.openingName;
                    return Column(
                      children: [
                        Container(
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
                                  displayOpeningName,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SyzygyPanelWidget(
                          isEligible: phaseInfo.isSyzygyReady,
                          isLoading: _syzygyLoading,
                          result: _syzygyResult,
                          onMoveSelected: _playUciMove,
                        ),
                        OpeningExplorerPanelWidget(
                          hasToken: OpeningExplorerService.hasTokenFor(AppSettingsService.instance.lichessApiToken),
                          isLoading: _openingExplorerLoading,
                          result: _openingExplorerResult,
                          minRating: _openingExplorerMinRating,
                          onMoveSelected: _playUciMove,
                          onMinRatingChanged: _onOpeningExplorerMinRatingChanged,
                        ),
                      ],
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
