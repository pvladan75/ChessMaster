import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:chess_app/widgets/ai_studio/solution_tree_models.dart';

void showGroupedMovesDialog({
  required BuildContext context,
  required SolutionGraphNode node,
  required Function(SolutionGraphNode node, int selectedIndex) onMoveSelected,
}) {
  int selectedIndex = node.selectedGroupedIndex;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: const ui.Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: ui.Color(0xFF818CF8), width: 1.5),
          ),
          title: Row(
            children: const [
              Icon(Icons.filter_list, color: ui.Color(0xFF818CF8), size: 22),
              SizedBox(width: 8),
              Text(
                'Odbrambene Varijante',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Izaberite odbrambeni potez protivnika za prikaz na tabli:',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(node.groupedOpponentMoves.length, (index) {
                  final isSelected = (index == selectedIndex);
                  final san = node.groupedOpponentMoves[index];
                  return ChoiceChip(
                    selected: isSelected,
                    selectedColor: const ui.Color(0xFF0D9488),
                    backgroundColor: const ui.Color(0xFF1E293B),
                    side: BorderSide(color: isSelected ? Colors.tealAccent : const ui.Color(0xFF475569)),
                    avatar: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                    label: Text(
                      san,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const ui.Color(0xFFE0E7FF),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    onSelected: (_) {
                      setDialogState(() {
                        selectedIndex = index;
                      });
                    },
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Zatvori', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.gamepad, size: 16),
              label: const Text('Prikaži Poziciju na Tabli'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const ui.Color(0xFF0284C7),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onMoveSelected(node, selectedIndex);
              },
            ),
          ],
        );
      },
    ),
  );
}
