import 'package:flutter/material.dart';

import 'package:chess_app/core/models/drill_outcome.dart';
import 'package:chess_app/core/models/engine_game_said.dart';
import 'package:chess_app/core/models/engine_game_task.dart';
import 'package:chess_app/features/analysis_studio/services/open_game_in_analysis.dart';
import 'package:chess_app/features/exercises/models/exercise_task_words.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/theme/breakpoints.dart';
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

  /// The item on show: the id of the one the reader chose, `null` before they
  /// chose, [_none] once they closed it on a phone.
  int? _chosen;
  static const int _none = -1;

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

  /// The trainer's verdict on a played game. **Written first, said after**:
  /// the review is read again from the server, so what the card then shows is
  /// what was stored and not what was tapped.
  Future<void> _judgeGame(bool met) async {
    final error = await _api.submitGameVerdict(widget.assignmentId, met: met);
    if (!mounted) return;
    if (error != null) {
      AppFeedback.error(context, error);
      return;
    }
    await _load();
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
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= Breakpoints.wide
              ? _wide(review)
              : _narrow(review),
    );
  }

  /// The item whose detail is drawn. On a window one is always chosen — the
  /// first on opening. On a phone none is, until a tap, except where the
  /// list holds a single item: a list of one is a tap for nothing.
  ReviewItem? _shown(AssignmentReview review, {required bool wide}) {
    if (review.items.isEmpty) return null;
    if (_chosen == _none && !wide) return null;
    for (final item in review.items) {
      if (item.itemId == _chosen) return item;
    }
    if (wide || review.items.length == 1) return review.items.first;
    return null;
  }

  void _choose(ReviewItem item, {required bool wide, required bool open}) {
    setState(() => _chosen = (!wide && open) ? _none : item.itemId);
  }

  /// The pane beside a list (pattern B, `docs/PLAN-EKRANI.md` R7): the items
  /// on the left, the chosen one large on the right, each scrolling by itself.
  Widget _wide(AssignmentReview review) {
    final shown = _shown(review, wide: true);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _summary(review),
              const SizedBox(height: AppSpacing.md),
              ..._rows(review, shown, wide: true),
              const SizedBox(height: AppSpacing.md),
              _generalNotes(review),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                0, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
            children: [
              if (shown != null) _detail(review, shown),
            ],
          ),
        ),
      ],
    );
  }

  /// A phone: the list, and a tap shows the item under its row.
  Widget _narrow(AssignmentReview review) {
    final shown = _shown(review, wide: false);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _summary(review),
        const SizedBox(height: AppSpacing.md),
        ..._rows(review, shown, wide: false),
        const SizedBox(height: AppSpacing.md),
        _generalNotes(review),
      ],
    );
  }

  List<Widget> _rows(AssignmentReview review, ReviewItem? shown,
      {required bool wide}) {
    if (review.items.isEmpty) {
      return [
        Text('This assignment has no positions.',
            style: TextStyle(color: context.colors.textSecondary)),
      ];
    }
    final rows = <Widget>[];
    for (final entry in review.items.asMap().entries) {
      final item = entry.value;
      final open = identical(item, shown);
      rows.add(_ItemRow(
        item: item,
        index: entry.key,
        comments: review.notesFor(item.itemId).length,
        selected: open,
        onTap: () => _choose(item, wide: wide, open: open),
      ));
      if (!wide && open) {
        rows.add(_detail(review, item));
      }
    }
    return rows;
  }

  Widget _detail(AssignmentReview review, ReviewItem item) {
    final index = review.items.indexOf(item);
    final notes = review.notesFor(item.itemId);
    String prompt(String what) => review.isTrainer
        ? 'Comment on this $what'
        : 'Question about this $what';
    if (item.kind == ReviewItemKind.video) {
      return _VideoItemCard(
        item: item,
        isTrainer: review.isTrainer,
        notes: notes,
        onComment: () =>
            _writeNote(itemId: item.itemId, prompt: prompt('video')),
        onDeleteNote: _deleteNote,
      );
    }
    if (item.kind == ReviewItemKind.game) {
      return _GameItemCard(
        item: item,
        notes: notes,
        isTrainer: review.isTrainer,
        onComment: () =>
            _writeNote(itemId: item.itemId, prompt: prompt('position')),
        onDeleteNote: _deleteNote,
        onJudge: _judgeGame,
      );
    }
    return _ItemCard(
      item: item,
      index: index,
      isTrainer: review.isTrainer,
      isLesson: review.isLesson,
      notes: notes,
      onComment: () =>
          _writeNote(itemId: item.itemId, prompt: prompt('position')),
      onDeleteNote: _deleteNote,
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
            ? (review.attemptedCount > 0 ? 'Downloaded' : 'Not downloaded yet')
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
        child: LayoutBuilder(builder: (context, c) {
          // Beside each other where the pane is wide, one under the other
          // where it is not; the board takes what the width gives it, up to
          // a size worth looking at.
          final sideBySide = c.maxWidth >= 700;
          final boardSize =
              sideBySide ? 360.0 : c.maxWidth.clamp(0.0, 400.0).toDouble();
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(item.label(index), style: AppText.title),
                  _puzzleVerdictChip(colors, item),
                ],
              ),
              if (item.instruction != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(item.instruction!,
                    style: AppText.body.copyWith(color: colors.textSecondary)),
              ],
              const SizedBox(height: AppSpacing.sm),
              ..._answerLines(context),
              const SizedBox(height: AppSpacing.sm),
              ...notes.map((note) =>
                  _NoteRow(note: note, onDelete: () => onDeleteNote(note))),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onComment,
                  icon: const Icon(Icons.mode_comment_outlined, size: 15),
                  label:
                      Text(isTrainer ? 'Comment' : 'Ask', style: AppText.body),
                ),
              ),
            ],
          );
          final board = item.fen != null
              ? BoardThumbnail(fen: item.fen!, size: boardSize)
              : Container(
                  width: boardSize,
                  height: boardSize,
                  alignment: Alignment.center,
                  color: colors.surfaceRaised,
                  child: Text('board not\navailable',
                      textAlign: TextAlign.center,
                      style: AppText.caption
                          .copyWith(color: colors.textSecondary)),
                );
          if (sideBySide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                board,
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: info),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: board),
              const SizedBox(height: AppSpacing.md),
              info,
            ],
          );
        }),
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

    {
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
      // `Text.rich`, not `RichText`: the same words, but a finder (and a
      // screen reader) reads them as one text.
      child: Text.rich(
        TextSpan(
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
}

/// A position's verdict as a chip, in words.
Widget _puzzleVerdictChip(AppColorTokens colors, ReviewItem item) {
  // Nothing was judged. Calling it "netačno" would be an answer to a
  // question nobody asked.
  if (item.solved == null) {
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
      child: Text(text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppText.caption.copyWith(color: color)),
    );

/// What a game says about itself in one chip, or nothing when it was never
/// played — a verdict of a game that did not happen would be an answer to a
/// question nobody asked.
EngineGameSaid? _gameSaid(ReviewItem item) {
  if (!item.attempted) return null;
  if (item.pending) return EngineGameSaid.notJudged;
  if (item.solved == true) return EngineGameSaid.met;
  if (item.solved == false) return EngineGameSaid.notMet;
  return null;
}

/// Same icon *shapes* the closing dialog uses (`ai_studio_screen.dart`) —
/// the owner is colour-blind, never hue alone.
Widget _gameVerdict(AppColorTokens colors, EngineGameSaid said) {
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
      Flexible(
        child: Text(engineGameSaidWords(said),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body.copyWith(color: color)),
      ),
    ],
  );
}

/// One item in the list: a small board, the number and title, how many
/// comments, and the verdict. The chosen one is outlined — an outline and not
/// a tint, so it reads without colour.
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.index,
    required this.comments,
    required this.selected,
    required this.onTap,
  });

  final ReviewItem item;
  final int index;
  final int comments;
  final bool selected;
  final VoidCallback onTap;

  String get _title => switch (item.kind) {
        ReviewItemKind.video => item.title ?? 'Tutorial video',
        ReviewItemKind.game => exerciseTaskWords(item.task),
        _ => item.label(index),
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final said = item.kind == ReviewItemKind.game ? _gameSaid(item) : null;
    final Widget? verdict = switch (item.kind) {
      ReviewItemKind.video => null,
      ReviewItemKind.game => said == null ? null : _gameVerdict(colors, said),
      _ => _puzzleVerdictChip(colors, item),
    };
    final isWhiteBottom = item.task?['side'] != 'b';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            side: BorderSide(
              color: selected ? colors.accent : colors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            key: Key('review-row-${item.itemId}'),
            customBorder: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0)),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  if (item.kind == ReviewItemKind.video)
                    Icon(Icons.movie_outlined, size: 48, color: colors.accent)
                  else if (item.fen != null)
                    BoardThumbnail(
                        fen: item.fen!, size: 48, isWhiteBottom: isWhiteBottom)
                  else
                    const SizedBox(width: 48, height: 48),
                  const SizedBox(width: AppSpacing.sm),
                  Text('${index + 1}.',
                      style: AppText.body.copyWith(color: colors.textMuted)),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyLargeBold),
                        if (comments > 0)
                          Text(
                            comments == 1 ? '1 comment' : '$comments comments',
                            style: AppText.caption
                                .copyWith(color: colors.textMuted),
                          ),
                      ],
                    ),
                  ),
                  if (verdict != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(flex: 0, child: verdict),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
    required this.onJudge,
  });

  final ReviewItem item;
  final List<AssignmentNote> notes;
  final bool isTrainer;
  final VoidCallback onComment;
  final void Function(AssignmentNote) onDeleteNote;

  /// The trainer's verdict: true for met, false for not met.
  final void Function(bool met) onJudge;

  /// A game with no goal — „Play N moves" (phase 15).
  bool get _noGoal => item.task?['goal'] == 'play';

  /// Whether this reader may give, or change, the verdict: the trainer, on a
  /// game that was played and that nobody but the trainer has judged. What
  /// the rules or a tablebase said is not an opinion to overrule — the server
  /// refuses it too (409); this only keeps the buttons from promising it.
  /// „Played" is not asked again here: the server's `pending` and a judge's
  /// name both mean a game that was played.
  bool get _trainerMayJudge =>
      isTrainer && (item.pending || item.judgedBy == 'trainer');

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final task = item.task;
    final fen = item.fen;
    final isWhiteBottom = task?['side'] != 'b';
    final said = _gameSaid(item);
    final movesText = gameMovesText(fen ?? '', item.moves);

    return Card(
      key: Key('review-game-${item.itemId}'),
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: LayoutBuilder(builder: (context, c) {
          // Two boards side by side, as large as the card lets them be.
          final boardSize =
              ((c.maxWidth - AppSpacing.md) / 2).clamp(110.0, 220.0).toDouble();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(exerciseTaskWords(task), style: AppText.title),
                  if (said != null) _gameVerdict(colors, said),
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
                        'Start', isWhiteBottom, boardSize),
                  if (item.finalFen != null)
                    _board(
                        context,
                        'review-game-final-${item.itemId}',
                        item.finalFen!,
                        'Position reached',
                        isWhiteBottom,
                        boardSize),
                ],
              ),
              ..._endingLines(colors),
              if (_trainerMayJudge) ...[
                const SizedBox(height: AppSpacing.sm),
                // Worded as what the tap does, not as the verdict it gives: a
                // card nobody has judged must not carry „Goal met" anywhere on
                // it (phase 9's gate holds that, and it is right). The icon
                // *shapes* are the verdict's own — never hue alone.
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    OutlinedButton.icon(
                      key: Key('review-game-judge-met-${item.itemId}'),
                      onPressed: () => onJudge(true),
                      icon: const Icon(Icons.emoji_events, size: 16),
                      label: const Text('Mark as met'),
                    ),
                    OutlinedButton.icon(
                      key: Key('review-game-judge-not-met-${item.itemId}'),
                      onPressed: () => onJudge(false),
                      icon: const Icon(Icons.flag, size: 16),
                      label: const Text('Mark as not met'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              ...notes.map((note) =>
                  _NoteRow(note: note, onDelete: () => onDeleteNote(note))),
              // A `Wrap`, not a `Row`: two labelled buttons are wider than a
              // narrow card, and a release build clips what a row cannot hold.
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    // The moves on a board, with the engine at hand — for both
                    // readers: a game with moves is a game handed in, which is
                    // when phase 12 opens Analysis to the student again.
                    if (fen != null && item.moves.isNotEmpty)
                      TextButton.icon(
                        key: Key('review-game-analysis-${item.itemId}'),
                        onPressed: () => openSanGameInAnalysis(
                          context,
                          startFen: fen,
                          sans: item.moves,
                          blackOrientation: !isWhiteBottom,
                        ),
                        icon: const Icon(Icons.biotech_outlined, size: 15),
                        label:
                            const Text('Open in Analysis', style: AppText.body),
                      ),
                    TextButton.icon(
                      onPressed: onComment,
                      icon: const Icon(Icons.mode_comment_outlined, size: 15),
                      label: Text(isTrainer ? 'Comment' : 'Ask',
                          style: AppText.body),
                    ),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _board(BuildContext context, String key, String boardFen, String label,
      bool isWhiteBottom, double boardSize) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BoardThumbnail(
          key: Key(key),
          fen: boardFen,
          size: boardSize,
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
          // A game with no goal waits for a person, not for a tablebase — and
          // the student is told who, not told to judge their own game.
          _noGoal
              ? (isTrainer
                  ? 'This game has no goal — how it was played is yours to '
                      'judge.'
                  : 'Your trainer will look at this game.')
              : 'No tablebase answer yet — the position reached is yours to '
                  'judge.',
          key: Key('review-game-pending-${item.itemId}'),
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
        'trainer' => 'Judged by the trainer',
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

/// A tutorial's film, as the review shows it (`docs/PLAN-TUTORIJAL-VIDEO.md`):
/// the only fact there is — whether, and when, the student downloaded it —
/// and the conversation about it. No board, no verdict: a film is not solved.
class _VideoItemCard extends StatelessWidget {
  const _VideoItemCard({
    required this.item,
    required this.isTrainer,
    required this.notes,
    required this.onComment,
    required this.onDeleteNote,
  });

  final ReviewItem item;
  final bool isTrainer;
  final List<AssignmentNote> notes;
  final VoidCallback onComment;
  final void Function(AssignmentNote) onDeleteNote;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final at = item.attemptedAt;
    return Card(
      key: Key('review-video-${item.itemId}'),
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.movie_outlined, color: colors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(item.title ?? 'Tutorial video',
                      style: AppText.bodyLargeBold),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              at == null
                  ? 'Not downloaded yet.'
                  : 'Downloaded on ${at.day}.${at.month}.${at.year}.',
              key: const Key('review-video-status'),
              style: AppText.body.copyWith(color: colors.textSecondary),
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
}
