import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:chess_app/routing/app_routes.dart';

import 'package:chess_app/models/user_session.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/widgets/board_thumbnail.dart';

import '../models/assignment.dart';
import '../models/solve_order.dart';
import 'custom_puzzle_solver_screen.dart';

/// The whole homework at a glance, and a way into it at any point.
///
/// The screen this replaces built a queue of the unanswered positions in the
/// trainer's order and walked through them one at a time. A child stuck on the
/// third position could not reach the fourth, and homework that cannot be
/// finished is homework that does not get done. "Let me see them all first and
/// start with the easy ones" is also a real way to study, not avoidance.
///
/// Nothing is given away by showing them: **the solution is never sent to the
/// app in advance** — the server judges the move and reveals the answer only
/// afterwards — so a grid of boards reveals exactly as much as one board did.
///
/// The trainer's order is kept as the order everything is listed and stepped
/// through in. It stops being a cage, not a suggestion.
class CustomAssignmentOverviewScreen extends StatefulWidget {
  const CustomAssignmentOverviewScreen({
    super.key,
    required this.session,
    required this.detail,
  });

  final UserSession session;
  final AssignmentDetail detail;

  @override
  State<CustomAssignmentOverviewScreen> createState() =>
      _CustomAssignmentOverviewScreenState();
}

class _CustomAssignmentOverviewScreenState
    extends State<CustomAssignmentOverviewScreen> {
  /// The positions in the trainer's order, whatever state they are in.
  late final List<CustomPosition> _positions;

  /// puzzleId → whether it was answered correctly. Seeded from what the server
  /// already recorded and updated as the student answers, so the grid is right
  /// the moment they come back from the board rather than after a refetch.
  final Map<String, bool> _answered = {};

  @override
  void initState() {
    super.initState();
    _positions = widget.detail.items
        .map((item) => widget.detail.positionFor(item.puzzleId ?? ''))
        .whereType<CustomPosition>()
        .toList();

    for (final item in widget.detail.items) {
      if (item.puzzleId != null && item.isDone) {
        _answered[item.puzzleId!] = item.solved == true;
      }
    }
  }

  List<String> get _ids => _positions.map((p) => p.puzzleId).toList();

  int get _doneCount => _answered.length;
  int get _correctCount => _answered.values.where((ok) => ok).length;

  /// The move the student played, where it was recorded. Absent for everything
  /// answered before it was stored, and that reads as "not known" rather than
  /// as nothing.
  String? _playedFor(String puzzleId) {
    for (final item in widget.detail.items) {
      if (item.puzzleId == puzzleId) return item.playedSan;
    }
    return null;
  }

  Future<void> _openAt(int index) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomPuzzleSolverScreen(
          session: widget.session,
          detail: widget.detail,
          positions: _positions,
          startIndex: index,
          answered: Map<String, bool>.from(_answered),
          onAnswered: (puzzleId, correct) =>
              setState(() => _answered[puzzleId] = correct),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openReview() async {
    await context.push(AppRoutes.assignmentReviewPath(
      widget.detail.assignment.id,
      title: widget.detail.assignment.title,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final next =
        firstUnanswered(puzzleIds: _ids, answered: _answered.keys.toSet());

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(title: Text(widget.detail.assignment.title)),
      body: SafeArea(
        child: Column(
          children: [
            _header(next),
            Expanded(
              child: _positions.isEmpty
                  ? Center(
                      child: Text('Ovaj zadatak nema nijednu poziciju.',
                          style: TextStyle(color: colors.textSecondary)),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        mainAxisExtent: 232,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _positions.length,
                      itemBuilder: (context, index) => _PositionTile(
                        position: _positions[index],
                        number: index + 1,
                        outcome: _answered[_positions[index].puzzleId],
                        playedSan: _playedFor(_positions[index].puzzleId),
                        onTap: () => _openAt(index),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(int? next) {
    final colors = context.colors;
    final total = _positions.length;
    final note = widget.detail.assignment.instructions;

    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_doneCount / $total urađeno'
            '${_doneCount == 0 ? '' : ' · tačno $_correctCount'}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          if (note != null && note.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(note, style: TextStyle(fontSize: 12, color: colors.textMuted)),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (next != null)
                FilledButton.icon(
                  onPressed: () => _openAt(next),
                  icon: const Icon(Icons.play_arrow),
                  // Continues in the trainer's order — the first position still
                  // waiting, not the one that happens to come after the last
                  // one touched.
                  label: Text(_doneCount == 0 ? 'Počni' : 'Nastavi'),
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 18, color: colors.success),
                    const SizedBox(width: 6),
                    Text('Sve je urađeno',
                        style: TextStyle(color: colors.success, fontSize: 13)),
                  ],
                ),
              OutlinedButton.icon(
                onPressed: _openReview,
                icon: const Icon(Icons.rate_review_outlined, size: 16),
                label: const Text('Pregled i komentari'),
              ),
            ],
          ),
          if (total > 1) ...[
            const SizedBox(height: 8),
            Text(
              'Možeš da radiš kojim redom hoćeš — dodirni bilo koju poziciju.',
              style: TextStyle(fontSize: 11.5, color: colors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

/// One position in the grid: the board, its number, and what became of it.
class _PositionTile extends StatelessWidget {
  const _PositionTile({
    required this.position,
    required this.number,
    required this.outcome,
    required this.playedSan,
    required this.onTap,
  });

  final CustomPosition position;
  final int number;

  /// null = untouched, true = answered correctly, false = answered wrongly.
  /// Three states, not two: "not done yet" and "got it wrong" are the two the
  /// student most needs to tell apart.
  final bool? outcome;

  final String? playedSan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final border = switch (outcome) {
      true => colors.success,
      false => colors.danger,
      null => colors.border,
    };

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: outcome == null ? 1 : 2),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('$number.',
                    style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                _stateChip(context),
              ],
            ),
            const SizedBox(height: 6),
            Center(child: BoardThumbnail(fen: position.fen, size: 120)),
            const Spacer(),
            Flexible(
              child: ClipRect(
                child: Text(
                  outcome == null
                      ? (position.instruction ??
                          '${position.sideToMove == 'w' ? 'Beli' : 'Crni'} je na potezu.')
                      : (playedSan == null
                          // Not "played nothing": the move simply was not
                          // recorded for this attempt.
                          ? 'potez nije zabeležen'
                          : 'tvoj potez: $playedSan'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: outcome == null
                          ? colors.textSecondary
                          : colors.textMuted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stateChip(BuildContext context) {
    final colors = context.colors;
    final (text, color) = switch (outcome) {
      true => ('tačno', colors.success),
      false => ('netačno', colors.danger),
      null => ('nije urađeno', colors.textMuted),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, color: color)),
    );
  }
}
