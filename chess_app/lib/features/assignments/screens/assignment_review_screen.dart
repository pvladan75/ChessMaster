import 'package:flutter/material.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import '../models/assignment_review.dart';
import '../services/assignment_api_service.dart';

/// What happened on one piece of homework, and a place to say something about
/// it.
///
/// Both sides open the same screen. Before it, homework ended as two numbers —
/// "2/2 urađeno, tačnost 100%" — and nobody could look at a single position to
/// see which board the child had and what they played. That is the part that
/// says *why*, and the only part worth teaching from.
class AssignmentReviewScreen extends StatefulWidget {
  const AssignmentReviewScreen({
    super.key,
    required this.session,
    required this.assignmentId,
    required this.title,
  });

  final UserSession session;
  final int assignmentId;
  final String title;

  @override
  State<AssignmentReviewScreen> createState() => _AssignmentReviewScreenState();
}

class _AssignmentReviewScreenState extends State<AssignmentReviewScreen> {
  late final AssignmentApiService _api =
      AssignmentApiService(authToken: widget.session.token);

  AssignmentReview? _review;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final review = await _api.fetchReview(widget.assignmentId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _failed = review == null;
      _review = review;
    });
  }

  /// Writes one note — about the whole assignment, or about one position.
  Future<void> _writeNote({int? itemId, required String prompt}) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(prompt, style: const TextStyle(fontSize: 16)),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'npr. ovu nisam razumeo',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Odustani')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Pošalji')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.isEmpty || !mounted) return;

    final result = await _api.addNote(
      assignmentId: widget.assignmentId,
      body: text,
      itemId: itemId,
    );
    if (!mounted) return;

    if (result.note == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Poruka nije poslata.')),
      );
      return;
    }
    setState(() => _review = _review?.withNote(result.note!));
  }

  Future<void> _deleteNote(AssignmentNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Obrisati poruku?'),
        content: Text(note.body, maxLines: 4, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Otkaži')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Obriši')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await _api.deleteNote(
        assignmentId: widget.assignmentId, noteId: note.id);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _review = _review?.withoutNote(note.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(title: Text(_review?.title ?? widget.title)),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    final colors = context.colors;
    if (_loading) return const Center(child: CircularProgressIndicator());

    // "Not reachable" and "nothing here" must not look the same.
    if (_failed || _review == null) {
      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          Icon(Icons.cloud_off, size: 40, color: colors.textMuted),
          const SizedBox(height: 12),
          const Text('Ne mogu da učitam pregled.', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Center(
            child: FilledButton(
                onPressed: _load, child: const Text('Pokušaj opet')),
          ),
        ],
      );
    }

    final review = _review!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summary(review),
        const SizedBox(height: 12),
        _generalNotes(review),
        const SizedBox(height: 16),
        if (review.items.isEmpty)
          Text('Ovaj zadatak nema nijednu poziciju.',
              style: TextStyle(color: colors.textSecondary))
        else
          ...review.items.asMap().entries.map(
                (entry) => _ItemCard(
                  item: entry.value,
                  index: entry.key,
                  isTrainer: review.isTrainer,
                  isLesson: review.isLesson,
                  notes: review.notesFor(entry.value.itemId),
                  onComment: () => _writeNote(
                    itemId: entry.value.itemId,
                    prompt: review.isTrainer
                        ? 'Komentar na ovu poziciju'
                        : 'Pitanje o ovoj poziciji',
                  ),
                  onDeleteNote: _deleteNote,
                ),
              ),
      ],
    );
  }

  Widget _summary(AssignmentReview review) {
    final colors = context.colors;
    final total = review.items.length;

    return Card(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              review.isLesson
                  ? '${review.attemptedCount} / $total koraka pregledano'
                  : '${review.attemptedCount} / $total urađeno'
                      '${review.attemptedCount == 0 ? '' : ' · tačno ${review.solvedCount}'}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (review.instructions != null) ...[
              const SizedBox(height: 8),
              Text(review.instructions!, style: const TextStyle(fontSize: 13)),
            ],
            const SizedBox(height: 6),
            Text(
              review.isTrainer
                  ? 'Učenik: ${review.studentName ?? '—'}'
                  : 'Zadao: ${review.trainerName ?? '—'}',
              style: TextStyle(fontSize: 12, color: colors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _generalNotes(AssignmentReview review) {
    final colors = context.colors;
    final notes = review.generalNotes;

    return Card(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Razgovor o zadatku',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                TextButton.icon(
                  onPressed: () => _writeNote(
                    prompt:
                        review.isTrainer ? 'Poruka učeniku' : 'Poruka treneru',
                  ),
                  icon: const Icon(Icons.add_comment_outlined, size: 16),
                  label: const Text('Napiši'),
                ),
              ],
            ),
            if (notes.isEmpty)
              Text(
                review.isTrainer
                    ? 'Još ništa nije napisano. Učenik vidi ono što ovde napišete.'
                    : 'Još ništa nije napisano. Ovde možete pitati trenera.',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              )
            else
              ...notes.map((note) =>
                  _NoteRow(note: note, onDelete: () => _deleteNote(note))),
          ],
        ),
      ),
    );
  }
}

