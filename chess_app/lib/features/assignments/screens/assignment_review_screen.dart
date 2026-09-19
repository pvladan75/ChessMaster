import 'package:flutter/material.dart';

import 'package:chess_app/core/models/drill_outcome.dart';
import 'package:chess_app/core/models/engine_game_said.dart';
import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/features/exercises/models/exercise_task_words.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import '../models/assignment_review.dart';
import '../services/assignment_api_service.dart';
import 'package:chess_app/widgets/app_feedback.dart';

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
    this.api,
  });

  final UserSession session;
  final int assignmentId;
  final String title;

  /// For tests, which have no server to answer.
  final AssignmentApiService? api;

  @override
  State<AssignmentReviewScreen> createState() => _AssignmentReviewScreenState();
}

class _AssignmentReviewScreenState extends State<AssignmentReviewScreen> {
  late final AssignmentApiService _api =
      widget.api ?? AssignmentApiService(authToken: widget.session.token);

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
              hintText: 'e.g. I did not understand this one',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Send')),
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
      AppFeedback.show(
        context,
        () => SnackBar(content: Text(result.error ?? 'Message not sent.')),
      );
      return;
    }
    setState(() => _review = _review?.withNote(result.note!));
  }

  Future<void> _deleteNote(AssignmentNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete message?'),
        content: Text(note.body, maxLines: 4, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = await _api.deleteNote(
        assignmentId: widget.assignmentId, noteId: note.id);
    if (!mounted) return;
    if (error != null) {
      AppFeedback.show(context, () => SnackBar(content: Text(error)));
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
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        children: [
          Icon(Icons.cloud_off, size: 40, color: colors.textMuted),
          const SizedBox(height: AppSpacing.md),
          const Text('Could not load review.', textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.md),
          Center(
            child:
                FilledButton(onPressed: _load, child: const Text('Try again')),
          ),
        ],
      );
    }

    final review = _review!;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _summary(review),
        const SizedBox(height: AppSpacing.md),
        _generalNotes(review),
        const SizedBox(height: AppSpacing.lg),
        if (review.items.isEmpty)
          Text('This assignment has no positions.',
              style: TextStyle(color: colors.textSecondary))
        else
          ...review.items.asMap().entries.map(
                (entry) => entry.value.kind == ReviewItemKind.game
                    ? _GameItemCard(
                        item: entry.value,
                        notes: review.notesFor(entry.value.itemId),
                        isTrainer: review.isTrainer,
                        onComment: () => _writeNote(
                          itemId: entry.value.itemId,
                          prompt: review.isTrainer
                              ? 'Comment on this position'
                              : 'Question about this position',
                        ),
                        onDeleteNote: _deleteNote,
                      )
                    : _ItemCard(
                        item: entry.value,
                        index: entry.key,
                        isTrainer: review.isTrainer,
                        isLesson: review.isLesson,
                        notes: review.notesFor(entry.value.itemId),
                        onComment: () => _writeNote(
                          itemId: entry.value.itemId,
                          prompt: review.isTrainer
                              ? 'Comment on this position'
                              : 'Question about this position',
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

    // A game has no "correct" to count — it is played or it is not, and the
    // card below says how it went.
    final isGameReview =
        review.items.isNotEmpty && review.items.every(_isGameItem);
    final summaryText = isGameReview
        ? (review.attemptedCount > 0 ? 'Played' : 'Not played yet')
        : (review.isLesson
            ? '${review.attemptedCount} of $total parts viewed'
            : '${review.attemptedCount} of $total completed'
                '${review.attemptedCount == 0 ? '' : ' · correct ${review.solvedCount}'}');

    return Card(
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              summaryText,
              key: const Key('review-summary-text'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (review.instructions != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(review.instructions!, style: AppText.bodyLarge),
            ],
            const SizedBox(height: 6),
            Text(
              review.isTrainer
                  ? 'Student: ${review.studentName ?? '—'}'
                  : 'Assigned by: ${review.trainerName ?? '—'}',
              style: AppText.body.copyWith(color: colors.textMuted),
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
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Assignment Discussion',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                TextButton.icon(
                  onPressed: () => _writeNote(
                    prompt: review.isTrainer
                        ? 'Message to student'
                        : 'Message to trainer',
                  ),
                  icon: const Icon(Icons.add_comment_outlined, size: 16),
                  label: const Text('Write'),
                ),
              ],
            ),
            if (notes.isEmpty)
              Text(
                review.isTrainer
                    ? 'Nothing written yet. The student will see what you write here.'
                    : 'Nothing written yet. You can ask your trainer here.',
                style: AppText.body.copyWith(color: colors.textSecondary),
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

bool _isGameItem(ReviewItem item) => item.kind == ReviewItemKind.game;

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
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
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
                    child: Text('board not\navailable',
                        textAlign: TextAlign.center,
                        style: AppText.caption
                            .copyWith(color: colors.textSecondary)),
                  ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.label(index),
                              style: AppText.bodyLargeBold,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _verdict(context),
                        ],
                      ),
                      if (item.instruction != null) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(item.instruction!,
                            style: AppText.body
                                .copyWith(color: colors.textSecondary)),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      ..._answerLines(context),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...notes.map((note) =>
                _NoteRow(note: note, onDelete: () => onDeleteNote(note))),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onComment,
                icon: const Icon(Icons.mode_comment_outlined, size: 15),
                label: Text(isTrainer ? 'Comment' : 'Ask', style: AppText.body),
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

    final played = item.attempted ? item.playedSan : null;

    // A puzzle and a set position mean different things by "the move played",
    // so they are not labelled the same. A position the trainer set is answered
    // once — that is *the* move. A puzzle refuses a wrong move and lets the
    // student try again, so what is kept is the first wrong idea.
    final isPuzzle = item.kind == ReviewItemKind.lichess;

    if (item.kind != ReviewItemKind.step) {
      // A puzzle solved without a single wrong move has nothing to report here,
      // and "nije zabeležen" would suggest something went missing.
      final silent = isPuzzle && played == null && item.solved == true;

      if (!silent) {
        lines.add(_line(
          context,
          isPuzzle
              ? (isTrainer ? 'First tried' : 'You first tried')
              : (isTrainer ? 'Played' : 'Your move'),
          played ??
              (item.attempted
                  // Not the same as playing nothing, and it must not read that
                  // way: the move simply was not recorded for this attempt.
                  ? 'not recorded'
                  : 'not completed'),
          muted: played == null,
        ));
      }

      if (item.solutionSan != null) {
        lines.add(_line(context, 'Solution', item.solutionSan!));
      } else if (item.solutionMoves != null) {
        lines.add(_line(context, 'Line', item.solutionMoves!));
      } else if (item.solutionHidden) {
        lines.add(_line(context, 'Solution', 'revealed once you answer',
            muted: true));
      }

      // Accepted, and not the move the book prints — the only rule that does
      // that is "a different mate is still a mate", so saying so is reporting.
      if (!isPuzzle &&
          item.solved == true &&
          item.playedSan != null &&
          item.solutionSan != null &&
          item.playedSan != item.solutionSan) {
        lines.add(Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Text('accepted although not author\'s move',
              style: AppText.caption.copyWith(color: colors.success)),
        ));
      }
    }

    if (item.msTaken != null) {
      lines.add(_line(
          context, 'Time', '${(item.msTaken! / 1000).toStringAsFixed(1)} s',
          muted: true));
    }

    return lines;
  }

  Widget _line(BuildContext context, String label, String value,
      {bool muted = false}) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
      child: RichText(
        text: TextSpan(
          style: AppText.body.copyWith(color: colors.textPrimary),
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
      return _chip(seen ? 'viewed' : 'not opened',
          seen ? colors.success : colors.textMuted);
    }
    if (!item.attempted) return _chip('not completed', colors.textMuted);
    return item.solved == true
        ? _chip('correct', colors.success)
        : _chip('incorrect', colors.danger);
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text, style: AppText.caption.copyWith(color: color)),
      );
}

