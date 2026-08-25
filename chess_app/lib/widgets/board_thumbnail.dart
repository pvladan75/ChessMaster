import 'package:flutter/material.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';

/// Maps a FEN piece letter ('P','n', ...) to the same chess_vectors_flutter
/// widget the live board renders, so any custom board UI (setup editors,
/// thumbnails) stays visually identical to the rest of the app. Returns null
/// for an empty square or unrecognized letter.
Widget? chessPieceWidget(String? p, {double size = 45}) {
  if (p == null) return null;
  switch (p) {
    case 'P':
      return WhitePawn(size: size);
    case 'N':
      return WhiteKnight(size: size);
    case 'B':
      return WhiteBishop(size: size);
    case 'R':
      return WhiteRook(size: size);
    case 'Q':
      return WhiteQueen(size: size);
    case 'K':
      return WhiteKing(size: size);
    case 'p':
      return BlackPawn(size: size);
    case 'n':
      return BlackKnight(size: size);
    case 'b':
      return BlackBishop(size: size);
    case 'r':
      return BlackRook(size: size);
    case 'q':
      return BlackQueen(size: size);
    case 'k':
      return BlackKing(size: size);
    default:
      return null;
  }
}

/// Small static board preview rendered from a FEN's piece placement, using
/// the same chess_vectors_flutter piece art as the live board everywhere
/// else in the app. Not interactive — purely a visual identifier for lists.
class BoardThumbnail extends StatelessWidget {
  final String fen;
  final double size;

  const BoardThumbnail({super.key, required this.fen, this.size = 40});

  static const _lightSquare = Color(0xFFEEEED2);
  static const _darkSquare = Color(0xFF769656);

  List<List<String?>> _parseBoard() {
    final grid =
        List<List<String?>>.generate(8, (_) => List<String?>.filled(8, null));
    try {
      final placement = fen.trim().split(' ').first;
      final rows = placement.split('/');
      for (int r = 0; r < 8 && r < rows.length; r++) {
        int c = 0;
        for (final char in rows[r].split('')) {
          if (c >= 8) break;
          final digit = int.tryParse(char);
          if (digit != null) {
            c += digit;
          } else {
            grid[r][c] = char;
            c++;
          }
        }
      }
    } catch (_) {}
    return grid;
  }

  @override
  Widget build(BuildContext context) {
    final grid = _parseBoard();
    final tileSize = size / 8;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: size,
        height: size,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8),
          itemCount: 64,
          itemBuilder: (context, index) {
            final r = index ~/ 8;
            final c = index % 8;
            final isLight = (r + c) % 2 == 0;
            final piece = chessPieceWidget(grid[r][c], size: tileSize);
            return Container(
              color: isLight ? _lightSquare : _darkSquare,
              child: piece == null ? null : Center(child: piece),
            );
          },
        ),
      ),
    );
  }
}
