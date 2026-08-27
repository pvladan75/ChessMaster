import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/app_logger.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_coordinates_button.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import '../models/assignment.dart';
import '../models/solve_order.dart';
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
class CustomPuzzleSolverScreen extends StatefulWidget {
  const CustomPuzzleSolverScreen({
    super.key,
    required this.session,
    required this.detail,
    required this.positions,
    required this.startIndex,
    this.answered = const {},
    this.onAnswered,
  });

  final UserSession session;
  final AssignmentDetail detail;

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
  final ChessBoardController _board = ChessBoardController();

  /// Every position, in the trainer's order.
  List<CustomPosition> get _queue => widget.positions;

  /// What has been answered so far, this session and before it.
  late final Map<String, bool> _answered;

  int _index = 0;
  CustomAttemptResult? _verdict;
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
    _api = AssignmentApiService(authToken: widget.session.token);
    _answered = Map<String, bool>.from(widget.answered);
    _index = widget.startIndex.clamp(0, (_queue.length - 1).clamp(0, 1 << 30));

    if (_queue.isNotEmpty) _load();
  }

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  void _load() {
    _board.loadFen(_current.fen);
    setState(() {
      _verdict = null;
      _shownAt = DateTime.now();
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
      AppLogger.log('[Solver] SAN nije izračunat: $e');
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

    setState(() => _sending = true);
    final result = await _api.submitCustomAttempt(
      assignmentId: widget.detail.assignment.id,
      puzzleId: _current.puzzleId,
      moveSan: san,
      msTaken: DateTime.now().difference(_shownAt).inMilliseconds,
    );
    if (!mounted) return;

    if (result == null) {
      setState(() => _sending = false);
      _board.loadFen(_current.fen);
      AppFeedback.show(
        context,
        () => const SnackBar(
            content: Text('Odgovor nije poslat — pokušaj ponovo.')),
      );
      return;
    }

    setState(() {
      _sending = false;
      _verdict = result;
      _answered[_current.puzzleId] = result.correct;
    });
    widget.onAnswered?.call(_current.puzzleId, result.correct);
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

  Future<void> _openReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssignmentReviewScreen(
          session: widget.session,
          assignmentId: widget.detail.assignment.id,
          title: widget.detail.assignment.title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.detail.assignment.title)),
        body: const Center(child: Text('Ovaj zadatak nema nijednu poziciju.')),
      );
    }

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: Text(widget.detail.assignment.title),
        actions: [
          const BoardCoordinatesButton(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.grid_view),
            tooltip: 'Sve pozicije',
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final heightBased =
                (constraints.maxHeight - 280).clamp(200.0, 520.0);
            final widthBased = (constraints.maxWidth - 24).clamp(180.0, 520.0);
            final boardSize =
                heightBased < widthBased ? heightBased : widthBased;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _header(),
                  const SizedBox(height: 10),
                  Center(
                    child: BoardWithCoordinates(
                      size: boardSize,
                      orientation: _orientation,
                      builder: (size) => ChessBoardWithOverlay(
                        controller: _board,
                        boardOrientation: _orientation,
                        boardSize: size,
                        // Locked once answered — in this sitting or an
                        // earlier one. Only the first attempt is recorded, so a
                        // board that still accepted moves would promise a
                        // second chance that does not exist.
                        isAllowedToMove: _verdict == null &&
                            !_sending &&
                            _alreadyAnswered == null,
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
                  _verdictPanel(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    final colors = context.colors;
    final assignmentNote = widget.detail.assignment.instructions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _index == 0 ? null : () => _step(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Prethodna',
              visualDensity: VisualDensity.compact,
            ),
            Expanded(
              child: Text(
                'Pozicija ${_index + 1} od ${_queue.length}',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
            ),
            IconButton(
              onPressed: _index + 1 >= _queue.length ? null : () => _step(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Sledeća',
              visualDensity: VisualDensity.compact,
            ),
            Text('Tačno: $_solved',
                style: TextStyle(color: colors.success, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        // The task, in the place a student looks first. Without it this screen
        // is a board and a stopwatch.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.accent),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.flag_outlined, size: 18, color: colors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _current.instruction ??
                      '${_current.sideToMove == 'w' ? 'Beli' : 'Crni'} je na potezu.',
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
              style: TextStyle(fontSize: 12, color: colors.textMuted)),
        ],
      ],
    );
  }

  Widget _verdictPanel() {
    final colors = context.colors;
    if (_sending) {
      return const Padding(
        padding: EdgeInsets.all(12),
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
                Text(settled ? 'Već urađeno — tačno' : 'Već urađeno — netačno',
                    style: TextStyle(
                        color: settled ? colors.success : colors.danger,
                        fontSize: 14)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Rezultat se ne menja — računa se prvi pokušaj.',
                style: TextStyle(color: colors.textMuted, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _openReview,
                  icon: const Icon(Icons.rate_review_outlined, size: 16),
                  label: const Text('Rešenje i komentari'),
                ),
                FilledButton.icon(
                  onPressed: _next,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Sledeća nerešena'),
                ),
              ],
            ),
          ],
        );
      }

      return Text(
        'Odigraj potez na tabli.',
        style: TextStyle(color: colors.textMuted, fontSize: 12),
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
            const SizedBox(width: 8),
            Text(
              verdict.correct ? 'Tačno' : 'Nije to',
              style: TextStyle(
                  color: tone, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // "drugi mat, ali mat" is worth saying out loud: the student found
        // something the book did not print, and should know it counted.
        if (verdict.correct && verdict.reason == 'drugi mat, ali mat')
          Text('Drugi mat od onog u knjizi — ali mat je mat.',
              style: TextStyle(color: colors.textSecondary, fontSize: 12)),
        if (!verdict.correct && verdict.solutionSan != null)
          Text('Rešenje: ${verdict.solutionSan}',
              style: TextStyle(color: colors.textSecondary, fontSize: 13)),
        const SizedBox(height: 10),
        FilledButton.icon(
          onPressed: _next,
          icon: const Icon(Icons.arrow_forward),
          // "Finish" only when nothing is left anywhere in the assignment —
          // being at the end of the list is no longer the same thing.
          label: Text(_answered.length >= _queue.length
              ? 'Završi'
              : 'Sledeća nerešena'),
        ),
      ],
    );
  }
}
