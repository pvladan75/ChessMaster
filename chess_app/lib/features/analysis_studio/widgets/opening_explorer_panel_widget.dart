import 'package:flutter/material.dart';

import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Shows move popularity and outcome statistics from the master opening book
/// on our server.
class OpeningExplorerPanelWidget extends StatelessWidget {
  final bool isLoading;
  final OpeningExplorerResult? result;
  final String? reason;
  final String? openingName;
  final void Function(String uci)? onMoveSelected;

  const OpeningExplorerPanelWidget({
    super.key,
    required this.isLoading,
    required this.result,
    this.reason,
    this.openingName,
    this.onMoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final String? statusMessage;
    if (isLoading) {
      statusMessage = null;
    } else if (reason != null) {
      if (reason == 'guest') {
        statusMessage = 'Sign in to see the opening book.';
      } else if (reason == 'not-configured' ||
          reason == 'unreadable' ||
          reason == 'inconsistent') {
        statusMessage = 'The opening book is not available on this server.';
      } else {
        statusMessage = 'The opening book could not be reached.';
      }
    } else if (result?.beyondBook == true) {
      statusMessage = 'This position is deeper than the opening book goes.';
    } else if (result == null || result!.total == 0) {
      statusMessage = 'No master game reached this position.';
    } else {
      statusMessage = null;
    }

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
              Icon(Icons.travel_explore, color: colors.accentAlt, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  openingName != null && openingName!.isNotEmpty
                      ? openingName!
                      : 'Opening book',
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyBold.copyWith(color: colors.accentAlt),
                ),
              ),
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colors.accentAlt,
                    ),
                  ),
                ),
            ],
          ),
          if (!isLoading) ...[
            if (statusMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                statusMessage,
                style: AppText.caption.copyWith(color: colors.textSecondary),
              ),
            ] else if (result != null && result!.total > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${result!.total} ${result!.total == 1 ? 'game' : 'games'}',
                style: AppText.micro.copyWith(color: colors.textMuted),
              ),
              if (result!.moves.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: result!.moves
                      .map((move) =>
                          _buildMoveChip(context, move, result!.total))
                      .toList(),
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMoveChip(
    BuildContext context,
    OpeningExplorerMove move,
    int positionTotal,
  ) {
    final colors = context.colors;
    final percent =
        positionTotal == 0 ? 0 : (move.total * 100 / positionTotal).round();
    return InkWell(
      onTap: onMoveSelected != null ? () => onMoveSelected!(move.uci) : null,
      borderRadius: AppRadii.roundedSm,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: AppRadii.roundedSm,
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${move.san} ($percent%)',
              style: AppText.caption.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                width: 60,
                height: 4,
                child: move.total == 0
                    ? ColoredBox(color: colors.border)
                    : Row(
                        children: [
                          if (move.white > 0)
                            Expanded(
                              flex: move.white,
                              child: ColoredBox(color: colors.sideWhite),
                            ),
                          if (move.draws > 0)
                            Expanded(
                              flex: move.draws,
                              child: ColoredBox(color: colors.sideDraw),
                            ),
                          if (move.black > 0)
                            Expanded(
                              flex: move.black,
                              child: ColoredBox(color: colors.sideBlack),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
