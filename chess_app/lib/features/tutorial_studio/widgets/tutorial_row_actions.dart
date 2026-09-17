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

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tutorial?'),
        content:
            Text('"${titleOf(row)}" will be permanently deleted, along with '
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
    if (confirmed != true || !context.mounted) return false;

    final error = await lessonApi.delete(id);
    if (!context.mounted) return false;
    if (error != null) {
      AppFeedback.error(context, error);
      return false;
    }
    AppFeedback.success(context, 'Tutorial deleted.');
    return true;
  }

  /// Sends [row] to a student chosen from this trainer's **accepted**
  /// students only — a relationship nobody has answered grants nothing, and
  /// the server is right to refuse it.
  Future<void> send(BuildContext context, Map<String, dynamic> row) async {
    final id = idOf(row);
    if (id == null) return;

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
    AppFeedback.success(context, 'Tutorial sent to student.');
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
  ) async {
    final id = idOf(row);
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
}
