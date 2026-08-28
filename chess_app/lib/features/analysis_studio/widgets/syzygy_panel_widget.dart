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
      return const _CategoryStyle('Pobeda', Colors.greenAccent);
    case SyzygyCategory.cursedWin:
      return const _CategoryStyle('Pobeda (50-poteza)', Colors.lightGreen);
    case SyzygyCategory.maybeWin:
      return const _CategoryStyle('Verovatna pobeda', Colors.lightGreenAccent);
    case SyzygyCategory.draw:
      return const _CategoryStyle('Remi', Colors.amberAccent);
    case SyzygyCategory.blessedLoss:
      return const _CategoryStyle('Remi (50-poteza)', Colors.orangeAccent);
    case SyzygyCategory.maybeLoss:
      return const _CategoryStyle('Verovatan gubitak', Colors.deepOrangeAccent);
    case SyzygyCategory.loss:
      return const _CategoryStyle('Gubitak', Colors.redAccent);
    case SyzygyCategory.unknown:
      return const _CategoryStyle('Nepoznato', Colors.grey);
  }
}

String? _dtzLabel(int? dtz) {
  if (dtz == null) return null;
  return 'DTZ ${dtz.abs()}';
}

/// Shows the tablebase verdict for the current position and, once loaded, the
/// list of moves ranked from the mover's perspective (best first).
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
              'Tablebase nije dostupan za ovu poziciju.',
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
          ],
        ],
      ),
    );
  }

  Widget _buildVerdictChip(SyzygyResult result) {
    final style = _styleFor(result.category);
    final dtz = _dtzLabel(result.dtz);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
    final style = _styleFor(move.category);
    final dtz = _dtzLabel(move.dtz);
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
