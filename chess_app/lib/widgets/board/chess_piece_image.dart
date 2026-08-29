import 'package:chess/chess.dart' as chess;
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter/material.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/board_skins.dart';

/// The one place a piece becomes a widget.
///
/// Everything that draws a piece goes through here: the board itself, the move
/// animation, both position editors, the thumbnails in lists, and the promotion
/// dialog. That was already the intent — `chessPieceWidget` has lived in
/// `board_thumbnail.dart` since it was written, with a header saying so — and
/// it moved here on 29.8.2026 when the pieces gained colours, because a second
/// copy of this switch is a second set of pieces that quietly ignores the
/// reader's choice.
///
/// [skin] defaults to whatever the reader has chosen. A caller passes one
/// explicitly only to draw a skin that is *not* selected — the preview in
/// Settings, and nothing else so far.
Widget? chessPieceWidget(String? p, {double size = 45, PieceSkin? skin}) {
  if (p == null) return null;
  final s = skin ?? AppSettingsService.instance.pieceSkin;
  switch (p) {
    case 'P':
      return WhitePawn(
          size: size, fillColor: s.whiteFill, strokeColor: s.whiteStroke);
    case 'N':
      return WhiteKnight(
          size: size, fillColor: s.whiteFill, strokeColor: s.whiteStroke);
    case 'B':
      return WhiteBishop(
          size: size, fillColor: s.whiteFill, strokeColor: s.whiteStroke);
    case 'R':
      return WhiteRook(
          size: size, fillColor: s.whiteFill, strokeColor: s.whiteStroke);
    case 'Q':
      return WhiteQueen(
          size: size, fillColor: s.whiteFill, strokeColor: s.whiteStroke);
    case 'K':
      return WhiteKing(
          size: size, fillColor: s.whiteFill, strokeColor: s.whiteStroke);
    // The black pawn is the one piece with no interior detail, and so the one
    // black piece that takes no decoration colour.
    case 'p':
      return BlackPawn(
          size: size, fillColor: s.blackFill, strokeColor: s.blackStroke);
    case 'n':
      return BlackKnight(
          size: size,
          fillColor: s.blackFill,
          strokeColor: s.blackStroke,
          decorationColor: s.blackDecoration);
    case 'b':
      return BlackBishop(
          size: size,
          fillColor: s.blackFill,
          strokeColor: s.blackStroke,
          decorationColor: s.blackDecoration);
    case 'r':
      return BlackRook(
          size: size,
          fillColor: s.blackFill,
          strokeColor: s.blackStroke,
          decorationColor: s.blackDecoration);
    case 'q':
      return BlackQueen(
          size: size,
          fillColor: s.blackFill,
          strokeColor: s.blackStroke,
          decorationColor: s.blackDecoration);
    case 'k':
      return BlackKing(
          size: size,
          fillColor: s.blackFill,
          strokeColor: s.blackStroke,
          decorationColor: s.blackDecoration);
    default:
      return null;
  }
}

/// The same drawing, from a `chess` package piece rather than a FEN letter.
///
/// Returns a pawn for a piece it cannot read, because both callers are drawing
/// something that is already on the board — an empty square is not one of the
/// answers, and a missing piece mid-animation is worse than a wrong one.
Widget chessPieceWidgetFor(chess.Piece piece,
    {double size = 45, PieceSkin? skin}) {
  final isWhite = piece.color == chess.Color.WHITE;
  final type = piece.type.name;
  final letter = isWhite ? type.toUpperCase() : type.toLowerCase();
  return chessPieceWidget(letter, size: size, skin: skin) ??
      chessPieceWidget(isWhite ? 'P' : 'p', size: size, skin: skin)!;
}
