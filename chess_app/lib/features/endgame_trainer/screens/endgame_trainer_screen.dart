import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_flip_button.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/endgame_info_panel.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import '../models/endgame_puzzle.dart';
import '../services/holding_pattern.dart';
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
    this.material,
    this.band,
    this.oppositeOnly = false,
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

  /// What the picker chose: a comma-separated list of material keys, a rating
  /// band, and whether to keep only opposite-bishop positions. All null means
  /// everything, which is what the two quick-start buttons send.
  final String? material;
  final String? band;
  final bool oppositeOnly;

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

  /// True when the drill running is the punishment rather than the position's
  /// own task: the board starts one move later, after the mistake, and the
  /// child plays the side that was wronged.
  bool _punishing = false;

  /// The position as it stood before the move that ended the drill.
  ///
  /// Losing a win on move twenty-eight and being offered only "start again" is
  /// the wrong lesson twice: it throws away twenty-seven moves that were right,
  /// and it teaches that a mistake is final rather than something to look at
  /// and try differently. The count stays visible, so taking a move back is
  /// free but not invisible.
  String? _drillRetryFen;
  int _drillMistakes = 0;

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
      material: widget.material,
      band: widget.band,
      oppositeOnly: widget.oppositeOnly,
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
      _punishing = false;
      _drillEnd = null;
      _drillRetryFen = null;
      _drillMistakes = 0;
      _drillMoves = 0;
      _kept = false;
      _keeping = false;
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
    _beginDrill(
      puzzle.fen,
      punishing: false,
      intro: puzzle.mode == EndgameMode.draw
          ? 'Protivnik igra tablično najbolje i pokušaće da dobije. Držite remi do kraja.'
          : 'Protivnik brani tablično najbolje. Dobitak morate da odigrate do kraja.',
    );
  }

  /// The position one move later, with the mistake already on the board.
  ///
  /// Every blunder is two exercises, and this is the second one. Knowing which
  /// move held is not the same as being able to take what was handed to you -
  /// a child who spots the error and then fails to convert has learned only
  /// half of it. Nothing new is needed on the server: the drill judges whatever
  /// position it is given.
  String? _positionAfterMistake() {
    final puzzle = _solve?.puzzle;
    final played = puzzle?.playedMove;
    if (puzzle == null || played == null || played.isEmpty) return null;
    final board = chess.Chess.fromFEN(puzzle.fen);
    // The move comes from the database as the game recorded it; if this client
    // cannot read that notation, the offer simply is not made.
    if (board.move(played) == false) return null;
    return board.fen;
  }

  /// Only where there is something to take. A draw thrown away can only have
  /// become a loss, so those are exactly the punishable ones; a win that
  /// slipped to a draw leaves nothing to convert, and the position's own task
  /// already covers holding it.
  bool get _canPunish =>
      _solve?.puzzle.mode == EndgameMode.draw &&
      _solve?.puzzle.playedMove != null &&
      (_solve?.puzzle.canBePlayedOut ?? false);

  void _startPunish() {
    final puzzle = _solve?.puzzle;
    final fen = _positionAfterMistake();
    if (puzzle == null || fen == null) return;
    _beginDrill(
      fen,
      punishing: true,
      intro: '${puzzle.playedMove} je upravo odigrano i remi je izgubljen. '
          'Sada je dobitak vaš — odigrajte ga do kraja.',
    );
  }

  void _beginDrill(String fen,
      {required bool punishing, required String intro}) {
    setState(() {
      _drilling = true;
      _punishing = punishing;
      _drillEnd = null;
      _drillRetryFen = null;
      _drillMistakes = 0;
      _drillMoves = 0;
      _hintSquare = null;
      _game = chess.Chess.fromFEN(fen);
      // Whoever has to move is whoever the exercise belongs to, and in the
      // punishment that is the other side of the board from the position's own
      // task.
      _orientation = _game!.turn == chess.Color.WHITE
          ? PlayerColor.white
          : PlayerColor.black;
      _feedbackIsGood = false;
      _feedback = intro;
    });
    _boardController.loadFen(fen);
  }

  /// Puts the board back to just before the move that lost it.
  void _retryDrillMove() {
    final fen = _drillRetryFen;
    if (fen == null) return;
    setState(() {
      _game = chess.Chess.fromFEN(fen);
      _drillEnd = null;
      _drillRetryFen = null;
      _feedbackIsGood = false;
      _feedback = 'Vraćeno na položaj pre tog poteza. Probajte drugi.';
    });
    _boardController.loadFen(fen);
  }

  void _stopDrill() {
    final puzzle = _solve?.puzzle;
    if (puzzle == null) return;
    setState(() {
      _drilling = false;
      _punishing = false;
      _drillEnd = null;
      _drillRetryFen = null;
      _drillMistakes = 0;
      _drillMoves = 0;
      _feedback = null;
      _game = chess.Chess.fromFEN(puzzle.fen);
      _orientation = puzzle.whiteToMove ? PlayerColor.white : PlayerColor.black;
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
      if (step.held) {
        _drillMoves++;
      } else {
        _drillMistakes++;
        _drillRetryFen = fenBefore;
      }
      _drillEnd = step.held ? step.finished : 'lost';
      _feedbackIsGood = step.held;
      _feedback = drillFeedbackText(step);
    });
    _boardController.loadFen(step.fen);
  }

  /// What the moves that hold have in common, when they have anything.
  ///
  /// Said once the answer is known rather than while it is being looked for:
  /// before that it is a hint, and a strong one. Half the positions have no
  /// such shape and get nothing, which is the point - a sentence invented to
  /// fill the space would be worse than the silence.
  String? _lessonFor(EndgamePuzzle puzzle) {
    return holdingLesson(
      fen: puzzle.fen,
      holdingUci: puzzle.winningMoves,
      playedUci: puzzle.playedMove == null
          ? null
          : uciForSan(puzzle.fen, puzzle.playedMove!),
    );
  }

  /// Whether this position has already been kept, so the button says so
  /// rather than quietly saving it twice.
  bool _kept = false;
  bool _keeping = false;

  /// Keeps the position, with everything the screen knows written into it.
  ///
  /// The description is composed rather than asked for. Someone who has just
  /// failed to understand a position will not stop to type why, and everything
  /// worth recording is already on the screen at that moment - what was played,
  /// what held, and the rule behind it. They can add their own later.
  Future<void> _keepForLater() async {
    final puzzle = _solve?.puzzle;
    if (puzzle == null || _kept || _keeping) return;
    setState(() => _keeping = true);

    final held = puzzle.winningMoves.isEmpty
        ? null
        : 'Držalo je: ${_allHoldingSan(puzzle).join(', ')}.';
    final story = _storyText(puzzle);
    final lesson = _lessonFor(puzzle);
    final elo = puzzle.blunderElo == null
        ? null
        : 'Pogrešio igrač od ${puzzle.blunderElo}.';
    final game = puzzle.game?.label;
    final task = puzzle.mode == EndgameMode.draw
        ? 'Zadatak: održati remi.'
        : 'Zadatak: zadržati dobitak.';

    final ok = await _api.keepForLater(
      fen: puzzle.fen,
      title: '${kEndgameTypeNames[puzzle.type] ?? puzzle.type} — nejasno',
      description:
          [task, story, held, lesson, elo, game].whereType<String>().join(' '),
    );
    if (!mounted) return;
    setState(() {
      _keeping = false;
      _kept = ok;
      _feedbackIsGood = ok;
      _feedback = ok
          ? 'Zapamćeno u „Moje pozicije", oznaka „Nejasno".'
          : 'Poziciju trenutno nije moguće sačuvati.';
    });
  }

  /// Every accepted move in notation, for the note that is kept with it.
  List<String> _allHoldingSan(EndgamePuzzle puzzle) {
    final out = <String>[];
    for (final uci in puzzle.winningMoves) {
      if (uci.length < 4) continue;
      final san = _sanFor(puzzle.fen, uci.substring(0, 2), uci.substring(2, 4),
          uci.length > 4 ? uci[4] : 'q');
      if (san != null) out.add(san);
    }
    out.sort();
    return out;
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
      return _withLesson(
        solve.puzzle.winningMoves.length == 1
            ? '$held Bio je to jedini potez.'
            : '$held Našli ste sve poteze koji drže rezultat.',
        solve.puzzle,
      );
    }
    return _withLesson('$held ${movesLeftText(left)}', solve.puzzle);
  }

  String _withLesson(String text, EndgamePuzzle puzzle) {
    final lesson = _lessonFor(puzzle);
    return lesson == null ? text : '$text $lesson';
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
      _feedback = _withLesson(
        rest.isEmpty
            ? 'Nema više poteza koji drže rezultat.'
            : (rest.length == 1
                ? 'Drži i ${rest.first}.'
                : 'Drže i: ${rest.join(', ')}.'),
        puzzle,
      );
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

    final wide = Breakpoints.isWide(context);
    final panel = EndgameInfoPanel(
      title: _taskText(solve.puzzle),
      // The story of the position, then what to do about it. Empty stays
      // null: a blank line under the heading is not the same as no line.
      subtitle: _subtitleText(solve),
      chips: _chips(solve.puzzle),
      message: _feedback,
      messageIsGood: _feedbackIsGood,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: EndgameBoardLayout(
            wide: wide,
            constraints: constraints,
            panel: panel,
            // The buttons under the board; on a phone the panel as well.
            reserveHeight: wide ? 140 : 280,
            builder: (boardSize) {
              return Column(
                children: [
                  Center(
                    child: BoardWithCoordinates(
                      size: boardSize,
                      orientation: _orientation,
                      builder: (inner) => ChessBoardWithOverlay(
                        controller: _boardController,
                        boardOrientation: _orientation,
                        boardSize: inner,
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
                  if (!wide) ...[
                    const SizedBox(height: 12),
                    panel,
                  ],
                  const SizedBox(height: 12),
                  _buildControls(solve),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _taskText(EndgamePuzzle puzzle) {
    final onMove = puzzle.whiteToMove ? 'Beli' : 'Crni';
    if (_drilling) {
      return _punishing
          ? 'Kaznite grešku — odigrajte dobitak do kraja'
          : (puzzle.mode == EndgameMode.draw
              ? 'Igrate do kraja — držite remi'
              : 'Igrate do kraja — odigrajte dobitak');
    }
    return puzzle.mode == EndgameMode.draw
        ? '$onMove na potezu — održite remi'
        : '$onMove na potezu — zadržite dobitak';
  }

  String? _subtitleText(EndgameSolveSession solve) {
    final parts =
        [_storyText(solve.puzzle), _instructionText(solve)].whereType<String>();
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// What to do on the board, said plainly. In the drill it changes every move,
  /// so it is only worth saying while there is a single question standing.
  String? _instructionText(EndgameSolveSession solve) {
    if (_drilling) return null;
    if (solve.isComplete) return null;
    return solve.puzzle.mode == EndgameMode.draw
        ? 'Odigrajte na tabli potez koji drži remi.'
        : 'Odigrajte na tabli potez koji zadržava dobitak.';
  }

  /// What actually happened here, when the position came from a real mistake.
  /// It gives away one move out of thirty-odd and buys the whole point of the
  /// position: somebody stood here and chose wrong.
  String? _storyText(EndgamePuzzle puzzle) {
    if (_drilling || puzzle.playedMove == null) return null;
    final lost = puzzle.mode == EndgameMode.draw
        ? 'remi je izgubljen'
        : 'dobitak je ispušten';
    return 'U partiji je odigrano ${puzzle.playedMove} i $lost.';
  }

  List<String> _chips(EndgamePuzzle puzzle) => [
        kEndgameTypeNames[puzzle.type] ?? puzzle.type,
        'Težina: ${_difficultyLabel(puzzle)}',
        if (puzzle.blunderElo != null) 'Pogrešio: ${puzzle.blunderElo}',
        if (puzzle.isExact) 'Tačno iz tablica',
        if (_drilling && _drillMoves > 0) 'Odigrano: $_drillMoves',
        if (_drilling && _drillMistakes > 0) 'Greške: $_drillMistakes',
        if (!_drilling && _attempted > 0) 'Rešeno: $_solved/$_attempted',
        if (puzzle.game != null) puzzle.game!.label,
      ];

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

  Widget _buildControls(EndgameSolveSession solve) {
    // Wrap for the same reason as the header: three buttons with Serbian labels
    // outgrow a narrow phone, and the overflow would not show in release.
    if (_drilling) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          if (_drillRetryFen != null)
            FilledButton.icon(
              onPressed: _boardLocked ? null : _retryDrillMove,
              icon: const Icon(Icons.undo),
              label: const Text('Vrati potez'),
            ),
          OutlinedButton.icon(
            onPressed:
                _boardLocked ? null : (_punishing ? _startPunish : _startDrill),
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
        // Offered before and after an answer alike. "I found it and still do
        // not see why" is the commoner case than a miss, and the one that
        // slips away.
        TextButton.icon(
          onPressed: _kept || _keeping ? null : _keepForLater,
          icon: Icon(_kept
              ? Icons.bookmark_added_outlined
              : Icons.bookmark_add_outlined),
          label: Text(_kept ? 'Zapamćeno' : 'Zapamti za kasnije'),
        ),
        // Offered whether or not the position has been solved: knowing which
        // move holds the win and being able to finish it are two different
        // things, and a child may want either one first.
        if (solve.puzzle.canBePlayedOut)
          OutlinedButton.icon(
            onPressed: _startDrill,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Odigraj do kraja'),
          ),
        // The other side of the same position, offered next to it.
        if (_canPunish)
          OutlinedButton.icon(
            onPressed: _startPunish,
            icon: const Icon(Icons.gavel),
            label: const Text('Kazni'),
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
