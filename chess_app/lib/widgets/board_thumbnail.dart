import 'package:flutter/material.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/app_radii.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board/chess_piece_image.dart';

// `chessPieceWidget` used to live here, and four dialogs still import it from
// this file. It moved to `board/chess_piece_image.dart` on 29.8.2026, when the
// pieces gained colours and the live board started drawing from the same
// factory; this re-export keeps those imports working rather than renaming them
// in four files for no gain.
export 'package:chess_app/widgets/board/chess_piece_image.dart'
    show chessPieceWidget;

/// Small static board preview rendered from a FEN's piece placement, using
/// the same chess_vectors_flutter piece art as the live board everywhere
/// else in the app. Not interactive — purely a visual identifier for lists.
class BoardThumbnail extends StatelessWidget {
  final String fen;
  final double size;

  /// Null takes the reader's chosen board. Settings passes one explicitly, to
  /// show a skin before it is the chosen one.
  final BoardSkin? skin;

  /// Same, for the pieces standing on it.
  final PieceSkin? pieceSkin;

  const BoardThumbnail({
    super.key,
    required this.fen,
    this.size = 40,
    this.skin,
    this.pieceSkin,
  });

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
    // Until 29.8.2026 this drew #EEEED2/#769656 — a green board, while every
    // live board in the app was brown. Two boards on one screen disagreeing
    // about what a chessboard looks like was the whole reason to make it a
    // skin.
    final board = skin ?? AppSettingsService.instance.boardSkin;

    return ClipRRect(
      borderRadius: AppRadii.roundedXs,
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
            final piece =
                chessPieceWidget(grid[r][c], size: tileSize, skin: pieceSkin);
            return Container(
              color: isLight ? board.lightSquare : board.darkSquare,
              child: piece == null ? null : Center(child: piece),
            );
          },
        ),
      ),
    );
  }
}
