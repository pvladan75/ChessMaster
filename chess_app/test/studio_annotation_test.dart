import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/models/analysis_models.dart';
import 'package:chess_app/move_tree.dart';
import 'package:chess_app/widgets/board_setup_dialog.dart';
import 'package:chess_app/widgets/engine_line_dialog.dart';
import 'package:chess_app/widgets/move_history_view.dart';
import 'package:chess_app/widgets/pgn_import_dialog.dart';
import 'package:chess_vectors_flutter/chess_vectors_flutter.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

const _startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

MoveNode _child(MoveNode parent, String san) {
  final node = MoveNode(
    san: san,
    fen: parent.fen,
    from: '',
    to: '',
    parent: parent,
  );
  parent.children.add(node);
  return node;
}

void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  group('MoveHistoryView', () {
    // The whole point of showing the tree: playing an alternative move from an
    // earlier position pushes the original continuation into a variation, and
    // without something on screen that lists variations there is no way back
    // to it — the navigation strip follows first children only.
    testWidgets('a sideline is on screen and can be gone back to',
        (tester) async {
      final tree = MoveTree(startingFen: _startFen);
      final e4 = _child(tree.root, 'e4');
      final e5 = _child(e4, 'e5');
      final c5 = _child(e4, 'c5');

      MoveNode? selected;
      await pump(
        tester,
        MoveHistoryView(
          moveTree: tree,
          currentNode: c5,
          onSelectNode: (node) => selected = node,
        ),
      );

      final text = tester.widget<RichText>(find.byType(RichText)).text;
      expect(text.toPlainText(), contains('e5'));
      expect(text.toPlainText(), contains('c5'));

      // Tapping the main line's move takes the board back to it.
      await tester.tapOnText(find.textRange.ofSubstring('e5'));
      expect(selected, same(e5));
    });

    testWidgets('a move comment is shown beside its move', (tester) async {
      final tree = MoveTree(startingFen: _startFen);
      final e4 = _child(tree.root, 'e4');
      e4.comment = 'Zauzima centar';

      await pump(
        tester,
        MoveHistoryView(
          moveTree: tree,
          currentNode: e4,
          onSelectNode: (_) {},
        ),
      );

      final text = tester.widget<RichText>(find.byType(RichText)).text;
      expect(text.toPlainText(), contains('Zauzima centar'));
    });
  });

  group('BoardSetupDialog', () {
    // Removing one piece used to mean arming the eraser, tapping, and arming
    // the piece again for the next square.

    /// The palette renders one of every piece as well, and is InkWells too, so
    /// anything counted over the whole dialog is off by the palette's copy.
    Finder onBoard(Finder finder) =>
        find.descendant(of: find.byType(GridView), matching: finder);

    /// The grid is laid out a8 first, so index 0 is a8 and index 48 is a2.
    Finder boardSquare(int index) => onBoard(find.byType(InkWell)).at(index);

    testWidgets('tapping a square that holds the armed piece empties it',
        (tester) async {
      // Tall enough that rank 2 is in the viewport, since the dialog scrolls.
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pump(tester, BoardSetupDialog(onFenGenerated: (_) {}));

      // A white pawn is what the palette arms first, and a2 holds one.
      expect(onBoard(find.byType(WhitePawn)), findsNWidgets(8));
      await tester.tap(boardSquare(6 * 8));
      await tester.pumpAndSettle();

      expect(onBoard(find.byType(WhitePawn)), findsNWidgets(7));
    });

    testWidgets('long-pressing a square empties it whatever is armed',
        (tester) async {
      await pump(tester, BoardSetupDialog(onFenGenerated: (_) {}));

      // a8 is a black rook — not the armed piece, so a tap would place a pawn
      // over it rather than clear it.
      expect(onBoard(find.byType(BlackRook)), findsNWidgets(2));
      await tester.longPress(boardSquare(0));
      await tester.pumpAndSettle();

      expect(onBoard(find.byType(BlackRook)), findsOneWidget);
      expect(onBoard(find.byType(WhitePawn)), findsNWidgets(8));
    });
  });

  group('PgnImportDialog', () {
    testWidgets('pasted text is handed over whole', (tester) async {
      String? pasted;
      await pump(
        tester,
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => PgnImportDialog(
                onPickFile: () {},
                onPasted: (text) => pasted = text,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1. e4 e5 2. Nf3 *');
      await tester.tap(find.text('Učitaj'));
      await tester.pumpAndSettle();

      expect(pasted, '1. e4 e5 2. Nf3 *');
    });

    testWidgets('an empty box loads nothing', (tester) async {
      var called = false;
      await pump(
        tester,
        PgnImportDialog(onPickFile: () {}, onPasted: (_) => called = true),
      );

      await tester.tap(find.text('Učitaj'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
    });
  });

  group('EngineLineDialog', () {
    AnalysisLine line() => AnalysisLine.fromPv(
          multipv: 1,
          depth: 20,
          eval: '+0.32',
          pvString: 'e2e4 e7e5 g1f3',
          startingFen: _startFen,
        );

    testWidgets('a line can be sent into the move tree', (tester) async {
      AnalysisLine? inserted;
      await pump(
        tester,
        EngineLineDialog(
          line: line(),
          orientation: PlayerColor.white,
          onInsertLineAsVariation: (l) => inserted = l,
        ),
      );

      await tester.tap(find.text('Ubaci kao varijaciju'));
      await tester.pumpAndSettle();

      expect(inserted?.sanMoveList, ['e4', 'e5', 'Nf3']);
    });

    testWidgets('a screen with no move tree is offered no such button',
        (tester) async {
      await pump(
        tester,
        EngineLineDialog(line: line(), orientation: PlayerColor.white),
      );

      expect(find.text('Ubaci kao varijaciju'), findsNothing);
    });
  });
}
