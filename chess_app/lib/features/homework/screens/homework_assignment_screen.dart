/// What a student sees when they open a sent homework: its items, in the
/// trainer's order, with what is done, open or locked — and the trainer's own
/// escape hatch on a locked one (docs/PLAN-DOMACI-ZADATAK.md §6, phase 5).
library;

import 'package:flutter/material.dart';

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
                      if (detail.assignment.instructions != null &&
                          detail.assignment.instructions!.isNotEmpty) ...[
                        Text(detail.assignment.instructions!,
                            style: AppText.bodyLarge),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Text(
                        detail.assignment.itemsSummary,
                        key: const Key('homework-progress'),
                        style: AppText.title,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      ...detail.children.map(_buildChildRow),
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

  Widget _buildChildRow(HomeworkChild child) {
    final locked = child.state == HomeworkChildState.locked;
    final done = child.state == HomeworkChildState.done;
    final stateLabel = done ? 'Done' : (locked ? 'Locked' : 'Open');
    final stateColor = done
        ? context.colors.success
        : (locked ? context.colors.textMuted : context.colors.accent);
    final blocker = locked ? _blockerOf(child) : null;

    return Card(
      key: Key('homework-child-${child.id}'),
      color: context.colors.surface,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        onTap: locked ? null : () => _openChild(child),
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
                        : (locked
                            ? Icons.lock_outline
                            : Icons.play_circle_outline),
                    color: stateColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      child.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Text(
                    stateLabel,
                    key: Key('homework-child-state-${child.id}'),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: stateColor,
                    ),
                  ),
                ],
              ),
              if (locked)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    blocker != null
                        ? 'Locked until "${blocker.title}" is done.'
                        : 'Locked until an earlier item is done.',
                    style:
                        AppText.body.copyWith(color: context.colors.textMuted),
                  ),
                ),
              if (child.openedByTrainer)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    // The same fact, said to whoever is reading it: „your
                    // trainer“ is nonsense on the trainer's own screen.
                    _isTrainer
                        ? 'You unlocked this early.'
                        : 'Unlocked early by your trainer.',
                    style: AppText.body.copyWith(color: context.colors.warning),
                  ),
                ),
              if (child.attemptedItems > 0 || (_isTrainer && locked))
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (child.attemptedItems > 0)
                      TextButton.icon(
                        key: Key('homework-child-review-${child.id}'),
                        onPressed: () => _openReview(child),
                        icon: const Icon(Icons.rate_review_outlined, size: 16),
                        label: const Text('Review', style: AppText.body),
                      ),
                    if (_isTrainer && locked)
                      TextButton.icon(
                        key: Key('homework-child-unlock-${child.id}'),
                        onPressed: _unlocking.contains(child.id)
                            ? null
                            : () => _unlock(child),
                        icon: const Icon(Icons.lock_open, size: 16),
                        label: const Text('Unlock for student'),
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
