import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

import '../models/assignment.dart';
import '../models/puzzle_review.dart';
import '../models/solve_order.dart';
import '../models/solve_target.dart';
import '../services/assignment_api_service.dart';
import 'assignment_review_screen.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// A student works through homework built from the trainer's own positions.
///
/// Every position arrives with a task and without an answer. The move is sent
/// to the server to be judged, because the solution stays there until it has
/// been earned — and because the rule that judges it is not a string
/// comparison: when the task was to mate, any mate counts. A child who finds a
/// different mate has solved the exercise, and hearing otherwise teaches them
/// to distrust the app rather than to look harder.
///
/// Homework passes [detail]; one's own exercises pass a [target] instead
/// (`docs/PLAN-MATERIJAL.md`, phase 1). One of the two, never both.
class CustomPuzzleSolverScreen extends StatefulWidget {
  const CustomPuzzleSolverScreen({
    super.key,
    required this.session,
    this.detail,
    this.target,
    required this.positions,
    required this.startIndex,
    this.answered = const {},
    this.onAnswered,
    this.api,
  }) : assert((detail == null) != (target == null),
            'a solver is for a homework or for a target, exactly one');

  final UserSession session;

  /// The homework being solved, or null when [target] says what for.
  final AssignmentDetail? detail;

  /// What the positions are solved for, when it is not a homework.
  final SolveTarget? target;

  /// Injectable for tests, the same seam `ChessGamePage.lessonApi` uses. The
  /// real one talks to the backend; a widget test that reached it would be
  /// asserting against whatever a server happened to answer.
  final AssignmentApiService? api;

  /// Every position in the assignment, in the trainer's order — not only the
  /// ones still to do. The student chooses where to start, and an answered
  /// position can be opened again to look at it; it just cannot be answered
  /// twice, because only the first attempt is recorded.
  final List<CustomPosition> positions;

  final int startIndex;

  /// puzzleId → whether it was answered correctly, as known when this screen
  /// opened.
  final Map<String, bool> answered;

  /// Reports each answer up, so the grid behind is right the moment the student
  /// comes back instead of after a refetch.
  final void Function(String puzzleId, bool correct)? onAnswered;

  @override
  State<CustomPuzzleSolverScreen> createState() =>
      _CustomPuzzleSolverScreenState();
}

class _CustomPuzzleSolverScreenState extends State<CustomPuzzleSolverScreen> {
  late final AssignmentApiService _api;
  late final SolveTarget _target;
  final ChessBoardController _board = ChessBoardController();

  /// The portrait column's scroll, so choosing a line brings the board — and
  /// the strip under it — back into view.
  final ScrollController _scroll = ScrollController();

  /// Every position, in the trainer's order.
  List<CustomPosition> get _queue => widget.positions;

  /// What has been answered so far, this session and before it. An answered
  /// position locks its board and `_verdictPanel` shows this instead
  /// (`_alreadyAnswered`). A find exercise asks for one move, so the first
  /// answer is the answer (`docs/PLAN-EXERCISE.md`, phases 14 and 16).
  late final Map<String, bool> _answered;

  int _index = 0;

  /// The server's verdict on the position on screen; null until it answers.
  CustomAttemptResult? _verdict;

  /// What a puzzle from a game reveals, made from [_verdict]'s review when the
  /// answer arrives (`docs/PLAN-ZAGONETKE-IZ-PARTIJE.md`, phase 5); null for
  /// every other exercise, and always before the move.
  PuzzleReveal? _reveal;

  /// The line the reveal is playing on the board, and how far into it; null
  /// while the board shows the puzzle.
  RevealLine? _revealLine;
  int _revealPly = 0;
  bool _sending = false;
  DateTime _shownAt = DateTime.now();

  CustomPosition get _current => _queue[_index];

  /// Whether the position on screen has already been answered, and how. Null
  /// means it is still open.
  bool? get _alreadyAnswered => _answered[_current.puzzleId];

  int get _solved => _answered.values.where((ok) => ok).length;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AssignmentApiService(authToken: widget.session.token);
    _target = widget.target ?? _homeworkTarget(widget.detail!);
    _answered = Map<String, bool>.from(widget.answered);
    _index = widget.startIndex.clamp(0, (_queue.length - 1).clamp(0, 1 << 30));

