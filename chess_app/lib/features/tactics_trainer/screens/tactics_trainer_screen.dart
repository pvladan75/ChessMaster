import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/services/puzzle_attempt_api.dart';
import 'package:chess_app/core/speech/move_words.dart';
import 'package:chess_app/core/speech/spoken_line.dart';
import 'package:chess_app/core/speech/vocabulary.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/services/speech_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_flip_button.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/trainer_board_layout.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import '../models/tactics_puzzle.dart';
import '../services/tactics_api_service.dart';

/// Solves adaptively-selected Lichess puzzles.
///
/// Kept as its own feature rather than folded into the AI Studio screen: these
/// puzzles are a linear move line with forced replies, while that screen drives
/// an engine-verified solution tree. Sharing one screen would mean branching on
/// puzzle type at every step of an already very large file.
class TacticsTrainerScreen extends StatefulWidget {
  const TacticsTrainerScreen({
    super.key,
    required this.session,
    this.assignmentId,
    this.assignmentTitle,
    this.puzzleIds,
    this.retry = false,
    this.retryIds,
    this.api,
    this.attemptApi,
    this.speech,
  });

  final UserSession session;

  /// When set, the screen works through an assignment's puzzles in order
  /// instead of asking the selector for the next one.
  final int? assignmentId;
  final String? assignmentTitle;
  final List<String>? puzzleIds;

  /// Walks the failed puzzles from `PuzzleAttemptApi.retryIds('lichess')`
  /// instead of the adaptive selector — the hub's „Retry failed" button.
  /// Unlike an assignment, a wrong move here may be tried again and „Skip"
  /// records a skip; it is not homework.
  final bool retry;

  /// With [retry], the queue to walk instead of the server's — the puzzle
  /// list's „Try again" hands it one id (`docs/PLAN-NAPREDAK-VEZBI.md` §7).
  /// Null fetches the whole queue, as the hub's „Retry failed" does.
  final List<String>? retryIds;

  /// Injected in tests, which have no server.
  final TacticsApiService? api;

  /// Injected in tests — fake the client, assert the request (rule 7) — for
  /// the retry queue and, indirectly, the request `api` builds (§4).
  final PuzzleAttemptApi? attemptApi;

  /// Injected in tests, which must not reach the machine's own voice. Null is
  /// the app's one `SpeechService`.
  final SpeechService? speech;

  bool get isAssignment => puzzleIds != null && puzzleIds!.isNotEmpty;

  /// Assignment and retry both serve one puzzle at a time from a fixed list
  /// of ids, in order, rather than asking the adaptive selector.
  bool get _walksQueue => isAssignment || retry;

  @override
  State<TacticsTrainerScreen> createState() => _TacticsTrainerScreenState();
}

class _TacticsTrainerScreenState extends State<TacticsTrainerScreen> {
  late final TacticsApiService _api;
  final ChessBoardController _boardController = ChessBoardController();

  chess.Chess? _game;
  TacticsPuzzle? _puzzle;
  TacticsSolveSession? _session;
  PuzzleSelection? _selection;

  bool _loading = true;
  bool _boardLocked = true;
  String? _error;

  /// The verdict, one sentence per line. Each is a [SpokenLine]: the text
  /// drawn is the text of the line that was spoken (D4), and nothing else on
  /// this screen speaks.
  List<SpokenLine>? _feedback;
  bool _feedbackIsGood = false;

  /// The side the reader plays. Fixed when the puzzle starts: flipping the
  /// board must not change whose move the task says it is.
  PlayerColor _userSide = PlayerColor.white;

  /// Bumped whenever a puzzle is put on the board, so the task line is a new
  /// widget and says its sentence again.
  int _taskSerial = 0;
  AttemptResult? _lastResult;
  DateTime? _startedAt;

  PlayerColor _orientation = PlayerColor.white;

  /// Guards against a reply landing after the user has moved on.
  int _puzzleToken = 0;

