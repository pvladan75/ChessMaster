import 'package:chess/chess.dart' as chess;
import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/features/analysis_studio/services/chessdb_service.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';
import 'package:flutter/material.dart';

// Matches the historical outcome share a move led to across real games —
// not "good/bad for the mover" (that depends on whose turn it is).
// Domain constants: Opening outcome breakdown bar colors.
const _whiteColor = Colors.lightBlueAccent;
const _drawColor = Colors.grey;
const _blackColor = Colors.deepOrangeAccent;

/// Shows real move popularity/win-rate stats from the Lichess Opening
/// Explorer for the current position. Falls back to the ChessDB panel when the
/// user picked ChessDB as their source, and when the Explorer could not be
/// reached at all - the two look the same on screen but never in the log.
// Rating floors offered to the user. The chosen one is a floor and not a
// bucket: the backend expands 1600 into every bucket from 1600 up, so the
// "1600+" on the chip is what the numbers below it actually count.
const kOpeningExplorerRatingOptions = <int?>[
  null,
  1600,
  1800,
  2000,
  2200,
  2500
];

String ratingOptionLabel(int? minRating) =>
    minRating == null ? 'Svi rejtinzi' : '$minRating+';

class OpeningExplorerPanelWidget extends StatelessWidget {
  final bool useLichess;
  final bool isLoading;
  final OpeningExplorerResult? result;
  final int? minRating;
  final void Function(String uci)? onMoveSelected;
  final void Function(int? minRating)? onMinRatingChanged;
  // Free, no-account fallback: the user's choice, or the Explorer being down.
  final ChessDbResult? chessDbResult;
  final bool isLoadingChessDb;

  const OpeningExplorerPanelWidget({
    super.key,
    required this.useLichess,
    required this.isLoading,
    required this.result,
    this.minRating,
    this.onMoveSelected,
    this.onMinRatingChanged,
    this.chessDbResult,
    this.isLoadingChessDb = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!useLichess) return _buildChessDbPanel(context);

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
                  result?.opening != null
                      ? '${result!.opening!.eco} · ${result!.opening!.name}'
                      : 'Lichess Opening Explorer',
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyBold.copyWith(color: colors.accentAlt),
                ),
              ),
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: colors.accentAlt),
                  ),
                ),
              if (onMinRatingChanged != null)
                DropdownButton<int?>(
                  value: minRating,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: colors.surface,
                  icon: Icon(Icons.expand_more,
                      color: colors.accentAlt, size: 16),
                  style: AppText.micro.copyWith(
                      color: colors.accentAlt, fontWeight: FontWeight.bold),
                  items: kOpeningExplorerRatingOptions
                      .map((r) => DropdownMenuItem<int?>(
                          value: r, child: Text(ratingOptionLabel(r))))
                      .toList(),
                  onChanged: onMinRatingChanged,
                ),
            ],
          ),
          if (!isLoading && result != null && result!.total > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${result!.total} partija',
              style: AppText.micro.copyWith(color: colors.textMuted),
            ),
          ],
          if (!isLoading && (result == null || result!.total == 0)) ...[
            const SizedBox(height: 6),
            Text(
              'Nema statistike za ovu poziciju.',
              style: AppText.caption.copyWith(color: colors.textSecondary),
            ),
          ],
          if (!isLoading && result != null && result!.moves.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result!.moves
                  .map((move) => _buildMoveChip(context, move, result!.total))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChessDbPanel(BuildContext context) {
    final colors = context.colors;
    final moves = chessDbResult?.moves ?? [];

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
              Icon(Icons.cloud_outlined, color: colors.accentAlt, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ChessDB Cloud (konsenzus, ne partije)',
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyBold.copyWith(color: colors.accentAlt),
                ),
              ),
              if (isLoadingChessDb)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: colors.accentAlt),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Procena iz motorske analize, ne iz odigranih partija. Za pravu statistiku izaberite Lichess u Podešavanjima.',
            style: AppText.micro.copyWith(color: colors.textSecondary),
          ),
          if (!isLoadingChessDb && moves.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Nema podataka za ovu poziciju.',
              style: AppText.caption.copyWith(color: colors.textSecondary),
            ),
          ],
          if (!isLoadingChessDb && moves.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: moves
                  .take(8)
                  .map((m) =>
                      _buildChessDbMoveChip(context, m, chessDbResult!.fen))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChessDbMoveChip(
      BuildContext context, ChessDbMove move, String fen) {
    final colors = context.colors;
    final san = _sanFromUci(fen, move.uci);
    final scoreLabel = move.score > 0
        ? '+${(move.score / 100).toStringAsFixed(2)}'
        : (move.score / 100).toStringAsFixed(2);
    final winrateColor = move.winrate >= 55
        ? colors.success
        : (move.winrate <= 45 ? colors.danger : colors.textSecondary);
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
              san,
              style: AppText.caption.copyWith(
                  color: colors.textPrimary, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '$scoreLabel · ${move.winrate.toStringAsFixed(0)}%',
              style: AppText.micro
                  .copyWith(color: winrateColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  String _sanFromUci(String fen, String uci) {
    if (uci.length < 4) return uci;
    try {
      final game = chess.Chess.fromFEN(fen);
      final from = uci.substring(0, 2);
      final to = uci.substring(2, 4);
      final promo = uci.length > 4 ? uci.substring(4, 5) : null;
      // The chess package's history entries carry no SAN string at all
      // (State only has from/to/flags/piece) — verbose pre-move candidates
      // are the only place a 'san' key actually exists, so look the move up
      // there instead of playing it and hoping history recorded it.
      for (final m in legalMoves(game)) {
        if (m['from'] == from && m['to'] == to) {
          if (promo == null ||
              m['promotion'] == promo ||
              m['promotion'] == promo.toLowerCase()) {
            return (m['san'] as String?) ?? uci;
          }
        }
      }
    } catch (_) {}
    return uci;
  }

  Widget _buildMoveChip(
      BuildContext context, OpeningExplorerMove move, int positionTotal) {
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
                  color: colors.textPrimary, fontWeight: FontWeight.w600),
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
                                child: const ColoredBox(color: _whiteColor)),
                          if (move.draws > 0)
                            Expanded(
                                flex: move.draws,
                                child: const ColoredBox(color: _drawColor)),
                          if (move.black > 0)
                            Expanded(
                                flex: move.black,
                                child: const ColoredBox(color: _blackColor)),
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
