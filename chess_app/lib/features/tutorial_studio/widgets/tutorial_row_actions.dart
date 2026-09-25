import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chess_app/constants.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/groups/services/group_api_service.dart';
import 'package:chess_app/features/lessons/services/lesson_api_service.dart';
import 'package:chess_app/features/tutorial_studio/models/tutorial_draft.dart';
import 'package:chess_app/features/tutorial_studio/services/tutorial_video_export.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// The four things a trainer can do to one saved tutorial row, lifted out of
/// `_SavedTutorialsDialog` (docs/PLAN-REORGANIZACIJA.md phase 3a, S3) so the
/// Library screen can offer the same four without a second implementation of
/// any of them. **One rule, one home**: the dialog and the screen both call
/// this, and neither writes its own copy of a confirmation, a request or the
/// bookkeeping a render leaves on the row.
///
/// A row is a raw `Map<String, dynamic>` — the shape `GET /lessons` returns —
/// because that is what both callers already hold: the dialog reads it out of
/// `fetchAll()`, and the Library screen's entries are read through
/// `positionLibrary`'s own shelf, not this one.
class TutorialRowActions {
  const TutorialRowActions({
    required this.lessonApi,
    required this.assignmentApi,
    required this.groupApi,
  });

  final LessonApiService lessonApi;
  final AssignmentApiService assignmentApi;
  final GroupApiService groupApi;

  static int? idOf(Map<String, dynamic> row) {
    final raw = row['id'];
    return raw is int ? raw : int.tryParse('$raw');
  }

  static String titleOf(Map<String, dynamic> row) =>
      row['title']?.toString() ?? '';

  /// A film this account is drawing of this tutorial right now.
  static bool isRendering(Map<String, dynamic> row) =>
      row['render_job_id'] != null;

  /// A film already rendered and ready to fetch.
  static bool hasVideo(Map<String, dynamic> row) => row['has_video'] == true;

  /// Students this trainer sent the film to who have not downloaded it yet —
  /// what deleting the tutorial would strand (`docs/PLAN-TUTORIJAL-VIDEO.md`,
  /// D13). Zero when the server did not say.
  static int waitingDownloadsOf(Map<String, dynamic> row) {
    final raw = row['waiting_downloads'];
    return raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
  }

  /// What a render's end means for its row: a film to download, and no render
  /// running any more. A hidden render is still running and keeps its place.
  static void _settleRender(Map<String, dynamic> row, RenderJobState? state) {
    if (state == null || state == RenderJobState.running) return;
    row['render_job_id'] = null;
    if (state == RenderJobState.done) row['has_video'] = true;
  }

  /// Asks first, then deletes on the server. Returns true only when the row
  /// is actually gone — a caller must remove it from its own list on true and
  /// leave it exactly where it was on false, because a row still on the
  /// server that vanishes from the screen is the deletion reporting a success
  /// it did not have.
  Future<bool> delete(BuildContext context, Map<String, dynamic> row) async {
    final id = idOf(row);
    if (id == null) return false;

    final choice = await confirmTutorialDelete(context,
        title: titleOf(row),
        hasVideo: hasVideo(row),
        waitingDownloads: waitingDownloadsOf(row));
    if (!context.mounted) return false;
    if (choice == TutorialDeleteChoice.downloadFirst) {
      await downloadTutorialVideo(context, lessonApi, row);
      return false;
    }
    if (choice != TutorialDeleteChoice.delete) return false;

    final error = await lessonApi.delete(id);
    if (!context.mounted) return false;
    if (error != null) {
      AppFeedback.error(context, error);
      return false;
    }
    return true;
  }

