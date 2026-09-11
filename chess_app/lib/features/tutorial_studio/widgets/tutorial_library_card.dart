import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chess_app/constants.dart';

import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import_save.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video_export.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_import_dialog.dart';
import 'package:chess_app/features/tutorial_studio/tutorial_studio_availability.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Asks whether an analysis line joins the open tutorial draft or starts a new one.
///
/// - `true`  — into the tutorial being written (`intoOpenDraft: true`)
/// - `false` — into a new one (`intoOpenDraft: false`)
/// - `null`  — the trainer cancelled
Future<bool?> askTutorialDestination(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Where does this line go?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Start new tutorial'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Continue editing tutorial'),
        ),
      ],
    ),
  );
}

/// The front door to the Tutorial Studio on the Library tab.
///
/// Draws itself only when [isTutorialStudioAvailable] is true.
/// A file the trainer picked, read.
typedef PickedTutorialFile = ({String name, String text});

/// How the card asks for files. Answers an empty list when nothing was picked.
typedef TutorialFilePicker = Future<List<PickedTutorialFile>> Function();

class TutorialLibraryCard extends StatelessWidget {
  const TutorialLibraryCard({
    super.key,
    required this.session,
    this.api,
    this.assignmentApi,
    this.groupApi,
    this.pickFiles,
  });

  final UserSession session;

  /// The seam a test reaches the library list through. Defaulted to a real
  /// service against this session's token, so nothing but a test passes it.
  final LessonApiService? api;

  /// The two seams the row actions go through — sending a tutorial to a child
  /// and reading the trainer's own students. Same rule: defaulted, so nothing
  /// but a test ever passes them.
  final AssignmentApiService? assignmentApi;
  final GroupApiService? groupApi;

  /// The file chooser, which is a platform channel and therefore the one part
  /// of the import a widget test cannot drive. Defaulted to the real one, like
  /// every other seam on this card, so only a test ever passes it.
  final TutorialFilePicker? pickFiles;

  @override
  Widget build(BuildContext context) {
    if (!isTutorialStudioAvailable) return const SizedBox.shrink();

    // The gap below belongs to the card rather than to the tab. The tab cannot
    // tell a card that draws nothing from a card that is not there, so spacing
    // it from the outside left 24 px of dead air at the top of the Library tab
    // on every phone — where this card is deliberately absent.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Card(
        shape: AppRadii.cardShape,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_stories_outlined,
                    color: context.colors.accent,
                    size: 28,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Interactive tutorials',
                      style: AppText.headline
                          .copyWith(color: context.colors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Create a tutorial that the student goes through on their own — '
                'position by position, with comments, arrows, and questions.',
                style:
                    AppText.body.copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New tutorial'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  padding: AppSpacing.buttonPadding,
                ),
                onPressed: () => _onNewTutorial(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                key: const Key('import-tutorial'),
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('Import from a file'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  padding: AppSpacing.buttonPadding,
                ),
                onPressed: () => _onImport(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.folder_open),
                label: const Text('Saved tutorials'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  padding: AppSpacing.buttonPadding,
                ),
                onPressed: () => _onOpenSavedTutorial(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onNewTutorial(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => const _NewTutorialNameDialog(),
    );

    // Trimmed and refused inside the dialog, so anything that arrives here is a
    // name. A tutorial has to have one before the first save — the studio
    // refuses an unnamed one — and finding that out after twenty minutes of
    // writing is the expensive way to learn it.
    if (name == null || !context.mounted) return;

    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TutorialStudioScreen(
        session: session,
        entry: TutorialEntry.blank(name),
      ),
    ));
  }

  /// „Import from a file" — one or more JSON tutorials written outside the app.
  ///
  /// Two doors out of one report, and which one is drawn depends on how many
  /// files were picked. One file opens in the studio **unsaved**, which is the
  /// flow a trainer checking a generated tutorial asked for: look at it on a
  /// board, fix what is wrong, then press „Save tutorial". Several files are
  /// written straight to the library, because opening a dozen in an authoring
  /// screen one at a time is a chore that gets skipped.
  Future<void> _onImport(BuildContext context) async {
    final picked = await (pickFiles ?? _pickJsonFiles)();
    if (!context.mounted || picked.isEmpty) return;

    final read = [
      for (final file in picked)
        readTutorialJson(file.text, fileName: file.name),
    ];

    final choice = await showTutorialImportDialog(context, read);
    if (!context.mounted || choice == null) return;

    switch (choice) {
      case ImportChoiceOpen(:final tutorial):
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => TutorialStudioScreen(
            session: session,
            // No id: the studio's own save creates it, with every refusal that
            // screen makes — the answer leak among them.
            entry: TutorialEntry.imported(
              tutorial.asLesson,
              sourceName: tutorial.fileName,
            ),
          ),
        ));

