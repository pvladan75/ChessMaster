/// What a student sees when they open a sent homework: its items, in the
/// trainer's order, with what is done, open or locked — and the trainer's own
/// escape hatch on a locked one (docs/PLAN-DOMACI-ZADATAK.md §6, phase 5).
library;

import 'package:flutter/material.dart';

import 'package:chess_app/core/models/engine_game_said.dart';
import 'package:chess_app/features/assignments/models/assignment.dart';
import 'package:chess_app/features/assignments/screens/assignment_review_screen.dart';
import 'package:chess_app/features/assignments/services/assignment_api_service.dart';
import 'package:chess_app/features/assignments/widgets/assignment_detail_gate.dart';
import 'package:chess_app/features/assignments/widgets/assignment_item_destination.dart';
import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:chess_app/widgets/app_feedback.dart';

import '../models/homework_child.dart';

class HomeworkAssignmentScreen extends StatefulWidget {
  const HomeworkAssignmentScreen({
    super.key,
    required this.session,
    required this.assignmentId,
    this.api,
  });

  final UserSession session;
  final int assignmentId;

  /// For tests, which have no server to answer.
  final AssignmentApiService? api;

  @override
  State<HomeworkAssignmentScreen> createState() =>
      _HomeworkAssignmentScreenState();
}

class _HomeworkAssignmentScreenState extends State<HomeworkAssignmentScreen> {
  late final AssignmentApiService _api =
      widget.api ?? AssignmentApiService(authToken: widget.session.token);

