import 'package:flutter/material.dart';
import 'package:chess/chess.dart' as chess;

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
    if (!visible || solutions.isEmpty || initialFen == null) {
      return const SizedBox.shrink();
    }

    final chips = _buildPgnChipsFromSolutions(solutions);
    if (chips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade700, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.account_tree, color: Colors.tealAccent, size: 18),
              SizedBox(width: 8),
              Text(
                'Stablo Rešenja (PGN):',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.white),
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

  List<Widget> _buildPgnChipsFromSolutions(Map<String, dynamic> solutions) {
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
        for (final m in tempBoard.moves({'verbose': true})) {
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
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    isCurrentPos ? Colors.amber.shade700 : Colors.teal.shade900,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCurrentPos
                      ? Colors.amberAccent
                      : Colors.tealAccent.withValues(alpha: 0.5),
                  width: isCurrentPos ? 2 : 1,
                ),
              ),
              child: Text(
                labelStr,
                style: TextStyle(
                  color: isCurrentPos ? Colors.white : Colors.tealAccent,
                  fontWeight:
                      isCurrentPos ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
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
