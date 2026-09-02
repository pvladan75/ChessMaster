import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chess_board/flutter_chess_board.dart';

import 'package:chess_app/widgets/board_overlay_painter.dart';
import 'package:chess_app/widgets/game_screen/chess_board_with_overlay.dart';

const double _boardSize = 400;

/// Reproduces how the room screen wires the board up, so tap-to-move is
/// exercised in the same configuration a trainer actually sits in.
class _Harness extends StatefulWidget {
  const _Harness({
    required this.controller,
    required this.onMove,
    this.onSquareTapForDrawing,
    this.isAllowedToMove = true,
    this.isDrawingMode = false,
    this.scrollable = false,
  });

  final ChessBoardController controller;
  final void Function(String from, String to, String promotion) onMove;
  final ValueChanged<String>? onSquareTapForDrawing;
  final bool isAllowedToMove;
  final bool isDrawingMode;

  /// The room screen puts the board in a Column inside a SingleChildScrollView,
  /// which brings a vertical drag recognizer into the gesture arena alongside
  /// the board's own tap.
  final bool scrollable;

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  Widget build(BuildContext context) {
    Widget board = SizedBox(
      width: _boardSize,
      height: _boardSize,
      child: _board(),
    );

    if (widget.scrollable) {
      board = SingleChildScrollView(
        child: Column(children: [board, const SizedBox(height: 2000)]),
      );
    }

    return MaterialApp(
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: board),
      ),
    );
  }

  Widget _board() => ChessBoardWithOverlay(
        controller: widget.controller,
        boardOrientation: PlayerColor.white,
        boardSize: _boardSize,
        isAllowedToMove: widget.isAllowedToMove,
        isDrawingMode: widget.isDrawingMode,
        drawingStartSquare: null,
        arrows: const [],
        engineArrows: const [],
        onMove: widget.onMove,
        onSquareTapForDrawing: widget.onSquareTapForDrawing ?? (_) {},
      );
}

/// Board-local centre of [square], which is also its global position here
/// because the harness pins the board to the top-left corner.
Offset _centreOf(String square) =>
    getSquareCenter(square, _boardSize, PlayerColor.white);

