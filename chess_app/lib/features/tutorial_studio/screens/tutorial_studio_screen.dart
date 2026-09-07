import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node_cursor.dart';
import 'package:chess_app/features/analysis_studio/models/pgn_span.dart';
import 'package:chess_app/features/analysis_studio/services/studio_lesson_step.dart';
import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show
        Assignment,
        AssignmentDetail,
        AssignmentItem,
        LessonStep,
        LessonStepKind;
import 'package:chess_app/features/assignments/screens/lesson_viewer_screen.dart';
import 'package:chess_app/features/lessons/widgets/preview_assignment_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/services/section_split.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_save.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_flow_panel.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_pgn_panel.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_sections_panel.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_bar.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_controller.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';

/// The room a trainer writes a tutorial in. Phase 4 of
/// `docs/PLAN-TUTORIJAL.md`.
///
/// **Why it is not a twelfth action in the Analysis Studio.** That screen is
/// 2446 lines and twelve actions of *analysing* — engine, explorer, tablebase,
/// motifs, game review — and every one of them is noise to somebody writing.
/// More concretely, the authoring flow needs a running list of examples on
/// screen at all times, and there is no room for it in a layout already
/// carrying a board, a move tree and an engine panel.
///
/// **What it holds, and nothing else:** the board, the move tree of the part
/// being written, the fields for the node the trainer is standing on, and the
/// running list of parts with one save at the end.
///
/// **P1 of `docs/PLAN-STUDIO-REDIZAJN.md` changed what is underneath it and
/// nothing that is on it.** A finished part used to be flattened to `fen` +
/// `pgn` and its tree dropped, so it could never be reopened — which is why a
/// second, weaker editing screen had to exist beside this one. Every part now
/// keeps its tree, so the screen holds one [TutorialDraft] and stands on
/// `_draft.section` instead of keeping a working tree beside a list of finished
/// strings. Not one user-facing string moved, which is what makes
/// `test/tutorial_authoring_test.dart` passing **unedited** the proof that the
/// flow survived. The layout this model was built for is P5.
///
/// Everything it draws already existed. Not one line of board, tree or cursor
/// code is copied in here — two models of one tree is the fault this codebase
/// has already paid for twice — and `test/tutorial_studio_test.dart` fails if a
/// copy appears.
/// What the trainer answered about the draft waiting in the slot.
///
/// Three answers rather than two. „Odbaci" and „Nastavi" left no way back out
/// of a question the trainer had not meant to be asked — and the dialog could
/// be dismissed by tapping beside it, which was read as „discard" and deleted
/// an unfinished tutorial without a word.
enum _DraftChoice { resume, fresh, cancel }

/// What to do with the position a pasted PGN brought with it.
enum _PastedPosition { take, keep, cancel }

class TutorialStudioScreen extends StatefulWidget {
  const TutorialStudioScreen({
    super.key,
    required this.session,
    required this.entry,
    this.lessonApi,
  });

  final UserSession session;

  /// Why the screen is being opened — D4 of `docs/PLAN-STUDIO-REDIZAJN.md`.
  ///
  /// Required, and with no default. The screen used to take an optional
  /// handover and load the one stored draft slot regardless, which is exactly
  /// how opening it to start something new came up carrying the last tutorial.
  final TutorialEntry entry;

  /// The seam a test watches the single save through.
  ///
  /// Defaulted to a real service against this session's token, so nothing but a
  /// test ever passes it.
  final LessonApiService? lessonApi;

  @override
  State<TutorialStudioScreen> createState() => _TutorialStudioScreenState();
}

class _TutorialStudioScreenState extends State<TutorialStudioScreen> {
  final ChessBoardController _boardController = ChessBoardController();
  final BoardAnnotationController _annotationController =
      BoardAnnotationController();

  late final LessonApiService _lessonApi =
      widget.lessonApi ?? LessonApiService(authToken: widget.session.token);

  late TutorialDraft _draft;
  PlayerColor _orientation = PlayerColor.white;

  String? _lastMoveFrom;
  String? _lastMoveTo;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _instructionController = TextEditingController();
  LessonStepKind _currentKind = LessonStepKind.show;
  final List<TextEditingController> _choiceControllers = [];
  int? _currentCorrectChoice;
  String? _currentSolutionSan;

  /// Bumped whenever the fields are refilled from the model rather than by the
  /// trainer typing into them.
  ///
  /// `DropdownButtonFormField` is a form field: it keeps the value it was given
  /// in its own state, and a rebuild alone will not move it. Without this a
  /// restored draft would read „Samo prikaži" over a part that asks for a move
  /// — the trainer believing they asked something they did not. The same trap
  /// `LessonStepEditorPanel._kindEpoch` was written for.
  int _fieldsEpoch = 0;
  int _selectedTab = 0;

  /// Set when the trainer backs out of the „unfinished tutorial" question.
  ///
  /// The screen flushes its draft on the way out, and the draft it is holding
  /// at that moment is the *blank* one it opened with — so writing it would
  /// overwrite the very tutorial the trainer just chose not to touch. Backing
  /// out has to leave the slot exactly as it was found.
  bool _leftWithoutWriting = false;

  /// The line being written, and where the trainer is standing on it.
  AnalysisNode get _root => _draft.section.root;
  AnalysisNode get _current => _draft.section.cursorNode;

  /// The handed-over line, when the screen was opened through the Studio's
  /// door. Null for every other way in.
  TutorialHandover? get _handover => switch (widget.entry) {
        TutorialEntryFromAnalysis(:final handover) => handover,
        _ => null,
      };

