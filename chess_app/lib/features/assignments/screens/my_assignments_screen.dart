import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/routing/app_routes.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import '../models/assignment.dart';
import '../services/assignment_api_service.dart';
import 'package:chess_app/widgets/adaptive_card_grid.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// Which of the student's assignments the list shows. Open and Done are
/// counted from the very list they filter (phase 11 of docs/PLAN-EKRANI.md):
/// one predicate, `_isDone`, decides both the number on the chip and the cards
/// under it.
enum _Filter { open, done, all }

/// What a student sees: the homework they have been set, and what is left.
class MyAssignmentsScreen extends StatefulWidget {
  const MyAssignmentsScreen({super.key, required this.session, this.api});

  final UserSession session;

  /// For tests, which have no server to answer.
  final AssignmentApiService? api;

  @override
  State<MyAssignmentsScreen> createState() => _MyAssignmentsScreenState();
}

class _MyAssignmentsScreenState extends State<MyAssignmentsScreen> {
  late final AssignmentApiService _api;
  List<Assignment> _assignments = const [];
  StudentProgress? _progress;
  bool _loading = true;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? AssignmentApiService(authToken: widget.session.token);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _api.fetchMine(),
      _api.fetchProgress(),
    ]);
    if (!mounted) return;

    setState(() {
      _assignments = results[0] as List<Assignment>;
      _progress = results[1] as StudentProgress?;
      _loading = false;
    });
  }

  /// What was done and what was said about it. Reachable while an assignment is
  /// still open, not only once it is finished: a student stuck on the third
  /// position has something to ask about right then.
  Future<void> _openReview(Assignment assignment) async {
    await context.push(
      AppRoutes.assignmentReviewPath(assignment.id, title: assignment.title),
    );
    if (mounted) _refresh();
  }

  /// A homework opens on its own screen (`HomeworkAssignmentScreen`), never
  /// on the item-picking logic below — a parent has no items of its own.
  Future<void> _openHomework(Assignment assignment) async {
    await context.push(AppRoutes.assignmentHomeworkPath(assignment.id));
    if (mounted) _refresh();
  }

  Future<void> _open(Assignment assignment) async {
    final result = await _api.fetchDetail(assignment.id);
    if (!mounted) return;
    final detail = result.detail;

    if (detail == null) {
      AppFeedback.show(
        context,
        () => SnackBar(
          content: Text(result.locked
              ? 'This item is locked until an earlier one is done.'
              : 'Could not open assignment.'),
        ),
      );
      return;
    }

    if (assignment.kind == AssignmentKind.lesson) {
      // A tutorial's film (docs/PLAN-TUTORIJAL-VIDEO.md). The screen says so
      // itself when the film is gone.
      //
      // The detail is already in hand, so it rides along and the route does not
      // fetch it again. Opened cold - a link, a restored session - the same
      // path fetches by id instead.
      await context.push(
        AppRoutes.assignmentLessonPath(detail.assignment.id),
        extra: detail,
      );
      if (mounted) _refresh();
      return;
    }

    // Homework built from the trainer's own positions is solved on its own
    // screen: those carry a written task and one move, while the Lichess set is
    // a forced line, and one screen serving both would branch at every step.
    //
    // It opens on the whole set rather than on the next unanswered position.
    // A child stuck on the third one could not reach the fourth before, and
    // seeing what is coming is part of how homework gets planned.
    if (detail.isCustom) {
      await context.push(
        AppRoutes.assignmentOverviewPath(detail.assignment.id),
        extra: detail,
      );
      if (mounted) _refresh();
      return;
    }

    final pending = detail.pending;
    if (pending.isEmpty) {
      AppFeedback.show(
        context,
        () => const SnackBar(
            content: Text('This assignment is already completed.')),
      );
      return;
    }

    await context.push(
      AppRoutes.assignmentTacticsPath(assignment.id),
      extra: detail,
    );

    if (mounted) _refresh();
  }

  /// A homework is done when every one of its items is; every other kind
  /// when the server says so or every item has been attempted. A homework's
  /// own `isComplete` reads item counters it does not have.
  bool _isDone(Assignment a) => a.isHomework
      ? a.childTotal > 0 && a.childCompleted >= a.childTotal
      : a.isComplete;

  @override
  Widget build(BuildContext context) {
    final openCount = _assignments.where((a) => !_isDone(a)).length;
    final doneCount = _assignments.length - openCount;
    final shown = switch (_filter) {
      _Filter.open => _assignments.where((a) => !_isDone(a)).toList(),
      _Filter.done => _assignments.where(_isDone).toList(),
      _Filter.all => _assignments,
    };

    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(title: const Text('My Assignments')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_progress != null) ...[
                    _buildProgressCard(_progress!),
                    const SizedBox(height: AppSpacing.md),
                  ],
                  if (_assignments.isEmpty)
                    _buildEmpty()
                  else ...[
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        for (final (filter, label) in [
                          (_Filter.open, 'Open ($openCount)'),
                          (_Filter.done, 'Done ($doneCount)'),
                          (_Filter.all, 'All (${_assignments.length})'),
                        ])
                          ChoiceChip(
                            key: Key('assignments-filter-${filter.name}'),
                            label: Text(label),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          _filter == _Filter.open
                              ? 'Nothing is open.'
                              : 'Nothing is done yet.',
                          style: TextStyle(color: context.colors.textSecondary),
                        ),
                      )
                    else
                      // Row by row, each row as tall as its tallest card: a
                      // fixed cell cut the trainer's instruction to one line
                      // (grading, 3.10.2026).
                      AdaptiveCardRows(
                        children: [
                          for (final assignment in shown)
                            _buildAssignmentCard(assignment),
                        ],
                      ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.inbox, size: 44, color: context.colors.textMuted),
          const SizedBox(height: 10),
          Text(
            'You have no assigned drills.',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }

  /// One row — the title and the rating, the sentence of figures, and the
  /// weakest themes — which wraps onto more only where the window is too
  /// narrow to hold them side by side.
  Widget _buildProgressCard(StudentProgress progress) {
    final muted =
        AppText.bodyLarge.copyWith(color: context.colors.textSecondary);
    return Card(
      margin: EdgeInsets.zero,
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        child: Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Your Progress', style: AppText.title),
                const SizedBox(width: AppSpacing.md),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.military_tech, size: 16),
                  label: Text('${progress.overallRating}'),
                ),
              ],
            ),
            if (!progress.hasData)
              Text('No data yet — solve a few puzzles.', style: muted)
            else ...[
              // Counted as the Practise cards count: each puzzle once, a
              // skip apart, and the share of new puzzles solved at the first
              // attempt — absent rather than „null%" when there were none.
              Text(
                key: const Key('my-progress-line'),
                'Last ${progress.periodDays} days: '
                '${progress.puzzles} ${progress.puzzles == 1 ? 'puzzle' : 'puzzles'}, ${progress.solved} solved'
                '${progress.skipped > 0 ? ', ${progress.skipped} skipped' : ''}'
                '${progress.accuracy == null ? '' : ', ${progress.accuracy}% at the first attempt'}'
                ', ${progress.activeDays} active ${progress.activeDays == 1 ? 'day' : 'days'}.',
                style: muted,
              ),
              if (progress.weakestThemes.isNotEmpty)
                Text(
                  'Most mistakes: '
                  '${progress.weakestThemes.take(3).map((t) => themeLabel(t.theme)).join(', ')}.',
                  style: AppText.bodyLarge,
                ),
            ],
          ],
        ),
      ),
    );
  }

  /// One card of the grid, whatever the assignment is. A homework has no
  /// puzzles or steps of its own, only children, so it reads `child_total` /
  /// `child_completed` rather than the item counters every other kind uses, and
  /// it has no review of its own (the parent holds no answers). A film has one
  /// thing to do, so no bar — only whether it happened.
  ///
  /// The action stands beside the card's own figures, not alone at the far
  /// edge of a row.
  Widget _buildAssignmentCard(Assignment assignment) {
    final isHomework = assignment.isHomework;
    final isLesson = assignment.kind == AssignmentKind.lesson;
    final done = _isDone(assignment);
    final overdue = !isHomework && assignment.isOverdue;

    final IconData icon;
    final Color iconColor;
    if (done) {
      icon = Icons.check_circle;
      iconColor = context.colors.success;
    } else if (overdue) {
      icon = Icons.warning_amber;
      iconColor = context.colors.danger;
    } else {
      icon = isHomework
          ? Icons.assignment_turned_in
          : (isLesson ? Icons.movie_outlined : Icons.assignment);
      iconColor = context.colors.accent;
    }

    final String figures = isHomework
        ? assignment.itemsSummary
        : isLesson
            ? (done ? 'Video · downloaded' : 'Video · not downloaded yet')
            : '${assignment.attemptedItems} / ${assignment.totalItems} completed'
                '${assignment.accuracy == null ? '' : ' · accuracy ${assignment.accuracy}%'}';

    final due = assignment.dueAt;
    final String? status = done && !isHomework
        ? null
        : overdue
            ? 'Overdue'
            : due == null
                ? null
                : 'Due: ${due.day}.${due.month}.${due.year}.';

    return Card(
      key: Key('assignment-row-${assignment.id}'),
      color: context.colors.surface,
      margin: EdgeInsets.zero,
      child: InkWell(
        // A downloaded film stays open: downloading it again is always
        // allowed. A finished puzzle set has nothing left to solve, so tapping
        // it now opens the review — which is where the answers finally are.
        onTap: isHomework
            ? () => _openHomework(assignment)
            : done && !isLesson
                ? () => _openReview(assignment)
                : () => _open(assignment),
        borderRadius: AppRadii.roundedMd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      assignment.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  if (status != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      status,
                      style: AppText.body.copyWith(
                        color: overdue
                            ? context.colors.danger
                            : context.colors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
              if (assignment.instructions != null &&
                  assignment.instructions!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child:
                      Text(assignment.instructions!, style: AppText.bodyLarge),
                ),
              const SizedBox(height: AppSpacing.sm),
              if (!isLesson) ...[
                LinearProgressIndicator(
                  value: assignment.progress,
                  backgroundColor: context.colors.surfaceRaised,
                ),
                const SizedBox(height: 6),
              ],
              Text(
                figures,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppText.body.copyWith(color: context.colors.textSecondary),
              ),
              // The action beside the card's own facts: who set it, and the
              // way into what was done and said about it.
              Row(
                children: [
                  Expanded(
                    child: assignment.trainerName == null
                        ? const SizedBox(height: 32)
                        : Text(
                            'Assigned by: ${assignment.trainerName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: context.colors.textMuted),
                          ),
                  ),
                  if (!isHomework && assignment.attemptedItems > 0)
                    TextButton.icon(
                      style: const ButtonStyle(
                          visualDensity: VisualDensity.compact),
                      onPressed: () => _openReview(assignment),
                      icon: const Icon(Icons.rate_review_outlined, size: 16),
                      label: const Text('Review and comments',
                          style: AppText.body),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
