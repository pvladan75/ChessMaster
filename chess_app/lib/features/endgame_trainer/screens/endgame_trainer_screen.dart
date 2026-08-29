import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/action_key_shortcuts.dart';
import 'package:chess_app/widgets/board_coordinates_button.dart';
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

  /// How many times the tables were opened in this position. Counted for the
  /// same reason a hint is counted in solve mode: a drill played with the
  /// finding in front of you is not the same as one played without it, and the
  /// chips must not read as though it were.
  int _readouts = 0;
  bool _reading = false;

  /// The finding, and the position it belongs to.
  ///
  /// Both, because a readout shown beside a board that has moved on is worse
  /// than no readout: it is a list of moves for a position nobody is looking
  /// at, and every number in it would be read as being about this one.
  TablebaseReadout? _readout;
  String? _readoutFen;

  /// Whether the panel stays open beside the board. Only on a window wide
  /// enough to have a column to spare; a phone gets the dialog, because a panel
  /// under the board there would push the board off the screen.
  bool _readoutOpen = false;

  /// Playing on from the position by hand, with the tables open.
  ///
  /// Not the drill any more, and deliberately so: here a move is not judged,
  /// nothing is counted, and either side may be moved. It is for the question
  /// the drill cannot answer by stopping — "why was that bad" — which is
  /// answered by playing the punishment out and watching it happen.
  bool _exploring = false;

  /// Where to put the board back when the exploring is done.
  String? _exploreFrom;

  /// Moves still to be held after the reader claimed the draw. Null when no
  /// claim is standing.
  int? _holdLeft;
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

  @override
  void dispose() {
    // Leaving the trainer is the reader saying they are done listening. A
    // sentence that outlives the screen it belongs to is how someone decides
    // the whole feature is more trouble than it is worth.
    SpeechService.instance.stop();
    super.dispose();
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
      includeOnline: AppSettingsService.instance.endgameIncludeOnline,
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
      _readouts = 0;
      _exploring = false;
      _exploreFrom = null;
      _readout = null;
      _readoutFen = null;
      _holdLeft = null;
      _drillEnd = null;
      _drillRetryFen = null;
      _drillMistakes = 0;
      _drillMoves = 0;
      _kept = false;
      _keeping = false;
    });
    _boardController.loadFen(puzzle.fen);
  }

  String? _sanFor(String fen, String from, String to, String promotion) {
    final probe = chess.Chess.fromFEN(fen);
    final made = probe.move({'from': from, 'to': to, 'promotion': promotion});
    if (made == false) return null;
    final history = probe.getHistory();
    return history.isEmpty ? null : history.last.toString();
  }

  Future<void> _onMove(String from, String to, String promotion) async {
    // A move is an answer, and an answer ends whatever was still being said.
    SpeechService.instance.stop();
    if (_exploring) {
      _playExploringMove(from, to, promotion);
      return;
    }
    final solve = _solve;
    final game = _game;
    if (solve == null || game == null || _boardLocked) {
      // The board widget has already moved the piece under the user's finger,
      // so a bare `return` leaves it sitting there. See the same guard in the
      // tactics trainer: this is how a refused move turned into a board you
      // could rearrange at will, for both sides.
      if (game != null) _boardController.loadFen(game.fen);
      return;
    }
    if (_drilling) {
      await _onDrillMove(from, to, promotion);
      return;
    }
    // A solved position stops taking moves; a drill does not, because there the
    // point is the moves after the first one.
    if (solve.isComplete) {
      _boardController.loadFen(game.fen);
      return;
    }

    final isPromotion = isPromotionMove(game, from, to);
    // What the reader chose on the board. Falls back to a queen only when the
    // move is a promotion and nothing was passed — an older caller, never the
    // board itself.
    final piece = promotion.isEmpty ? 'q' : promotion;

    // Trial move on a copy: a move that does not hold the result must never
    // disturb the position the user still has to solve.
    final probe = chess.Chess.fromFEN(game.fen);
    if (probe.move({'from': from, 'to': to, 'promotion': piece}) == false) {
      _boardController.loadFen(game.fen);
      return;
    }

    final uci = isPromotion ? '$from$to$piece' : '$from$to';
    final verdict = solve.submit(
      uci,
      san: _sanFor(game.fen, from, to, piece),
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
      // Straight back to the position, with no button in between. The failed
      // status used to stay until "Pokušaj ponovo" was pressed, and while it
      // did the board took drags it then refused — so the position on screen
      // and the position being solved drifted apart. The mistake stays on the
      // record either way, so this costs nothing that was being measured.
      solve.retryAfterMistake();
      setState(() {
        _feedback = solve.puzzle.mode == EndgameMode.draw
            ? 'Taj potez gubi remi. Probajte drugi.'
            : 'Taj potez ispušta dobitak. Probajte drugi.';
        _feedbackIsGood = false;
      });
      _boardController.loadFen(game.fen);
      return;
    }

    game.move({'from': from, 'to': to, 'promotion': piece});
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
    // The button says "back to the task", and the task is not finished while
    // moves are still unfound - one of three, in the report this came from. So
    // it goes back to the task, not to a closed board with a button that has to
    // be discovered: coming out of the drill resumes the hunt on its own.
    // Solved *and* with moves left, which is the same condition the "Nađi i
    // ostale" button appears under. Unsolved is not unfinished in this sense -
    // leaving the drill without having answered goes back to the plain task,
    // not to "find another one".
    final unfinished = _solve?.status == EndgameSolveStatus.solved &&
        _missing(puzzle).isNotEmpty;
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
    if (unfinished) _huntForTheRest();
  }

  /// One move of the drill: played, sent, and judged by the server.
  ///
  /// The verdict is not worked out here even though the position is small
  /// enough to look up. It belongs on the server for the same reason the
  /// puzzle's own rating does — a result that arrives from a client is one the
  /// server cannot check — and asking costs nothing extra, since the tables
  /// have to be consulted to answer the child at all.
  Future<void> _onDrillMove(String from, String to, String promotion) async {
    // Answering is an answer to the sentence too.
    SpeechService.instance.stop();
    final game = _game;
    if (game == null || _drillEnd != null) return;

    final isPromotion = isPromotionMove(game, from, to);
    final piece = promotion.isEmpty ? 'q' : promotion;

    // Trial move on a copy first, so an illegal drag never leaves the board
    // showing a position the server was never asked about.
    final probe = chess.Chess.fromFEN(game.fen);
    if (probe.move({'from': from, 'to': to, 'promotion': piece}) == false) {
      return;
    }
    final uci = isPromotion ? '$from$to$piece' : '$from$to';
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
        if (_holdLeft != null) _holdLeft = _holdLeft! - 1;
      } else {
        _drillMistakes++;
        _drillRetryFen = fenBefore;
      }
      // A claim held to the end closes the drill, and says so in its own
      // words: the position was not proved dead, the reader held it.
      final claimed = _holdLeft != null && _holdLeft! <= 0 && step.held;
      _drillEnd = claimed ? 'draw' : (step.held ? step.finished : 'lost');
      _feedbackIsGood = step.held;
      _feedback = claimed ? holdOutText(0) : drillFeedbackText(step);
      if (claimed || !step.held) _holdLeft = null;
    });
    _boardController.loadFen(step.fen);
    _refreshReadout();
  }

  /// Opens the tables on the position in front of the reader.
  ///
  /// The whole finding, not a chosen move. What makes this drill hard is that
  /// holding and progressing are different things, and that is exactly what the
  /// list shows: which moves keep the result, and which of those get anywhere.
  Future<void> _showReadout({bool wide = false}) async {
    if (wide && _readoutOpen) {
      setState(() {
        _readoutOpen = false;
        _readout = null;
        _readoutFen = null;
      });
      return;
    }
    final readout = await _fetchReadout(counted: true);
    if (readout == null || !mounted) return;
    if (wide) {
      setState(() => _readoutOpen = true);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _ReadoutDialog(readout: readout, onPlay: _playFromReadout),
    );
  }

  /// Asks the tables about the position on the board right now.
  ///
  /// [counted] separates the reader opening the tables from the panel keeping
  /// itself current: one is a use of the help and belongs on the chip, the
  /// other is the same answer refreshed and does not.
  Future<TablebaseReadout?> _fetchReadout({bool counted = false}) async {
    final solve = _solve;
    final game = _game;
    if (solve == null || game == null || _reading) return null;
    final fen = game.fen;
    setState(() => _reading = true);
    final readout = await _api.fetchReadout(
      fen: fen,
      goal: _punishing ? EndgameMode.win : solve.puzzle.mode,
    );
    if (!mounted) return null;
    setState(() {
      _reading = false;
      if (readout != null) {
        _readout = readout;
        _readoutFen = fen;
        if (counted) _readouts++;
      }
    });
    if (readout == null) {
      setState(() {
        _feedbackIsGood = false;
        _feedback = 'Tablica trenutno nije dostupna, pa se nalaz ne može '
            'pročitati.';
      });
    }
    return readout;
  }

  /// Plays a move from the finding, whoever it belongs to.
  ///
  /// The reader asked for this after a losing move: rather than take it back
  /// and never learn anything, play the refutation from the list, answer it on
  /// the board, and keep going until the reason is on the screen. So the first
  /// tap steps out of the drill and into exploring, and the position the drill
  /// stopped at is remembered.
  void _playFromReadout(ReadoutMove move) {
    final game = _game;
    if (game == null) return;
    final board = chess.Chess.fromFEN(game.fen);
    final from = move.uci.substring(0, 2);
    final to = move.uci.substring(2, 4);
    final promotion = move.uci.length > 4 ? move.uci.substring(4, 5) : 'q';
    if (board.move({'from': from, 'to': to, 'promotion': promotion}) == false) {
      return;
    }
    setState(() {
      _exploreFrom ??= game.fen;
      _exploring = true;
      _game = board;
      _boardLocked = false;
      _feedbackIsGood = move.holds;
      _feedback = 'Istražujete: ${move.san}. '
          '${_readoutMoveWord(move)} Tabla je slobodna — odigrajte odgovor ili '
          'uzmite potez iz nalaza.';
    });
    _boardController.loadFen(board.fen);
    _refreshReadout(force: true);
  }

  /// One move played by hand on the board while exploring.
  void _playExploringMove(String from, String to, String promotion) {
    final game = _game;
    if (game == null) return;
    final board = chess.Chess.fromFEN(game.fen);
    final piece = promotion.isEmpty ? 'q' : promotion;
    if (board.move({'from': from, 'to': to, 'promotion': piece}) == false) {
      return;
    }
    setState(() {
      _game = board;
      _feedbackIsGood = false;
      _feedback = 'Istražujete — potezi se ovde ne ocenjuju.';
    });
    _boardController.loadFen(board.fen);
    _refreshReadout(force: true);
  }

  /// Puts the board back where the exploring started.
  void _stopExploring() {
    final back = _exploreFrom;
    if (back == null) return;
    setState(() {
      _exploring = false;
      _exploreFrom = null;
      _game = chess.Chess.fromFEN(back);
      _feedback = null;
      _feedbackIsGood = false;
    });
    _boardController.loadFen(back);
    _refreshReadout(force: true);
  }

  /// What one line of the finding says about a move, in words.
  String _readoutMoveWord(ReadoutMove move) {
    final outcome = outcomeWord(move.outcome);
    if (move.dtz == null) return 'Posle njega: $outcome.';
    return 'Posle njega: $outcome, DTZ ${move.dtz}.';
  }

  /// Keeps the open panel about the position in front of the reader.
  ///
  /// Called after every judged move, so the reader can play on with the tables
  /// beside them and watch where it goes wrong — which is the point of the
  /// panel rather than the dialog. The stale answer is dropped first: better an
  /// empty panel for a moment than a list belonging to a position that is gone.
  Future<void> _refreshReadout({bool force = false}) async {
    if (!_readoutOpen && !force) return;
    if (!_readoutOpen && _readout == null) return;
    setState(() {
      _readout = null;
      _readoutFen = null;
    });
    await _fetchReadout();
  }

  /// Whether there is anything left to hold: no pawns on the board.
  ///
  /// The cheap half of the question, answered here so the button only appears
  /// where it could apply. Whether the draw is really finished is the tables'
  /// answer, and it is asked when the button is pressed.
  bool get _mightBeOver {
    final game = _game;
    if (game == null || !_drilling || _punishing) return false;
    if (_solve?.puzzle.mode != EndgameMode.draw) return false;
    return !RegExp(r'[pP]').hasMatch(game.fen.split(' ').first);
  }

  /// Closes a draw that has nothing left in it.
  ///
  /// Without this the only way out of a dead drawn rook ending is to shuffle
  /// until the position repeats, which teaches nothing and reads as the drill
  /// refusing to end.
  Future<void> _concludeDraw() async {
    final solve = _solve;
    final game = _game;
    if (solve == null || game == null || _reading) return;
    setState(() => _reading = true);
    final readout =
        await _api.fetchReadout(fen: game.fen, goal: EndgameMode.draw);
    if (!mounted) return;
    setState(() => _reading = false);

    if (readout == null) {
      setState(() {
        _feedbackIsGood = false;
        _feedback = 'Tablica trenutno nije dostupna, pa se remi ne može '
            'zaključiti.';
      });
      return;
    }
    if (!readout.deadDraw) {
      // Not a refusal. The position is not provably finished, so instead of
      // arguing about it the drill asks for the demonstration: hold it for a
      // few more moves and it closes. That answers the same complaint without
      // claiming anything about the position that is not true.
      final dropping = readout.dropping;
      final why = dropping.isEmpty
          ? 'Ovo još nije mrtva pozicija.'
          : 'Ovo još nije mrtva pozicija — ${dropping.first.san} gubi remi.';
      setState(() {
        _holdLeft = holdOutMoves;
        _feedbackIsGood = false;
        _feedback = '$why ${holdOutText(holdOutMoves)}';
      });
      return;
    }
    setState(() {
      _holdLeft = null;
      _drillEnd = 'draw';
      _feedbackIsGood = true;
      _feedback = 'Remi je zaključen — nema pešaka, a izgubiti se može samo '
          'poklanjanjem figure. Nema više šta da se drži.';
    });
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

  /// The letters, and the button each of them presses.
  ///
  /// Written as a mirror of [_buildControls] on purpose: a key stands for a
  /// button that is on the screen, and null everywhere that button is not
  /// offered or is disabled. A key that works while its button is greyed out
  /// would be a second way in with nothing to see it by - and this screen locks
  /// the board on purpose while the tables are being asked.
  Map<LogicalKeyboardKey, VoidCallback?> _shortcutBindings(
      BuildContext context) {
    final solve = _solve;
    // Nothing to press while the position is still on its way, or when the
    // fetch failed and the screen is one button wide.
    if (solve == null || _loading || _error != null) {
      return const {};
    }

    if (_drilling) {
      final open = Breakpoints.isWide(context) && _readoutOpen;
      return {
        LogicalKeyboardKey.keyN: _boardLocked ? null : _loadNext,
        LogicalKeyboardKey.keyR:
            _boardLocked ? null : (_punishing ? _startPunish : _startDrill),
        LogicalKeyboardKey.keyT: _reading || (_drillEnd != null && !open)
            ? null
            : () => _showReadout(wide: Breakpoints.isWide(context)),
        LogicalKeyboardKey.keyU:
            _boardLocked || _drillRetryFen == null ? null : _retryDrillMove,
      };
    }

    return {
      LogicalKeyboardKey.keyN: _loadNext,
      // Nothing to retry any more: a wrong answer puts the position back by
      // itself, so the button this key stood for no longer exists.
      LogicalKeyboardKey.keyR: null,
      LogicalKeyboardKey.keyH: solve.isComplete ? null : _showHint,
      // The tables are a drill button; solving a position with the answer in
      // front of you is not solving it.
      LogicalKeyboardKey.keyT: null,
      LogicalKeyboardKey.keyU: null,
    };
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
          const BoardCoordinatesButton(),
          BoardFlipButton(
            onPressed: () => setState(() {
              _orientation = _orientation == PlayerColor.white
                  ? PlayerColor.black
                  : PlayerColor.white;
            }),
          ),
        ],
      ),
      body: SafeArea(
        child: ActionKeyShortcuts(
          bindings: _shortcutBindings(context),
          child: _buildBody(),
        ),
      ),
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

    // Beside the board and under what the screen is already saying, so one
    // column holds the whole conversation: what to do, what happened, and - on
    // request - what the tables say about it.
    final aside = wide && _readoutOpen
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              panel,
              const SizedBox(height: AppSpacing.md),
              _ReadoutPanel(
                // Guarded by the position it was read for. The refresh clears
                // it first, so this is a second lock on the same door - and it
                // is the door that matters: a list of moves under a board that
                // has moved on would be read as being about this board.
                readout: _readoutFen == _game?.fen ? _readout : null,
                loading: _reading,
                onPlay: _playFromReadout,
              ),
            ],
          )
        : panel;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: EndgameBoardLayout(
            wide: wide,
            constraints: constraints,
            panel: aside,
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
                            (_exploring ||
                                (_drilling
                                    ? _drillEnd == null
                                    : !solve.isComplete)),
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
                    const SizedBox(height: AppSpacing.md),
                    panel,
                  ],
                  const SizedBox(height: AppSpacing.md),
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
    // A solved position still said "Beli na potezu — zadržite dobitak", which
    // is an instruction to play on a board that will not answer. Coming back
    // from the drill lands exactly there, and it reads as a frozen board.
    final solve = _solve;
    if (solve != null && solve.isComplete) {
      return puzzle.mode == EndgameMode.draw
          ? 'Rešeno — remi je održan'
          : 'Rešeno — dobitak je zadržan';
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
    // Solved means the board is closed, and saying nothing about that is how a
    // deliberate lock reads as a broken one. Reported three times now, in three
    // places; each time the board was right and silent. So it names the way
    // out, and only the ways that are actually on the screen.
    if (solve.isComplete) {
      final left = _missing(solve.puzzle).length;
      return left > 0
          // The count goes through the same sentence the verdict uses, so the
          // cases agree without a second rule to keep in step.
          ? 'Tabla je zatvorena dok je pozicija rešena. ${movesLeftText(left)} '
              '„Nađi i ostale" vraća položaj da ih potražite, a „Sledeća" nosi '
              'novu poziciju.'
          : 'Tabla je zatvorena dok je pozicija rešena. „Odigraj do kraja" '
              'nastavlja ovu poziciju, a „Sledeća" nosi novu.';
    }
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
        if (_exploring) 'Istraživanje',
        if (_readouts > 0) 'Nalaz: $_readouts',
        if (_holdLeft != null && _holdLeft! > 0) 'Do remija: $_holdLeft',
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
          // The tables, on request and never on their own. In this mode the
          // reader is playing against perfect defence and can be stuck without
          // having blundered, which is a different situation from the one the
          // solve screen's hint is for.
          if (_exploring)
            FilledButton.icon(
              onPressed: _stopExploring,
              icon: const Icon(Icons.undo),
              label: const Text('Nazad na poziciju'),
            ),
          Builder(builder: (context) {
            final wide = Breakpoints.isWide(context);
            final open = wide && _readoutOpen;
            return OutlinedButton.icon(
              onPressed: _reading || (_drillEnd != null && !open)
                  ? null
                  : () => _showReadout(wide: wide),
              icon: Icon(open
                  ? Icons.visibility_off_outlined
                  : Icons.table_chart_outlined),
              label: Text(open ? 'Sakrij nalaz' : 'Nalaz tablica'),
            );
          }),
          if (_mightBeOver && _drillEnd == null)
            OutlinedButton.icon(
              onPressed: _reading ? null : _concludeDraw,
              icon: const Icon(Icons.handshake_outlined),
              label: const Text('Zaključi remi'),
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
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 40),
            const SizedBox(height: AppSpacing.md),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
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

/// How wide the finding may be inside a dialog on this screen.
///
/// 128 is what an AlertDialog spends before its content sees a pixel: 40 of
/// inset and 24 of padding, twice over.
double _dialogWidth(BuildContext context) {
  final room = MediaQuery.sizeOf(context).width - 136;
  if (room < 200) return 200;
  return room > 420 ? 420 : room;
}

/// The finding beside the board, on a window with a column to spare.
///
/// The same list as the dialog and a different thing to use: it stays while the
/// drill is played, so the reader can go on making moves and watch where the
/// tables and their own idea part company. That is what was asked for, and it
/// is why this is not modal.
class _ReadoutPanel extends StatelessWidget {
  const _ReadoutPanel({
    required this.readout,
    required this.loading,
    this.onPlay,
  });

  final TablebaseReadout? readout;
  final bool loading;
  final void Function(ReadoutMove move)? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = readout;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Nalaz tablica', style: theme.textTheme.titleSmall),
              const Spacer(),
              if (loading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (data == null)
            Text(
              loading ? 'Čitam tablice…' : 'Nalaz za ovu poziciju još nije tu.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.colors.textMuted),
            )
          else ...[
            Text(
              '${outcomeWord(data.outcome)}'
              '${data.dtz == null ? '' : ', DTZ ${data.dtz}'} · '
              'drži ${data.holding} od ${data.total}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            // Capped rather than endless: a pawnless ending can offer thirty
            // moves, and a column that long pushes everything else off screen.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final move in data.moves)
                      _MoveRow(
                        move: move,
                        onTap: onPlay == null ? null : () => onPlay!.call(move),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'DTZ: polupotezi do uzimanja ili poteza pešaka, ne do mata. '
              'Zvezdica = potez nulira taj brojač. '
              'Dodir na potez ga odigra na tabli.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// The tables' finding for one position, as a list a person can read.
///
/// Ordered the way the drill thinks: the moves that keep the result first, and
/// among those the ones that get somewhere. The two numbers people mix up are
/// spelled out once at the bottom rather than left as initials - DTZ is the
/// distance to the next capture or pawn move, and it is not the distance to
/// mate, which Syzygy does not store at all.
class _ReadoutDialog extends StatelessWidget {
  const _ReadoutDialog({required this.readout, this.onPlay});

  final TablebaseReadout readout;
  final void Function(ReadoutMove move)? onPlay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final holding = readout.moves.where((m) => m.holds).toList();
    final losing = readout.moves.where((m) => !m.holds).toList();

    return AlertDialog(
      title: const Text('Nalaz tablica'),
      content: SizedBox(
        // From the screen, never a fixed number, and counting everything the
        // dialog takes for itself: 40 of inset on each side and 24 of content
        // padding, which is why subtracting only the insets still overflowed a
        // 360 dp phone. In a release build that paints no warning - it clips -
        // and this shape of bug has been shipped here before.
        width: _dialogWidth(context),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(
              'Pozicija: ${outcomeWord(readout.outcome)}'
              '${readout.dtz == null ? '' : ', DTZ ${readout.dtz}'}. '
              'Drži ${readout.holding} od ${readout.total} poteza.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            if (holding.isNotEmpty) ...[
              Text('Drže rezultat', style: theme.textTheme.labelLarge),
              for (final move in holding)
                _MoveRow(move: move, onTap: _tap(context, move)),
            ],
            if (losing.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('Gube rezultat', style: theme.textTheme.labelLarge),
              for (final move in losing)
                _MoveRow(move: move, onTap: _tap(context, move)),
            ],
            const Divider(height: 24),
            Text(
              'DTZ je broj polupoteza do sledećeg uzimanja ili poteza pešaka, '
              'ne do mata — po njemu se broji pravilo pedeset poteza. Zvezdica '
              'znači da potez nulira taj brojač, što je u dobijenoj poziciji '
              'napredak po definiciji. Dodir na potez ga odigra na tabli.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.colors.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Zatvori'),
        ),
      ],
    );
  }

  /// Closes first, then plays: the move happens on the board behind, and the
  /// dialog would be standing over the thing it was asked to show.
  VoidCallback? _tap(BuildContext context, ReadoutMove move) {
    final play = onPlay;
    if (play == null) return null;
    return () {
      Navigator.of(context).pop();
      play(move);
    };
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.move, this.onTap});

  final ReadoutMove move;

  /// Plays this move on the board. The finding stops being a list to read and
  /// becomes a way to ask "and then what?", which is the question a losing move
  /// leaves behind.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = move.holds ? context.colors.success : context.colors.warning;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // Flexible, not a fixed width. A row of fixed pieces in a dialog is
          // how the 360 dp phone gets clipped in a release build, where no
          // warning is painted - the notation is the part that may be cut, and
          // it is the part that survives being cut.
          Flexible(
            flex: 3,
            child: Text(
              '${move.san}${move.zeroing ? ' *' : ''}',
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: colour.withValues(alpha: 0.18),
              borderRadius: AppRadii.roundedSm,
            ),
            child: Text(outcomeWord(move.outcome),
                style: theme.textTheme.bodySmall),
          ),
          const Spacer(),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            flex: 2,
            child: Text(
              move.dtz == null ? '—' : 'DTZ ${move.dtz}',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: context.colors.textMuted),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: row,
    );
  }
}