      case ImportChoiceSave(:final tutorials):
        await _saveImported(context, tutorials);
    }
  }

  /// Writes the batch and says what became of it.
  Future<void> _saveImported(
    BuildContext context,
    List<ImportedTutorial> tutorials,
  ) async {
    final service = api ?? LessonApiService(authToken: session.token);
    final outcomes = await saveImportedTutorials(tutorials, service);
    if (!context.mounted) return;

    final failed = outcomes.where((o) => !o.saved).toList();
    final saved = outcomes.length - failed.length;

    if (failed.isEmpty) {
      AppFeedback.success(
        context,
        '$saved ${saved == 1 ? 'tutorial' : 'tutorials'} imported.',
      );
      return;
    }

    // Named rather than counted. A batch told „3 failed" has to be imported
    // again from the beginning to find out which three.
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import finished'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$saved saved, ${failed.length} not.'),
              const SizedBox(height: AppSpacing.sm),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final outcome in failed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Text(
                            '${outcome.name}: ${outcome.error}',
                            style: AppText.caption
                                .copyWith(color: ctx.colors.danger),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// The real chooser. JSON only, several at a time.
  ///
  /// A file that cannot be read from disk is dropped here rather than carried
  /// as an empty string: „the file is not valid JSON" would be the wrong
  /// sentence for a file the operating system would not open.
  static Future<List<PickedTutorialFile>> _pickJsonFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: true,
    );
    if (result == null) return const [];

    final files = <PickedTutorialFile>[];
    for (final file in result.files) {
      // The bytes are there on the web and on some Android pickers; the path is
      // there on Windows. Either is enough.
      final bytes = file.bytes;
      if (bytes != null) {
        files.add(
            (name: file.name, text: utf8.decode(bytes, allowMalformed: true)));
        continue;
      }
      final path = file.path;
      if (path == null) continue;
      try {
        files.add((name: file.name, text: await File(path).readAsString()));
      } catch (_) {
        // Unreadable on disk. Nothing to import and nothing to say about its
        // contents.
      }
    }
    return files;
  }

  Future<void> _onOpenSavedTutorial(BuildContext context) async {
    final service = api ?? LessonApiService(authToken: session.token);
    final rawRows = await service.fetchAll();
    if (!context.mounted) return;

    // `lastFetchFailed` is the whole answer. The `identical(rawRows, const [])`
    // that stood beside it happened to be harmless — `jsonDecode` builds a new
    // list, so a genuinely empty library is never the canonical `const []` —
    // but it read as though it were doing the work, and it would start
    // misfiring the day `fetchAll` returned a plain `[]` on failure. A second
    // condition that cannot be right when the first is wrong is not a
    // safeguard.
    if (service.lastFetchFailed) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Saved tutorials'),
          content: const Text('Could not load tutorials.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      return;
    }

    // Two questions, and the second one is newer than this card.
    //
    // A row with no `position_list` is a diagram rather than a tutorial, and
    // opening the studio on it opens something with no parts.
    //
    // And `is_trainer_lesson` is true for exactly the rows `GET /lessons`
    // reaches through `acceptedTrainersOf` — everything the trainers who teach
    // this account have ever saved. **This is somebody else's work**, and it
    // has no business on the shelf a trainer writes from: a student on Windows
    // opened one in the studio, edited it, and found out only at save, where
    // the server refused them. Reported live on 8.9.2026. Since 7.9.2026 the
    // row also carries a bin and a „pošalji" they could never have used — an
    // action drawn where it cannot work, which is the fault this list had just
    // been fixed to stop being.
    //
    // The flag is the same one `chess_game_screen`'s lesson list splits its two
    // sections by, and the one `assign_lesson_dialog` already filters on; this
    // was the one reader that ignored it.
    final tutorials = <Map<String, dynamic>>[];
    for (final item in rawRows) {
      if (item is! Map) continue;
      if (item['is_trainer_lesson'] == true) continue;
      final posList = item['position_list'];
      // A list, empty or not — but never `null`, which is what a plain saved
      // lesson has and what keeps those out of a sheet about tutorials.
      //
      // The empty ones used to be hidden too, which meant a tutorial whose
      // parts had all been deleted could not be reached to be deleted itself,
      // and the refusal below ("nothing to show yet") could never fire on
      // anything. A feature that is complete, tested and unreachable is a
      // shape this project has met before.
      if (posList is List) {
        tutorials.add(Map<String, dynamic>.from(item));
      }
    }

    if (tutorials.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Saved tutorials'),
          content: const Text('You have no saved tutorials.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      return;
    }

    final picked = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _SavedTutorialsDialog(
        tutorials: tutorials,
        lessonApi: service,
        assignmentApi:
            assignmentApi ?? AssignmentApiService(authToken: session.token),
        groupApi: groupApi ?? GroupApiService(),
      ),
    );

    if (picked != null && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TutorialStudioScreen(
          session: session,
          entry: TutorialEntry.saved(picked),
        ),
      ));
    }
  }
}