  /// Position in the assignment's puzzle list; unused in adaptive mode.
  int _assignmentIndex = 0;
  bool _assignmentFinished = false;

  /// Assigned puzzles that could not be loaded. Skipped so the rest can still
  /// be solved, but never in silence: a set that ends with any of these is
  /// not „complete" (found live 20.9.2026, when all of one could not be).
  final Set<String> _unloadable = {};

  /// What is still being served. Starts as everything the assignment has left
  /// and is replaced by the skipped ones when the student goes back for them,
  /// so a second pass does not walk over work they have already answered.
  List<String>? _queue;

  /// Whether this puzzle's attempt has already been sent to the server.
  ///
  /// A wrong answer to homework finishes the puzzle on the spot, and the user
  /// may then still ask to see the solution; without this the same attempt
  /// would be submitted twice.
  bool _attemptRecorded = false;

  /// Puzzles walked past without an answer, in the order they were skipped.
  ///
  /// Kept because "Zadatak je završen" was shown at the end of the run whether
  /// or not anything had been answered — a student who pressed "Preskoči"
  /// twice was told they were done, while the homework stayed unfinished and
  /// the trainer was never told. Reported live on 27.8.2026 by exactly that
  /// route.
  final List<String> _skipped = [];

  /// Set once the retry queue has been asked for and come back empty — its
  /// own screen, distinct from an assignment's „nothing left" (this is not
  /// homework and there is nothing to submit).
  bool _retryEmpty = false;

