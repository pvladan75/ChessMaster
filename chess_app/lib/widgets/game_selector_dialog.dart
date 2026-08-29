import 'package:flutter/material.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

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
                style: AppText.bodyLargeBold,
              ),
              subtitle: Text(
                game.pgnBody.length > 60
                    ? '${game.pgnBody.substring(0, 60)}...'
                    : game.pgnBody,
                style:
                    AppText.caption.copyWith(color: context.colors.textMuted),
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
