import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/pgn_parser.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import '../models/assignment.dart';
import '../services/assignment_api_service.dart';

/// Lets a student work through an assigned lesson on their own.
///
/// The lesson builder already produces multi-step lessons, but until now they
/// could only be shown by a trainer inside a live session — so a student had no
/// way to revisit one between lessons. This is that missing half: the same steps,
/// self-paced, with each one recorded as it is read.
class LessonViewerScreen extends StatefulWidget {
  const LessonViewerScreen({
    super.key,
    required this.session,
    required this.detail,
  });

  final UserSession session;
  final AssignmentDetail detail;

  @override
  State<LessonViewerScreen> createState() => _LessonViewerScreenState();
}

class _LessonViewerScreenState extends State<LessonViewerScreen> {
  late final AssignmentApiService _api;
  final ChessBoardController _board = ChessBoardController();

  late int _stepIndex;
  late final Set<int> _seen;

  /// Positions of the current step's line, when it was saved from an analysis
  /// tree. Empty when the step is a single position.
  List<String> _fens = const [];
  List<String> _moves = const [];
  int _moveIndex = 0;

  PlayerColor _orientation = PlayerColor.white;

  List<LessonStep> get _steps => widget.detail.steps;
  LessonStep get _step => _steps[_stepIndex];

  @override
  void initState() {
    super.initState();
    _api = AssignmentApiService(authToken: widget.session.token);
    _seen = widget.detail.items.where((i) => i.isDone).map((i) => i.position).toSet();
    // Resume where the student stopped rather than restarting the lesson.
    _stepIndex = widget.detail.resumeStepIndex.clamp(0, _steps.length - 1);
    _loadStep();
  }

  @override
  void dispose() {
    _board.dispose();
    super.dispose();
  }

  void _loadStep() {
    final step = _step;

    // A step saved from the analysis board carries its line as PGN, and replaying
    // it is what lets the student walk the variation instead of staring at the
    // final position.
    //
    // PgnParser always replays from the standard starting position and drops the
    // PGN tags, so a lesson that began from a custom position would come back as
    // a different game entirely. The parsed line is therefore only trusted when
    // its first position matches the step's own — otherwise the step is shown as
    // a still position, which is wrong-free rather than wrong.
    List<String> fens = const [];
    List<String> moves = const [];
    final pgn = step.pgn;
    if (pgn != null && pgn.trim().isNotEmpty) {
      try {
        final parsed = PgnParser.parse(pgn);
        if (parsed != null && parsed.fens.isNotEmpty && _sameFen(parsed.fens.first, step.fen)) {
          fens = parsed.fens;
          moves = parsed.movesSan;
        }
      } catch (_) {
        // Fall through to the still position.
      }
    }

    setState(() {
      _fens = fens;
      _moves = moves;
      _moveIndex = 0;
      _orientation = _sideToMove(step.fen);
    });
    _board.loadFen(step.fen);

    _markSeen();
  }

  /// Compares the board part of two FENs. Move counters differ harmlessly
  /// between a stored position and a replayed one, so comparing whole strings
  /// would reject lines that are in fact the same.
  static bool _sameFen(String a, String b) {
    final left = a.trim().split(' ');
    final right = b.trim().split(' ');
    if (left.isEmpty || right.isEmpty) return false;
    return left.take(4).join(' ') == right.take(4).join(' ');
  }

  static PlayerColor _sideToMove(String fen) {
    try {
      return chess.Chess.fromFEN(fen).turn == chess.Color.WHITE
          ? PlayerColor.white
          : PlayerColor.black;
    } catch (_) {
      return PlayerColor.white;
    }
  }

  /// Records the step the first time it is opened. Repeat visits are cheap
  /// no-ops on the server, so re-reading a lesson is not penalised.
  void _markSeen() {
    if (_seen.contains(_stepIndex)) return;
    _seen.add(_stepIndex);
    _api.markLessonStep(
      assignmentId: widget.detail.assignment.id,
      position: _stepIndex,
    );
  }