  late final PuzzleAttemptApi _attemptApi =
      widget.attemptApi ?? PuzzleAttemptApi(authToken: widget.session.token);

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? TacticsApiService(authToken: widget.session.token);
    if (widget.retry) {
      _loadRetryQueue();
    } else {
      _loadNext();
    }
  }

  Future<void> _loadRetryQueue() async {
    final ids =
        widget.retryIds ?? await _attemptApi.retryIds(PuzzleSource.lichess);
    if (!mounted) return;
    if (ids == null || ids.isEmpty) {
      setState(() {
        _loading = false;
        _retryEmpty = true;
      });
      return;
    }
    _queue = ids;
    _loadNext();
  }

  @override
  void dispose() {
    // The reader is leaving, which is one of the three things that may cut a
    // sentence off. See SpeechService.stop.
    try {
      unawaited(_speech.stop().catchError((Object _) {}));
    } catch (_) {}
    _boardController.dispose();
    super.dispose();
  }

  SpeechService get _speech => widget.speech ?? SpeechService.instance;

  /// Says [line] through the one speech service. Forced, because the same
  /// verdict twice in a row is two verdicts, and guarded, because a voice that
  /// throws must never be able to stop a move, a reply or the finish.
  void _say(SpokenLine line) {
    if (!mounted) return;
    try {
      unawaited(_speech.speakLine(line, force: true).catchError((Object _) {}));
    } catch (_) {}
  }

  /// A move played in [fenBefore], said as a move and read off the position it
  /// was played in — never off a string of squares.
  void _sayMove(String fenBefore, String uci) {
    if (uci.length < 4) return;
    try {
      final facts = MoveWords.factsOf(
          fenBefore, uci.substring(0, 2), uci.substring(2, 4),
          promotion: uci.length > 4 ? uci[4].toLowerCase() : 'q');
      if (facts != null) _say(MoveWords.line(facts));
    } catch (_) {}
  }

  /// Draws and says the verdict, line by line, in order.
  void _verdict(List<SpokenLine> lines, {required bool good}) {
    setState(() {
      _feedback = lines;
      _feedbackIsGood = good;
    });
    lines.forEach(_say);
  }

  Future<void> _loadNext() async {
    // Leaving a puzzle that was never answered is a skip. Recorded here rather
    // than in the button, because every way out of a puzzle comes through this
    // one method.
    final leaving = _puzzle;
    final leavingUnfinished =
        leaving != null && !(_session?.isComplete ?? false);
    if (widget.isAssignment) {
      if (leavingUnfinished && !_skipped.contains(leaving.id)) {
        _skipped.add(leaving.id);
      }
    } else if (leavingUnfinished) {
      // Free practice and retry: a skip is worth recording, so a puzzle
      // walked past without an answer does not read as "never seen" on the
      // hub card. Fired, not awaited — recording must never hold up the next
      // position.
      unawaited(_api.submitAttempt(
        puzzleId: leaving.id,
        solved: false,
        skipped: true,
      ));
    }

    // Moving to the next puzzle is the reader saying they are done with the
    // last verdict; and forgetting it means the same sentence is read again
    // when it comes round on a later puzzle.
    try {
      unawaited(_speech.stop().catchError((Object _) {}));
    } catch (_) {}
    _speech.forget();

    final token = ++_puzzleToken;
    setState(() {
      _loading = true;
      _error = null;
      _feedback = null;
      _lastResult = null;
      _boardLocked = true;
    });

    if (widget._walksQueue) {
      await _loadAssignmentPuzzle(token);
      return;
    }

    final response = await _api.fetchAdaptivePuzzle(excludeId: _puzzle?.id);
    if (!mounted || token != _puzzleToken) return;

    if (response == null || !response.puzzle.isPlayable) {
      setState(() {
        _loading = false;
        _error = response == null
            ? 'Cannot load puzzle. Check your connection to the server.'
            : 'Puzzle received in an invalid format.';
      });
      return;
    }

    _startPuzzle(response.puzzle, response.selection);
  }

  /// Serves the assignment's or the retry queue's puzzles in order, one by
  /// id. `_queue` is already populated for retry mode by the time this runs
  /// (`_loadRetryQueue`), so the fallback below only fires for an assignment.
  Future<void> _loadAssignmentPuzzle(int token) async {
    final ids = _queue ??= List<String>.from(widget.puzzleIds!);
    if (_assignmentIndex >= ids.length) {
      setState(() {
        _loading = false;
        _assignmentFinished = true;
      });
      return;
    }

    final puzzle = await _api.fetchPuzzleById(ids[_assignmentIndex]);
    if (!mounted || token != _puzzleToken) return;

    if (puzzle == null || !puzzle.isPlayable) {
      // One bad row must not strand the student on the rest of the homework.
      AppLogger.log(
          '[Tactics] Skipping assigned puzzle ${ids[_assignmentIndex]}.');
      _unloadable.add(ids[_assignmentIndex]);
      _assignmentIndex++;
      await _loadAssignmentPuzzle(token);
      return;
    }

    _assignmentIndex++;
    _startPuzzle(puzzle, PuzzleSelection(targetRating: puzzle.rating));
  }

  void _startPuzzle(TacticsPuzzle puzzle, PuzzleSelection selection) {
    final game = chess.Chess.fromFEN(puzzle.fen);
    final fenBeforeSetup = game.fen;

    // The stored FEN is the position before the opponent's mistake. Playing the
    // setup move is what produces the position the user is actually asked about.
    final setup = puzzle.setupMove!;
    game.move({
      'from': setup.substring(0, 2),
      'to': setup.substring(2, 4),
      if (setup.length > 4) 'promotion': setup[4],
    });

    setState(() {
      _puzzle = puzzle;
      _selection = selection;
      _session = TacticsSolveSession(puzzle);
      _game = game;
      // Whoever is to move after the setup move is the side the user plays.
      _orientation = game.turn == chess.Color.WHITE
          ? PlayerColor.white
          : PlayerColor.black;
      _userSide = _orientation;
      _taskSerial++;
      _loading = false;
      _boardLocked = false;
      _startedAt = DateTime.now();
      _feedback = null;
      _attemptRecorded = false;
    });

    _boardController.loadFen(game.fen);
    // What the opponent just played comes first — the reader is asked about
    // the position it made — and the task follows from the line under the
    // board, built after this frame.
    _sayMove(fenBeforeSetup, setup);
    AppLogger.log(
        '[Tactics] Puzzle ${puzzle.id} (rating ${puzzle.rating}) loaded.');
  }

  /// True when this move lands a pawn on the last rank.
  bool _isPromotion(chess.Chess game, String from, String to) {
    final piece = game.get(from);
    if (piece == null || piece.type != chess.PieceType.PAWN) return false;
    return to.endsWith('8') || to.endsWith('1');
  }

  /// Asks which piece to promote to.
  ///
  /// The board only reports from/to, so without this every promotion would
  /// silently become a queen — and any puzzle whose answer is an under-promotion
  /// (Lichess tags a whole theme of them) would be impossible to solve.
  Future<void> _onMove(String from, String to, String promotion) async {
    final session = _session;
    final game = _game;
    if (session == null || game == null || _boardLocked || session.isComplete) {
      // The board widget has already moved the piece under the user's finger,
      // so a bare `return` leaves it there. That is how a refused move became
      // a board you could shuffle at will, for both sides: every drag was
      // declined here and every one of them stayed on screen. Whatever the
      // reason for refusing, the position the user sees has to be the position
      // that exists.
      if (game != null) _boardController.loadFen(game.fen);
      return;
    }

    final isPromotion = _isPromotion(game, from, to);
    // The board asks now — one dialog for every board in the app, in the moving
    // side's colour (widgets/promotion_picker.dart). This screen used to ask on
    // its own, after the piece had already been moved, which is why the same
    // question looked different here than everywhere else.
    final piece = promotion.isEmpty ? 'q' : promotion;

    // Trial move on a copy: an illegal or non-solution move must never disturb
    // the real position.
    final probe = chess.Chess.fromFEN(game.fen);
    final moved = probe.move({'from': from, 'to': to, 'promotion': piece});
    if (moved == false) {
      _boardController.loadFen(game.fen);
      return;
    }

    // The suffix belongs on the move only when a promotion actually happened.
    final uci = isPromotion ? '$from$to$piece' : '$from$to';
    final verdict = session.submit(
      uci,
      givesCheckmate: probe.in_checkmate,
      // Passed for the sake of the first wrong try, which is the only thing a
      // trainer can read afterwards: `e2e4` says nothing to anyone.
      san: _sanFor(game.fen, from, to, piece),
    );

    if (!verdict.correct) {
      // The board is put back, so the user sees the position they must still
      // solve rather than the mistake they just made.
      _boardController.loadFen(game.fen);

      if (widget.isAssignment) {
        // Homework has one answer. It is already recorded as wrong by the
        // first attempt, so offering another try would show a second chance
        // that changes nothing — the trainer sees the first move either way.
        // Better to say so and move on.
        await _finish(
          solved: false,
          note: [
            SpokenLine([SpeechVocabulary.oneAttempt]),
            SpokenLine([SpeechVocabulary.notSolved]),
          ],
        );
        return;
      }

      // Practice: straight back to trying, with no button in between. The
      // mistake stays on the session's record, so a retried puzzle still does
      // not count as a clean solve and the rating is unaffected.
      session.retryAfterMistake();
      _verdict([
        SpokenLine([SpeechVocabulary.incorrectTryAnother])
      ], good: false);
      return;
    }

    game.move({'from': from, 'to': to, 'promotion': piece});
    _boardController.loadFen(game.fen);

    if (verdict.puzzleSolved) {
      setState(() {
        _feedback = null;
        _feedbackIsGood = true;
      });
    } else {
      _verdict([
        SpokenLine([SpeechVocabulary.correctKeepGoing])
      ], good: true);
    }

    if (verdict.opponentReply != null) {
      await _playOpponentReply(verdict.opponentReply!);
    }

    if (verdict.puzzleSolved) {
      await _finish(solved: session.countsAsSolved);
    }
  }

  /// The move in notation a person reads, asked of a copy of the position.
  ///
  /// `move_to_san` has to be asked *before* the move exists on the board — it
  /// reads the position it is given, and called afterwards it throws. The same
  /// trap cost a whole afternoon on the homework screen.
  static String? _sanFor(String fen, String from, String to, String promotion) {
    try {
      final game = chess.Chess.fromFEN(fen);
      if (game.move({'from': from, 'to': to, 'promotion': promotion}) ==
          false) {
        return null;
      }
      final made = game.history.last.move;
      game.undo_move();
      return game.move_to_san(made);
    } catch (_) {
      return null;
    }
  }

  Future<void> _playOpponentReply(String uci) async {
    final token = _puzzleToken;
    setState(() => _boardLocked = true);

    // A beat before the reply, so the user sees their own move land first.
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted || token != _puzzleToken) return;

    final game = _game;
    if (game == null) return;

    final fenBefore = game.fen;
    game.move({
      'from': uci.substring(0, 2),
      'to': uci.substring(2, 4),
      if (uci.length > 4) 'promotion': uci[4],
    });
    _boardController.loadFen(game.fen);
    _sayMove(fenBefore, uci);

    if (!mounted || token != _puzzleToken) return;
    setState(() => _boardLocked = _session?.isComplete ?? true);
  }

  /// Records the attempt and closes the puzzle.
  ///
  /// [note] replaces the verdict when neither "solved" nor "solved with help"
  /// is the truth — a wrong answer to homework, which has one attempt, is
  /// finished too. [say] is false where the screen has just said its own
  /// words (the solution played out) and the verdict would only be drawn.
  Future<void> _finish({
    required bool solved,
    List<SpokenLine>? note,
  }) async {
    final puzzle = _puzzle;
    if (puzzle == null) return;

    final lines = note ??
        [
          SpokenLine([
            solved ? SpeechVocabulary.solved : SpeechVocabulary.solvedWithHelp
          ])
        ];
    setState(() {
      _boardLocked = true;
      _feedback = lines;
      _feedbackIsGood = solved;
    });
    lines.forEach(_say);

    final elapsed = _startedAt == null
        ? null
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    _attemptRecorded = true;
    final result = await _api.submitAttempt(
      puzzleId: puzzle.id,
      solved: solved,
      msTaken: elapsed,
      // What they tried before they found it — or instead of finding it.
      playedSan: _session?.firstWrongSan,
    );

    if (!mounted) return;
    setState(() => _lastResult = result);
  }

  /// Gives up on the current puzzle: plays the rest of the line out so the user
  /// sees the idea, and records it as unsolved.
  Future<void> _showSolution() async {
    final session = _session;
    final game = _game;
    // `failed` is allowed through: homework has one attempt, and the position
    // it got wrong is exactly the one worth seeing played out. `solved` is not
    // — there is nothing left to show.
    if (session == null ||
        game == null ||
        session.status == SolveStatus.solved) {
      return;
    }

    setState(() => _boardLocked = true);
    final token = _puzzleToken;

    // Everything from where the user got stuck to the end of the line.
    for (final move
        in session.puzzle.solution.sublist(session.solvedMoveCount * 2)) {
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted || token != _puzzleToken) return;

      final fenBefore = game.fen;
      game.move({
        'from': move.substring(0, 2),
        'to': move.substring(2, 4),
        if (move.length > 4) 'promotion': move[4],
      });
      _boardController.loadFen(game.fen);
      _sayMove(fenBefore, move);
      setState(() {});
    }

    // Recorded once. A homework answer that was already submitted as wrong
    // must not be sent a second time just because the user then looked at the
    // solution — the first attempt is the one that counts, on both sides.
    if (_attemptRecorded) {
      setState(() => _boardLocked = true);
      return;
    }
    // Said as well as drawn: the screen never draws a sentence it does not
    // say (the walkthrough's rule, kept by every spoken screen).
    await _finish(solved: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
        title: Text(
            widget.retry ? 'Retry' : (widget.assignmentTitle ?? 'Tactics')),
        actions: [
          const BoardViewMenu(),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.retry && (_retryEmpty || _assignmentFinished)) {
      return _buildRetryDone();
    }
    if (_assignmentFinished) {
      return _buildAssignmentDone();
    }
    if (_error != null) {
      return _buildError();
    }

    Widget board(double boardSize) => BoardWithCoordinates(
          size: boardSize,
          orientation: _orientation,
          builder: (size) => ChessBoardWithOverlay(
            controller: _boardController,
            boardOrientation: _orientation,
            boardSize: size,
            isAllowedToMove: !_boardLocked,
            isDrawingMode: false,
            drawingStartSquare: null,
            arrows: const [],
            engineArrows: const [],
            onMove: _onMove,
            onSquareTapForDrawing: (_) {},
            // Free practice copies like any board; an assigned puzzle does
            // once it is answered, and not while it is being solved.
            copyPosition:
                !widget.isAssignment || (_session?.isComplete ?? false),
          ),
        );

    // One layout for every board screen (R1): the board sized by the window,
    // the panel beside it on a window and under it on a phone, the buttons
    // under the board. The choice is the window's, never the orientation.
    return TrainerScreenLayout(
      board: board,
      panel: _buildPanel(),
      controls: _buildControls(),
    );
  }

  /// Goes back for the puzzles that were walked past.
  ///
  /// Only those: the queue is replaced rather than restarted, so a student who
  /// answered eight and skipped two is asked the two, not the ten.
  void _retrySkipped() {
    setState(() {
      _queue = List<String>.from(_skipped);
      _skipped.clear();
      _assignmentIndex = 0;
      _assignmentFinished = false;
    });
    _loadNext();
  }

  /// Retry's own empty/done screen — distinct from an assignment's, because
  /// this is not homework and there is nothing to submit or leave unfinished.
  Widget _buildRetryDone() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 56, color: context.colors.success),
            const SizedBox(height: 14),
            const Text(
              'Nothing to retry.',
              textAlign: TextAlign.center,
              style: AppText.headline,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentDone() {
    // Reaching the end of the list is not the same as finishing the homework,
    // and saying so was the whole bug: skipped puzzles stay unanswered, the
    // assignment is not marked complete, and the trainer is never told - while
    // the student had been shown "Zadatak je završen" and reasonably went away.
    final skipped = _skipped.length;
    final unfinished = skipped > 0;

    // What could not even be shown comes first: nothing was answered for it,
    // nothing was sent, and „complete" would be a lie told to the one person
    // who cannot check it.
    if (_unloadable.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 56, color: context.colors.warning),
              const SizedBox(height: 14),
              Text(
                '${puzzleCountLabel(_unloadable.length)} could not be loaded.',
                textAlign: TextAlign.center,
                style: AppText.headline,
              ),
              const SizedBox(height: 6),
              Text(
                'Nothing was sent for them, so this assignment is not '
                'finished. Tell your trainer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              unfinished ? Icons.pending_actions : Icons.task_alt,
              size: 56,
              color:
                  unfinished ? context.colors.warning : context.colors.success,
            ),
            const SizedBox(height: 14),
            Text(
              unfinished
                  ? 'Homework is not submitted yet.'
                  : 'Assignment complete.',
              textAlign: TextAlign.center,
              style: AppText.headline,
            ),
            const SizedBox(height: 6),
            Text(
              unfinished
                  ? 'You skipped ${puzzleCountLabel(skipped)}. Homework is '
                      'only submitted once you attempt them — until then your trainer '
                      'is not notified that you finished.'
                  : 'Your trainer can see the result.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            // Wrap, not Row: two buttons side by side are wider than a 360 px
            // phone, and a release build clips the second one in silence.
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (unfinished)
                  FilledButton.icon(
                    onPressed: _retrySkipped,
                    icon: const Icon(Icons.playlist_add_check),
                    label: const Text('Retry skipped'),
                  ),
                // The one main action is filled: where nothing was skipped
                // the way back is that action, and where something was it is
                // the outlined second.
                if (unfinished)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to assignments'),
                  )
                else
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to assignments'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: context.colors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: _loadNext,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  /// What the screen says, in one place: the context as chips, the task, the
  /// verdict and — after a solve — the new rating (R2, R3). The header card,
  /// the verdict box and the rating card were three places.
  Widget _buildPanel() {
    final puzzle = _puzzle;
    final session = _session;
    if (puzzle == null || session == null) return const SizedBox.shrink();

    // The sentence the task line draws is the sentence it speaks (D4): one
    // SpokenLine, read for both.
    final task = SpokenLine([
      _userSide == PlayerColor.white
          ? SpeechVocabulary.whiteToMove
          : SpeechVocabulary.blackToMove,
      SpeechVocabulary.findBestMove,
    ]);

    final result = _lastResult;
    final lines = _feedback ?? const <SpokenLine>[];

    return TrainerInfoPanel(
      // A new puzzle is a new panel: it says its task again (D4), which a
      // panel kept across puzzles would not.
      key: ValueKey('task-$_taskSerial'),
      task: task,
      autoSpeak: true,
      speech: widget.speech,
      chips: [
        'Rating ${puzzle.rating}',
        // The motif is deliberately withheld until it is over: naming it
        // upfront gives the puzzle away.
        if (session.isComplete && puzzle.trainableThemes.isNotEmpty)
          'Motif: ${puzzle.trainableThemes.join(', ')}'
        else
          'Moves needed: ${puzzle.userMoveCount} · '
              'found ${session.solvedMoveCount}',
        if (widget.isAssignment)
          'Puzzle: $_assignmentIndex of ${widget.puzzleIds!.length}'
        else if (widget.retry)
          'Puzzle: $_assignmentIndex of ${_queue?.length ?? 0}'
        else if (_selection?.targetTheme != null && !session.isComplete)
          'Practicing your weakest theme.',
      ],
      message: lines,
      // The rating card of old, said in the verdict's own box.
      messageText: result == null
          ? null
          : [
              'Rating: ${result.newRating} '
                  '(${result.ratingChange >= 0 ? '+' : ''}'
                  '${result.ratingChange})',
              'Puzzle rating: ${result.puzzleRating}',
              'Total solved: ${result.puzzlesSolved}',
            ],
      // Good and not good are said by the shape of the icon as well as in
      // words — never by the colour of the box alone.
      messageIcon: lines.isEmpty && result == null
          ? null
          : (_feedbackIsGood
              ? Icons.check_circle_outline
              : Icons.error_outline),
      messageIsGood: _feedbackIsGood,
    );
  }

  Widget _buildControls() {
    final session = _session;
    final complete = session?.isComplete ?? false;
    final failedNow = session?.status == SolveStatus.failed;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        // No "Pokušaj ponovo". A wrong move in practice puts the position back
        // and lets the user try again straight away, which is what everybody
        // pressed that button for; leaving it there meant a board that
        // accepted drags while it waited for an answer nobody needed to give.
        // Homework is the other half of the same rule: one attempt, already
        // recorded, so there is nothing to retry.
        if (!complete || failedNow)
          TextButton.icon(
            onPressed: _showSolution,
            icon: const Icon(Icons.visibility),
            label: const Text('Show solution'),
          ),
        // One filled button per state (R4): Skip while solving, Next once the
        // puzzle is over.
        FilledButton.icon(
          onPressed: _loadNext,
          icon: const Icon(Icons.skip_next),
          label: Text(complete ? 'Next' : 'Skip'),
        ),
      ],
    );
  }
}

/// "1 puzzle", "2 puzzles", "5 puzzles" — English uses two forms: singular and plural.
String puzzleCountLabel(int count) {
  return count == 1 ? '1 puzzle' : '$count puzzles';
}