    if (_queue.isNotEmpty) _load();
  }

  /// Homework's four answers: its title, its note, its route for an answer,
  /// and its review.
  SolveTarget _homeworkTarget(AssignmentDetail detail) => SolveTarget(
        title: detail.assignment.title,
        note: detail.assignment.instructions,
        submit: (puzzleId, moveSan, msTaken) => _api.submitCustomAttempt(
          assignmentId: detail.assignment.id,
          puzzleId: puzzleId,
          moveSan: moveSan,
          msTaken: msTaken,
        ),
        onReview: (_) => _openReview(detail),
      );

  @override
  void dispose() {
    _board.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _load() {
    _board.loadFen(_current.fen);
    setState(() {
      _verdict = null;
      _reveal = null;
      _revealLine = null;
      _revealPly = 0;
      _shownAt = DateTime.now();
    });
  }

  /// Plays [line] from its start, the first move shown as an arrow.
  void _showLine(RevealLine line) {
    _board.loadFen(line.fens.first);
    setState(() {
      _revealLine = line;
      _revealPly = 0;
    });
    // The tiles sit under the verdict, below the board: a line walked on a
    // board scrolled out of sight is a line nobody sees (found by looking at
    // the screen at 360 x 640, where only three ranks were left in view).
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  void _seekLine(int ply) {
    final line = _revealLine;
    if (line == null) return;
    final to = ply.clamp(0, line.length);
    _board.loadFen(line.fens[to]);
    setState(() => _revealPly = to);
  }

  /// Back to the question's own position, whatever line was on the board.
  void _backToPuzzle() {
    _board.loadFen(_current.fen);
    setState(() {
      _revealLine = null;
      _revealPly = 0;
    });
  }

  PlayerColor get _orientation =>
      _current.sideToMove == 'b' ? PlayerColor.black : PlayerColor.white;

  /// Turns the move just played on the board into SAN, then asks the server.
  ///
  /// `move_to_san` has to be asked *before* the move exists on the board — it
  /// reads the position it is given, and called afterwards it throws. That
  /// exception, swallowed inside an async handler, left the screen sitting on
  /// "odigraj potez" with the piece already moved and nothing else happening:
  /// the worst possible failure, because it is indistinguishable from the app
  /// simply ignoring the child.
  static String? _sanFor(String fen, String from, String to, String promotion) {
    try {
      final game = chess.Chess.fromFEN(fen);
      // The piece the reader chose, not a queen by default: the answer to a
      // puzzle is sometimes a knight, and it is sent as SAN — `d8=N` and
      // `d8=Q` are different answers.
      if (!game.move({
        'from': from,
        'to': to,
        'promotion': promotion.isEmpty ? 'q' : promotion,
      })) {
        return null;
      }
      final made = game.history.last.move;
      game.undo_move();
      return game.move_to_san(made);
    } catch (e) {
      AppLogger.log('[Solver] SAN not calculated: $e');
      return null;
    }
  }

  Future<void> _onMove(String from, String to, String promotion) async {
    if (_sending || _verdict != null) return;

    final san = _sanFor(_current.fen, from, to, promotion);
    if (san == null) {
      // Not a legal move here, or we could not read it. Either way the board
      // goes back so the student is never left looking at a position that no
      // longer matches the question.
      _board.loadFen(_current.fen);
      return;
    }
    await _send(san);
  }

  /// Sends the move and shows what the server said of it.
  Future<void> _send(String san) async {
    final puzzleId = _current.puzzleId;
    setState(() => _sending = true);
    final result = await _target.submit(
      puzzleId,
      san,
      DateTime.now().difference(_shownAt).inMilliseconds,
    );
    if (!mounted) return;

    if (result == null) {
      setState(() => _sending = false);
      _board.loadFen(_current.fen);
      AppFeedback.show(
        context,
        () => const SnackBar(content: Text('Answer not sent — try again.')),
      );
      return;
    }

    // Do the thing, then say it. A right move stays on the board; a wrong
    // one is taken back, so the position shown is the one that was asked.
    if (!result.correct) _board.loadFen(_current.fen);
    widget.onAnswered?.call(puzzleId, result.correct);
    final review = result.review;
    setState(() {
      _sending = false;
      _verdict = result;
      _reveal = review == null
          ? null
          : PuzzleReveal.of(
              fen: _current.fen,
              review: review,
              solverSan: result.playedSan,
              correct: result.correct,
            );
      _answered[puzzleId] = result.correct;
    });
  }

  /// Moves to the next position still waiting, in the trainer's order.
  ///
  /// It wraps, so a position skipped early is still reached from the end rather
  /// than being left behind by a button that says "next".
  void _next() {
    final target = nextUnanswered(
      puzzleIds: _queue.map((p) => p.puzzleId).toList(),
      answered: _answered.keys.toSet(),
      from: _index,
    );
    if (target == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index = target);
    _load();
  }

  /// Steps through the positions as they are listed, answered or not, so the
  /// student can look around rather than only forward.
  void _step(int delta) {
    final target = _index + delta;
    if (target < 0 || target >= _queue.length) return;
    setState(() => _index = target);
    _load();
  }

  Future<void> _openReview(AssignmentDetail detail) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssignmentReviewScreen(
          session: widget.session,
          assignmentId: detail.assignment.id,
          title: detail.assignment.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_target.title)),
        body: Center(
            child: Text(widget.detail != null
                ? 'This assignment has no positions.'
                : 'Nothing is waiting to be solved.')),
      );
    }

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
        title: Text(_target.title),
        actions: [
          const BoardViewMenu(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.grid_view),
            tooltip: 'All positions',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            // How much is done, not how far along the queue we are: with a free
            // order the second number was never the same question.
            value: _answered.length / _queue.length,
            minHeight: 4,
            backgroundColor: colors.surfaceRaised,
          ),
        ),
      ),
      // The arrow keys walk the reveal's line, as its strip does. With no line
      // on the board the cursor holds no positions, so the keys have nowhere
      // to go while the position is still a question.
      body: MoveKeyboardShortcuts(
        cursor: _revealCursor(),
        // The cursor's own onSeek already redraws the board.
        onChanged: () {},
        child: SafeArea(
          child: LandscapeBoardLayout.applies(context)
              ? LandscapeBoardLayout(
                  board: _boardView,
                  // The verdict scrolls with the task: with a reveal it is
                  // taller than a pinned footer can hold on a phone on its side.
                  panels: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _header(),
                      const SizedBox(height: AppSpacing.sm),
                      _verdictPanel(),
                    ],
                  ),
                  footer: [
                    if (_revealLine != null) _revealStrip(_revealLine!),
                  ],
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final heightBased =
                        (constraints.maxHeight - 280).clamp(200.0, 520.0);
                    final widthBased =
                        (constraints.maxWidth - 24).clamp(180.0, 520.0);
                    final boardSize =
                        heightBased < widthBased ? heightBased : widthBased;

                    return SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          _header(),
                          const SizedBox(height: 10),
                          Center(child: _boardView(boardSize)),
                          // The strip right under the board, so the line and
                          // the board it walks are in view together.
                          if (_revealLine != null) _revealStrip(_revealLine!),
                          const SizedBox(height: AppSpacing.md),
                          _verdictPanel(),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  /// The cursor over the reveal's line — the strip's and the keys' alike.
  LinearMoveCursor _revealCursor() {
    final line = _revealLine;
    return LinearMoveCursor(
      fens: line?.fens ?? const [],
      index: _revealPly,
      onSeek: _seekLine,
    );
  }

  Widget _header() {
    final colors = context.colors;
    final assignmentNote = _target.note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _index == 0 ? null : () => _step(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous',
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text(
                'Position ${_index + 1} of ${_queue.length}',
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(color: colors.textSecondary),
              ),
            ),
            IconButton(
              onPressed: _index + 1 >= _queue.length ? null : () => _step(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next',
              visualDensity: VisualDensity.compact,
            ),
            Text('Correct: $_solved',
                style: AppText.body.copyWith(color: colors.success)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // The task, in the place a student looks first. Without it this screen
        // is a board and a stopwatch.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: AppRadii.roundedSm,
            border: Border.all(color: colors.accent),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flag_outlined, size: 18, color: colors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _current.instruction ??
                      '${_current.sideToMove == 'w' ? 'White' : 'Black'} to move.',
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (assignmentNote != null && assignmentNote.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(assignmentNote,
              style: AppText.body.copyWith(color: colors.textMuted)),
        ],
      ],
    );
  }

  Widget _boardView(double boardSize) => BoardWithCoordinates(
        size: boardSize,
        orientation: _orientation,
        builder: (size) => ChessBoardWithOverlay(
          controller: _board,
          boardOrientation: _orientation,
          boardSize: size,
          // Locked once answered — in this sitting or an earlier one. Only the
          // first attempt is recorded, so a board that still accepted moves
          // would promise a second chance that does not exist.
          isAllowedToMove:
              _verdict == null && !_sending && _alreadyAnswered == null,
          isDrawingMode: false,
          drawingStartSquare: null,
          arrows: _revealLine?.arrowsAt(_revealPly) ?? const [],
          engineArrows: const [],
          onMove: _onMove,
          // Closed while the position is still the question, open once it is
          // answered — the same moment the board stops taking moves. It is
          // off so that no help is used, not so that nothing is learned after.
          copyPosition: _verdict != null || _alreadyAnswered != null,
          onSquareTapForDrawing: (_) {},
        ),
      );

  Widget _verdictPanel() {
    final colors = context.colors;
    if (_sending) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: CircularProgressIndicator(),
      );
    }
    final verdict = _verdict;
    if (verdict == null) {
      // Answered in an earlier sitting. The board is locked and says why, in
      // place of a hint to play a move that would not count.
      final settled = _alreadyAnswered;
      if (settled != null) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(settled ? Icons.check_circle : Icons.cancel,
                    color: settled ? colors.success : colors.danger, size: 18),
                const SizedBox(width: 6),
                Text(
                    settled
                        ? 'Already completed — correct'
                        : 'Already completed — incorrect',
                    style: TextStyle(
                        color: settled ? colors.success : colors.danger,
                        fontSize: 14)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Score does not change — only the first attempt counts.',
                style: AppText.body.copyWith(color: colors.textMuted)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (_target.onReview != null)
                  OutlinedButton.icon(
                    onPressed: () => _target.onReview!(context),
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    label: const Text('Solution and comments'),
                  ),
                FilledButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next unsolved'),
                ),
              ],
            ),
          ],
        );
      }

      return Text(
        'Play a move on the board.',
        style: AppText.body.copyWith(color: colors.textMuted),
      );
    }

    final tone = verdict.correct ? colors.success : colors.danger;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(verdict.correct ? Icons.check_circle : Icons.cancel,
                color: tone, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              verdict.correct ? 'Correct' : 'Not quite',
              style: AppText.title.copyWith(color: tone),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // "a different mate, but mate" is worth saying out loud: the student
        // found something the book did not print, and should know it counted.
        // The string is `customPuzzleJudge.js`'s, byte for byte.
        if (verdict.correct && verdict.reason == 'a different mate, but mate')
          Text('Different checkmate from the book — but mate is mate.',
              style: AppText.body.copyWith(color: colors.textSecondary)),
        if (!verdict.correct && verdict.solutionSan != null)
          Text('Solution: ${verdict.solutionSan}',
              style: AppText.bodyLarge.copyWith(color: colors.textSecondary)),
        if (_reveal != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _revealPanel(_reveal!),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            // The exercise's own screen, for one's own exercise: its answer,
            // its words, and the place to change them.
            if (_target.onOpen != null)
              OutlinedButton.icon(
                key: const Key('solver-open'),
                onPressed: () => _target.onOpen!(context, _current),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open'),
              ),
            FilledButton.icon(
              onPressed: _next,
              icon: const Icon(Icons.arrow_forward),
              // "Finish" only when nothing is left anywhere in the assignment
              // — being at the end of the list is no longer the same thing.
              label: Text(_answered.length >= _queue.length
                  ? 'Finish'
                  : 'Next unsolved'),
            ),
          ],
        ),
      ],
    );
  }

  /// The reveal, after the verdict and right or wrong: the words, each line
  /// the review offers, and what is said of the solver's own move. The strip
  /// that walks a chosen line is [_revealStrip], beside the board.
  Widget _revealPanel(PuzzleReveal reveal) {
    final colors = context.colors;
    return Column(
      key: const Key('reveal'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reveal.words != null) ...[
          Text(reveal.words!,
              key: const Key('reveal-words'),
              style: AppText.body.copyWith(color: colors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
        ],
        for (final l in reveal.lines) ...[
          _revealTile(l),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (reveal.note != null)
          Text(reveal.note!,
              key: const Key('reveal-note'),
              style: AppText.body.copyWith(color: colors.textSecondary)),
      ],
    );
  }

  /// The strip that walks [line], its moves, and the way back to the puzzle —
  /// under the board in portrait, pinned under the panels on a phone on its
  /// side.
  Widget _revealStrip(RevealLine line) {
    final colors = context.colors;
    return Column(
      key: const Key('reveal-strip'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MoveNavigationControls(
          cursor: _revealCursor(),
          centerLabel: '$_revealPly / ${line.length}',
        ),
        Row(
          children: [
            Expanded(
              child: Text(line.sans.join(' '),
                  key: const Key('reveal-moves'),
                  style: AppText.body.copyWith(color: colors.textSecondary)),
            ),
            TextButton.icon(
              key: const Key('reveal-back'),
              onPressed: _backToPuzzle,
              icon: const Icon(Icons.undo, size: 16),
              label: const Text('Back to the puzzle'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _revealTile(RevealLine line) {
    final colors = context.colors;
    final chosen = identical(line, _revealLine) ||
        (_revealLine?.kind == line.kind && _revealLine != null);
    return OutlinedButton(
      key: ValueKey('reveal-line-${line.kind.name}'),
      onPressed: () => _showLine(line),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        side: BorderSide(
            color: chosen ? colors.accent : colors.border,
            width: chosen ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(line.title,
              style: AppText.bodyBold.copyWith(color: colors.textPrimary)),
          Text(line.caption,
              style: AppText.caption.copyWith(color: colors.textSecondary)),
        ],
      ),
    );
  }
}
