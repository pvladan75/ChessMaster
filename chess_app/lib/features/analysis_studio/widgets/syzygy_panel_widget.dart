import 'package:chess_app/core/services/mate_distance.dart';
import 'package:chess_app/features/analysis_studio/services/syzygy_tablebase_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

class _CategoryStyle {
  final String label;
  final Color color;
  const _CategoryStyle(this.label, this.color);
}

// Syzygy endgame theoretical WDL outcomes — domain evaluation constants.
_CategoryStyle _styleFor(SyzygyCategory category) {
  switch (category) {
    case SyzygyCategory.win:
      return const _CategoryStyle('Win', Colors.greenAccent);
    case SyzygyCategory.cursedWin:
      return const _CategoryStyle('Win (50-move)', Colors.lightGreen);
    case SyzygyCategory.maybeWin:
      return const _CategoryStyle('Probable win', Colors.lightGreenAccent);
    case SyzygyCategory.draw:
      return const _CategoryStyle('Draw', Colors.amberAccent);
    case SyzygyCategory.blessedLoss:
      return const _CategoryStyle('Draw (50-move)', Colors.orangeAccent);
    case SyzygyCategory.maybeLoss:
      return const _CategoryStyle('Probable loss', Colors.deepOrangeAccent);
    case SyzygyCategory.loss:
      return const _CategoryStyle('Loss', Colors.redAccent);
    case SyzygyCategory.unknown:
      return const _CategoryStyle('Unknown', Colors.grey);
  }
}

String? _dtzLabel(int? dtz) {
  if (dtz == null) return null;
  return 'DTZ ${dtz.abs()}';
}

/// A move's category is the tablebase's for the side to move *after* it, so
/// the mover's own result is its mirror. Until 1.10.2026 the chips were
/// coloured by it unturned, and the best move of a won position was drawn as
/// a loss.
SyzygyCategory _forMover(SyzygyCategory category) {
  switch (category) {
    case SyzygyCategory.win:
      return SyzygyCategory.loss;
    case SyzygyCategory.maybeWin:
      return SyzygyCategory.maybeLoss;
    case SyzygyCategory.cursedWin:
      return SyzygyCategory.blessedLoss;
    case SyzygyCategory.draw:
      return SyzygyCategory.draw;
    case SyzygyCategory.blessedLoss:
      return SyzygyCategory.cursedWin;
    case SyzygyCategory.maybeLoss:
      return SyzygyCategory.maybeWin;
    case SyzygyCategory.loss:
      return SyzygyCategory.win;
    case SyzygyCategory.unknown:
      return SyzygyCategory.unknown;
  }
}

bool _decisive(SyzygyCategory c) =>
    c != SyzygyCategory.draw && c != SyzygyCategory.unknown;

/// Shows the tablebase verdict for the current position and, once loaded, the
/// moves in the order the tablebase gave them — best first for the side to
/// move, by the distance to mate where it is known — each with „mate in N" /
/// „mated in N", or its DTZ where no source knew the distance to mate.
class SyzygyPanelWidget extends StatelessWidget {
  final bool isEligible;
  final bool isLoading;
  final SyzygyResult? result;
  final void Function(String uci)? onMoveSelected;

  const SyzygyPanelWidget({
    super.key,
    required this.isEligible,
    required this.isLoading,
    required this.result,
    this.onMoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!isEligible) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.table_chart, color: colors.info, size: 16),
              const SizedBox(width: 6),
              Text(
                'Syzygy Tablebase',
                style: AppText.bodyBold.copyWith(color: colors.info),
              ),
              const Spacer(),
              if (isLoading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.info),
                )
              else if (result != null)
                _buildVerdictChip(result!),
            ],
          ),
          if (!isLoading && result == null) ...[
            const SizedBox(height: 6),
            Text(
              // The panel is drawn only for a position the tablebase covers,
              // so no answer is the tablebase not answering — a Lichess block
              // after a 429, or no network — never „no tablebase".
              'The tablebase did not answer. Try again in a minute.',
              style: AppText.caption.copyWith(color: colors.textSecondary),
            ),
          ],
          if (!isLoading && result != null && result!.moves.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result!.moves
                  .map((move) => _buildMoveChip(context, move))
                  .toList(),
            ),
            if (result!.moves.any((m) =>
                _decisive(m.category) &&
                mateInAfterMove(m.dtm, checkmate: m.checkmate) == null)) ...[
              const SizedBox(height: 6),
              Text(
                'Distance to mate unknown for some moves: they show DTZ, '
                'half-moves to the next capture or pawn move.',
                style: AppText.caption.copyWith(color: colors.textSecondary),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildVerdictChip(SyzygyResult result) {
    final style = _styleFor(result.category);
    final dtz =
        mateLabel(mateInFromPosition(result.dtm)) ?? _dtzLabel(result.dtz);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.2),
        borderRadius: AppRadii.roundedSm,
        border: Border.all(color: style.color),
      ),
      child: Text(
        dtz != null ? '${style.label} · $dtz' : style.label,
        style: AppText.micro
            .copyWith(fontWeight: FontWeight.bold, color: style.color),
      ),
    );
  }

  Widget _buildMoveChip(BuildContext context, SyzygyMove move) {
    final style = _styleFor(_forMover(move.category));
    final dtz =
        mateLabel(mateInAfterMove(move.dtm, checkmate: move.checkmate)) ??
            (_decisive(move.category) ? _dtzLabel(move.dtz) : null);
    return InkWell(
      onTap: onMoveSelected != null ? () => onMoveSelected!(move.uci) : null,
      borderRadius: AppRadii.roundedSm,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: style.color.withValues(alpha: 0.12),
          borderRadius: AppRadii.roundedSm,
          border: Border.all(color: style.color.withValues(alpha: 0.6)),
        ),
        child: Text(
          dtz != null ? '${move.san} ($dtz)' : move.san,
          style: AppText.caption
              .copyWith(color: style.color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
