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
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
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
    this.handover,
    this.lessonApi,
  });

  final UserSession session;

  /// The position — or the whole line — the Analysis Studio handed over.
  ///
  /// Null when the trainer opened the screen on its own, in which case the
  /// board starts on the position a game starts on and the draft they left last
  /// time comes back.
  final TutorialHandover? handover;

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
  final TextEditingController _sentenceController = TextEditingController();
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

  /// The line being written, and where the trainer is standing on it.
  AnalysisNode get _root => _draft.section.root;
  AnalysisNode get _current => _draft.section.cursorNode;

  @override
  void initState() {
    super.initState();
    final handover = widget.handover;
    _draft = TutorialDraft(sections: [
      TutorialSection.blank(
        fen: handover?.root.fen ?? TutorialDraft.startFen,
        title: 'Primer 1',
      ),
    ]);
    if (handover != null) {
      _draft.section.root = handover.root;
      _draft.section.cursorNode = handover.root;
    }
    if (handover?.blackOrientation ?? false) _orientation = PlayerColor.black;
    _boardController.loadFen(_root.fen);
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sentenceController.dispose();
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

  /// Brings back what was being written.
  ///
  /// A handover wins over the stored working tree — the trainer just said which
  /// position they want — but the parts already written come back either way,
  /// because that is the flow the door exists for: work the next part out in
  /// the Studio, hand it over, carry on with the same tutorial.
  ///
  /// Giving the slot an identity, so that opening a *different* tutorial can no
  /// longer come up carrying this one's parts, is D4 of
  /// `docs/PLAN-STUDIO-REDIZAJN.md` and lands with the entry flow in P3.
  Future<void> _restoreDraft() async {
    final restored = await TutorialDraftService.instance.load();
    if (!mounted || restored == null) return;

    final handover = widget.handover;
    setState(() {
      _draft = restored;
      if (handover != null) {
        // The parts already written stay; the one being written is the line the
        // trainer just handed over.
        _draft.selected = _draft.sections.length - 1;
        _draft.section.root = handover.root;
        _draft.section.cursorNode = handover.root;
      } else {
        _orientation = _draft.section.blackOrientation
            ? PlayerColor.black
            : PlayerColor.white;
      }
      _loadSelectedSection();
    });
  }

  /// Fills the fields from the part that is open. Every write in this direction
  /// bumps [_fieldsEpoch].
  void _loadSelectedSection() {
    final section = _draft.section;
    _titleController.text = _draft.title;
    _sentenceController.text = _current.comment;
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
      _sentenceController.text = node.comment;
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
      _sentenceController.text = child.comment;
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
      _sentenceController.text = '';
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
            final boardSize = wide
                ? (constraints.maxWidth * 0.45)
                    .clamp(280.0, constraints.maxHeight - 120)
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SingleChildScrollView(child: board),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: SingleChildScrollView(child: _authoringColumn()),
                  ),
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

  /// Closes the part being written and opens the next one.
  ///
  /// It starts on the position this part's line ran out at — exactly the
  /// position the child's screen joins on, so show → ask happens on one board
  /// with no reset. Offering the other answer as well is D9 of
  /// `docs/PLAN-STUDIO-REDIZAJN.md` and lands with the section panel in P5.
  void _commitExample() {
    setState(() {
      _syncSelectedSection();
      _draft.addSection(
        continueFromEnd: true,
        title: 'Primer ${_draft.sections.length + 1}',
      );
      _sentenceController.text = '';
      _instructionController.text = '';
      _currentKind = LessonStepKind.show;
      for (final c in _choiceControllers) {
        c.dispose();
      }
      _choiceControllers.clear();
      _currentCorrectChoice = null;
      _currentSolutionSan = null;
      _boardController.loadFen(_root.fen);
      _lastMoveFrom = null;
      _lastMoveTo = null;
      _fieldsEpoch++;
    });
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
            context, 'Primer koji traži potez ne sme da ima liniju.');
        return;
      }
      if (section.kind == LessonStepKind.askChoice &&
          !section.choices.any((c) => c.correct)) {
        AppFeedback.error(
            context, 'Tačno jedan ponuđeni odgovor mora da bude tačan.');
        return;
      }
    }

    final error = await _lessonApi.save(
      title: _titleController.text.trim(),
      positionList: _draft.positionList,
    );

    if (!mounted) return;
    if (error == null) {
      AppFeedback.success(context, 'Tutorijal je sačuvan.');
    } else {
      AppFeedback.error(context, error);
    }
  }

  /// The tree of the part being written, and everything written *about* it.
  Widget _authoringColumn() {
    final written = _draft.sections.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('tutorial-title'),
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Naziv tutorijala'),
          // Written into the draft rather than only held in the controller.
          // The draft is what `TutorialDraftService` stores, so a title that
          // lives only here comes back empty next time — with every part
          // still in place, which is what made it invisible.
          onChanged: (value) {
            _draft.title = value;
            _persist();
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (written > 0) ...[
          Text('Primeri', style: AppText.bodyBold),
          for (int i = 0; i < written; i++) Text(_draft.sections[i].title),
          const SizedBox(height: AppSpacing.md),
        ],
        Text(_draft.section.title, style: AppText.bodyBold),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          key: const Key('example-sentence'),
          controller: _sentenceController,
          decoration:
              const InputDecoration(labelText: 'Komentar za trenutni potez'),
          onChanged: (val) {
            _current.comment = val;
            _persist();
          },
        ),
        const SizedBox(height: AppSpacing.sm),
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
            decoration: const InputDecoration(labelText: 'Zadatak za učenika'),
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
        const SizedBox(height: AppSpacing.md),
        TextButton(
          onPressed: _commitExample,
          child: const Text('+ Dodaj sledeću poziciju u tutorijal'),
        ),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          onPressed: _saveTutorial,
          child: const Text('Sačuvaj tutorijal'),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Linija ovog primera',
            style:
                AppText.bodyBold.copyWith(color: context.colors.textPrimary)),
        const SizedBox(height: AppSpacing.xs),
        AnalysisMoveTreeWidget(
          rootNode: _root,
          activeNode: _current,
          onSelectNode: _jumpTo,
        ),
      ],
    );
  }
}
