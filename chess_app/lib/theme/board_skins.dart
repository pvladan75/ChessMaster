import 'package:flutter/material.dart';

/// The colours of the board itself, and of the pieces standing on it.
///
/// Deliberately **not** a [ThemeExtension], and deliberately not part of
/// `AppColorTokens`. Three reasons, and each one is a thing that would break if
/// this followed the app theme:
///
/// 1. A skin is a taste, not a palette. A green board in the light theme is a
///    legitimate choice and every chess program allows it, so the board must
///    survive a switch from light to dark unchanged.
/// 2. A piece skin has to be readable from places that have no `BuildContext`
///    — `pieceImageForAnimation` in `board_overlay_painter.dart` is called from
///    inside a widget that only knows a board size and an orientation.
/// 3. Rule 14 in `.agents/agents/flutter_token_migrator.md` forbids stretching
///    a token named `surface` to mean "light square". A domain colour gets a
///    domain-named home instead. This is that home.
///
/// Chosen by the reader in Settings and stored by [id]; the id is never
/// translated and never renamed, because it is what sits in `SharedPreferences`
/// and a renamed id silently resets everybody's choice back to the default.
@immutable
class BoardSkin {
  /// Stored in preferences. Never translated, never renamed.
  final String id;

  /// Shown in Settings, in Serbian, like every other user-facing string.
  final String name;

  final Color lightSquare;
  final Color darkSquare;

  const BoardSkin({
    required this.id,
    required this.name,
    required this.lightSquare,
    required this.darkSquare,
  });

  /// The board this app has always drawn.
  ///
  /// These are not invented values: they are the exact pixels of
  /// `images/brown_board.png` inside `flutter_chess_board`, which is a flat
  /// two-colour image rather than a wood texture — sampled 29.8.2026, 120
  /// colours in the whole file and all of them antialiasing along the square
  /// seams. Painting the squares instead of drawing that image is therefore a
  /// pixel-faithful change, minus a blurred seam: the board is 375 px wide and
  /// 375/8 is not a whole number, so every edge in the PNG is blended.
  ///
  /// It exists so a reader who changes nothing sees no change. Do not retune it.
  static const BoardSkin classic = BoardSkin(
    id: 'classic',
    name: 'Klasična',
    lightSquare: Color(0xFFF0DAB5),
    darkSquare: Color(0xFFB58763),
  );

  static const BoardSkin green = BoardSkin(
    id: 'green',
    name: 'Zelena',
    lightSquare: Color(0xFFE9EDCC),
    darkSquare: Color(0xFF779556),
  );

  static const BoardSkin blue = BoardSkin(
    id: 'blue',
    name: 'Plava',
    lightSquare: Color(0xFFC4D1D1),
    darkSquare: Color(0xFF677C8D),
  );

  static const BoardSkin highContrast = BoardSkin(
    id: 'high_contrast',
    name: 'Visoki kontrast',
    lightSquare: Color(0xFFFFFFFF),
    darkSquare: Color(0xFF737373),
  );

  static const BoardSkin grayscale = BoardSkin(
    id: 'grayscale',
    name: 'Siva',
    lightSquare: Color(0xFFE2E2E2),
    darkSquare: Color(0xFF8C8C8C),
  );

  /// Every skin offered, in the order Settings shows them.
  static const List<BoardSkin> all = [
    classic,
    green,
    blue,
    highContrast,
    grayscale,
  ];

  /// Falls back rather than throws: an id can come from a preference written by
  /// a newer build, or by a build where a skin existed that has since been
  /// dropped. Neither is a reason to fail to draw a board.
  static BoardSkin byId(String? id) {
    for (final skin in all) {
      if (skin.id == id) return skin;
    }
    return classic;
  }
}

/// The fill and stroke handed to the `chess_vectors_flutter` piece widgets.
///
/// Those widgets have always accepted `fillColor` and `strokeColor` — nothing
/// in this app ever passed them, so every board in it has drawn the package
/// defaults. This is the type that carries an answer instead.
///
/// [blackDecoration] is the third colour the black pieces take: the knight's
/// eye and mane, the bishop's cross, the rook's and queen's inlays, the king's
/// cross. It defaults to white in the package, which is what makes a black
/// piece legible as a *knight* rather than a silhouette. The black pawn is the
/// one piece with no decoration — it has no interior detail to lose.
@immutable
class PieceSkin {
  final String id;
  final String name;

  final Color whiteFill;
  final Color whiteStroke;

  final Color blackFill;
  final Color blackStroke;
  final Color blackDecoration;

  const PieceSkin({
    required this.id,
    required this.name,
    required this.whiteFill,
    required this.whiteStroke,
    required this.blackFill,
    required this.blackStroke,
    required this.blackDecoration,
  });

  /// The package defaults, which is what every board in the app draws today.
  ///
  /// Note that a white piece is drawn by its *stroke*: white fill on the
  /// classic light square measures about 1.3:1, and it has always been legible
  /// because the black outline does the work. Any new piece skin inherits that
  /// constraint — the stroke is what has to separate from the square.
  static const PieceSkin classic = PieceSkin(
    id: 'classic',
    name: 'Klasične',
    whiteFill: Color(0xFFFFFFFF),
    whiteStroke: Color(0xFF000000),
    blackFill: Color(0xFF000000),
    blackStroke: Color(0xFF000000),
    blackDecoration: Color(0xFFFFFFFF),
  );

  static const PieceSkin warm = PieceSkin(
    id: 'warm',
    name: 'Tople',
    whiteFill: Color(0xFFFDF6E3),
    whiteStroke: Color(0xFF222222),
    blackFill: Color(0xFF222222),
    blackStroke: Color(0xFF222222),
    blackDecoration: Color(0xFFFDF6E3),
  );

  static const PieceSkin highContrast = PieceSkin(
    id: 'high_contrast',
    name: 'Visoki kontrast',
    whiteFill: Color(0xFFFFFF00),
    whiteStroke: Color(0xFF000000),
    blackFill: Color(0xFF000000),
    blackStroke: Color(0xFF000000),
    blackDecoration: Color(0xFFFFFF00),
  );

  static const List<PieceSkin> all = [classic, warm, highContrast];

  static PieceSkin byId(String? id) {
    for (final skin in all) {
      if (skin.id == id) return skin;
    }
    return classic;
  }
}
