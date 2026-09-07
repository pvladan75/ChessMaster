import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/models/move_cursor.dart';
import 'package:chess_app/features/lessons/models/lesson_step_line.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/services/speech_service.dart';
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
    this.speech,
  });

  final UserSession session;
  final AssignmentDetail detail;
  final AssignmentApiService? api;

  /// Injectable for tests. The real one is a singleton that talks to the
  /// machine running the suite.
  final SpeechService? speech;

  @override
  State<LessonViewerScreen> createState() => LessonViewerScreenState();
}

class LessonViewerScreenState extends State<LessonViewerScreen> {
  late final AssignmentApiService _api;
  late final SpeechService _speech;
  final ChessBoardController _board = ChessBoardController();

  late int _stepIndex;
  late final Set<int> _seen;

  /// The parsed variation tree, or a single-node tree if this step has no line.
  MoveTree? _tree;

  /// The node the walk is currently standing on.
  MoveNode? _node;

  List<ChessArrow> get _currentArrows => _node?.arrows ?? const [];
  List<SquareMark> get _currentSquares => _node?.squares ?? const [];

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
    _speech = widget.speech ?? SpeechService.instance;
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
    // The loop checks this before every step, so leaving the screen ends the
    // walk rather than letting it go on talking to nobody.
    _narrationRun += 1;
    _narrating = false;
    _speech.stop();
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
    // The reader is told where the line starts, which is what the old `_sameFen`
    // guard was working around: `PgnParser` always replayed from the standard
    // position, so a step out of an endgame book came back as a different game
    // and had to be rejected on sight.
    //
    // It is `LessonStepLine` rather than `MoveTree` directly, because the
    // trainer's studio checks a step against the same reader before saving it.
    // A step that does not replay is refused there; here it simply shows its
    // still position, which is what an older step with a broken line does.
    final line = LessonStepLine.read(fen: step.fen, pgn: step.pgn);
    final tree = line.tree ?? MoveTree(startingFen: step.fen);

    // Does this step go on from where the board already stands? A lesson moves
    // from showing to asking on **one** board: the demonstration walks to
    // 2...Kd6, the next step asks „Kako beli sada ponovo zauzima opoziciju?"
    // from that same position, and all that may happen on screen is that the
    // board becomes the child's to play on. Reloading the FEN and recomputing
    // the orientation there is a visible jump that says a new exercise has
    // started — which is exactly what it is not.
    final continues =
        _shownFen.isNotEmpty && MoveTree.samePosition(step.fen, _shownFen);

    setState(() {
      _tree = tree;
      _node = tree.root;
      _wrongAnswers = 0;
      _sending = false;
      _verdict = null;
      _reveal = null;
      // A continuing step keeps the board the child is looking at, whichever
      // way round it is. Only a step that opens a different position gets to
      // decide the orientation.
      if (!continues) _orientation = _sideToMove(step.fen);
    });

    // The pieces are only put back if they are not there already — a step that
    // continues from this position has nothing to load, and a child who has
    // been trying moves out has.
    if (!continues || _explored) {
      _board.loadFen(step.fen);
    }
    // After the board is settled: a step the child had been playing on is a
    // step whose pieces have just been put back.
    if (_explored) setState(() => _explored = false);
    _shownFen = step.fen;

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

  void _goToStep(int index, {bool keepNarration = false}) {
    if (index < 0 || index >= _steps.length) return;
    if (!keepNarration) _stopNarration();
    setState(() => _stepIndex = index);
    _loadStep();
  }

  /// Whether the next step simply goes on from the position on the board.
  ///
  /// That is the join the lesson is built around — a demonstration and the
  /// question about the position it arrived at are two steps and one board —
  /// and it is the only case where the walk carries on by itself. A next step
  /// that starts somewhere else is a new diagram, and the child opens it when
  /// they are ready.
  bool get _nextStepContinuesHere {
    if (_stepIndex + 1 >= _steps.length) return false;
    return MoveTree.samePosition(_steps[_stepIndex + 1].fen, _lessonFen);
  }

  /// The position the board was last put on by the lesson.
  ///
  /// Kept because a step is not always a new picture: a step that asks
  /// something usually stands on the position the step before it walked to,
  /// and in that case the board must not be reloaded and the orientation must
  /// not be recomputed. Empty until the first step is loaded.
  String _shownFen = '';

