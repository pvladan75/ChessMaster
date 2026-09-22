import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/core/services/local_puzzle_extractor_service.dart';
import 'package:chess_app/core/services/puzzle_set_api_service.dart';
import 'package:chess_app/core/services/puzzle_set_repository.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/exercises/models/exercise.dart';
import 'package:chess_app/features/exercises/screens/exercise_editor_screen.dart';
import 'package:chess_app/features/exercises/services/exercise_api_service.dart';
import 'package:chess_app/features/exercises/widgets/make_exercise_sheet.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/homework/screens/homework_list_screen.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/board_preview_panel.dart';
import 'package:chess_app/features/library/widgets/course_picker_dialog.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/features/position_scanner/widgets/assign_positions_dialog.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_editor_entry.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_row_actions.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/services/lesson_recording_api.dart';
import 'package:chess_app/widgets/app_feedback.dart';
import 'package:chess_app/widgets/confirm_delete.dart';

/// Everything the trainer keeps, in one place — phase 3a of
/// `docs/PLAN-REORGANIZACIJA.md` (S3). [LibraryList] draws the chips, the
/// search field and the rows; this screen fetches, opens and acts.
///
/// Two sources, read once and held together: the server's five shelves
/// (`PositionLibraryService.list()`, over `positionLibrary.js`) and the
/// device's own puzzle sets, which the server never sees.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.session,
    this.initialChip,
    this.initialFromTrainer,
    this.lessonApi,
    this.positionLibrary,
    this.assignmentApi,
    this.groupApi,
    this.homeworkApi,
    this.exerciseApi,
    this.puzzleSets,
    this.recordingApi,
  });

  final UserSession session;

  /// Where the list opens — the Tutorials card's „Saved tutorials" opens it on
  /// [LibraryChip.tutorials] and on the trainer's own (false). Until
  /// 17.9.2026 that button opened a dialog of its own, a second copy of this
  /// list that gave its rows no room on a phone.
  final LibraryChip? initialChip;
  final bool? initialFromTrainer;

  /// Seams for a test; defaulted to real services against this session.
  final LessonApiService? lessonApi;
  final PositionLibraryService? positionLibrary;
  final AssignmentApiService? assignmentApi;
  final GroupApiService? groupApi;

  /// Seam for the "Homework" door's list; same rule as the seams above.
  final HomeworkApiService? homeworkApi;

  /// Seam for the door into `ExerciseEditorScreen` (phase 11); same rule.
  final ExerciseApiService? exerciseApi;

  /// Seam for the account's puzzle sets; same rule as the seams above.
  final PuzzleSetRepository? puzzleSets;

  /// Seam for deleting a recording; same rule as the seams above.
  final LessonRecordingApi? recordingApi;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late final PositionLibraryService _library = widget.positionLibrary ??
      PositionLibraryService(authToken: widget.session.token);
  late final LessonApiService _lessons =
      widget.lessonApi ?? LessonApiService(authToken: widget.session.token);
  late final HomeworkApiService _homework =
      widget.homeworkApi ?? HomeworkApiService(authToken: widget.session.token);
  late final ExerciseApiService _exerciseApi =
      widget.exerciseApi ?? ExerciseApiService(authToken: widget.session.token);

  /// The account's puzzle sets. Until 21.9.2026 this shelf read the device's
  /// own store directly, so the owner's sets showed on Windows and the phone
  /// had none under the same account.
  late final PuzzleSetRepository _puzzleSets = widget.puzzleSets ??
      PuzzleSetRepository(
        api: PuzzleSetApiService(authToken: widget.session.token),
      );
  late final LessonRecordingApi _recordingApi = widget.recordingApi ??
      LessonRecordingApi(authToken: widget.session.token);
  late final TutorialRowActions _tutorialActions = TutorialRowActions(
    lessonApi: _lessons,
    assignmentApi: widget.assignmentApi ??
        AssignmentApiService(authToken: widget.session.token),
    groupApi: widget.groupApi ?? GroupApiService(),
  );

  List<LibraryEntry>? _entries;
  bool _loading = true;
  bool _failed = false;

  /// The labels this user has given their positions and tutorials; the list
  /// filters by them (phase 3b — the manual's Preparation page had promised
  /// it since the batch that rewrote it).
  List<String> _labels = const [];

  /// The raw `saved_lessons` rows behind the `tutorial` entries — fetched
  /// once alongside the list rather than per tap or per button, because every
  /// action a tutorial row offers (send, export, delete…) needs the row
  /// `GET /lessons` returns, not the shelf's slimmer [LibraryEntry].
  List<Map<String, dynamic>> _rawTutorials = const [];

  /// The entry drawn in the pane, on a wide window. Null is „nothing chosen
  /// yet", which is what the pane says out loud.
  LibraryEntry? _chosen;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Map<String, dynamic>? _rawTutorialFor(LibraryEntry entry) {
    for (final row in _rawTutorials) {
      if (row['id']?.toString() == entry.id) return row;
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });

    final items = await _library.list();
    final sets = await _puzzleSets.load();
    final rawRows = await _lessons.fetchAll();
    final labels = await _lessons.fetchLabels();
    if (!mounted) return;

    if (items == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }

    final rawTutorials = [
      for (final row in rawRows)
        if (row is Map && row['position_list'] is List)
          Map<String, dynamic>.from(row),
    ];

    final puzzleSets = [
      for (final set in sets)
        LibraryEntry(
          kind: LibraryKind.puzzleSet,
          id: set.id,
          title: set.title,
          fen: '',
          assignable: false,
          createdAt: set.createdAt,
        ),
    ];

    setState(() {
      _loading = false;
      _entries = [...items, ...puzzleSets];
      _rawTutorials = rawTutorials;
      _labels = labels;
    });
  }

  /// One row's trailing controls, per kind. A kind with nothing to offer
  /// draws none — [LibraryList] shows nothing rather than an empty row of
  /// buttons.
  List<Widget> _actionsFor(LibraryEntry entry) {
    // Somebody else's material — readable because they teach this account —
    // is not this account's to send, render or delete. The dialog this screen
    // replaced left those rows out for that reason (reported 8.9.2026).
    if (entry.fromTrainer) return const [];
    switch (entry.kind) {
      case LibraryKind.tutorial:
        final row = _rawTutorialFor(entry);
        if (row == null) return const [];
        return [
          if (TutorialRowActions.isRendering(row))
            IconButton(
              icon: Icon(Icons.movie, size: 20, color: context.colors.accent),
              tooltip: 'Rendering — show progress',
              onPressed: () => _watchRender(row),
            )
          else
            IconButton(
              icon: const Icon(Icons.videocam_outlined, size: 20),
              tooltip: 'Export video',
              onPressed: () => _exportVideo(row),
            ),
          if (TutorialRowActions.hasVideo(row))
            IconButton(
              icon: const Icon(Icons.file_download_outlined, size: 20),
              tooltip: 'Download video',
              onPressed: () => _downloadVideo(row),
            ),
          IconButton(
            icon: const Icon(Icons.send_outlined, size: 20),
            tooltip: 'Send to student',
            onPressed: () => _tutorialActions.send(context, row),
          ),
          IconButton(
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: context.colors.danger,
            ),
            tooltip: 'Delete tutorial',
            onPressed: () => _deleteTutorial(entry, row),
          ),
        ];
      // **A position is not sent; it is made into an exercise first** — the
      // owner's rule of 19.9.2026 (185.5). Since phase 10 a scan with no
      // printed solution is a position, and its card still offered „Assign",
      // a door the server can only refuse (205.3). So the card asks what the
      // entry *is*, not which table it came from: an exercise is assigned, a
      // position is offered the sheet that makes one of it.
      case LibraryKind.scan:
      case LibraryKind.position:
        return [
          IconButton(
            icon: const Icon(Icons.playlist_add, size: 20),
            tooltip: 'Add to tutorial',
            onPressed: () => _addToTutorial(entry),
          ),
          if (entry.isExercise)
            IconButton(
              icon: const Icon(Icons.assignment_outlined, size: 20),
              tooltip: 'Assign to student',
              onPressed: () => _assign(entry),
            )
          else
            IconButton(
              icon: const Icon(Icons.task_alt, size: 20),
              tooltip: 'Make exercise',
              onPressed: () => _makeExercise(entry),
            ),
        ];
      case LibraryKind.recording:
        return [
          IconButton(
            icon: const Icon(Icons.play_circle_outline, size: 20),
            tooltip: 'Play',
            onPressed: () => _openRecording(entry),
          ),
          // The shelf lists only the host's own (`listRecordings`), and a
          // trainer's shared one returned early above.
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 20, color: context.colors.danger),
            tooltip: 'Delete recording',
            onPressed: () => _deleteRecording(entry),
          ),
        ];
      // Deleted from the shelf since 21.9.2026 (TODO-provera 211.4: „Nema
      // dugme za brisanje"). Until then a set could only be deleted from the
      // dialog on the Analysis screen, and an analysis from nowhere here.
      case LibraryKind.analysis:
        return [
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 20, color: context.colors.danger),
            tooltip: 'Delete analysis',
            onPressed: () => _deleteAnalysis(entry),
          ),
        ];
      case LibraryKind.puzzleSet:
        return [
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 20, color: context.colors.danger),
            tooltip: 'Delete puzzle set',
            onPressed: () => _deletePuzzleSet(entry),
          ),
        ];
    }
  }

  Future<bool> _confirmDelete(String what, String title) async =>
      await confirmDelete(context, what: what, title: title) && mounted;

  /// The card goes only once the server has let go of the thing — a card that
  /// vanishes while the account still has it is back on the next load.
  void _dropEntry(LibraryEntry entry) {
    setState(() => _entries = _entries?.where((e) => e != entry).toList());
  }

  Future<void> _deletePuzzleSet(LibraryEntry entry) async {
    if (!await _confirmDelete('puzzle set', entry.title)) return;
    final deleted = await _puzzleSets.delete(entry.id);
    if (!mounted) return;
    if (!deleted) {
      AppFeedback.error(context, notDeletedMessage(entry.title));
      return;
    }
    _dropEntry(entry);
    AppFeedback.success(context, 'Puzzle set deleted.');
  }

  Future<void> _deleteRecording(LibraryEntry entry) async {
    final id = int.tryParse(entry.id);
    if (id == null) return;
    if (!await _confirmDelete('recording', entry.title)) return;
    final deleted = await _recordingApi.delete(id);
    if (!mounted) return;
    if (!deleted) {
      AppFeedback.error(context, notDeletedMessage(entry.title));
      return;
    }
    _dropEntry(entry);
    AppFeedback.success(context, 'Recording deleted.');
  }

  Future<void> _deleteAnalysis(LibraryEntry entry) async {
    final id = int.tryParse(entry.id);
    if (id == null) return;
    if (!await _confirmDelete('analysis', entry.title)) return;
    final deleted = await AnalysisPersistenceService.instance.deleteAnalysis(
      id: id,
      userToken: widget.session.token,
    );
    if (!mounted) return;
    if (!deleted) {
      AppFeedback.error(context, notDeletedMessage(entry.title));
      return;
    }
    _dropEntry(entry);
    AppFeedback.success(context, 'Analysis deleted.');
  }

  /// The sheet the room opens, over this card's position with nothing played
  /// on it — so „Find the move" goes to the exercise's own screen („Play the
  /// move", phase 14), and „Win", „Draw or better" and „Play N moves" are
  /// saved from the sheet as they are in the room.
  Future<void> _makeExercise(LibraryEntry entry) async {
    final saved = await showDialog<Exercise>(
      context: context,
      builder: (_) => MakeExerciseSheet(
        api: _exerciseApi,
        moveTree: MoveTree(startingFen: entry.fen),
        availableUserLabels: _labels,
      ),
    );
    if (saved == null || !mounted) return;
    // Do the thing, then say it.
    _load();
    AppFeedback.success(context, 'Exercise saved.');
  }

  Future<void> _watchRender(Map<String, dynamic> row) async {
    await _tutorialActions.watchRender(context, row);
    if (mounted) setState(() {});
  }

  /// Redrawn afterwards: a film the retention timer has taken takes its
  /// button with it (`TutorialRowActions` clears `has_video`), and a row
  /// still offering it is a button that answers the same refusal forever.
  Future<void> _downloadVideo(Map<String, dynamic> row) async {
    await _tutorialActions.downloadVideo(context, row);
    if (mounted) setState(() {});
  }

  Future<void> _exportVideo(Map<String, dynamic> row) async {
    await _tutorialActions.exportVideo(context, row);
    if (mounted) setState(() {});
  }

  Future<void> _deleteTutorial(
    LibraryEntry entry,
    Map<String, dynamic> row,
  ) async {
    final deleted = await _tutorialActions.delete(context, row);
    if (!mounted || !deleted) return;
    setState(() {
      _entries = _entries?.where((e) => e != entry).toList();
      _rawTutorials = _rawTutorials.where((r) => r != row).toList();
    });
  }

  Future<void> _addToTutorial(LibraryEntry entry) async {
    final course = await showDialog<CourseSummary>(
      context: context,
      builder: (context) => CoursePickerDialog(service: _library),
    );
    if (course == null || !mounted) return;

    final error = await _lessons.appendStep(
      lessonId: course.id,
      step: {
        'title': entry.title,
        'fen': entry.fen,
        if (entry.instruction != null) 'instruction': entry.instruction,
        if (entry.solutionSan != null) 'solutionSan': entry.solutionSan,
      },
    );
    if (!mounted) return;
    if (error != null) {
      AppFeedback.error(context, error);
      return;
    }
    AppFeedback.success(context, 'Added to "${course.title}".');
  }

  Future<void> _assign(LibraryEntry entry) async {
    final message = await showDialog<String>(
      context: context,
      builder: (context) =>
          AssignPositionsDialog(session: widget.session, puzzleIds: [entry.id]),
    );
    if (message == null || !mounted) return;
    AppFeedback.show(context, () => SnackBar(content: Text(message)));
  }

  void _openRecording(LibraryEntry entry) {
    final id = int.tryParse(entry.id);
    if (id == null) return;
    context.push(AppRoutes.replayPath(id));
  }

  Future<void> _openTutorial(LibraryEntry entry) async {
    if (entry.fromTrainer) {
      // A student on Windows once opened their trainer's tutorial in the
      // studio, edited it, and was refused only at save (8.9.2026).
      AppFeedback.info(context, 'This tutorial belongs to your trainer.');
      return;
    }
    final row = _rawTutorialFor(entry);
    if (row == null) {
      AppFeedback.error(context, 'Tutorial not found.');
      return;
    }
    await openTutorialEditor(
      context,
      session: widget.session,
      api: _lessons,
      lesson: row,
    );
  }

  Future<void> _openAnalysis(LibraryEntry entry) async {
    final id = int.tryParse(entry.id);
    if (id == null) return;
    final root = await AnalysisPersistenceService.instance.loadAnalysis(
      id: id,
      userToken: widget.session.token,
    );
    if (!mounted) return;
    if (root == null) {
      AppFeedback.error(context, 'Could not load that analysis.');
      return;
    }
    // The whole tree, as it was saved: a game would be its main line and
    // would drop the sidelines, comments and arrows.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnalysisStudioScreen(
          userSession: widget.session,
          initialTree: root,
        ),
      ),
    );
  }

  void _open(LibraryEntry entry) {
    switch (entry.kind) {
      case LibraryKind.tutorial:
        _openTutorial(entry);
      case LibraryKind.position:
        context.push(AppRoutes.analysisPath(fen: entry.fen));
      case LibraryKind.scan:
        // A saved exercise of this trainer's own opens for reading and
        // editing (phase 11); everything else — a bare scan, or somebody
        // else's exercise, not this account's to change — opens on its bare
        // position as it always has.
        if (entry.isExercise && !entry.fromTrainer) {
          _openExercise(entry);
        } else {
          context.push(AppRoutes.analysisPath(fen: entry.fen));
        }
      case LibraryKind.analysis:
        _openAnalysis(entry);
      case LibraryKind.recording:
        _openRecording(entry);
      case LibraryKind.puzzleSet:
        _openPuzzleSet(entry);
    }
  }

  /// Opens a saved puzzle set on the Analysis screen.
  ///
  /// Until 20.9.2026 this shelf drew puzzle sets and a tap on one did nothing,
  /// because the only door into puzzle mode was the dialog on the screen the
  /// set had been extracted in. The owner reported both halves of that the
  /// same evening — the dead tap, and not knowing where saved puzzles were at
  /// all — and the Library is where he looked.
  ///
  /// The set is re-read here rather than carried on the [LibraryEntry]: the
  /// entry is a shelf row, deliberately slim, and the puzzles are on the
  /// device anyway. A set that has since been deleted or emptied is said, not
  /// opened.
  Future<void> _openPuzzleSet(LibraryEntry entry) async {
    final sets = await _puzzleSets.load();
    if (!mounted) return;
    final match = sets.where((set) => set.id == entry.id);
    final puzzles = match.isEmpty ? const <LocalPuzzle>[] : match.first.puzzles;
    if (puzzles.isEmpty) {
      AppFeedback.error(context, 'That set has no puzzles left in it.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AnalysisStudioScreen(
          userSession: widget.session,
          initialPuzzles: puzzles,
        ),
      ),
    );
    // A set can be finished or discarded in there, so the shelf is re-read.
    if (mounted) _load();
  }

  Future<void> _openExercise(LibraryEntry entry) async {
    final saved = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExerciseEditorScreen(
          api: _exerciseApi,
          exerciseId: entry.id,
          availableUserLabels: _labels,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    // Do the thing, then say it.
    _load();
    AppFeedback.success(context, 'Exercise saved.');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('Library'),
        backgroundColor: colors.surface,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_failed) {
      final colors = context.colors;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: colors.textMuted),
              const SizedBox(height: AppSpacing.md),
              const Text('The library could not be loaded.'),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: _load, child: const Text('Try again')),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _homeworkDoor(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _shelfAndPane()),
        ],
      ),
    );
  }

  /// The shelf, and on a wide window a pane beside it — phase 5 of
  /// `docs/PLAN-LISTE.md`, pattern B.
  ///
  /// Below [Breakpoints.wide] nothing changes at all: the list is the screen
  /// and a tap on a board opens the dialog it has always opened. That is not
  /// only the plan's rule, it is the behaviour the owner checked live on
  /// 20.9.2026 (item 205, point 5).
  Widget _shelfAndPane() {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= Breakpoints.wide;
      final shelf = LibraryList(
        entries: _entries ?? const [],
        onOpen: _open,
        actionsFor: _actionsFor,
        labels: _labels,
        initialChip: widget.initialChip,
        originChips: widget.initialFromTrainer != null,
        initialFromTrainer: widget.initialFromTrainer,
        // Only where there is a pane to put it in. Null keeps the dialog,
        // which is what the narrow window and the room's column both want.
        onSelect: wide ? (entry) => setState(() => _chosen = entry) : null,
        selectedId: wide && _chosen != null ? LibraryList.idOf(_chosen!) : null,
        // The sheet that makes one lives in Preparation, not here —
        // this is a door, not a second editor (`docs/PLAN-EXERCISE.md`,
        // phase 4). Same call as the Teach tab's own „Preparation" card.
        onNewExercise: () =>
            context.push(AppRoutes.roomPath('STUDIO', role: 'host')),
      );
      if (!wide) return shelf;

      // The pane takes what is left over one full column of cards, never
      // more than [_paneMax]. A card is at most `AdaptiveCardGrid.maxTileWidth`
      // wide, so this is the rule that keeps the shelf able to draw a whole
      // one: at 840 the pane is wide and the shelf holds a single column, at
      // 1920 the pane stops growing and every further pixel goes to cards.
      // Splitting the difference evenly would instead give 840 two half-cards
      // and a pane too narrow for a board.
      final paneWidth =
          (constraints.maxWidth - AdaptiveCardGrid.maxTileWidth - AppSpacing.md)
              .clamp(_paneMin, _paneMax);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: shelf),
          const SizedBox(width: AppSpacing.md),
          SizedBox(width: paneWidth, child: _pane(paneWidth)),
        ],
      );
    });
  }

  static const double _paneMin = 280;
  static const double _paneMax = 420;

  /// What stands in the pane: the chosen entry's board, or a line saying what
  /// the pane is for.
  ///
  /// The empty line matters more than it looks. Phase 3a was amended because
  /// a dialog took width it could not fill; a pane that is blank until the
  /// first tap is the same fault in a different shape, and the owner would be
  /// right to report it.
  Widget _pane(double width) {
    final colors = context.colors;
    final entry = _chosen;
    if (entry == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'Tap a board to see it here.',
            textAlign: TextAlign.center,
            style: AppText.body.copyWith(color: colors.textMuted),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              entry.title,
              textAlign: TextAlign.center,
              style: AppText.subtitle,
            ),
            const SizedBox(height: AppSpacing.sm),
            BoardPreviewPanel(
              entry: entry,
              // The board takes the pane's width less its padding, capped so
              // a very wide pane does not draw a board bigger than the cards
              // it is meant to sit beside.
              boardSize: (width - AppSpacing.md * 2).clamp(240.0, 360.0),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => _open(entry),
              child: const Text('Open'),
            ),
          ],
        ),
      ),
    );
  }

  /// A homework template is not a shelf entry — it has no FEN and comes from
  /// a different endpoint (`/homeworks`, not `positionLibrary.js`) — so it is
  /// not a seventh [LibraryKind]: [LibraryList]'s six chips are frozen and
  /// the manual quotes them. This is a door beside the list rather than a
  /// chip inside it, opening the same [HomeworkListScreen] the Teach tab's
  /// card does (`docs/PLAN-DOMACI-ZADATAK.md` §5, §9 item 5).
  Widget _homeworkDoor() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        key: const Key('library-homework-chip'),
        avatar: const Icon(Icons.assignment_outlined, size: 18),
        label: const Text('Homework'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => HomeworkListScreen(api: _homework),
          ),
        ),
      ),
    );
  }
}
