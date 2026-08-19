import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

import '../models/assignment.dart';
import '../services/assignment_api_service.dart';

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
  });

  final UserSession session;
  final AssignmentDetail detail;

  @override
  State<CustomPuzzleSolverScreen> createState() =>
      _CustomPuzzleSolverScreenState();
}

class _CustomPuzzleSolverScreenState extends State<CustomPuzzleSolverScreen> {
  late final AssignmentApiService _api;
  final ChessBoardController _board = ChessBoardController();

  /// Only the positions still unanswered, in the order the trainer set them.
  late final List<CustomPosition> _queue;

  int _index = 0;
  CustomAttemptResult? _verdict;
  bool _sending = false;
  DateTime _shownAt = DateTime.now();
  int _solved = 0;

  CustomPosition get _current => _queue[_index];

  @override
  void initState() {
    super.initState();
    _api = AssignmentApiService(authToken: widget.session.token);

    final pendingIds =
        widget.detail.pending.map((item) => item.puzzleId).toSet();
    _queue = widget.detail.items
        .where((item) => pendingIds.contains(item.puzzleId))
        .map((item) => widget.detail.positionFor(item.puzzleId ?? ''))
        .whereType<CustomPosition>()
        .toList();

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
  Future<void> _onMove(String from, String to) async {
    if (_sending || _verdict != null) return;

    final game = chess.Chess.fromFEN(_current.fen);
    final move = game.move({'from': from, 'to': to, 'promotion': 'q'});
    if (move == false) {
      _board.loadFen(_current.fen);
      return;
    }
    final san =
        game.history.isEmpty ? '' : game.move_to_san(game.history.last.move);

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Odgovor nije poslat — pokušaj ponovo.')),
      );
      return;
    }

    setState(() {
      _sending = false;
      _verdict = result;
      if (result.correct) _solved += 1;
    });
  }

  void _next() {
    if (_index + 1 >= _queue.length) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _index += 1);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (_queue.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.detail.assignment.title)),
        body: const Center(
            child: Text('Sve pozicije iz ovog zadatka su urađene.')),
      );
    }

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: Text(widget.detail.assignment.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_index + 1) / _queue.length,
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
                    child: SizedBox(
                      width: boardSize,
                      height: boardSize,
                      child: ChessBoardWithOverlay(
                        controller: _board,
                        boardOrientation: _orientation,
                        boardSize: boardSize,
                        // Locked once answered: the question has been settled
                        // and shuffling pieces afterwards only muddles it.
                        isAllowedToMove: _verdict == null && !_sending,
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
            Expanded(
              child: Text(
                'Pozicija ${_index + 1} od ${_queue.length}',
                style: TextStyle(color: colors.textSecondary, fontSize: 12),
              ),
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
          label: Text(_index + 1 >= _queue.length ? 'Završi' : 'Sledeća'),
        ),
      ],
    );
  }
}
