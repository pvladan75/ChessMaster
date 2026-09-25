import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_entry.dart';
import 'package:chess_app/features/tutorial_studio/screens/tutorial_studio_screen.dart';
import 'package:chess_app/features/tutorial_studio/services/pgn_game_import.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_import_save.dart';
import 'package:chess_app/features/tutorial_studio/widgets/tutorial_import_dialog.dart';
import 'package:chess_app/features/library/screens/library_screen.dart';
import 'package:chess_app/features/library/services/position_library_service.dart';
import 'package:chess_app/features/library/widgets/library_list.dart';
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
    this.positionLibrary,
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

  /// The shelf „Saved tutorials" opens the Library on. Same rule as the
  /// seams above.
  final PositionLibraryService? positionLibrary;

  @override
  Widget build(BuildContext context) {
    // No gap of its own: the Teach tab's flow spaces its cards, and a gap
    // inside one card of a row would end it short of its neighbours.
    return Card(
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
                    'Tutorials',
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
              style: AppText.body.copyWith(color: context.colors.textSecondary),
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

  /// „Import from a file" — tutorials written outside the app, or games.
  ///
  /// Two doors out of one report, and which one is drawn depends on how many
  /// files were picked. One file opens in the studio **unsaved**, which is the
  /// flow a trainer checking a generated tutorial asked for: look at it on a
  /// board, fix what is wrong, then press „Save tutorial". Several files are
  /// written straight to the library, because opening a dozen in an authoring
  /// screen one at a time is a chore that gets skipped.
  Future<void> _onImport(BuildContext context) async {
    final picked = await (pickFiles ?? _pickTutorialFiles)();
    if (!context.mounted || picked.isEmpty) return;

    // Which reader a file gets is decided by what is in it, not by this screen:
    // a tutorial written outside the app is JSON, a game is PGN, and one PGN
    // file can hold many games and therefore many tutorials.
    final read = [
      for (final file in picked)
        ...tutorialsFromFile(name: file.name, text: file.text),
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

  /// The real chooser. Tutorials and games, several at a time.
  ///
  /// Both extensions in one picker rather than two buttons: a trainer has one
  /// „import" in their head, and which reader a file needs is a question the
  /// app can answer by looking at it.
  ///
  /// A file that cannot be read from disk is dropped here rather than carried
  /// as an empty string: „the file is not valid JSON" would be the wrong
  /// sentence for a file the operating system would not open.
  static Future<List<PickedTutorialFile>> _pickTutorialFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'pgn'],
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

  /// „Saved tutorials" is the Library, opened on the trainer's own
  /// tutorials. Until 17.9.2026 it was a dialog of its own — a second copy of
  /// the list, its search and its labels — which on a phone gave its rows no
  /// height in portrait and no width for a title in landscape (the owner's
  /// screenshots). One list, one home: `docs/PLAN-REORGANIZACIJA.md` S3.
  Future<void> _onOpenSavedTutorial(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LibraryScreen(
        session: session,
        initialChip: LibraryChip.tutorials,
        initialFromTrainer: false,
        lessonApi: api,
        positionLibrary: positionLibrary,
        assignmentApi: assignmentApi,
        groupApi: groupApi,
      ),
    ));
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
