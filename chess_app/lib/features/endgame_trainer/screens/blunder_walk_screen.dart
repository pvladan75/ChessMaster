import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

// The service re-exports the game model, as it does the drill step.
import '../services/endgame_api_service.dart';

/// Walks a real game from where it first went wrong, stopping at every mistake.
///
/// A separate screen from the trainer because it is a different object. The
/// trainer asks one question of one board; this walks a game — a line of moves,
/// a cursor over it, and several exercises in sequence — and folding the two
/// together would put two unrelated modes in one file.
///
/// Two rules shape it, and both came from watching the trainer being used:
///
/// The board is never turned automatically. Mistakes alternate between the
/// players in real games — three in six moves, black then white then black, in
/// the game the tests use — so turning it at each stop would spin it under the
/// reader. The flip button is there for whoever wants it.
///
/// And moves already seen can be walked over freely, while an unanswered
/// mistake is a wall. The navigation strip gets only the positions up to that
/// wall, so it stops there without knowing why.
class BlunderWalkScreen extends StatefulWidget {
  const BlunderWalkScreen({
    super.key,
    required this.session,
    this.minBlunders,
    this.maxBlunders,
    this.minElo,
    this.maxElo,
    this.material,
    this.api,
  });

  final UserSession session;
  final int? minBlunders;
  final int? maxBlunders;
  final int? minElo;
  final int? maxElo;
  final String? material;

  /// Injected in tests, which have no server.
  final EndgameApiService? api;

  @override
  State<BlunderWalkScreen> createState() => _BlunderWalkScreenState();
}

class _BlunderWalkScreenState extends State<BlunderWalkScreen> {
  final ChessBoardController _boardController = ChessBoardController();

  late final EndgameApiService _api =
      widget.api ?? EndgameApiService(authToken: widget.session.token);

  BlunderWalk? _walk;
  PlayerColor _orientation = PlayerColor.white;
  bool _loading = true;
  String? _error;
  String? _feedback;
  bool _feedbackIsGood = false;

  /// Positions from the opening board to the wall, one per ply plus the start.
  /// Rebuilt whenever the wall moves, which is the only time it changes.
  List<String> _fens = const [];

  @override
  void initState() {
    super.initState();
    _loadNext();
  }

  Future<void> _loadNext() async {
    setState(() {
      _loading = true;
      _error = null;
      _feedback = null;
    });

    final result = await _api.fetchNextGame(
      minBlunders: widget.minBlunders,
      maxBlunders: widget.maxBlunders,
      minElo: widget.minElo,
      maxElo: widget.maxElo,
      material: widget.material,
      excludeId: _walk?.game.id,
    );
    if (!mounted) return;

    if (result.game == null || !result.game!.isPlayable) {
      setState(() {
        _loading = false;
        _error = result.outcome == EndgameFetchOutcome.noneMatch
            ? 'Nema partije koja odgovara traženim uslovima.'
            : 'Trenutno nije moguće dobaviti partiju.';
      });
      return;
    }

    final walk = BlunderWalk(result.game!);
    setState(() {
      _walk = walk;
      _loading = false;
      // The side that has to find something, once, at the start. After that it
      // stays where the reader put it.
      _orientation = _sideToMove(walk.game.startFen) == 'white'
          ? PlayerColor.white
          : PlayerColor.black;
      _feedbackIsGood = false;
      _feedback = null;
    });
    _rebuildLine();
  }

  String _sideToMove(String fen) {
    final parts = fen.split(' ');
    return parts.length < 2 || parts[1] == 'w' ? 'white' : 'black';
  }

  /// Replays the game up to the wall and caches every position on the way.
  void _rebuildLine() {
    final walk = _walk;
    if (walk == null) return;
    final board = chess.Chess.fromFEN(walk.game.startFen);
    final fens = <String>[board.fen];
    for (var ply = 0; ply < walk.frontier; ply++) {
      if (board.move(walk.game.moves[ply]) == false) break;
      fens.add(board.fen);
    }
    setState(() => _fens = fens);
    _showCurrent();
  }

  void _showCurrent() {
    final walk = _walk;
    if (walk == null || _fens.isEmpty) return;
    _boardController.loadFen(_fens[walk.cursor.clamp(0, _fens.length - 1)]);
  }

  void _seek(int index) {
    final walk = _walk;
    if (walk == null) return;
    setState(() {
      walk.seek(index);
      _feedback = null;
    });
    _showCurrent();
  }

  Future<void> _onMove(String from, String to) async {
    final walk = _walk;
    final blunder = walk?.pending;
    if (walk == null || blunder == null) return;
    // Only at the wall, and only on the board the wall stands on.
    if (walk.cursor != blunder.ply) return;

    final board = chess.Chess.fromFEN(blunder.fen);
    final piece = board.get(from);
    final isPromotion = piece != null &&
        piece.type == chess.PieceType.PAWN &&
        (to.endsWith('8') || to.endsWith('1'));
    const promotion = 'q';
    if (board.move({'from': from, 'to': to, 'promotion': promotion}) == false) {
      return;
    }
    final san = board.getHistory().last.toString();
    final uci = isPromotion ? '$from$to$promotion' : '$from$to';

    final verdict = walk.submit(uci, san: san);
    if (!verdict.correct) {
      setState(() {
        _feedbackIsGood = false;
        _feedback = blunder.lostAWin
            ? '$san takođe ispušta dobitak. Probajte drugi potez.'
            : '$san ne drži remi. Probajte drugi potez.';
      });
      _showCurrent();
      return;
    }

    _afterStop(blunder, found: san);
  }

