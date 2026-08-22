import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_flip_button.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import '../models/endgame_puzzle.dart';
import '../services/endgame_api_service.dart';

/// Serbian names for the mined endgame types. The keys are what the database
/// stores and must not be translated there.
const Map<String, String> kEndgameTypeNames = {
  'PawnEnding': 'Pešačke završnice',
  'RookPawnVsRook': 'Top i pešak protiv topa',
  'QueenVsRook': 'Dama protiv topa',
  'BishopVsKnight': 'Lovac protiv skakača',
  'RookBishopVsRook': 'Top i lovac protiv topa',
  'OppositeBishops': 'Raznobojni lovci',
  'DoubleBishopVsBishopKnight': 'Dva lovca protiv lovca i skakača',
};

/// Trains endgame technique on mined positions.
///
/// The difference from the tactics trainer is not cosmetic. A tactics puzzle
/// has one answer and a forced line; an endgame position usually has several
/// moves that hold the result and no forced continuation at all. So this screen
/// accepts any move in [EndgamePuzzle.winningMoves] and asks a single question
/// per position, rather than walking a line.
class EndgameTrainerScreen extends StatefulWidget {
  const EndgameTrainerScreen({
    super.key,
    required this.session,
    this.type,
    this.mode,
    this.maxPieces,
    this.minPawns,
    this.api,
  });

  final UserSession session;

  /// Restricts to one endgame type, for a themed lesson.
  final String? type;

  /// Converting a win and holding a draw are different skills; a lesson usually
  /// wants one of them, not a mixture.
  final EndgameMode? mode;

  final int? maxPieces;
  final int? minPawns;

  /// Injected in tests. A widget test has no server, and the layout is exactly
  /// what needs testing here: a release build paints no overflow warning, so a
  /// row wider than a 360 dp phone is simply clipped and the buttons past the
  /// edge cannot be reached.
  final EndgameApiService? api;

  @override
  State<EndgameTrainerScreen> createState() => _EndgameTrainerScreenState();
}

class _EndgameTrainerScreenState extends State<EndgameTrainerScreen> {
  final ChessBoardController _boardController = ChessBoardController();

  late final EndgameApiService _api =
      widget.api ?? EndgameApiService(authToken: widget.session.token);

  EndgameSolveSession? _solve;
  chess.Chess? _game;
  PlayerColor _orientation = PlayerColor.white;

  bool _loading = true;
  bool _boardLocked = false;
  String? _error;
  String? _feedback;
  bool _feedbackIsGood = false;
  String? _hintSquare;
  int _solved = 0;
  int _attempted = 0;

  /// Accepted moves the user has produced for the current position, across
  /// replays of it. Kept so a second pass can ask for the ones still missing.
  final Set<String> _found = {};

  /// True once the user has asked to see the remaining answers. Revealing is a
  /// choice, not what happens automatically on a solve: a position with three
  /// answers is worth hunting through, and printing them all immediately takes
  /// that away.
  bool _revealed = false;

