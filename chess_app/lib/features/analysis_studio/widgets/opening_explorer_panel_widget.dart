import 'package:flutter/material.dart';
import 'package:chess_app/features/analysis_studio/services/opening_explorer_service.dart';

// Matches the historical outcome share a move led to across real games —
// not "good/bad for the mover" (that depends on whose turn it is).
const _whiteColor = Colors.lightBlueAccent;
const _drawColor = Colors.grey;
const _blackColor = Colors.deepOrangeAccent;

/// Shows real move popularity/win-rate stats from the Lichess Opening
/// Explorer for the current position. Hidden entirely when no Lichess API
/// token is configured, since the explorer now requires authentication.
// Fixed rating buckets accepted by the Lichess Explorer `ratings` param.
// Selecting a bucket returns games whose average rating is in that bucket
// and above (e.g. 2500 means "2500+").
const kOpeningExplorerRatingOptions = <int?>[null, 1600, 1800, 2000, 2200, 2500];

String ratingOptionLabel(int? minRating) => minRating == null ? 'Svi rejtinzi' : '$minRating+';

class OpeningExplorerPanelWidget extends StatelessWidget {
  final bool hasToken;
  final bool isLoading;
  final OpeningExplorerResult? result;
  final int? minRating;
  final void Function(String uci)? onMoveSelected;
  final void Function(int? minRating)? onMinRatingChanged;

  const OpeningExplorerPanelWidget({
    super.key,
    required this.hasToken,
    required this.isLoading,
    required this.result,
    this.minRating,
    this.onMoveSelected,
    this.onMinRatingChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasToken) return const SizedBox.shrink();

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
              const Icon(Icons.travel_explore, color: Colors.purpleAccent, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  result?.opening != null
                      ? '${result!.opening!.eco} · ${result!.opening!.name}'
                      : 'Lichess Opening Explorer',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.purpleAccent),
                ),
              ),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
                  ),
                ),
              if (onMinRatingChanged != null)
                DropdownButton<int?>(
                  value: minRating,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  dropdownColor: Colors.grey.shade900,
                  icon: const Icon(Icons.expand_more, color: Colors.purpleAccent, size: 16),
                  style: const TextStyle(fontSize: 10, color: Colors.purpleAccent, fontWeight: FontWeight.bold),
                  items: kOpeningExplorerRatingOptions
                      .map((r) => DropdownMenuItem<int?>(value: r, child: Text(ratingOptionLabel(r))))
                      .toList(),
                  onChanged: onMinRatingChanged,
                ),
            ],
          ),
          if (!isLoading && result != null && result!.total > 0) ...[
            const SizedBox(height: 4),
            Text(
              '${result!.total} partija',
              style: const TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
          if (!isLoading && (result == null || result!.total == 0)) ...[
            const SizedBox(height: 6),
            const Text(
              'Nema statistike za ovu poziciju.',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
          if (!isLoading && result != null && result!.moves.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: result!.moves.map((move) => _buildMoveChip(move, result!.total)).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMoveChip(OpeningExplorerMove move, int positionTotal) {
    final percent = positionTotal == 0 ? 0 : (move.total * 100 / positionTotal).round();
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
              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
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
                          if (move.white > 0) Expanded(flex: move.white, child: const ColoredBox(color: _whiteColor)),
                          if (move.draws > 0) Expanded(flex: move.draws, child: const ColoredBox(color: _drawColor)),
                          if (move.black > 0) Expanded(flex: move.black, child: const ColoredBox(color: _blackColor)),
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