  AssignmentDetail? _detail;
  bool _loading = true;
  String? _error;
  int? _lockedBy;
  final Set<int> _unlocking = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Whether this reader is the trainer, read from the payload — the
  /// parent's `trainer_id` against the session's id — never from a flag a
  /// caller could pass wrongly.
  bool get _isTrainer =>
      _detail != null && _detail!.assignment.trainerId == widget.session.id;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _lockedBy = null;
    });
    final result = await _api.fetchDetail(widget.assignmentId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _detail = result.detail;
      _lockedBy = result.locked ? result.lockedBy : null;
      _error = result.detail == null && !result.locked
          ? 'Could not load homework.'
          : null;
    });
  }

  /// The item that holds [child] shut, resolved by id against the children
  /// this screen already has — never by reading `blockedBy` as an index.
  HomeworkChild? _blockerOf(HomeworkChild child) {
    final blockedBy = child.blockedBy;
    final detail = _detail;
    if (blockedBy == null || detail == null) return null;
    for (final sibling in detail.children) {
      if (sibling.id == blockedBy) return sibling;
    }
    return null;
  }

  Future<void> _openChild(HomeworkChild child) async {
    if (child.state == HomeworkChildState.locked) return;

    final Widget screen;
    if (child.kind == 'engine_game') {
      // Nothing to fetch: the task travelled with this child already, and
      // that is the door into „play it out" — nothing else in the app opens
      // one.
      screen = assignmentItemScreen(
        session: widget.session,
        detail: AssignmentDetail(
          assignment: Assignment(
            id: child.id,
            title: child.title,
            kind: AssignmentKind.engineGame,
            task: child.task,
          ),
          items: const [],
        ),
        api: _api,
      );
    } else {
      // The three detail-fed kinds want the child's own detail, fetched by
      // id — the same gate every other assignment screen uses.
      screen = AssignmentDetailGate(
        session: widget.session,
        assignmentId: child.id,
        api: _api,
        builder: (detail) => assignmentItemScreen(
          session: widget.session,
          detail: detail,
          api: _api,
        ),
      );
    }

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    // What the server says now, not what this screen assumed a moment ago.
    if (mounted) _load();
  }

  /// What was answered on one item, and what the trainer wrote about it.
  /// The parent has no review of its own — `buildReview` is built from
  /// `assignment_items` and a parent has none — but every child is an
  /// ordinary assignment, so this is where a homework's answers are read,
  /// by either side.
  Future<void> _openReview(HomeworkChild child) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AssignmentReviewScreen(
        session: widget.session,
        assignmentId: child.id,
        title: child.title,
        api: _api,
      ),
    ));
    if (mounted) _load();
  }

  Future<void> _unlock(HomeworkChild child) async {
    setState(() => _unlocking.add(child.id));
    final error = await _api.openGate(child.id);
    if (!mounted) return;
    setState(() => _unlocking.remove(child.id));
    if (error != null) {
      AppFeedback.show(context, () => SnackBar(content: Text(error)));
      return;
    }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;

    return Scaffold(
      backgroundColor: context.colors.canvas,
      appBar: AppBar(title: Text(detail?.assignment.title ?? 'Homework')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : detail == null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      // One numbered list of reading width: a step is a line,
                      // not a card as wide as the window (phase 11 of
                      // docs/PLAN-EKRANI.md).
                      Center(
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(maxWidth: _listWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (detail.assignment.instructions != null &&
                                  detail
                                      .assignment.instructions!.isNotEmpty) ...[
                                Text(detail.assignment.instructions!,
                                    style: AppText.bodyLarge),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              Text(
                                detail.assignment.itemsSummary,
                                key: const Key('homework-progress'),
                                style: AppText.title,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              LinearProgressIndicator(
                                value: detail.assignment.progress,
                                backgroundColor: context.colors.surfaceRaised,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _buildSteps(detail),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    final lockedBy = _lockedBy;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 40, color: context.colors.textMuted),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              lockedBy != null
                  ? 'Locked — item #$lockedBy has to be done first.'
                  : (_error ?? 'Homework not found.'),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  /// The reading width of the list: wide enough for a title, a line under it,
  /// a state and two actions on one line, narrow enough that the eye does not
  /// travel a window to get from a step's name to its button.
  static const double _listWidth = 820;

  /// Below this width the actions leave the line and go under the step's text.
  static const double _inlineFrom = 560;

  /// The numbered list: one card, one line a step, a hairline between them.
  Widget _buildSteps(AssignmentDetail detail) {
    // The one step that can be done now, for the person who does it. A trainer
    // is not asked to continue anything: their door is Review and Unlock.
    final current = _isTrainer
        ? null
        : detail.children
            .where((c) => c.state == HomeworkChildState.open)
            .firstOrNull;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: context.colors.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inline = constraints.maxWidth >= _inlineFrom;
          return Column(
            children: [
              for (var i = 0; i < detail.children.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                _buildChildRow(
                  detail.children[i],
                  number: i + 1,
                  inline: inline,
                  isCurrent: detail.children[i].id == current?.id,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildChildRow(
    HomeworkChild child, {
    required int number,
    required bool inline,
    required bool isCurrent,
  }) {
    final locked = child.state == HomeworkChildState.locked;
    final done = child.state == HomeworkChildState.done;
    final stateLabel = done ? 'Done' : (locked ? 'Locked' : 'Open');
    final stateColor = done
        ? context.colors.success
        : (locked ? context.colors.textMuted : context.colors.accent);
    final blocker = locked ? _blockerOf(child) : null;
    final verdict = _verdict(child);

    final stateWord = Text(
      stateLabel,
      key: Key('homework-child-state-${child.id}'),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: stateColor,
      ),
    );

    // What is said under the title: why it is locked, who opened it, whether
    // it waits to be judged, how it went. Each is one short line.
    final lines = <Widget>[
      if (locked)
        Text(
          blocker != null
              ? 'Locked until "${blocker.title}" is done.'
              : 'Locked until an earlier item is done.',
          style: AppText.body.copyWith(color: context.colors.textMuted),
        ),
      if (child.openedByTrainer)
        Text(
          // The same fact, said to whoever is reading it: „your
          // trainer“ is nonsense on the trainer's own screen.
          _isTrainer
              ? 'You unlocked this early.'
              : 'Unlocked early by your trainer.',
          style: AppText.body.copyWith(color: context.colors.warning),
        ),
      if (child.pendingItems > 0)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Never by hue alone (the owner is colour-blind): an
            // hourglass is a different *shape* from the done
            // check-mark and the locked padlock beside it, and the
            // words say the rest. This is not a failure — the
            // tablebase could not be reached, the game still counts
            // as done, and it is judged the next time anybody opens
            // this homework (`docs/PLAN-EXERCISE.md`, phase 3b).
            Icon(Icons.hourglass_empty,
                size: 14, color: context.colors.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Played — not judged yet',
                key: Key('homework-child-pending-${child.id}'),
                style: AppText.body.copyWith(color: context.colors.textMuted),
              ),
            ),
          ],
        ),
      if (verdict != null) verdict,
    ];

    final actions = <Widget>[
      if (child.attemptedItems > 0)
        TextButton(
          key: Key('homework-child-review-${child.id}'),
          style: _compactButton,
          onPressed: () => _openReview(child),
          child: const Text('Review'),
        ),
      if (_isTrainer && locked)
        TextButton(
          key: Key('homework-child-unlock-${child.id}'),
          style: _compactButton,
          onPressed:
              _unlocking.contains(child.id) ? null : () => _unlock(child),
          child: const Text('Unlock for student'),
        ),
      // The one filled button of the screen (R4): the step to do now.
      if (isCurrent)
        FilledButton(
          key: Key('homework-child-continue-${child.id}'),
          style: _compactButton,
          onPressed: () => _openChild(child),
          child: const Text('Continue'),
        ),
    ];

    final title = Text(
      child.title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: locked ? context.colors.textMuted : null,
      ),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inline)
          title
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: title),
              const SizedBox(width: AppSpacing.sm),
              stateWord,
            ],
          ),
        for (final line in lines) ...[const SizedBox(height: 2), line],
        if (!inline && actions.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Wrap(spacing: AppSpacing.sm, children: actions),
        ],
      ],
    );

    return Material(
      key: Key('homework-child-${child.id}'),
      color: Colors.transparent,
      child: InkWell(
        // The trainer's tap on a played item opens what the student did, not
        // a board to play on — the student's tap is unchanged, and so is the
        // separate Review button, which either side may use.
        onTap: locked
            ? null
            : (_isTrainer && child.attemptedItems > 0)
                ? () => _openReview(child)
                : () => _openChild(child),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            crossAxisAlignment:
                inline ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: inline ? 0 : 2),
                child: Icon(
                  done
                      ? Icons.check_circle
                      : (locked
                          ? Icons.lock_outline
                          : Icons.play_circle_outline),
                  color: stateColor,
                ),
              ),
              SizedBox(
                width: 32,
                child: Padding(
                  padding: EdgeInsets.only(top: inline ? 0 : 2),
                  child: Text(
                    '$number.',
                    textAlign: TextAlign.center,
                    style:
                        AppText.body.copyWith(color: context.colors.textMuted),
                  ),
                ),
              ),
              Expanded(child: text),
              if (inline) ...[
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 56, child: stateWord),
                SizedBox(
                  width: 260,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        actions[i],
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static const ButtonStyle _compactButton =
      ButtonStyle(visualDensity: VisualDensity.compact);

  /// How this child went, in words — shown to both sides, and never for a
  /// child that has not been attempted or is still waiting to be judged: the
  /// pending block above already says that, and saying both would make one
  /// of the two look like a mistake.
  Widget? _verdict(HomeworkChild child) {
    if (child.attemptedItems == 0 || child.pendingItems > 0) return null;

    switch (child.kind) {
      case 'engine_game':
        // Never by hue alone (the owner is colour-blind): met and not met
        // are different icon *shapes*, the same ones the closing dialog
        // uses.
        final said =
            child.solvedItems > 0 ? EngineGameSaid.met : EngineGameSaid.notMet;
        final icon =
            said == EngineGameSaid.met ? Icons.emoji_events : Icons.flag;
        final color = said == EngineGameSaid.met
            ? context.colors.success
            : context.colors.danger;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                engineGameSaidWords(said),
                key: Key('homework-child-verdict-${child.id}'),
                style: AppText.body.copyWith(color: context.colors.textPrimary),
              ),
            ),
          ],
        );
      case 'puzzles':
        return Text(
          '${child.solvedItems} of ${child.totalItems} correct',
          key: Key('homework-child-verdict-${child.id}'),
          style: AppText.body.copyWith(color: context.colors.textMuted),
        );
      case 'lesson':
        // A tutorial's film: downloaded is all there is to say, never
        // whether it was watched (docs/PLAN-TUTORIJAL-VIDEO.md, D3).
        return Text(
          'Video downloaded',
          key: Key('homework-child-verdict-${child.id}'),
          style: AppText.body.copyWith(color: context.colors.textMuted),
        );
      default:
        return null;
    }
  }
}