/// The trainer's own tutorials, and the three things they can do with one.
///
/// It used to be a list that could only be **opened**, which is how „ne postoji
/// mogućnost brisanja tutorijala" and „tutorijal ne može da se pošalje đaku"
/// were both true on 7.9.2026 while the server had `DELETE /lessons/:id` and
/// `POST /assignments/lesson` all along, and the app called them from two
/// screens a trainer writing a tutorial has no reason to be on. **A capability
/// that exists at every layer and is reachable from nowhere the user goes is a
/// capability they do not have.**
///
/// Stateful for one reason: a row that was deleted has to leave the list
/// without closing it, so the trainer can delete a second one.
class _SavedTutorialsDialog extends StatefulWidget {
  const _SavedTutorialsDialog({
    required this.tutorials,
    required this.lessonApi,
    required this.assignmentApi,
    required this.groupApi,
  });

  final List<Map<String, dynamic>> tutorials;
  final LessonApiService lessonApi;
  final AssignmentApiService assignmentApi;
  final GroupApiService groupApi;

  @override
  State<_SavedTutorialsDialog> createState() => _SavedTutorialsDialogState();
}

class _SavedTutorialsDialogState extends State<_SavedTutorialsDialog> {
  late final List<Map<String, dynamic>> _rows = [...widget.tutorials];

  /// True while a row is being deleted or sent, so neither can be started
  /// twice on a list that is about to change under it.
  bool _busy = false;

  /// How many tutorials there have to be before a search box is worth the
  /// height it takes.
  static const int _filterFrom = 6;

  static int? _idOf(Map<String, dynamic> row) {
    final raw = row['id'];
    return raw is int ? raw : int.tryParse('$raw');
  }

  static String _titleOf(Map<String, dynamic> row) =>
      row['title']?.toString() ?? '';

  static List<String> _labelsOf(Map<String, dynamic> row) => [
        for (final tag in (row['tags'] as List?) ?? const []) tag.toString(),
      ];

  /// What the trainer has typed into the search box.
  String _query = '';

  /// Which labels are being filtered by. Empty means „every tutorial".
  final Set<String> _selectedLabels = {};

  /// Every label in the list, in the order they are first met.
  ///
  /// Read off the rows rather than from `GET /lessons/labels`: that endpoint
  /// answers with the labels of everything this account can see — saved
  /// positions included — and a chip for a label no tutorial here carries is a
  /// chip that empties the list when it is pressed. These rows are all in
  /// memory anyway.
  List<String> get _availableLabels {
    final labels = <String>[];
    final seen = <String>{};
    for (final row in _rows) {
      for (final label in _labelsOf(row)) {
        if (seen.add(label.toLowerCase())) labels.add(label);
      }
    }
    labels.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return labels;
  }

  /// The rows that survive the search box and the chips.
  ///
  /// A tutorial matches a selection when it carries **any** of the chosen
  /// labels, not all of them: most tutorials carry one label, and an
  /// intersection of two is empty almost every time — a filter that answers
  /// „nothing" to an obvious question is a filter nobody presses twice.
  List<Map<String, dynamic>> get _visibleRows {
    final query = _query.trim().toLowerCase();
    return [
      for (final row in _rows)
        if (_matches(row, query)) row,
    ];
  }

  bool _matches(Map<String, dynamic> row, String query) {
    if (query.isNotEmpty) {
      final haystack =
          '${_titleOf(row)} ${row['description'] ?? ''}'.toLowerCase();
      if (!haystack.contains(query)) return false;
    }
    if (_selectedLabels.isEmpty) return true;
    final labels = _labelsOf(row).map((l) => l.toLowerCase()).toSet();
    return _selectedLabels.any((l) => labels.contains(l.toLowerCase()));
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final id = _idOf(row);
    if (id == null || _busy) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tutorial?'),
        content:
            Text('"${_titleOf(row)}" will be permanently deleted, along with '
                'all parts.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: ctx.colors.danger)),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _busy = true);
    final error = await widget.lessonApi.delete(id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      // Only on success. A row that is still on the server must stay on the
      // screen, or the trainer is told it is gone by its absence.
      if (error == null) _rows.removeWhere((r) => _idOf(r) == id);
    });
    if (error != null) {
      AppFeedback.error(context, error);
      return;
    }
    AppFeedback.success(context, 'Tutorial deleted.');
  }

