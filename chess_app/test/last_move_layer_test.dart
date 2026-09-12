import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
// The package's barrel re-exports `package:chess`, whose `Color` enum would
// otherwise shadow Flutter's — the same collision `board_skin_rendering_test`
// solves the same way.
import 'package:flutter_chess_board/flutter_chess_board.dart' hide Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chess_app/services/app_settings_service.dart';
import 'package:chess_app/theme/board_skins.dart';
import 'package:chess_app/widgets/board/skinned_chess_board.dart';

/// Phase 0 of `docs/PLAN-OZNAKE-NA-TABLI.md`: the last move is drawn on a layer
/// **between the squares and the pieces**.
///
/// ## Why this is a pixel test and not a widget-tree test
///
/// The claim is about paint order, and the three things being ordered are not
/// comparable objects: the squares and the wash are `CustomPaint` siblings, and
/// the pieces are a `GridView` of widgets with their own render objects. There
/// is no single canvas holding all three to read an order off, and asserting
/// the *index* of a child in a `Stack` would pass for a layer that was moved
/// into a different `Stack` entirely.
///
/// So the question is asked of the picture, which is where the answer actually
/// lives: **a pixel of the square changes and a pixel of the piece does not.**
/// One of those alone proves nothing — "the square darkened" is equally true of
/// a wash painted over everything, and "the piece is untouched" is equally true
/// of a layer that draws nothing at all. It is the pair that pins the order,
/// and the mutation this file exists for — moving the layer after the piece
/// grid — fails the second half while passing the first.
///
/// ## Why the sampled pixels are found rather than written down
///
/// A rook glyph does not fill its square, and which pixels are ink and which
/// are board is a property of `chess_vectors_flutter` that no test should
/// hard-code. So both pixels are located in the **unmarked** render by matching
/// exact colours — the skin's own square colour, and the piece skin's own fill
/// — and the test fails saying so if it cannot find them. That also makes the
/// sampling self-validating: a pixel called "on the piece" is one that was
/// measured to be the piece's colour.
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsService.instance.init();
  });

  // Colours that appear nowhere else, so a pixel carrying one has been drawn by
  // this skin rather than by a default that happens to match.
  const skin = BoardSkin(
    id: 'test-layer',
    name: 'Testna',
    lightSquare: Color(0xFFE8E8E8),
    darkSquare: Color(0xFF3C6E3C),
  );
  const pieces = PieceSkin(
    id: 'test-layer-pieces',
    name: 'Testne',
    whiteFill: Color(0xFFFFFDF7),
    whiteStroke: Color(0xFF202020),
    blackFill: Color(0xFF101010),
    blackStroke: Color(0xFF202020),
    blackDecoration: Color(0xFF303030),
  );

  // A lone white rook on e4, so exactly one square of the board carries a piece
  // and every other square answers for the board alone.
  const fen = '8/8/8/8/4R3/8/8/8 w - - 0 1';
  const boardEdge = 400.0;
  const squareEdge = boardEdge / 8;
  const key = ValueKey('board');

  // e4 with the board the usual way up: file e is column 4, rank 4 is row 4.
  const e4 =
      Rect.fromLTWH(4 * squareEdge, 4 * squareEdge, squareEdge, squareEdge);
  // a1, which no move in this file touches.
  const a1 = Rect.fromLTWH(0, 7 * squareEdge, squareEdge, squareEdge);

  Widget wrap(Widget child) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child:
                  SizedBox(width: boardEdge, height: boardEdge, child: child),
            ),
          ),
        ),
      );

  /// The rendered board as raw RGBA, at one device pixel per logical pixel so
  /// the rectangles above address it directly.
  Future<(Uint8List, int)> render(WidgetTester tester,
      {String? from, String? to}) async {
    await tester.pumpWidget(wrap(SkinnedChessBoard(
      controller: ChessBoardController()..loadFen(fen),
      boardSkin: skin,
      pieceSkin: pieces,
      lastMoveFrom: from,
      lastMoveTo: to,
    )));
    await tester.pumpAndSettle();

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    late Uint8List bytes;
    late int width;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      width = image.width;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      bytes = data!.buffer.asUint8List();
    });
    return (bytes, width);
  }

  Color pixel(Uint8List bytes, int width, int x, int y) {
    final i = (y * width + x) * 4;
    return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
  }

  /// The first pixel inside [area] that is exactly [wanted], scanned in a grid
  /// fine enough to find a glyph's interior and coarse enough to be quick.
  Offset? findPixel(Uint8List bytes, int width, Rect area, Color wanted) {
    for (var y = area.top.toInt() + 1; y < area.bottom.toInt() - 1; y += 2) {
      for (var x = area.left.toInt() + 1; x < area.right.toInt() - 1; x += 2) {
        if (pixel(bytes, width, x, y) == wanted) {
          return Offset(x + 0.0, y + 0.0);
        }
      }
    }
    return null;
  }

  testWidgets('the wash darkens the square and leaves the piece alone',
      (tester) async {
    final (plain, width) = await render(tester);

    // Both sampled pixels come out of the render with no move on it, so each is
    // known to be what it is called rather than assumed to be.
    final onBoard = findPixel(plain, width, e4, skin.lightSquare);
    final onPiece = findPixel(plain, width, e4, pieces.whiteFill);
    expect(onBoard, isNotNull,
        reason: 'no pixel of e4 is the skin\'s dark square — the board is not '
            'being drawn with the skin this test passed it');
    expect(onPiece, isNotNull,
        reason: 'no pixel of e4 is the piece skin\'s white fill — the rook is '
            'not on the square, so this test proves nothing about a wash '
            'under it');

    final (marked, _) = await render(tester, from: 'e1', to: 'e4');

    expect(
      pixel(marked, width, onBoard!.dx.toInt(), onBoard.dy.toInt()),
      isNot(pixel(plain, width, onBoard.dx.toInt(), onBoard.dy.toInt())),
      reason: 'the square of the last move is not drawn any differently — the '
          'layer is painting nothing',
    );
    expect(
      pixel(marked, width, onPiece!.dx.toInt(), onPiece.dy.toInt()),
      pixel(plain, width, onPiece.dx.toInt(), onPiece.dy.toInt()),
      reason: 'the piece standing on the square changed colour, so the wash is '
          'being painted over it rather than under it — which is the whole '
          'thing this layer exists to avoid',
    );
  });

  testWidgets('the square left behind is marked too', (tester) async {
    final (plain, width) = await render(tester);
    // e1 is empty in this position, so its whole area answers for the board.
    const e1 =
        Rect.fromLTWH(4 * squareEdge, 7 * squareEdge, squareEdge, squareEdge);
    final sample = findPixel(plain, width, e1, skin.darkSquare)!;

    final (marked, _) = await render(tester, from: 'e1', to: 'e4');
    expect(
      pixel(marked, width, sample.dx.toInt(), sample.dy.toInt()),
      isNot(pixel(plain, width, sample.dx.toInt(), sample.dy.toInt())),
      reason: 'only the destination was marked; a move has two squares and the '
          'one it came from is half of what the reader is being shown',
    );
  });

  testWidgets('a square with no move on it is untouched', (tester) async {
    final (plain, width) = await render(tester);
    final sample = findPixel(plain, width, a1, skin.darkSquare)!;

    final (marked, _) = await render(tester, from: 'e1', to: 'e4');
    expect(
      pixel(marked, width, sample.dx.toInt(), sample.dy.toInt()),
      pixel(plain, width, sample.dx.toInt(), sample.dy.toInt()),
      reason: 'a square nowhere near the move was darkened, so the wash is not '
          'being clipped to the two squares it names',
    );
  });

  testWidgets('the wash stays inside its own square', (tester) async {
    // Carried over from `last_move_marker_test.dart`, deleted with the marker
    // it tested: a corner square is the case that shows a rect drawn a hair too
    // wide, because a1 has two edges against the board's own edge and two
    // against neighbours. The wash is a filled square, not a stroke, so nothing
    // is inset — which is exactly why it is worth asking.
    final (plain, width) = await render(tester);
    const b1 =
        Rect.fromLTWH(squareEdge, 7 * squareEdge, squareEdge, squareEdge);
    const a2 = Rect.fromLTWH(0, 6 * squareEdge, squareEdge, squareEdge);

    final onB1 = findPixel(plain, width, b1, skin.lightSquare)!;
    final onA2 = findPixel(plain, width, a2, skin.lightSquare)!;

    final (marked, _) = await render(tester, from: 'a1', to: 'h8');
    for (final (name, sample) in [('b1', onB1), ('a2', onA2)]) {
      expect(
        pixel(marked, width, sample.dx.toInt(), sample.dy.toInt()),
        pixel(plain, width, sample.dx.toInt(), sample.dy.toInt()),
        reason: 'the wash on a1 bled onto $name',
      );
    }
  });

  testWidgets('a name that is not a square draws nothing', (tester) async {
    // These names come out of a PGN comment nobody validates — the same reason
    // `getSquareCenter` was taught to answer `Offset.zero` rather than throw
    // inside a painter. Without the check that reads that answer, a rect lands
    // centred on the board's top-left corner, which is a quarter of a square of
    // wash on a1/a8 that no move put there.
    final (plain, width) = await render(tester);
    for (final bad in ['z9', 'e', '', 'e0']) {
      final (drawn, _) = await render(tester, to: bad);
      expect(drawn, plain,
          reason: 'the name "$bad" is not a square and something was drawn '
              'for it anyway');
    }
    expect(width, greaterThan(0));
  });

  testWidgets('no move, nothing drawn', (tester) async {
    final (plain, width) = await render(tester);
    final (nulls, _) = await render(tester, from: null, to: null);
    expect(nulls, plain,
        reason: 'a board with no move on it must render exactly as it did '
            'before this layer existed — every board loaded from a FEN is in '
            'that state, and so is every board in the app until phase 2');
  });

  // Asked of the method rather than of a render, and deliberately so: a
  // `RepaintBoundary.toImage()` paints its subtree whatever `shouldRepaint`
  // answers, and in the app the wash changes at the same moment the position
  // does — so the piece grid's own rebuild would hide a stale answer here for
  // as long as the two happen to change together. A mutation returning `false`
  // survived every pixel test in this file, which is how this one came to be
  // written. Its sibling `_SquaresPainter` has the same gap and is private.
  test('the layer repaints when, and only when, it has something new to say',
      () {
    const base =
        LastMovePainter(from: 'e2', to: 'e4', orientation: PlayerColor.white);

    expect(
        base.shouldRepaint(const LastMovePainter(
            from: 'e2', to: 'e4', orientation: PlayerColor.white)),
        isFalse,
        reason: 'nothing changed and the board would be repainted anyway');
    expect(
        base.shouldRepaint(const LastMovePainter(
            from: 'd2', to: 'e4', orientation: PlayerColor.white)),
        isTrue,
        reason: 'the move came from somewhere else and the old wash would '
            'stay on the board');
    expect(
        base.shouldRepaint(const LastMovePainter(
            from: 'e2', to: 'e3', orientation: PlayerColor.white)),
        isTrue);
    expect(
        base.shouldRepaint(const LastMovePainter(
            from: 'e2', to: 'e4', orientation: PlayerColor.black)),
        isTrue,
        reason: 'the board was turned round, so both squares are somewhere '
            'else on the screen while the move is the same one');
    expect(
        base.shouldRepaint(const LastMovePainter(
            from: null, to: null, orientation: PlayerColor.white)),
        isTrue,
        reason: 'the move was taken back and its wash has to go with it');
  });

  testWidgets('the wash follows the board when it is turned round',
      (tester) async {
    // Flipped, e4 sits where e5 sits the other way up. If the painter used the
    // board's geometry and the pieces used their own, this is where they would
    // stop agreeing — and the piece is what says which square is which.
    await tester.pumpWidget(wrap(SkinnedChessBoard(
      controller: ChessBoardController()..loadFen(fen),
      boardSkin: skin,
      pieceSkin: pieces,
      boardOrientation: PlayerColor.black,
      lastMoveTo: 'e4',
    )));
    await tester.pumpAndSettle();

    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    late Uint8List bytes;
    late int width;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      width = image.width;
      bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();
    });

    // Turned round, e4 is column 3, row 3. The rook is drawn there too, so the
    // square carries both and neither can stand in for the other.
    const flippedE4 =
        Rect.fromLTWH(3 * squareEdge, 3 * squareEdge, squareEdge, squareEdge);
    expect(findPixel(bytes, width, flippedE4, pieces.whiteFill), isNotNull,
        reason:
            'the rook is not where a flipped board puts e4, so this test is '
            'measuring the wrong square');
    expect(findPixel(bytes, width, flippedE4, skin.lightSquare), isNull,
        reason: 'the square under the rook is still its plain colour, so the '
            'wash went to the square e4 occupies when the board is the usual '
            'way up — the painter is not reading the orientation');
  });
}
