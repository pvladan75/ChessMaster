import 'dart:async';

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
/// And the continuation is played on the board rather than listed under it.
/// After a right answer the board stays where it is and the game plays forward
/// from there, a move at a time, stopping at the next mistake. A row of move
/// buttons would say the same thing in notation, which is the one form a child
/// working on a board does not need it in - and the first version of this
/// screen did exactly that.
///
/// Touching the navigation takes the playback over. From then on the moves are
/// stepped by hand, still no further than the next mistake: an unanswered one
/// is a wall, and the strip is handed only the positions up to it, so it stops
/// there without knowing why.
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

  /// Plays the continuation forward after an answer. Slow enough to follow a
  /// rook across the board and fast enough not to be waited on.
  static const _playbackStep = Duration(milliseconds: 850);

  /// How much of it plays by itself.
  ///
  /// Between two mistakes the gap is usually a move or three and watching it is
  /// the point. After the last one the rest of the game is opened, and that is
  /// another matter: the median tail is eleven moves but a quarter run past
  /// twenty and the longest is a hundred and fifty-five, which at this speed is
  /// two minutes of watching a decided game. So the playback stops here and the
  /// rest stays open to walk through at whatever pace the reader likes.
  static const _maxPlayback = 12;

  Timer? _playback;

  @override
  void dispose() {
    _playback?.cancel();
    super.dispose();
  }

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

    _stopPlayback();
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
    // Reaching for the strip is how the reader says they would rather do this
    // themselves.
    _stopPlayback();
    setState(() {
      walk.seek(index);
      _feedback = null;
    });
    _showCurrent();
  }

  void _stopPlayback() {
    _playback?.cancel();
    _playback = null;
  }

  /// Walks the game forward, one move at a time, as far as it is worth doing
  /// by itself.
  void _playForward() {
    _stopPlayback();
    var played = 0;
    _playback = Timer.periodic(_playbackStep, (timer) {
      final walk = _walk;
      if (!mounted || walk == null || !walk.canGoForward) {
        _stopPlayback();
        return;
      }
      setState(walk.forward);
      _showCurrent();
      played++;
      if (!walk.canGoForward || played >= _maxPlayback) _stopPlayback();
    });
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

  /// Says how it went, then lets the game play on from where the board is.
  ///
  /// The board is not moved to the next mistake. Jumping there would skip the
  /// part worth seeing - what the players actually did with the position - and
  /// it is the part this whole screen exists to show.
  void _afterStop(GameBlunder blunder, {String? found}) {
    final walk = _walk!;

    final verdict = found == null
        ? 'Držalo je: ${blunder.shouldPlay.join(', ')}.'
        : (blunder.shouldPlay.length == 1
            ? 'Tačno — $found je bio jedini potez.'
            : 'Tačno. Držalo je i: '
                '${blunder.shouldPlay.where((m) => m != found).join(', ')}.');

    // The last answer opens the game to its end rather than to the next stop,
    // so it is worth saying which of the two just happened.
    final last = walk.answeredCount == walk.totalCount;
    setState(() {
      _feedbackIsGood = found != null;
      _feedback = last
          ? '$verdict To je bila poslednja greška — ostatak partije je '
              'otključan, prođite kroz njega trakom.'
          : '$verdict Partija se nastavlja onako kako je odigrana.';
    });
    // The wall has moved, so the line the strip walks is longer now.
    _rebuildLine();
    _playForward();
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
                ),
                // No chips. Naming the moves under the board says in notation
                // what the board is already saying in pieces, and it is the
                // form a child working on a board needs least.
                showMoveChips: false,
                centerLabel: 'Potez ${walk.cursor} od ${walk.frontier}',
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
