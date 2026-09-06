import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node_cursor.dart';
import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_handover.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_draft_service.dart';
import 'package:chess_app/models/user_session.dart';
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
/// 2383 lines and twelve actions of *analysing* — engine, explorer, tablebase,
/// motifs, game review — and every one of them is noise to somebody writing.
/// More concretely, the authoring flow needs a running list of examples on
/// screen at all times, and there is no room for it in a layout already
/// carrying a board, a move tree and an engine panel.
///
/// **What it holds, and nothing else:** the board, the move tree of the example
/// being written, the fields for the node the trainer is standing on, and the
/// running list of examples with one save at the end.
///
/// This is **the shell** — batch D, phase 4a. The board, the tree, the strip,
/// the door from the Studio and the draft are here; the per-node fields, the
/// running list and the single `POST /lessons/save` are batch E, and they go in
/// [_authoringColumn], beside the tree. Nothing on this screen talks to the
/// server yet, which is deliberate: decision 3 saves once, at the end, so a
/// tutorial abandoned halfway leaves nothing half-written in the library.
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
  });

  final UserSession session;

  /// The position — or the whole line — the Analysis Studio handed over.
  ///
  /// Null when the trainer opened the screen on its own, in which case the
  /// board starts on the position a game starts on and the draft they left last
  /// time comes back.
  final TutorialHandover? handover;

  @override
  State<TutorialStudioScreen> createState() => _TutorialStudioScreenState();
}

class _TutorialStudioScreenState extends State<TutorialStudioScreen> {
  static const String _startFen =
      'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  final ChessBoardController _boardController = ChessBoardController();

  late AnalysisNode _root;
  late AnalysisNode _current;
  TutorialDraft _draft = TutorialDraft();
  PlayerColor _orientation = PlayerColor.white;

  String? _lastMoveFrom;
  String? _lastMoveTo;

  @override
  void initState() {
    super.initState();
    final handover = widget.handover;
    _root = handover?.root ?? AnalysisNode(fen: _startFen);
    _current = _root;
    if (handover?.blackOrientation ?? false) _orientation = PlayerColor.black;
    _boardController.loadFen(_root.fen);
    unawaited(_restoreDraft());
  }

  @override
  void dispose() {
    // Flushed rather than left to the debounce: a pending timer dies with the
    // screen, and a draft that is only ever written 600 ms after the last move
    // is a draft that is never written when the trainer closes the window.
    unawaited(TutorialDraftService.instance.flush(
      draft: _draft,
      workingTree: _root,
      workingNode: _current,
      blackOrientation: _orientation == PlayerColor.black,
    ));
    super.dispose();
  }

  /// Brings back what was being written.
  ///
  /// A handover wins over the stored working tree — the trainer just said which
  /// position they want — but the examples already written come back either
  /// way, because that is the flow the door exists for: work the next example
  /// out in the Studio, hand it over, carry on with the same tutorial.
  Future<void> _restoreDraft() async {
    final restored = await TutorialDraftService.instance.load();
    if (!mounted || restored == null) return;

    setState(() {
      _draft = restored.draft;
      if (widget.handover == null) {
        _root = restored.workingTree;
        _current = restored.resolveWorkingNode();
        _orientation =
            restored.blackOrientation ? PlayerColor.black : PlayerColor.white;
        _boardController.loadFen(_current.fen);
      }
    });
  }

  void _persist() => TutorialDraftService.instance.scheduleSave(
        draft: _draft,
        workingTree: _root,
        workingNode: _current,
        blackOrientation: _orientation == PlayerColor.black,
      );

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
      _current = node;
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

    final child = _current.addChild(
      childFen: played.fen,
      san: played.san,
      uci: played.uci,
    );

    setState(() {
      _current = child;
      _boardController.loadFen(played.fen);
      _lastMoveFrom = from;
      _lastMoveTo = to;
    });
    _persist();
  }

  /// Starts the example over on [fen], with nothing written after it.
  void _startFrom(String fen) {
    setState(() {
      _root = AnalysisNode(fen: fen);
      _current = _root;
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
                  // lesson plan; the editor that writes them is batch E.
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

  /// The tree of the example being written — and, from batch E, everything
  /// written *about* it.
  ///
  /// What goes here next, in this order: the fields for the node the trainer is
  /// standing on (the sentence, the kind, the question, the choices — the same
  /// four `LessonStepEditorPanel` already edits), then the running list of
  /// Primer 1, Primer 2, … with „+ Dodaj sledeću poziciju u tutorijal" under it
  /// and one „Sačuvaj tutorijal" at the end. They belong beside the tree
  /// because that is the column that is read while writing; the board is the
  /// column that is played on.
  Widget _authoringColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
