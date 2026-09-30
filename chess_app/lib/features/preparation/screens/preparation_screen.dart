/// Preparation, as its own screen — phase 1 of `docs/PLAN-PRIPREMA.md`.
///
/// Built from what exists elsewhere in the app (see the gate's head comment,
/// `test/preparation_screen_test.dart`, for the full list): the board, the
/// marking bar, the move strip and cursor, the graphical/notation tree, the
/// engine's panel and the two evaluation bars, `LandscapeBoardLayout` for a
/// phone on its side, `playedMove` for a move on a position, and
/// `PreparationLayout` for where everything goes. On `AnalysisNode`. No
/// socket, no request — `test/preparation_screen_test.dart`'s „no server"
/// group and its own source guard hold that.
library;

import 'package:flutter/foundation.dart';
import 'dart:async' show unawaited;
import 'dart:convert' show utf8;
import 'dart:io' show Directory, File, Platform;
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';

import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/lessons/models/part_titles.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/features/position_scanner/services/scanner_api_service.dart';
import 'package:chess_app/features/position_scanner/widgets/side_to_move_gate.dart';
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/dialogs/analysis_studio_dialogs.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node.dart';
import 'package:chess_app/features/analysis_studio/models/analysis_node_cursor.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/analysis_studio/services/insert_line_as_variation.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_exporter_service.dart';
import 'package:chess_app/features/analysis_studio/services/pgn_import.dart';
import 'package:chess_app/features/analysis_studio/widgets/board_setup_dialog.dart';
import 'package:chess_app/features/analysis_studio/widgets/move_tree_widget.dart';
import 'package:chess_app/features/preparation/services/preparation_engine.dart';
import 'package:chess_app/features/preparation/services/preparation_layout.dart';
import 'package:chess_app/features/tutorial_studio/services/lesson_take.dart';
import 'package:chess_app/features/tutorial_studio/services/narration_take.dart'
    show
        NarrationStart,
        NarrationState,
        PcmSource,
        WavFileSink,
        narrationClockOf,
        narrationFallbackMaxMs;
import 'package:chess_app/features/tutorial_studio/services/record_pcm_source.dart';
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/fen_legality.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart' show EngineArrow;
import 'package:chess_app/widgets/bar_word_menu.dart';
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/engine_settings_dialog.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_bar.dart';
import 'package:chess_app/features/library/widgets/keep_board.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_controller.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/game_selector_dialog.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/pgn_import_dialog.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

/// Whether [a] and [b] draw exactly the same arrows and squares — asked when
/// opening another sentence, to tell whether the board actually changed
/// (D16 E of `docs/PLAN-PRIPREMA.md`).
bool _sameMarks(NodeBeat a, NodeBeat b) =>
    a.arrows.map((x) => x.toString()).join(',') ==
        b.arrows.map((x) => x.toString()).join(',') &&
    a.squares.map((x) => x.toString()).join(',') ==
        b.squares.map((x) => x.toString()).join(',');

class PreparationScreen extends StatefulWidget {
  const PreparationScreen({
    super.key,
    required this.userSession,
    this.initialFen,
    this.initialTree,
    this.engine,
    this.positionLibrary,
    this.lessonApi,
    this.scannerApi,
    this.exerciseApi,
    this.onOpenInAnalysis,
    this.lessonRecordingApi,
    this.pcmSourceFactory,
    this.lessonTakeDir,
  });

  final UserSession userSession;

  /// A position to open on. The starting position when neither this nor
  /// [initialTree] is given.
  final String? initialFen;

  /// A whole tree to open — variations, comments, arrows and squares as they
  /// are — with the cursor on its root. Wins over [initialFen].
  final AnalysisNode? initialTree;

  /// The engine's glue. Injected by a test, which has no engine to ask and
  /// needs to see what was asked of one; built by the screen otherwise.
  final PreparationEngine? engine;

  // The seams of phase 2 of `docs/PLAN-PRIPREMA.md`, fixed by the lead so
  // the gate (`test/preparation_material_test.dart`) compiles. Each is built
  // by the screen itself where it is not given.

  /// What the Library holds.
  final PositionLibraryService? positionLibrary;

  /// A tutorial's parts, and where „Position" is kept.
  final LessonApiService? lessonApi;

  /// Settles a side nobody set, before the position is used.
  final ScannerApiService? scannerApi;

  /// „Exercise…".
  final ExerciseApiService? exerciseApi;

  /// „Open in Analysis": handed a copy of the whole tree. The screen pushes
  /// Analysis itself when nothing is given.
  final void Function(AnalysisNode tree)? onOpenInAnalysis;

  // The seams of phase 3, fixed by the lead so the gate
  // (`test/preparation_recording_test.dart`) compiles. Named as the room's
  // are; each is built by the screen itself where it is not given.

  /// Whether this account may record and for how long, and the upload.
  final LessonRecordingApi? lessonRecordingApi;

  /// The microphone.
  final PcmSource Function()? pcmSourceFactory;

  /// Where a take is kept until the server has it.
  final Future<Directory> Function()? lessonTakeDir;

  @override
  State<PreparationScreen> createState() => _PreparationScreenState();
}