  void _goToStep(int index) {
    if (index < 0 || index >= _steps.length) return;
    setState(() => _stepIndex = index);
    _loadStep();
  }

  /// Jumps to the position after [count] moves of the step's line.
  void _applyMovesUpTo(int count) {
    if (_fens.isEmpty) return;
    final index = count.clamp(0, _fens.length - 1);
    setState(() => _moveIndex = index);
    _board.loadFen(_fens[index]);
  }

  @override
  Widget build(BuildContext context) {
    if (_steps.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.detail.assignment.title)),
        body: const Center(child: Text('Ova lekcija nema nijedan korak.')),
      );
    }

    final done = _seen.length;

    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text(widget.detail.assignment.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.flip_camera_android),
            tooltip: 'Okreni tablu',
            onPressed: () => setState(() {
              _orientation =
                  _orientation == PlayerColor.white ? PlayerColor.black : PlayerColor.white;
            }),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: done / _steps.length,
            minHeight: 4,
            backgroundColor: context.colors.surfaceRaised,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final heightBased = (constraints.maxHeight - 250).clamp(200.0, 520.0);
            final widthBased = (constraints.maxWidth - 24).clamp(180.0, 520.0);
            final boardSize = heightBased < widthBased ? heightBased : widthBased;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  _buildHeader(done),
                  const SizedBox(height: 10),
                  Center(
                    child: SizedBox(
                      width: boardSize,
                      height: boardSize,
                      child: ChessBoardWithOverlay(
                        controller: _board,
                        boardOrientation: _orientation,
                        boardSize: boardSize,
                        // The student is reading a lesson, not playing it.
                        isAllowedToMove: false,
                        isDrawingMode: false,
                        drawingStartSquare: null,
                        arrows: const [],
                        engineArrows: const [],
                        onMove: (_, __) {},
                        onSquareTapForDrawing: (_) {},
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_moves.isNotEmpty) _buildMoveControls(),
                  const SizedBox(height: 10),
                  _buildStepControls(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(int done) {
    final instructions = widget.detail.assignment.instructions;

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
                    _step.title.isEmpty ? 'Korak ${_stepIndex + 1}' : _step.title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${_stepIndex + 1}/${_steps.length}',
                  style: TextStyle(fontSize: 13, color: context.colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Pregledano $done od ${_steps.length} koraka',
              style: TextStyle(fontSize: 11.5, color: context.colors.textMuted),
            ),
            if (instructions != null && instructions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(instructions, style: const TextStyle(fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMoveControls() {
    return Column(
      children: [
        Text(
          'Potez $_moveIndex od ${_moves.length}',
          style: TextStyle(fontSize: 12, color: context.colors.textSecondary),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.first_page),
              tooltip: 'Na početak',
              onPressed: _moveIndex == 0 ? null : () => _applyMovesUpTo(0),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Nazad',
              onPressed: _moveIndex == 0 ? null : () => _applyMovesUpTo(_moveIndex - 1),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Napred',
              onPressed:
                  _moveIndex >= _moves.length ? null : () => _applyMovesUpTo(_moveIndex + 1),
            ),
            IconButton(
              icon: const Icon(Icons.last_page),
              tooltip: 'Na kraj',
              onPressed:
                  _moveIndex >= _moves.length ? null : () => _applyMovesUpTo(_moves.length),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStepControls() {
    final isLast = _stepIndex >= _steps.length - 1;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _stepIndex == 0 ? null : () => _goToStep(_stepIndex - 1),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Prethodni korak'),
        ),
        ElevatedButton.icon(
          onPressed: isLast ? () => Navigator.of(context).maybePop() : () => _goToStep(_stepIndex + 1),
          icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
          label: Text(isLast ? 'Završi' : 'Sledeći korak'),
        ),
      ],
    );
  }
}