void main() {
  testWidgets('tap the piece, then the destination, and the move is made',
      (tester) async {
    final controller = ChessBoardController();
    final moves = <String>[];

    await tester.pumpWidget(_Harness(
      controller: controller,
      onMove: (from, to, promotion) => moves.add('$from$to$promotion'),
    ));

    await tester.tapAt(_centreOf('e2'));
    await tester.pump();
    await tester.tapAt(_centreOf('e4'));
    await tester.pump();

    expect(moves, ['e2e4'],
        reason: 'tap-to-move is the whole point of the setting');
    expect(controller.game.get('e4')?.type, PieceType.PAWN);
  });

  testWidgets('tapping an empty square first does nothing', (tester) async {
    final controller = ChessBoardController();
    final moves = <String>[];

    await tester.pumpWidget(_Harness(
      controller: controller,
      onMove: (from, to, promotion) => moves.add('$from$to$promotion'),
    ));

    await tester.tapAt(_centreOf('e4'));
    await tester.pump();

    expect(moves, isEmpty);
  });

  testWidgets(
      'still works with the board inside a scroll view, as the room has it',
      (tester) async {
    final controller = ChessBoardController();
    final moves = <String>[];

    await tester.pumpWidget(_Harness(
      controller: controller,
      onMove: (from, to, promotion) => moves.add('$from$to$promotion'),
      scrollable: true,
    ));

    await tester.tapAt(_centreOf('e2'));
    await tester.pump();
    await tester.tapAt(_centreOf('e4'));
    await tester.pump();

    expect(moves, ['e2e4']);
  });

  // The two states that reproduce the reported symptom — a board where nothing
  // moves at all. With tap mode on, the package's drag-and-drop is switched
  // off, so if the tap overlay is inactive too there is no way left to move a
  // piece. Worth pinning down, because "nothing happens" gives the user no clue
  // which of these it is.
  testWidgets('nothing moves when the user is not allowed to move',
      (tester) async {
    final moves = <String>[];

    await tester.pumpWidget(_Harness(
      controller: ChessBoardController(),
      onMove: (from, to, promotion) => moves.add('$from$to$promotion'),
      isAllowedToMove: false,
    ));

    await tester.tapAt(_centreOf('e2'));
    await tester.pump();
    await tester.tapAt(_centreOf('e4'));
    await tester.pump();

    expect(moves, isEmpty);
  });

  testWidgets('drawing mode takes the taps, so no move is made',
      (tester) async {
    final moves = <String>[];
    final drawn = <String>[];

    await tester.pumpWidget(_Harness(
      controller: ChessBoardController(),
      onMove: (from, to, promotion) => moves.add('$from$to$promotion'),
      onSquareTapForDrawing: drawn.add,
      isDrawingMode: true,
    ));

    await tester.tapAt(_centreOf('e2'));
    await tester.pump();

    expect(moves, isEmpty);
    expect(drawn, ['e2'],
        reason: 'the tap belongs to the arrow tool while it is on');
  });

  testWidgets('dragging works too — the two input styles coexist',
      (tester) async {
    final controller = ChessBoardController();
    final moves = <String>[];

    await tester.pumpWidget(_Harness(
      controller: controller,
      onMove: (from, to, promotion) => moves.add('$from$to$promotion'),
    ));

    await tester.dragFrom(_centreOf('e2'), _centreOf('e4') - _centreOf('e2'));
    await tester.pumpAndSettle();

    // Tap mode is an addition, not a replacement: reaching for the piece and
    // dragging it must keep working, or the setting looks like a broken board.
    expect(moves, ['e2e4']);
  });

  testWidgets('a dragged move is not animated', (tester) async {
    final controller = ChessBoardController();

    await tester.pumpWidget(_Harness(
      controller: controller,
      onMove: (_, __, ___) {},
    ));

    await tester.dragFrom(_centreOf('e2'), _centreOf('e4') - _centreOf('e2'));
    await tester.pump();

    // The user already carried the piece across the board by hand; replaying
    // the trip makes the move look like it happened twice.
    expect(find.byType(AnimatedMovePiece), findsNothing);
  });

  testWidgets('a tapped move is animated', (tester) async {
    final controller = ChessBoardController();

    await tester.pumpWidget(_Harness(
      controller: controller,
      onMove: (_, __, ___) {},
    ));

    await tester.tapAt(_centreOf('e2'));
    await tester.pump();
    await tester.tapAt(_centreOf('e4'));
    await tester.pump();

    // Nothing travelled under the pointer here, so the slide is what shows
    // the piece actually going somewhere.
    expect(find.byType(AnimatedMovePiece), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('a second tap on the same piece deselects it', (tester) async {
    final controller = ChessBoardController();
    final moves = <String>[];

    await tester.pumpWidget(_Harness(
      controller: controller,
      onMove: (from, to, promotion) => moves.add('$from$to$promotion'),
    ));

    await tester.tapAt(_centreOf('e2'));
    await tester.pump();
    await tester.tapAt(_centreOf('e2'));
    await tester.pump();
    // Deselected, so the next tap on an empty square must not move anything.
    await tester.tapAt(_centreOf('e4'));
    await tester.pump();

    expect(moves, isEmpty);
  });

  /// A pawn on d7 with d8 free, white to move — the position the reader was
  /// sitting in when they reported that promotion did not work.
  ChessBoardController promotionBoard() {
    final controller = ChessBoardController();
    controller.loadFen('8/3P2P1/1R6/P3n2K/4k2P/1P6/8/8 w - - 5 23');
    return controller;
  }

  testWidgets('a pawn reaching the last rank asks what it becomes',
      (tester) async {
    final controller = promotionBoard();
    final moves = <String>[];

    await tester.pumpWidget(_Harness(
      controller: controller,
      onMove: (from, to, promotion) => moves.add('$from$to$promotion'),
    ));

    await tester.tapAt(_centreOf('d7'));
    await tester.pump();
    await tester.tapAt(_centreOf('d8'));
    await tester.pumpAndSettle();

    expect(find.text('U šta se pretvara pešak?'), findsOneWidget,
        reason: 'tap-move je ranije ćutke pravio damu');
    expect(moves, isEmpty, reason: 'ništa se ne igra dok se ne odgovori');

    await tester.tap(find.text('Skakač'));
    await tester.pumpAndSettle();

    expect(controller.game.get('d8')?.type, PieceType.KNIGHT);
    expect(moves, ['d7d8n'],
        reason: 'izabrana figura mora da stigne i do ekrana koji vodi partiju');
  });

  testWidgets('backing out of the question leaves the pawn where it was',
      (tester) async {
    // A move nobody finished choosing is not a move. Playing it as a queen
    // would be the app answering its own question.
    final controller = promotionBoard();
    final moves = <String>[];

    await tester.pumpWidget(_Harness(
      controller: controller,
      onMove: (from, to, promotion) => moves.add('$from$to$promotion'),
    ));

    await tester.tapAt(_centreOf('d7'));
    await tester.pump();
    await tester.tapAt(_centreOf('d8'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Odustani'));
    await tester.pumpAndSettle();

    expect(moves, isEmpty);
    expect(controller.game.get('d8'), isNull);
    expect(controller.game.get('d7')?.type, PieceType.PAWN);
  });

  testWidgets('an ordinary move is not interrupted by the question',
      (tester) async {
    final controller = promotionBoard();
    final moves = <String>[];

    await tester.pumpWidget(_Harness(
      controller: controller,
      onMove: (from, to, promotion) => moves.add('$from$to$promotion'),
    ));

    // The rook to the eighth rank: the destination looks like a promotion
    // square and is not one.
    await tester.tapAt(_centreOf('b6'));
    await tester.pump();
    await tester.tapAt(_centreOf('b8'));
    await tester.pumpAndSettle();

    expect(find.text('U šta se pretvara pešak?'), findsNothing);
    expect(moves, ['b6b8']);
  });

  testWidgets('the highlight is forwarded to the painter even in drawing mode',
      (tester) async {
    final controller = ChessBoardController();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChessBoardWithOverlay(
          controller: controller,
          boardOrientation: PlayerColor.white,
          boardSize: 400,
          isAllowedToMove: true,
          isDrawingMode: true,
          drawingStartSquare: null,
          arrows: const [],
          engineArrows: const [],
          onMove: (_, __, ___) {},
          onSquareTapForDrawing: (_) {},
          lastMoveFrom: 'e2',
          lastMoveTo: 'e4',
        ),
      ),
    ));

    final painters = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((w) => w.painter)
        .whereType<ChessBoardPainter>()
        .toList();

    expect(painters, isNotEmpty, reason: 'the painter must be in the tree');
    for (final p in painters) {
      expect(p.lastMoveFrom, 'e2');
      expect(p.lastMoveTo, 'e4');
    }
  });
}