  @override
  void initState() {
    super.initState();
    final handover = _handover;

    _draft = switch (widget.entry) {
      // The saved tutorial is the draft. Nothing is taken out of the local slot
      // until it has said which tutorial it belongs to — see
      // [_adoptStoredDraft].
      TutorialEntrySaved(:final lesson) => TutorialDraft.fromLesson(lesson),
      TutorialEntryBlank(:final title) => TutorialDraft(
          title: title,
          sections: [
            TutorialSection.blank(fen: TutorialDraft.startFen, title: 'Deo 1'),
          ],
        ),
      TutorialEntryFromAnalysis() => TutorialDraft(sections: [
          TutorialSection.blank(
            fen: handover?.root.fen ?? TutorialDraft.startFen,
            title: 'Deo 1',
          ),
        ]),
    };

    if (handover != null) {
      _draft.section.root = handover.root;
      _draft.section.cursorNode = handover.root;
      // Onto the part, not onto the screen: `_loadSelectedSection` below reads
      // the orientation out of the part, so setting the field here would be
      // overwritten one line later.
      _draft.section.blackOrientation = handover.blackOrientation;
    }
    // Every field of the open part, not just the two that used to be set here
    // by hand. `_loadSelectedSection` is the one place a part's kind, task,
    // offered answers, recorded move and orientation are read into the editor —
    // and until 7.9.2026 the opening path skipped it, so those fields sat at
    // their defaults and the first `_persist()` wrote the defaults back over
    // the part. Reopening a saved question and pressing „Sačuvaj tutorijal"
    // turned it into a plain position, silently. See
    // `test/tutorial_reopen_test.dart`.
    _loadSelectedSection();
    unawaited(_adoptStoredDraft());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionController.dispose();
    for (final c in _choiceControllers) {
      c.dispose();
    }
    // Flushed rather than left to the debounce: a pending timer dies with the
    // screen, and a draft that is only ever written 600 ms after the last move
    // is a draft that is never written when the trainer closes the window.
    //
    // Unless the trainer backed out of the stored-draft question, in which case
    // this screen holds a blank draft and writing it would delete theirs.
    if (!_leftWithoutWriting) {
      _syncSelectedSection();
      unawaited(TutorialDraftService.instance.flush(_draft));
    }
    super.dispose();
  }

  /// Decides what to do with the draft left in the local slot.
  ///
  /// One slot, one draft, and until P3b it was loaded on every open regardless
  /// of what the trainer had asked for — which is complaint 1.1 of
  /// `docs/PLAN-STUDIO-REDIZAJN.md`, in one line. What the entry says now
  /// decides:
  ///
  /// * **from the Studio's door** — the parts already written come back, and
  ///   the handed-over line becomes the open one. That is the flow the door
  ///   exists for: work the next part out in the Studio, hand it over, carry on
  ///   with the same tutorial. Unless the door said otherwise, in which case
  ///   nothing is adopted.
  /// * **a saved tutorial** — only a draft **of that tutorial** is adopted. A
  ///   draft of another one is somebody else's unfinished business, and is left
  ///   exactly where it is and unmentioned.
  /// * **a new tutorial** — nothing is adopted, and if the slot holds anything
  ///   the trainer is asked, by name. Silence is what made this feel haunted.
  Future<void> _adoptStoredDraft() async {
    final stored = await TutorialDraftService.instance.load();
    if (!mounted || stored == null) return;

    switch (widget.entry) {
      case TutorialEntryFromAnalysis(:final intoOpenDraft):
        if (!intoOpenDraft) return;
        final handover = _handover!;
        setState(() {
          _draft = stored;
          // The parts already written stay; the one being written is the line
          // the trainer just handed over.
          _draft.selected = _draft.sections.length - 1;
          _draft.section.root = handover.root;
          _draft.section.cursorNode = handover.root;
          _draft.section.storedPgn = null;
          _loadSelectedSection();
        });

      case TutorialEntrySaved():
        // A draft that never belonged to a tutorial, or belonged to a different
        // one, says nothing about this one.
        if (stored.lessonId == null || stored.lessonId != _draft.lessonId) {
          return;
        }
        setState(() {
          _draft = stored;
          _loadSelectedSection();
        });

      case TutorialEntryBlank():
        if (_isEmptyDraft(stored)) return;
        final choice = await _askAboutStoredDraft(stored);
        if (!mounted) return;
        switch (choice) {
          case _DraftChoice.resume:
            setState(() {
              _draft = stored;
              _loadSelectedSection();
            });
          case _DraftChoice.fresh:
            // Thrown away rather than left behind: a draft the trainer has
            // just declined must not be waiting for them the next time they
            // start something. This is the one branch that loses work, which
            // is why the question says so in those words.
            await TutorialDraftService.instance.clear();
          case _DraftChoice.cancel:
            // Neither tutorial is touched: not the stored one, and not this
            // blank screen, which goes away.
            _leftWithoutWriting = true;
            final navigator = Navigator.of(context);
            if (navigator.canPop()) navigator.pop();
        }
    }
  }

  /// Nothing worth offering: one part, no moves, no words, no name.
  static bool _isEmptyDraft(TutorialDraft draft) =>
      draft.title.trim().isEmpty &&
      draft.sections.length == 1 &&
      draft.sections.single.root.children.isEmpty &&
      draft.sections.single.root.comment.trim().isEmpty;