/// One position: the board, what was played, what the answer was, and whatever
/// was said about it.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.index,
    required this.isTrainer,
    required this.isLesson,
    required this.notes,
    required this.onComment,
    required this.onDeleteNote,
  });

  final ReviewItem item;
  final int index;
  final bool isTrainer;
  final bool isLesson;
  final List<AssignmentNote> notes;
  final VoidCallback onComment;
  final void Function(AssignmentNote) onDeleteNote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Card(
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.fen != null)
                  BoardThumbnail(fen: item.fen!, size: 120)
                else
                  Container(
                    width: 120,
                    height: 120,
                    alignment: Alignment.center,
                    color: colors.surfaceRaised,
                    child: Text('tabla nije\ndostupna',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(fontSize: 11, color: colors.textMuted)),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.label(index),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _verdict(context),
                        ],
                      ),
                      if (item.instruction != null) ...[
                        const SizedBox(height: 4),
                        Text(item.instruction!,
                            style: TextStyle(
                                fontSize: 12, color: colors.textSecondary)),
                      ],
                      const SizedBox(height: 8),
                      ..._answerLines(context),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...notes.map((note) =>
                _NoteRow(note: note, onDelete: () => onDeleteNote(note))),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onComment,
                icon: const Icon(Icons.mode_comment_outlined, size: 15),
                label: Text(isTrainer ? 'Komentariši' : 'Pitaj',
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The two lines that carry the whole point of this screen: what was played
  /// and what the answer was.
  List<Widget> _answerLines(BuildContext context) {
    final colors = context.colors;
    final lines = <Widget>[];

    String? played;
    if (!item.attempted) {
      played = null;
    } else if (item.playedSan != null) {
      played = item.playedSan;
    }

    if (item.kind != ReviewItemKind.step) {
      lines.add(_line(
        context,
        isTrainer ? 'Odigrao' : 'Tvoj potez',
        played ??
            (item.attempted
                // Not the same as playing nothing, and it must not read that
                // way: the move simply was not recorded for this attempt.
                ? 'nije zabeležen'
                : 'nije urađeno'),
        muted: played == null,
      ));

      if (item.solutionSan != null) {
        lines.add(_line(context, 'Rešenje', item.solutionSan!));
      } else if (item.solutionMoves != null) {
        lines.add(_line(context, 'Linija', item.solutionMoves!));
      } else if (item.solutionHidden) {
        lines.add(
            _line(context, 'Rešenje', 'otkriva se kad odgovoriš', muted: true));
      }

      // Accepted, and not the move the book prints — the only rule that does
      // that is "a different mate is still a mate", so saying so is reporting.
      if (item.solved == true &&
          item.playedSan != null &&
          item.solutionSan != null &&
          item.playedSan != item.solutionSan) {
        lines.add(Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text('priznato iako nije autorov potez',
              style: TextStyle(fontSize: 11, color: colors.success)),
        ));
      }
    }

    if (item.msTaken != null) {
      lines.add(_line(
          context, 'Vreme', '${(item.msTaken! / 1000).toStringAsFixed(1)} s',
          muted: true));
    }

    return lines;
  }

  Widget _line(BuildContext context, String label, String value,
      {bool muted = false}) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 12, color: colors.textPrimary),
          children: [
            TextSpan(
                text: '$label: ',
                style: TextStyle(color: colors.textMuted, fontSize: 11.5)),
            TextSpan(
              text: value,
              style: TextStyle(
                color: muted ? colors.textMuted : colors.textPrimary,
                fontStyle: muted ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verdict(BuildContext context) {
    final colors = context.colors;

    // A lesson step was read, not answered. Calling it "netačno" would be an
    // answer to a question nobody asked.
    if (item.kind == ReviewItemKind.step || item.solved == null) {
      final seen = item.attempted;
      return _chip(seen ? 'pregledano' : 'nije otvoreno',
          seen ? colors.success : colors.textMuted);
    }
    if (!item.attempted) return _chip('nije urađeno', colors.textMuted);
    return item.solved == true
        ? _chip('tačno', colors.success)
        : _chip('netačno', colors.danger);
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: color)),
      );
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.onDelete});

  final AssignmentNote note;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            note.mine ? Icons.person : Icons.person_outline,
            size: 15,
            color: note.mine ? colors.accent : colors.textMuted,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.mine ? 'ja' : (note.authorName ?? 'druga strana'),
                  style: TextStyle(fontSize: 10.5, color: colors.textMuted),
                ),
                Text(note.body, style: const TextStyle(fontSize: 12.5)),
              ],
            ),
          ),
          // Only the author may take a note back; deleting the other side's
          // words is a different thing and is not offered.
          if (note.mine)
            InkWell(
              onTap: onDelete,
              child: Icon(Icons.close, size: 14, color: colors.textMuted),
            ),
        ],
      ),
    );
  }
}
