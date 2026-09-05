import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import '../models/assignment.dart';
import '../services/assignment_api_service.dart';
import 'package:chess_app/widgets/action_banner.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/speakable_info.dart';

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
    this.api,
  });

  final UserSession session;
  final AssignmentDetail detail;
  final AssignmentApiService? api;

  @override
  State<LessonViewerScreen> createState() => LessonViewerScreenState();
}

class LessonViewerScreenState extends State<LessonViewerScreen> {
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

  List<List<ChessArrow>> _arrows = const [];
  List<List<SquareMark>> _squares = const [];
  List<ChessArrow> _rootArrows = const [];
  List<SquareMark> _rootSquares = const [];

  List<ChessArrow> get _currentArrows {
    if (_moveIndex == 0) return _rootArrows;
    if (_moveIndex > 0 && _moveIndex <= _arrows.length) {
      return _arrows[_moveIndex - 1];
    }
    return const [];
  }

  List<SquareMark> get _currentSquares {
    if (_moveIndex == 0) return _rootSquares;
    if (_moveIndex > 0 && _moveIndex <= _squares.length) {
      return _squares[_moveIndex - 1];
    }
    return const [];
  }

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
    _api = widget.api ?? AssignmentApiService(authToken: widget.session.token);
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
    // One reader, since phase 2 of `docs/PLAN-INTERAKTIVNA-LEKCIJA.md`. The line
    // and the notes used to come from two different parsers and were thrown away
    // whenever the two disagreed about how many moves there were; `mainLine()`
    // builds them in one walk, so they cannot.
    //
    // `MoveTree.parsePgn` is also told where the line starts, which is what the
    // old `_sameFen` guard was working around: `PgnParser` always replayed from
    // the standard position, so a step out of an endgame book came back as a
    // different game and had to be rejected on sight.
    List<String> fens = const [];
    List<String> moves = const [];
    List<String> comments = const [];
    List<List<ChessArrow>> arrows = const [];
    List<List<SquareMark>> squares = const [];
    List<ChessArrow> rootArrows = const [];
    List<SquareMark> rootSquares = const [];
    final pgn = step.pgn;
    if (pgn != null && pgn.trim().isNotEmpty) {
      try {
        final tree = MoveTree.parsePgn(pgn, startingFen: step.fen);
        final line = tree?.mainLine();
        if (line != null) {
          if (!line.isEmpty) {
            fens = line.fens;
            moves = line.movesSan;
            comments = line.hasNoNotes ? const [] : line.comments;
            arrows = line.arrows;
            squares = line.squares;
          }
          rootArrows = line.rootArrows;
          rootSquares = line.rootSquares;
        }
      } catch (_) {
        // Fall through to the still position.
      }
    }

    setState(() {
      _fens = fens;
      _moves = moves;
      _comments = comments;
      _arrows = arrows;
      _squares = squares;
      _rootArrows = rootArrows;
      _rootSquares = rootSquares;
      _moveIndex = 0;
      _explored = false;
      _wrongAnswers = 0;
      _sending = false;
      _verdict = null;
      _reveal = null;
      _orientation = _sideToMove(step.fen);
    });
    _board.loadFen(step.fen);

