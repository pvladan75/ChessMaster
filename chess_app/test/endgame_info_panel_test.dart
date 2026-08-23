import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chess_app/theme/breakpoints.dart';
import 'package:chess_app/widgets/endgame_info_panel.dart';

const _boardKey = Key('board');

Widget harness({required double width, required double height}) => MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => LayoutBuilder(
            builder: (context, constraints) => EndgameBoardLayout(
              wide: Breakpoints.isWide(context),
              constraints: constraints,
              panel: const EndgameInfoPanel(
                title: 'Beli na potezu — održite remi',
                subtitle: 'Nađite potez koji drži remi.',
                chips: ['KRPvKR', 'Težina: 6/10'],
                message: 'Tačno — remi je održan.',
                messageIsGood: true,
              ),
              reserveHeight: 200,
              builder: (boardSize) => Column(
                children: [
                  SizedBox(
                    key: _boardKey,
                    width: boardSize,
                    height: boardSize,
                    child: const ColoredBox(color: Colors.brown),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('on a wide window the panel stands to the right of the board',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(width: 1200, height: 900));
    await tester.pumpAndSettle();

    final board = tester.getRect(find.byKey(_boardKey));
    final panel = tester.getRect(find.byType(EndgameInfoPanel));

    // Beside, not above or below: the whole point is that the board and what
    // is being said about it are in view together.
    expect(panel.left, greaterThan(board.right - 1));
    expect(panel.top, lessThan(board.bottom));
    // And close to it. The first version let the board column swallow every
    // spare pixel and centred a capped board inside it, which parked the panel
    // at the far edge of a wide monitor with empty board between the two things
    // you have to read together.
    expect(panel.left - board.right, lessThan(40));
  });

  testWidgets('on a phone the layout hands the whole width to the board',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(harness(width: 360, height: 800));
    await tester.pumpAndSettle();

    // Narrow means the layout renders the board column alone; the screen puts
    // the panel under it, which is why there is none in the tree here.
    expect(tester.takeException(), isNull);
    expect(find.byType(EndgameInfoPanel), findsNothing);
    expect(tester.getSize(find.byKey(_boardKey)).width, 360 - 24);
    // Square, and bounded by the tighter axis either way.
    expect(tester.getSize(find.byKey(_boardKey)).height, 360 - 24);
  });

  testWidgets(
      'the panel says all four of its parts, and none of the empty ones',
      (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: EndgameInfoPanel(
          title: 'Crni je ovde odigrao Rd3 i izgubio remi',
          chips: ['KRPPvKR'],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('Rd3'), findsOneWidget);
    expect(find.text('KRPPvKR'), findsOneWidget);
    // A panel with nothing to report shows no empty box where the verdict goes.
    expect(find.byType(Container), findsNWidgets(2));
  });
}