  /// A replayed position must not be counted twice in the tally, and a second
  /// solve of something already failed must not turn into a clean one.
  bool _countedThisPuzzle = false;

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
      _hintSquare = null;
    });

    final result = await _api.fetchNext(
      type: widget.type,
      mode: widget.mode,
      maxPieces: widget.maxPieces,
      minPawns: widget.minPawns,
      excludeId: _solve?.puzzle.id,
    );
    if (!mounted) return;

    if (!result.hasPuzzle) {
      setState(() {
        _loading = false;
        // The two are said differently on purpose. "Nothing matches" is a fact
        // about the filters and retrying will not help; "unavailable" might
        // pass. Reporting both as one error taught the user the wrong lesson.
        _error = result.outcome == EndgameFetchOutcome.noneMatch
            ? 'Nema završnice koja odgovara traženim uslovima.'
            : 'Trenutno nije moguće dobaviti završnicu.';
      });
      return;
    }

    final puzzle = result.puzzle!;
    setState(() {
      _solve = EndgameSolveSession(puzzle);
      _game = chess.Chess.fromFEN(puzzle.fen);
      // Always from the side that has to solve it. Looking at a rook ending
      // upside down is a needless obstacle for a child.
      _orientation = puzzle.whiteToMove ? PlayerColor.white : PlayerColor.black;
      _loading = false;
      _boardLocked = false;
      _found.clear();
      _revealed = false;
      _countedThisPuzzle = false;
    });
    _boardController.loadFen(puzzle.fen);
  }

  bool _isPromotion(chess.Chess game, String from, String to) {
    final piece = game.get(from);
    if (piece == null || piece.type != chess.PieceType.PAWN) return false;
    final rank = to.substring(1);
    return (piece.color == chess.Color.WHITE && rank == '8') ||
        (piece.color == chess.Color.BLACK && rank == '1');
  }

  String? _sanFor(String fen, String from, String to, String promotion) {
    final probe = chess.Chess.fromFEN(fen);
    final made = probe.move({'from': from, 'to': to, 'promotion': promotion});
    if (made == false) return null;
    final history = probe.getHistory();
    return history.isEmpty ? null : history.last.toString();
  }

  Future<void> _onMove(String from, String to) async {
    final solve = _solve;
    final game = _game;
    if (solve == null || game == null || _boardLocked || solve.isComplete) {
      return;
    }

    final isPromotion = _isPromotion(game, from, to);
    const promotion = 'q';

    // Trial move on a copy: a move that does not hold the result must never
    // disturb the position the user still has to solve.
    final probe = chess.Chess.fromFEN(game.fen);
    if (probe.move({'from': from, 'to': to, 'promotion': promotion}) == false) {
      return;
    }

    final uci = isPromotion ? '$from$to$promotion' : '$from$to';
    final verdict = solve.submit(
      uci,
      san: _sanFor(game.fen, from, to, promotion),
    );

    if (verdict.alreadyFound) {
      setState(() {
        _feedback = 'Taj potez ste već našli. Potražite drugi.';
        _feedbackIsGood = false;
      });
      _boardController.loadFen(game.fen);
      return;
    }

    if (!verdict.correct) {
      setState(() {
        _feedback = solve.puzzle.mode == EndgameMode.draw
            ? 'Taj potez gubi remi. Pokušajte ponovo.'
            : 'Taj potez ispušta dobitak. Pokušajte ponovo.';
        _feedbackIsGood = false;
      });
      _boardController.loadFen(game.fen);
      return;
    }

    game.move({'from': from, 'to': to, 'promotion': promotion});
    final reply = verdict.opponentReply;
    if (reply != null && reply.length >= 4) {
      game.move({
        'from': reply.substring(0, 2),
        'to': reply.substring(2, 4),
        'promotion': 'q',
      });
    }
    _boardController.loadFen(game.fen);

    if (!_countedThisPuzzle) {
      _countedThisPuzzle = true;
      _attempted++;
      if (solve.countsAsSolved) _solved++;
    }

    _found.add(uci);

    setState(() {
      _hintSquare = null;
      _feedbackIsGood = true;
      _feedback = _successText(solve);
    });
  }

  /// Names the other correct moves after a solve.
  ///
  /// A child who found one of two drawing moves should learn that the other one
  /// also draws — that is the lesson of the position, and staying quiet about it
  /// implies their move was the only one.
  String _successText(EndgameSolveSession solve) {
    final held = solve.puzzle.mode == EndgameMode.draw
        ? 'Tačno — remi je održan.'
        : 'Tačno — dobitak je zadržan.';
    final left = _missing(solve.puzzle).length;
    if (left == 0) {
      return solve.puzzle.winningMoves.length == 1
          ? '$held Bio je to jedini potez.'
          : '$held Našli ste sve poteze koji drže rezultat.';
    }
    return left == 1
        ? '$held Postoji još jedan takav potez.'
        : '$held Postoji još $left takvih poteza.';
  }

  /// Accepted moves not yet produced by the user, in UCI.
  List<String> _missing(EndgamePuzzle puzzle) => puzzle.winningMoves
      .where((m) => !_found.any((f) => EndgameSolveSession.sameMove(f, m)))
      .toList();

  /// The remaining answers in notation a person reads. Worked out against the
  /// starting position rather than carried in another column, since the server
  /// sends UCI.
  List<String> _missingSan(EndgamePuzzle puzzle) {
    final result = <String>[];
    for (final uci in _missing(puzzle)) {
      if (uci.length < 4) continue;
      final san = _sanFor(puzzle.fen, uci.substring(0, 2), uci.substring(2, 4),
          uci.length > 4 ? uci[4] : 'q');
      if (san != null) result.add(san);
    }
    return result;
  }

  /// Puts the same position back, asking for an answer not yet found.
  void _huntForTheRest() {
    final puzzle = _solve?.puzzle;
    if (puzzle == null) return;
    setState(() {
      _solve = EndgameSolveSession(puzzle, alreadyFound: Set.of(_found));
      _game = chess.Chess.fromFEN(puzzle.fen);
      _feedback = 'Isti položaj — nađite još jedan potez koji drži rezultat.';
      _feedbackIsGood = false;
      _hintSquare = null;
    });
    _boardController.loadFen(puzzle.fen);
  }

  void _revealRest() {
    final puzzle = _solve?.puzzle;
    if (puzzle == null) return;
    final rest = _missingSan(puzzle);
    setState(() {
      _revealed = true;
      _feedback = rest.isEmpty
          ? 'Nema više poteza koji drže rezultat.'
          : (rest.length == 1
              ? 'Drži i ${rest.first}.'
              : 'Drže i: ${rest.join(', ')}.');
      _feedbackIsGood = true;
    });
  }

  void _showHint() {
    final solve = _solve;
    if (solve == null || solve.isComplete) return;
    setState(() {
      _hintSquare = solve.revealHint();
      _feedback = _hintSquare == null
          ? null
          : 'Potez vodi na polje ${_hintSquare!.toUpperCase()}.';
      _feedbackIsGood = false;
    });
  }

  void _retry() {
    final solve = _solve;
    final game = _game;
    if (solve == null || game == null) return;
    solve.retryAfterMistake();
    setState(() => _feedback = null);
    _boardController.loadFen(game.fen);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text(
          widget.type == null
              ? 'Završnice'
              : (kEndgameTypeNames[widget.type] ?? 'Završnice'),
        ),
        actions: [
          BoardFlipButton(
            onPressed: () => setState(() {
              _orientation = _orientation == PlayerColor.white
                  ? PlayerColor.black
                  : PlayerColor.white;
            }),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();

    final solve = _solve;
    if (solve == null) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        // The board is square, so the tighter axis bounds it. Taking the
        // minimum against the width matters on a short, narrow window, where
        // the height-derived size would otherwise overflow sideways - and a
        // release build paints no warning when it does.
        final heightBased = (constraints.maxHeight - 260).clamp(200.0, 560.0);
        final widthBased = (constraints.maxWidth - 24).clamp(180.0, 560.0);
        final boardSize = heightBased < widthBased ? heightBased : widthBased;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildHeader(solve.puzzle),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: boardSize,
                  height: boardSize,
                  child: ChessBoardWithOverlay(
                    controller: _boardController,
                    boardOrientation: _orientation,
                    boardSize: boardSize,
                    isAllowedToMove: !_boardLocked && !solve.isComplete,
                    isDrawingMode: false,
                    drawingStartSquare: null,
                    arrows: const [],
                    engineArrows: const [],
                    onMove: _onMove,
                    onSquareTapForDrawing: (_) {},
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_feedback != null) _buildFeedback(),
              const SizedBox(height: 12),
              _buildControls(solve),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(EndgamePuzzle puzzle) {
    final onMove = puzzle.whiteToMove ? 'Beli' : 'Crni';
    final task = puzzle.mode == EndgameMode.draw
        ? '$onMove na potezu — održite remi'
        : '$onMove na potezu — zadržite dobitak';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(task, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        // Wrap, not Row: these chips grow with the type name and the game
        // label, and a Row wider than the screen is silently clipped in a
        // release build.
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _chip(kEndgameTypeNames[puzzle.type] ?? puzzle.type),
            _chip('Težina: ${_difficultyLabel(puzzle)}'),
            if (puzzle.isExact) _chip('Tačno iz tablica'),
            if (_attempted > 0) _chip('Rešeno: $_solved/$_attempted'),
            if (puzzle.game != null) _chip(puzzle.game!.label),
          ],
        ),
      ],
    );
  }

  String _difficultyLabel(EndgamePuzzle puzzle) {
    final score = puzzle.difficultyScore;
    if (score != null) return '$score/10';
    switch (puzzle.difficulty) {
      case 'easy':
        return 'lako';
      case 'hard':
        return 'teško';
      default:
        return 'srednje';
    }
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      );

  Widget _buildFeedback() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: (_feedbackIsGood ? Colors.green : Colors.orange).withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(_feedback!, textAlign: TextAlign.center),
    );
  }

  Widget _buildControls(EndgameSolveSession solve) {
    // Wrap for the same reason as the header: three buttons with Serbian labels
    // outgrow a narrow phone, and the overflow would not show in release.
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (solve.status == EndgameSolveStatus.failed)
          OutlinedButton.icon(
            onPressed: _retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Pokušaj ponovo'),
          ),
        if (!solve.isComplete)
          OutlinedButton.icon(
            onPressed: _showHint,
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Pomoć'),
          ),
        // Offered only when there is something left to find, and only as a
        // choice: the position is solved either way.
        if (solve.status == EndgameSolveStatus.solved &&
            _missing(solve.puzzle).isNotEmpty) ...[
          OutlinedButton.icon(
            onPressed: _huntForTheRest,
            icon: const Icon(Icons.replay),
            label: Text('Nađi i ostale (${_found.length}/'
                '${solve.puzzle.winningMoves.length})'),
          ),
          if (!_revealed)
            TextButton.icon(
              onPressed: _revealRest,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Pokaži'),
            ),
        ],
        FilledButton.icon(
          onPressed: _loadNext,
          icon: const Icon(Icons.arrow_forward),
          label: Text(
            solve.status == EndgameSolveStatus.solved ? 'Sledeća' : 'Preskoči',
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
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
}