    _markSeen();
  }

  int _wrongAnswers = 0;
  bool _sending = false;
  StepAnswerResult? _verdict;
  StepRevealResult? _reveal;

  static String? _sanFor(String fen, String from, String to, String promotion) {
    try {
      final game = chess.Chess.fromFEN(fen);
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
    } catch (_) {
      return null;
    }
  }

  Future<void> submitMove(String moveSan) async {
    if (_sending || _verdict?.correct == true || _reveal != null) return;

    setState(() => _sending = true);

    final result = await _api.answerLessonStep(
      assignmentId: widget.detail.assignment.id,
      position: _stepIndex,
      moveSan: moveSan,
    );

    if (!mounted) return;
    if (result == null) {
      setState(() => _sending = false);
      _board.loadFen(_lessonFen);
      AppFeedback.show(
        context,
        () => const SnackBar(
            content: Text('Odgovor nije poslat — proveri vezu.')),
      );
      return;
    }

    setState(() {
      _sending = false;
      _verdict = result;
      if (!result.correct) {
        _wrongAnswers++;
      }
    });

    // A wrong move goes back where it came from, which is what every other
    // board in this app does — `wrong_move_board_test.dart` is named after the
    // rule. It is not only a convention: the second try is read off
    // `_lessonFen`, so a board left standing on the first wrong move offers the
    // child moves that resolve to nothing from the position being judged, and
    // the board then snaps back with nothing said. A correct alternative is
    // left where the child put it on purpose — §2.5 answers that with the
    // sentence about where the lesson goes on from, not by moving the pieces.
    if (!result.correct) {
      _board.loadFen(_lessonFen);
    }
  }

  Future<void> submitChoice(int index) async {
    if (_sending || _verdict?.correct == true || _reveal != null) return;

    setState(() => _sending = true);

    final result = await _api.answerLessonStep(
      assignmentId: widget.detail.assignment.id,
      position: _stepIndex,
      choiceIndex: index,
    );

    if (!mounted) return;
    if (result == null) {
      setState(() => _sending = false);
      AppFeedback.show(
        context,
        () => const SnackBar(
            content: Text('Odgovor nije poslat — proveri vezu.')),
      );
      return;
    }

    setState(() {
      _sending = false;
      _verdict = result;
      if (!result.correct) {
        _wrongAnswers++;
      }
    });
  }

  Future<void> _revealSolution() async {
    if (_sending) return;
    setState(() => _sending = true);
    final result = await _api.revealLessonStep(
      assignmentId: widget.detail.assignment.id,
      position: _stepIndex,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _sending = false);
      AppFeedback.show(
        context,
        () => const SnackBar(
            content: Text('Odgovor nije poslat — proveri vezu.')),
      );
      return;
    }
    setState(() {
      _sending = false;
      _reveal = result;
    });
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
        actions: const [BoardViewMenu()],
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
                          // Playable on show and ask_move, locked on ask_choice
                          isAllowedToMove:
                              _step.kind != LessonStepKind.askChoice,
                          isDrawingMode: false,
                          drawingStartSquare: null,
                          arrows: _currentArrows,
                          squares: _currentSquares,
                          engineArrows: const [],
                          onMove: (from, to, promotion) {
                            if (_step.kind == LessonStepKind.askMove &&
                                _verdict?.correct != true &&
                                _reveal == null) {
                              final san =
                                  _sanFor(_lessonFen, from, to, promotion);
                              if (san != null) {
                                submitMove(san);
                              } else {
                                _board.loadFen(_lessonFen);
                              }
                            } else {
                              if (!_explored) setState(() => _explored = true);
                            }
                          },
                          onSquareTapForDrawing: (_) {},
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildStepTasks(),
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

  Widget _buildStepTasks() {
    if (_step.kind == LessonStepKind.show) return const SizedBox.shrink();

    if (_sending) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: CircularProgressIndicator(),
      );
    }

    if (_reveal != null) {
      return ActionBanner(
        tone: ActionTone.calm,
        text: 'Rešenje: ${_reveal!.solutionSan}',
      );
    }

    if (_verdict != null) {
      if (_verdict!.correct) {
        final san = _verdict!.solutionSan;
        return ActionBanner(
          tone: ActionTone.calm,
          text: san != null ? 'Tačno. Mi nastavljamo posle $san.' : 'Tačno.',
        );
      } else {
        return Column(
          children: [
            ActionBanner(
              tone: ActionTone.problem,
              text: _verdict!.reason,
              actionLabel: _wrongAnswers >= 2 ? 'Pokaži mi' : null,
              onAction: _wrongAnswers >= 2 ? _revealSolution : null,
            ),
            if (_step.kind == LessonStepKind.askChoice) _buildChoices(),
          ],
        );
      }
    }

    if (_step.kind == LessonStepKind.askChoice) {
      return _buildChoices();
    }

    return const SizedBox.shrink();
  }

  Widget _buildChoices() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (var i = 0; i < _step.choices.length; i++)
            OutlinedButton(
              onPressed: () => submitChoice(i),
              child: Text(_step.choices[i]),
            ),
        ],
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
            Expanded(
              child: SpeakableInfo(
                text: comment,
                autoSpeak: false,
                child: Text(comment, style: AppText.bodyLarge),
              ),
            ),
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
                      child: SpeakableInfo(
                        text: _step.instruction!,
                        autoSpeak: false,
                        child: Text(
                          _step.instruction!,
                          style: TextStyle(
                              fontSize: 13.5,
                              color: context.colors.textPrimary,
                              fontWeight: FontWeight.w500),
                        ),
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
