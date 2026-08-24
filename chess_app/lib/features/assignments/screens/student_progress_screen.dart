import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/routing/app_routes.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import '../models/assignment.dart';
import '../services/assignment_api_service.dart';
import '../widgets/assign_lesson_dialog.dart';
import '../widgets/create_assignment_dialog.dart';
import '../widgets/parent_report_dialog.dart';

/// A trainer's view of one student: how they are doing, what has been set, and
/// the shortest path to setting more.
///
/// The report leads with what the trainer would otherwise have to work out by
/// hand — which motifs the student keeps failing — and the "set homework" button
/// arrives with exactly those motifs pre-selected.
class StudentProgressScreen extends StatefulWidget {
  const StudentProgressScreen({
    super.key,
    required this.session,
    required this.studentId,
    required this.studentName,
  });

  final UserSession session;
  final int studentId;
  final String studentName;

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  late final AssignmentApiService _api;
  StudentProgress? _progress;
  List<Assignment> _assignments = const [];
  bool _loading = true;
  int _days = 30;

  @override
  void initState() {
    super.initState();
    _api = AssignmentApiService(authToken: widget.session.token);
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      _api.fetchProgress(studentId: widget.studentId, days: _days),
      _api.fetchGiven(studentId: widget.studentId),
    ]);
    if (!mounted) return;

    setState(() {
      _progress = results[0] as StudentProgress?;
      _assignments = results[1] as List<Assignment>;
      _loading = false;
    });
  }

  Future<void> _createAssignment() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => CreateAssignmentDialog(
        api: _api,
        studentId: widget.studentId,
        studentName: widget.studentName,
        suggestedThemes:
            _progress?.weakestThemes.map((t) => t.theme).toList() ?? const [],
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zadatak je poslat učeniku.')),
      );
      _refresh();
    }
  }

  Future<void> _assignLesson() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => AssignLessonDialog(
        api: _api,
        session: widget.session,
        studentId: widget.studentId,
        studentName: widget.studentName,
      ),
    );

    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lekcija je poslata učeniku.')),
      );
      _refresh();
    }
  }

  Future<void> _openReview(Assignment assignment) async {
    await context.push(AppRoutes.assignmentReviewPath(
      assignment.id,
      title: assignment.title,
    ));
    if (mounted) _refresh();
  }

  Future<void> _deleteAssignment(Assignment assignment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Povući zadatak?'),
        content: Text('"${assignment.title}" će nestati sa učenikove liste, '
            'zajedno sa onim što je već urađeno.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Otkaži')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Povuci'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final error = await _api.delete(assignment.id);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(
        title: Text(widget.studentName),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize),
            tooltip: 'Izveštaj za roditelja',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => ParentReportDialog(
                api: _api,
                studentId: widget.studentId,
                studentName: widget.studentName,
              ),
            ),
          ),
          PopupMenuButton<int>(
            tooltip: 'Period',
            initialValue: _days,
            onSelected: (value) {
              setState(() => _days = value);
              _refresh();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 7, child: Text('Poslednjih 7 dana')),
              PopupMenuItem(value: 30, child: Text('Poslednjih 30 dana')),
              PopupMenuItem(value: 90, child: Text('Poslednjih 90 dana')),
            ],
            icon: const Icon(Icons.date_range),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'assign-lesson',
            onPressed: _assignLesson,
            icon: const Icon(Icons.menu_book),
            label: const Text('Zadaj lekciju'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'assign-puzzles',
            onPressed: _createAssignment,
            icon: const Icon(Icons.add_task),
            label: const Text('Zadaj vežbu'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  _buildSummary(),
                  const SizedBox(height: 16),
                  _buildThemes(),
                  const SizedBox(height: 16),
                  _buildAssignments(),
                ],
              ),
            ),
    );
  }

  Widget _buildSummary() {
    final progress = _progress;
    if (progress == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Izveštaj nije dostupan.'),
        ),
      );
    }

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
                  child: Text('Pregled',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.military_tech, size: 16),
                  label: Text('Rejting ${progress.overallRating}'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!progress.hasData)
              Text(
                'Učenik nije rešavao zagonetke u poslednjih ${progress.periodDays} dana.',
                style: TextStyle(color: context.colors.textSecondary),
              )
            else
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  _stat('Rešeno',
                      '${progress.solvedAttempts}/${progress.totalAttempts}'),
                  // Null accuracy is rendered as a dash, never as 0%.
                  _stat(
                      'Tačnost',
                      progress.accuracy == null
                          ? '—'
                          : '${progress.accuracy}%'),
                  _stat('Aktivnih dana', '${progress.activeDays}'),
                  _stat('Ukupno rešeno', '${progress.lifetimeSolved}'),
                ],
              ),
            const SizedBox(height: 12),
            Divider(color: context.colors.border),
            const SizedBox(height: 4),
            Text(
              'Zadaci: ${progress.assignmentsCompleted}/${progress.assignmentsTotal} završeno'
              '${progress.assignmentsOverdue > 0 ? ' · ${progress.assignmentsOverdue} van roka' : ''}',
              style: TextStyle(
                fontSize: 13,
                color: progress.assignmentsOverdue > 0
                    ? context.colors.danger
                    : context.colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(fontSize: 11.5, color: context.colors.textMuted)),
      ],
    );
  }

  Widget _buildThemes() {
    final progress = _progress;
    if (progress == null || progress.weakestThemes.isEmpty) {
      return Card(
        color: context.colors.surface,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Još nema dovoljno pokušaja da bi se izdvojile slabe teme. '
            'Tema ulazi u izveštaj tek posle nekoliko rešenih zagonetki.',
            style: TextStyle(color: context.colors.textSecondary, fontSize: 13),
          ),
        ),
      );
    }

    return Card(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Po temama',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              'Prikazane su samo teme sa dovoljno pokušaja da broj nešto znači.',
              style: TextStyle(fontSize: 11.5, color: context.colors.textMuted),
            ),
            const SizedBox(height: 12),
            ...progress.weakestThemes
                .map((theme) => _themeRow(theme, weak: true)),
            if (progress.strongestThemes.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...progress.strongestThemes
                  .take(3)
                  .map((theme) => _themeRow(theme, weak: false)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _themeRow(ThemeAccuracy theme, {required bool weak}) {
    final accuracy = theme.accuracy ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Proportional rather than fixed: a long motif name plus a fixed bar
          // and a fixed number leaves nothing on a narrow phone.
          Expanded(
            flex: 5,
            child: Text(
              themeLabel(theme.theme),
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: accuracy / 100,
                minHeight: 7,
                backgroundColor: context.colors.surfaceRaised,
                color: weak ? context.colors.warning : context.colors.success,
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 74,
            child: Text(
              '$accuracy% (${theme.attempts})',
              style:
                  TextStyle(fontSize: 12, color: context.colors.textSecondary),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignments() {
    return Card(
      color: context.colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Zadaci',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (_assignments.isEmpty)
              Text(
                'Još niste zadali nijednu vežbu ovom učeniku.',
                style: TextStyle(
                    color: context.colors.textSecondary, fontSize: 13),
              )
            else
              ..._assignments.map((assignment) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    // Opens what actually happened, position by position. The
                    // numbers on this row say that something went wrong; only
                    // the review says where.
                    onTap: () => _openReview(assignment),
                    leading: Icon(
                      assignment.isComplete
                          ? Icons.check_circle
                          : (assignment.isOverdue
                              ? Icons.warning_amber
                              : Icons.assignment),
                      color: assignment.isComplete
                          ? context.colors.success
                          : (assignment.isOverdue
                              ? context.colors.danger
                              : context.colors.accent),
                    ),
                    title: Text(assignment.title,
                        style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '${assignment.attemptedItems}/${assignment.totalItems} urađeno'
                      '${assignment.accuracy == null ? '' : ' · tačnost ${assignment.accuracy}%'}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Povuci zadatak',
                      onPressed: () => _deleteAssignment(assignment),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
