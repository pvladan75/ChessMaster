import 'package:flutter/material.dart';
import 'package:chess_app/move_tree.dart';

class GameSelectorDialog extends StatelessWidget {
  final List<PgnGameInfo> games;
  final Function(PgnGameInfo game) onGameSelected;

  const GameSelectorDialog({
    super.key,
    required this.games,
    required this.onGameSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Izaberite partiju zbirke (${games.length})'),
      content: SizedBox(
        width: 400,
        height: 300,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: games.length,
          itemBuilder: (context, index) {
            final game = games[index];
            return ListTile(
              title: Text(
                game.displayName,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: Text(
                game.pgnBody.length > 60
                    ? '${game.pgnBody.substring(0, 60)}...'
                    : game.pgnBody,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 12),
              onTap: () {
                Navigator.pop(context);
                onGameSelected(game);
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Otkaži'),
        ),
      ],
    );
  }
}