  /// Asks about the draft in the slot, **by name**.
  ///
  /// The name is the whole point. „You have an unfinished draft" is a question
  /// nobody can answer; „Opozicija, 3 dela" is one they can.
  Future<_DraftChoice> _askAboutStoredDraft(TutorialDraft stored) async {
    final name =
        stored.title.trim().isEmpty ? 'bez naziva' : stored.title.trim();
    final answer = await showDialog<_DraftChoice>(
      context: context,
      // Not dismissible: tapping beside this dialog used to answer it, and the
      // answer it gave was „discard".
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Imate nezavršen tutorijal'),
        content: Text(
          'Prošli put ste pisali tutorijal „$name" '
          '(${stored.sections.length} ${_partsWord(stored.sections.length)}). '
          'Nastavite tamo gde ste stali ili počnite novi? '
          'Ako počnete novi, nezavršeni se briše.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DraftChoice.cancel),
            child: const Text('Odustajem'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DraftChoice.fresh),
            child: const Text('Nov'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_DraftChoice.resume),
            child: const Text('Nastavi'),
          ),
        ],
      ),
    );
    // A dialog that comes back with nothing — a back button, a route popped
    // from elsewhere — is a question that was not answered, and an unanswered
    // question must never be read as the answer that deletes something.
    return answer ?? _DraftChoice.cancel;
  }

  static String _partsWord(int count) {
    if (count == 1) return 'deo';
    if (count >= 2 && count <= 4) return 'dela';
    return 'delova';
  }

  /// Fills the fields from the part that is open. Every write in this direction
  /// bumps [_fieldsEpoch].
  void _loadSelectedSection() {
    _annotationController.cancelPending();
    final section = _draft.section;
    _titleController.text = _draft.title;
    _instructionController.text = section.instruction ?? '';
    _currentKind = section.kind;
    for (final c in _choiceControllers) {
      c.dispose();
    }
    _choiceControllers
      ..clear()
      ..addAll([
        for (final choice in section.choices)
          TextEditingController(text: choice.text),
      ]);
    final correct = section.choices.indexWhere((c) => c.correct);
    _currentCorrectChoice = correct == -1 ? null : correct;
    _currentSolutionSan = section.solutionSan;
    // The orientation belongs to the part, and it is read back here for the
    // same reason the kind and the task are: `_syncSelectedSection` writes the
    // screen's orientation into whichever part is open, so a part opened while
    // the screen stood the other way round had its stored choice overwritten
    // by the way the previous part happened to be looking.
    _orientation =
        section.blackOrientation ? PlayerColor.black : PlayerColor.white;
    _boardController.loadFen(_current.fen);
    _lastMoveFrom = null;
    _lastMoveTo = null;
    _fieldsEpoch++;
  }

  /// Writes the fields back into the part that is open.
  ///
  /// The fields are the live editing surface and the section is the record;
  /// they meet here, in one place, before anything is persisted, committed or
  /// sent. The same shape `LessonStepEditorPanel._syncCurrentStepControllers`
  /// already uses.
  void _syncSelectedSection() {
    final section = _draft.section;
    final instruction = _instructionController.text.trim();
    section.instruction = instruction.isEmpty ? null : instruction;
    section.kind = _currentKind;
    section.solutionSan = _currentSolutionSan;
    section.blackOrientation = _orientation == PlayerColor.black;
    section.choices
      ..clear()
      ..addAll([
        for (var i = 0; i < _choiceControllers.length; i++)
          TutorialChoice(
            text: _choiceControllers[i].text,
            correct: i == _currentCorrectChoice,
          ),
      ]);
  }

  void _persist() {
    _syncSelectedSection();
    TutorialDraftService.instance.scheduleSave(_draft);
  }

  /// The one cursor this screen is walked by — the strip's buttons and the
  /// arrow keys read it from here rather than each building their own.
  ///
  /// [AnalysisNodeCursor] is what makes the strip *ask* at a fork instead of
  /// walking into the first child. That rule matters more on this side than on
  /// the student's: a trainer who wrote two answers to one move and gets only
  /// one of them back has lost the sideline they wrote the tutorial for.
  AnalysisNodeCursor _moveCursor() =>
      AnalysisNodeCursor(currentNode: _current, onSelect: _jumpTo);

  void _jumpTo(AnalysisNode node) {
    setState(() {
      // Drawing is left, not just interrupted. A half-drawn arrow was already
      // forgotten here — it would otherwise land on a position its first
      // square does not belong to — but the mode itself stayed on, so the next
      // click on the new beat's board drew instead of doing what it looked
      // like it would do. Asked for live on 7.9.2026: the toolbar must not
      // still be lit on a beat the trainer has only just arrived at.
      _annotationController.stop();
      _draft.section.cursorNode = node;
      _boardController.loadFen(node.fen);
      _lastMoveFrom = null;
      _lastMoveTo = null;
    });
    _persist();
  }

  /// Whether [node] is [_current] or stands above it on the line.
  ///
  /// Asked before a move is deleted: the trainer is usually standing on or
  /// below the move they are taking back, and a cursor left pointing into a
  /// detached subtree is a board showing a position the part no longer holds.
  bool _cursorIsAtOrBelow(AnalysisNode node) {
    for (AnalysisNode? n = _current; n != null; n = n.parent) {
      if (identical(n, node)) return true;
    }
    return false;
  }

  /// Takes a move back, with everything written under it.
  ///
  /// **The menu was already there and did nothing.** `AnalysisMoveTreeWidget`
  /// draws „Unapredi u Glavnu Liniju" and „Obriši Ovu Varijantu" on a
  /// long-press or a right-click, and this screen passed neither callback — so
  /// a trainer opened it, pressed „Obriši", and the move stayed. The only way
  /// to take a move back was to retype the line in the „PGN" tab, which is
  /// where the owner found it on 7.9.2026: „ne mogu da se brišu potezi (ili ne
  /// vidim kako)". The dead entries are hidden now, and these two are wired.
  ///
  /// It asks first only when there is something to lose — a move with words,
  /// drawings or moves under it. A trainer taking back a piece they dropped on
  /// the wrong square should not have to answer a question about it, and a
  /// dialog on every deletion is a dialog that gets dismissed unread.
  Future<void> _deleteNode(AnalysisNode node) async {
    final parent = node.parent;
    // The root is the part's starting position rather than a move. There is a
    // way to throw that away and it is „Obriši deo".
    if (parent == null) return;

    if (_carriesWork(node)) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Obriši potez?'),
          content: Text('„${node.moveNumberLabel}${node.moveSan}" i sve što '
              'je napisano posle njega biće obrisano.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Odustani'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Obriši'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
    }

    // Moved off it before it is detached, not after: `_jumpTo` loads the
    // board from the node it is given, and a cursor inside the subtree being
    // removed would be pointing at a position the part no longer has.
    if (_cursorIsAtOrBelow(node)) _jumpTo(parent);
    setState(() => parent.removeChild(node));
    _persist();
  }

  /// Whether [node] holds anything beyond the move itself.
  static bool _carriesWork(AnalysisNode node) =>
      node.children.isNotEmpty ||
      node.comment.trim().isNotEmpty ||
      node.arrows.isNotEmpty ||
      node.squares.isNotEmpty;

  /// Makes a sideline the line the child walks.
  ///
  /// It matters more here than in the Analysis Studio: the „Tok" timeline and
  /// the narrated walk both follow first children, so which branch is main is
  /// a decision about the lesson rather than about how the tree is drawn.
  void _promoteNode(AnalysisNode node) {
    final parent = node.parent;
    if (parent == null) return;
    setState(() => parent.promoteToMainLine(node));
    _persist();
  }

  /// A move the board reported, dragged or tapped.
  ///
  /// A move the position does not allow puts the board back where it was rather
  /// than growing a line out of it: the board is the trainer's only view of
  /// where they are, and leaving it showing a position the tree does not hold is
  /// how the two quietly part company.
  void _onMove(String from, String to, String promotion) {
    _annotationController.cancelPending();
    final played = playedMove(
      fen: _current.fen,
      from: from,
      to: to,
      promotion: promotion,
    );
    if (played == null) {
      _boardController.loadFen(_current.fen);
      return;
    }

    if (_currentKind == LessonStepKind.askMove) {
      setState(() {
        _currentSolutionSan = played.san;
      });
      _boardController.loadFen(_current.fen);
      _persist();
      return;
    }

    final child = _current.addChild(
      childFen: played.fen,
      san: played.san,
      uci: played.uci,
    );

    setState(() {
      _draft.section.cursorNode = child;
      _boardController.loadFen(played.fen);
      _lastMoveFrom = from;
      _lastMoveTo = to;
    });
    _persist();
  }

  /// Starts the part over on [fen], with nothing written after it.
  void _startFrom(String fen) {
    _annotationController.cancelPending();
    setState(() {
      final fresh = AnalysisNode(fen: fen);
      _draft.section
        ..root = fresh
        ..cursorNode = fresh
        // The stored text described the line that was just thrown away.
        ..storedPgn = null;
      _boardController.loadFen(fen);
      _lastMoveFrom = null;
      _lastMoveTo = null;
    });
    _persist();
  }

  void _flipBoard() {
    setState(() {
      _orientation = _orientation == PlayerColor.white
          ? PlayerColor.black
          : PlayerColor.white;
    });
    _persist();
  }

  /// The second and third of the three ways a start position gets here — a FEN
  /// typed in and the board editor. The first is the handover. It is the
  /// Studio's own dialog, so a trainer who has set a position once has set it
  /// everywhere.
  ///
  /// `onPgnLoaded` is deliberately not passed: importing a PGN into a tree is
  /// the Analysis Studio's job, and a line brought in that way arrives here
  /// through the door as a whole tree rather than through a second importer
  /// written beside the first.
  void _showSetupDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AnalysisBoardSetupDialog(
        initialFen: _current.fen,
        onPositionSet: _startFrom,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Studio za tutorijal',
            overflow: TextOverflow.ellipsis, maxLines: 1, style: AppText.title),
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: context.colors.accent),
            tooltip: 'Unos pozicije',
            onPressed: _showSetupDialog,
          ),
          TextButton(
            key: const Key('preview-as-student'),
            onPressed: _previewAsStudent,
            child: const Text('Pregledaj kao učenik'),
          ),
          FilledButton(
            onPressed: _saveTutorial,
            child: const Text('Sačuvaj tutorijal'),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      // Arrow keys drive the same cursor the strip's buttons do. This screen is
      // written on with a keyboard and a mouse, and reading a line with the
      // mouse alone is what makes a desktop window feel like a phone in a frame.
      body: MoveKeyboardShortcuts(
        cursor: _moveCursor(),
        // _jumpTo does its own setState.
        onChanged: () {},
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= Breakpoints.wide;
            // Beside the tree on a real window, under it on a narrow one. The
            // board never takes more height than it has: a `Row` wider than the
            // screen is clipped in silence in a release build, and this screen
            // is the one that has the most to put in a row.
            final boardPaneWidth =
                constraints.maxWidth - 460 - AppSpacing.md * 3;
            final maxHeightLimit =
                (constraints.maxHeight - 120).clamp(280.0, double.infinity);
            final boardSize = wide
                ? boardPaneWidth.clamp(280.0, maxHeightLimit)
                : constraints.maxWidth - AppSpacing.lg * 2;

            final board = _boardColumn(boardSize.toDouble());
            if (!wide) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(children: [board, _authoringColumn()]),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    key: const Key('board-pane'),
                    child: Center(
                      child: SingleChildScrollView(
                        child: board,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _authoringPaneWide(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _boardColumn(double boardSize) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: boardSize,
          height: boardSize,
          child: Card(
            elevation: 4,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: BoardWithCoordinates(
                size: boardSize - AppSpacing.sm * 2,
                orientation: _orientation,
                builder: (inner) => ChessBoardWithOverlay(
                  controller: _boardController,
                  boardOrientation: _orientation,
                  boardSize: inner,
                  isAllowedToMove: true,
                  isDrawingMode: _annotationController.isDrawing,
                  drawingStartSquare: _annotationController.pendingFrom,
                  // The arrows and the rings the trainer drew on this move.
                  // The node has carried them since phase 2 of the interactive
                  // lesson plan and nothing wrote one until P7a: every arrow in
                  // every lesson before that got there by being typed into a
                  // PGN by hand. The bar below writes them now, through
                  // `BoardAnnotationController`.
                  arrows: _current.arrows,
                  squares: _current.squares,
                  engineArrows: const [],
                  lastMoveFrom: _lastMoveFrom,
                  lastMoveTo: _lastMoveTo,
                  onMove: _onMove,
                  onSquareTapForDrawing: _onSquareTapForDrawing,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: boardSize,
          child: BoardAnnotationBar(
            mode: _annotationController.mode,
            selectedColorCode: _annotationController.colorCode,
            onArrowPressed: _toggleArrowMode,
            onSquarePressed: _toggleSquareMode,
            onColorSelected: _selectColor,
            onClearPressed: _clearMarks,
          ),
        ),
        SizedBox(
          width: boardSize,
          child: MoveNavigationControls(
            cursor: _moveCursor(),
            centerLabel: null,
            iconSize: 20,
            onFlipBoard: _flipBoard,
          ),
        ),
      ],
    );
  }

  void _toggleArrowMode() {
    setState(() {
      if (_annotationController.mode == AnnotationMode.arrow) {
        _annotationController.stop();
      } else {
        _annotationController.setMode(AnnotationMode.arrow);
      }
    });
  }

  void _toggleSquareMode() {
    setState(() {
      if (_annotationController.mode == AnnotationMode.square) {
        _annotationController.stop();
      } else {
        _annotationController.setMode(AnnotationMode.square);
      }
    });
  }

  void _selectColor(String code) {
    setState(() {
      _annotationController.setColor(code);
    });
  }

  void _clearMarks() {
    final changed = _annotationController.clearMarks(
      arrows: _current.arrows,
      squares: _current.squares,
    );
    if (changed) {
      setState(() {});
      _persist();
    }
  }

  void _onSquareTapForDrawing(String square) {
    final changed = _annotationController.tap(
      square,
      arrows: _current.arrows,
      squares: _current.squares,
    );
    setState(() {});
    if (changed) {
      _persist();
    }
  }

  /// Puts the generated names back in order after the parts have moved.
  ///
  /// Only the names the studio wrote itself — a title the trainer typed is
  /// theirs and survives every reorder. See [isGeneratedSectionTitle], which is
  /// the one place that rule lives.
  void _renumberGeneratedTitles() {
    for (var i = 0; i < _draft.sections.length; i++) {
      final title = _draft.sections[i].title;
      if (title.trim().isEmpty || isGeneratedSectionTitle(title)) {
        _draft.sections[i].title = generatedSectionTitle(i);
      }
    }
  }

  void _selectSection(int index) {
    if (index < 0 || index >= _draft.sections.length) return;
    _syncSelectedSection();
    _draft.selected = index;
    _draft.section.cursorNode = _draft.section.root;
    _loadSelectedSection();
    setState(() {});
    _persist();
  }

  /// „Novi prikaz" — the next demonstration, and the board it opens on.
  ///
  /// The one question left, and it is about a *position* rather than about
  /// parts: „Odavde" keeps the child's board from reloading, which is what
  /// makes two demonstrations in a row read as one; „Nova tabla" starts a
  /// fresh example. The old wording asked where a *deo* begins, which is the
  /// word this screen no longer makes a trainer think in.
  Future<void> _addShowSection() async {
    final continueFromEnd = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odakle počinje?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Otkaži'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nova tabla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Odavde'),
          ),
        ],
      ),
    );
    if (!mounted || continueFromEnd == null) return;

    _syncSelectedSection();
    _draft.addSection(
      continueFromEnd: continueFromEnd,
      title: generatedSectionTitle(_draft.sections.length),
    );
    _renumberGeneratedTitles();
    _loadSelectedSection();
    setState(() {});
    _persist();
  }

  /// „Traži potez na tabli" / „Traži odgovor iz liste" — the question goes on
  /// the beat the trainer is standing on.
  ///
  /// This is the arrangement the studio has always described and never built:
  /// the demonstration in the part in front, the question on a bare position,
  /// and what followed carried on after it. [splitForQuestion] decides all of
  /// that; the screen only puts the parts where they go.
  ///
  /// A part with no line has nothing to cut, so it simply becomes the question
  /// — which is the same act, with the first and third parts empty.
  void _askHere(LessonStepKind kind) {
    _syncSelectedSection();
    final part = _draft.section;

    if (!canSplitForQuestion(part)) {
      setState(() => _currentKind = kind);
      _syncSelectedSection();
      _persist();
      return;
    }

    final parts = splitForQuestion(part, _current, kind: kind);
    setState(() {
      _draft.replaceSelected(parts);
      // The question is the one the trainer just asked for, so it is the one
      // they are left standing on — with the board on the position it asks
      // about.
      _draft.selected = _draft.sections.indexOf(parts.firstWhere(
        (p) => p.kind != LessonStepKind.show,
        orElse: () => parts.first,
      ));
    });
    _renumberGeneratedTitles();
    _loadSelectedSection();
    setState(() {});
    _persist();
    AppFeedback.success(context, 'Pitanje je postavljeno na ovoj poziciji.');
  }

  /// „Preimenuj" — the trainer's own name for a part, or none.
  ///
  /// Emptying the field is not a failure to name it: a part with no name of its
  /// own is called by what it says, which is what [TutorialSection.label] does
  /// and what most parts are better off with.
  Future<void> _renameSection(int index) async {
    if (index < 0 || index >= _draft.sections.length) return;
    final section = _draft.sections[index];
    final own = isGeneratedSectionTitle(section.title.trim())
        ? ''
        : section.title.trim();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: own, hint: section.label(index)),
    );
    if (!mounted || name == null) return;
    setState(() {
      section.title =
          name.trim().isEmpty ? generatedSectionTitle(index) : name.trim();
    });
    _persist();
  }

  void _moveSection(int from, int to) {
    if (from < 0 || from >= _draft.sections.length) return;
    if (to < 0 || to >= _draft.sections.length || from == to) return;
    _syncSelectedSection();
    _draft.moveSection(from, to);
    _renumberGeneratedTitles();
    _loadSelectedSection();
    setState(() {});
    _persist();
  }

  void _cloneSection(int index) {
    if (index < 0 || index >= _draft.sections.length) return;
    _syncSelectedSection();
    _draft.cloneSection(index);
    _renumberGeneratedTitles();
    _loadSelectedSection();
    setState(() {});
    _persist();
  }

  void _removeSection(int index) {
    if (!_draft.removeSection(index)) {
      AppFeedback.info(context, 'Poslednji deo ne može biti obrisan.');
      return;
    }
    _renumberGeneratedTitles();
    _loadSelectedSection();
    setState(() {});
    _persist();
  }

  /// The tutorial as a child will meet it, without saving anything.
  ///
  /// It was buried in `LessonStepEditorPanel`, which D8 retires on Windows, and
  /// it is the fastest answer to „does this feel right" that this screen can
  /// give — so it comes across rather than being lost with the panel.
  ///
  /// **Nothing is sent.** The draft is projected into an `AssignmentDetail` and
  /// the viewer is handed `PreviewAssignmentApiService`, which answers every
  /// call locally: a trainer trying their own question does not mark a child's
  /// schedule, and a preview that wrote to the server would be a save nobody
  /// asked for.
  void _previewAsStudent() {
    _syncSelectedSection();
    final steps = _draft.positionList;

    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LessonViewerScreen(
        session: widget.session,
        detail: AssignmentDetail(
          assignment: Assignment(
            id: _draft.lessonId ?? 0,
            title: _titleController.text.trim(),
          ),
          items: [
            for (var i = 0; i < steps.length; i++)
              AssignmentItem(puzzleId: null, position: i, attemptedAt: null),
          ],
          steps: steps.map(LessonStep.fromJson).toList(),
        ),
        api: PreviewAssignmentApiService(),
      ),
    ));
  }

  /// The open part as text, with the map of where each node sits in it.
  ///
  /// **A fresh export, not `pgnForSave`.** That getter answers with the exact
  /// text the server stored while the part is untouched — right for a save, and
  /// wrong here: the spans describe the text the writer just wrote, and a
  /// stored text formatted even slightly differently would put the caret and
  /// the right-click menu on the wrong move. What is *sent* is still the stored
  /// text; what is *shown* is the tree.
  PgnWithSpans get _exportOfOpenPart =>
      StudioLessonStep.textWithSpans(_draft.section.root);

  /// The node with this id, anywhere in the open part's tree.
  AnalysisNode? _nodeById(String id) {
    AnalysisNode? walk(AnalysisNode node) {
      if (node.id == id) return node;
      for (final child in node.children) {
        final hit = walk(child);
        if (hit != null) return hit;
      }
      return null;
    }

    return walk(_root);
  }

  /// „Dodaj strelicu" and „Označi polje": stand on the move that was clicked and
  /// hand the drawing to the board.
  ///
  /// **No second way of drawing is written.** The board and
  /// `BoardAnnotationController` already do this, and a menu that put marks on
  /// nodes by itself would be the second copy of a rule this repository has
  /// paid for more than once.
  void _drawFromText(String nodeId, AnnotationMode mode) {
    final node = _nodeById(nodeId);
    if (node == null) return;
    if (node.id != _current.id) _jumpTo(node);
    setState(() => _annotationController.setMode(mode));
    AppFeedback.info(
      context,
      mode == AnnotationMode.arrow
          ? 'Nacrtajte strelicu na tabli.'
          : 'Kliknite polje na tabli.',
    );
  }

  /// „Dodaj komentar": the words of one move, edited where the trainer asked.
  Future<void> _editCommentFromText(String nodeId) async {
    final node = _nodeById(nodeId);
    if (node == null) return;
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _CommentDialog(initial: node.comment),
    );
    if (!mounted || saved == null) return;
    setState(() => node.comment = saved);
    _persist();
  }

  /// Reads the trainer's text and, if it replays, makes it the part's line.
  ///
  /// Through `readStepTree` — that is `LessonStepLine`, the reader the child's
  /// screen uses. Nothing here parses a PGN a second way, which is the rule
  /// `step_tree.dart` carries and the reason this tab is a rendering rather
  /// than a second editor.
  ///
  /// **Refused rather than partly applied.** `MoveTree.parsePgn` skips a move it
  /// cannot play without a word, so a text with one bad move would otherwise
  /// replace the part with the moves it happened to understand — the trainer
  /// watching a line they wrote come back shorter, with no error. The likeliest
  /// cause is not a typo but a game pasted from the initial position into a part
  /// that stands on move twelve, where every move is rejected at once.
  Future<void> _applyPgn(String text) async {
    final section = _draft.section;

    // A pasted game usually carries its own `[FEN]`, and it is nearly always a
    // different position from the one this part stands on — in which case every
    // move is rejected at once and the count says nothing useful. So the
    // question is asked **before** the parse, and only when the two positions
    // really differ. Clocks are not part of that comparison: a line walked to
    // here and a part written from here are the same board to a child.
    var startFen = section.root.fen;
    final header = MoveTree.fenHeaderOf(text);
    if (header != null && !MoveTree.samePosition(header, startFen)) {
      final answer = await _askAboutPastedPosition(
        title: 'Tekst počinje iz druge pozicije',
        explanation:
            'Ovaj PGN nosi svoju polaznu poziciju, različitu od pozicije ovog '
            'dela. Ako je uzmete, dete će ovaj deo otvarati na toj poziciji.',
        takeLabel: 'Uzmi tu poziciju',
      );
      if (!mounted || answer == _PastedPosition.cancel) return;
      if (answer == _PastedPosition.take) startFen = header;
    }

    var read = readStepTree(fen: startFen, pgn: text);

    // A text with no `[FEN]` says nothing about where it starts, so there was
    // nothing to ask about and the trainer got only the count of moves that
    // would not play — „samo mi ovo javi", 7.9.2026. But a PGN without a
    // header is a game from the standard opening position, which is a position
    // like any other: if the text plays cleanly from **there** and not from
    // here, the same question can be asked, and now it is grounded in the
    // reading rather than in a guess about what the trainer meant.
    //
    // Only when it replays whole. A text that half fits the opening position
    // is not a game from it, and offering to move the part onto a position
    // that also rejects moves would trade one silent loss for another.
    if (read.rejectedMoves > 0 && header == null) {
      final fromStart = readStepTree(fen: TutorialDraft.startFen, pgn: text);
      if (fromStart.rejectedMoves == 0 && fromStart.root.children.isNotEmpty) {
        final answer = await _askAboutPastedPosition(
          title: 'Tekst ne počinje odavde',
          explanation:
              'Ovaj PGN nema svoju polaznu poziciju, a njegovi potezi ne mogu '
              'da se odigraju iz pozicije ovog dela — mogu iz početne. Ako je '
              'uzmete, dete će ovaj deo otvarati iz početne pozicije.',
          takeLabel: 'Uzmi početnu poziciju',
        );
        if (!mounted || answer == _PastedPosition.cancel) return;
        if (answer == _PastedPosition.take) {
          startFen = TutorialDraft.startFen;
          read = fromStart;
        }
      }
    }

    if (read.rejectedMoves > 0) {
      AppFeedback.error(
        context,
        'Nije primenjeno: ${read.rejectedMoves} '
        '${_movesWord(read.rejectedMoves)} ne može da se odigra iz pozicije '
        'ovog dela.'
        // Said only when it is the answer to „why did it not ask me
        // anything?". With a `[FEN]` the question was asked and answered.
        '${header == null ? ' Tekst nema svoju polaznu poziciju ([FEN]), pa '
            'ne može da se prepozna odakle počinje.' : ''}',
      );
      return;
    }

    setState(() {
      section.root = read.root;
      // The end of the line, not its beginning. A trainer presses „Primeni"
      // having just typed a move on the end of the text, and being thrown back
      // to the opening position means finding their way to it again on every
      // application — reported live on 7.9.2026, on the very fix that made a
      // line ending in `Nxb4*` applicable at all. It is also what „Tok" then
      // shows: the last card is the one they wrote.
      section.cursorNode = endOfMainLine(read.root);
      // Nothing to invalidate by hand. `isPristine` compares `treeSignature`
      // against the tree itself, and this is a different tree — which is the
      // whole reason P1 chose a signature over a `bool edited`: a flag is the
      // version of this that one mutator forgets to set. Deleting the stored
      // text here was watched surviving a mutation, because it was doing
      // nothing.

      _annotationController.cancelPending();
      _boardController.loadFen(section.cursorNode.fen);
      _lastMoveFrom = null;
      _lastMoveTo = null;
    });
    _persist();
    AppFeedback.success(context, 'Primenjeno.');
  }

  /// Asked once, never assumed: taking the pasted position changes the board a
  /// child opens this part on.
  ///
  /// Two questions, one dialog, because they have the same three answers and
  /// the same consequence. The first is „this text brought a position of its
  /// own"; the second is „this text brought none, and only plays from the
  /// opening position".
  Future<_PastedPosition> _askAboutPastedPosition({
    required String title,
    required String explanation,
    required String takeLabel,
  }) async {
    final answer = await showDialog<_PastedPosition>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_PastedPosition.cancel),
            child: const Text('Odustani'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_PastedPosition.keep),
            child: const Text('Zadrži postojeću'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_PastedPosition.take),
            child: Text(takeLabel),
          ),
        ],
      ),
    );
    return answer ?? _PastedPosition.cancel;
  }

  static String _movesWord(int count) {
    if (count == 1) return 'potez';
    if (count >= 2 && count <= 4) return 'poteza';
    return 'poteza';
  }

  Future<void> _saveTutorial() async {
    if (_titleController.text.trim().isEmpty) {
      AppFeedback.error(context, 'Tutorijal mora da ima naziv.');
      return;
    }

    _syncSelectedSection();

    // Named, not counted. A trainer with fourteen parts and a refusal that says
    // „a part" has been told they are wrong and not where — which is the same
    // as not being told. `LessonStepEditorPanel` named them, and D8 retires that
    // panel, so the naming comes here with the rule.
    final leaking = _draft.sections.where((s) => s.leaksAnswer).toList();
    if (leaking.isNotEmpty) {
      AppFeedback.error(
        context,
        'Nije sačuvano. ${_namesOf(leaking)} nosi liniju u kojoj je odgovor '
        '— ukloni liniju ili promeni tip zadatka.',
      );
      return;
    }

    for (final section in _draft.sections) {
      if (section.kind != LessonStepKind.askChoice) continue;
      final answers = section.choices.where((c) => c.text.trim().isNotEmpty);
      if (answers.length < 2 || answers.length > 4) {
        AppFeedback.error(context,
            'Pitanje sa ponuđenim odgovorima traži dva do četiri odgovora.');
        return;
      }
      if (answers.where((c) => c.correct).length != 1) {
        AppFeedback.error(
            context, 'Tačno jedan ponuđeni odgovor mora da bude tačan.');
        return;
      }
    }

    _draft.title = _titleController.text.trim();
    final error = await commitDraft(_draft, _lessonApi);

    if (!mounted) return;
    if (error == null) {
      // The draft now knows its lesson id and every step id, so the next press
      // of this button edits this tutorial instead of making a second one.
      _persist();
      AppFeedback.success(context, 'Tutorijal je sačuvan.');
    } else {
      AppFeedback.error(context, error);
    }
  }

  /// The tutorial's name, written once and drawn by both layouts.
  ///
  /// Both halves of this screen need it and batch 58 arrived with the field —
  /// and the four lines of comment explaining it — copied into each. A widget
  /// written twice is a widget that gets fixed once.
  Widget _titleField() {
    return TextField(
      key: const Key('tutorial-title'),
      controller: _titleController,
      decoration: const InputDecoration(labelText: 'Naziv tutorijala'),
      // Written into the draft rather than only held in the controller. The
      // draft is what `TutorialDraftService` stores, so a title that lives only
      // here comes back empty next time — with every part still in place, which
      // is what made it invisible.
      onChanged: (value) {
        _draft.title = value;
        _persist();
      },
    );
  }

  /// The table of contents, wired to the screen that owns the draft.
  Widget _sectionsPanel() {
    return TutorialSectionsPanel(
      draft: _draft,
      onSelect: _selectSection,
      onAddShow: _addShowSection,
      onAsk: _askHere,
      onMove: _moveSection,
      onClone: _cloneSection,
      onRename: _renameSection,
      onRemove: _removeSection,
    );
  }

  Widget _authoringPaneWide() {
    return SizedBox(
      key: const Key('authoring-pane'),
      width: 460,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titleField(),
          _leakBanner(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            key: const Key('sections-half'),
            flex: 2,
            child: _sectionsPanel(),
          ),
          const Divider(),
          Expanded(
            key: const Key('editor-half'),
            flex: 3,
            child: SingleChildScrollView(
              child: _editorFields(),
            ),
          ),
        ],
      ),
    );
  }

  /// The tree of the part being written, and everything written *about* it.
  Widget _authoringColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titleField(),
        _leakBanner(),
        const SizedBox(height: AppSpacing.md),
        _sectionsPanel(),
        const SizedBox(height: AppSpacing.md),
        _editorFields(),
      ],
    );
  }

  /// „Deo 2" and „Deo 4", quoted, for a sentence that names what is wrong.
  static String _namesOf(List<TutorialSection> sections) => sections
      .map((s) => '„${s.title.trim().isEmpty ? 'Deo' : s.title}"')
      .join(', ');

  /// Said on the way in, about parts that were already saved this way.
  ///
  /// §7.2 of the plan: a tutorial written before this refusal existed can carry
  /// the leak, and hydration is the only moment anyone would find out. The quiet
  /// version of this bug is a child who simply stops getting anything wrong, so
  /// it is worth a banner rather than a line in a log.
  Widget _leakBanner() {
    final leaking = _draft.sections.where((s) => s.leaksAnswer).toList();
    if (leaking.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const Key('leak-banner'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Material(
        color: context.colors.dangerContainer,
        borderRadius: AppRadii.roundedSm,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber,
                  size: 18, color: context.colors.onDangerContainer),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Dete bi videlo odgovor: ${_namesOf(leaking)} traži potez, a '
                  'nosi liniju koju dete može da prolista dugmetom „Sledeći '
                  'potez".',
                  style: AppText.body
                      .copyWith(color: context.colors.onDangerContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The kind the trainer picked, and the one question worth asking about it.
  ///
  /// Asked rather than done: deleting a trainer's line and the words inside it
  /// because they touched a dropdown is not a repair, it is a loss they did not
  /// agree to. Refusing outright is no better — it leaves them with a position
  /// they cannot ask about and no way forward. The demonstration belongs in the
  /// part *before* the question, which the viewer joins without reloading the
  /// board. Carried over from `LessonStepEditorPanel`, which D8 retires.
  Future<void> _chooseKind(LessonStepKind? value) async {
    if (value == null) return;

    if (value == LessonStepKind.askMove && _draft.section.hasLine) {
      final drop = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dete bi videlo odgovor'),
          content: const Text(
            'Ovaj deo nosi liniju, a dete može da je prolista dugmetom '
            '„Sledeći potez" pre nego što odgovori. Demonstracija ide u deo '
            'ispred pitanja — pitanje ostaje samo pozicija.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Odustani'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Ukloni liniju i postavi pitanje'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (drop != true) {
        // The dropdown keeps the value it was given in its own state, so the
        // subtree is rebuilt to put „Samo prikaži" back in front of the
        // trainer. Same reason [_fieldsEpoch] exists at all.
        setState(() => _fieldsEpoch++);
        return;
      }
      setState(_dropLine);
    }

    setState(() => _currentKind = value);
    _persist();
  }

  /// Takes the moves off the open part, keeping the position it asks about and
  /// everything written on that position.
  void _dropLine() {
    final section = _draft.section;
    section.root.children.clear();
    section.cursorNode = section.root;
    _boardController.loadFen(section.root.fen);
    _lastMoveFrom = null;
    _lastMoveTo = null;
    _annotationController.cancelPending();
  }

  Widget _questionCard() {
    return Material(
      key: const Key('question-card'),
      color: context.colors.surface,
      borderRadius: AppRadii.roundedMd,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          borderRadius: AppRadii.roundedMd,
          border: Border.all(
            color: context.colors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The subtree is rebuilt whenever the fields are refilled from the
            // model — see [_fieldsEpoch]. The field's own key stays put, because it
            // is the handle the tests reach it by.
            KeyedSubtree(
              key: ValueKey('kind-$_fieldsEpoch'),
              child: DropdownButtonFormField<LessonStepKind>(
                key: const Key('example-kind'),
                initialValue: _currentKind,
                decoration: const InputDecoration(labelText: 'Tip zadatka'),
                items: const [
                  DropdownMenuItem(
                      value: LessonStepKind.show, child: Text('Samo prikaži')),
                  DropdownMenuItem(
                      value: LessonStepKind.askMove,
                      child: Text('Traži potez na tabli')),
                  DropdownMenuItem(
                      value: LessonStepKind.askChoice,
                      child: Text('Traži odgovor iz liste')),
                ],
                onChanged: _chooseKind,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_currentKind != LessonStepKind.show) ...[
              TextField(
                key: const Key('example-instruction'),
                controller: _instructionController,
                decoration:
                    const InputDecoration(labelText: 'Zadatak za učenika'),
                // Same reason as the sentence on a beat card: a question a
                // child reads is longer than one line, and a field that scrolls
                // sideways hides its own beginning. It **grows** with the text
                // rather than starting two lines tall: this card carries the
                // answers and „Dodaj odgovor" under it, and two lines of empty
                // field pushed that button below the fold — which is not a
                // layout opinion but a control a trainer cannot press.
                maxLines: null,
                keyboardType: TextInputType.multiline,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (_currentKind == LessonStepKind.askMove) ...[
              if (_currentSolutionSan != null)
                Text('Tačan potez: $_currentSolutionSan'),
            ],
            if (_currentKind == LessonStepKind.askChoice) ...[
              Text('Ponuđeni odgovori', style: AppText.bodyBold),
              // `RadioGroup` rather than a `groupValue` on every button: that pair
              // of arguments is deprecated, and the batch that wrote them silenced
              // the analyzer with a file-level `ignore_for_file` instead — which
              // kept the count at 29 by hiding three infos rather than by not
              // adding them. This is also the shape `LessonStepEditorPanel` uses,
              // which the brief named.
              RadioGroup<int>(
                groupValue: _currentCorrectChoice,
                onChanged: (val) => setState(() => _currentCorrectChoice = val),
                child: Column(
                  children: [
                    for (int i = 0; i < _choiceControllers.length; i++)
                      Row(
                        children: [
                          Radio<int>(value: i),
                          Expanded(
                            child: TextField(
                              key: Key('example-choice-$i'),
                              controller: _choiceControllers[i],
                            ),
                          ),
                          IconButton(
                            key: Key('example-choice-delete-$i'),
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                _choiceControllers.removeAt(i);
                                if (_currentCorrectChoice == i) {
                                  _currentCorrectChoice = null;
                                } else if (_currentCorrectChoice != null &&
                                    _currentCorrectChoice! > i) {
                                  _currentCorrectChoice =
                                      _currentCorrectChoice! - 1;
                                }
                              });
                            },
                          )
                        ],
                      ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _choiceControllers.add(TextEditingController());
                  });
                },
                child: const Text('Dodaj odgovor'),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _editorFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _tabButton(
              key: const Key('tok-tab'),
              label: 'Tok',
              isSelected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
            const SizedBox(width: AppSpacing.xs),
            _tabButton(
              key: const Key('stablo-tab'),
              label: 'Stablo',
              isSelected: _selectedTab == 1,
              onTap: () => setState(() => _selectedTab = 1),
            ),
            const SizedBox(width: AppSpacing.xs),
            _tabButton(
              key: const Key('pgn-tab'),
              label: 'PGN',
              isSelected: _selectedTab == 2,
              onTap: () => setState(() => _selectedTab = 2),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        IndexedStack(
          index: _selectedTab,
          children: [
            TutorialFlowPanel(
              root: _root,
              current: _current,
              onSelect: _jumpTo,
              onCommentChanged: (node, text) {
                // `setState`, because the sentence is also the part's name:
                // the panel calls [TutorialSection.label], which reads the
                // first thing the part says. The beat cards keep their own
                // controllers and focus nodes, so rebuilding them under the
                // caret costs a frame and changes nothing the trainer sees.
                setState(() => node.comment = text);
                _persist();
              },
              question: _questionCard(),
              onDelete: _deleteNode,
            ),
            AnalysisMoveTreeWidget(
              rootNode: _root,
              activeNode: _current,
              onSelectNode: _jumpTo,
              onPromoteNode: _promoteNode,
              onDeleteNode: _deleteNode,
            ),
            // Keyed by the tree it is showing: a new part, or a text that has
            // just been applied, is a different line and the field follows it.
            // Anything else — a move played, an arrow drawn — leaves the
            // trainer's unapplied text alone, which `didUpdateWidget` decides.
            TutorialPgnPanel(
              key: ValueKey(_root.id),
              export: _exportOfOpenPart,
              currentNodeId: _current.id,
              onApply: _applyPgn,
              onCaretMoved: (id) {
                final node = _nodeById(id);
                if (node != null && node.id != _current.id) _jumpTo(node);
              },
              onDrawArrow: (id) => _drawFromText(id, AnnotationMode.arrow),
              onMarkSquare: (id) => _drawFromText(id, AnnotationMode.square),
              onEditComment: _editCommentFromText,
            ),
          ],
        ),
      ],
    );
  }

  Widget _tabButton({
    required Key key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: isSelected ? context.colors.surfaceRaised : context.colors.surface,
      borderRadius: AppRadii.roundedSm,
      child: InkWell(
        borderRadius: AppRadii.roundedSm,
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 64),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.roundedSm,
            border: Border.all(
              color: isSelected
                  ? context.colors.borderStrong
                  : context.colors.border,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: (isSelected ? AppText.bodyBold : AppText.body).copyWith(
              color: isSelected
                  ? context.colors.textPrimary
                  : context.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// The one-field dialog behind „Dodaj komentar".
///
/// A `StatefulWidget` rather than a `TextEditingController` created beside
/// `showDialog`, and that is a fix this repository has already paid for once:
/// disposing on the dialog's future asserts, because the future completes on
/// `pop` while the route is still animating out and the field is still being
/// rebuilt. The controller has to belong to something that goes away with the
/// route.
/// „Preimenuj" — a name of the trainer's own, or none at all.
///
/// The hint is the name the part goes by now, so emptying the field reads as
/// „call it what it says" rather than as leaving something blank.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial, required this.hint});

  final String initial;
  final String hint;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Naziv'),
      content: TextField(
        key: const Key('section-name-field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Naziv',
          hintText: widget.hint,
          helperText: 'Prazno — zove se po onome što piše u njemu.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Sačuvaj'),
        ),
      ],
    );
  }
}

class _CommentDialog extends StatefulWidget {
  const _CommentDialog({required this.initial});

  final String initial;

  @override
  State<_CommentDialog> createState() => _CommentDialogState();
}

class _CommentDialogState extends State<_CommentDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Komentar za ovaj potez'),
      content: TextField(
        key: const Key('pgn-comment-field'),
        controller: _controller,
        autofocus: true,
        minLines: 2,
        maxLines: null,
        keyboardType: TextInputType.multiline,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Odustani'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Sačuvaj'),
        ),
      ],
    );
  }
}
