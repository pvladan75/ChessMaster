import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node_cursor.dart';
import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/assignments/models/assignment.dart'
    show LessonStepKind;
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_save.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_flow_panel.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_sections_panel.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
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
      if (handover.blackOrientation) _orientation = PlayerColor.black;
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
    _syncSelectedSection();
    unawaited(TutorialDraftService.instance.flush(_draft));
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
        final resume = await _askAboutStoredDraft(stored);
        if (!mounted) return;
        if (resume) {
          setState(() {
            _draft = stored;
            _loadSelectedSection();
          });
        } else {
          // Thrown away rather than left behind: a draft the trainer has just
          // declined must not be waiting for them the next time they start
          // something.
          await TutorialDraftService.instance.clear();
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
  Future<bool> _askAboutStoredDraft(TutorialDraft stored) async {
    final name =
        stored.title.trim().isEmpty ? 'bez naziva' : stored.title.trim();
    final answer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Imate nezavr\u0161en tutorijal'),
        content: Text(
          'Pro\u0161li put ste pisali tutorijal \u201E$name\u201D '
          '(${stored.sections.length} ${_partsWord(stored.sections.length)}). '
          'Nastavite tamo gde ste stali, ili ga odbacite i po\u010Dnite nov?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Odbaci'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Nastavi'),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  static String _partsWord(int count) {
    if (count == 1) return 'deo';
    if (count >= 2 && count <= 4) return 'dela';
    return 'delova';
  }

  /// Fills the fields from the part that is open. Every write in this direction
  /// bumps [_fieldsEpoch].
  void _loadSelectedSection() {
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
      _draft.section.cursorNode = node;
      _boardController.loadFen(node.fen);
      _lastMoveFrom = null;
      _lastMoveTo = null;
    });
    _persist();
  }

  /// A move the board reported, dragged or tapped.
  ///
  /// A move the position does not allow puts the board back where it was rather
  /// than growing a line out of it: the board is the trainer's only view of
  /// where they are, and leaving it showing a position the tree does not hold is
  /// how the two quietly part company.
  void _onMove(String from, String to, String promotion) {
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
                  isDrawingMode: false,
                  drawingStartSquare: null,
                  // The arrows and the rings the trainer drew on this move. The
                  // node has carried them since phase 2 of the interactive
                  // lesson plan; the editor that writes them is P7 of the
                  // redesign.
                  arrows: _current.arrows,
                  squares: _current.squares,
                  engineArrows: const [],
                  lastMoveFrom: _lastMoveFrom,
                  lastMoveTo: _lastMoveTo,
                  onMove: _onMove,
                  onSquareTapForDrawing: (_) {},
                ),
              ),
            ),
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

  void _addSection({required bool continueFromEnd}) {
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

  Future<void> _saveTutorial() async {
    if (_titleController.text.trim().isEmpty) {
      AppFeedback.error(context, 'Tutorijal mora da ima naziv.');
      return;
    }

    _syncSelectedSection();

    for (final section in _draft.sections) {
      if (section.kind == LessonStepKind.askMove &&
          section.pgnForSave.trim().isNotEmpty) {
        AppFeedback.error(
            context, 'Deo koji traži potez ne sme da ima liniju.');
        return;
      }
      if (section.kind == LessonStepKind.askChoice &&
          !section.choices.any((c) => c.correct)) {
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
      onAdd: _addSection,
      onMove: _moveSection,
      onClone: _cloneSection,
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
        const SizedBox(height: AppSpacing.md),
        _sectionsPanel(),
        const SizedBox(height: AppSpacing.md),
        _editorFields(),
      ],
    );
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
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _currentKind = val;
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_currentKind != LessonStepKind.show) ...[
              TextField(
                key: const Key('example-instruction'),
                controller: _instructionController,
                decoration:
                    const InputDecoration(labelText: 'Zadatak za učenika'),
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
                node.comment = text;
                _persist();
              },
              question: _questionCard(),
            ),
            AnalysisMoveTreeWidget(
              rootNode: _root,
              activeNode: _current,
              onSelectNode: _jumpTo,
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