class _PreparationScreenState extends State<PreparationScreen>
    with SingleTickerProviderStateMixin {
  final ChessBoardController _boardController = ChessBoardController();
  final BoardAnnotationController _annotation = BoardAnnotationController();
  late final PreparationEngine _engine = widget.engine ?? PreparationEngine();
  late final TabController _phoneTabs = TabController(length: 4, vsync: this);
  late final LessonApiService _lessonApi =
      widget.lessonApi ?? LessonApiService(authToken: widget.userSession.token);
  late final PositionLibraryService _library = widget.positionLibrary ??
      PositionLibraryService(authToken: widget.userSession.token);

  late AnalysisNode _rootNode;
  late AnalysisNode _currentNode;

  /// Which of [_currentNode]'s beats is open — D4/D16 of
  /// `docs/PLAN-PRIPREMA.md`. Reset to 0 wherever the cursor moves to a
  /// different node.
  int _currentAt = 0;

  /// The cursor's open sentence — what the board draws and what a drawn mark
  /// or a recording's `arrow_drawn` goes to.
  NodeBeat get _openBeat =>
      _currentNode.beats[_currentAt.clamp(0, _currentNode.beats.length - 1)];

  PlayerColor _orientation = PlayerColor.white;

  // ── the Library's drawer (phase 2) ───────────────────────────────────
  bool _libraryOpen = false;
  bool _libraryLoading = false;
  bool _libraryFailed = false;
  List<LibraryEntry>? _libraryEntries;

  /// The labels this account has used, asked for the first time something
  /// needs them — the Library's filter, „Position", „Exercise…" — and not
  /// on arrival: the screen opens without a request. Null until answered.
  List<String>? _labels;

  Future<List<String>> _userLabels() async {
    final known = _labels;
    if (known != null) return known;
    final fetched = await _lessonApi.fetchLabels();
    if (mounted) setState(() => _labels = fetched);
    return fetched;
  }

  // ── a tutorial walked from the bar (D13) ─────────────────────────────
  List<Map<String, dynamic>>? _activeParts;
  int _activePartIndex = 0;

  ValueListenable<TickerModeData>? _shown;

  // ── recording a lesson here (phase 3) ────────────────────────────────
  /// The take while one is running, and where its file is. Null otherwise.
  LessonTake? _take;
  String? _takePath;

  @override
  void initState() {
    super.initState();
    final tree = widget.initialTree;
    final startFen = tree?.fen ?? widget.initialFen ?? _startFen;
    if (tree != null) {
      _rootNode = tree;
      _currentNode = tree;
    } else {
      _rootNode = AnalysisNode(fen: startFen);
      _currentNode = _rootNode;
    }
    _boardController.loadFen(_currentNode.fen);
    _engine.init();
    AppSettingsService.instance.addListener(_onAppSettingsChanged);
    _phoneTabs.addListener(_onPhoneTabChanged);
  }

  void _onAppSettingsChanged() {
    if (mounted) setState(() {});
  }

  void _onPhoneTabChanged() {
    if (mounted) setState(() {});
    if (_phoneTabs.index == 3 && _libraryEntries == null && !_libraryLoading) {
      _loadLibrary();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final shown = TickerMode.getValuesNotifier(context);
    if (!identical(shown, _shown)) {
      _shown?.removeListener(_onShownChanged);
      _shown = shown..addListener(_onShownChanged);
    }
  }

  /// Leaving this screen — a route over it, or `dispose` — switches the
  /// engine off and releases it, exactly as `AnalysisStudioScreen` does
  /// (`_onShownChanged`); coming back leaves it off until asked again.
  void _onShownChanged() {
    final shown = _shown?.value.enabled ?? true;
    if (shown) {
      _attachEngine();
      return;
    }
    if (_engine.isOn) {
      setState(_engine.reset);
    }
    _engine.detach();
  }

  void _attachEngine() {
    _engine.attach(
      getFen: () => _currentNode.fen,
      onRefused: (reason) {
        if (!mounted) return;
        AppFeedback.error(context, 'Engine cannot calculate: $reason');
      },
      onChanged: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _shown?.removeListener(_onShownChanged);
    _phoneTabs.removeListener(_onPhoneTabChanged);
    _phoneTabs.dispose();
    AppSettingsService.instance.removeListener(_onAppSettingsChanged);
    _engine.detach();
    // A take still open at this point was neither stopped nor discarded — the
    // pop guard makes that rare — and it is closed rather than left holding
    // its file.
    _take?.removeListener(_onTakeChanged);
    unawaited(_take?.cancel());
    super.dispose();
  }

  // ── the cursor, moves and the tree ────────────────────────────────────

  AnalysisNodeCursor _moveCursor() =>
      AnalysisNodeCursor(currentNode: _currentNode, onSelect: _jumpTo);

  void _jumpTo(AnalysisNode node) {
    setState(() {
      _currentNode = node;
      _currentAt = 0;
      _boardController.loadFen(node.fen);
      _annotation.cancelPending();
    });
    _engine.triggerAnalysis(node.fen);
    _stampMoveLanded(node);
  }

  /// Opens sentence [at] of [node] — the ‹ › that walk a position's
  /// sentences. Not a move and not a new part, so it stamps `arrow_drawn`
  /// when the sentence it opens draws something different from the one it
  /// left (D16 E of `docs/PLAN-PRIPREMA.md`).
  void _selectBeat(AnalysisNode node, int at) {
    final before = _openBeat;
    setState(() {
      _currentNode = node;
      _currentAt = at;
      _annotation.cancelPending();
    });
    if (!_sameMarks(before, _openBeat)) _stampArrowChange();
  }

  /// A fresh sentence after the open one, keeping its marks, and opens it.
  void _addSentence() {
    final node = _currentNode;
    final at = _currentAt.clamp(0, node.beats.length - 1);
    setState(() {
      node.addBeat(after: at, keepMarks: true);
      _currentAt = at + 1;
    });
  }

  /// Drops sentence [at] of [node], with an „Undo" — Preparation has no
  /// other undo (D16 C). False, and nothing removed, for a position's only
  /// sentence.
  bool _removeSentence(AnalysisNode node, int at) {
    final removed = node.beats[at].copy();
    final before = _openBeat;
    if (!node.removeBeatAt(at)) return false;
    setState(() {
      if (identical(node, _currentNode)) {
        _currentAt = at == 0 ? 0 : at - 1;
      }
    });
    // What is drawn changed as surely as if the trainer had cleared it, and a
    // take must see it (the recording's invariant).
    if (!_sameMarks(before, _openBeat)) _stampArrowChange();
    AppFeedback.show(
      context,
      () => SnackBar(
        content: const Text('Sentence removed.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            final shown = _openBeat;
            setState(() {
              node.beats.insert(at, removed);
              if (identical(node, _currentNode)) _currentAt = at;
            });
            if (!_sameMarks(shown, _openBeat)) _stampArrowChange();
          },
        ),
      ),
    );
    return true;
  }

  void _playMove(String from, String to, String promotion) {
    final played = playedMove(
      fen: _currentNode.fen,
      from: from,
      to: to,
      promotion: promotion,
    );
    if (played == null) {
      // Refused: the board reloads the position it had.
      setState(() => _boardController.loadFen(_currentNode.fen));
      return;
    }
    setState(() {
      _currentNode = _currentNode.addChild(
        childFen: played.fen,
        san: played.san,
        uci: played.uci,
      );
      _currentAt = 0;
      _boardController.loadFen(played.fen);
      _annotation.cancelPending();
    });
    _engine.triggerAnalysis(played.fen);
    _stampMovePlayed(_currentNode, from, to);
  }

  void _promoteNode(AnalysisNode node) {
    final parent = node.parent;
    if (parent == null) return;
    setState(() => parent.promoteToMainLine(node));
  }

  bool _isDescendantOf(AnalysisNode node, AnalysisNode ancestor) {
    AnalysisNode? n = node;
    while (n != null) {
      if (identical(n, ancestor)) return true;
      n = n.parent;
    }
    return false;
  }

  void _deleteNode(AnalysisNode node) {
    final parent = node.parent;
    if (parent == null) return;
    var cursorMoved = false;
    setState(() {
      final cursorFallsUnder = _isDescendantOf(_currentNode, node);
      parent.removeChild(node);
      if (cursorFallsUnder) {
        _currentNode = parent;
        _currentAt = 0;
        _boardController.loadFen(parent.fen);
        cursorMoved = true;
      }
    });
    // A deleted variation that took the cursor with it: the cursor lands on
    // the move already in the tree, exactly as the strip or the keyboard
    // would land it there.
    if (cursorMoved) _stampMoveLanded(parent);
  }

  void _moveVariation(AnalysisNode node, {required bool earlier}) {
    setState(() => node.parent?.moveVariation(node, earlier: earlier));
  }

  void _insertEngineLine(AnalysisLine line) {
    final result = insertLineAsVariation(_currentNode, line.continuationLan);
    setState(() {});
    if (result.added > 0) {
      AppFeedback.info(context, 'Moves added to variation: ${result.added}.');
    } else if (result.rejected) {
      AppFeedback.warning(context, 'Line does not match current position.');
    } else {
      AppFeedback.info(context, 'Line was already in the tree.');
    }
  }

  /// Puts [root] on the board as a new root: the cursor on it, no last move,
  /// no marks of the old one, a half-drawn arrow forgotten, the engine asked
  /// about the new position (D1). Whoever asks — the Library, „Board", an
  /// engine line's „load this position" — goes through this one function, so
  /// phase 3 has one place to stamp a recording's `init`.
  ///
  /// Closes a tutorial being walked from the bar: putting anything else on
  /// the board closes it (D13).
  void _setNewRoot(AnalysisNode root) {
    setState(() {
      _activeParts = null;
      _rootNode = root;
      _currentNode = root;
      _currentAt = 0;
      _boardController.loadFen(root.fen);
      _annotation.cancelPending();
    });
    _engine.triggerAnalysis(root.fen);
    _stampInit();
  }

  /// Loads [fen] as a new root, as the room does from an engine line's
  /// dialog.
  void _loadFenToMainBoard(String fen) => _setNewRoot(AnalysisNode(fen: fen));

  // ── a tutorial walked from the bar (D13) ─────────────────────────────

  void _loadTutorial(List<dynamic> steps) {
    _activeParts = [
      for (final s in steps) Map<String, dynamic>.from(s as Map),
    ];
    _loadPart(0);
  }

  /// One part with its own line — never the tutorial's whole PGN, which is
  /// D1's difference between a tutorial and a saved analysis.
  void _loadPart(int index) {
    final part = _activeParts![index];
    final read = readStepTree(
      fen: part['fen'] as String,
      pgn: part['pgn'] as String?,
    );
    setState(() {
      _activePartIndex = index;
      _rootNode = read.root;
      _currentNode = read.root;
      _currentAt = 0;
      _boardController.loadFen(read.root.fen);
      _annotation.cancelPending();
    });
    _engine.triggerAnalysis(read.root.fen);
    _stampInit();
    if (read.rejectedMoves > 0) {
      final n = read.rejectedMoves;
      AppFeedback.warning(context,
          '$n ${n == 1 ? 'move' : 'moves'} could not be played and ${n == 1 ? 'was' : 'were'} left out');
    }
  }

  void _nextPart() {
    final parts = _activeParts;
    if (parts != null && _activePartIndex + 1 < parts.length) {
      _loadPart(_activePartIndex + 1);
    }
  }

  void _prevPart() {
    if (_activeParts != null && _activePartIndex > 0) {
      _loadPart(_activePartIndex - 1);
    }
  }

  /// Leaves the board where it stands — closing does not put anything new on
  /// it.
  void _closePart() => setState(() => _activeParts = null);

  String _partLabel() {
    final parts = _activeParts!;
    final part = parts[_activePartIndex];
    final title = shownPartTitle(part['title']?.toString(), _activePartIndex);
    final base = 'Part ${_activePartIndex + 1} of ${parts.length}';
    return title == null ? base : '$base · $title';
  }

  Widget _partNavBar() {
    final parts = _activeParts!;
    return Row(
      children: [
        IconButton(
          key: const Key('prep-part-prev'),
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous part',
          onPressed: _activePartIndex > 0 ? _prevPart : null,
        ),
        // Flexible, not Expanded: the two arrows stand on either side of
        // the words they turn, not at the two ends of the bar.
        Flexible(
          child: Text(
            _partLabel(),
            key: const Key('prep-part-label'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          key: const Key('prep-part-next'),
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next part',
          onPressed: _activePartIndex + 1 < parts.length ? _nextPart : null,
        ),
        IconButton(
          key: const Key('prep-part-close'),
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: _closePart,
        ),
      ],
    );
  }

  // ── the Library's drawer ─────────────────────────────────────────────

  void _toggleLibrary() {
    final opening = !_libraryOpen;
    setState(() => _libraryOpen = opening);
    if (opening && _libraryEntries == null && !_libraryLoading) {
      _loadLibrary();
    }
  }

  void _closeLibrary() {
    if (_libraryOpen) setState(() => _libraryOpen = false);
  }

  Future<void> _loadLibrary() async {
    setState(() {
      _libraryLoading = true;
      _libraryFailed = false;
    });
    final items = await _library.list();
    if (!mounted) return;
    await _userLabels();
    if (!mounted) return;
    setState(() {
      _libraryLoading = false;
      if (items == null) {
        _libraryFailed = true;
      } else {
        _libraryEntries = items;
        _libraryFailed = false;
      }
    });
  }

  Widget _libraryContent({bool shrinkWrap = false}) {
    if (_libraryLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_libraryFailed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('The library could not be loaded.'),
            const SizedBox(height: 12),
            FilledButton(
                onPressed: _loadLibrary, child: const Text('Try again')),
          ],
        ),
      );
    }
    return LibraryList(
      entries: _libraryEntries ?? const [],
      onOpen: _putLibraryEntryOnBoard,
      labels: _labels ?? const [],
      shrinkWrap: shrinkWrap,
      chips: const [
        LibraryChip.all,
        LibraryChip.tutorials,
        LibraryChip.analyses,
        LibraryChip.exercises,
        LibraryChip.positions,
      ],
    );
  }

  Widget _libraryDrawer() {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeLibrary,
              child: Container(color: Colors.black54),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Material(
              key: const Key('prep-library-drawer'),
              elevation: 8,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SizedBox(
                width: 380,
                height: double.infinity,
                child: SafeArea(
                  top: false,
                  // `shrinkWrap` and a scrollable of the drawer's own — as
                  // the room's narrow column already does — rather than
                  // `LibraryList`'s own `Expanded` list, which needs more
                  // height than a chips-and-search header plus five
                  // board-thumbnail rows leaves it at this width.
                  child: (_libraryLoading || _libraryFailed)
                      ? _libraryContent()
                      : SingleChildScrollView(
                          child: _libraryContent(shrinkWrap: true),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// D1: what goes on the board, by what the entry is.
  Future<void> _putLibraryEntryOnBoard(LibraryEntry entry) async {
    switch (entry.kind) {
      case LibraryKind.tutorial:
        final id = int.tryParse(entry.id);
        final row = id == null ? null : await _lessonApi.fetchRow(id);
        if (row == null || !mounted) return;
        final steps = row['position_list'];
        if (steps is! List || steps.isEmpty) return;
        _closeLibrary();
        _loadTutorial(steps);
      case LibraryKind.analysis:
        final id = int.tryParse(entry.id);
        if (id == null) return;
        final root = await AnalysisPersistenceService.instance.loadAnalysis(
          id: id,
          userToken: widget.userSession.token,
        );
        if (root == null || !mounted) return;
        _closeLibrary();
        _setNewRoot(root);
      case LibraryKind.position:
      case LibraryKind.scan:
        if (!entry.needsReview) {
          _closeLibrary();
          _setNewRoot(AnalysisNode(fen: entry.fen));
          return;
        }
        final fen = await settledFen(
          context,
          api: widget.scannerApi ??
              ScannerApiService(authToken: widget.userSession.token),
          puzzleId: entry.id,
          fen: entry.fen,
          needsReview: entry.needsReview,
        );
        if (fen == null || !mounted) return;
        _closeLibrary();
        _setNewRoot(AnalysisNode(fen: fen));
      case LibraryKind.recording:
        // Never on this drawer's chips.
        break;
    }
  }

  // ── „Board ▾" ─────────────────────────────────────────────────────────

  void _openBoardSetupDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AnalysisBoardSetupDialog(
        initialFen: _currentNode.fen,
        onPositionSet: (fen) => _setNewRoot(AnalysisNode(fen: fen)),
      ),
    );
  }

  void _openFenPasteDialog() {
    showDialog<void>(
      context: context,
      builder: (_) =>
          _FenPasteDialog(onLoad: (fen) => _setNewRoot(AnalysisNode(fen: fen))),
    );
  }

  void _openPgnImportDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => PgnImportDialog(
        onPickFile: _pickPgnFile,
        onPasted: _handlePastedPgn,
      ),
    );
  }

  Future<void> _pickPgnFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pgn'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.single;
      String content;
      if (picked.bytes != null) {
        content = utf8.decode(picked.bytes!);
      } else if (picked.path != null) {
        content = await File(picked.path!).readAsString();
      } else {
        return;
      }
      if (!mounted) return;
      _handlePastedPgn(content);
    } catch (e) {
      if (mounted) AppFeedback.error(context, 'Error reading PGN file: $e');
    }
  }

  void _handlePastedPgn(String content) {
    final games = MoveTree.splitGames(content);
    if (games.isEmpty) {
      AppFeedback.error(
          context, 'Pasted text does not contain a valid PGN game.');
      return;
    }
    if (games.length == 1) {
      _loadPgnText(content);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (_) => GameSelectorDialog(
        games: games,
        onGameSelected: (game) => _loadPgnText(_rawTextOf(game)),
      ),
    );
  }

  String _rawTextOf(PgnGameInfo game) {
    final buf = StringBuffer();
    game.headers.forEach((k, v) => buf.writeln('[$k "$v"]'));
    buf.writeln();
    buf.write(game.pgnBody);
    return buf.toString();
  }

  void _loadPgnText(String text) {
    final import = readAnalysisPgn(text);
    if (import == null) {
      AppFeedback.error(
          context, 'Pasted text does not contain a valid PGN game.');
      return;
    }
    _setNewRoot(import.root);
  }

  // ── „Save as… ▾" ─────────────────────────────────────────────────────

  Future<void> _openSavePositionDialog() async {
    final labels = await _userLabels();
    if (!mounted) return;
    keepBoardAsPosition(
      context,
      api: _lessonApi,
      fen: _currentNode.fen,
      labels: labels,
    );
  }

  Future<void> _openMakeExerciseSheet() async {
    final labels = await _userLabels();
    if (!mounted) return;
    await keepBoardAsExercise(
      context,
      api: widget.exerciseApi ??
          ExerciseApiService(authToken: widget.userSession.token),
      from: _currentNode,
      labels: labels,
    );
  }

  /// The standard start with no move and no mark on it.
  bool get _boardIsBare =>
      _rootNode.children.isEmpty &&
      // Every sentence, not the first: a board whose only mark is on a later
      // one is not bare (phase 6).
      _rootNode.beats.every((b) => b.arrows.isEmpty && b.squares.isEmpty) &&
      _rootNode.fen == _startFen;

  Future<void> _saveAsAnalysis() async {
    if (_boardIsBare) {
      AppFeedback.error(context, 'There is nothing on this board to keep yet.');
      return;
    }
    await promptSaveAnalysisDialog(
      context,
      rootNode: _rootNode,
      userSession: widget.userSession,
    );
  }

  void _exportAsPgn() {
    if (_rootNode.children.isEmpty) {
      AppFeedback.error(
          context, 'There are no moves on this board to export yet.');
      return;
    }
    exportPgnDialog(
      context,
      PgnExporterService.exportToPgn(
        _rootNode,
        customHeaders: const {'Event': 'Preparation'},
      ),
      fileName: _preparationPgnFileName(DateTime.now()),
    );
  }

  static String _preparationPgnFileName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'preparation-${now.year}-${two(now.month)}-${two(now.day)}.pgn';
  }

  void _openInAnalysis() {
    final copy = copyTree(_rootNode);
    final onOpenInAnalysis = widget.onOpenInAnalysis;
    if (onOpenInAnalysis != null) {
      onOpenInAnalysis(copy);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AnalysisStudioScreen(
        userSession: widget.userSession,
        initialTree: copy,
      ),
    ));
  }

  void _onMenuAction(String value) {
    switch (value) {
      case 'board-setup':
        _openBoardSetupDialog();
      case 'board-fen':
        _openFenPasteDialog();
      case 'board-pgn':
        _openPgnImportDialog();
      case 'board-start':
        _setNewRoot(AnalysisNode(fen: _startFen));
      case 'save-position':
        _openSavePositionDialog();
      case 'save-exercise':
        _openMakeExerciseSheet();
      case 'save-analysis':
        _saveAsAnalysis();
      case 'save-pgn':
        _exportAsPgn();
      case 'open-analysis':
        _openInAnalysis();
      case 'settings':
        _openSettings();
      case 'part-prev':
        _prevPart();
      case 'part-next':
        _nextPart();
    }
  }

  List<PopupMenuEntry<String>> _boardMenuItems() => const [
        PopupMenuItem(
            key: Key('prep-board-setup'),
            value: 'board-setup',
            child: Text('Set up position…')),
        PopupMenuItem(
            key: Key('prep-board-fen'),
            value: 'board-fen',
            child: Text('Paste FEN…')),
        PopupMenuItem(
            key: Key('prep-board-pgn'),
            value: 'board-pgn',
            child: Text('Import PGN…')),
        PopupMenuItem(
            key: Key('prep-board-start'),
            value: 'board-start',
            child: Text('Starting position')),
      ];

  List<PopupMenuEntry<String>> _saveMenuItems() => const [
        PopupMenuItem(
            key: Key('prep-save-position'),
            value: 'save-position',
            child: Text('Position')),
        PopupMenuItem(
            key: Key('prep-save-exercise'),
            value: 'save-exercise',
            child: Text('Exercise…')),
        PopupMenuItem(
            key: Key('prep-save-analysis'),
            value: 'save-analysis',
            child: Text('Analysis')),
        PopupMenuItem(
            key: Key('prep-save-pgn'), value: 'save-pgn', child: Text('PGN')),
        PopupMenuItem(
            key: Key('prep-open-analysis'),
            value: 'open-analysis',
            child: Text('Open in Analysis')),
      ];

  /// The phone's single ⋮, both menus' items under their two headings, and
  /// „Settings" — [full] is false for the desktop/landscape „More", which
  /// only ever offers Settings there, the other two doors having buttons of
  /// their own.
  List<PopupMenuEntry<String>> _moreMenuItems({required bool full}) => [
        if (full) ...[
          const PopupMenuItem<String>(
              enabled: false, child: Text('Put on the board')),
          ..._boardMenuItems(),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
              enabled: false, child: Text('Keep what is on the board')),
          ..._saveMenuItems(),
          const PopupMenuDivider(),
        ],
        const PopupMenuItem<String>(value: 'settings', child: Text('Settings')),
      ];

  // ── marks ──────────────────────────────────────────────────────────────

  void _toggleArrowMode() {
    setState(() {
      if (_annotation.mode == AnnotationMode.arrow) {
        _annotation.stop();
      } else {
        _annotation.setMode(AnnotationMode.arrow);
      }
    });
  }

  void _toggleSquareMode() {
    setState(() {
      if (_annotation.mode == AnnotationMode.square) {
        _annotation.stop();
      } else {
        _annotation.setMode(AnnotationMode.square);
      }
    });
  }

  void _toggleRangeMode() {
    setState(() {
      _annotation.rangeMode = !_annotation.rangeMode;
      if (!_annotation.rangeMode) _annotation.pendingRangeFrom = null;
    });
  }

  void _selectColor(String code) {
    setState(() => _annotation.setColor(code));
  }

  void _onSquareTapForDrawing(String square) {
    // The first tap of an arrow changes neither list but must still repaint:
    // the board draws the square it will be drawn from, which is the only
    // thing telling the trainer their tap was heard.
    final changed = _annotation.tap(
      square,
      arrows: _openBeat.arrows,
      squares: _openBeat.squares,
      asRange:
          _annotation.rangeMode || HardwareKeyboard.instance.isShiftPressed,
    );
    setState(() {});
    if (changed) _stampArrowChange();
  }

  void _clearMarks() {
    final changed = _annotation.clearMarks(
      arrows: _openBeat.arrows,
      squares: _openBeat.squares,
    );
    if (changed) {
      setState(() {});
      _stampArrowChange();
    }
  }

  void _undoMark() {
    final squares = _openBeat.squares;
    final arrows = _openBeat.arrows;
    final squareFirst = _annotation.mode == AnnotationMode.square;
    var changed = squareFirst
        ? _annotation.undoLastSquare(squares)
        : _annotation.undoLastArrow(arrows);
    if (!changed) {
      changed = squareFirst
          ? _annotation.undoLastArrow(arrows)
          : _annotation.undoLastSquare(squares);
    }
    if (changed) {
      setState(() {});
      _stampArrowChange();
    } else {
      AppFeedback.info(context, 'No mark to undo.');
    }
  }

  // ── recording a lesson here (phase 3 of docs/PLAN-PRIPREMA.md) ───────
  //
  // Reused as it is from `docs/PLAN-SESIJA.md`'s phase 5b.3, the room's own
  // recording: `LessonTake`, `WavFileSink`, `RecordPcmSource`,
  // `narrationClockOf`, `narrationFallbackMaxMs` and `LessonRecordingApi`.
  // The order is the room's and it is the point: the server is asked first
  // (`permit()`), a refusal is said and the microphone is never opened; then
  // the file, then the microphone.
  //
  // The timeline is stamped from the one place each kind of change already
  // goes through — `_setNewRoot` and `_loadPart` for a new board (`init`),
  // `_jumpTo` and `_deleteNode`'s fallback for the cursor landing on a move
  // already in the tree (`move`), `_playMove` for a move played (`move`), and
  // the three functions above that change what is drawn on the board
  // (`arrow_drawn`) — so a door added later that goes through one of them
  // cannot forget to stamp it.

  LessonRecordingApi get _lessonRecordingApi =>
      widget.lessonRecordingApi ??
      LessonRecordingApi(authToken: widget.userSession.token);

  /// True from a tap on „Record" until the take exists or was refused.
  bool _preparingTake = false;

  bool get _isRecordingLesson =>
      _take != null && _take!.state != NarrationState.stopped;

  /// Stamps a board event on the take, at this point in the audio. A no-op
  /// while nothing is being recorded, which is what lets every door onto the
  /// board call it without asking first.
  void _markLesson(String type, Map<String, dynamic> data) {
    _take?.mark(type, data);
  }

  Map<String, dynamic> _marksOf(AnalysisNode node) => {
        if (node.arrows.isNotEmpty)
          'arrows': [
            for (final a in node.arrows)
              {'from': a.from, 'to': a.to, 'color': a.colorCode},
          ],
        if (node.squares.isNotEmpty)
          'squares': [
            for (final s in node.squares)
              {'square': s.square, 'color': s.colorCode},
          ],
      };

  /// The board as it stands: the cursor's own position, the whole tree under
  /// the root as PGN, and the cursor's own marks where it has any. Used both
  /// for the `init` event `_startLessonRecording` opens a take with, and for
  /// every `init` stamped afterwards — `_setNewRoot` and `_loadPart` always
  /// leave the cursor on the root they just put on the board, so the same
  /// snapshot answers both without asking twice what „the board" means.
  Map<String, dynamic> _boardSnapshot() => {
        'fen': _currentNode.fen,
        'pgn': PgnExporterService.exportToPgn(_rootNode),
        ..._marksOf(_currentNode),
      };

  void _stampInit() => _markLesson('init', _boardSnapshot());

  void _stampMoveLanded(AnalysisNode node) =>
      _markLesson('move', {'fen': node.fen, ..._marksOf(node)});

  void _stampMovePlayed(AnalysisNode node, String from, String to) =>
      _markLesson(
          'move', {'fen': node.fen, 'from': from, 'to': to, ..._marksOf(node)});

  /// Every change of the marks on the board in front of the trainer — drawn,
  /// removed, „Undo", „Clear" — writes both lists whole, always, so the
  /// player never has to guess which one changed.
  void _stampArrowChange() => _markLesson('arrow_drawn', {
        'arrows': [
          for (final a in _openBeat.arrows)
            {'from': a.from, 'to': a.to, 'color': a.colorCode},
        ],
        'squares': [
          for (final s in _openBeat.squares)
            {'square': s.square, 'color': s.colorCode},
        ],
      });

  void _onTakeChanged() {
    if (mounted) setState(() {});
  }

  Future<Directory> _defaultLessonTakeDir() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}lessons');
  }

  /// Asks the server first — whether this account may record, and for how
  /// long — and only then opens the microphone. A refusal said after half an
  /// hour of talking is the one this order exists to prevent.
  Future<void> _startLessonRecording() async {
    // The take does not exist until the server has answered and its folder
    // is known, so a second tap in that time is refused by this and not by
    // the take.
    if (_take != null || _preparingTake) return;
    _preparingTake = true;
    final LessonTake take;
    try {
      final permit = await _lessonRecordingApi.permit();
      if (!mounted) return;
      if (!permit.allowed) {
        AppFeedback.warning(context, permit.reason ?? 'You may not record.');
        return;
      }
      final dir = await (widget.lessonTakeDir ?? _defaultLessonTakeDir)();
      if (!mounted) return;
      dir.createSync(recursive: true);
      final path = '${dir.path}${Platform.pathSeparator}'
          'lesson-${DateTime.now().millisecondsSinceEpoch}.wav';
      take = LessonTake(
        source: (widget.pcmSourceFactory ?? RecordPcmSource.new)(),
        sink: WavFileSink(path),
        maxMs: permit.maxMs ?? narrationFallbackMaxMs,
      )..addListener(_onTakeChanged);
      setState(() {
        _take = take;
        _takePath = path;
      });
    } finally {
      _preparingTake = false;
    }
    unawaited(take.done.then(_onTakeDone));
    final NarrationStart started;
    try {
      started = await take.start(opening: _boardSnapshot());
    } catch (e) {
      _forgetTake();
      if (mounted) {
        AppFeedback.error(context, 'The microphone could not start: $e');
      }
      return;
    }
    if (!mounted) return;
    if (started == NarrationStart.noPermission) {
      _forgetTake();
      AppFeedback.warning(context,
          'The app may not use the microphone. Allow it in the system settings.');
    }
  }

  void _forgetTake() {
    _take?.removeListener(_onTakeChanged);
    final path = _takePath;
    if (mounted) {
      setState(() {
        _take = null;
        _takePath = null;
      });
    } else {
      _take = null;
      _takePath = null;
    }
    if (path != null) {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    }
  }

  /// Whatever ended the take — Stop, the cap, or Discard (null).
  Future<void> _onTakeDone(LessonRecording? recording) async {
    if (!mounted) return;
    final path = _takePath;
    if (recording == null || path == null) {
      _forgetTake();
      return;
    }
    if (recording.stoppedAtCap) {
      AppFeedback.info(context,
          'Recording stopped at the limit of one recording. It is kept.');
    }
    final title = await _askLessonTitle();
    if (!mounted) return;
    if (title == null) {
      _forgetTake();
      return;
    }
    await _uploadLesson(recording, path, title);
  }

  Future<String?> _askLessonTitle() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Save the recording'),
        content: TextField(
          key: const Key('lesson-title-field'),
          controller: controller,
          autofocus: true,
          maxLength: 255,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Discard'),
          ),
          ElevatedButton(
            key: const Key('lesson-save'),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.pop(ctx, text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Sends the take, and keeps it on this device until the server says 201 —
  /// it is the only copy of a voice.
  Future<void> _uploadLesson(
      LessonRecording recording, String path, String title) async {
    while (mounted) {
      final result = await _lessonRecordingApi.upload(
        audioPath: path,
        title: title,
        events: recording.events,
        durationMs: recording.durationMs,
      );
      if (!mounted) return;
      if (result.ok) {
        _forgetTake();
        AppFeedback.success(
            context, 'Recording saved. It is under Recordings.');
        return;
      }
      final again = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('The recording was not saved'),
          content: Text(result.error ?? 'The recording could not be uploaded.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Discard'),
            ),
            ElevatedButton(
              key: const Key('lesson-upload-retry'),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
      if (again != true) {
        _forgetTake();
        return;
      }
    }
  }

  /// The clock (and, in its last minute, „N s left") beside a shape that is
  /// not only a colour — the owner is colourblind — a dot recording, bars
  /// paused. The same widget sits in the bar's actions on the wide bar and
  /// takes over the title on a phone held upright, where 360 px hold either
  /// it or a tutorial's part label, not both.
  Widget _recordingIndicator() {
    final take = _take!;
    final colors = context.colors;
    final paused = take.state == NarrationState.paused;
    final remaining = take.remainingMs;
    return Row(
      key: const Key('prep-recording'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(paused ? Icons.pause : Icons.fiber_manual_record,
            color: colors.danger, size: 16),
        const SizedBox(width: AppSpacing.xs),
        Text(narrationClockOf(take.positionMs),
            style: AppText.bodyBold.copyWith(color: colors.danger)),
        if (remaining < 60000) ...[
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              '${(remaining / 1000).ceil().clamp(0, 60)} s left',
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(color: colors.warning),
            ),
          ),
        ],
      ],
    );
  }

  /// The three things a trainer may do to a running take, at every width.
  List<Widget> _recordingControls() {
    final take = _take!;
    final paused = take.state == NarrationState.paused;
    final colors = context.colors;
    return [
      IconButton(
        key: const Key('lesson-recording-pause'),
        icon: Icon(paused ? Icons.play_arrow : Icons.pause),
        tooltip: paused ? 'Resume' : 'Pause',
        onPressed: paused ? take.resume : take.pause,
      ),
      IconButton(
        key: const Key('lesson-recording-stop'),
        icon: Icon(Icons.stop, color: colors.danger),
        tooltip: 'Stop and save',
        onPressed: take.stop,
      ),
      IconButton(
        key: const Key('lesson-recording-discard'),
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Discard',
        onPressed: take.cancel,
      ),
    ];
  }

  /// ⋮ while a take runs: what puts something on the board, and nothing that
  /// keeps — „Save as…" and its five doors give way while a lesson is being
  /// recorded. A tutorial's part is walked from here too where 360 px do not
  /// hold both it and the recording's own clock in the title.
  List<PopupMenuEntry<String>> _recordingMoreMenuItems() => [
        ..._boardMenuItems(),
        if (_activeParts != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem<String>(
            key: const Key('prep-part-prev'),
            value: 'part-prev',
            enabled: _activePartIndex > 0,
            child: const Text('Previous part'),
          ),
          PopupMenuItem<String>(
            key: const Key('prep-part-next'),
            value: 'part-next',
            enabled: _activePartIndex + 1 < _activeParts!.length,
            child: const Text('Next part'),
          ),
        ],
      ];

  // ── the shape ─────────────────────────────────────────────────────────

  Future<void> _openSettings() async {
    await context.push(AppRoutes.preferences);
    if (mounted) setState(() {});
  }

  /// The desktop window and a phone on its side get the bar's own doors
  /// (D11); a phone held upright puts the Library on a tab and both menus
  /// behind one ⋮ (§4, D13 — narrower than 840, and never landscape's own
  /// board-and-panels rule, which is what phase 1's tests already pump).
  bool get _wideBar => Breakpoints.isWide(context);

  Widget _barTitle(bool wideBar, bool recording) {
    if (recording && !wideBar) return _recordingIndicator();
    if (_activeParts != null) return _partNavBar();
    return const Text('Preparation', overflow: TextOverflow.ellipsis);
  }

  List<Widget> _barActions(bool wideBar, bool recording) {
    if (!recording) {
      if (wideBar) {
        return [
          TextButton(
            key: const Key('prep-library'),
            onPressed: _toggleLibrary,
            child: const Text('Library'),
          ),
          BarWordMenu<String>(
            key: const Key('prep-board-menu'),
            word: 'Board',
            onSelected: _onMenuAction,
            itemBuilder: (_) => _boardMenuItems(),
          ),
          BarWordMenu<String>(
            key: const Key('prep-save-menu'),
            word: 'Save as…',
            onSelected: _onMenuAction,
            itemBuilder: (_) => _saveMenuItems(),
          ),
          TextButton(
            key: const Key('prep-record'),
            // `ThemeData.adaptivePlatformDensity` is compact on every
            // desktop, which shaves 8 dp off a button's minimum height —
            // measured `108.6x36` at `minimumSize: Size(48, 44)`, so the
            // asked-for height allows for it.
            style: TextButton.styleFrom(minimumSize: const Size(48, 52)),
            onPressed: _startLessonRecording,
            child: const Text('Record'),
          ),
          PopupMenuButton<String>(
            key: const Key('prep-more'),
            icon: const Icon(Icons.more_vert),
            tooltip: 'More',
            onSelected: _onMenuAction,
            itemBuilder: (_) => _moreMenuItems(full: false),
          ),
        ];
      }
      return [
        IconButton(
          key: const Key('prep-record'),
          icon: const Icon(Icons.fiber_manual_record),
          tooltip: 'Record',
          onPressed: _startLessonRecording,
        ),
        PopupMenuButton<String>(
          key: const Key('prep-more'),
          icon: const Icon(Icons.more_vert),
          tooltip: 'More',
          onSelected: _onMenuAction,
          itemBuilder: (_) => _moreMenuItems(full: true),
        ),
      ];
    }

    // D11: while a take runs, „Save as…" and ⋮ give way on the wide bar —
    // „Library" and „Board" stay, because a position loaded in mid-recording
    // is part of the recording. On the narrow bar ⋮ stays and holds only what
    // puts something on the board.
    if (wideBar) {
      return [
        TextButton(
          key: const Key('prep-library'),
          onPressed: _toggleLibrary,
          child: const Text('Library'),
        ),
        BarWordMenu<String>(
          key: const Key('prep-board-menu'),
          word: 'Board',
          onSelected: _onMenuAction,
          itemBuilder: (_) => _boardMenuItems(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: _recordingIndicator(),
        ),
        ..._recordingControls(),
      ];
    }
    return [
      ..._recordingControls(),
      PopupMenuButton<String>(
        key: const Key('prep-more'),
        icon: const Icon(Icons.more_vert),
        tooltip: 'More',
        onSelected: _onMenuAction,
        itemBuilder: (_) => _recordingMoreMenuItems(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final wideBar = _wideBar;
    final recording = _isRecordingLesson;
    // A lesson being recorded is the only copy of a voice: leaving would drop
    // it without a word. The way out is Stop (which saves) or Discard.
    return PopScope(
      canPop: !recording,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        AppFeedback.warning(context, 'Stop or discard the recording first.');
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
          title: _barTitle(wideBar, recording),
          actions: _barActions(wideBar, recording),
        ),
        body: MoveKeyboardShortcuts(
          cursor: _moveCursor(),
          onChanged: () {},
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final body =
                      Size(constraints.maxWidth, constraints.maxHeight);
                  if (LandscapeBoardLayout.applies(context)) {
                    return _buildLandscape(body);
                  }
                  if (Breakpoints.isWide(context)) return _buildDesktop(body);
                  return _buildPhone(body);
                },
              ),
              if (wideBar && _libraryOpen) _libraryDrawer(),
            ],
          ),
        ),
      ),
    );
  }

  // ── shared pieces ────────────────────────────────────────────────────

  Widget _boardWidget(double size) {
    return BoardWithCoordinates(
      size: size,
      orientation: _orientation,
      builder: (boardSize) => ChessBoardWithOverlay(
        controller: _boardController,
        boardOrientation: _orientation,
        boardSize: boardSize,
        isAllowedToMove: true,
        isDrawingMode: _annotation.isDrawing,
        drawingStartSquare: _annotation.pendingFrom,
        arrows: _openBeat.arrows,
        squares: _openBeat.squares,
        engineArrows: _engineArrows(),
        lastMoveFrom: _lastMoveFrom,
        lastMoveTo: _lastMoveTo,
        onMove: _playMove,
        onSquareTapForDrawing: _onSquareTapForDrawing,
      ),
    );
  }

  String? get _lastMoveFrom {
    final uci = _currentNode.moveUci;
    return uci != null && uci.length >= 4 ? uci.substring(0, 2) : null;
  }

  String? get _lastMoveTo {
    final uci = _currentNode.moveUci;
    return uci != null && uci.length >= 4 ? uci.substring(2, 4) : null;
  }

  List<EngineArrow> _engineArrows() {
    if (!AppSettingsService.instance.showEngineArrows || !_engine.isOn) {
      return const [];
    }
    return [
      for (final line in _engine.lines.values)
        if (line.bestMoveLan.length >= 4)
          EngineArrow(
            from: line.bestMoveLan.substring(0, 2),
            to: line.bestMoveLan.substring(2, 4),
            evalText: line.evaluation,
            rank: line.multipv,
          ),
    ];
  }

  Widget _marksWidget(MarkingDensity density) {
    return BoardAnnotationBar(
      mode: _annotation.mode,
      selectedColorCode: _annotation.colorCode,
      onArrowPressed: _toggleArrowMode,
      onSquarePressed: _toggleSquareMode,
      onColorSelected: _selectColor,
      onClearPressed: _clearMarks,
      rangeMode: _annotation.rangeMode,
      onRangePressed: _toggleRangeMode,
      density: density,
      onUndoPressed: _undoMark,
    );
  }

  Widget _stripWidget() {
    return MoveNavigationControls(
      cursor: _moveCursor(),
      dense: true,
      onFlipBoard: () => setState(() {
        _orientation = _orientation == PlayerColor.white
            ? PlayerColor.black
            : PlayerColor.white;
      }),
      trailing: const [BoardViewMenu(arrows: true, boardSize: true)],
    );
  }

  Widget _treeWidget({required bool startOnGraph, bool fills = false}) {
    return AnalysisMoveTreeWidget(
      fills: fills,
      rootNode: _rootNode,
      activeNode: _currentNode,
      onSelectNode: _jumpTo,
      onPromoteNode: _promoteNode,
      onDeleteNode: _deleteNode,
      onMoveVariation: _moveVariation,
      startOnGraph: startOnGraph,
    );
  }

  String _commentLabel(AnalysisNode node, int at, int of) {
    final base = node.isRoot
        ? 'Comment (select a move)'
        : 'Comment for ${node.moveNumberLabel}${node.moveSan}';
    return of > 1 ? '$base · sentence ${at + 1} of $of' : base;
  }

  Widget _commentPanel() {
    final node = _currentNode;
    final isRoot = node.isRoot;
    final at = _currentAt.clamp(0, node.beats.length - 1);
    final of = node.beats.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(_commentLabel(node, at, of), style: AppText.bodyBold),
            ),
            // Nothing is added on the starting position, whose comment is
            // switched off here as today (D16 E).
            if (!isRoot && of > 1) ...[
              IconButton(
                key: const Key('prep-sentence-prev'),
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Previous sentence',
                visualDensity: VisualDensity.compact,
                onPressed: at > 0 ? () => _selectBeat(node, at - 1) : null,
              ),
              IconButton(
                key: const Key('prep-sentence-next'),
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Next sentence',
                visualDensity: VisualDensity.compact,
                onPressed: at < of - 1 ? () => _selectBeat(node, at + 1) : null,
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        _CommentField(
          key: ObjectKey(node.beats[at]),
          node: node,
          at: at,
          enabled: !isRoot,
          onChanged: (text) => setState(() => node.beats[at].comment = text),
        ),
        if (!isRoot) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton(
                key: const Key('prep-add-sentence'),
                onPressed: _addSentence,
                child: const Text('Add a sentence here'),
              ),
              if (of > 1)
                OutlinedButton(
                  key: const Key('prep-remove-sentence'),
                  onPressed: () => _removeSentence(node, at),
                  child: const Text('Remove this sentence'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  List<AnalysisLine> _sortedEngineLines() {
    final keys = _engine.lines.keys.toList()..sort();
    return [for (final k in keys) _engine.lines[k]!];
  }

  /// [dials] is false only where the room's dials add height a box this
  /// small does not have (D11's stacked comment-and-engine, 900 wide): the
  /// same two controls are still reached through [_openEngineSettingsDialog]
  /// on Windows, so nothing here is unreachable, only not inline.
  Widget _enginePanel({bool dials = true}) {
    return StockfishAnalysisWidget(
      isEngineEnabled: _engine.showEvaluation,
      isAllowedToUseEngine: true,
      isOnline: _engine.isOnline,
      isCustomEngineActive: _engine.isCustomEngineActive,
      lines: _sortedEngineLines(),
      orientation: _orientation,
      analysisDepth: dials ? _engine.analysisDepth : null,
      analysisLines: dials ? _engine.analysisLines : null,
      onAnalysisDepthChanged: (value) {
        _engine.setAnalysisDepth(value);
        _engine.triggerAnalysis(_currentNode.fen);
        setState(() {});
      },
      onAnalysisLinesChanged: (value) {
        _engine.setAnalysisLines(value);
        _engine.triggerAnalysis(_currentNode.fen);
        setState(() {});
      },
      onToggleEngine: () {
        setState(() => _engine.showEvaluation = !_engine.showEvaluation);
        _engine.triggerAnalysis(_currentNode.fen);
      },
      isShowEvalBarEnabled: _engine.showEvalBar,
      onToggleShowEvalBar: () {
        setState(() => _engine.showEvalBar = !_engine.showEvalBar);
        _engine.triggerAnalysis(_currentNode.fen);
      },
      onOpenSettings:
          (!kIsWeb && Platform.isWindows) ? _openEngineSettingsDialog : null,
      onForceRestart: () {
        _engine.stopNow();
        _engine.triggerAnalysis(_currentNode.fen);
      },
      onLoadFenToMainBoard: _loadFenToMainBoard,
      onInsertLineAsVariation: _insertEngineLine,
    );
  }

  Future<void> _openEngineSettingsDialog() async {
    if (!mounted) return;
    await showEngineSettingsDialog(
      context,
      stockfishService: _engine.service,
      isEngineEnabled: _engine.isOn,
    );
    if (mounted) setState(() {});
  }

  // ── a desktop window (D11) ───────────────────────────────────────────

  Widget _buildDesktop(Size body) {
    final layout = PreparationLayout.desktop(
      body,
      scale: AppSettingsService.instance.boardSizeScale,
    );
    final boardColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: layout.board,
          height: layout.board,
          child: _boardWidget(layout.board),
        ),
        const SizedBox(height: PreparationLayout.rowGap),
        SizedBox(width: layout.board, child: _marksWidget(layout.marks)),
        const SizedBox(height: PreparationLayout.rowGap),
        SizedBox(width: layout.board, child: _stripWidget()),
      ],
    );

    final evalSlot = SizedBox(
      width: PreparationLayout.evalBar,
      height: layout.board,
      child: _engine.showEvalBar
          ? VerticalEvalBarWidget(
              eval: _engine.eval,
              evalString: _engine.evalString,
              depth: _engine.evalDepth,
              height: layout.board,
              orientation: _orientation,
            )
          : null,
    );

    // Each in a box of its own height, scrolling inside it: an engine with
    // three lines to show is taller than its place, and what does not fit
    // scrolls in its own panel rather than moving the tree or the board.
    Widget boxed(Widget child, {Key? key}) => KeyedSubtree(
          key: key,
          child: SingleChildScrollView(child: child),
        );
    final commentAndEngine = layout.commentBesideEngine
        ? SizedBox(
            height: PreparationLayout.underTreeBeside,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: boxed(_commentPanel())),
                const SizedBox(width: PreparationLayout.gap),
                Expanded(
                  child:
                      boxed(_enginePanel(), key: const Key('prep-engine-box')),
                ),
              ],
            ),
          )
        : SizedBox(
            height: PreparationLayout.underTreeStacked,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: PreparationLayout.commentAlone,
                  child: boxed(_commentPanel()),
                ),
                const SizedBox(height: PreparationLayout.gap),
                Expanded(
                  child:
                      boxed(_enginePanel(), key: const Key('prep-engine-box')),
                ),
              ],
            ),
          );

    // The pane is as tall as the body lets it be, and the tree takes what the
    // comment and the engine leave: nothing here is behind a tab, and nothing
    // is pushed off the window (D11).
    final pane = SizedBox(
      width: layout.paneWidth,
      height: math.max(0.0, body.height - 2 * PreparationLayout.padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _treeWidget(startOnGraph: true, fills: true)),
          const SizedBox(height: PreparationLayout.gap),
          commentAndEngine,
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(PreparationLayout.padding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          evalSlot,
          const SizedBox(width: PreparationLayout.evalGap),
          boardColumn,
          const SizedBox(width: PreparationLayout.gap),
          pane,
        ],
      ),
    );
  }

  // ── a phone held upright ─────────────────────────────────────────────

  Widget _buildPhone(Size body) {
    final layout = PreparationLayout.phone(
      body,
      scale: AppSettingsService.instance.boardSizeScale,
    );
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(PreparationLayout.padding),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_engine.showEvalBar)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: PreparationLayout.rowGap),
                    child: SizedBox(
                      width: layout.board,
                      child: HorizontalEvalBarWidget(
                        eval: _engine.eval,
                        evalString: _engine.evalString,
                        depth: _engine.evalDepth,
                        orientation: _orientation,
                      ),
                    ),
                  ),
                SizedBox(
                  width: layout.board,
                  height: layout.board,
                  child: _boardWidget(layout.board),
                ),
                const SizedBox(height: PreparationLayout.rowGap),
                SizedBox(
                    width: layout.board, child: _marksWidget(layout.marks)),
                const SizedBox(height: PreparationLayout.rowGap),
                SizedBox(width: layout.board, child: _stripWidget()),
              ],
            ),
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _PinnedPhoneTabs(child: _phoneTabBar()),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(PreparationLayout.padding),
          sliver: SliverToBoxAdapter(child: _phoneTabContent()),
        ),
      ],
    );
  }

  Widget _phoneTabBar() {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: TabBar(
        controller: _phoneTabs,
        // Four fixed tabs share the phone's width; the default 16 a side
        // left 58 px for a word, and „Comment" read „Commen".
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        tabs: const [
          Tab(text: 'Tree'),
          Tab(text: 'Comment'),
          Tab(text: 'Engine'),
          Tab(text: 'Library'),
        ],
      ),
    );
  }

  Widget _phoneTabContent() {
    return switch (_phoneTabs.index) {
      0 => _treeWidget(startOnGraph: false),
      1 => _commentPanel(),
      2 => _enginePanel(),
      _ => _libraryContent(shrinkWrap: true),
    };
  }

  // ── a phone held on its side ─────────────────────────────────────────

  Widget _buildLandscape(Size body) {
    return LandscapeBoardLayout(
      boardScale: AppSettingsService.instance.boardSizeScale,
      board: _boardWidget,
      boardAside: (height) => _engine.showEvalBar
          ? VerticalEvalBarWidget(
              eval: _engine.eval,
              evalString: _engine.evalString,
              depth: _engine.evalDepth,
              height: height,
              orientation: _orientation,
            )
          : const SizedBox.shrink(),
      header: _phoneTabBar(),
      panels: _phoneTabContent(),
      footer: [
        _marksWidget(
            PreparationLayout.marksFor(LandscapeBoardLayout.minPanelWidth)),
        _stripWidget(),
      ],
    );
  }
}