  /// True while the step's line is walking itself, a sentence at a time.
  bool _narrating = false;

  /// Bumped to end whatever loop is running. A run that finds the number
  /// changed underneath it stops without touching the screen — cheaper and
  /// safer than trying to cancel a chain of futures.
  int _narrationRun = 0;

  /// How long a move with nothing written about it stays on the board.
  ///
  /// Only reached inside a narrated walk, where the alternative is a move that
  /// appears and is gone before it is seen.
  static const _silentStep = Duration(milliseconds: 1400);

  /// Whether the machine can actually read the step out.
  ///
  /// Not "is speech switched on": a reader with speech off is offered the
  /// button and switching it on is what pressing it does, the same rule
  /// `SpeakableInfo` follows. A machine with no voice at all is a different
  /// answer — there the button is not drawn, because a control that cannot
  /// work is worse than no control.
  bool get _canNarrate =>
      _speech.state != SpeechState.noVoice &&
      _speech.state != SpeechState.failed;

  /// Walks the line the way it is taught: the sentence about the position is
  /// read out, and the next move is played when the voice has finished it.
  ///
  /// The pedagogical shape this exists for, in the owner's words: a step is one
  /// board, and „1. Kd3 {…} Ke5 {…} 2. Kc4 {…}" is one lesson on it. The child
  /// hears why the move was played, sees the squares it is about, and only then
  /// does the answer appear — a board that moves under a sentence still being
  /// spoken leaves the listener hearing about a position that is no longer
  /// there.
  ///
  /// It waits on the sentence rather than on a clock. `SpeechService.speak`
  /// completes when the voice stops (`awaitSpeakCompletion`), and carries its
  /// own watchdog for the platforms that never report it — so a machine that
  /// goes quiet without saying so still walks on instead of freezing.
  ///
  /// With speech off there is no timer and no autoplay: the child presses
  /// „Sledeći potez" and reads. That is the same screen, not a lesser one.
  Future<void> _narrate() async {
    if (_narrating || _tree == null || _tree!.root.children.isEmpty) return;

    if (!_speech.enabled) {
      // Pressing play with speech off means "read it to me", so it is switched
      // on here rather than answered with nothing.
      await _speech.setEnabled(true);
      if (!mounted) return;
    }
    if (_speech.state != SpeechState.ready) {
      AppFeedback.show(
        context,
        () => const SnackBar(
            content: Text('Nema glasa na ovom uređaju — listaj dugmadima.')),
      );
      return;
    }

    final run = ++_narrationRun;
    setState(() => _narrating = true);

    while (mounted && _narrating && run == _narrationRun) {
      // The reader can switch speech off from anywhere while this runs. Without
      // this the loop would race to the end of the line in silence, since
      // `speak` returns at once when it has nothing to speak with.
      if (!_speech.enabled || _speech.state != SpeechState.ready) break;

      final text = _node?.comment ?? '';
      if (text.isEmpty) {
        await Future<void>.delayed(_silentStep);
      } else {
        // `force`, because two moves in a row can carry the same sentence and
        // the service otherwise says it once — which here would not just skip
        // the words, it would skip the wait.
        await _speech.speak(text, force: true);
      }

      if (!mounted || !_narrating || run != _narrationRun) return;

      if (_node != null && _node!.children.isNotEmpty) {
        // At a fork the walk stops and the child chooses. Taking the first
        // child silently would make every sideline unreachable for exactly the
        // child who is listening rather than pressing — which is the child this
        // feature is for.
        if (_node!.children.length > 1) break;
        _applyNode(_node!.children.first);
        continue;
      }

      // The line has run out. If the next step stands on this very position,
      // the lesson has not stopped — it is about to ask something about the
      // board the child is already looking at, so the walk goes on through the
      // join instead of ending at a „Sledeći korak" button.
      if (!_nextStepContinuesHere) break;

      _goToStep(_stepIndex + 1, keepNarration: true);
      if (!mounted || !_narrating || run != _narrationRun) return;

      if (_step.kind != LessonStepKind.show) {
        // The question is read out, and then the voice stops. The board is
        // already the child's — nothing was reloaded and nothing moved; what
        // changed is whose turn it is to act.
        final question = _step.instruction;
        if (question != null && question.isNotEmpty) {
          await _speech.speak(question, force: true);
        }
        break;
      }
    }

    if (mounted && run == _narrationRun) setState(() => _narrating = false);
  }