  void _reveal() {
    final walk = _walk;
    final blunder = walk?.pending;
    if (walk == null || blunder == null) return;
    walk.reveal();
    _afterStop(blunder, found: null);
  }

  /// Moves on to the next stop and says what the game did in between.
  void _afterStop(GameBlunder blunder, {String? found}) {
    final walk = _walk!;
    final from = walk.cursor;
    walk.toPending();
    final passed = walk.game.moves.sublist(from, walk.cursor);

    final opening = found == null
        ? 'Držalo je: ${blunder.shouldPlay.join(', ')}.'
        : (blunder.shouldPlay.length == 1
            ? 'Tačno — $found je bio jedini potez.'
            : 'Tačno. Držalo je i: '
                '${blunder.shouldPlay.where((m) => m != found).join(', ')}.');
    final played = 'U partiji je odigrano ${passed.join(' ')}.';

    setState(() {
      _feedbackIsGood = found != null;
      _feedback = walk.isFinished || walk.pending == null
          ? '$opening $played Partija je odigrana do kraja.'
          : '$opening $played';
    });
    _rebuildLine();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(title: const Text('Greške iz partija')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    final walk = _walk;
    if (walk == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Same reasoning as the trainer: the board is square, so the tighter
        // axis bounds it, and a release build paints no warning when a row
        // outgrows the screen.
        final heightBased = (constraints.maxHeight - 320).clamp(180.0, 520.0);
        final widthBased = (constraints.maxWidth - 24).clamp(160.0, 520.0);
        final boardSize = heightBased < widthBased ? heightBased : widthBased;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildHeader(walk),
              const SizedBox(height: 10),
              Center(
                child: BoardWithCoordinates(
                  size: boardSize,
                  orientation: _orientation,
                  builder: (inner) => ChessBoardWithOverlay(
                    controller: _boardController,
                    boardOrientation: _orientation,
                    boardSize: inner,
                    isAllowedToMove: walk.pending != null &&
                        walk.cursor == walk.pending!.ply,
                    isDrawingMode: false,
                    drawingStartSquare: null,
                    arrows: const [],
                    engineArrows: const [],
                    onMove: _onMove,
                    onSquareTapForDrawing: (_) {},
                  ),
                ),
              ),
              const SizedBox(height: 8),
              MoveNavigationControls(
                cursor: LinearMoveCursor(
                  fens: _fens,
                  index: walk.cursor,
                  onSeek: _seek,
                  movesSan: walk.game.moves.take(walk.frontier).toList(),
                ),
                showMoveChips: true,
                onFlipBoard: () => setState(() {
                  _orientation = _orientation == PlayerColor.white
                      ? PlayerColor.black
                      : PlayerColor.white;
                }),
              ),
              if (_feedback != null) ...[
                const SizedBox(height: 8),
                _buildFeedback(),
              ],
              const SizedBox(height: 10),
              _buildControls(walk),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BlunderWalk walk) {
    final blunder = walk.pending;
    final String task;
    if (blunder == null) {
      task = walk.isFinished
          ? 'Partija je prošla — nađeno ${walk.solvedCount} od ${walk.totalCount}'
          : 'Prođite kroz nastavak, pa dalje na sledeću grešku';
    } else if (walk.cursor != blunder.ply) {
      task = 'Vratite se na grešku da biste nastavili';
    } else {
      final who = blunder.side == 'white' ? 'Beli' : 'Crni';
      task = blunder.lostAWin
          ? '$who je ovde odigrao ${blunder.played} i ispustio dobitak'
          : '$who je ovde odigrao ${blunder.played} i izgubio remi';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(task, style: Theme.of(context).textTheme.titleMedium),
        if (blunder != null && walk.cursor == blunder.ply)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              blunder.lostAWin
                  ? 'Nađite potez koji zadržava dobitak.'
                  : 'Nađite potez koji drži remi.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 6),
        // Wrap, not Row: the game label alone can outgrow a narrow phone.
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _chip(walk.game.label),
            _chip('Greške: ${walk.answeredCount}/${walk.totalCount}'),
            if (blunder?.material != null) _chip(blunder!.material!),
          ],
        ),
      ],
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );

  Widget _buildFeedback() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (_feedbackIsGood ? Colors.green : Colors.orange)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(_feedback!, textAlign: TextAlign.center),
      );

  Widget _buildControls(BlunderWalk walk) {
    final blunder = walk.pending;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        // Standing away from an unanswered stop is the one place the strip
        // cannot help, because the wall is behind the cursor rather than ahead
        // of it.
        if (blunder != null && walk.cursor != blunder.ply)
          FilledButton.icon(
            onPressed: () => _seek(blunder.ply),
            icon: const Icon(Icons.error_outline),
            label: const Text('Na grešku'),
          ),
        if (blunder != null && walk.cursor == blunder.ply)
          TextButton.icon(
            onPressed: _reveal,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Pokaži'),
          ),
        FilledButton.icon(
          onPressed: _loadNext,
          icon: const Icon(Icons.arrow_forward),
          label: Text(walk.isFinished ? 'Sledeća partija' : 'Preskoči'),
        ),
      ],
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadNext,
                child: const Text('Pokušaj ponovo'),
              ),
            ],
          ),
        ),
      );
}