class _PinnedPhoneTabs extends SliverPersistentHeaderDelegate {
  const _PinnedPhoneTabs({required this.child});

  final Widget child;

  static const double _extent = 48;

  @override
  double get minExtent => _extent;

  @override
  double get maxExtent => _extent;

  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      child;

  @override
  bool shouldRebuild(_PinnedPhoneTabs oldDelegate) =>
      oldDelegate.child != child;
}

/// The comment's `TextField` — a `StatefulWidget` so its controller belongs to
/// the node it was seeded from rather than to a `build()` that runs again
/// under the caret. Keyed by the node's id at the call site, so a new node
/// gets a fresh instance rather than this one's text.
class _CommentField extends StatefulWidget {
  const _CommentField({
    super.key,
    required this.node,
    required this.at,
    required this.enabled,
    required this.onChanged,
  });

  final AnalysisNode node;

  /// Which of [node]'s beats this field is about.
  final int at;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_CommentField> createState() => _CommentFieldState();
}

class _CommentFieldState extends State<_CommentField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.node.beats[widget.at].comment);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('prep-comment'),
      controller: _controller,
      enabled: widget.enabled,
      minLines: 2,
      maxLines: 4,
      decoration: const InputDecoration(
        isDense: true,
        border: OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}

/// „Paste FEN…": a trimmed position, refused with [fenIllegalReason]'s own
/// sentence, staying open until it is given one it can use.
class _FenPasteDialog extends StatefulWidget {
  const _FenPasteDialog({required this.onLoad});

  final ValueChanged<String> onLoad;

  @override
  State<_FenPasteDialog> createState() => _FenPasteDialogState();
}

class _FenPasteDialogState extends State<_FenPasteDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final fen = _controller.text.trim();
    final reason = fenIllegalReason(fen);
    if (reason != null) {
      setState(() => _error = reason);
      return;
    }
    Navigator.pop(context);
    widget.onLoad(fen);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Paste a position (FEN)'),
      content: TextField(
        key: const Key('prep-fen-field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Load'),
        ),
      ],
    );
  }
}
