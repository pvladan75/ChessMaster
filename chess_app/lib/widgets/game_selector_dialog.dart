import 'package:flutter/material.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/theme/app_colors.dart';
import 'package:chess_app/theme/app_typography.dart';

class GameSelectorDialog extends StatefulWidget {
  final List<PgnGameInfo> games;
  final Function(PgnGameInfo game) onGameSelected;

  const GameSelectorDialog({
    super.key,
    required this.games,
    required this.onGameSelected,
  });

  @override
  State<GameSelectorDialog> createState() => _GameSelectorDialogState();
}

class _GameSelectorDialogState extends State<GameSelectorDialog> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Whether [game] matches [needle] — the two player names and the moves,
  /// and nothing else. The rest of the header map (`Event`, `Date`,
  /// `Result`, ...) is deliberately not read: a search that walked the whole
  /// map would find a date or a result and silently reorder the list.
  bool _matches(PgnGameInfo game, String needle, String movesNeedle) {
    if ((game.headers['White'] ?? '').toLowerCase().contains(needle)) {
      return true;
    }
    if ((game.headers['Black'] ?? '').toLowerCase().contains(needle)) {
      return true;
    }
    // The moves, read through `MoveTree.sanTokens`, not the raw body. The
    // owner's games carry `{ [%clk 0:03:00] }` after every move, so
    // `1. e4 { … } 1... c5` does not contain `e4 c5` and the move half of this
    // search found nothing on real data. Both sides are read the same way, so
    // a reader who types `1. e4 c5` and one who types `e4 c5` get the same
    // answer.
    if (movesNeedle.isEmpty) return false;
    return _movesOf(game).contains(movesNeedle);
  }

  /// `e4 c5 Nf3 d6`, cached: the list is rebuilt on every keystroke and a
  /// collection of four thousand games would otherwise be re-read each time.
  final Map<PgnGameInfo, String> _moveCache = {};

  String _movesOf(PgnGameInfo game) => _moveCache.putIfAbsent(
      game, () => MoveTree.sanTokens(game.pgnBody).join(' ').toLowerCase());

  /// A preview of the PGN body that stops at a whitespace boundary instead
  /// of cutting inside a move, with runs of whitespace collapsed to one
  /// space. The ellipsis is appended only when something was actually
  /// dropped.
  String _pgnPreview(String pgnBody) {
    // Written out from the moves rather than sliced out of the file, so the
    // line reads the same whatever the exporter put between the moves. Before
    // this it showed `1. e4 { [%clk 0:03:00] } 1... c5 { [%clk 0:03:00] } 2.`
    // — two moves where eight fit.
    final moves = MoveTree.sanTokens(pgnBody);
    if (moves.isEmpty) return '';

    final line = StringBuffer();
    var shown = 0;
    for (var i = 0; i < moves.length; i++) {
      // A body that starts with Black to move numbers from 1 here too; these
      // previews are of whole games, and a number that is one out is worth
      // less than a second parser to get it right.
      final piece = i.isEven ? '${i ~/ 2 + 1}. ${moves[i]}' : moves[i];
      if (line.isNotEmpty && line.length + piece.length + 1 > 60) break;
      if (line.isNotEmpty) line.write(' ');
      line.write(piece);
      shown++;
    }
    return shown < moves.length ? '$line...' : line.toString();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim();
    final needle = query.toLowerCase();
    final games = widget.games;
    final movesNeedle = MoveTree.sanTokens(query).join(' ').toLowerCase();
    final filtered = query.isEmpty
        ? games
        : games.where((g) => _matches(g, needle, movesNeedle)).toList();
    final total = games.length;

    // AlertDialog lays title, content and actions out under an
    // IntrinsicWidth, which takes the widest intrinsic and forces every
    // child to it — so the size is read from MediaQuery instead, the same
    // instinct BoardPreviewDialog already carries. Clamped on both
    // dimensions so a very large window does not give the dialog the width
    // of the screen.
    final mediaSize = MediaQuery.of(context).size;
    final dialogWidth = (mediaSize.width - 64).clamp(280.0, 640.0);
    final dialogHeight = (mediaSize.height - 260).clamp(240.0, 640.0);

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      title: Text(
        query.isEmpty
            ? 'Choose a game from the collection ($total)'
            : 'Choose a game from the collection — ${filtered.length} of $total',
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search by player or move',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No game matches "$query"',
                        textAlign: TextAlign.center,
                        style: AppText.body
                            .copyWith(color: context.colors.textMuted),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final game = filtered[index];
                        return ListTile(
                          title: Text(
                            game.displayName,
                            style: AppText.bodyLargeBold,
                          ),
                          subtitle: Text(
                            _pgnPreview(game.pgnBody),
                            style: AppText.caption
                                .copyWith(color: context.colors.textMuted),
                          ),
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 12),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onGameSelected(game);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
