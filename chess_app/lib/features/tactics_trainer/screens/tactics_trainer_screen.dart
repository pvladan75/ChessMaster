import 'dart:async';

import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_flip_button.dart';
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
  });

  final UserSession session;

  /// When set, the screen works through an assignment's puzzles in order
  /// instead of asking the selector for the next one.
  final int? assignmentId;
  final String? assignmentTitle;
  final List<String>? puzzleIds;

  bool get isAssignment => puzzleIds != null && puzzleIds!.isNotEmpty;

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
  String? _feedback;
  bool _feedbackIsGood = false;
  String? _hintSquare;
  AttemptResult? _lastResult;
  DateTime? _startedAt;

  PlayerColor _orientation = PlayerColor.white;

  /// Guards against a reply landing after the user has moved on.
  int _puzzleToken = 0;

  /// Position in the assignment's puzzle list; unused in adaptive mode.
  int _assignmentIndex = 0;
  bool _assignmentFinished = false;

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

  @override
  void initState() {
    super.initState();
    _api = TacticsApiService(authToken: widget.session.token);
    _loadNext();
  }

  @override
  void dispose() {
    _boardController.dispose();
    super.dispose();
  }

  Future<void> _loadNext() async {
    // Leaving a puzzle that was never answered is a skip. Recorded here rather
    // than in the button, because every way out of a puzzle comes through this
    // one method.
    final leaving = _puzzle;
    if (widget.isAssignment &&
        leaving != null &&
        !(_session?.isComplete ?? false) &&
        !_skipped.contains(leaving.id)) {
      _skipped.add(leaving.id);
    }

    final token = ++_puzzleToken;
    setState(() {
      _loading = true;
      _error = null;
      _feedback = null;
      _hintSquare = null;
      _lastResult = null;
      _boardLocked = true;
    });

    if (widget.isAssignment) {
      await _loadAssignmentPuzzle(token);
      return;
    }

    final response = await _api.fetchAdaptivePuzzle(excludeId: _puzzle?.id);
    if (!mounted || token != _puzzleToken) return;

    if (response == null || !response.puzzle.isPlayable) {
      setState(() {
        _loading = false;
        _error = response == null
            ? 'Ne mogu da učitam zagonetku. Proverite vezu sa serverom.'
            : 'Zagonetka je stigla u neispravnom obliku.';
      });
      return;
    }

    _startPuzzle(response.puzzle, response.selection);
  }

  /// Serves the assignment's puzzles in the order the trainer set them.
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
          '[Tactics] Preskačem zadatu zagonetku ${ids[_assignmentIndex]}.');
      _assignmentIndex++;
      await _loadAssignmentPuzzle(token);
      return;
    }

    _assignmentIndex++;
    _startPuzzle(puzzle, PuzzleSelection(targetRating: puzzle.rating));
  }

  void _startPuzzle(TacticsPuzzle puzzle, PuzzleSelection selection) {
    final game = chess.Chess.fromFEN(puzzle.fen);

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
      _loading = false;
      _boardLocked = false;
      _startedAt = DateTime.now();
      _feedback = null;
      _attemptRecorded = false;
    });

    _boardController.loadFen(game.fen);
    AppLogger.log(
        '[Tactics] Zagonetka ${puzzle.id} (rejting ${puzzle.rating}) učitana.');
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
  Future<String?> _askPromotionPiece() {
    const options = {'q': 'Dama', 'r': 'Top', 'b': 'Lovac', 'n': 'Skakač'};

    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('U šta promovišete?'),
        content: Wrap(
          spacing: 8,
          children: [
            for (final entry in options.entries)
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, entry.key),
                child: Text(entry.value),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _onMove(String from, String to) async {
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

    String promotion = 'q';
    if (isPromotion) {
      setState(() => _boardLocked = true);
      final chosen = await _askPromotionPiece();
      if (!mounted) return;
      setState(() => _boardLocked = false);
      if (chosen == null) {
        _boardController.loadFen(game.fen);
        return;
      }
      promotion = chosen;
    }

    // Trial move on a copy: an illegal or non-solution move must never disturb
    // the real position.
    final probe = chess.Chess.fromFEN(game.fen);
    final moved = probe.move({'from': from, 'to': to, 'promotion': promotion});
    if (moved == false) {
      _boardController.loadFen(game.fen);
      return;
    }

    // The suffix belongs on the move only when a promotion actually happened.
    final uci = isPromotion ? '$from$to$promotion' : '$from$to';
    final verdict = session.submit(
      uci,
      givesCheckmate: probe.in_checkmate,
      // Passed for the sake of the first wrong try, which is the only thing a
      // trainer can read afterwards: `e2e4` says nothing to anyone.
      san: _sanFor(game.fen, from, to, promotion),
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
        setState(() {
          _feedback = 'Nije to. Zadatak ima jedan pokušaj, potez je zabeležen.';
          _feedbackIsGood = false;
        });
        await _finish(solved: false, note: 'Nije rešeno.');
        return;
      }

      // Practice: straight back to trying, with no button in between. The
      // mistake stays on the session's record, so a retried puzzle still does
      // not count as a clean solve and the rating is unaffected.
      session.retryAfterMistake();
      setState(() {
        _feedback = 'Nije to. Probajte drugi potez.';
        _feedbackIsGood = false;
      });
      return;
    }

    game.move({'from': from, 'to': to, 'promotion': promotion});
    _boardController.loadFen(game.fen);

    setState(() {
      _hintSquare = null;
      _feedback = verdict.puzzleSolved ? null : 'Tačno — nastavite.';
      _feedbackIsGood = true;
    });

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

    game.move({
      'from': uci.substring(0, 2),
      'to': uci.substring(2, 4),
      if (uci.length > 4) 'promotion': uci[4],
    });
    _boardController.loadFen(game.fen);

    if (!mounted || token != _puzzleToken) return;
    setState(() => _boardLocked = _session?.isComplete ?? true);
  }

  /// Records the attempt and closes the puzzle.
  ///
  /// [note] replaces the message when neither "solved" nor "solved with help"
  /// is the truth — a wrong answer to homework, which has one attempt, is
  /// finished too.
  Future<void> _finish({required bool solved, String? note}) async {
    final puzzle = _puzzle;
    if (puzzle == null) return;

    setState(() {
      _boardLocked = true;
      _feedback = note ?? (solved ? 'Rešeno!' : 'Rešeno uz pomoć.');
      _feedbackIsGood = solved;
    });

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

      game.move({
        'from': move.substring(0, 2),
        'to': move.substring(2, 4),
        if (move.length > 4) 'promotion': move[4],
      });
      _boardController.loadFen(game.fen);
      setState(() {});
    }

    // Recorded once. A homework answer that was already submitted as wrong
    // must not be sent a second time just because the user then looked at the
    // solution — the first attempt is the one that counts, on both sides.
    if (_attemptRecorded) {
      setState(() => _boardLocked = true);
      return;
    }
    await _finish(solved: false);
  }

  void _useHint() {
    final square = _session?.revealHint();
    if (square == null) return;
    setState(() {
      _hintSquare = square;
      _feedback = 'Pomerite figuru sa polja $square.';
      _feedbackIsGood = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text(widget.assignmentTitle ?? 'Taktika'),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_assignmentFinished) {
      return _buildAssignmentDone();
    }
    if (_error != null) {
      return _buildError();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // The board is square, so it is bounded by whichever axis is tighter.
        // Taking the minimum against the width matters on a short, narrow window
        // where the height-derived size would otherwise exceed it and overflow.
        final heightBased = (constraints.maxHeight - 240).clamp(220.0, 560.0);
        final widthBased = (constraints.maxWidth - 24).clamp(180.0, 560.0);
        final boardSize = heightBased < widthBased ? heightBased : widthBased;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              _buildHeader(),
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: boardSize,
                  height: boardSize,
                  child: ChessBoardWithOverlay(
                    controller: _boardController,
                    boardOrientation: _orientation,
                    boardSize: boardSize,
                    isAllowedToMove: !_boardLocked,
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
              _buildFeedback(),
              const SizedBox(height: 12),
              _buildControls(),
            ],
          ),
        );
      },
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

  Widget _buildAssignmentDone() {
    // Reaching the end of the list is not the same as finishing the homework,
    // and saying so was the whole bug: skipped puzzles stay unanswered, the
    // assignment is not marked complete, and the trainer is never told - while
    // the student had been shown "Zadatak je završen" and reasonably went away.
    final skipped = _skipped.length;
    final unfinished = skipped > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              unfinished ? 'Domaći još nije predat.' : 'Zadatak je završen.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              unfinished
                  ? 'Preskočili ste ${puzzleCountLabel(skipped)}. Domaći se '
                      'predaje tek kad ih pokušate — do tada trener ne dobija '
                      'obaveštenje da ste završili.'
                  : 'Vaš trener vidi rezultat.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 20),
            // Wrap, not Row: two buttons side by side are wider than a 360 px
            // phone, and a release build clips the second one in silence.
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (unfinished)
                  ElevatedButton.icon(
                    onPressed: _retrySkipped,
                    icon: const Icon(Icons.playlist_add_check),
                    label: const Text('Uradi preskočene'),
                  ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Nazad na zadatke'),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: context.colors.textMuted),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadNext,
              icon: const Icon(Icons.refresh),
              label: const Text('Pokušaj ponovo'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final puzzle = _puzzle;
    final session = _session;
    if (puzzle == null || session == null) return const SizedBox.shrink();

    final toMove = _orientation == PlayerColor.white ? 'Beli' : 'Crni';

    return Card(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$toMove na potezu — nađite najbolji potez',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text('${puzzle.rating}'),
                  avatar: const Icon(Icons.speed, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              // The motif is deliberately withheld until it is over: naming it
              // upfront gives the puzzle away.
              session.isComplete && puzzle.trainableThemes.isNotEmpty
                  ? 'Motiv: ${puzzle.trainableThemes.join(', ')}'
                  : 'Potrebno poteza: ${puzzle.userMoveCount} · '
                      'pronađeno ${session.solvedMoveCount}',
              style:
                  TextStyle(fontSize: 12, color: context.colors.textSecondary),
            ),
            if (widget.isAssignment) ...[
              const SizedBox(height: 4),
              Text(
                'Zadatak: $_assignmentIndex od ${widget.puzzleIds!.length}',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
            ] else if (_selection?.targetTheme != null &&
                !session.isComplete) ...[
              const SizedBox(height: 4),
              Text(
                'Vežbate svoju najslabiju temu.',
                style: TextStyle(fontSize: 11, color: context.colors.textMuted),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    final result = _lastResult;
    final message = _feedback;

    if (result != null) {
      final positive = result.ratingChange >= 0;
      return Card(
        color: (positive ? context.colors.success : context.colors.danger)
            .withValues(alpha: 0.12),
        child: ListTile(
          leading: Icon(
            positive ? Icons.trending_up : Icons.trending_down,
            color: positive ? context.colors.success : context.colors.danger,
          ),
          title: Text('Rejting: ${result.newRating} '
              '(${result.ratingChange >= 0 ? '+' : ''}${result.ratingChange})'),
          subtitle: Text('Težina zagonetke: ${result.puzzleRating} · '
              'ukupno rešeno: ${result.puzzlesSolved}'),
        ),
      );
    }

    if (message == null) return const SizedBox(height: 8);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            (_feedbackIsGood ? context.colors.success : context.colors.warning)
                .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _feedbackIsGood ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: _feedbackIsGood
                ? context.colors.success
                : context.colors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
        ],
      ),
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
        if (!complete)
          OutlinedButton.icon(
            onPressed: _hintSquare == null ? _useHint : null,
            icon: const Icon(Icons.lightbulb_outline),
            label: const Text('Pomoć'),
          ),
        if (!complete || failedNow)
          OutlinedButton.icon(
            onPressed: _showSolution,
            icon: const Icon(Icons.visibility),
            label: const Text('Prikaži rešenje'),
          ),
        ElevatedButton.icon(
          onPressed: _loadNext,
          icon: const Icon(Icons.skip_next),
          label: Text(complete ? 'Sledeća zagonetka' : 'Preskoči'),
        ),
      ],
    );
  }
}

/// "1 zagonetku", "2 zagonetke", "5 zagonetaka" — the accusative the sentence
/// above needs, in the three forms Serbian actually uses.
///
/// Written out rather than fudged with "zagonetki(e)": this string is read by
/// children, and the app is theirs before it is anybody's. The 11-14 exception
/// is the one that catches every naive implementation - 11 takes the same form
/// as 5, not the same as 1.
String puzzleCountLabel(int count) {
  final last = count % 10;
  final lastTwo = count % 100;

  if (last == 1 && lastTwo != 11) return '$count zagonetku';
  if (last >= 2 && last <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return '$count zagonetke';
  }
  return '$count zagonetaka';
}