  Future<void> _send(Map<String, dynamic> row) async {
    final id = _idOf(row);
    if (id == null || _busy) return;

    setState(() => _busy = true);
    final students = await widget.groupApi.myStudents();
    if (!mounted) return;
    setState(() => _busy = false);

    // Pending ones are in that list on purpose — the home screen draws them
    // greyed out — and a relationship nobody has accepted grants nothing.
    // Offering the name would be offering something the server is right to
    // refuse.
    final accepted = students.where((s) => s['status'] == 'accepted').toList();
    if (accepted.isEmpty) {
      AppFeedback.info(
          context, 'You have no students who have accepted the invitation.');
      return;
    }

    final studentId = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send to student'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 320),
          child: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: accepted.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (ctx, i) => ListTile(
                title: Text(accepted[i]['name']?.toString() ?? 'Student'),
                onTap: () {
                  final raw = accepted[i]['id'];
                  Navigator.of(ctx)
                      .pop(raw is int ? raw : int.tryParse('$raw'));
                },
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (!mounted || studentId == null) return;

    setState(() => _busy = true);
    final result = await widget.assignmentApi.createLessonAssignment(
      studentId: studentId,
      lessonId: id,
      title: _titleOf(row),
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (!result.success) {
      AppFeedback.error(context, result.error ?? 'Failed to send.');
      return;
    }
    AppFeedback.success(context, 'Tutorial sent to student.');
  }

  Future<void> _exportVideo(Map<String, dynamic> row) async {
    final id = _idOf(row);
    if (id == null || _busy) return;

    setState(() => _busy = true);
    final state = await exportTutorialVideo(
      context: context,
      api: widget.lessonApi,
      lessonId: id,
      title: _titleOf(row),
      draft: TutorialDraft.fromLesson(row),
      // Marked the moment the server accepts it, so a render the trainer hides
      // stays on its row — the place they will look for it.
      onStarted: (jobId) => row['render_job_id'] = jobId,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _settleRender(row, state);
    });
  }

  /// Whether a film of this tutorial is being drawn for this account.
  ///
  /// The list says so (`render_job_id`) and this dialog says so the moment it
  /// starts one — item 5 of part two of `docs/PLAN-SNIMANJE.md`. A render the
  /// trainer hid has to be somewhere they can find it again, and the row they
  /// started it from is where they will look.
  bool _isRendering(Map<String, dynamic> row) => row['render_job_id'] != null;

  /// What a render's end means for its row: a film to download, and no render
  /// running. A hidden one is still running and keeps its place.
  void _settleRender(Map<String, dynamic> row, RenderJobState? state) {
    if (state == null || state == RenderJobState.running) return;
    row['render_job_id'] = null;
    if (state == RenderJobState.done) row['has_video'] = true;
  }

  /// The render running for this row, shown again.
  Future<void> _watchRender(Map<String, dynamic> row) async {
    final jobId = row['render_job_id']?.toString();
    if (jobId == null || _busy) return;

    setState(() => _busy = true);
    final state = await watchTutorialRender(
      context: context,
      api: widget.lessonApi,
      jobId: jobId,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _settleRender(row, state);
    });
  }

  /// Whether this tutorial has a film waiting for it.
  ///
  /// The list says so (`has_video`), which is what lets the button be drawn
  /// only where it can do something — an action offered on a row that cannot
  /// perform it is this repository's most frequent fault.
  bool _hasVideo(Map<String, dynamic> row) => row['has_video'] == true;

