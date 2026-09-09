import 'dart:async';
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
    // Before `super.dispose()`, and it matters: a periodic timer that outlives
    // the widget calls `setState` on a dead element. This project has already
    // paid once for a timer that fired after the thing it belonged to was gone.
    _typing?.cancel();
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
      //
      // And the trainer decides it when they said so. `blackOrientation` is
      // null for every step written before the studio could send it, and for
      // those the side to move is still the best guess — but a step that
      // carries the field carries a decision, and a computed orientation
      // overruling it is the board flipping under a child in the middle of a
      // tutorial written from one side. Reported live on 7.9.2026.
      if (!continues) {
        _orientation = _orientationOf(step);
      }
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
            content: Text('Answer not sent — check your connection.')),
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
            content: Text('Answer not sent — check your connection.')),
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
            content: Text('Answer not sent — check your connection.')),
      );
      return;
    }
    setState(() {
      _sending = false;
      _reveal = result;
    });
  }

  /// Which way round a step's board stands.
  static PlayerColor _orientationOf(LessonStep step) =>
      switch (step.blackOrientation) {
        true => PlayerColor.black,
        false => PlayerColor.white,
        null => _sideToMove(step.fen),
      };

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

  /// How much of the current sentence has been written on screen, 0 to 1.
  ///
  /// **Only while the voice is reading.** A child reading at their own pace
  /// gets the whole sentence at once: making them wait for letters they could
  /// already have read is a worse screen, not a prettier one.
  double _typed = 1;
  Timer? _typing;

  /// Characters a second, the same rate the exported video writes at.
  ///
  /// The device voice does not say how far through a sentence it is —
  /// `flutter_tts` reports word ranges on Android and iOS and nothing at all on
  /// Windows, which is where a trainer checks their own material — so the
  /// writing runs at a fixed reading speed and is completed the moment `speak`
  /// returns. It can therefore finish early and never finishes late, which is
  /// the right way round: text still arriving after the voice has stopped is
  /// what reads as broken.
  static const double _typedCharsPerSecond = 14;

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
            content: Text('No voice on this device — navigate with buttons.')),
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
        _startTyping(text);
        await _speech.speak(text, force: true);
        _finishTyping();
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

      // The line has run out, and the tutorial has not. The walk carries on
      // into the next part — every part, not only one that stands on this very
      // position.
      //
      // **It used to stop at a part that opened somewhere else**, on the rule
      // that a join is a continuation while a new diagram is a page-turn the
      // child should turn themselves. The trainer met that rule on 7.9.2026
      // and read it as a bug: they pressed a play button, watched the first
      // part, and concluded the second one „uopšte se ne prikazuje" — „mislio
      // sam da pušta ceo tutorijal kroz sve delove". A control with a ▶ on it
      // promises the whole thing, and the child this walk exists for is
      // precisely the one who is listening rather than pressing. The old rule
      // also predates „Traži potez na tabli", which now routinely cuts one
      // part into a chain of three.
      //
      // What still stops the walk is unchanged and is what it should be: a
      // fork, a part that asks something, and the end of the tutorial.
      if (_stepIndex + 1 >= _steps.length) break;

      // A part that opens somewhere else is a new diagram, and crossing to it
      // puts the pieces back. That is a change of board, so it waits a beat —
      // a board that rearranges itself under a sentence still being spoken
      // leaves the listener hearing about a position that is no longer there,
      // which is the fault this whole loop is written around.
      if (!_nextStepContinuesHere) {
        await Future<void>.delayed(_silentStep);
        if (!mounted || !_narrating || run != _narrationRun) return;
      }

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
    // Stopping the voice completes the sentence rather than freezing it
    // half-written: the child stopped the reading, not the reading of *this*
    // sentence, and half a sentence on screen is a bug wearing an animation.
    _finishTyping();
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
        body: const Center(child: Text('This tutorial has no parts.')),
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
              // **Two layouts, and the reason is the navigation strip.**
              //
              // What a step says — the task, the trainer's sentence, the fork's
              // choices — used to sit between the board and the strip, so every
              // step with a longer sentence pushed the strip somewhere else and
              // the child had to find it again. Reported by the owner on
              // 9.9.2026.
              //
              // Wide enough, and the words go beside the board, which is also
              // what the exported video does. Otherwise the strip goes directly
              // under the board and the words below *it*: the thing that grows
              // is then the last thing on the screen, and it pushes nothing.
              //
              // 840 is this project's breakpoint everywhere else.
              final wide = constraints.maxWidth >= 840;
              final heightBased =
                  (constraints.maxHeight - 250).clamp(200.0, 520.0);
              final widthBased = wide
                  // Half the width, less the gap and the column's own margin,
                  // so the board never crowds the sentence beside it.
                  ? (constraints.maxWidth * 0.5 - 32).clamp(180.0, 520.0)
                  : (constraints.maxWidth - 24).clamp(180.0, 520.0);
              final boardSize =
                  heightBased < widthBased ? heightBased : widthBased;

              // The board, and beside or below it the words about it. Built
              // once and placed twice, so the two layouts cannot drift into
              // being two screens.
              final board = Center(
                child: BoardWithCoordinates(
                  size: boardSize,
                  orientation: _orientation,
                  builder: (size) => ChessBoardWithOverlay(
                    controller: _board,
                    boardOrientation: _orientation,
                    boardSize: size,
                    // Playable on show and ask_move, locked on ask_choice
                    isAllowedToMove: _step.kind != LessonStepKind.askChoice,
                    isDrawingMode: false,
                    drawingStartSquare: null,
                    arrows: _currentArrows,
                    squares: _currentSquares,
                    engineArrows: const [],
                    onMove: (from, to, promotion) {
                      if (_step.kind == LessonStepKind.askMove &&
                          _verdict?.correct != true &&
                          _reveal == null) {
                        final san = _sanFor(_lessonFen, from, to, promotion);
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
              );

              // Everything this step has to say. On a phone it is the last
              // thing on the screen, so it can grow without moving anything;
              // on a wide window it is the column beside the board.
              final said = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStepTasks(),
                  if (_explored) _buildRestore(),
                  _buildMoveComment(),
                  _buildBranchChoices(),
                ],
              );

              final strip = _tree != null && _tree!.root.children.isNotEmpty
                  ? _buildMoveControls()
                  : const SizedBox.shrink();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _buildHeader(done),
                    const SizedBox(height: 10),
                    if (wide)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(children: [
                            board,
                            const SizedBox(height: 10),
                            strip
                          ]),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(child: said),
                        ],
                      )
                    else ...[
                      board,
                      const SizedBox(height: 10),
                      strip,
                      said,
                    ],
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
        text: 'Solution: ${_reveal!.solutionSan}',
      );
    }

    if (_verdict != null) {
      if (_verdict!.correct) {
        final san = _verdict!.solutionSan;
        return ActionBanner(
          tone: ActionTone.calm,
          text: san != null ? 'Correct. We continue after $san.' : 'Correct.',
        );
      } else {
        return Column(
          children: [
            ActionBanner(
              tone: ActionTone.problem,
              text: _verdict!.reason,
              actionLabel: _wrongAnswers >= 2 ? 'Show me' : null,
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
    final shown = _typedSlice(comment);

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
                // The speaker button reads the whole sentence, not the part of
                // it that happens to be drawn.
                text: comment,
                autoSpeak: false,
                child: Text(shown, style: AppText.bodyLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// As much of [text] as the voice has read, cut on a word.
  ///
  /// Whole words for the same reason the video does it: „the knig" for a tenth
  /// of a second reads as a glitch rather than as writing.
  String _typedSlice(String text) {
    if (_typed >= 1) return text;
    final upTo = (text.length * _typed).floor();
    if (upTo <= 0) return '';
    final cut = text.substring(0, upTo);
    final lastSpace = cut.lastIndexOf(' ');
    return lastSpace > 0 ? cut.substring(0, lastSpace) : '';
  }

  /// The moves that leave this position, when there is more than one.
  ///
  /// **A fork the child cannot see is a sideline that does not exist for
  /// them.** The branch chooser was reachable only by pressing „Sledeći potez",
  /// which opens a sheet: nothing on the screen said there was anything to
  /// choose, the narrated walk stopped dead at the fork with no explanation,
  /// and a listening child — the child this feature is for — never met the
  /// other line at all. Reported live on 7.9.2026, on a tutorial cut by
  /// „Traži potez na tabli", where the continuation *opens* on a fork: the
  /// answer and its alternatives are the first thing in that part.
  ///
  /// The sheet stays: it is what the strip and the arrow keys do on every
  /// screen. This says the same thing where the child is already looking.
  ///
  /// The main line is marked by a **shape** rather than by a colour, the same
  /// way [showBranchChoice] marks it, and it is marked rather than preselected
  /// — the point is that the others are reachable.
  Widget _buildBranchChoices() {
    final node = _node;
    if (node == null || node.children.length < 2) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Multiple lines continue from here — which one?',
            style: AppText.bodyBold.copyWith(color: context.colors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < node.children.length; i++)
                ActionChip(
                  avatar: Icon(
                    i == 0 ? Icons.star : Icons.arrow_forward,
                    size: 16,
                    color:
                        i == 0 ? context.colors.warning : context.colors.accent,
                  ),
                  label: Text(node.children[i].san),
                  onPressed: () {
                    // Taking a branch is the reader driving, the same as the
                    // strip: whatever was being read is about the position
                    // they are leaving.
                    _stopNarration();
                    _applyNode(node.children[i]);
                  },
                ),
            ],
          ),
        ],
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
                        ? 'Part ${_stepIndex + 1}'
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
              'Viewed $done of ${_steps.length} parts',
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
            'Trying moves — nothing is graded here.',
            style: AppText.body.copyWith(color: context.colors.textMuted),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: _restore,
            icon: const Icon(Icons.restart_alt, size: 16),
            label: const Text('Reset position'),
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
      centerLabel: 'Move ${progress.at} of ${progress.of}',
      onFlipBoard: () => setState(() {
        _orientation = _orientation == PlayerColor.white
            ? PlayerColor.black
            : PlayerColor.white;
      }),
      trailing: [_buildNarrationButton()],
    );
  }

  /// Begin writing [text] on screen at reading speed.
  void _startTyping(String text) {
    _typing?.cancel();
    if (text.isEmpty) return;
    final started = DateTime.now();
    setState(() => _typed = 0);
    _typing = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final seconds = DateTime.now().difference(started).inMilliseconds / 1000;
      final done = (seconds * _typedCharsPerSecond) / text.length;
      setState(() => _typed = done.clamp(0.0, 1.0));
      if (_typed >= 1) timer.cancel();
    });
  }

  /// The voice has stopped, so the sentence is whole however far the writing
  /// had got. Called on the way out of every path, including the ones that
  /// leave the walk early.
  void _finishTyping() {
    _typing?.cancel();
    _typing = null;
    if (mounted && _typed != 1) setState(() => _typed = 1);
  }

  /// Starts and stops the narrated walk through the tutorial.
  ///
  /// It says „Pusti tutorijal" because that is what it does — it runs on
  /// through the parts, stopping only where the child has something to do. It
  /// said „Pročitaj mi liniju" while it walked one part, which was true and
  /// still misread: a ▶ on a tutorial promises the tutorial, and a trainer
  /// pressed it, watched one part and reported that the rest „uopšte se ne
  /// prikazuje".
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
          tooltip: _narrating ? 'Stop reading' : 'Play tutorial',
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
          label: const Text('Previous part'),
        ),
        ElevatedButton.icon(
          onPressed: isLast
              ? () => Navigator.of(context).maybePop()
              : () => _goToStep(_stepIndex + 1),
          icon: Icon(isLast ? Icons.check : Icons.arrow_forward),
          label: Text(isLast ? 'Finish' : 'Next part'),
        ),
      ],
    );
  }
}