  /// Ends the walk. Called by everything the reader does — a button on the
  /// strip, a move of their own, the next step, leaving.
  void _stopNarration() {
    if (!_narrating) return;
    _narrationRun += 1;
    _speech.stop();
    if (mounted) setState(() => _narrating = false);
  }

  /// Jumps to a specific node in the tree.
  void _applyNode(MoveNode node) {
    setState(() {
      _node = node;
      _explored = false;
    });
    _shownFen = node.fen;
    _board.loadFen(node.fen);
  }

  /// The position the lesson is showing right now — the step's own board, or
  /// wherever the student has walked to along its line.
  String get _lessonFen => _node?.fen ?? _step.fen;

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
        body: const Center(child: Text('Ovaj tutorijal nema nijedan korak.')),
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
                              // The child has taken the board. Whatever was
                              // being read is about a position they have just
                              // left.
                              _stopNarration();
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
                    if (_tree != null && _tree!.root.children.isNotEmpty)
                      _buildMoveControls(),
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

  /// What the trainer wrote about the position now on the board.
  ///
  /// Index 0 is the position before the first move. Somebody does write about
  /// that one — it is the diagram the step opens on — and PGN keeps that note
  /// ahead of move one rather than on a move, which is why it lives in its own
  /// field. Notes about moves start at index 1, so the note for move n lives
  /// at n - 1.
  Widget _buildMoveComment() {
    final comment = _node?.comment ?? '';
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
  MoveCursor _moveCursor() {
    if (_tree == null || _node == null) {
      return LinearMoveCursor(fens: const [], index: 0, onSeek: (_) {});
    }
    return MoveTreeCursor(
      moveTree: _tree!,
      currentNode: _node!,
      // Taking the strip or the arrow keys is the reader saying they would
      // rather drive. The walk stops, and so does the voice.
      onSelect: (node) {
        _stopNarration();
        _applyNode(node);
      },
    );
  }

  /// How far along the line the child has walked, and how long that line is.
  ///
  /// Both numbers are about **the line they are on**, not about the tree: the
  /// first is the depth of the current node, the second that depth plus what
  /// still follows it down first children. On a step with no branches those are
  /// exactly the old „Potez N od M" — the line's length either way. On a step
  /// that branches they are the only honest answer, because there is no single
  /// number of moves in a tree: stepping into a shorter sideline shortens the
  /// line, and saying so is the point.
  ({int at, int of}) _lineProgress() {
    var at = 0;
    for (var node = _node; node?.parent != null; node = node!.parent) {
      at++;
    }

    var of = at;
    for (var node = _node;
        node != null && node.children.isNotEmpty;
        node = node.children.first) {
      of++;
    }

    return (at: at, of: of);
  }

  Widget _buildMoveControls() {
    final progress = _lineProgress();

    return MoveNavigationControls(
      cursor: _moveCursor(),
      centerLabel: 'Potez ${progress.at} od ${progress.of}',
      onFlipBoard: () => setState(() {
        _orientation = _orientation == PlayerColor.white
            ? PlayerColor.black
            : PlayerColor.white;
      }),
      trailing: [_buildNarrationButton()],
    );
  }

  /// Starts and stops the narrated walk down the line.
  ///
  /// Wrapped in a builder on the speech service so that installing a voice, or
  /// switching speech off in another screen, is reflected here without the
  /// reader having to reopen the lesson.
  Widget _buildNarrationButton() {
    return AnimatedBuilder(
      animation: _speech,
      builder: (context, _) {
        if (!_canNarrate) return const SizedBox.shrink();
        return IconButton(
          icon: Icon(_narrating ? Icons.stop : Icons.play_arrow),
          tooltip: _narrating ? 'Zaustavi čitanje' : 'Pročitaj mi liniju',
          onPressed: _narrating ? _stopNarration : _narrate,
        );
      },
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
