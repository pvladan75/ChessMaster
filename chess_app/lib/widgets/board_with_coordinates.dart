import 'package:flutter/material.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

/// Frames a board with file letters and rank numbers.
///
/// The board package draws none, and without them a flipped board is a guess.
/// That matters most where the app turns the board on its own — the endgame
/// trainer orients every position toward whoever has to solve it, and the
/// punishment drill turns it again mid-exercise — so "which way is this" stops
/// being answerable from the pieces alone.
///
/// On the edge rather than in every square: a coordinate in each square reads
/// as clutter on a phone and competes with the pieces, which are the thing to
/// look at.
///
/// [size] is the whole thing, gutter included, so a caller that already worked
/// out how much room it has can pass the same number it would have given the
/// board and nothing overflows.
class BoardWithCoordinates extends StatelessWidget {
  const BoardWithCoordinates({
    super.key,
    required this.size,
    required this.orientation,
    required this.builder,
  });

  final double size;
  final PlayerColor orientation;

  /// Called with what is left for the board once the labels have their strip.
  final Widget Function(double boardSize) builder;

  static const _files = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];

  @override
  Widget build(BuildContext context) {
    // Enough for a digit at any board size, and capped so a large board does
    // not grow a wide margin it has no use for.
    final gutter = (size * 0.05).clamp(12.0, 20.0);
    final boardSize = size - gutter;
    final whiteAtBottom = orientation == PlayerColor.white;

    final ranks = List<int>.generate(8, (i) => whiteAtBottom ? 8 - i : i + 1);
    final files = whiteAtBottom ? _files : _files.reversed.toList();

    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(
                alpha: 0.7,
              ),
        );

    return SizedBox(
      width: size,
      height: size,
      child: Column(
        children: [
          SizedBox(
            height: boardSize,
            child: Row(
              children: [
                SizedBox(
                  width: gutter,
                  child: Column(
                    children: [
                      for (final rank in ranks)
                        Expanded(
                          child: Center(child: Text('$rank', style: style)),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  width: boardSize,
                  height: boardSize,
                  child: builder(boardSize),
                ),
              ],
            ),
          ),
          SizedBox(
            height: gutter,
            child: Row(
              children: [
                SizedBox(width: gutter),
                for (final file in files)
                  SizedBox(
                    width: boardSize / 8,
                    child: Center(child: Text(file, style: style)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
