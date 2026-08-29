import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/board_skins.dart';

/// Guards the *catalogue*, not the colours.
///
/// The values are a judgement and are measured elsewhere; what is mechanical,
/// and what silently resets every reader's choice when it goes wrong, is the
/// id. `BoardSkin.byId` falls back to `classic` rather than throwing, so a
/// duplicated or renamed id does not crash — it quietly hands back the wrong
/// skin, or the default, and looks like the reader never chose anything. These
/// tests exist to make that loud while the catalogue is still one entry long,
/// because the moment it is five they stop being obvious.
void main() {
  group('BoardSkin catalogue', () {
    test('every id is unique', () {
      final ids = BoardSkin.all.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'two skins share an id: $ids');
    });

    test('every skin is reachable by its own id', () {
      for (final skin in BoardSkin.all) {
        expect(BoardSkin.byId(skin.id).id, skin.id);
      }
    });

    test('an unknown or missing id falls back to classic', () {
      expect(BoardSkin.byId(null).id, 'classic');
      expect(BoardSkin.byId('').id, 'classic');
      expect(BoardSkin.byId('a-skin-from-a-newer-build').id, 'classic');
    });

    test('classic is still the board the app has always drawn', () {
      // The sampled pixels of flutter_chess_board's brown_board.png. If this
      // fails, someone retuned the default rather than adding a skin beside it,
      // and every existing reader's board changed without them asking.
      expect(BoardSkin.classic.lightSquare.toARGB32(), 0xFFF0DAB5);
      expect(BoardSkin.classic.darkSquare.toARGB32(), 0xFFB58763);
    });

    test('every skin has a name to show', () {
      for (final skin in BoardSkin.all) {
        expect(skin.name.trim(), isNotEmpty, reason: 'skin ${skin.id}');
      }
    });
  });

  group('PieceSkin catalogue', () {
    test('every id is unique', () {
      final ids = PieceSkin.all.map((s) => s.id).toList();
      expect(ids.toSet().length, ids.length,
          reason: 'two skins share an id: $ids');
    });

    test('every skin is reachable by its own id', () {
      for (final skin in PieceSkin.all) {
        expect(PieceSkin.byId(skin.id).id, skin.id);
      }
    });

    test('an unknown or missing id falls back to classic', () {
      expect(PieceSkin.byId(null).id, 'classic');
      expect(PieceSkin.byId('nema-ovakvih').id, 'classic');
    });

    test('classic is the chess_vectors_flutter default, unchanged', () {
      expect(PieceSkin.classic.whiteFill.toARGB32(), 0xFFFFFFFF);
      expect(PieceSkin.classic.whiteStroke.toARGB32(), 0xFF000000);
      expect(PieceSkin.classic.blackFill.toARGB32(), 0xFF000000);
      expect(PieceSkin.classic.blackStroke.toARGB32(), 0xFF000000);
      // The interior detail of every black piece except the pawn. White by
      // default in the package, and the reason a black knight reads as a
      // knight instead of a blob.
      expect(PieceSkin.classic.blackDecoration.toARGB32(), 0xFFFFFFFF);
    });

    test('every skin has a name to show', () {
      for (final skin in PieceSkin.all) {
        expect(skin.name.trim(), isNotEmpty, reason: 'skin ${skin.id}');
      }
    });
  });
}
