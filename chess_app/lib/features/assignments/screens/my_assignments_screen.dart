import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/routing/app_routes.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import '../models/assignment.dart';
import '../services/assignment_api_service.dart';
import 'package:chess_app/widgets/app_feedback.dart';

/// What a student sees: the homework they have been set, and what is left.
class MyAssignmentsScreen extends StatefulWidget {
  const MyAssignmentsScreen({super.key, required this.session});

  final UserSession session;

  @override
  State<MyAssignmentsScreen> createState() => _MyAssignmentsScreenState();
}

class _MyAssignmentsScreenState extends State<MyAssignmentsScreen> {
  late final AssignmentApiService _api;
  List<Assignment> _assignments = const [];
  StudentProgress? _progress;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _api = AssignmentApiService(authToken: widget.session.token);
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

  Future<void> _open(Assignment assignment) async {
    final detail = await _api.fetchDetail(assignment.id);
    if (!mounted) return;

    if (detail == null) {
      AppFeedback.show(
        context,
        () => const SnackBar(content: Text('Ne mogu da otvorim zadatak.')),
      );
      return;
    }

    if (assignment.kind == AssignmentKind.lesson) {
      if (detail.steps.isEmpty) {
        AppFeedback.show(
          context,
          () =>
              const SnackBar(content: Text('Ova lekcija više nije dostupna.')),
        );
        return;
      }

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
        () => const SnackBar(content: Text('Ovaj zadatak je već završen.')),
      );
      return;
    }

    await context.push(
      AppRoutes.assignmentTacticsPath(assignment.id),
      extra: detail,
    );

    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(title: const Text('Moji zadaci')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  if (_progress != null) _buildProgressCard(_progress!),
                  const SizedBox(height: AppSpacing.lg),
                  if (_assignments.isEmpty)
                    _buildEmpty()
                  else
                    ..._assignments.map(_buildAssignmentCard),
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
            'Nemate zadatih vežbi.',
            style: TextStyle(color: context.colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(StudentProgress progress) {
    return Card(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Vaš napredak', style: AppText.title),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.military_tech, size: 16),
                  label: Text('${progress.overallRating}'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!progress.hasData)
              Text(
                'Još nema podataka — rešite nekoliko zagonetki.',
                style: AppText.bodyLarge
                    .copyWith(color: context.colors.textSecondary),
              )
            else ...[
              Text(
                'Poslednjih ${progress.periodDays} dana: ${progress.totalAttempts} zagonetki, '
                'tačnost ${progress.accuracy}%, aktivnih dana ${progress.activeDays}.',
                style: AppText.bodyLarge
                    .copyWith(color: context.colors.textSecondary),
              ),
              if (progress.weakestThemes.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Najviše grešite: '
                  '${progress.weakestThemes.take(3).map((t) => themeLabel(t.theme)).join(', ')}.',
                  style: AppText.bodyLarge,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    final overdue = assignment.isOverdue;
    final done = assignment.isComplete;
    final isLesson = assignment.kind == AssignmentKind.lesson;

    return Card(
      color: context.colors.surface,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        // A finished lesson stays open: re-reading it is the point. A finished
        // puzzle set has nothing left to solve, so tapping it now opens the
        // review — which is where the answers finally are.
        onTap: done && !isLesson
            ? () => _openReview(assignment)
            : () => _open(assignment),
        borderRadius: AppRadii.roundedMd,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    done
                        ? Icons.check_circle
                        : (overdue
                            ? Icons.warning_amber
                            : (isLesson ? Icons.menu_book : Icons.assignment)),
                    color: done
                        ? context.colors.success
                        : (overdue
                            ? context.colors.danger
                            : context.colors.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      assignment.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ],
              ),
              if (assignment.instructions != null &&
                  assignment.instructions!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(assignment.instructions!, style: AppText.bodyLarge),
              ],
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: assignment.progress,
                backgroundColor: context.colors.surfaceRaised,
              ),
              const SizedBox(height: 6),
              Text(
                isLesson
                    ? '${assignment.attemptedItems} / ${assignment.totalItems} koraka pregledano'
                    : '${assignment.attemptedItems} / ${assignment.totalItems} urađeno'
                        '${assignment.accuracy == null ? '' : ' · tačnost ${assignment.accuracy}%'}',
                style:
                    AppText.body.copyWith(color: context.colors.textSecondary),
              ),
              if (assignment.dueAt != null)
                Text(
                  overdue
                      ? 'Rok je istekao'
                      : 'Rok: ${assignment.dueAt!.day}.${assignment.dueAt!.month}.${assignment.dueAt!.year}.',
                  style: AppText.body.copyWith(
                    color: overdue
                        ? context.colors.danger
                        : context.colors.textMuted,
                  ),
                ),
              if (assignment.trainerName != null)
                Text(
                  'Zadao: ${assignment.trainerName}',
                  style: TextStyle(
                      fontSize: 11.5, color: context.colors.textMuted),
                ),
              if (assignment.attemptedItems > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _openReview(assignment),
                    icon: const Icon(Icons.rate_review_outlined, size: 16),
                    label:
                        const Text('Pregled i komentari', style: AppText.body),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
