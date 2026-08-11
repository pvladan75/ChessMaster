import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

class StudioInfoHeaderWidget extends StatelessWidget {
  final String? selectedCategory;
  final String selectedMateDepth;
  final String selectedBasicMateType;
  final PlayerColor puzzleOrientation;
  final VoidCallback onBackToHub;
  final VoidCallback onRestartPuzzle;
  final VoidCallback onNextPuzzle;

  const StudioInfoHeaderWidget({
    super.key,
    required this.selectedCategory,
    required this.selectedMateDepth,
    required this.selectedBasicMateType,
    required this.puzzleOrientation,
    required this.onBackToHub,
    required this.onRestartPuzzle,
    required this.onNextPuzzle,
  });

  String get headerGoal {
    return selectedCategory == 'mate_puzzle'
        ? '${puzzleOrientation == PlayerColor.white ? "⚪ Beli" : "⚫ Crni"} na potezu - Mat u $selectedMateDepth ${selectedMateDepth == '1' ? 'potez' : 'poteza'}'
        : (selectedCategory == 'basic_mate'
            ? 'Vežbanje: $selectedBasicMateType (Matirajte Stockfish-a)'
            : '${puzzleOrientation == PlayerColor.white ? "⚪ Beli" : "⚫ Crni"} na potezu - Pronađite dobitni put');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox.shrink(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: puzzleOrientation == PlayerColor.white ? Colors.blueGrey.shade900 : Colors.teal.shade900,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: puzzleOrientation == PlayerColor.white ? Colors.white38 : Colors.tealAccent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flag,
                size: 18,
                color: puzzleOrientation == PlayerColor.white ? Colors.white : Colors.tealAccent,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  headerGoal,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
