import 'package:flutter/material.dart';

import 'package:chess_app/theme/app_colors.dart';
import '../models/trainer_panel.dart';

/// The trainer's panel: what the job is right now, above the list of people.
///
/// A section inside the "Ljudi" tab rather than a fifth tab of its own.
/// Teaching is a position in a relationship, not a property of an account, so a
/// destination in the navigation bar would be empty for everybody who teaches
/// nobody — which is most of the people who open this app, and almost all of
/// the children. The tab that already exists because of a relationship is the
/// one this belongs in.
///
/// Nothing here is drawn unless there is something to say. Four headings over
/// four empty lists read as a screen that failed to load, so an empty panel is
/// no panel at all.
class TrainerPanelView extends StatelessWidget {
  final TrainerPanel panel;

  /// Enters a room this trainer is hosting. Takes the code rather than a route:
  /// the screen that owns the session decides how a room is opened.
  final void Function(String roomCode) onEnterLesson;

  /// Opens one assignment's review, and marks it looked at.
  final void Function(PanelAssignment assignment) onOpenAssignment;

  /// Opens a student's progress — which is also the screen where the next
  /// exercise is set.
  final void Function(int studentId, String name) onOpenStudent;

  const TrainerPanelView({
    super.key,
    required this.panel,
    required this.onEnterLesson,
    required this.onOpenAssignment,
    required this.onOpenStudent,
  });

