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

  /// True while the position is being played out against a perfect opponent
  /// rather than answered in a single move. The two modes share the board and
  /// nothing else: solving asks "which moves hold the result", playing out asks
  /// "can you actually finish it", and a child who can do the first often
  /// cannot yet do the second.
  bool _drilling = false;

  /// How the drill ended: 'lost' when a move gave the result away, otherwise
  /// whatever the server called it. Null while it is still running.
  String? _drillEnd;

  int _drillMoves = 0;

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
      _drilling = false;
      _drillEnd = null;
      _drillMoves = 0;
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
    if (solve == null || game == null || _boardLocked) return;
    if (_drilling) {
      await _onDrillMove(from, to);
      return;
    }
    // A solved position stops taking moves; a drill does not, because there the
    // point is the moves after the first one.
    if (solve.isComplete) return;

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

  /// Puts the starting position back and plays it out instead of solving it.
  void _startDrill() {
    final puzzle = _solve?.puzzle;
    if (puzzle == null) return;
    setState(() {
      _drilling = true;
      _drillEnd = null;
      _drillMoves = 0;
      _hintSquare = null;
      _game = chess.Chess.fromFEN(puzzle.fen);
      _feedbackIsGood = false;
      _feedback = puzzle.mode == EndgameMode.draw
          ? 'Protivnik igra tablično najbolje i pokušaće da dobije. Držite remi do kraja.'
          : 'Protivnik brani tablično najbolje. Dobitak morate da odigrate do kraja.';
    });
    _boardController.loadFen(puzzle.fen);
  }

  void _stopDrill() {
    final puzzle = _solve?.puzzle;
    if (puzzle == null) return;
    setState(() {
      _drilling = false;
      _drillEnd = null;
      _drillMoves = 0;
      _feedback = null;
      _game = chess.Chess.fromFEN(puzzle.fen);
    });
    _boardController.loadFen(puzzle.fen);
  }

  /// One move of the drill: played, sent, and judged by the server.
  ///
  /// The verdict is not worked out here even though the position is small
  /// enough to look up. It belongs on the server for the same reason the
  /// puzzle's own rating does — a result that arrives from a client is one the
  /// server cannot check — and asking costs nothing extra, since the tables
  /// have to be consulted to answer the child at all.
  Future<void> _onDrillMove(String from, String to) async {
    final game = _game;
    if (game == null || _drillEnd != null) return;

    final isPromotion = _isPromotion(game, from, to);
    const promotion = 'q';

    // Trial move on a copy first, so an illegal drag never leaves the board
    // showing a position the server was never asked about.
    final probe = chess.Chess.fromFEN(game.fen);
    if (probe.move({'from': from, 'to': to, 'promotion': promotion}) == false) {
      return;
    }
    final uci = isPromotion ? '$from$to$promotion' : '$from$to';
    final fenBefore = game.fen;

    setState(() {
      _boardLocked = true;
      _feedbackIsGood = false;
      _feedback = 'Proveravam u tablicama…';
    });

    final result = await _api.judgeDrillMove(fen: fenBefore, move: uci);
    if (!mounted) return;

    if (result.outcome != DrillJudgeOutcome.ok || result.step == null) {
      // Back to where it was. A move nobody judged must not be left standing
      // as though it had been — that is the whole difference this mode sells.
      _boardController.loadFen(fenBefore);
      setState(() {
        _boardLocked = false;
        _feedbackIsGood = false;
        _feedback = result.message ??
            (result.outcome == DrillJudgeOutcome.unavailable
                ? 'Tablica trenutno nije dostupna, pa potez ne može da se presudi. '
                    'Pokušajte za koji trenutak.'
                : 'Taj potez nije moguće presuditi.');
      });
      return;
    }

    final step = result.step!;
    setState(() {
      _game = chess.Chess.fromFEN(step.fen);
      _boardLocked = false;
      _drillMoves++;
      _drillEnd = step.held ? step.finished : 'lost';
      _feedbackIsGood = step.held;
      _feedback = drillFeedbackText(step);
    });
    _boardController.loadFen(step.fen);
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
                    isAllowedToMove: !_boardLocked &&
                        (_drilling ? _drillEnd == null : !solve.isComplete),
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
    final String task;
    if (_drilling) {
      task = puzzle.mode == EndgameMode.draw
          ? 'Igrate do kraja — držite remi'
          : 'Igrate do kraja — odigrajte dobitak';
    } else {
      task = puzzle.mode == EndgameMode.draw
          ? '$onMove na potezu — održite remi'
          : '$onMove na potezu — zadržite dobitak';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(task, style: Theme.of(context).textTheme.titleMedium),
        // What actually happened here, when the position came from a real
        // mistake. It gives away one move out of thirty-odd and buys the whole
        // point of the position: somebody stood here and chose wrong.
        if (!_drilling && puzzle.playedMove != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'U partiji je odigrano ${puzzle.playedMove} i '
              '${puzzle.mode == EndgameMode.draw ? 'remi je izgubljen' : 'dobitak je ispušten'}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
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
            if (puzzle.blunderElo != null)
              _chip('Pogrešio: ${puzzle.blunderElo}'),
            if (puzzle.isExact) _chip('Tačno iz tablica'),
            if (_drilling && _drillMoves > 0) _chip('Odigrano: $_drillMoves'),
            if (!_drilling && _attempted > 0)
              _chip('Rešeno: $_solved/$_attempted'),
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
    if (_drilling) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _boardLocked ? null : _startDrill,
            icon: const Icon(Icons.refresh),
            label: const Text('Ispočetka'),
          ),
          OutlinedButton.icon(
            onPressed: _boardLocked ? null : _stopDrill,
            icon: const Icon(Icons.close),
            label: const Text('Nazad na zadatak'),
          ),
          FilledButton.icon(
            onPressed: _boardLocked ? null : _loadNext,
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Sledeća'),
          ),
        ],
      );
    }

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
        // Offered whether or not the position has been solved: knowing which
        // move holds the win and being able to finish it are two different
        // things, and a child may want either one first.
        if (solve.puzzle.canBePlayedOut)
          OutlinedButton.icon(
            onPressed: _startDrill,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Odigraj do kraja'),
          ),
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