  /// „Download video" — the film rendered earlier, fetched now.
  ///
  /// **This is the whole reason the tutorial keeps its filename.** The link
  /// handed out when a film is rendered carries a token that dies in thirty
  /// minutes, so closing that dialog used to mean rendering the film again.
  Future<void> _downloadVideo(Map<String, dynamic> row) async {
    final id = _idOf(row);
    if (id == null || _busy) return;

    setState(() => _busy = true);
    final link = await widget.lessonApi.fetchTutorialVideo(id);
    if (!mounted) return;
    setState(() => _busy = false);

    if (link.ok) {
      await launchUrl(
        Uri.parse(resolveMediaUrl(link.downloadUrl!)),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    // The server's own sentence: „there is no film" and „the film has been
    // deleted to save space, export it again" are different answers, and only
    // one of them means pressing the camera.
    if (!mounted) return;
    AppFeedback.info(
      context,
      link.error ?? 'This tutorial has no video yet.',
    );
    if (link.status == LessonVideoStatus.expired) {
      // The row is stale now — the list said it had a film and the server says
      // it is gone, so the next draw must not offer the same dead button.
      setState(() => row['has_video'] = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Saved tutorials'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The search box and the chips are drawn only where they can do
              // something. A trainer with four tutorials does not need a filter
              // above them, and the list this dialog can show is short enough
              // that the controls would be taller than the thing they filter.
              if (_rows.length > _filterFrom) ...[
                TextField(
                  key: const Key('tutorial-search'),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18),
                    hintText: 'Search by name',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (_availableLabels.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final label in _availableLabels)
                        FilterChip(
                          label: Text(label, style: AppText.caption),
                          selected: _selectedLabels.contains(label),
                          onSelected: (on) => setState(() {
                            if (on) {
                              _selectedLabels.add(label);
                            } else {
                              _selectedLabels.remove(label);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              Flexible(
                fit: FlexFit.loose,
                child: _visibleRows.isEmpty
                    ? Center(
                        child: Text(
                          _rows.isEmpty
                              ? 'You have no saved tutorials.'
                              : 'No tutorial matches that.',
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _visibleRows.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final row = _visibleRows[index];
                          return ListTile(
                            title: Text(
                              _titleOf(row),
                              // A tutorial is named by its first sentence, so this
                              // title is as long as a sentence and it shares the row
                              // with three actions. Without the ellipsis it pushes
                              // them off the right-hand edge of a 360 dp phone, where
                              // a release build draws no warning and the buttons are
                              // simply not there.
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Its labels, so the chips above are answerable:
                            // a filter whose result does not say why a row is
                            // in it is a filter that has to be trusted.
                            subtitle: _labelsOf(row).isEmpty
                                ? null
                                : Text(
                                    _labelsOf(row).join(', '),
                                    style: AppText.caption.copyWith(
                                        color: context.colors.textSecondary),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: () => Navigator.of(context).pop(row),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // A film being drawn for this row is shown,
                                // rather than offered a second time: one film
                                // per tutorial, and a hidden render has to be
                                // somewhere a trainer can find it again. A
                                // still icon, not a spinner — its shape says
                                // it, and an animation on a row never settles.
                                if (_isRendering(row))
                                  IconButton(
                                    icon: Icon(Icons.movie,
                                        size: 20, color: context.colors.accent),
                                    tooltip: 'Rendering — show progress',
                                    onPressed:
                                        _busy ? null : () => _watchRender(row),
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(Icons.videocam_outlined,
                                        size: 20),
                                    tooltip: 'Export video',
                                    onPressed:
                                        _busy ? null : () => _exportVideo(row),
                                  ),
                                if (_hasVideo(row))
                                  IconButton(
                                    icon: const Icon(
                                        Icons.file_download_outlined,
                                        size: 20),
                                    tooltip: 'Download video',
                                    onPressed: _busy
                                        ? null
                                        : () => _downloadVideo(row),
                                  ),
                                IconButton(
                                  icon:
                                      const Icon(Icons.send_outlined, size: 20),
                                  tooltip: 'Send to student',
                                  onPressed: _busy ? null : () => _send(row),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      size: 20, color: context.colors.danger),
                                  tooltip: 'Delete tutorial',
                                  onPressed: _busy ? null : () => _delete(row),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

/// „Novi tutorijal" — one field, and the controller's whole life inside it.
///
/// Stateful for one reason, and it is not style. A controller created beside
/// `showDialog` and disposed when that future completes is disposed **too
/// early**: the future finishes on `pop`, while the route is still animating
/// out and the `TextField` still rebuilding, and the rebuild asserts on a
/// controller that is already gone. Leaving it undisposed instead leaks a
/// listener. A `State` is the only place that knows when the field is actually
/// finished with.
class _NewTutorialNameDialog extends StatefulWidget {
  const _NewTutorialNameDialog();

  @override
  State<_NewTutorialNameDialog> createState() => _NewTutorialNameDialogState();
}

class _NewTutorialNameDialogState extends State<_NewTutorialNameDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Answers with the name, or with nothing at all when it is blank. Three
  /// spaces is a blank name.
  void _submit() {
    final trimmed = _controller.text.trim();
    Navigator.of(context).pop(trimmed.isEmpty ? null : trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New tutorial'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Tutorial title'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}
