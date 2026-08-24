import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';
import 'package:chess_app/features/analysis_studio/services/chessdb_service.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

// Matches the historical outcome share a move led to across real games —
// not "good/bad for the mover" (that depends on whose turn it is).
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
    if (!useLichess) return _buildChessDbPanel(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade900.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore,
                  color: context.colors.accentAlt, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result?.opening != null
                      ? '${result!.opening!.eco} · ${result!.opening!.name}'
                      : 'Lichess Opening Explorer',
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.accentAlt),
                ),
              ),
              if (isLoading)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.colors.accentAlt),
                  ),
                ),
              if (onMinRatingChanged != null)
                DropdownButton<int?>(
                  value: minRating,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: Colors.grey.shade900,
                  icon: Icon(Icons.expand_more,
                      color: context.colors.accentAlt, size: 16),
                  style: AppText.micro.copyWith(
                      color: context.colors.accentAlt,
                      fontWeight: FontWeight.bold),
                  items: kOpeningExplorerRatingOptions
                      .map((r) => DropdownMenuItem<int?>(
                          value: r, child: Text(ratingOptionLabel(r))))
                      .toList(),
                  onChanged: onMinRatingChanged,
                ),
            ],
          ),
          if (!isLoading && result != null && result!.total > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${result!.total} partija',
              style: AppText.micro.copyWith(color: context.colors.textMuted),
            ),
          ],
          if (!isLoading && (result == null || result!.total == 0)) ...[
            const SizedBox(height: 6),
            Text(
              'Nema statistike za ovu poziciju.',
              style:
                  AppText.caption.copyWith(color: context.colors.textSecondary),
            ),
          ],
          if (!isLoading && result != null && result!.moves.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result!.moves
                  .map((move) => _buildMoveChip(move, result!.total))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChessDbPanel(BuildContext context) {
    final moves = chessDbResult?.moves ?? [];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade900.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined,
                  color: context.colors.accentAlt, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ChessDB Cloud (konsenzus, ne partije)',
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyBold
                      .copyWith(color: context.colors.accentAlt),
                ),
              ),
              if (isLoadingChessDb)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: context.colors.accentAlt),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Procena iz motorske analize, ne iz odigranih partija. Za pravu statistiku izaberite Lichess u Podešavanjima.',
            style: AppText.micro.copyWith(
                color: context.colors.textPrimary.withValues(alpha: 0.5)),
          ),
          if (!isLoadingChessDb && moves.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Nema podataka za ovu poziciju.',
              style:
                  AppText.caption.copyWith(color: context.colors.textSecondary),
            ),
          ],
          if (!isLoadingChessDb && moves.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: moves
                  .take(8)
                  .map((m) => _buildChessDbMoveChip(m, chessDbResult!.fen))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChessDbMoveChip(ChessDbMove move, String fen) {
    final san = _sanFromUci(fen, move.uci);
    final scoreLabel = move.score > 0
        ? '+${(move.score / 100).toStringAsFixed(2)}'
        : (move.score / 100).toStringAsFixed(2);
    final winrateColor = move.winrate >= 55
        ? Colors.greenAccent
        : (move.winrate <= 45 ? Colors.redAccent : Colors.white70);
    return InkWell(
      onTap: onMoveSelected != null ? () => onMoveSelected!(move.uci) : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              san,
              style: AppText.caption
                  .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
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
      for (final m in game.moves({'verbose': true})) {
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

  Widget _buildMoveChip(OpeningExplorerMove move, int positionTotal) {
    final percent =
        positionTotal == 0 ? 0 : (move.total * 100 / positionTotal).round();
    return InkWell(
      onTap: onMoveSelected != null ? () => onMoveSelected!(move.uci) : null,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${move.san} ($percent%)',
              style: AppText.caption
                  .copyWith(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: SizedBox(
                width: 60,
                height: 4,
                child: move.total == 0
                    ? const ColoredBox(color: Colors.white24)
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
