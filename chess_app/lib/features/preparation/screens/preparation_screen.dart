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
import 'dart:convert' show utf8;
import 'dart:io' show File, Platform;
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HardwareKeyboard;
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:go_router/go_router.dart';

import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
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
import 'package:chess_app/features/tutorial_studio/services/step_tree.dart';
import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/services/fen_legality.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/ai_studio/board_eval_widgets.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/board_overlay_painter.dart' show EngineArrow;
import 'package:chess_app/widgets/board_view_menu.dart';
import 'package:chess_app/widgets/board_with_coordinates.dart';
import 'package:chess_app/widgets/engine_settings_dialog.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_bar.dart';
import 'package:chess_app/widgets/game_screen/board_annotation_controller.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';
import 'package:chess_app/widgets/game_screen/move_keyboard_shortcuts.dart';
import 'package:chess_app/widgets/game_screen/move_navigation_controls.dart';
import 'package:chess_app/widgets/game_selector_dialog.dart';
import 'package:chess_app/widgets/landscape_board_layout.dart';
import 'package:chess_app/widgets/pgn_import_dialog.dart';
import 'package:chess_app/widgets/save_position_dialog.dart';
import 'package:chess_app/widgets/stockfish_analysis_widget.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

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
    super.dispose();
  }

  // ── the cursor, moves and the tree ────────────────────────────────────

  AnalysisNodeCursor _moveCursor() =>
      AnalysisNodeCursor(currentNode: _currentNode, onSelect: _jumpTo);

  void _jumpTo(AnalysisNode node) {
    setState(() {
      _currentNode = node;
      _boardController.loadFen(node.fen);
      _annotation.cancelPending();
    });
    _engine.triggerAnalysis(node.fen);
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
      _boardController.loadFen(played.fen);
      _annotation.cancelPending();
    });
    _engine.triggerAnalysis(played.fen);
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
    setState(() {
      final cursorFallsUnder = _isDescendantOf(_currentNode, node);
      parent.removeChild(node);
      if (cursorFallsUnder) {
        _currentNode = parent;
        _boardController.loadFen(parent.fen);
      }
    });
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
      _boardController.loadFen(root.fen);
      _annotation.cancelPending();
    });
    _engine.triggerAnalysis(root.fen);
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
      _boardController.loadFen(read.root.fen);
      _annotation.cancelPending();
    });
    _engine.triggerAnalysis(read.root.fen);
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
    showDialog<void>(
      context: context,
      builder: (_) => SavePositionDialog(
        availableUserLabels: labels,
        initialPersistedLabels: const [],
        initialShouldPersist: false,
        onSave: (title, description, tags, persist) =>
            _savePosition(title, description, tags),
      ),
    );
  }

  Future<void> _savePosition(
      String title, String description, List<String> tags) async {
    final error = await _lessonApi.save(
      title: title,
      description: description,
      tags: tags,
      fen: _currentNode.fen,
    );
    if (!mounted) return;
    if (error != null) {
      AppFeedback.error(context, error);
      return;
    }
    AppFeedback.success(context, 'Position saved.');
  }

  Future<void> _openMakeExerciseSheet() async {
    final pgn = PgnExporterService.exportToPgn(_currentNode);
    final parsed = MoveTree.parsePgn(pgn, startingFen: _currentNode.fen);
    if (parsed == null || parsed.rejectedMoves > 0) {
      final n = parsed?.rejectedMoves ?? 0;
      AppFeedback.error(context,
          '$n ${n == 1 ? 'move' : 'moves'} on this board could not be read back, so making an exercise of it would answer a different line than you built.');
      return;
    }
    final labels = await _userLabels();
    if (!mounted) return;
    final saved = await openMakeExerciseSheet(
      context,
      api: widget.exerciseApi ??
          ExerciseApiService(authToken: widget.userSession.token),
      moveTree: parsed,
      availableUserLabels: labels,
    );
    if (saved != null && mounted) {
      AppFeedback.success(context, 'Exercise saved.');
    }
  }

  /// The standard start with no move and no mark on it.
  bool get _boardIsBare =>
      _rootNode.children.isEmpty &&
      _rootNode.arrows.isEmpty &&
      _rootNode.squares.isEmpty &&
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
    _annotation.tap(
      square,
      arrows: _currentNode.arrows,
      squares: _currentNode.squares,
      asRange:
          _annotation.rangeMode || HardwareKeyboard.instance.isShiftPressed,
    );
    setState(() {});
  }

  void _clearMarks() {
    final changed = _annotation.clearMarks(
      arrows: _currentNode.arrows,
      squares: _currentNode.squares,
    );
    if (changed) setState(() {});
  }

  void _undoMark() {
    final squares = _currentNode.squares;
    final arrows = _currentNode.arrows;
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
    } else {
      AppFeedback.info(context, 'No mark to undo.');
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final wideBar = _wideBar;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: LandscapeBoardLayout.toolbarHeight(context),
        title: _activeParts == null
            ? const Text('Preparation', overflow: TextOverflow.ellipsis)
            : _partNavBar(),
        actions: [
          if (wideBar) ...[
            TextButton(
              key: const Key('prep-library'),
              onPressed: _toggleLibrary,
              child: const Text('Library'),
            ),
            PopupMenuButton<String>(
              key: const Key('prep-board-menu'),
              onSelected: _onMenuAction,
              itemBuilder: (_) => _boardMenuItems(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Board'),
              ),
            ),
            PopupMenuButton<String>(
              key: const Key('prep-save-menu'),
              onSelected: _onMenuAction,
              itemBuilder: (_) => _saveMenuItems(),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Save as…'),
              ),
            ),
            PopupMenuButton<String>(
              key: const Key('prep-more'),
              icon: const Icon(Icons.more_vert),
              tooltip: 'More',
              onSelected: _onMenuAction,
              itemBuilder: (_) => _moreMenuItems(full: false),
            ),
          ] else
            PopupMenuButton<String>(
              key: const Key('prep-more'),
              icon: const Icon(Icons.more_vert),
              tooltip: 'More',
              onSelected: _onMenuAction,
              itemBuilder: (_) => _moreMenuItems(full: true),
            ),
        ],
      ),
      body: MoveKeyboardShortcuts(
        cursor: _moveCursor(),
        onChanged: () {},
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final body = Size(constraints.maxWidth, constraints.maxHeight);
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
        arrows: _currentNode.arrows,
        squares: _currentNode.squares,
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

  String _commentLabel(AnalysisNode node) => node.isRoot
      ? 'Comment (select a move)'
      : 'Comment for ${node.moveNumberLabel}${node.moveSan}';

  Widget _commentPanel() {
    final node = _currentNode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(_commentLabel(node), style: AppText.bodyBold),
        const SizedBox(height: 4),
        _CommentField(
          key: ValueKey('prep-comment-${node.id}'),
          node: node,
          enabled: !node.isRoot,
          onChanged: (text) => setState(() => node.comment = text),
        ),
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
    required this.enabled,
    required this.onChanged,
  });

  final AnalysisNode node;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  State<_CommentField> createState() => _CommentFieldState();
}

class _CommentFieldState extends State<_CommentField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.node.comment);

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
