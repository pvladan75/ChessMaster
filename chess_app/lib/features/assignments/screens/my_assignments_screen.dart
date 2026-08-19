import 'package:flutter/material.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/features/tactics_trainer/screens/tactics_trainer_screen.dart';
import '../models/assignment.dart';
import '../services/assignment_api_service.dart';
import 'lesson_viewer_screen.dart';
import 'custom_puzzle_solver_screen.dart';

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

  Future<void> _open(Assignment assignment) async {
    final detail = await _api.fetchDetail(assignment.id);
    if (!mounted) return;

    if (detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ne mogu da otvorim zadatak.')),
      );
      return;
    }

    if (assignment.kind == AssignmentKind.lesson) {
      if (detail.steps.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ova lekcija više nije dostupna.')),
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              LessonViewerScreen(session: widget.session, detail: detail),
        ),
      );
      if (mounted) _refresh();
      return;
    }

    // Homework built from the trainer's own positions is solved on its own
    // screen: those carry a written task and one move, while the Lichess set is
    // a forced line, and one screen serving both would branch at every step.
    if (detail.isCustom) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CustomPuzzleSolverScreen(session: widget.session, detail: detail),
        ),
      );
      if (mounted) _refresh();
      return;
    }

    final pending = detail.pending;
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ovaj zadatak je već završen.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TacticsTrainerScreen(
          session: widget.session,
          assignmentId: assignment.id,
          assignmentTitle: assignment.title,
          // Only what is left, so returning to a half-done assignment picks up
          // where the student stopped instead of starting over.
          puzzleIds: pending.map((item) => item.puzzleId!).toList(),
        ),
      ),
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
                padding: const EdgeInsets.all(16),
                children: [
                  if (_progress != null) _buildProgressCard(_progress!),
                  const SizedBox(height: 16),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Vaš napredak',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 13),
              )
            else ...[
              Text(
                'Poslednjih ${progress.periodDays} dana: ${progress.totalAttempts} zagonetki, '
                'tačnost ${progress.accuracy}%, aktivnih dana ${progress.activeDays}.',
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 13),
              ),
              if (progress.weakestThemes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Najviše grešite: '
                  '${progress.weakestThemes.take(3).map((t) => themeLabel(t.theme)).join(', ')}.',
                  style: const TextStyle(fontSize: 13),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        // A finished lesson stays open: re-reading it is the point, unlike a
        // puzzle set where the answers are already known.
        onTap: done && !isLesson ? null : () => _open(assignment),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                Text(assignment.instructions!,
                    style: const TextStyle(fontSize: 13)),
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
                style: TextStyle(
                    fontSize: 12, color: context.colors.textSecondary),
              ),
              if (assignment.dueAt != null)
                Text(
                  overdue
                      ? 'Rok je istekao'
                      : 'Rok: ${assignment.dueAt!.day}.${assignment.dueAt!.month}.${assignment.dueAt!.year}.',
                  style: TextStyle(
                    fontSize: 12,
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
            ],
          ),
        ),
      ),
    );
  }
}