  @override
  Widget build(BuildContext context) {
    if (panel.isEmpty) return const SizedBox.shrink();
    final colors = context.colors;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today, color: colors.accent, size: 28),
                const SizedBox(width: 12),
                // Expanded, not a bare Text: at 360 px a title next to an icon
                // is wider than the card, and a release build clips it in
                // silence instead of striping it.
                const Expanded(
                  child: Text(
                    'Panel trenera',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (panel.today.isNotEmpty)
              _section(
                context,
                title: 'Danas',
                color: colors.accent,
                children: [
                  for (final lesson in panel.today) _lessonRow(context, lesson),
                ],
              ),
            if (panel.awaitingReview.isNotEmpty)
              _section(
                context,
                title: 'Za pregled',
                color: colors.success,
                count: panel.awaitingReview.length,
                children: [
                  for (final a in panel.awaitingReview) _reviewRow(context, a),
                ],
              ),
            if (panel.dueSoon.isNotEmpty)
              _section(
                context,
                title: 'Domaći ističe',
                color: colors.warning,
                count: panel.dueSoon.length,
                children: [
                  for (final a in panel.dueSoon) _dueRow(context, a),
                ],
              ),
            if (panel.stalled.isNotEmpty)
              _section(
                context,
                title: 'Domaći stoji',
                color: colors.info,
                count: panel.stalled.length,
                children: [
                  for (final a in panel.stalled) _stalledRow(context, a),
                ],
              ),
            if (panel.idle.isNotEmpty)
              _section(
                context,
                title: 'Nije vežbao',
                color: colors.textMuted,
                children: [
                  for (final s in panel.idle) _idleRow(context, s),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// One heading and its rows.
  ///
  /// The heading is a [Wrap] rather than a [Row]: "Domaći ističe" beside its
  /// count is close to the width of a 360 px card, and a heading that grows by
  /// one digit is exactly the row that overflows on a phone and nowhere else.
  Widget _section(
    BuildContext context, {
    required String title,
    required Color color,
    required List<Widget> children,
    int? count,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  color: color,
                ),
              ),
              if (count != null && count > 1)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(fontSize: 12, color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  /// A card: what it is on the left, what to do about it on the right.
  ///
  /// The text side is [Expanded] so a long student name shortens itself
  /// instead of pushing the button off the edge of the screen.
  Widget _card(
    BuildContext context, {
    required String title,
    required String subtitle,
    String? note,
    Color? noteColor,
    required String action,
    required VoidCallback onAction,
    bool filled = false,
    Widget? leading,
  }) {
    final colors = context.colors;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: filled ? colors.surfaceRaised : colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
                if (note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    note,
                    style: TextStyle(
                        fontSize: 12, color: noteColor ?? colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          filled
              ? ElevatedButton(onPressed: onAction, child: Text(action))
              : OutlinedButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }

  Widget _lessonRow(BuildContext context, PanelLesson lesson) {
    final colors = context.colors;
    final guests =
        lesson.guests.isEmpty ? 'bez pozvanih' : lesson.guests.join(', ');

    return _card(
      context,
      filled: true,
      leading: SizedBox(
        width: 46,
        child: Text(
          _hhmm(lesson.scheduledAt),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
      ),
      title: lesson.title,
      subtitle: guests,
      note: 'soba ${lesson.roomCode}',
      noteColor: colors.textMuted,
      action: 'Uđi',
      onAction: () => onEnterLesson(lesson.roomCode),
    );
  }

  Widget _reviewRow(BuildContext context, PanelAssignment a) {
    return _card(
      context,
      filled: true,
      title: '${a.studentName} · ${a.title}',
      subtitle:
          '${a.solvedItems} od ${a.totalItems} tačno${_accuracy(a) ?? ''}',
      note: 'predato ${_ago(a.completedAt)}',
      action: 'Pregledaj',
      onAction: () => onOpenAssignment(a),
    );
  }

  Widget _dueRow(BuildContext context, PanelAssignment a) {
    final colors = context.colors;
    final overdue = a.dueAt != null && a.dueAt!.isBefore(DateTime.now());

    return _card(
      context,
      title: '${a.studentName} · ${a.title}',
      subtitle: '${a.attemptedItems} od ${a.totalItems} urađeno',
      note:
          overdue ? 'rok je istekao ${_ago(a.dueAt)}' : 'rok ${_due(a.dueAt)}',
      noteColor: overdue ? colors.danger : colors.warning,
      action: 'Otvori',
      onAction: () => onOpenAssignment(a),
    );
  }

  /// Homework nobody has moved for days, deadline or no deadline.
  ///
  /// The note says which of the two it is, because the trainer's next move
  /// differs: work with no date was never given one, and work with a distant
  /// date is simply being left for later.
  Widget _stalledRow(BuildContext context, PanelAssignment a) {
    final never = a.attemptedItems == 0;

    return _card(
      context,
      title: '${a.studentName} · ${a.title}',
      subtitle: never
          ? 'nije ni otvoren · ${a.totalItems} zadataka'
          : 'stao na ${a.attemptedItems} od ${a.totalItems}',
      note: a.dueAt == null
          ? 'bez roka · ${_ago(a.lastMoveAt)}'
          : 'rok ${_due(a.dueAt)} · ${_ago(a.lastMoveAt)}',
      action: 'Otvori',
      onAction: () => onOpenAssignment(a),
    );
  }

  Widget _idleRow(BuildContext context, PanelIdleStudent s) {
    return _card(
      context,
      title: s.name,
      // No open homework, by construction: a student with work outstanding is
      // in "Domaći stoji" instead, where the sentence about them is useful.
      subtitle: s.lastActiveAt == null
          ? 'nema zadatog domaćeg · još nije rešio nijedan zadatak'
          : 'nema zadatog domaćeg · poslednji put ${_ago(s.lastActiveAt)}',
      action: 'Otvori',
      onAction: () => onOpenStudent(s.id, s.name),
    );
  }

  /// Accuracy, only when there is something to be accurate about. A "0%" over
  /// an empty assignment says the student failed at nothing.
  String? _accuracy(PanelAssignment a) {
    if (a.totalItems == 0) return null;
    return ' · ${(a.solvedItems * 100 / a.totalItems).round()}%';
  }
}

String _hhmm(DateTime? at) {
  if (at == null) return '--:--';
  return '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
}

/// How long ago, in the words a person would use.
///
/// Days rather than dates, because every one of these is recent by
/// construction — the panel only shows what is current — and "pre 3 dana" is
/// read faster than a date the reader has to subtract from today.
String _ago(DateTime? at) {
  if (at == null) return 'nepoznato kada';
  final days = DateTime.now().difference(at).inDays;
  if (days <= 0) return 'danas';
  if (days == 1) return 'juče';
  return 'pre $days dana';
}

/// When a deadline falls, for a deadline that has not passed yet.
String _due(DateTime? at) {
  if (at == null) return 'bez roka';
  final now = DateTime.now();
  final days = at.difference(now).inDays;
  if (at.day == now.day && days == 0) return 'danas u ${_hhmm(at)}';
  if (days < 1) return 'sutra u ${_hhmm(at)}';
  return 'za $days dana';
}
