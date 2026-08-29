import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/pgn_parser.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_coordinates_button.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
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

  /// One entry per move, in step with [_moves] — empty string where the trainer
  /// wrote nothing. Empty as a whole when the lesson carries no comments at
  /// all, or when they could not be lined up with the moves.
  List<String> _comments = const [];
  int _moveIndex = 0;

  PlayerColor _orientation = PlayerColor.white;

  /// True once the student has moved a piece away from the position the lesson
  /// is showing.
  ///
  /// The board used to be locked, and that was defensible while a step was only
  /// a picture. It stopped being defensible the moment a step could carry a
  /// task: a position scanned out of a book says "Beli matira u jednom potezu",
  /// and a child reading that reasonably tries to play it. Found live, by the
  /// student, in exactly those words.
  ///
  /// Nothing here is judged or recorded — the lesson is still read rather than
  /// solved. This is a board to try things on, and [_restore] puts it back.
  bool _explored = false;

  List<LessonStep> get _steps => widget.detail.steps;
  LessonStep get _step => _steps[_stepIndex];

  @override
  void initState() {
    super.initState();
    _api = AssignmentApiService(authToken: widget.session.token);
    _seen = widget.detail.items
        .where((i) => i.isDone)
        .map((i) => i.position)
        .toSet();
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
    List<String> comments = const [];
    final pgn = step.pgn;
    if (pgn != null && pgn.trim().isNotEmpty) {
      try {
        final parsed = PgnParser.parse(pgn);
        if (parsed != null &&
            parsed.fens.isNotEmpty &&
            _sameFen(parsed.fens.first, step.fen)) {
          fens = parsed.fens;
          moves = parsed.movesSan;
          comments = _mainLineComments(pgn, step.fen, moves.length);
        }
      } catch (_) {
        // Fall through to the still position.
      }
    }

    setState(() {
      _fens = fens;
      _moves = moves;
      _comments = comments;
      _moveIndex = 0;
      _explored = false;
      _orientation = _sideToMove(step.fen);
    });
    _board.loadFen(step.fen);

    _markSeen();
  }

  /// The trainer's note on each move of the main line, in step with the moves
  /// [PgnParser] found.
  ///
  /// Read with a second parser rather than by extending the first: [PgnParser]
  /// strips `{...}` before handing the game to the `chess` package, and the
  /// quirks it works around are the reason it is written the way it is.
  /// [MoveTree] already reads comments, variations and arrows, so the notes are
  /// taken from there and the line itself is still the one being displayed.
  ///
  /// Returns nothing at all when the two readings disagree about how many moves
  /// the line has. A comment shown against the wrong move is worse than no
  /// comment: it is the trainer appearing to say something they did not.
  static List<String> _mainLineComments(String pgn, String fen, int moveCount) {
    if (moveCount == 0) return const [];
    try {
      final tree = MoveTree.parsePgn(pgn, startingFen: fen);
      if (tree == null) return const [];

      final comments = <String>[];
      var node = tree.root;
      while (node.children.isNotEmpty) {
        node = node.children.first;
        comments.add(node.comment);
      }

      if (comments.length != moveCount) return const [];
      if (comments.every((c) => c.isEmpty)) return const [];
      return comments;
    } catch (_) {
      return const [];
    }
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
    setState(() {
      _moveIndex = index;
      _explored = false;
    });
    _board.loadFen(_fens[index]);
  }

  /// The position the lesson is showing right now — the step's own board, or
  /// wherever the student has walked to along its line.
  String get _lessonFen =>
      _fens.isEmpty ? _step.fen : _fens[_moveIndex.clamp(0, _fens.length - 1)];

  /// Puts the pieces back where the lesson had them.
  void _restore() {
    setState(() => _explored = false);
    _board.loadFen(_lessonFen);
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
        actions: const [BoardCoordinatesButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: done / _steps.length,
            minHeight: 4,
            backgroundColor: context.colors.surfaceRaised,
          ),
        ),
      ),
      // Arrow keys drive the same cursor the strip's buttons do. A lesson is
      // walked far more than it is clicked through.
      body: MoveKeyboardShortcuts(
        cursor: _moveCursor(),
        // The cursor's own onSeek already redraws the screen.
        onChanged: () {},
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heightBased =
                  (constraints.maxHeight - 250).clamp(200.0, 520.0);
              final widthBased =
                  (constraints.maxWidth - 24).clamp(180.0, 520.0);
              final boardSize =
                  heightBased < widthBased ? heightBased : widthBased;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _buildHeader(done),
                    const SizedBox(height: 10),
                    Center(
                      child: BoardWithCoordinates(
                        size: boardSize,
                        orientation: _orientation,
                        builder: (size) => ChessBoardWithOverlay(
                          controller: _board,
                          boardOrientation: _orientation,
                          boardSize: size,
                          // Playable, but only for trying things: the move is
                          // not sent anywhere and nothing about the lesson
                          // changes. A step that asks for a mate and refuses to
                          // let the child play one is a screen promising what it
                          // will not do.
                          isAllowedToMove: true,
                          isDrawingMode: false,
                          drawingStartSquare: null,
                          arrows: const [],
                          engineArrows: const [],
                          onMove: (_, __, ___) {
                            if (!_explored) setState(() => _explored = true);
                          },
                          onSquareTapForDrawing: (_) {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_explored) _buildRestore(),
                    _buildMoveComment(),
                    if (_moves.isNotEmpty) _buildMoveControls(),
                    const SizedBox(height: 10),
                    _buildStepControls(),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// What the trainer wrote about the move now on the board.
  ///
  /// Index 0 is the position before the first move, which nobody wrote a note
  /// about, so the note for move n lives at n - 1.
  Widget _buildMoveComment() {
    if (_moveIndex <= 0 || _moveIndex > _comments.length) {
      return const SizedBox.shrink();
    }
    final comment = _comments[_moveIndex - 1];
    if (comment.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: AppRadii.roundedSm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 16, color: context.colors.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(comment, style: AppText.bodyLarge)),
          ],
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
                    _step.title.isEmpty
                        ? 'Korak ${_stepIndex + 1}'
                        : _step.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${_stepIndex + 1}/${_steps.length}',
                  style: AppText.bodyLarge
                      .copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Pregledano $done od ${_steps.length} koraka',
              style: TextStyle(fontSize: 11.5, color: context.colors.textMuted),
            ),
            // The task for *this* position, above the assignment's own note.
            // The title is a name, so without this the student was given a
            // board and left to guess what was being asked of them.
            if (_step.instruction != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.colors.surfaceRaised,
                  borderRadius: AppRadii.roundedSm,
                  border: Border.all(color: context.colors.accent),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.flag_outlined,
                        size: 16, color: context.colors.accent),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _step.instruction!,
                        style: TextStyle(
                            fontSize: 13.5,
                            color: context.colors.textPrimary,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (instructions != null && instructions.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(instructions, style: AppText.bodyLarge),
            ],
          ],
        ),
      ),
    );
  }

  /// Shown only once the pieces have actually been moved, so it never sits
  /// there suggesting something is wrong with an untouched board.
  Widget _buildRestore() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        children: [
          Text(
            'Probaš poteze — ovde se ništa ne ocenjuje.',
            style: AppText.body.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: _restore,
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text('Vrati poziciju'),
          ),
        ],
      ),
    );
  }

  /// The one cursor this screen is walked by. The strip's buttons and the arrow
  /// keys read it from here rather than each building their own, so there is no
  /// second copy to fall out of step.
  MoveCursor _moveCursor() => LinearMoveCursor(
        fens: _fens,
        index: _moveIndex,
        onSeek: _applyMovesUpTo,
      );

  Widget _buildMoveControls() {
    return MoveNavigationControls(
      cursor: _moveCursor(),
      centerLabel: 'Potez $_moveIndex od ${_moves.length}',
      onFlipBoard: () => setState(() {
        _orientation = _orientation == PlayerColor.white
            ? PlayerColor.black
            : PlayerColor.white;
      }),
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
          onPressed: isLast
              ? () => Navigator.of(context).maybePop()
              : () => _goToStep(_stepIndex + 1),
          icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
          label: Text(isLast ? 'Završi' : 'Sledeći korak'),
        ),
      ],
    );
  }
}