/// A „play it out" game: the task, the verdict, the moves both sides played,
/// the two boards it started and ended on, how it ended and who judged it —
/// everything the trainer needs to be the judge of last resort where no
/// tablebase answers (`docs/PLAN-EXERCISE.md`, phase 9).
class _GameItemCard extends StatelessWidget {
  const _GameItemCard({
    required this.item,
    required this.notes,
    required this.isTrainer,
    required this.onComment,
    required this.onDeleteNote,
  });

  final ReviewItem item;
  final List<AssignmentNote> notes;
  final bool isTrainer;
  final VoidCallback onComment;
  final void Function(AssignmentNote) onDeleteNote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final task = item.task;
    final fen = item.fen;
    final isWhiteBottom = task?['side'] != 'b';
    final said = _said();
    final movesText = gameMovesText(fen ?? '', item.moves);

    return Card(
      key: Key('review-game-${item.itemId}'),
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Text(exerciseTaskWords(task), style: AppText.bodyLargeBold),
                if (said != null) _verdict(colors, said),
              ],
            ),
            if (movesText.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(movesText, style: AppText.body),
            ],
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.sm,
              children: [
                if (fen != null)
                  _board(context, 'review-game-start-${item.itemId}', fen,
                      'Start', isWhiteBottom),
                if (item.finalFen != null)
                  _board(context, 'review-game-final-${item.itemId}',
                      item.finalFen!, 'Position reached', isWhiteBottom),
              ],
            ),
            ..._endingLines(colors),
            const SizedBox(height: AppSpacing.sm),
            ...notes.map((note) =>
                _NoteRow(note: note, onDelete: () => onDeleteNote(note))),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onComment,
                icon: const Icon(Icons.mode_comment_outlined, size: 15),
                label: Text(isTrainer ? 'Comment' : 'Ask', style: AppText.body),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nothing when the game was never played — a verdict of a game that did
  /// not happen would be an answer to a question nobody asked.
  EngineGameSaid? _said() {
    if (!item.attempted) return null;
    if (item.pending) return EngineGameSaid.notJudged;
    if (item.solved == true) return EngineGameSaid.met;
    if (item.solved == false) return EngineGameSaid.notMet;
    return null;
  }

  /// Same icon *shapes* the closing dialog uses (`ai_studio_screen.dart`) —
  /// the owner is colour-blind, never hue alone.
  Widget _verdict(AppColorTokens colors, EngineGameSaid said) {
    final icon = switch (said) {
      EngineGameSaid.met => Icons.emoji_events,
      EngineGameSaid.notMet => Icons.flag,
      EngineGameSaid.notJudged => Icons.hourglass_empty,
    };
    final color = switch (said) {
      EngineGameSaid.met => colors.warning,
      EngineGameSaid.notMet => colors.danger,
      EngineGameSaid.notJudged => colors.textMuted,
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(engineGameSaidWords(said),
            style: AppText.body.copyWith(color: color)),
      ],
    );
  }

  Widget _board(BuildContext context, String key, String boardFen, String label,
      bool isWhiteBottom) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BoardThumbnail(
          key: Key(key),
          fen: boardFen,
          size: 110,
          isWhiteBottom: isWhiteBottom,
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(label, style: AppText.caption.copyWith(color: colors.textMuted)),
      ],
    );
  }

  List<Widget> _endingLines(AppColorTokens colors) {
    final lines = <Widget>[];

    final endingText = _endingText();
    if (endingText != null) {
      lines.add(Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text('Ended: $endingText', style: AppText.body),
      ));
    }

    final judgedText = _judgedByText();
    if (judgedText != null) {
      lines.add(Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: Text(judgedText,
            style: AppText.body.copyWith(color: colors.textMuted)),
      ));
    }

    // Two honest sentences, said only when they are true: a tablebase
    // verdict does not need either one, and the pending one is never a
    // failure.
    if (item.pending) {
      lines.add(Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: Text(
          'No tablebase answer yet — the position reached is yours to judge.',
          style: AppText.body.copyWith(color: colors.textMuted),
        ),
      ));
    }
    if (_rulesCheckedNoteMoreThanNotMated()) {
      lines.add(Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: Text(
          'Only "not checkmated" could be checked — the position reached is '
          'yours to judge.',
          style: AppText.body.copyWith(color: colors.textMuted),
        ),
      ));
    }

    return lines;
  }

  /// True when the rules judged a move target on a goal that is not „win"
  /// with more than seven pieces on the board — the one case where being
  /// „met by the rules" means only that nobody was checkmated.
  bool _rulesCheckedNoteMoreThanNotMated() =>
      item.ending == 'moveTarget' &&
      item.judgedBy == 'rules' &&
      item.task?['goal'] != 'win';

  String? _endingText() {
    final endingName = item.ending;
    if (endingName == null) return null;
    final GameEnding ending;
    try {
      ending = GameEnding.values.byName(endingName);
    } catch (_) {
      return null;
    }
    final fen = item.fen;
    final task = fen == null
        ? null
        : EngineGameTask.fromJson({...?item.task, 'fen': fen});
    return engineGameEndingWords(task, ending);
  }

  String? _judgedByText() => switch (item.judgedBy) {
        'rules' => 'Judged by the rules',
        'tablebase' => 'Judged by the tablebase',
        'device' => 'Judged by the device',
        _ => null,
      };
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({required this.note, required this.onDelete});

  final AssignmentNote note;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
                  note.mine ? 'me' : (note.authorName ?? 'other side'),
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
