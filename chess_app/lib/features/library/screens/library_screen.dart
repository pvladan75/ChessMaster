import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/core/services/local_puzzle_set_storage_service.dart';
import 'package:chess_app/features/analysis_studio/screens/analysis_studio_screen.dart';
import 'package:chess_app/features/analysis_studio/services/analysis_persistence_service.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/homework/screens/homework_list_screen.dart';
import 'package:chess_app/features/homework/services/homework_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/library/models/library_entry.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/course_picker_dialog.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
import 'package:chess_app/features/position_scanner/widgets/assign_positions_dialog.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_editor_entry.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_row_actions.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/routing/app_routes.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/app_feedback.dart';

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
    final sets = await LocalPuzzleSetStorageService.instance.loadSets();
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
            icon: Icon(Icons.delete_outline,
                size: 20, color: context.colors.danger),
            tooltip: 'Delete tutorial',
            onPressed: () => _deleteTutorial(entry, row),
          ),
        ];
      case LibraryKind.scan:
        return [
          IconButton(
            icon: const Icon(Icons.playlist_add, size: 20),
            tooltip: 'Add to tutorial',
            onPressed: () => _addToTutorial(entry),
          ),
          IconButton(
            icon: const Icon(Icons.assignment_outlined, size: 20),
            tooltip: 'Assign to student',
            onPressed: () => _assign(entry),
          ),
        ];
      case LibraryKind.position:
        return [
          IconButton(
            icon: const Icon(Icons.playlist_add, size: 20),
            tooltip: 'Add to tutorial',
            onPressed: () => _addToTutorial(entry),
          ),
        ];
      case LibraryKind.recording:
        return [
          IconButton(
            icon: const Icon(Icons.play_circle_outline, size: 20),
            tooltip: 'Play',
            onPressed: () => _openRecording(entry),
          ),
        ];
      case LibraryKind.analysis:
      case LibraryKind.puzzleSet:
        return const [];
    }
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
      LibraryEntry entry, Map<String, dynamic> row) async {
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
      builder: (context) => AssignPositionsDialog(
        session: widget.session,
        puzzleIds: [entry.id],
      ),
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
    await openTutorialEditor(context,
        session: widget.session, api: _lessons, lesson: row);
  }

  Future<void> _openAnalysis(LibraryEntry entry) async {
    final id = int.tryParse(entry.id);
    if (id == null) return;
    final root = await AnalysisPersistenceService.instance
        .loadAnalysis(id: id, userToken: widget.session.token);
    if (!mounted) return;
    if (root == null) {
      AppFeedback.error(context, 'Could not load that analysis.');
      return;
    }
    // The whole tree, as it was saved: a game would be its main line and
    // would drop the sidelines, comments and arrows.
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AnalysisStudioScreen(
        userSession: widget.session,
        initialTree: root,
      ),
    ));
  }

  void _open(LibraryEntry entry) {
    switch (entry.kind) {
      case LibraryKind.tutorial:
        _openTutorial(entry);
      case LibraryKind.position:
      case LibraryKind.scan:
        context.push(AppRoutes.analysisPath(fen: entry.fen));
      case LibraryKind.analysis:
        _openAnalysis(entry);
      case LibraryKind.recording:
        _openRecording(entry);
      case LibraryKind.puzzleSet:
        // No door into puzzle mode outside the Analysis screen it was
        // extracted in — see the report. Drawn, but tapping it does nothing.
        break;
    }
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
          Expanded(
            child: LibraryList(
              entries: _entries ?? const [],
              onOpen: _open,
              actionsFor: _actionsFor,
              labels: _labels,
              initialChip: widget.initialChip,
              originChips: widget.initialFromTrainer != null,
              initialFromTrainer: widget.initialFromTrainer,
              // The sheet that makes one lives in Preparation, not here —
              // this is a door, not a second editor (`docs/PLAN-EXERCISE.md`,
              // phase 4). Same call as the Teach tab's own „Preparation" card.
              onNewExercise: () =>
                  context.push(AppRoutes.roomPath('STUDIO', role: 'host')),
            ),
          ),
        ],
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
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => HomeworkListScreen(api: _homework),
        )),
      ),
    );
  }
}