  /// Sends [row]'s **film** to a student chosen from this trainer's
  /// **accepted** students only — a relationship nobody has answered grants
  /// nothing, and the server is right to refuse it.
  ///
  /// A tutorial is sent as its video (`docs/PLAN-TUTORIJAL-VIDEO.md`, D5), so
  /// one without a film is not offered students at all: the trainer is told
  /// why and offered the export, which is the way forward.
  Future<void> send(BuildContext context, Map<String, dynamic> row) async {
    final id = idOf(row);
    if (id == null) return;

    if (!hasVideo(row)) {
      final export = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Export the video first'),
          content: Text('A tutorial is sent to a student as its video, and '
              '"${titleOf(row)}" has none yet.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const ValueKey('tutorial-send-export-first'),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Export video'),
            ),
          ],
        ),
      );
      if (export == true && context.mounted) await exportVideo(context, row);
      return;
    }

    final students = await groupApi.myStudents();
    if (!context.mounted) return;

    final accepted = students.where((s) => s['status'] == 'accepted').toList();
    if (accepted.isEmpty) {
      AppFeedback.info(
          context, 'You have no students who have accepted the invitation.');
      return;
    }

    final studentId = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send the video to a student'),
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
    if (!context.mounted || studentId == null) return;

    final result = await assignmentApi.createLessonAssignment(
      studentId: studentId,
      lessonId: id,
      title: titleOf(row),
    );
    if (!context.mounted) return;

    if (!result.success) {
      AppFeedback.error(context, result.error ?? 'Failed to send.');
      return;
    }
    AppFeedback.success(context, 'Video sent to the student.');
  }

  /// Starts a render and marks [row] as rendering the moment the server
  /// accepts it, so a trainer who hides the dialog still finds it on the row.
  Future<RenderJobState?> exportVideo(
    BuildContext context,
    Map<String, dynamic> row,
  ) async {
    final id = idOf(row);
    if (id == null) return null;

    final state = await exportTutorialVideo(
      context: context,
      api: lessonApi,
      lessonId: id,
      title: titleOf(row),
      draft: TutorialDraft.fromLesson(row),
      onStarted: (jobId) => row['render_job_id'] = jobId,
    );
    _settleRender(row, state);
    return state;
  }

  /// Reopens the render already running for [row].
  Future<RenderJobState?> watchRender(
    BuildContext context,
    Map<String, dynamic> row,
  ) async {
    final jobId = row['render_job_id']?.toString();
    if (jobId == null) return null;

    final state = await watchTutorialRender(
        context: context, api: lessonApi, jobId: jobId);
    _settleRender(row, state);
    return state;
  }

  /// Fetches the rendered film and hands it to the platform to open. The link
  /// the server hands out dies in thirty minutes, so this is fetched fresh
  /// every time rather than kept from when the render finished.
  Future<void> downloadVideo(
    BuildContext context,
    Map<String, dynamic> row,
  ) =>
      downloadTutorialVideo(context, lessonApi, row);
}

const _videoGoesToo = '\n\nIts video will be deleted too. Download it first '
    'if you want to keep it.';

String _stranded(int count) => count == 1
    ? '\n\n1 student has not downloaded its video yet, and will not be able to.'
    : '\n\n$count students have not downloaded its video yet, and will not be able to.';

/// What the trainer chose when asked to delete a tutorial.
enum TutorialDeleteChoice { cancel, delete, downloadFirst }

/// Asks before a tutorial is deleted — one dialog for every place that
/// deletes one (the Library and Preparation's column).
///
/// **A rendered video goes with the tutorial** (the owner's decision of
/// 22.9.2026): the film is reached only through the tutorial, so the server
/// deletes it too. When there is one, the dialog says so and offers to
/// download it first; that choice deletes nothing.
///
/// A film sent to students who have not downloaded it yet is stranded by the
/// delete, and this is the only moment the trainer can know — so the dialog
/// says how many ([waitingDownloads], `docs/PLAN-TUTORIJAL-VIDEO.md`, D13).
Future<TutorialDeleteChoice> confirmTutorialDelete(
  BuildContext context, {
  required String title,
  required bool hasVideo,
  int waitingDownloads = 0,
}) async {
  final choice = await showDialog<TutorialDeleteChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete tutorial?'),
      content: Text('"$title" will be permanently deleted, along with all '
          'parts.${hasVideo ? _videoGoesToo : ''}'
          '${waitingDownloads > 0 ? _stranded(waitingDownloads) : ''}'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(TutorialDeleteChoice.cancel),
          child: const Text('Cancel'),
        ),
        if (hasVideo)
          TextButton(
            key: const ValueKey('tutorial-delete-download-first'),
            onPressed: () =>
                Navigator.of(ctx).pop(TutorialDeleteChoice.downloadFirst),
            child: const Text('Download video'),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(TutorialDeleteChoice.delete),
          child: Text('Delete', style: TextStyle(color: ctx.colors.danger)),
        ),
      ],
    ),
  );
  return choice ?? TutorialDeleteChoice.cancel;
}

/// Fetches a tutorial's rendered film and hands it to the platform to open.
/// The link the server hands out dies in thirty minutes, so it is fetched
/// fresh every time rather than kept from when the render finished.
Future<void> downloadTutorialVideo(
  BuildContext context,
  LessonApiService lessonApi,
  Map<String, dynamic> row,
) async {
  final id = TutorialRowActions.idOf(row);
  if (id == null) return;

  final link = await lessonApi.fetchTutorialVideo(id);
  if (!context.mounted) return;

  if (link.ok) {
    await launchUrl(
      Uri.parse(resolveMediaUrl(link.downloadUrl!)),
      mode: LaunchMode.externalApplication,
    );
    return;
  }
  AppFeedback.info(context, link.error ?? 'This tutorial has no video yet.');
  if (link.status == LessonVideoStatus.expired) {
    row['has_video'] = false;
  }
}
