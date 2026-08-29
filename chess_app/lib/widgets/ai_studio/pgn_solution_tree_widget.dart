import 'package:chess/chess.dart' as chess;
import 'package:flutter/material.dart';

import 'package:chess_app/core/services/legal_moves.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

/// Called when the user taps a move chip to jump the board to that position.
typedef PgnMoveSelected = void Function(
    String from, String to, String targetFen, String labelSan);

/// Flat, chip-per-move rendering of the puzzle's solution tree, read straight
/// off the raw `{uci: {uci: ...}}` solutions map (as opposed to
/// [SolutionGraphWidget], which lays the same data out as a graph).
class PgnSolutionTreeWidget extends StatelessWidget {
  final bool visible;
  final String? initialFen;
  final Map<String, dynamic> solutions;
  final String? activeFen;
  final PgnMoveSelected onMoveSelected;

  const PgnSolutionTreeWidget({
    super.key,
    required this.visible,
    required this.initialFen,
    required this.solutions,
    required this.activeFen,
    required this.onMoveSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (!visible || solutions.isEmpty || initialFen == null) {
      return const SizedBox.shrink();
    }

    final chips = _buildPgnChipsFromSolutions(context, solutions);
    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 6),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.roundedMd,
        border: Border.all(color: Colors.teal.shade700, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree, color: colors.accent, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Stablo Rešenja (PGN):',
                style: AppText.subtitle.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPgnChipsFromSolutions(
      BuildContext context, Map<String, dynamic> solutions) {
    final colors = context.colors;
    final List<Widget> chips = [];

    final tempBoard = chess.Chess.fromFEN(initialFen!);
    final fenParts = initialFen!.split(' ');
    int moveNum = fenParts.length > 5 ? (int.tryParse(fenParts[5]) ?? 1) : 1;
    bool isWhiteToMove = (tempBoard.turn == chess.Color.WHITE);

    void traverseNode(
        Map<String, dynamic> node, int num, bool isWhite, String prefix) {
      for (var uciMove in node.keys) {
        if (uciMove.length < 4) continue;
        final from = uciMove.substring(0, 2);
        final to = uciMove.substring(2, 4);
        final promo = uciMove.length > 4 ? uciMove[4] : null;

        // The chess package's history entries carry no SAN string at all
        // (only from/to/flags/piece) — has to come from the verbose
        // pre-move candidate list, which does have a 'san' key, so look
        // it up there before actually playing the move.
        String sanStr = uciMove;
        for (final m in legalMoves(tempBoard)) {
          if (m['from'] == from && m['to'] == to) {
            if (promo == null ||
                m['promotion'] == promo ||
                m['promotion'] == promo.toLowerCase()) {
              sanStr = (m['san'] as String?) ?? uciMove;
              break;
            }
          }
        }

        tempBoard.move({'from': from, 'to': to, 'promotion': promo});

        final targetFen = tempBoard.fen;
        final String labelStr = isWhite ? '$num. $sanStr' : '$num... $sanStr';
        final bool isCurrentPos = (activeFen == targetFen);

        chips.add(
          InkWell(
            onTap: () => onMoveSelected(from, to, targetFen, labelStr),
            borderRadius: AppRadii.roundedSm,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isCurrentPos
                    ? colors.warning.withValues(alpha: 0.22)
                    : colors.surfaceRaised,
                borderRadius: AppRadii.roundedSm,
                border: Border.all(
                  color: isCurrentPos
                      ? colors.warning
                      : colors.accent.withValues(alpha: 0.5),
                  width: isCurrentPos ? 2 : 1,
                ),
              ),
              child: Text(
                labelStr,
                style:
                    (isCurrentPos ? AppText.bodyLargeBold : AppText.bodyLarge)
                        .copyWith(
                  color: isCurrentPos ? colors.warning : colors.accent,
                ),
              ),
            ),
          ),
        );

        final subVal = node[uciMove];
        if (subVal is Map && subVal.isNotEmpty) {
          final nextMap = Map<String, dynamic>.from(subVal);
          final nextIsWhite = !isWhite;
          final nextNum = nextIsWhite ? num + 1 : num;
          traverseNode(nextMap, nextNum, nextIsWhite, prefix);
        }

        tempBoard.undo();
      }
    }

    traverseNode(solutions, moveNum, isWhiteToMove, '');
    return chips;
  }
}
